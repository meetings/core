package Dicole::Utils::Mail;
use strict;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::Utils::User;
use MIME::Base64;
use Email::Address;
use Dicole::Utils::Localization;

sub init_smtp {
    my ( $class, $smtp_host ) = @_;

    $smtp_host ||= OpenInteract2::Util->_get_smtp_host( {} );

#    MIME::Lite->send( 'smtp', $smtp_host, Timeout => 10 );

    return 1;
}

sub send {
    my ( $class, %p ) = @_;

    my $p = {
        user => undef,
        user_id => undef,
        to => undef,

        from => undef,
        from_user => undef,
        from_user_id => undef,
        reply_to => undef,
        subject => undef,
        text => undef,
        html => undef,
        domain_id => undef,
        %p,
    };

    my $domain_id = Dicole::Utils::Domain->guess_current_id( $p{domain_id} );

    my $user = $p->{user} || $p->{user_id};
    if ( $user ) {
        # Just return as you would have sent the mail in case of disabled users for now..
        # TODO: Later this should probably die and be handled somehow.
        $user = Dicole::Utils::User->ensure_object( $user );
        return undef if $user->login_disabled;
        return undef if ! $user->email;

        if ( $domain_id ) {
            my $notes = Dicole::Utils::User->notes_data( $user );
            return undef if $notes->{$domain_id}->{user_disabled};
        }

        my $email = eval { Dicole::Utils::User->email_with_name( $user ) };
        if ( $domain_id && $p->{ics} && ! $p->{disable_ics_attachment} ) {
            my $notes = Dicole::Utils::User->notes_data( $user );
            my $ics_email = $notes->{$domain_id}->{ics_email};
            $email = $ics_email if $ics_email;
        }
        die unless $email;

        $p->{to} = $email;
    }

    unless ( $p->{no_init_smtp} ) {
        $class->init_smtp( $p->{smtp_host} );
    }

    if ( ! $p->{from} ) {
        my $notify_email = $class->get_domain_notify_email( $domain_id );
        $p->{from} = $notify_email if $notify_email;
    }

    my $from_user = $p->{from_user} || $p->{from_user_id};
    if ( $from_user ) {
        $from_user = Dicole::Utils::User->ensure_object( $from_user );
        if ( $from_user ) {
            my $ao = $class->string_to_address_object( $p->{from} );
            my $phrase = Dicole::Utils::User->name( $from_user ) . ' via ' . Dicole::Utils::Text->ensure_utf8( $ao->phrase );
            $ao->phrase( Dicole::Utils::Text->ensure_internal( $phrase ) );
            $p->{from} = Dicole::Utils::Text->ensure_utf8( $ao->format );
        }
    }

    for my $type ( qw/ from to reply_to / ) {
        next unless $p->{ $type };
        $p->{ $type . '_original' } = $p->{ $type };
        my $aos = $class->string_to_address_objects( $p->{ $type } );

        my @new = ();
        for my $ao ( @$aos ) {
            my $new = '';
            if ( my $phrase = $ao->phrase ) {
                $phrase =~ s/\@/-at-/g;
                $new .= "=?UTF-8?B?" . MIME::Base64::encode_base64( Dicole::Utils::Text->ensure_utf8( $phrase ), "") . "?= ";
                $new .= '<' . Dicole::Utils::Text->ensure_utf8( $ao->address ) . '>';
            }
            else {
                $new .= Dicole::Utils::Text->ensure_utf8( $ao->address );
            }
            $p->{ $type } = $new;
            push @new, $new;
        }
        $p->{ $type } = join ";", @new;
    }

    my $container = MIME::Lite->new(
        OpenInteract2::Util->_build_header_info( {
            $p->{from} ? ( from => $p->{from} ) : (),
            to => $p->{to},
            subject => "=?UTF-8?B?" . MIME::Base64::encode_base64($p->{subject}, "") . "?=",
        } ),
        $p->{reply_to} ? ( 'Reply-To' => $p->{reply_to} ) : (),
        Type => $p->{ics} ? 'multipart/mixed' : 'multipart/alternative',
    );

    my $msg = $p->{ics} ? MIME::Lite->new(
        Type => 'multipart/alternative',
    ) : $container;

    $msg->attr( 'content-type.charset' => 'utf-8' );

    $msg->attach(
        Type => 'text/plain; charset="utf-8"',
        Data => $p->{text},
        Encoding => 'quoted-printable',
    ) if $p->{text} && ! $p->{disable_text};

    $msg->attach(
        Type => 'text/html; charset="utf-8"',
        Data => $p->{html},
        Encoding => 'quoted-printable',
    ) if $p->{html} && ! $p->{disable_html};

    if ( $p->{ics} ) {
        $msg->attach(
            'Content-Type' => 'text/calendar; charset="UTF-8"; method=REQUEST',
            Data => $p->{ics},
        );

        $container->attach( $msg );

        $container->attach(
            Type => 'application/ics; name="invite.ics"',
            Disposition => 'attachment; filename="invite.ics"',
            Data => $p->{ics},
        ) if ! $p->{disable_ics_attachment};
    }

    my $from_ao = $class->string_to_address_object( $container->get('From') );

    if ( ! $container->send_by_sendmail( FromSender => $from_ao->address ) ) {
        get_logger(LOG_APP)->error("Error sending mail: $!");
        die "Cannot send message: $!";
    }
    else {
        eval { CTX->lookup_object('sent_email')->new( {
            sent_date => time,
            domain_id => $domain_id,
            to_email => $p->{to_original} || '',
            from_email => $p->{from_original} || '',
            reply_email => $p->{reply_to_original} || '',
            subject => $p->{subject} || '',
            raw_data => $container->as_string,
            to_user => $user ? Dicole::Utils::User->ensure_id( $user ) : 0,
            from_user => $from_user ? Dicole::Utils::User->ensure_id( $from_user ) : 0,
        } )->save };
    }
}

# deprecated. just use send with user or user_id param which will override "to"
sub send_to_user {
    my ( $self, %p ) = @_;

    $self->send( %p );
}

sub send_localized_template_mail {
    my ( $self, %p ) = @_;

    return $self->send( %p, %{ $self->localized_template_mail_params( %p ) } );
}

sub send_nlocalized_template_mail {
    my ( $self, %p ) = @_;

    return $self->send( %p, %{ $self->localized_template_mail_params( ( %p, use_nlocalized => 1 ) ) } );
}

my $mail_cache = {};

sub nmail_template_for_key {
    my ( $self, $template_key ) = @_;

    return $mail_cache->{ $template_key } if $mail_cache->{ $template_key };

    my $file = $template_key;
    $file =~ s/_template/.tmpl/;
    my $full_file = CTX->repository->fetch_package( "dicole_meetings" )->directory . '/template/mail/' . $file;

    return $mail_cache->{ $template_key } ||= `cat $full_file`;
}

sub localized_template_mail_params {
    my ( $self, %p ) = @_;

    my $p = {
        language_handle => undef,
        lang => undef,
        domain_id => undef,
        partner_id => undef,
        group_id => undef,

        template_key_base => undef,

        subject_template_key => undef,
        html_template_key => undef,
        text_template_key => undef,

        override_subject => undef,

        template_params => {},
        %p
    };

    my %mail_params = ();
    for my $target ( qw/ subject text html / ) {
        my $template_key = $p->{ $target . '_template_key'};
        $template_key ||= $p->{template_key_base} . '_' . $target . '_template';
        my $template = '';
        if ( $p{use_nlocalized} ) {
            $template = $self->nmail_template_for_key( $template_key );
        }
        else {
            $template = Dicole::Utils::Localization->translate( { %$p }, $template_key );
        }

        if ( $template && $template ne $template_key ) {
            my $params = { "in_$target" => 1, %{ $p->{template_params} } };
            $mail_params{ $target } = Dicole::Utils::Template->process( $template, $params, { action => $self, lang => $p->{lang}, user => $p->{user}, user_id => $p->{user_id}, ampm => $p->{ampm} } );
            if ( $mail_params{ $target } =~ /^can ?not process template/i ) {
                use Data::Dumper;
                my $error_params = { %$params };
                delete $error_params->{OI};
                get_logger(LOG_APP)->error( Data::Dumper::Dumper( [ $template, $error_params, $mail_params{ $target }, \%p ] ) );

                $mail_params{ $target } = "Unfortunately we encountered a problem while sending this email. An automatic notification of this has been sent to us and we will inspect this as soon as possible!";
            }
        }
    }

    if ( $p{override_subject} ) {
        $mail_params{subject} = $p{override_subject};
    }

    return \%mail_params;
}

sub send_template_mail_to_users {
    my ( $self, %p ) = @_;

    return unless @{ $p{users} };

    my $cg = CTX->content_generator('TT');

    my %mail_params = ();
    for my $target ( qw/ subject text html / ) {
        my $template = $target . '_template';
        if ( $p{ $template } ) {
            $mail_params{ $target } = $cg->generate(
                {}, { "in_$target" => 1,  %{ $p{template_params} } }, { name => $p{ $template } },
            );
        }
    }

    $self->send_to_user(
        user => $_,
        %mail_params,
    ) for @{ $p{users} };
}

sub get_domain_notify_email {
    my ( $class, $domain_or_id ) = @_;

    my $tool = Dicole::Utils::Domain->guess_current_settings_tool( $domain_or_id );

    my $notify_email = Dicole::Settings->fetch_single_setting(
        tool => $tool,
        attribute => 'domain_notify_email',
    );

    return $notify_email if $notify_email;
    return undef;
}

sub string_to_address {
    my ( $class, $email_string ) = @_;

    return shift @{ $class->string_to_addresses( $email_string ) };
}

sub string_to_addresses {
    my ( $class, $email_string ) = @_;

    return [ map { Dicole::Utils::Text->ensure_utf8( $_->address ) } @{ $class->string_to_address_objects( $email_string ) } ];
}

sub string_to_full_addresses {
    my ( $class, $email_string ) = @_;

    return [ map { Dicole::Utils::Text->ensure_utf8( $_->original ) } @{ $class->string_to_address_objects( $email_string ) } ];
}

sub string_to_address_object {
    my ( $class, $email_string ) = @_;

    return shift @{ $class->string_to_address_objects( $email_string ) };
}

sub string_to_address_objects {
    my ( $class, $email_string ) = @_;

    return [ Email::Address->parse( Dicole::Utils::Text->ensure_internal( $email_string ) ) ];
}

sub form_email_string {
    my ( $class, $email, $name ) = @_;

    my $address = $class->address_object_from_email_and_name( $email, $name );

    return Dicole::Utils::Text->ensure_utf8( $address->format );
}

sub address_object_from_email_and_name {
    my ( $class, $email, $name ) = @_;

    my $ao = $class->string_to_address_object( $email );

    if ( $name ) {
        $ao->phrase( Dicole::Utils::Text->ensure_internal( $name ) );
    }

    return $ao;
}

sub strip_quotes_and_sigs_from_br_html {
    my ( $self, $content ) = @_;

    my $tag          = qr,<\s*\w+\s*/?>,;
    my $quote        = qr,((>|&gt;|&#62;) ?)+,;
    my $br           = qr,<br\s*/>,;
    my $quote_header = qr,(?:^\s*On .+:|^\s*(\d+[\.\/\-]){2}\d+.*\&(\#60|lt)\;.*\@.*\&(\#62|gt)\;),i;

#    my $quote_header = qr,^On .+:($br)?\r?\n\s*$quote,i;
#    $content =~ s/$quote_header//;

    my @lines = split $br, $content;
    my @result;

    my $inside_quote = 0;
    for my $line (@lines) {
        last if $line =~ /^\s*($tag)?-- ($tag)?$/;
        if ( $line =~ /^\s*$quote/ ) {
            if ( ! $inside_quote ) {
                while ( @result ) {
                    my $last = pop @result;
                    unless ( $last =~ /^\s*$/ || $last =~ $quote_header ) {
                        push @result, $last;
                        last;
                    }
                }
            }
            $inside_quote = 1;
        }
        else {
            push @result, $line;
            $inside_quote = 0;
        }
    }

    my $result = join "<br />", grep /\S/, @result;

    return $result;
}

1;
