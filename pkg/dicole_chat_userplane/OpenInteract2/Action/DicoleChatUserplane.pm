package OpenInteract2::Action::DicoleChatUserplane;

use strict;

use base qw(Dicole::Action
            Dicole::Action::Common::Summary
            Dicole::Action::Common::Settings);

use Switch;
use XML::Simple;
use Log::Log4perl qw(get_logger);
use OpenInteract2::Constants qw(:log);
use OpenInteract2::Context qw(CTX);
use Dicole::Generictool::Data;
use Dicole::Content::Iframe;
use Dicole::Widget::Text;
use Dicole::Widget::Hyperlink;
use Dicole::Widget::Listing;
use Date::Format qw(time2str);
use HTTP::Status qw(RC_OK);
use Unicode::MapUTF8 qw(to_utf8 from_utf8);

use constant USER_IMAGE_FIELD => 'pro_image';

use constant USER_IMAGE_THUMB_SUFFIX => '';
use constant USER_IMAGE_FULL_SUFFIX  => '_o';
use constant USER_IMAGE_ICON_SUFFIX  => '_t';

use constant HTML_MIMETYPE => 'text/html';

use constant FLASH_COM_SERVER  => 'flashcom.dicole.userplane.com';
use constant FLASH_DOMAINID    => 'crm.dicole.net';
use constant FLASH_SERVER      => 'swf.userplane.com';
use constant FLASH_APPLICATION => 'CommunicationSuite';
use constant FLASH_LOCALE      => 'english'; # XXX: get this from user data?

use constant AUTH_KEY     => 'avKiozAs3hah5ooThhaive4Eeize9iNg';
use constant AUTH_INVALID => 'INVALID';
use constant AUTH_YES     => 'yes';

use constant FILENAME_SEPARATOR => '.';
use constant PARAM_SEPARATOR    => '|';

use constant VC_ROOM_ENABLED => 1;
use constant VC_USER_IN_ROOM => 1;

use constant VC_CONN_CONNECTED    => 1;
use constant VC_CONN_DISCONNECTED => 0;

use constant ROOM_CREATOR_ID => 'dicole_admin';
use constant ADMIN_IDS       => { jpir => 1, inf => 1 };
use constant GROUP_UNDEFINED  => 0;

use constant DICOLE_CHARSET => 'ISO-8859-1';

our $VERSION = sprintf("%d.%02d", q$Revision: 1.20 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

OpenInteract2::Action::DicoleChatUserplane

=head1 DESCRIPTION

DicoleChatUserplane is a class for creating, managing & logging
Userplane Flash chat connections.

=head1 METHODS

=head2 view( )

Returns Iframe containing code to connect to the chat server.

=cut

sub view {
    my $self = shift;

    $self->param('active_navigation', 'group_virtualconference');

    $self->tool(
        Dicole::Tool->new(
            action => $self,
            no_tool_tabs => 1,
            structure => 'custom',
            custom_content => Dicole::Content::Iframe->new(
                url => $self->derive_url( task => 'chat' ),
            ),
        )
    );

    return $self->generate_tool_content;
}

=pod

=head2 chat ( )

Makes connection to Flash communication server.

=cut

sub chat {
    my $self = shift;

    my $group = CTX->request->{target_group};
    $group->{groups_id} || return undef;

    my $session = $self->_get_session($group->{groups_id});
    $session->{room_id} || return undef;

    my $room = $self->_get_room({room_id => $session->{room_id}});

    my $flash_params = {strFlashcomServer  => FLASH_COM_SERVER,
                        strDomainID        => FLASH_DOMAINID,
                        strSessionGUID     => $session->{sessionGUID_str},
                        strKey             => AUTH_KEY,
                        strInitialRoom     => $room->{room_name},
                        strSwfServer       => FLASH_SERVER,
                        strApplicationName => FLASH_APPLICATION,
                        strLocale          => FLASH_LOCALE};

    # XXX: strUserID?
    my $strFlashVars = "strServer=" . $flash_params->{strFlashcomServer}
        . "&strSwfServer=" . $flash_params->{strSwfServer}
        . "&strDomainID=" . $flash_params->{strDomainID}
        . "&strSessionGUID=" . $flash_params->{strSessionGUID}
        . "&strKey=" . $flash_params->{strKey}
        . "&strLocale=" . $flash_params->{strLocale}
        . "&strInitialRoom=" . $flash_params->{strInitialRoom};

    $flash_params->{strFlashVars} = $strFlashVars;

    CTX->response->content_type(HTML_MIMETYPE);
    CTX->response->status(RC_OK);
    CTX->controller->no_template('yes');

    return $self->generate_content($flash_params,
                                   {name => 'dicole_chat_userplane::chat_flash'});
}

=pod

=head2 virtualconference_summary ( )

Displays the VC summary box in the group page.

=cut

sub virtualconference_summary {
    my $self = shift;

    my $group_id = (CTX->request->{target_group_id} || return undef);
    my $room     = $self->_get_room({group_id => $group_id});

    # $room->{room_id} || return undef;

    my $has_vc_rights;
    ($room->{room_id} && $room->{enabled}) && ($has_vc_rights = 1);

    my $box = Dicole::Box->new();

    # box title: 'Virtual conference'
    my $title = Dicole::Widget::Horizontal->new;
    $title->add_content(
        Dicole::Widget::Hyperlink->new(
            content => $self->_msg('In virtual conference'),
            link => Dicole::URL->create_from_parts(
                action => 'chat',
                task => 'view',
                target => CTX->request->target_group_id,
            ),
        )
    );

    if ($has_vc_rights) {
        # show box of online users, if any
        my $users = $self->_get_users_present($group_id);

        # generate box title
        $box->name($title->generate_content);

        if ($users) {
            # generate list of online users
            my $list = Dicole::Widget::Listing->new(use_keys => 0,);
            foreach my $user (@$users) {
                # this kind of sucks, but since there is no popup widget yet...
                my $link = qq{javascript:void(window.open('/profile_popup/professional/} .
                       $user->id . qq{', 'profile', 'toolbar=no,menubar=no,} .
                       qq{statusbar=no,scrollbars=yes,width=640,height=480'))};
                $list->new_row;
                $list->add_cell(content =>
                    Dicole::Widget::Hyperlink->new(content => 
                        $user->first_name . ' ' . $user->last_name, link => $link,),);
            }
            $box->content($list);
        } else {
            # no online users
            $box->content(Dicole::Widget::Text->new(text => $self->_msg('No online users'),));
        }
    } else {
        # generate box title
        $box->name($title->generate_content);

        # show message explaining the possibility of purchasing VC rights from Dicole
        $box->content(Dicole::Widget::Text->new(text => $self->_msg('The virtual conferencing tool is an optional service with a monthly cost. Please contact Dicole Oy if you want to enable the service.')));
    }

    return $box->output;
}

=pod

=head2 userplane_comm ()

Wrapper function for dispatching various Userplane functionality.

=cut

sub userplane_comm {
    my $self = shift;

    my $function = (CTX->request->param('function') || CTX->request->param('action'));

    unless(CTX->request->param('domainID') eq FLASH_DOMAINID) {
        return $self->_xml_wrapper;
    }

    my $sessionGUID_tmp = CTX->request->param('sessionGUID');
    my ($sessionGUID, $room_id) = $sessionGUID_tmp =~ /(.+)\|(\d+)$/;

    $self->{_params} = {
        domainID    => CTX->request->param('domainID'),
        function    => $function,
        sessionGUID => $sessionGUID,
        key         => CTX->request->param('key'),
        room_id     => $room_id
    };

    my $xml;

    switch ($self->{_params}->{function}) {
        case 'getUser'                { $xml = $self->_get_user_xml; last }
        case 'sendArchive'            { 
            $self->{_params}->{xmlData} = CTX->request->param('xmlData');
            $self->_send_archive; last
        }
        case 'getDomainPreferences'   { $xml = $self->_get_domain_preferences_xml; last }
        case 'onUserConnectionChange' { 
            $self->{_params}->{userID}    = CTX->request->param('userID');
            $self->{_params}->{connected} = CTX->request->param('connected');
            $self->_on_user_connection_change; last
        }
        case 'onUserRoomChange'       { 
            $self->{_params}->{userID}   = CTX->request->param('userID');
            $self->{_params}->{roomName} = CTX->request->param('roomName');
            $self->{_params}->{inRoom}   = CTX->request->param('inRoom');
            $self->_on_user_room_change; last
        }
        # NOTE: the following are not implemented
        case 'onRoomStatusChange'     { last }
        case 'setBannedStatus'        { last }
        case 'setBlockedStatus'       { last }
        case 'setFriendStatus'        { last }
        case 'getAnnouncements'       { last }
    }

    return $self->_xml_wrapper($xml);
}

=pod

=head2 send_archive ( )

Saves chatlog entries to database.

=cut

sub _send_archive {
    my $self = shift;

    my $struct;
    eval {
        my $xp = new XML::Simple;
        $struct = $xp->xml_in($self->{_params}->{xmlData});
    };

    if ($struct->{room}->{name}) {
        # single room
        my $data = $struct->{room}->{messages}->{entry};
        my $room_name = $struct->{room}->{name};
        if (ref($data) eq 'ARRAY') {
            # multiple entries
            foreach my $entry (@{$data}) {
                $self->_save_chatlog_entry($entry,
                                           $self->_get_room({room_name => $room_name}));
            }
        } else {
            # single entry
            $self->_save_chatlog_entry($data, 
                                       $self->_get_room({room_name => $room_name}));
        }
    } else {
        # multiple rooms
        my $data = $struct->{room};
        foreach my $room_name (keys(%{$data})) {
            my $entry_d = $data->{$room_name}->{messages}->{entry};
            my $ref = ref($entry_d);
            if (ref($entry_d) eq 'ARRAY') {
                # multiple entries
                foreach my $entry (@{$entry_d}) {
                    $self->_save_chatlog_entry($entry, 
                                               $self->_get_room({room_name => $room_name}));
                }
            } else {
                # single entry
                $self->_save_chatlog_entry($entry_d,
                                           $self->_get_room({room_name => $room_name}));
            }
        }
    }

    return 1; # true; no return value needed by userplane flashcomm
}

=pod

=head2 _on_user_connection_change ( )

Saves state on user connection to database.

=cut

sub _on_user_connection_change {
    my $self = shift;

    my $connection = CTX->lookup_object('dicole_vc_connection')->new;
    my $user = CTX->lookup_object('user')->fetch_by_login_name($self->{_params}->{userID}, 
                                                               {skip_security => 1});
    $connection->{user_id}   = $user->{user_id};
    $connection->{group_id}  = GROUP_UNDEFINED; # XXX: fix group id
    $connection->{timestamp} = time; # unix timestamp

    if ($self->{_params}->{connected} eq 'true') {
        # connected
        $connection->{status} = VC_CONN_CONNECTED;
    } else {
        # disconnected
        $connection->{status} = VC_CONN_DISCONNECTED;
    }

    eval {
        $connection->save;
    };

    if ($@) {
        return 1; # true; no return value needed by userplane flashcomm
    } else {
        return 1;
    }
}

=pod

=head2 _on_user_room_change ( )

Saves user room state to database.

=cut

sub _on_user_room_change {
    my $self = shift;

    unless($self->{_params}->{roomName}) {
        return undef;
    }
    my $room = $self->_get_room({room_name => $self->{_params}->{roomName}});
    unless($room->{room_id}) {
        return undef;
    }

    my $user = CTX->lookup_object('user')->fetch_by_login_name($self->{_params}->{userID}, 
                                                               {skip_security => 1});    
    unless($user->{user_id}) {
        return undef;
    }

    my $presence;

    my $data = Dicole::Generictool::Data->new;
    $data->object(CTX->lookup_object('dicole_vc_presence'));
    $data->query_params({
        where => 'user_id = ?',
        value => [$user->{user_id}]
    });
    $data->data_group;

    if(defined($data->data->[0])) {
        # user has existing presence in DB
        $presence = $data->data->[0];
    } else {
        $presence = CTX->lookup_object('dicole_vc_presence')->new;
    }

    if ($self->{_params}->{inRoom} eq 'true') {
        # joined room
        $presence->{in_room} = 1;
    } else {
        # left room
        $presence->{in_room} = 0;
    }

    $presence->{user_id}   = $user->{user_id};
    $presence->{room_id}   = $room->{room_id};
    $presence->{timestamp} = time; # use unix timestamp

    eval {
        $presence->save;
    };

    return 1; # true; no return value needed by userplane flashcomm    
}

=pod

=head2 _on_user_room_change ( HASH param )

Fetches chat room from database, checkin whether the room is enabled.

=cut

sub _get_room {
    my ($self, $param) = @_;

    if ($param->{room_name}) {
        my $data = Dicole::Generictool::Data->new;
        $data->object(CTX->lookup_object('dicole_vc_rooms'));
        $data->query_params({
            where  => 'room_name = ? AND enabled = ?',
            value  => [$param->{room_name}, VC_ROOM_ENABLED],
        });
        $data->data_group;
        defined($data->data->[0]->{room_id}) && return $data->data->[0];
    } elsif ($param->{group_id}) {
        my $data = Dicole::Generictool::Data->new;
        $data->object(CTX->lookup_object('dicole_vc_rooms'));
        $data->query_params({
            where  => 'group_id = ? AND enabled = ?',
            value  => [$param->{group_id}, VC_ROOM_ENABLED],
        });
        $data->data_group;
        defined($data->data->[0]->{room_id}) && return $data->data->[0];
    } elsif ($param->{room_id}) {
        my $data = Dicole::Generictool::Data->new;
        $data->object(CTX->lookup_object('dicole_vc_rooms'));
        $data->query_params({
            where  => 'room_id = ? AND enabled = ?',
            value  => [$param->{room_id}, VC_ROOM_ENABLED],
        });
        $data->data_group;
        defined($data->data->[0]->{room_id}) && return $data->data->[0];
    }
    return undef;
}


=pod

=head2 send_archive ( HASH entry, HASH room )

Saves single chatlog entry to database.

=cut

sub _save_chatlog_entry {
    my ($self, $entry, $room) = @_;

    unless($entry && $room->{room_id}) {
        return undef;
    }

    my $n_entry = CTX->lookup_object('dicole_vc_chatlog')->new;

    my $invisible;
    ($entry->{userID}->{invisible} eq 'true') ? $invisible = 1 : $invisible = 0;

    $n_entry->{room_id}      = $room->{room_id};
    $n_entry->{room_name}    = $room->{room_name};
    $n_entry->{timestamp}    = $entry->{timestamp};
    $n_entry->{content}      = $entry->{content};
    $n_entry->{type}         = $entry->{type};
    $n_entry->{userID}       = $entry->{userID}->{content};
    $n_entry->{invisible}    = $invisible;
    $n_entry->{display_name} = $entry->{displayName};

    eval {
        $n_entry->save;
    };
    if ($@) {
        # XXX: logging code
        return undef;
    }

    return $n_entry;
}

=pod

=head2 xml_wrapper ( STRING xml )

Wrapper function for transmitting xml data; standard header & footer.

=cut

sub _xml_wrapper {
    my ($self, $xml) = @_;

    CTX->response->content_type('text/xml; charset=utf-8');
    CTX->response->status(RC_OK);
    CTX->controller->no_template('yes');

    my $xml_t = "<?xml version=\"1.0\" encoding=\"iso-8859-1\"?>\n<communicationsuite>\n";
    my $date_str = time2str('%c', time);
    $xml_t .= "<time>$date_str</time>\n";
    $xml && ($xml_t .= $xml);
    $xml_t .= "</communicationsuite>\n";

    return $xml_t;
}

=pod

=head2 _get_session ( SCALAR group_id )

Checks whether user has rights to connect to VC.

=cut

sub _get_session {
    my ($self, $group_id) = @_;

    $group_id || return undef;

    my $room_id;

    my $data = Dicole::Generictool::Data->new;
    $data->object(CTX->lookup_object('dicole_vc_rooms'));
    $data->query_params({
        where  => 'group_id = ? AND enabled = ?',
        value  => [$group_id, VC_ROOM_ENABLED]
    });
    $data->data_group;

    if (defined($data->data->[0]->{room_id})) {
        $room_id = $data->data->[0]->{room_id};
    } else {
        return undef;
    }

    # XXX: is this right?
    my $ret_str = CTX->request->auth_user->{login_name};
    $ret_str .= PARAM_SEPARATOR;
    $ret_str .= $room_id;

    my $ret = {
        login_name      => CTX->request->auth_user->{login_name},
        group_id        => $group_id,
        room_id         => $room_id,
        sessionGUID_str => $ret_str,
    };

    return $ret;
}

=pod

=head2 _get_session ( SCALAR group_id )

Returns list of user ids present in VC for specified group.

=cut

sub _get_users_present {
    my ($self, $group_id) = @_;

    unless($group_id) {
        return undef;
    }
    my $room = $self->_get_room({group_id => $group_id});
    unless($room->{room_id}) {
        return undef;
    }

    my $presences = CTX->lookup_object('dicole_vc_presence')->fetch_group({
        where => 'room_id = ? AND in_room = ?',
        value => [$room->{room_id}, VC_USER_IN_ROOM]
    });

    $presences->[0]->{user_id} || return undef;

    my $user_ids = [];
    foreach my $presence (@$presences) {
        push(@{$user_ids}, $presence->{user_id});
    }

    $user_ids->[0] || return undef;

    my $data = Dicole::Generictool::Data->new;
    $data->object(CTX->lookup_object('user'));
    $data->selected_where(list => {user_id => $user_ids});
    $data->data_group;

    defined($data->data->[0]) ? return $data->data : return undef;
}


=pod

=head2 _get_user_xml ( )

Returns XML data for user; used to construct chat user interface.

=cut

sub _get_user_xml {
    my $self = shift;

    # XXX: implement user info without authentication (?)

    my $user = $self->_auth_user;

    if ($user eq AUTH_INVALID) {
        # XXX: move this to template?
        return "<user>\n<userid>" . AUTH_INVALID . "</userid>\n</user>\n";
    }

    my $room = $self->_get_room({room_id => $self->{_params}->{room_id}});
    # convert displayname to UTF-8
    my $d_str = join(' ', $user->{first_name}, $user->{last_name});
    my $displayname = to_utf8({-string => $d_str, -charset => DICOLE_CHARSET});

    # XXX: profile url
    my $profile_url = 'http://chat.dicole.net/profile/professional/' . $user->{user_id};

    my $image_urls = $self->_get_image_urls($user->{user_id});

    my $user_data = {userID           => $user->{login_name},
                     displayname      => $displayname,
                     image_icon       => $image_urls->{icon},
                     image_thumb      => $image_urls->{thumb},
                     image_full       => $image_urls->{full},
                     profile_url      => $profile_url,
                     room_creator_id  => ROOM_CREATOR_ID,
                     room_name        => $room->{room_name},
                     initial_room     => $room->{room_name}};

    if (ADMIN_IDS->{$user_data->{userID}}) {
        $user_data->{admin} = 'true';
    } else {
        $user_data->{admin} = 'false';
    }

    return $self->generate_content($user_data,
                                   {name => 'dicole_chat_userplane::get_user_xml'});
}


=pod

=head2 _get_domain_preferences_xml ( )

Returns XML data for domain; used by Userplane Flash comminucation server.

=cut

sub _get_domain_preferences_xml {
    my $self = shift;

    my $domain_data = {};

    return $self->generate_content($domain_data,
                                   {name => 'dicole_chat_userplane::get_domain_preferences_xml'});
}

=pod

=head2 _auth_user ( )

Authenticates user to VC chat.

=cut

sub _auth_user {
    my $self = shift;

    my $key = CTX->request->param('key');

    unless($key eq AUTH_KEY) {
        return AUTH_INVALID;
    }

    my ($user, $login_name);

    eval { 
        $user = CTX->lookup_object('user')->fetch_by_login_name($self->{_params}->{sessionGUID}, 
                                                                {skip_security => 1});
        $login_name = $user->{login_name};
    };

    unless ($login_name) {
        return AUTH_INVALID;
    }

    my $group_id = $self->_get_room({room_id => $self->{_params}->{room_id}})->{group_id};
    my $group_found;

    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('groups') );
    $data->query_params( {
        from  => [ qw(dicole_groups dicole_group_user) ],
            where => "dicole_group_user.groups_id = dicole_groups.groups_id AND dicole_group_user.user_id = ?",
            value => [ $user->{user_id} ]
            } );
    $data->data_group;

    if (scalar(@{$data->data})) {
        foreach my $group (@{$data->data}) {
            if ($group_id == $group->{groups_id}) {
                $group_found = 1;
            }
        }
    }

    unless($group_found) {
        return AUTH_INVALID;
    }

    # XXX: is this needed?
    $self->{_params}->{userID} = $self->{_params}->{sessionGUID};

    return $user;
}

=pod

=head2 _get_image_urls ( SCALAR user_id )

Returns profile image urls for specified user. Used by Flash chat applet.

=cut

sub _get_image_urls {
    my ($self, $user_id) = @_;

    # XXX: if professional not found, return personal?

    unless($user_id) {
        return undef;
    }

    my $data = Dicole::Generictool::Data->new;
    $data->object(CTX->lookup_object('profile'));
    $data->query_params({
        where => 'user_id = ?',
        value => [$user_id]
    });
    $data->data_group;

    unless(defined($data->data->[0]->{USER_IMAGE_FIELD()})) {
        return undef;
    }

    my $full_url = $data->data->[0]->{USER_IMAGE_FIELD()};

    my $i      = rindex($full_url, FILENAME_SEPARATOR);
    my $suffix = substr($full_url, - (length($full_url - $i) + 1));
    my $url    = substr($full_url, 0, $i);

    my $thumb = $url . USER_IMAGE_THUMB_SUFFIX . $suffix;
    my $full  = $url . USER_IMAGE_FULL_SUFFIX  . $suffix;
    my $icon  = $url . USER_IMAGE_ICON_SUFFIX  . $suffix;

    my $ret = {thumb => $thumb,
               full  => $full,
               icon  => $icon};

    return $ret;
}

1;
