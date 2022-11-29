package OpenInteract2::Action::External;

use strict;

use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::Tool;
use Dicole::URL;
use Dicole::Content::Iframe;
use Dicole::Security::Encryption;

our $VERSION = sprintf( "%d.%02d", q$Revision: 1.15 $ =~ /(\d+)\.(\d+)/ );

# Here's an example of the simplest response...

sub _fetch_source {
    my ( $self ) = @_;

    my $object = CTX->lookup_object('externalsource');

    my $source = $object->fetch_group(
        { where => 'name = ?', value => [ CTX->request->task_name ] }
    )->[0];

    return "No such source found!" if !$source;

    if ( $source->{external_type} == 1 && $source->{users_ids} ) {
        return "Access denied. The tool is not available for this user!"
            unless scalar(
                grep { $_ == CTX->request->auth_user_id }
                    split /\s*,\s*/, $source->{users_ids}
            );
    }
    elsif ( $source->{external_type} == 2 && $source->{groups_ids} ) {
        return "Access denied. The tool is not available for this group!"
            unless grep { $_ == CTX->request->target_id }
                    split /,/, $source->{groups_ids};
        return "Access denied. The tool is not available for this group!"
            unless grep { $_ == CTX->request->target_id }
                    @{ CTX->request->auth_user_groups_ids };
    }
    elsif ( $source->{external_type} == 3 ) {
        return "Access denied. This tool is only available for administrators!"
            unless $self->mchk_y( 'OpenInteract2::Action::DicoleSecurity', 'admin_access' );
    }

    return "You must be logged in to access external tools."
        unless CTX->request->auth_is_logged_in;

    return $source;
}

sub _get_custom_object {
    my ( $self, $source ) = @_;
    my $object = CTX->lookup_object( $source->{custom_object} );
    my $obj = {};
    my $user_id = CTX->request->auth_user_id;
    my $target_id = CTX->request->target_id;
    my $custom_obj_id = $source->{custom_obj_id};
    my $custom_where = $source->{custom_where};
    if ( $custom_obj_id !~ /^\d+$/ ) {
        if ( $custom_obj_id eq 'user_id' ) {
            $custom_obj_id = $user_id;
        }
        elsif ( $custom_obj_id eq 'target_id' ) {
            $custom_obj_id = $target_id;
        }
        else {
            die "custom_obj_id not defined. Use user_id, target_id or a number.";
        }
        $obj = $object->fetch( $custom_obj_id, { skip_security => 1 } );
    }
    elsif ( $custom_where ) {
        $custom_where =~ s/\%\%user_id\%\%/$user_id/g;
        $custom_where =~ s/\%\%target_id\%\%/$target_id/g;
        $obj = $object->fetch_group( {
            where => $custom_where,
            skip_security => 1
        } )->[0];
    }
    return $obj || {};
}

sub _use_custom_object {
    my ( $self, $source, $url, $obj ) = @_;
    $obj ||= $self->_get_custom_object( $source );
    foreach my $field ( split /,/, $source->{custom_fields} ) {
        my $value = $obj->{$field};
        $url =~ s/\%\%$field\%\%/$value/g;
    }
    return $url;
}

sub handler {
    my ( $self, $p ) = @_;

    my $source = $self->_fetch_source;
    return $source unless ref $source;
    
    if ( $source->{navigation_type} eq 'group_tool' && $self->param('target_type') ne 'group' ) {
        return $self->redirect( $self->derive_url( action => 'group_external' ) );
    }

    $self->param( 'active_navigation', $source->{navid} );
    $self->param( 'navigation_type', $source->{navigation_type} );

    my $url = $source->{url};

    if ( $source->{request} eq 'post' ) {
        $url = Dicole::URL->create_from_current(
            action => ( $self->param('target_type') eq 'group' ) ?
                'group_external_post' : 'external_post',
            task => CTX->request->task_name
        );
    }
    else {
        # Use currently authorized login password if configuration specifies
        if ( $source->{use_login_pass} ) {
            my $sec = Dicole::Security::Encryption->new;
            $sec->use_dynamic( 1 );
            my $pass = $sec->decrypt(
                CTX->request->session->{login_password}
            );
             if ( $url =~ /\@/ ) {
                $url =~ s/(:).*?(\@)/$1$pass$2/;
            }

            if ( $source->{pass_field} && $url =~ /(\?|\&)$source->{pass_field}=/ ) {
                $url =~ s/(\?|\&)$source->{pass_field}(=)/$1$source->{pass_field}$2$pass/;
            }
            if ( $source->{pass_field} && $url =~ /\%\%$source->{pass_field}\%\%/ ) {
                $url =~ s/\%\%$source->{pass_field}\%\%/$pass/g;
            }
        }

        # Use currently authorized login name if configuration specifies
        if ( $source->{use_login_user} ) {
            my $username = CTX->request->auth_user->{login_name};
            if ( $url =~ /\@/ ) {
                $url =~ s{(//).*?(:.*?\@)}{$1$username$2};
            }
            if ( $source->{user_field} && $url =~ /(\?|\&)$source->{user_field}=/ ) {
                $url =~ s/(\?|\&)$source->{user_field}(=)/$1$source->{user_field}$2$username/;
            }
            if ( $source->{user_field} && $url =~ /\%\%$source->{user_field}\%\%/ ) {
                $url =~ s/\%\%$source->{user_field}\%\%/$username/g;
            }
        }

        if ( $source->{custom_object} ) {
            $url = $self->_use_custom_object( $source, $url );
        }
    }

    $self->tool( Dicole::Tool->new(
        action => $self,
        no_tool_tabs => 1,
        structure => 'custom',
        custom_content => Dicole::Content::Iframe->new( url => $url )
    ) );

    return $self->generate_tool_content;
}

1;

__END__

=head1 NAME

OpenInteract2::Action::External - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS
