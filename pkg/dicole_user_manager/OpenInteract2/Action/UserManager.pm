package OpenInteract2::Action::UserManager;

use strict;

use base ( qw(
    OpenInteract2::Action::UserManagerCommon
    Dicole::Action::Common::List
    Dicole::Action::Common::Add
    Dicole::Action::Common::Edit
    Dicole::Action::Common::Show
    Dicole::Action::Common::Remove
    Dicole::Action::Common::Settings
) );

use Dicole::Generictool;
use Dicole::Generictool::Data;
use Dicole::Tool;
use Dicole::Files;
use Dicole::URL;
use Dicole::Security qw( :receiver :target :check );
use Dicole::Utility;
use Dicole::Pathutils;
use Dicole::MessageHandler qw( :message );
use DateTime::TimeZone;
use Dicole::Excel;
use DateTime;
#use Convert::Scalar;
use Template;
use SPOPS::Utility;
use Dicole::Utils::JSON;
use Spreadsheet::ParseExcel;
use IO::File;
use Dicole::Utils::User;

use OpenInteract2::Context   qw( CTX );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.107 $ =~ /(\d+)\.(\d+)/);

########################################
# Settings tab
########################################

sub _settings_config {
    my ( $self, $settings ) = @_;
    $settings->tool( 'user_manager' );
    $settings->user( 0 );
    $settings->group( 0 );
    $settings->global( 1 );
}


# TODO: How about generating an example Excel template for importing users?
# Importing new users from a file
sub import_users {
    my ( $self ) = @_;
    $self->_init_common_tool( {
        tool_config => { upload => 1 },
        class => 'user',
        skip_security => 1
    } );

    $self->tool->Path->add( name => $self->_msg( 'Import new users from an Excel sheet'
    ) );

    $self->gtool->add_bottom_button(
        name  => 'upload',
        value => $self->_msg( 'Upload' ),
    );

    if ( CTX->request->param( 'upload' ) ) {
        my ( $code, $message ) = $self->gtool->validate_and_save(
            $self->gtool->visible_fields, {
                clear_output => 1,
                no_save => 1,
            }
        );

        if ( $code ) {
            my $excel_file = CTX->request->upload( 'excel_file' );
            if ( ref( $excel_file ) ) {
                my $filehandle = IO::File->new_from_fd(
                    $excel_file->filehandle, 'r'
                );
                my ( $num_users, $failed ) = $self->_import_excel( $filehandle );

                if ( defined $num_users ) {
                    $message = $self->_msg( "[_1] user(s) imported.", $num_users );
                }
                else {
                    $code = MESSAGE_ERROR;
                    $message = $self->_msg( "Upload a valid Excel file." );
                }
                if ( $failed ) {
                    $code = MESSAGE_WARNING;
                    $message .= ' '
                        . $self->_msg( "The following rows failed: [_1]", $failed );
                }
            }
            else {
                $code = MESSAGE_ERROR;
                $message = $self->_msg( "Upload a valid Excel file." );
            }
        }
        unless ( $code ) {
            $message = $self->_msg( "Failed importing users: [_1]", $message );
        }

        $self->tool->add_message( $code, $message );
    }

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Upload Excel sheet' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_add
    );

    return $self->generate_tool_content;
}

sub ws_import_users {
    my ( $self ) = @_;
    $self->_init_common_tool( {
        tool_config => { upload => 1 },
        class => 'user',
        skip_security => 1
    } );

    $self->tool->Path->add( name => $self->_msg( 'Import new users from a Wanha Satama tab separated file'
    ) );

    $self->gtool->add_bottom_button(
        name  => 'upload',
        value => $self->_msg( 'Upload' ),
    );

    if ( CTX->request->param( 'upload' ) ) {
        my ( $code, $message ) = $self->gtool->validate_and_save(
            $self->gtool->visible_fields, {
                clear_output => 1,
                no_save => 1,
            }
        );

        if ( $code ) {
            my $excel_file = CTX->request->upload( 'excel_file' );
            if ( ref( $excel_file ) ) {
                my $filehandle = IO::File->new_from_fd(
                    $excel_file->filehandle, 'r'
                );
                my ( $num_users, $failed ) = $self->_import_ws( $filehandle );

                if ( defined $num_users ) {
                    $message = $self->_msg( "[_1] user(s) imported.", $num_users );
                }
                else {
                    $code = MESSAGE_ERROR;
                    $message = $self->_msg( "Upload a valid file." );
                }
                if ( $failed ) {
                    $code = MESSAGE_WARNING;
                    $message .= ' '
                        . $self->_msg( "The following rows failed: [_1]", $failed );
                }
            }
            else {
                $code = MESSAGE_ERROR;
                $message = $self->_msg( "Upload a valid file." );
            }
        }
        unless ( $code ) {
            $message = $self->_msg( "Failed importing users: [_1]", $message );
        }

        $self->tool->add_message( $code, $message );
    }

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg( 'Upload Wanha Satama user file' )
    );
    $self->tool->Container->box_at( 0, 0 )->add_content(
        $self->gtool->get_add
    );

    return $self->generate_tool_content;
}

sub download_example_excel {
    my ( $self ) = @_;
    $self->gtool( Dicole::Generictool->new(
        object => CTX->lookup_object( 'user' ),
        skip_security => 1,
        current_view => 'excel_fields',
    ) );
    $self->init_fields;
    my $excel = Dicole::Excel->new;
    my $styles = $excel->get_excel_styles;
    $excel->create_sheet( Dicole::Utils::Text->utf8_to_latin( $self->_msg_excel( 'List of users' ) ) );
    $excel->set_printing;
    $excel->set_header( Dicole::Utils::Text->utf8_to_latin( $self->_msg_excel( 'List of users' ) ) );

    $self->_write_import_excel_header( $excel, $styles );
    # Return the final excel sheet and set the browser
    # output headers correctly.
    return $excel->get_excel( 'User_import-' . DateTime->now->ymd . '.xls' );
}

sub download_user_report {
    my ( $self ) = @_;
    my $excel = Dicole::Excel->new;
    my $date = DateTime->now->ymd;
    $excel->create_sheet( Dicole::Utils::Text->utf8_to_latin( $self->_msg( 'List of users - [_1]', $date ) ) );
    $excel->set_printing;
    $excel->set_header( Dicole::Utils::Text->utf8_to_latin( $self->_msg( 'List of users - [_1]', $date ) ) );

    $self->_write_user_report_excel( $excel );
    # Return the final excel sheet and set the browser
    # output headers correctly.
    return $excel->get_excel( 'User_report-' . $date . '.xls' );
}

# Returns the field size in the Excel sheet column.
# If the field has no such information, the field
# size is determined by calculating the length
# of the field name and adding 5 more characters as
# length. This ensures that an excel column
# is never shorter than the text describing it.
sub _excel_field_size {
    my ( $self, $field ) = @_;
    my $size = $field->options->{excel_size};
    $size ||= length( $field->desc ) + 5;
    return $size;
}

# Writes the Person report header with search options & all
sub _write_import_excel_header {
    my ( $self, $excel, $styles ) = @_;

    my $columns = [];
    foreach my $field ( @{ $self->_excel_import_fields } ) {
        push @{ $columns }, [
            Dicole::Utils::Text->utf8_to_latin( $field->desc ),
            Dicole::Utils::Text->utf8_to_latin( $self->_excel_field_size( $field ) )
        ];
    }

    $excel->write_columns(
        columns => $columns,
        row   => 0,
        col   => 0,
        style => $styles->{column_title}
    );

    my $columns_example = [];
    foreach my $field ( @{ $self->_excel_import_fields } ) {

        if ( $field->id eq 'dicole_theme' ) {
            $field->options->{excel_example} = '0';
        }
        elsif ( $field->id eq 'language' ) {
            $field->options->{excel_example} = 'en';
        }
        elsif ( $field->id eq 'timezone' ) {
            $field->options->{excel_example} = 'Europe/Helsinki';
        }
        elsif ( $field->id eq 'starting_page' ) {
            $field->options->{excel_example} = '0';
        }

        push @{ $columns_example }, [
            Dicole::Utils::Text->utf8_to_latin( $field->options->{excel_example} ),
            Dicole::Utils::Text->utf8_to_latin( $self->_excel_field_size( $field ) ),
        ];
    }

    $excel->write_columns(
        columns => $columns_example,
        row   => 1,
        col   => 0,
        style => $styles->{text_top}
    );
}

sub _write_user_report_excel {
    my ( $self, $excel ) = @_;

    my $styles = $excel->get_excel_styles;
    
    my @source_columns = (
        [ 'email', $self->_msg('Email'), 25 ],
        [ 'first name', $self->_msg('First name') ],
        [ 'last name', $self->_msg('Last name') ],
        [ 'login disabled', $self->_msg('Login disabled') ],
        [ 'billing info', $self->_msg('Billing info') ],
        [ 'country', 'Country' ],
#        [ '', $self->_msg('') ],
    );
    $_->[2] ||= length( $_->[1] ) + 5 for @source_columns;
    my %cmap = map { $_->[0] => $_ } @source_columns;

    my $columns = [];
    foreach my $col ( @source_columns ) {
        push @{ $columns }, [
            Dicole::Utils::Text->utf8_to_latin( $col->[1] ),
            Dicole::Utils::Text->utf8_to_latin( $col->[2] )
        ];
    }

    $excel->write_columns(
        columns => $columns,
        row   => 0,
        col   => 0,
        style => $styles->{column_title}
    );
    
    my $domains = eval { CTX->lookup_action('dicole_domains') };
    my $domain_id = 0;
    my $users = [];
    if ( $domains ) {
        eval {
            $domain_id = $domains->execute( get_current_domain => {} )->id;
        };
        eval {
            my $uids = $domains->execute( users_by_domain => { domain_id => $domain_id } );
            $users = CTX->lookup_object('user')->fetch_group( {
                where => Dicole::Utils::SQL->column_in( 'user_id', $uids )
            } );
        }
    }
    else {
        $users = CTX->lookup_object('user')->fetch_group;
    }

    my $user_profiles = CTX->lookup_action('networking_api')->e( user_profile_object_map => {
        domain_id    => $domain_id,
        user_id_list => [ map { $_->id } @$users ],
    });

    my $row = 1;
    for my $user ( @$users ) {

        my $columns_user = [];
        foreach my $column ( @source_columns ) {
            my $key = $column->[0];
            my $value = '';

            if ( $key eq 'email' ) {
                $value = $user->email;
            }
            elsif ( $key eq 'first name' ) {
                $value = $user->first_name;
            }
            elsif ( $key eq 'last name' ) {
                $value = $user->last_name;
            }
            elsif ( $key eq 'login disabled' ) {
                $value = $user->login_disabled ?
                    $self->_msg('Yes')
                    :
                    $self->_msg('No');
            }
            elsif ( $key eq 'billing info' ) {
                my $notedata = Dicole::Utils::JSON->decode( $user->notes || '{}' );
                $value = $notedata->{ $domain_id }{billing_info} || '';
            }
            elsif ( $key eq 'country' ) {
                my $profile = $user_profiles->{ $user->id };
                $value = $profile ? $profile->contact_address_1 : '';
            }
#             elsif ( $key eq '' ) {
#                 $value = $user->x;
#             }

            push @{ $columns_user }, [
                Dicole::Utils::Text->utf8_to_latin( $value ),
                $cmap{ $column->[0] }->[2] ,
            ];
        }

        $excel->write_columns(
            columns => $columns_user,
            row   => $row,
            col   => 0,
            style => $styles->{text_top}
        );
        $row++;
    }
}

# Get fields available in an import excel
sub _excel_import_fields {
    my ( $self ) = @_;

    my $fields = [];
    foreach my $field_name ( @{ $self->gtool->visible_fields } ) {
        my $field = $self->gtool->get_field( $field_name );
        push @{ $fields }, $field;
    }
    return $fields;
}

# Older WriteExcel requires iso-8859-1 as the encoding.
# If you try to input UTF8 data, the Excel sheet corrupts.
# Newer version supports UTF16 but we delay implementation
# until we have full UTF8 support anyway.
#
# This is changed to try to force utf-8
# OLD COMMENT: We use this method to convert translations from UTF8 to ISO-8859-1.
sub _msg_excel {
    my ( $self, @params ) = @_;
    my $string = $self->_msg( @params );
#    Convert::Scalar::utf8_downgrade( $string, 1 );
    return Dicole::Utils::Text->ensure_utf8( $string );
}

# This action resets default personal rights by first
# removing default personal rights (receiver and target id
# are the same, target_type is TARGET_USER) and then
# adding default personal rights for all users

sub reset_default_personal_rights {
    my ( $self ) = @_;

    # Remove default_personal_rights collections from users

    my $coll = Dicole::Security->collection_by_idstring(
        'default_personal_rights' );

    if ( $coll ) {
        my $secs = CTX->lookup_object( 'dicole_security' )->fetch_iterator( {
            where => "receiver_user_id = target_user_id AND collection_id = ?",
            value => [ $coll->id ],
        } );

        while ( my $sec = $secs->get_next() ) {
            $sec->remove( { skip_security => 1 } );
        }
    }

    my $users = CTX->lookup_object( 'user' )->fetch_iterator( {
        skip_security => 1
    } );
    while ( my $user = $users->get_next() ) {
        $self->_new_user_operations( $user->id, $user );
    }
    Dicole::MessageHandler->add_message( MESSAGE_SUCCESS, $self->_msg(
        'Reset of all user default personal rights was successful.'
    ) );
    return CTX->response->redirect( Dicole::URL->create_from_current(
        task => 'list'
    ) );
}

sub add {
    my ($self) = @_;

    return OpenInteract2::Action::UserManager::Add->new( $self, {
        box_title => 'New user details',
        class => 'user',
        skip_security => 1,
        view => 'add',
    } )->execute;
}

sub remove {
    my ($self) = @_;

    return OpenInteract2::Action::UserManager::Remove->new( $self, {
        box_title => 'List of users',
        path_name => 'Remove users',
        class => 'user',
        skip_security => 1,
        confirm_text => 'Are you sure you want to remove the selected users?',
        view => 'remove',
    } )->execute;
}

# Deleted user operations
sub _deleted_user_operations {
    my ( $self, $uid, $only_remove_files ) = @_;
    $uid ||= $self->param('user_id');
    $only_remove_files ||= $self->param('only_remove_files');

    if ( ! $only_remove_files ) {
        # Remove archetype default_personal_rights collections from user
        my $colls = CTX->lookup_object( 'dicole_security' )->fetch_iterator( {
            where => "receiver_user_id = ? OR target_user_id = ?",
            value => [ $uid, $uid ],
        } );
    
        while ( my $coll = $colls->get_next() ) {
            $coll->remove;
        }
        
        # TODO: What about personal tools? =)
    }
    
    my $action = CTX->lookup_action( 'personal_files' );
    $action->custom_init( { target_type => 'user', target_id => $uid } );
    $action->_del_paths( [ 'users/' . $uid ] );

    return 1;
}

sub resend_account {
    my ( $self ) = @_;
    my $uid = CTX->request->param( 'uid' );
    my $user = CTX->lookup_object( 'user' )->fetch( $uid, { skip_security => 1 } );
    my $plain = SPOPS::Utility->generate_random_code( 6 );
    my $crypted = ( CTX->lookup_login_config->{crypt_password} )
                    ? SPOPS::Utility->crypt_it( $plain ) : $plain;
    $user->{password} = $crypted;
    $user->save( { skip_security => 1 } );
    $self->_send_new_user_email( $user, $plain );
    Dicole::MessageHandler->add_message( MESSAGE_SUCCESS, $self->_msg(
        'Account successfully resend through email.'
    ) );
    return CTX->response->redirect( Dicole::URL->create_full_from_current(
        task => 'show',
        params => { uid => $uid }
    ) );
}

sub _send_new_user_email {
    my ( $self, $data, $password ) = @_;

    my $request = CTX->request;
    my $server_url = Dicole::Pathutils->new->get_server_url;

    my %email_params = (
        login       => $data->{login_name},
        first_name  => $data->{first_name},
        last_name   => $data->{last_name},
        password    => $password,
        server_name => $server_url
    );

    $self->log( 'info', "Sending registration information via email to '$email_params{login}'" );

    my $settings = $self->_get_settings;
    $settings->fetch_settings;
    my $settings_hash = $settings->settings_as_hash;

    my ( $message, $subject );
    unless ( $settings_hash->{'account_email'} ) {
        $message = $self->generate_content(
            \%email_params,
            { name => 'dicole_user_manager::new_user_mail' }
        );
        $subject = $self->_msg( 'Registration information from [_1]', $server_url );
    } else {
        my $tt = Template->new;
        $tt->process( \$settings_hash->{'account_email'}, \%email_params, \$message );
        $tt->process( \$settings_hash->{'account_email_subject'}, \%email_params, \$subject );
    }

    eval {
        Dicole::Utils::Mail->send(
            text => $message,
            to      => $data->{email},
            subject => $subject
        )
    };
    if ( $@ ) {
        $self->log( 'error', "Cannot send email! $@" );
        $self->tool->add_message( $self->_msg( 'Error sending email: [_1]', $@ ) );
    }
}

# New user operations

sub _if_user_duplicate {
    my ( $self, $login_name ) = @_;
    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('user') );
    $data->query_params( {
        where => "login_name = ?",
        value => [ $login_name ]
    } );
    return 1 if $data->total_count( 1 );
    return undef;
}

sub _if_email_duplicate {
    my ( $self, $email ) = @_;
    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('user') );
    $data->query_params( {
        where => "email = ?",
        value => [ $email ]
    } );
    return 1 if $data->total_count( 1 );
    return undef;
}

# Replace inherited methods in Common::Show

sub _pre_init_common_show {
    my ( $self ) = @_;
    $self->_config_tool_show( 'tab_override', 'list' );
    $self->_config_tool_show( 'rows', 2 );
    $self->_update_user_starting_page_for_domain;
    return $self->SUPER::_pre_init_common_show;
}

sub _common_buttons_show {
    my ( $self, $id ) = @_;
    $self->SUPER::_common_buttons_show( $id );
    $self->gtool->add_bottom_button(
        type  => 'confirm_submit',
        value => $self->_msg( 'Resend account' ),
        confirm_box => {
            title => $self->_msg( 'Resend account through email' ),
            name => 'resend_' . $id,
            msg   => $self->_msg( "Password for login will be changed. Are you sure you want to resend this account?" ),
            href  => Dicole::URL->create_full_from_current(
                task => 'resend_account',
                params => { uid => $id }
            )
         }
    );

}

sub _post_init_common_show {
    my ( $self ) = @_;
    $self->SUPER::_post_init_common_show;
    $self->_generate_timezones;
    $self->_generate_starting_page;
    $self->_generate_themes;
    
    $self->gtool->merge_fake_to_spops( 1 );
    $self->gtool->fake_objects( [ { billing_info => $self->_get_user_billing_info } ] );
}

sub _pre_gen_tool_show {
    my ( $self ) = @_;
    $self->gtool( Dicole::Generictool->new(
        object => CTX->lookup_object( 'groups' ),
        skip_security => 1,
        current_view => 'show_user_groups',
    ) );
    $self->init_fields;
    $self->gtool->Data->query_params( {
        from => [ qw(dicole_groups dicole_group_user) ],
        where => 'dicole_group_user.groups_id = dicole_groups.groups_id '
            . 'AND dicole_group_user.user_id = ?',
        value => [ CTX->request->param( 'uid' ) ],
        order => 'dicole_groups.name'
    } );
    $self->tool->Container->box_at( 0, 1 )->name(
        $self->_msg( 'Groups user belongs to' )
    );
    $self->tool->Container->box_at( 0, 1 )->add_content(
        $self->gtool->get_list
    );
}

sub _pre_init_common_edit {
    my ( $self ) = @_;
    $self->_config_tool_edit( 'tab_override', 'list' );
    $self->_update_user_starting_page_for_domain;
    return $self->SUPER::_pre_init_common_edit;
}

sub _post_init_common_edit {
    my ( $self ) = @_;
    $self->SUPER::_post_init_common_edit;
    $self->_init_password;
    $self->_generate_timezones;
    $self->_generate_starting_page;
    $self->_generate_themes;
    $self->gtool->optional_passwords( 1 );
    
    $self->gtool->merge_fake_to_spops( 1 );
    $self->gtool->fake_objects( [ { billing_info => $self->_get_user_billing_info } ] );
    
}

sub _post_save_edit {
    my ( $self, $data ) = @_;

    $self->_update_ldap_user($data, CTX->request->param('password'));

    if ( CTX->request->auth_user_id eq $data->data->id ) {
        $self->log( 'info',
            "Updating cached auth user in request for user id ["
                . $data->data->id . "]"
        );
        my $session = CTX->request->session;
        $session->{_oi_cache}{user_refresh_on} = time;
        $session->{lang} = undef;
    }
    
    my $dicole_domains = eval { CTX->lookup_action( 'dicole_domains' ) };
    my $domain = $dicole_domains ? eval { $dicole_domains->get_current_domain } : undef;
    my $domain_id = $domain ? $domain->id : 0;

    Dicole::Settings->store_single_setting(
        user_id => $data->data->id,
        tool => 'login',
        attribute => 'starting_group_' . $domain_id,
        value => $data->data->starting_page,
    );
    
    my $notedata = Dicole::Utils::JSON->decode( $data->data->notes || '{}' );
    $notedata->{ $domain_id }{billing_info} = $data->data->{billing_info};
    $data->data->notes( Dicole::Utils::JSON->encode( $notedata ) );
    $data->data->save;
    
    return undef;
}

sub _pre_gen_tool_list {
    my ( $self ) = @_;

    $self->tool->Container->box_at( 0, 0 )->add_content(
        Dicole::Widget::Hyperlink->new(
            class => 'download_user_report_link',
            link => $self->derive_url( task => 'download_user_report', target => 0, additional => [] ),
            content => $self->_msg( 'Download user report' ),
        )
    );
}

sub _update_ldap_user {
    my ($self, $data_obj, $plain_pass) = @_;

    my $data = $data_obj->data; # XXX

    # check that user object needs external authentication
    # XXX: is this needed?
    unless ( $data->{external_auth} ) {
        return undef;
    }

    my $cn = $data->{first_name} . ' ' . $data->{last_name};

    my $rs;

    eval {
        # update Dicole::LDAPUser object
        my $lu = new Dicole::LDAPUser( {
            ldap_server_name => $data->{external_auth},
            login_name       => $data->{login_name}
        });
        $lu->field('first_name', $data->{first_name});
        $lu->field('last_name', $data->{last_name});
        $lu->field('cn', $cn);
        $lu->field('email', $data->{email});
        $lu->field('language', $data->{language});
    
        $rs = $lu->update;
    
        my $la;
        if ($plain_pass) {
            $la = new Dicole::LDAPAdmin($data->{external_auth});
            $rs = $la->update_user_password($lu, $plain_pass);
        }
    };

    if ($@ or (! $rs)) {
    $self->log( 'error',
            "Failed to update LDAP user [$data->{login_name} via server [$data->{external_auth}]" );
    } else {
    $self->log( 'info',
            "Updated LDAP user [$data->{login_name} via server [$data->{external_auth}]" );
    }

    return $rs;
}

sub _init_password {
    my ( $self, $gtool ) = @_;
    $gtool ||= $self->gtool;
    $gtool->get_field('password')->options(
        confirm => 1,
        confirm_text => $self->_msg( 'Verify password' ),
        crypt => CTX->server_config->{login}{crypt_password}
    );
}

sub _update_user_starting_page_for_domain {
    my ( $self ) = @_;
    
    my $uid = CTX->request->param('uid');
    if ( $uid ) {
        my $dicole_domains = eval { CTX->lookup_action( 'dicole_domains' ) };
        my $domain = $dicole_domains ? eval { $dicole_domains->get_current_domain } : undef;
        my $domain_id = $domain ? $domain->id : 0;
        
        # megahack :D
        my $sg = Dicole::Settings->fetch_single_setting(
            user_id => $uid,
            tool => 'login',
            attribute => 'starting_group_' . $domain_id,
        );
    
        if ( $sg ) {
            my $user = CTX->lookup_object('user')->fetch( $uid );
            $user->starting_page( $sg );
            $user->save;
        }
    }
}

sub _get_user_billing_info {
    my ( $self ) = @_;
    
    my $uid = CTX->request->param('uid');
    if ( $uid ) {
        my $dicole_domains = eval { CTX->lookup_action( 'dicole_domains' ) };
        my $domain = $dicole_domains ? eval { $dicole_domains->get_current_domain } : undef;
        my $domain_id = $domain ? $domain->id : 0;
        
        my $user = CTX->lookup_object('user')->fetch( $uid );
        my $data = Dicole::Utils::JSON->decode( $user->notes || '{}' );
        return $data->{$domain_id}->{billing_info};
    }
    return '';
}

# Generates starting page dropdown
sub _generate_starting_page {
    my ( $self ) = @_;
    my $starting_page = $self->gtool->get_field( 'starting_page' );
#    $starting_page->add_dropdown_item( 0, $self->_msg( 'Personal summary' ) );
    my $groups = CTX->lookup_object( 'groups' )->fetch_group( {
        from => [ qw(dicole_groups dicole_group_user) ],
        where => 'dicole_group_user.groups_id = dicole_groups.groups_id '
            . 'AND dicole_group_user.user_id = ?',
        value => [ CTX->request->param( 'uid' ) ]
    } );
    
    my $gids = eval { CTX->lookup_action('dicole_domains')->groups_by_domain };
    my %gidhash = $gids ? map { $_ => 1 } @$gids : ();
    
    my $filled = 0;
    foreach my $group ( @{ $groups } ) {
        next if $gids && ! $gidhash{ $group->id };
        $filled = 1;
        $starting_page->add_dropdown_item( $group->id, $group->{name} );
    }
    
    unless ( $filled ) {
        $starting_page->add_dropdown_item( 0, $self->_msg('Default') );
    }
}

# Generates theme selection dropdown
sub _generate_themes {
    my ( $self ) = @_;
    my $theme_dropdown = $self->gtool->get_field( 'dicole_theme' );
    $theme_dropdown->add_dropdown_item( 0, $self->_msg( 'Default' ) );
    my $themes = CTX->lookup_object( 'dicole_theme' )->fetch_group( {
        where => 'user_id = 0 AND groups_id = 0',
        order => 'name',
    } );
    foreach my $theme ( @{ $themes } ) {
        $theme_dropdown->add_dropdown_item( $theme->id, $theme->{name} );
    }
}

# Generates timezone selection dropdown
sub _generate_timezones {
    my ( $self ) = @_;
    my $timezone = $self->gtool->get_field( 'timezone' );
    $timezone->add_dropdown_item( 'UTC', $self->_msg( '-- Select --' ) );
    foreach my $zone ( @{ DateTime::TimeZone->all_names } ) {
        $timezone->add_dropdown_item( $zone, $zone );
    }
}

sub _import_excel {
    my ( $self, $filehandle ) = @_;

    my $log = get_logger( LOG_APP );

    my $count_import = 0;
    my @rows_failed;

    # Create an excel worksheet object
    my $excel = Spreadsheet::ParseExcel::Workbook->Parse(
        $filehandle
    );
    return undef unless $excel;

    # Create generictool object, load fields from the "add" view
    my $gtool = Dicole::Generictool->new(
        object => CTX->lookup_object('user'),
        skip_security => 1,
        current_view => 'excel_fields',
    );
    $self->init_fields( gtool => $gtool );
    $gtool->get_field('password')->options(
        crypt => CTX->server_config->{login}{crypt_password}
    );

    # We are only interested in the first worksheet
    my $wsheet = $excel->Worksheet( 0 );

    my $domain_groups = [];
    my $domain_id = 0;
    my $dicole_domains = eval { CTX->lookup_action( 'dicole_domains' ) };

    if ( $dicole_domains ) {
        $dicole_domains->task( 'groups_by_domain' );
        $domain_groups = $dicole_domains->execute;
        $domain_id = eval { $dicole_domains->get_current_domain->id } || 0;
    }

    # Go through the worksheet, row by row until
    # the last row is achieved
    for ( my $row = $wsheet->{MinRow} + 1;
        defined $wsheet->{MaxRow} && $row <= $wsheet->{MaxRow} ; $row++ ) {

        # Go through all the fields in the view and expect the
        # fields in the excel sheet to appear in the exactly same
        # order.
        my $col = 0;

        # Skip to next row if login name not present
        my $first_cell = $wsheet->{Cells}[$row][0];
        next if ! $first_cell || ! $first_cell->Value;

        my $plaintext_password = undef;
        foreach my $field_id ( @{ $gtool->visible_fields } ) {
            my $field = $gtool->get_field( $field_id );
            $field->use_field_value( 1 );

            my $cell = $wsheet->{Cells}[$row][$col];

            my $value;
            $value = Dicole::Utils::Text->latin_to_utf8( $cell->Value ) if ref $cell;

            if ( $field->id eq 'password' ) {
                if ( $value ) {
                    $log->is_debug &&  $log->debug(
                        "Using password from excel:" . $value
                    );
                    $field->value( $value );
                }
                else {
                    $log->is_debug && $log->debug( "Generating password" );
                    my ( $pass ) = CTX->lookup_action( 'register' )->
                        _create_password;
                    $field->value( $pass );
                }

                $plaintext_password = $field->value;
            }
            elsif ( $field->id eq 'starting_page' || $field->id eq 'dicole_theme' ) {
                $value =~ tr/[0-9]//cd;
                $value ||= 0;
                $field->value( $value );
            }
            elsif ( $field->id eq 'notes' ) {
                my $info = { $domain_id => { billing_info => $value } };
                $field->value( Dicole::Utils::JSON->encode( $info ) ) if defined( $value ) && $value ne '';
            }
            else {
                $field->value( $value );
            }

            $col++;
        }

        if ( $log->is_debug ) {
            my $string = "Trying to save user with following values:\n";
            foreach my $field_id ( @{ $gtool->visible_fields } ) {
                my $value = $gtool->get_field( $field_id )->value;
                $string .= $field_id .': '. $value . "\n";
            }
            $log->debug( $string );
        }

        # validate and save. Run new user operations if the
        # object got successfully saved. Otherwise store the
        # the failed row numbers for later use.

        # don't save the last which is virtual field "initial_groups".
        # do a copy so that the next round is not affected when popping
        my @visible_fields = @{ $gtool->visible_fields };
        pop @visible_fields;

        my ( $code, $message ) = $gtool->validate_and_save(
            \@visible_fields,
            { skip_cache => 1, no_save => 1 }
        );

        my $data = $gtool->Data->data;
        if ( $code ) {
            my $user = Dicole::Utils::User->fetch_user_by_login_in_current_domain( $data->{email} );
            $user ||= Dicole::Utils::User->fetch_user_by_login_in_current_domain( $data->{login_name} );

            if ( ! $user ) {
                $data->{login_name} = $data->{email};
                $data->{theme_id} = CTX->lookup_default_object_id( 'theme' );
                $gtool->Data->data_save;

                my $external_auth = undef;
                if ( $dicole_domains ) {
                    my $domain = $dicole_domains->get_current_domain;
                    $external_auth = $domain->external_auth;
                }

                $self->_post_saving( $gtool->Data, $plaintext_password, $external_auth );

                $count_import++;
                $user = $gtool->Data->data;
            }

            if ( eval { CTX->lookup_action('add_user_to_group'); } ) {
                my $initial_groups = $gtool->get_field( 'initial_groups' )->value;
                for my $gid ( split /\s*,\s*/, $initial_groups ) {
                    $gid =~ tr/[0-9]//cd;
                    next unless $gid;
                    if ( $dicole_domains ) {
                        next unless ( grep { $_ == $gid } @{ $domain_groups } ) > 0;
                    }
                    CTX->lookup_action('add_user_to_group')->execute( {
                        user_id => $user->id,
                        group_id => $gid,
                    } );
                }
            }
        }
        else {
            push @rows_failed, "$row: $message";
        }
    }
    return $count_import, join( ", ", @rows_failed );
}

sub _import_ws {
    my ( $self, $filehandle ) = @_;

    my $count_import = 0;
    my @rows_failed;

    # data
    my $data_string = '';
    {
        local $/;
        $data_string = <$filehandle>;
    }
    return undef unless $data_string;
    
    my $users = [];
    
    my @rows = split "\n", $data_string;
    my $keys = shift @rows;
    for my $row ( @rows ) {
        my %data = ();
        my @keys = split "\t", $keys;
        my @values = split "\t", $row;
        while ( scalar @keys ) {
            my $key = shift @keys;
            $data{ $key } = shift @values if $key;
        }
        push @$users, \%data;
    }
    
    my $dicole_domains = eval { CTX->lookup_action( 'dicole_domains' ) };

    # Go through the worksheet, row by row until
    # the last row is achieved
    my $row = 0;
    for my $user_data ( @$users ) {
        $row++;

        next if $user_data->{given_name} eq 'testi';
        next unless $user_data->{rb01} eq 'rb0102';

        my $user = CTX->lookup_object('user')->new;
        
        my $password = CTX->lookup_action( 'register' )->_create_password;
        my $crypted = ( CTX->lookup_login_config->{crypt_password} ) ?
            SPOPS::Utility->crypt_it( $password ) : $password;
        
        $user->password( $crypted );
        $user->email( $user_data->{mail} );
        $user->login_name( $user->email );
        $user->first_name( $user_data->{given_name} );
        $user->last_name( $user_data->{surname} );
        
        next if ! $user->login_name || ! $user->first_name || ! $user->last_name;
        
        if ( $self->_if_user_duplicate( $user->login_name ) ) {
            push @rows_failed, "$row: " . $self->_msg(
                "Login name [_1] already exists. Choose another login name.",
                $user->login_name
            );
            next;
        }
        else {
            $user->{theme_id} = CTX->lookup_default_object_id( 'theme' );
            $user->save;
            
            my $external_auth = undef;
            if ( $dicole_domains ) {
                my $domain = $dicole_domains->get_current_domain;
                $external_auth = $domain->external_auth;
                
                $user->language( $domain->default_language );
                $user->timezone( $domain->default_timezone );
                $user->save;
            }
            
            $self->_post_saving( $user, $password, $external_auth );
            
            eval {
                my $networking = CTX->lookup_action('networking');
                my $profile = $networking->_get_profile_object( $user->id );
                $profile->employer_name( $user_data->{company} ) unless $user_data->{company} eq 'null';
                $profile->employer_title( $user_data->{title} ) unless $user_data->{title} eq 'null';
                $profile->save;
            };
    
            $count_import++;
        }
    }
    
    return $count_import, join( ", ", @rows_failed );
}

sub _post_saving {
    my ( $self, $data, $password, $external_auth ) = @_;
    my $user = $data;
    if ( ref( $user ) && $user->can( 'data' ) && ref ( $user->data ) && ref ( $user->data ) ne 'HASH' ) {
        $user = $user->data;
    }

    # use supplied external_auth, fall back to default if any
    
    $external_auth ||= CTX->lookup_login_config->{create_server}->{default};

    my $cs = $external_auth;

    if ( $cs && $cs !~ /^local$/i ) {
        # create LDAP user
        $password ||= CTX->request->param('password');
        $self->_create_ldap_user(
            $user, $password, $cs
        );

        # save value of external_auth to database
        $user->{external_auth} = $cs;
        eval { $user->save };
    }
    
    $self->_new_user_operations( $user->id, $user );

    if ( CTX->request->param('send_account') ) {
        $self->_send_new_user_email( $user, CTX->request->param('password') || $password );
    }

    return 1;
}

package OpenInteract2::Action::UserManager::Add;

use base 'Dicole::Task::GTAdd';
use OpenInteract2::Context   qw( CTX );

sub _post_init {
    my ( $self ) = @_;
    $self->action->_init_password;
    $self->action->_generate_timezones;
    $self->action->_generate_themes;
}

sub _pre_save {
    my ( $self, $data ) = @_;

    if ( $self->action->_if_user_duplicate( $data->data->{login_name} ) ) {
        $self->action->gtool->get_field( 'login_name' )->error( 1 );
        $self->action->tool->add_message( 0, $self->action->_msg(
            "Login name [_1] already exists. Choose another login name.",
            $data->{login_name}
        ) );
        return 0;
    }
    elsif ( $self->action->_if_email_duplicate( $data->data->{email} ) ) {
        $self->action->gtool->get_field( 'email' )->error( 1 );
        $self->action->tool->add_message( 0, $self->action->_msg(
            "User with email address [_1] already exists. "
                . "Choose a different email address.",
             $data->{email}
        ) );
        return 0;
    }
    else {
        $data->data->{theme_id} = CTX->lookup_default_object_id( 'theme' );
        return 1;
    }
}

sub _post_save {
    my ( $self, $data ) = @_;

    my $ea;
    eval {
        my $domain = CTX->lookup_action('dicole_domains')->get_current_domain;
        $ea = $domain->external_auth;
    };
    
    my $domain_id = 0;
    eval {
        my $domain = CTX->lookup_action('dicole_domains')->get_current_domain;
        $domain_id = $domain->id;
    };
    
    my $notedata = Dicole::Utils::JSON->decode( $data->data->notes || '{}' );
    $notedata->{ $domain_id }{billing_info} = $data->data->{billing_info};
    $data->data->notes( Dicole::Utils::JSON->encode( $notedata ) );
    $data->data->save;

    $self->action->_post_saving( $data, undef, $ea );

    return $self->action->_msg( "User has been saved." );
}


package OpenInteract2::Action::UserManager::Remove;

use base 'Dicole::Task::GTRemove';
use OpenInteract2::Context   qw( CTX );

# Replace inherited methods in Common::Remove

sub _post_init {
    my ( $self ) = @_;
    # Deleting your own username is not possible
    $self->action->gtool->Data->query_params( {
        where => 'user_id != ?',
        value => [ CTX->request->auth_user_id ]
    } );
}

sub _pre_remove {
    my ( $self, $ids ) = @_;

    $ids || return undef;

    foreach my $id (keys %{$ids}) {
    my $o = CTX->lookup_object('user')->fetch($id, { skip_security => 1 });
    if ( $o->{external_auth} ) {
        # delete user from LDAP database
        my $login_name  = $o->{login_name};
        my $ldap_server = $o->{external_auth};
        my $la = new Dicole::LDAPAdmin($ldap_server);
        my $rs = $la->delete_user($la->search_user($login_name));
        unless ($rs) {
        $self->action->log('warn', "Failed to remove user [$login_name] from LDAP database [$ldap_server].");
        }
    }
    }

    return 1;
}

sub _post_remove {
    my ( $self, $ids ) = @_;
    foreach my $id ( keys %{ $ids } ) {
        $self->action->_deleted_user_operations( $id );
    }
    return $self->action->_msg( "Selected users removed." );
}


1;

__END__

=head1 NAME

OpenInteract2::Action::DicoleUserManager - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS


