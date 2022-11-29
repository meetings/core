package Dicole::Security;

# $Id: Security.pm,v 1.32 2010-07-20 04:08:04 amv Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context qw( CTX );
use SPOPS::SQLInterface;
use Scalar::Util;
use Dicole::Cache;

use base qw( Exporter );

our $VERSION   = sprintf("%d.%02d", q$Revision: 1.32 $ =~ /(\d+)\.(\d+)/);

our @EXPORT_OK = qw(
    CHECK_YES CHECK_NO CHECK_UNDEF
    TARGET_USER TARGET_GROUP TARGET_SYSTEM TARGET_OBJECT
    RECEIVER_USER RECEIVER_GROUP RECEIVER_LOCAL RECEIVER_GLOBAL
);

our %EXPORT_TAGS = (
    check => [ qw( CHECK_YES CHECK_NO CHECK_UNDEF ) ] ,
    target => [ qw( TARGET_USER TARGET_GROUP TARGET_SYSTEM TARGET_OBJECT ) ] ,
    receiver => [ qw( RECEIVER_USER RECEIVER_GROUP
                      RECEIVER_LOCAL RECEIVER_GLOBAL ) ] ,
);

=pod

=head1 NAME

Dicole Security module

=head1 SYNOPSIS

First you must init a singleton object. In Dicole this is usually done
already in the Controller so you can skip this.

  Dicole::Security->init();

After that you can start to check rights like this:

  use Dicole::Security qw( :check );

  my $oi_module = __PACKAGE__ or "OI::Module::Name";
  my $id_string = "id_of_group_right";
  my $group_id = 1;

  # For current user
  my $SEC = Dicole::Security->new;
  # For user with id 13
  my $SEC = Dicole::Security->new( 13 );
  # For group with id 23
  my $SEC = Dicole::Security->new( 23, 'group' );

  do() if $SEC->check( $oi_module, $id_string, $group_id) == CHECK_YES;

  # following uses CTX->request->target_id as $group_id
  do_for_target() if $SEC->check( $oi_module, $id_string ) == CHECK_YES;

or with Dicole::Security::Checker for the current user

  use base qw( Dicole::Security::Checker );

  my ( $self ) = @_;

  my $id_string = "id_of_group_right";
  my $group_id = 1;

  # checks from module "ref $self" for CHECK_YES, returns 1/0
  do() if $self->chk_y($id_string, $group_id);

  # checks for CHECK_NO, returns 1/0
  do() if $self->mchk_n(__PACKAGE__, $id_string, $group_id);

If you want to check rights from other than the user
that is currently logged in, you should create a new object:

  my $sec = Dicole::Security->new( $user_id );
  do() if $sec->check( $oi_module, $id_string, $group_id) == CHECK_YES;

or with Dicole::Security::Checker

  my $checker = Dicole::Security::Checker->new( $user_id );
  do() if $checker->chk_y($id_string, $group_id);

=head1 DESCRIPTION

This is a class which handles the loading and checking the rights in Dicole.
It functions by gathering security data to a singleton object and
performing checks against that data. Some data general data is loaded
when the singleton object is initialized and some is loaded when the
securities are checked the first time.

=head1 INHERITS

L<Exporter|Exporter>

=head1 EXPORTABLE METHODS

    :check => [ qw( CHECK_YES CHECK_NO CHECK_UNDEF ) ] ,
    :target => [ qw( TARGET_USER TARGET_GROUP TARGET_SYSTEM ) ] ,
    :receiver => [ qw( RECEIVER_USER RECEIVER_GROUP
                      RECEIVER_LOCAL RECEIVER_GLOBAL ) ] ,

=cut

# "constants"

sub TARGET_USER     { return 1; };
sub TARGET_GROUP    { return 2; };
sub TARGET_SYSTEM   { return 3; };
sub TARGET_OBJECT   { return 4; };

sub RECEIVER_USER     { return 1; };
sub RECEIVER_GROUP    { return 2; };
sub RECEIVER_LOCAL    { return 3; };
sub RECEIVER_GLOBAL   { return 4; };

sub CHECK_YES   { return 1; };
sub CHECK_NO    { return 2; };
sub CHECK_UNDEF { return 3; };

sub TARGET_NAMES {
    return {
        TARGET_USER() => 'user',
        TARGET_GROUP() => 'group',
        TARGET_SYSTEM() => 'system',
        TARGET_OBJECT() => 'object',
    };
}

my $SEC;

=pod

=head1 CLASS METHODS

=head2 new( [INT] )

Param: User id of the user whose securities are checked through
this object. Defaults to CTX->request->auth_user_id if the
user is logged in and 0 (check only global rights) if not.

Creates a new Dicole::Security object for checking
given users rights. This function also inits the singleton
object if it has not been initialized for the current
OpenInteract2 request.

=cut

sub new {
    my ( $class, $id, $type ) = @_;
    
    # Init if instance not found or was initialized during a different
    # request. This way people using the object way should not have to
    # worry about initializing the object separately.
    
    $class->init if ! $SEC || ! $SEC->{levels_by_module} || ! $SEC->{levels_by_id}|| ! $SEC->{rights};
    $class->init if CTX->request && $SEC->{initialized_for_request} && 
        Scalar::Util::refaddr( CTX->request ) !=
        Scalar::Util::refaddr( $SEC->{initialized_for_request} );

    my $self = bless {}, $class;

    if ( ! $type && ! $id ) {
        if ( CTX->controller && CTX->controller->initial_action && CTX->controller->initial_action->current_rights ) {
            $type = CTX->controller->initial_action->current_rights->{type};
            $id = CTX->controller->initial_action->current_rights->{id};
        }
    }

    if ( $type eq 'global' ) {
        $id = 0;
    }
    elsif ( $type eq 'group' ) {
        $id ||= 0;
    }
    else {
        $type = 'user';
        unless ( defined( $id ) ) {
            $id = CTX->request->auth_is_logged_in ?
                CTX->request->auth_user_id : 0;
        }
    }

    $self->{type} = $type;
    $self->{id} = $id;

    return $self;
}

=head2 init

Inits a new singleton instance and fetches the security levels
from the database. This clears all previous security
data which is being stored at the singleton object.

=cut

sub init {
    my ( $class ) = @_;

    # to make sure no circular references are left hanging:
    delete $SEC->{initialized_for_request} if $SEC;
    
    $SEC = {};
    $SEC->{rights} = {};
    $class->_init_levels;

    $SEC->{initialized_for_request} = CTX->request;

    return $SEC;
}

#
# fetch security level data from database and form two hashes
# with modules/ids as keys from it.
#

sub _init_levels {
    my ( $class ) = @_;

    my $level_stash = Dicole::Cache->fetch_or_store( 'security_level_stash', sub {

        Dicole::RuntimeLogger->rlog('Security init levels');

        my $ls = { levels_by_module => {}, levels_by_id => {} };
        my $levels = CTX->lookup_object('dicole_security_level')->fetch_group || [];

        my $targets = TARGET_NAMES();

        foreach my $level (@$levels) {

            my $full_string = $level->{oi_module} . '::' . $level->{id_string};
            my $stamp = $full_string . '/' . $targets->{ $level->{target_type} };
            my $new = {
                level_id => $level->{level_id},
                default => $level->{default},
                assign_right => $level->{assign_right},
                target_type => $level->{target_type},
                stamp => $stamp,
            };

            $ls->{levels_by_module}{ $level->{oi_module} }{ $level->{id_string} } = $new;
            $ls->{levels_by_id}{ $level->{level_id} } = $new;
        }

        Dicole::RuntimeLogger->rlog('Security init levels');

        return $ls;

    }, { no_domain_id => 1, no_group_id => 1, expires => 60*60 } );

    $SEC->{levels_by_module} = $level_stash->{levels_by_module};
    $SEC->{levels_by_id} = $level_stash->{levels_by_id};

}

=pod

=head2 instance

Returns the singletonrights hash and inits it if necessary.

=cut

sub instance {
    my ( $class ) = @_;
    return $SEC if $SEC;
    return $class->init;
}

=pod

=head1 OBJECT METHODS

=head2 check ( STRING, STRING, INTEGER )

checks the right status for module, security level and target id.
returns one of CHECK_NO, CHECK_YES, CHECK_UNDEF.


=cut

sub check {
    my ( $self, $module, $string, $id ) = @_;

    my $SEC = $self->instance;

    my $level = $SEC->{levels_by_module}{$module}{$string};

    return CHECK_UNDEF if !$level;

    my $tree = $self->rights_lookup_tree;
    my $rights = $tree->{ $level->{level_id} };

    $id ||= 0;

    return CHECK_NO if $rights->{$id} == CHECK_NO ||
                         $rights->{0} == CHECK_NO;
    return CHECK_YES if $rights->{$id} == CHECK_YES ||
                          $rights->{0} == CHECK_YES;

    return CHECK_UNDEF;
}

sub rights_lookup_tree {
    my ( $self ) = @_;

    $self->_build_rights;

    return $self->instance->{rights}{ $self->{type} }{ $self->{id} };
}

sub level_by_id {
    my ( $class, $id ) = @_;

    return $class->security_levels_by_id->{ $id };

}

sub level_by_string {
    my ( $class, $string ) = @_;

    my ( $mod, $id ) = $string =~ /(.*)\:\:(.*)/;

    return $class->security_levels_by_module->{ $mod }{ $id };
}

sub serialize_secure {
    my ( $class, $secure, $targets ) = @_;

    my @options = split /\s*,\s*/, $secure;
    my @result = ();
    for my $option ( @options ) {
        my @combination = split /\s*\+\s*/, $option;
        push @result, @{ $class->serialized_level_combinations_for_level_combination( \@combination, $targets ) };
    }

    return \@result;
}

sub serialized_levels_for_level {
    my ( $class, $level, $targets ) = @_;

    if ( ! ref ($level) ) {
        $level = $class->level_by_string( $level );
    }

    return () unless $level;

    my @targets = ( 0 );
    my @domains = ( 0 );

    $targets->{object} ||= $targets->{object_id};
    $targets->{user} ||= $targets->{user_id};
    $targets->{group} ||= $targets->{group_id};
    $targets->{domain} ||= $targets->{domain_id};

    push @targets, $targets->{ TARGET_NAMES()->{ $level->{target_type} } } || ();
    push @domains, $targets->{domain} || ();

    my @secs = ();

    for my $t ( @targets ) {
        for my $d ( @domains ) {
            push @secs, join( ":", ( $level->{stamp}, $d, $t ) );
        }
    }

    return \@secs;
}

sub serialized_level_combinations_for_level_combination {
    my ( $class, $level_combination, $targets ) = @_;

    my @options = ();
    for my $level ( @$level_combination ) {
        push @options, $class->serialized_levels_for_level( $level, $targets );
    }

    return $class->_rec_combinations( [], \@options );

}

sub _rec_combinations {
    my ( $class, $base, $options ) = @_;
    if ( ! scalar( @$options ) ) {
        return [ $base ];
    }
    else {
        my @return = ();
        my @new_options = @$options;
        my $current = shift( @new_options );
        for my $option_fragment ( @$current ) {
            my $new_base = [ @$base, $option_fragment ];
            push @return, @{ $class->_rec_combinations( $new_base, \@new_options ) };
        }
        return \@return;
    }
}


sub security_levels_by_id {
    my ( $class ) = @_;

    return $class->instance->{levels_by_id};
}

sub security_levels_by_module {
    my ( $class ) = @_;

    return $class->instance->{levels_by_module};
}

=pod

=head2 target_type_for_level( STRING, STRING )

returns target type of the level specified by module and security level.

=cut
sub target_type_for_level {
    my ( $class, $module, $string ) = @_;

    my $level = $class->instance->{levels_by_module}{$module}{$string};
    return undef if !$level;

    return $level->{target_type};
}
=pod

=head2 collection_by_idstring( STRING )

returns the collection with given idstring.

=cut

# TODO: This should _really_ be put in the collection SPOPS class..

sub collection_by_idstring {
    my ( $self, $idstring ) = @_;
    
    my $colls = CTX->lookup_object( 'dicole_security_collection' )->
        fetch_group( {
            where => 'idstring = ?',
            value => [ $idstring ],
            limit => 1,
    } ) || [];

    return $colls->[0];
}

=pod

=head2 collection_id_by_idstring( STRING )

returns the id of the collection with given idstring.

=cut

sub collection_id_by_idstring {
    my ( $self, $idstring ) = @_;
    
    my $coll = $self->collection_by_idstring( $idstring );

    return $coll ? $coll->id : die "No collection for '$idstring'";
}

#
# This function will gather authorized users rights and place
# them into the {rights} variable.
# Later this will also generate missing caches on the way.
# Now it doesn't implement caching at all ;-)
#

sub _build_rights {
    my ($self) = @_;

    return if $SEC->{rights}{ $self->{type} }{ $self->{id} };

    Dicole::RuntimeLogger->rlog('Security tree building');
 
    # fetch first public rights, override them with global right,
    # them with groups' rights and them with personal rights.

    my $rights = {};

    if ( $self->{id} ) {
        
        my @hashes = (
            $self->_fetch_global_rights,
            $self->_fetch_local_rights
        );
        
        if ( $self->{type} eq 'user' ) {
            push @hashes, $self->_fetch_group_rights_for_user( $self->{id} );
            push @hashes, $self->_fetch_user_rights( $self->{id} );
        }
        elsif ( $self->{type} eq 'group' ) {
            push @hashes, $self->_fetch_group_rights( $self->{id} );
        }
        
        my %combined_keys = ();
        for my $h ( @hashes ) {
            $combined_keys{ $_ } = () for ( keys %$h );
        }
        
        for my $key ( keys %combined_keys ) {
            $_->{$key} ||= {} for @hashes;
            $rights->{$key} = { map { %{ $_->{$key} } } @hashes };
        }
    }
    else {
        $rights = $self->_fetch_global_rights;
    }

    $SEC->{rights}{ $self->{type} }{ $self->{id} } = $rights;

    Dicole::RuntimeLogger->rlog('Security tree building');

##    get_logger( LOG_ACTION )->error( Data::Dumper::Dumper( $rights ) );

    return 1;
}

#
# returns reference to a hash which contains
# all of the users personal rights.
#

sub _fetch_user_rights {

    my ($self, $uid) = @_;

    my $iter = SPOPS::SQLInterface->db_select({
            select => [
                's.target_user_id',
                's.target_group_id',
                'l.level_id',
                'c.allowed',
                's.target_object_id',
            ],
            from   => [

                'dicole_security s',
                'dicole_security_col_lev l',
                'dicole_security_collection c',
            ],
            where  => 's.receiver_user_id = ?' .
                      ' AND s.collection_id = l.collection_id ' .
                      ' AND s.collection_id = c.collection_id',
            value => [ $uid ],
            db     => CTX->datasource( CTX->lookup_system_datasource_name ),
            return => 'sth',
    });

    # collect the rights one by one to a hash which will be returned

    my $rights = {};
    my $CHECK_NO = CHECK_NO;

    while (my $r = $iter->fetchrow_arrayref()) {

        my $target_id = $r->[4] || $r->[0] || $r->[1];
        
        next if $rights->{ $r->[2] }{ $target_id } == $CHECK_NO;
        
        $rights->{ $r->[2] }{ $target_id } = $r->[3];
    }


    return $rights;
}

#
# returns reference to a hash which contains
# all of the local rights.
#

sub _fetch_local_rights {
    my ($self) = @_;
    return $self->_fetch_shared_rights( RECEIVER_LOCAL );
}

sub _fetch_global_rights {
    my ($self) = @_;
    return $self->_fetch_shared_rights( RECEIVER_GLOBAL );
}

sub _fetch_shared_rights {

    my ($self, $receiver_type) = @_;

    my $iter = SPOPS::SQLInterface->db_select({
            select => [

                's.target_user_id',
                's.target_group_id',
                'l.level_id',
                'c.allowed',
                's.target_object_id',
            ],
            from   => [

                'dicole_security s',
                'dicole_security_col_lev l',
                'dicole_security_collection c',
            ],
            where  => 's.receiver_group_id = 0 AND s.receiver_user_id = 0' .
                      ' AND s.receiver_type = ?' .
                      ' AND s.collection_id = l.collection_id ' .
                      ' AND s.collection_id = c.collection_id ',
            value => [ $receiver_type ],
            db     => CTX->datasource( CTX->lookup_system_datasource_name ),
            return => 'sth',
    });

    # collect the rights one by one to a hash which will be returned

    my $rights = {};
    my $CHECK_NO = CHECK_NO;

    while (my $r = $iter->fetchrow_arrayref()) {

        my $target_id = $r->[4] || $r->[0] || $r->[1];
        
        next if $rights->{ $r->[2] }{ $target_id } == $CHECK_NO;
        
        $rights->{ $r->[2] }{ $target_id } = $r->[3];
    }


    return $rights;
}

#
# returns  reference to a hash which contains
# all of the users groups' rights.
#

sub _fetch_group_rights_for_user {

    my ($self, $uid) = @_;

    my $ids = [];

    if ( $uid == CTX->request->auth_user_id ) {
        $ids = CTX->request->auth_user_groups_ids || [];
    }
    else {
        my $iter = SPOPS::SQLInterface->db_select({
            select => [
                'groups_id',
            ],
            from   => [
                'dicole_group_user',
            ],
            where  => 'user_id = ?',
            value => [ $uid ],
            db     => CTX->datasource( CTX->lookup_system_datasource_name ),
            return => 'sth',
        });

        while (my $r = $iter->fetchrow_arrayref()) {
            push @$ids, $r->[0];
        }
    }

    return {} if !scalar @$ids;

    return $self->_fetch_rights_for_groups( $ids );
}

sub _fetch_group_rights {
    my ($self, $gid) = @_;

    return $self->_fetch_rights_for_groups( [ $gid ] );
}

sub _fetch_rights_for_groups {

    my ($self, $gids) = @_;

    my $iter = SPOPS::SQLInterface->db_select({
            select => [
                's.target_user_id',
                's.target_group_id',
                'l.level_id',
                'c.allowed',
                's.target_object_id',
            ],
            from   => [

                'dicole_security s',
                'dicole_security_col_lev l',
                'dicole_security_collection c',
            ],
            where  => Dicole::Utils::SQL->column_in(
                        's.receiver_group_id', $gids
                      )  .
                      ' AND s.collection_id = l.collection_id ' .
                      ' AND s.collection_id = c.collection_id ',
            db     => CTX->datasource( CTX->lookup_system_datasource_name ),
            return => 'sth',
    });

    my $CHECK_NO = CHECK_NO;
    my $group_sec = {};

    while (my $r = $iter->fetchrow_arrayref()) {

        my $target_id = $r->[4] || $r->[0] || $r->[1];

        next if $group_sec->{ $r->[2] }{ $target_id } == $CHECK_NO;

        $group_sec->{ $r->[2] }{ $target_id } = $r->[3];
    }

    return $group_sec;
}

#
# pushes rights from the $source rights tree to the
# $target rights tree.
#
# this is not used before we have caching..
# .. will it ever be? it is slow i guess...
#
#

sub _push_rights {

    my ($self, $added, $source, $override) = @_;

    foreach my $id (keys %{$source}) {

        foreach my $target (keys %{$source->{$id}}) {

            if ($override || $added->{$id}{$target} != CHECK_NO) {

                $added->{$id}{$target} = $source->{$id}{$target};
            }
        }
    }

    return 1;
}

1;

__END__

=head1 AUTHOR

Antti Vähäkotamäki E<lt>antti@ionstream.fiE<gt>,

=head1 COPYRIGHT AND LICENSE

 Copyright (c) 2004 Ionstream Oy / Dicole
 http://www.dicole.com

Licence version: MPL 1.1/GPL 2.0/LGPL 2.1

The contents of this file are subject to the Mozilla Public License Version
1.1 (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
for the specific language governing rights and limitations under the
License.

The Original Code is Dicole Code.

The Initial Developer of the Original Code is Ionstream Oy (info@dicole.com).
Portions created by the Initial Developer are Copyright (C) 2004
the Initial Developer. All Rights Reserved.

Contributor(s):

Alternatively, the contents of this file may be used under the terms of
either the GNU General Public License Version 2 or later (the "GPL"), or
the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
in which case the provisions of the GPL or the LGPL are applicable instead
of those above. If you wish to allow use of your version of this file only
under the terms of either the GPL or the LGPL, and not to allow others to
use your version of this file under the terms of the MPL, indicate your
decision by deleting the provisions above and replace them with the notice
and other provisions required by the GPL or the LGPL. If you do not delete
the provisions above, a recipient may use your version of this file under
the terms of any one of the MPL, the GPL or the LGPL.

=cut

1;

