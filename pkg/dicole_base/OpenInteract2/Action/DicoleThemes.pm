package OpenInteract2::Action::DicoleThemes;

# $Id: DicoleThemes.pm,v 1.6 2009-01-07 14:42:32 amv Exp $

use strict;

use base ( qw(
    Dicole::Action::Common::List
    Dicole::Action::Common::Show
    Dicole::Action::Common::Remove
) );

use Dicole::MessageHandler qw( :message );
use OpenInteract2::Context   qw( CTX );
use Dicole::URL;
use OpenInteract2::Package;
use Dicole::Generictool::FakeObject;
use OpenInteract2::Config::Ini;
use File::Spec::Functions    qw( :ALL );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

# Replace inherited methods in Common::Remove

sub _post_init_common_remove {
    my ( $self ) = @_;
    # Deleting default theme is not possible
    $self->gtool->Data->query_params( {
        where => 'default_theme != ?',
        value => [ 1 ]
    } );
}

sub _post_init_common_list {
    my ( $self ) = @_;

    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Upload' ),
        link  => Dicole::URL->create_from_current( task => 'upload' )
    );

}

sub _pre_remove {
    my ( $self, $ids ) = @_;
    foreach my $id ( keys %{ $ids } ) {
        my $theme = CTX->lookup_object( 'dicole_theme' )->fetch( $id );
        $self->_delete_theme( $theme->{ident} );
    }
    return 1;
}

#
# CTX->lookup_directory( 'package' )

# Deleting theme
sub _delete_theme {
    my ( $self, $pack ) = @_;

    eval {
        my $package = CTX->repository->fetch_package( $pack );
        $package->remove_files( CTX->lookup_directory( 'website' ) );
        CTX->repository->remove_package( $package );
    };
    if ( $@ ) {
        die "$@: Pack was: $pack";
    }
    else {
        return 1;
    }
}

sub _check_package_exists {
    my ( $self, $name, $version ) = @_;
    my $info = CTX->repository->get_package_info( $name );
    if ( $info && $info->{version} == $version ) {
        return 1;
    }
    return 0;
}

sub upload {
    my ( $self ) = @_;

    $self->_init_common_tool( {
        tool_config => { upload => 1 },
    } );

    $self->tool->Path->add( name => $self->_msg( 'Upload theme' ) );

    $self->gtool->fake_objects( [
        Dicole::Generictool::FakeObject->new(
            { id => 'upload_id' }
        )
    ] );
    
    my $package_file;
    if ( CTX->request->param( 'upload' ) ) {
        my $upload_obj = CTX->request->upload( 'theme_file' );
        $package_file = $upload_obj->tmp_name;
    }

    unless ( $package_file ) {
        return $self->_display_upload_form;
    }

    # Make sure we run the latest package repository
    CTX->repository->_clear_package_info;
    CTX->repository->_clear_package_cache;
    CTX->repository->_read_repository;

    my $package = eval { OpenInteract2::Package->new({
        package_file => $package_file
    }) };

    if ( $@ ) {
        $self->tool->add_message( MESSAGE_ERROR,
            $self->_msg( 'File is not a valid theme package!' )
        );
        return $self->_display_upload_form;
    }

    my $is_installed = $self->_check_package_exists(
        $package->name, $package->version
    );
    if ( $is_installed ) {
        $self->tool->add_message( MESSAGE_ERROR,
            $self->_msg( 'This theme version is already installed.' )
        );
        return $self->_display_upload_form;
    }

    my $prev_ver_package_dir = undef;
    # Store directory name of previous package for removal purposes
    if ( CTX->repository->get_package_info( $package->name ) ) {
        my $old_pack = CTX->repository->fetch_package( $package->name );
        $prev_ver_package_dir = rel2abs( $old_pack->directory );
    }

    my $full_package_name = $package->full_name;
    my $installed_package = eval {
        OpenInteract2::Package->install({
            package_file => $package_file,
            repository   => CTX->repository
        })
    };
    if ( $@ ) {
        my $err_msg = $@;
        # We need no stinking line numbers
        $err_msg =~ s{ at /.+$}{};
        $self->tool->add_message( MESSAGE_ERROR,
            $self->_msg( 'Error while installing theme: [_1]', $err_msg )
        );
        return $self->_display_upload_form;
    }
        
    my $inifile = File::Spec->catfile(
        CTX->repository->full_config_dir, $installed_package->name, 'theme.ini'
    );

    unless ( $inifile ) {
        $self->_delete_theme( $installed_package->name );
        $self->tool->add_message( MESSAGE_ERROR,
            $self->_msg( 'Unable to find conf/theme.ini in theme package [_1]', $installed_package->name )
        );
        return $self->_display_upload_form;
    }
        
    my $ini = OpenInteract2::Config::Ini->new( { filename => $inifile } );

    my $theme = eval { CTX->lookup_object( 'dicole_theme' )->fetch_group( {
        where => 'ident = ?',
        value => [ $installed_package->name ],
        limit => 1
    } )->[0] };
    $theme = CTX->lookup_object( 'dicole_theme' )->new unless ref $theme;

    my $parent_not_present = undef;
    if ( $ini->{theme}{parent_theme} ) {
        my $parent = eval { CTX->lookup_object( 'dicole_theme' )->fetch_group( {
            where => 'ident = ?',
            value => [ $ini->{theme}{parent_theme} ],
            limit => 1
        } )->[0] };
        if ( $@ || !ref( $parent ) ) {
            $parent_not_present = 1;
        }
    }

    if ( $parent_not_present ) {
        $self->_delete_theme( $installed_package->name );
        $self->tool->add_message( MESSAGE_ERROR,
        $self->_msg( 'This theme requires parent theme package [_1] which is not present.', $ini->{parent_theme} )
        );
        return $self->_display_upload_form;
    }

    $theme->{ident} = $installed_package->name;
    $theme->{description} = $installed_package->config->description;
    $theme->{version} = $installed_package->version;
    $theme->{author} = join ", ", $installed_package->config->author_names;

    foreach my $param ( qw( screenshot css_all css_aural name css_braille css_embossed
                    css_handheld css_print css_projection css_screen css_tty css_tv theme_images parent_theme ) ) {
        $theme->{$param} = $ini->{theme}{$param};
    }
    $theme->{modifyable} = 1 if $ini->{theme}{modifyable};
    $theme->save;

    # Remove previous version package directory if present
    if ( $prev_ver_package_dir ) {
        $installed_package->_remove_directory_tree( $prev_ver_package_dir );
    }

    $self->tool->add_message( MESSAGE_SUCCESS,
    $self->_msg( 'Installed version [_1] of theme [_2]', $installed_package->version, $ini->{name} )
    );
    return CTX->response->redirect(
        Dicole::URL->create_from_current( task => 'list' )
    );

}

sub _display_upload_form {
    my ( $self ) = @_;
    
    $self->gtool->add_bottom_button(
        name  => 'upload',
        value => $self->_msg( 'Upload' ),
    );

    $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Cancel' ),
        link  => Dicole::URL->create_from_current( task => 'list' )
    );

    # Create add form
    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Upload theme in ZIP format' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_add
    );

    return $self->generate_tool_content;
}

# Replace inherited methods in Common::Show

sub _pre_init_common_show {
    my ( $self ) = @_;
    $self->_config_tool_show( 'tab_override', 'list' );
    return $self->SUPER::_pre_init_common_show;
}

sub _common_buttons_show {
    my ( $self, $id ) = @_;

    $self->SUPER::_common_buttons_show( $id );

   $self->gtool->add_bottom_button(
        type  => 'link',
        value => $self->_msg( 'Set as default theme' ),
        link  => Dicole::URL->create_from_current(
            task => 'toggle_default',
            params => { id => $id }
        )
    );

}

# Toggles the wanted theme as default theme
sub toggle_default {
    my ( $self ) = @_;

    my $id = CTX->request->param( 'id' );

    my $themes = CTX->lookup_object( 'dicole_theme' )->fetch_group( {
        where => 'default_theme = ?',
        value => [ 1 ]
    } );

    foreach my $th ( @{ $themes } ) {
        $th->{default_theme} = 0;
        $th->save;
    }

    my $theme = CTX->lookup_object( 'dicole_theme' )->fetch( $id );
    $theme->{default_theme} = 1;
    $theme->save;

    return CTX->response->redirect( Dicole::URL->create_from_current(
        task => 'show',
        params => { id => $id }
    ) );
}

1;

__END__

=head1 NAME

OpenInteract2::Action::DicoleThemes - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS
