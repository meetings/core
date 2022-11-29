package Dicole::Utils::User;
use strict;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Digest::SHA;
use Dicole::Utils::Text;

sub get_domain_note {
    my ( $self, $user, $domain_id, $note ) = @_;

    my $data = $self->notes_data( $user );

    return $data->{ $domain_id }->{ $note };
}

sub set_domain_note {
    my ( $self, $user, $domain_id, $note, $value, $opts ) = @_;
    $opts = { skip_save => $opts } unless ref $opts eq 'HASH';

    my $data = $self->notes_data( $user, "die_on_debug" );

    my $old_value = $data->{ $domain_id }->{ $note };

    if ( defined $value ) {
        $data->{ $domain_id }->{ $note } = $value;
    }
    else {
        delete $data->{ $domain_id }->{ $note };
   
    }

    $self->set_notes_data( $user, $data, $opts );

    return $old_value;
}

sub notes_data {
    my ( $self, $user, $die_on_debug ) = @_;

    $user = $self->ensure_object( $user );

    my $data = eval { Dicole::Utils::JSON->decode( $user->notes || '{}' ) };

    my $debug = ( $user->notes && ! $data ) ? 1 : 0;

    if ( $@ || $debug ) {
        my $initial_error = $@;
        use Carp;
        eval { Carp::confess };
        get_logger(LOG_APP)->error( "Confession for this is:\n\n" . $@ . "\n\nInitial error was:\n\n" . $initial_error );

        use Data::Dumper;
        get_logger(LOG_APP)->error( "Failed to parse existing notes for user ". $user->id .":\n\n" .  Data::Dumper::Dumper( $user->notes ) );

        die "Could not parse user notes" if $die_on_debug;
    }

    return $data || {};
}

sub set_notes_data {
    my ( $self, $user, $data, $opts ) = @_;
    $opts = { skip_save => $opts } unless ref $opts eq 'HASH';

    $user = eval { $self->ensure_object( $user ) };
    my $edata = eval { Dicole::Utils::JSON->encode( $data ) };

    if ( $@ || $edata eq '' || $edata eq '{}' ) {
        my $initial_error = $@;
        use Carp;
        eval { Carp::confess };
        get_logger(LOG_APP)->error( "Confession for this is:\n\n" . $@ . "\n\nInitial error was:\n\n" . $initial_error );

        use Data::Dumper;
        get_logger(LOG_APP)->error( "Failed to encode notes data or refusing to store empty notes for user ".$user->id."! Tried to store:\n\n" . Data::Dumper::Dumper( $data ) . "\n\n leaving as: \n\n" . Data::Dumper::Dumper( $user->notes ) );
        return 0;
    }

    $user->notes( $edata );
    $user->save unless $opts->{skip_save};

    if ( CTX->request ) {
        my $session = CTX->request->session;
        $session->{_oi_cache}{user_refresh_on} = time;
    }

    return 1;
}

sub full_name {
    my ( $self, $user, $default ) = @_;

    $user = eval { $self->ensure_object( $user ) };
    return $default unless $user;
    $self->update_full_name( $user );
    return $user->name;
}

sub name {
    my ( $self, $user, $default ) = @_;

    $user = eval { $self->ensure_object( $user ) };
    return $default unless $user;
    return $user->email || $user->phone unless $user->first_name || $user->last_name;
    return join( " ", ( $user->first_name || (), $user->last_name || () ));
}

sub initials {
    my ( $self, $user, $default ) = @_;

    $user = eval { $self->ensure_object( $user ) };
    return $self->form_user_initials_for_name( $self->name( $user ), $default );
}

sub form_user_initials_for_name {
    my ( $self, $name, $default ) = @_;

    $name = Dicole::Utils::Text->ensure_internal( $name );
    $name =~ s/\@.*//;

    my @name_parts = split /\s|\./, $name;
    my $initials = ( @name_parts > 1 ) ?
        [split //, $name_parts[0]]->[0] . [split //, $name_parts[-1]]->[0]
        :
        [split //, $name_parts[0]]->[0] . [split //, $name_parts[0]]->[1];

    return Dicole::Utils::Text->ensure_utf8( $initials ) || $default;
}

sub first_name {
    my ( $self, $user, $default ) = @_;

    $user = eval { $self->ensure_object( $user ) };
    return $default unless $user;
    return $user->email unless $user->first_name;
    return $user->first_name;
}

sub short_name {
    my ( $self, $user, $default ) = @_;

    $user = eval { $self->ensure_object( $user ) };
    return $default unless $user;
    return $user->email unless $user->first_name || $user->last_name;
    return $self->short_name_from_parts( $user->first_name, $user->last_name );
}

sub short_name_from_parts {
    my ( $self, $first, $last ) = @_;

    $last = Dicole::Utils::Text->ensure_internal( $last );
    my @parts = split /\s+/, $last;
    my $letters = '';
    for my $part ( @parts ) {
        my ( $letter ) = $part =~ /(\w)/;
        $letters .= $part if $letter;
    }

    return $first . ' ' . Dicole::Utils::Text->ensure_utf8( $letters ) . '.';
}

sub update_full_name {
    my ( $self, $user ) = @_;

    $user = eval { $self->ensure_object( $user ) };
    return unless $user;
    my $full = $user->name || '';
    my $real_full = $self->_combine_full_name( $user );
    unless ( $full eq $real_full ) {
        $user->name( $real_full );
        $user->save;
    }

    return 1;
}

sub email_with_name {
    my ( $self, $user ) = @_;

    $user = eval { $self->ensure_object( $user ) };
    die "no user found" unless $user;

    my $full_name = $self->full_name( $user ) || $user->email;
    $full_name =~ s/"//g;

    return '"' . $full_name . '" <' . $user->email . '>';
}

sub sanitized_email {
    my ( $self, $user ) = @_;

    $user = eval { $self->ensure_object( $user ) };
    die "no user found" unless $user;

    return Dicole::Utils::Mail->string_to_address( $self->email_with_name( $user ) );
}

sub url {
    my ( $self, $user, $group_id, $domain_id, $params ) = @_;
    $user = eval { $self->ensure_id( $user ) };
    return undef unless $user;

    return eval { CTX->lookup_action('networking_api')->e( user_profile_url => {
        user_id => $user, group_id => $group_id, domain_id => $domain_id, params => $params
    } ) } || undef;
}

sub image {
    my ( $self, $user, $size, $domain_id, $profile_object ) = @_;
    $user = eval { $self->ensure_id( $user ) };
    return undef unless $user;

    return CTX->lookup_action('networking_api')->e( user_portrait_thumb => {
        profile_object => $profile_object, user_id => $user, domain_id => $domain_id, size => $size, no_default => 1
    } );
}

sub icon_hash {
    my ( $self, $user, $size, $group_id, $domain_id, $profile_object, $url_params ) = @_;

    $user = eval { $self->ensure_object( $user ) };
    my $image = $self->image( $user, $size, $domain_id, $profile_object );

    return {
        id => $user->id,
        name => $self->name( $user ),
        url => $self->url( $user, $group_id, $domain_id, $url_params ),
        image => $image,
        'image_' . $size => $image,
    };
}

sub icon_hash_list {
    my ( $self, $users, $size, $group_id, $domain_id ) = @_;

    my $profile_map = CTX->lookup_action('networking_api')->e( user_profile_object_map => { 
        user_id_list => [ map { ref( $_ ) ? $_->id : $_ } @$users ],
        domain_id => $domain_id,
    } );

    return [ map { Dicole::Utils::User->icon_hash( $_, $size, $group_id, $domain_id, $profile_map->{ ref( $_ ) ? $_->id : $_ } ) } @$users ];
}

sub user_belongs_to_group {
    return belongs_to_group( @_ );
}

sub belongs_to_group {
    my ( $self, $user_id_or_object, $group_id_or_object ) = @_;

    my $user_id = ref( $user_id_or_object ) ? $user_id_or_object->id : $user_id_or_object;
    my $group_id = ref( $group_id_or_object ) ? $group_id_or_object->id : $group_id_or_object;

    my $group_users = SPOPS::SQLInterface->db_select( {
        select => [ 'user_id' ],
        from => 'dicole_group_user',
        where => 'user_id = ? AND groups_id = ?',
        value => [ $user_id, $group_id ],
        db     => CTX->datasource( CTX->lookup_system_datasource_name ),
        return => 'hash',
    }) || [];
    
    return scalar( @$group_users ) ? 1 : 0;
}

sub filter_list_to_group_members {
    my ( $self, $user_id_or_object_list, $group_id_or_object ) = @_;

    my %id_map = map { $self->ensure_id( $_ ) => $_ } @$user_id_or_object_list;
    my $group_id = ref( $group_id_or_object ) ? $group_id_or_object->id : $group_id_or_object;

    my $group_users = SPOPS::SQLInterface->db_select( {
        select => [ 'user_id' ],
        from => 'dicole_group_user',
        where => 'groups_id = ? AND ' . Dicole::Utils::SQL->column_in( user_id => [ keys %id_map ] ),
        value => [ $group_id ],
        db     => CTX->datasource( CTX->lookup_system_datasource_name ),
        return => 'hash',
    }) || [];

    return [ map { $id_map{ $_->{user_id} } } @$group_users ];
}

sub filter_list_to_domain_users {
    my ( $self, $user_id_or_object_list, $domain_id_or_object ) = @_;

    my %id_map = map { $self->ensure_id( $_ ) => $_ } @$user_id_or_object_list;
    my $domain_id = ref( $domain_id_or_object ) ? $domain_id_or_object->id : $domain_id_or_object;

    my $domain_users = SPOPS::SQLInterface->db_select( {
        select => [ 'user_id' ],
        from => 'dicole_domain_user',
        where => 'domain_id = ? AND ' . Dicole::Utils::SQL->column_in( user_id => [ keys %id_map ] ),
        value => [ $domain_id ],
        db     => CTX->datasource( CTX->lookup_system_datasource_name ),
        return => 'hash',
    }) || [];

    return [ map { $id_map{ $_->{user_id} } } @$domain_users ];
}

sub _combine_full_name {
    my ( $self, $data ) = @_;

    my $first = $data->{first_name};
    my $middle = $data->{middle_name};
    my $last = $data->{last_name};

    return join (' ', ( $first || (), $middle || (), $last || () )) || '';
}

sub ensure_object {
    my ( $self, $user ) = @_;

    if ( $user && ! ref( $user ) ) {
        if ( CTX->request && CTX->request->auth_user_id == $user ) {
            $user = CTX->request->auth_user;
        }
        else {
            $user = CTX->lookup_object('user')->fetch( $user );
        }
    }

    if ( ! ref $user ) {
        eval { Carp::confess; };
        my $error = $@;
        get_logger(LOG_APP)->error( $error );

        die 'user not found: "' . $user .'"';
    }
    else {
        return $user;
    }
}

sub ensure_object_list {
    my ( $self, $users ) = @_;

    my @id_list = ();
    my %id_lookup = ();
    my %found_object_id_lookup = ();
    my %missing_object_id_lookup = ();

    for my $u ( @$users ) {
        next unless $u;
        if ( ref ( $u ) ) {
            next if $found_object_id_lookup{ $u->id };
            delete $missing_object_id_lookup{ $u->id };
            $found_object_id_lookup{ $u->id } = $u;
        }
        else {
            next if $found_object_id_lookup{ $u };
            next if $missing_object_id_lookup{ $u };
            $missing_object_id_lookup{ $u } = 1;
        }
        my $id = ref( $u ) ? $u->id : $u;
        next if $id_lookup{ $id };
        $id_lookup{ $id } = 1;
        push @id_list, $id;
    }

    if ( CTX->request && CTX->request->auth_user_id && $missing_object_id_lookup{ CTX->request->auth_user_id } ) {
        $found_object_id_lookup{ CTX->request->auth_user_id } = CTX->request->auth_user;
        delete $missing_object_id_lookup{ CTX->request->auth_user_id };
    }

    my $objects = CTX->lookup_object('user')->fetch_group({
        where => Dicole::Utils::SQL->column_in( user_id => [ keys %missing_object_id_lookup ] )
    } ) || [];

    $found_object_id_lookup{ $_->id } = $_ for @$objects;

    return [ map { $found_object_id_lookup{ $_ } || () } @id_list ];
}

sub ensure_object_id_map {
    my ( $self, $users ) = @_;
    $users = $self->ensure_object_list( $users );
    return { map { $_ ? ( $_->id => $_ ) : () } @$users };
}


sub ensure_id {
    my ( $self, $user ) = @_;

    if ( $user && ref( $user ) ) {
        $user = $user->id;
    }

    return $user;
}

sub change_password {
    my ( $self, $user, $old, $new, $check ) = @_;

    return unless $user;
    if ( $old ) {
        if ( $new || $check ) {
            if ( ! ( $new eq $check ) ) {
                return ( 0, "Passwords did't not match. New password not saved." );
            }
        }
    }
    else {
        if ( $new || $check ) {
            return ( 0, "You need to provide the old password to change passwords" );
        }
        return;
    }

    $user = $self->ensure_object( $user );

    if ( $user->{external_auth} && ! ($user->{external_auth} =~ /local/i)) {
        my $l = Dicole::LDAPUser->new( {
            ldap_server_name => $user->{external_auth},
            login_name       => $user->{login_name},
            password         => $old,
        } );
        if ( $l->check_password ) {
            if ( $l->password( $new ) && $l->update ) {
                return ( 1, 'New password saved.' );
            }
            else {
                return ( 0, 'Password modification failed' );
            }
        }
        else {
            return ( 0, 'Old password authentication failed' );
        }
    }

    if ( ! $user->check_password( $old ) ) {
        return ( 0, 'Old password authentication failed' );
    }

    my $crypted = ( CTX->lookup_login_config->{crypt_password} )
        ? SPOPS::Utility->crypt_it( $new ) : $new;
    $user->password( $crypted );
    $user->save;

    return ( 1, 'New password saved.' );
}

sub identification_key {
    my ( $class, $user, $secure, $domain_id, $time ) = @_;

    $user = $class->ensure_object( $user );
    $secure = $secure ? 1 : 0;
    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );
    $time ||= time;

    my $secret = $class->authorization_key_invalidation_secret( $user );
    my @parts = ( $secret, $user->id, $secure, $domain_id, $time );
    my $string = join '::', @parts;
    my $digest = Digest::SHA::sha1_base64( $string );
    $digest =~ tr/\+\//-_/;
    
    return join '_', $user->id, $secure, $domain_id, $time, $digest;
}

sub resolve_identification_key {
    my ( $class, $key ) = @_;

    my ($id, $secure, $domain_id, $time, $checksum ) = $key =~ /^(\d+)_(\d+)_(\d+)_(\d+)_(.*)$/;

    my $valid_key = $class->identification_key( $id, $secure, $domain_id, $time );

    return ( 0, 0, 0, 0 ) unless $key eq $valid_key;
    return ( $id, $secure, $domain_id, $time );
}

sub temporary_authorization_key {
    my ( $class, $user, $expire_hours ) = @_;

    $expire_hours ||= 1;

    return $class->authorization_key( user => $user, create_session => 1, valid_hours => $expire_hours );
}

sub permanent_authorization_key {
    my ( $class, $user ) = @_;

    return $class->authorization_key( user => $user );
}

sub authorization_key {
    my ( $class, %params ) = @_;

    my $param = 0;
    my $time = time;
    my $type = '';

    $type .= 'c' if $params{create_session};
    $type .= 'd' if $params{allow_disable};
    $type .= 's' if $params{single_use};
    if ( $param = $params{valid_hours} ) {
        $type .= 'h';
    }
    elsif ( $param = $params{valid_minutes} ) {
        $type .= 'm';
    }
    else {
        $type .= 'e';
        $time = 0 unless $type =~ /d/ || $type =~ /s/;
    }

    my $key = $class->_authorization_key( 'v1', $type, $params{user}, $param, $time );

    if ( $type =~ /d/ || $type =~ /s/ ) {
        my $desc =  $params{description};
        # TODO: store this disablable key to database
    }
    # TODO: store any key to database so that user sees which keys are still open
    # TODO: and wipe this database every time the user private key is changed

    return $key;
}

sub _authorization_key {
    my ( $class, $version, $type, $user, $expire_param, $creation_time ) = @_;

    $expire_param ||= 0;
    $creation_time ||= 0;

    my $uid = ref( $user ) ? $user->id : $user;

    my $secret = $class->authorization_key_invalidation_secret( $user );
    my @parts = ( $secret, $version, $type, $uid, $expire_param, $creation_time );
    my $string = join '::', @parts;
    my $digest = Digest::SHA::sha1_base64( $string );
    $digest =~ tr/\+\//-_/;
    return join '_', $version, $type, $uid, $expire_param, $creation_time, $digest;
}

sub fetch_by_authorization_key {
    my ( $class, $key ) = @_;

    # types: eternal, hours to expire, minutes to expire, create session, single use, disablable

    my ( $version, $type, $id, $expire_param, $creation_time, $checksum ) =
        $key =~ /^(v\d+)_([ehmcsd]+)_(\d+)_(\d+)_(\d+)_(.*)$/;
    my $user = eval { CTX->lookup_object('user')->fetch( $id, { skip_security => 1 } ) };
    return undef unless $user;

    return undef unless $class->_authorization_key( $version, $type, $user, $expire_param, $creation_time ) eq $key;

    if ( $type =~ /d/ || $type =~ /s/ ) {
        # TODO: query disablable key database for this key. return undef if disabled.
        # mark disabled if single use.
    }
    if ( $type =~ /h/ ) {
        return undef if time > $creation_time + $expire_param * 60 * 60;
    }
    elsif ( $type =~ /m/ ) {
        return undef if time > $creation_time + $expire_param * 60;
    }

    return wantarray ? ( $user, $type ) : $user;
}

sub fetch_by_authorization_key_in_domain {
    my ( $class, $key, $domain_id ) = @_;

    my ( $user, $type ) = Dicole::Utils::User->fetch_by_authorization_key( $key );

    return ( $user && Dicole::Utils::User->belongs_to_domain( $user, $domain_id ) ) ? $user : undef;
}

sub authorization_key_invalidation_secret {
    my( $self, $user ) = @_;
    
    $user = $self->ensure_object( $user );

    if ( ! $user->inv_secret ) {
        $self->invalidate_user_authorization_keys( $user );
    }

    return ( $user->inv_secret || '' ) . '::' . ( CTX->server_config->{dicole}{master_auth_invalidation_secret} || '' );
}

sub invalidate_user_authorization_keys {
    my ( $self, $user ) = @_;

    $user = $self->ensure_object( $user );

    return unless ref( $user ) && ( ! $user->first_name || ( $user->first_name ne 'Anonymous' ) );

    my @chars = ('a'..'z','A'..'Z','0'..'9','_','-');
    my $new_random = join( "", map( { $chars[rand @chars] } (1..16)));

    $user->inv_secret( $new_random );
    $user->save;

    # TODO: delete all the users keys from the database
}

sub fetch_user_by_login {
    my ( $class, $login, $domain_id ) = @_;

    return undef unless $login;

    if ( $domain_id ) {
        return $class->fetch_user_by_login_in_domain( $login, $domain_id );
    }
    else {
        my $users = CTX->lookup_object('user')->fetch_group( {
            where => 'login_name = ?',
            value => [ $login ],
        } ) || [];

        my $user = pop @$users;

        unless ( $user ) {
            $users = CTX->lookup_object('user')->fetch_group( {
                where => 'email = ?',
                value => [ $login ],
            } ) || [];
            $user = pop @$users;
        }

        return $user;
    }
}
sub fetch_user_by_facebook_uid_in_domain {
    my ( $class, $uid, $domain_id ) = @_;

    my $users = CTX->lookup_object('user')->fetch_group( {
        from => ['sys_user', 'dicole_domain_user'],
        where => 'facebook_user_id = ? AND domain_id = ? AND sys_user.user_id = dicole_domain_user.user_id',
        value => [ $uid, $domain_id ],
    } ) || [];

    return pop @$users;
}

sub fetch_user_by_phone_in_domain {
    my ( $class, $phone, $domain_id ) = @_;

    return undef unless $phone;

    my $users = CTX->lookup_object('user')->fetch_group( {
        from => ['sys_user', 'dicole_domain_user'],
        where => 'phone = ? AND domain_id = ? AND sys_user.user_id = dicole_domain_user.user_id',
        value => [ $phone, $domain_id ],
    } ) || [];

    my $user = pop @$users;

    return $user;
}

sub fetch_user_by_login_in_domain {
    my ( $class, $login, $domain_id ) = @_;

    return undef unless $login;

    my $users = CTX->lookup_object('user')->fetch_group( {
        from => ['sys_user', 'dicole_domain_user'],
        where => 'login_name = ? AND domain_id = ? AND sys_user.user_id = dicole_domain_user.user_id',
        value => [ $login, $domain_id ],
    } ) || [];

    my $user = pop @$users;

    unless ( $user ) {
        $users = CTX->lookup_object('user')->fetch_group( {
            from => ['sys_user', 'dicole_domain_user'],
            where => 'email = ? AND domain_id = ? AND sys_user.user_id = dicole_domain_user.user_id',
            value => [ $login, $domain_id ],
        } ) || [];
        $user = pop @$users;
    }

    return $user;
}

sub fetch_user_by_login_in_current_domain {
    my ( $class, $login ) = @_;

    my $domain = Dicole::Utils::Domain->guess_current;
    die unless $domain;

    return $class->fetch_user_by_login_in_domain( $login, $domain->id );
}

sub fetch_user_by_login_and_pass_in_domain {
    my ( $class, $login, $pass, $domain_id ) = @_;

    my $user = $class->fetch_user_by_login_in_domain( $login, $domain_id );
    return ( $user && $user->check_password( $pass ) ) ? $user : undef;
}

sub fetch_domain_users_by_login {
    my ( $class, $login ) = @_;

    return {} unless $login;

    # first by email, second by login_name, login_name overrides.
    my $login_users = CTX->lookup_object('user')->fetch_group({
        where => 'login_name = ?',
        value => [ $login ],
    });

    my $email_users = CTX->lookup_object('user')->fetch_group({
        where => 'email = ?',
        value => [ $login ],
    });

    my $dus = CTX->lookup_object('dicole_domain_user')->fetch_group({
        where => Dicole::Utils::SQL->column_in( user_id => [ map { $_->id } ( @$email_users, @$login_users ) ] ),
    });

    my %ud_lookup = ();
    for my $du ( @$dus ) {
        push @{ $ud_lookup{ $du->user_id } }, $du->domain_id;
    }

    my %du_lookup = ();
    for my $user ( @$login_users, @$email_users ) {
        for my $domain_id ( @{ $ud_lookup{ $user->id } || [] } ) {
            $du_lookup{ $domain_id } ||= $user;
        }
    }

    return \%du_lookup;
}

sub domains {
    my ( $class, $user ) = @_;

    my $dus = CTX->lookup_object('dicole_domain_user')->fetch_group( {
        where => 'user_id = ?',
        value => [ $class->ensure_id( $user ) ],
    } );

    return [ map { $_->domain_id } @$dus ];
}

sub belongs_to_domain {
    my ( $class, $user, $domain_id ) = @_;

    return 1 unless $domain_id;

    my $domains = $class->domains( $user );
    for ( @$domains ) {
        return 1 if $_ == $domain_id;
    }
    return 0;
}

sub is_developer {
    my ($class, $user, $domain_id) = @_;

    return unless CTX->request and CTX->request->auth_user_id;

    return eval { $class->get_domain_note($user || CTX->request->auth_user, Dicole::Utils::Domain->guess_current_id( $domain_id ), 'developer') };
}

1;
