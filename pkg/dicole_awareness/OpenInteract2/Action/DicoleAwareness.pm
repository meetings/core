package OpenInteract2::Action::DicoleAwareness;

use strict;

use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::Widget::Listing;
use Dicole::Widget::Hyperlink;
use Dicole::Widget::Text;
use Dicole::Widget::Horizontal;
use Dicole::Generictool::Data;
use Dicole::Widget::Dropdown;
use Dicole::Widget::Image;
use Dicole::Widget::LinkImage;
use Dicole::Widget::Javascript;

use constant CONTROL_IMAGE_PATH => "/images/theme/default/navigation/controls";
use constant CONTROL_IMAGE_RES => "20x20";

use constant 
{
	SKYPE_ACTION_PREFIX => 'skype:',
	SKYPE_IMG_PREFIX => 'skype_',
	SKYPE_IMG_W => 16,
	SKYPE_IMG_H => 16,
	SKYPE_IMG_RES => '16x16',
	SKYPE_IMG_FORMAT => '.png'
};

use constant
{
	JS_SKYPECHECK_PATH => '/js/skypeCheck.js',
	JS_SKYPESTATUS_PATH => '/js/skypestatus.js'
};

our $VERSION = sprintf("%d.%02d", q$Revision: 1.50 $ =~ /(\d+)\.(\d+)/);

sub register_object_activity {
    my ( $self ) = @_;

    my $object = $self->param('object');
    my $object_id = $self->param('object_id') || ( $object ? $object->id : undef );
    my $object_type = $self->param('object_type') || ref( $object );

    return unless $object_id && $object_type;

    my $act = $self->param('act');

    my $domain_id = Dicole::Utils::Domain->guess_current_id( $self->param('domain_id') );
    my $user_id = $self->param('user_id') // CTX->request->auth_user_id;
    my $target_group_id = $self->param('target_group_id') || 0;
    my $target_user_id = $self->param('target_user_id') || 0;
    my $from_ip = $self->param('from_ip');

    if ( ! $from_ip ) {
        my $ip = CTX->request->cgi->http('X-Forwarded-For');
        my @ip = split /\s*[\s\,]\s*/, $ip;
        $from_ip = shift @ip;
    }
    my $referer = $self->param('referer') // CTX->request->cgi->referer;
    my $user_agent = $self->param('user_agent') // CTX->request->cgi->user_agent;

    my $time = $self->param('time') // time;

    CTX->lookup_object( 'object_activity' )->new({
        object_id => $object_id,
        object_type => $object_type,
        act => $act,
        domain_id => $domain_id,
        user_id => $user_id,
        target_group_id => $target_group_id,
        target_user_id => $target_user_id,
        from_ip => $from_ip,
        time => $time,
        referer => $referer,
        user_agent => $user_agent,
    })->save;
}

sub register_activity {
    my ( $self ) = @_;

    my $domain = eval { CTX->lookup_action('dicole_domains')->get_current_domain  };
    my $domain_id = $domain ? $domain->id : 0;

    return unless $domain_id == 133;
    
    my $action = CTX->controller->initial_action->name;

    # XXX: Maybe a better way to register certain actions/tasks to be skipped
    # from register activity at some point of time
    return undef if $action eq 'skype';

    my $class = CTX->lookup_object( 'logged_action' );
    return unless $class;

    my $o = $class->new;

    $o->time( time );
    $o->user_id( CTX->request->auth_user_id || 0 );
    $o->target_group_id( CTX->request->target_group_id || 0 );
    $o->target_user_id( CTX->request->target_user_id || 0 );
    $o->action( $action || '' );
    $o->task( CTX->controller->initial_action->task || '' );
    $o->url( CTX->request->url_relative || '' );
    $o->domain_id( $domain_id );

    $o->save;
}

sub time_elapsed_from_last_action_string_by_user_id {
    my ( $self ) = @_;

    my $epoch = $self->last_action_epoch_by_user_id;
    
    return $self->msg( 'Unknown' ) unless $epoch;
    
    my $time = time;
    my $elapsed = $time - $epoch;
    
    return $self->_msg('[_1] second(s)', int( $elapsed ) ) if ( $elapsed < 60 );
    return $self->_msg('[_1] minute(s)', int( $elapsed / 60 ) ) if ( $elapsed < 60*60 );
    return $self->_msg('[_1] hour(s)', int( $elapsed / 60 / 60 ) ) if ( $elapsed < 60*60*24 );
    return $self->_msg('[_1] day(s)', int( $elapsed / 60 / 60 / 24 ) );
}

sub when_online_string_by_user_id {
    my ( $self ) = @_;
    my $epoch = $self->last_action_epoch_by_user_id;
    return $self->epoch_to_when_string( $epoch );
}

sub epoch_to_when_string {
    my ( $self, $epoch ) = @_;
    $epoch ||= $self->param('epoch');
    return $self->msg( 'Never' ) unless $epoch;
    
    my $time = time;
    my $elapsed = $time - $epoch;
    
    return $self->_msg('Now' ) if ( $elapsed < 60*5 );
    return $self->_msg('[_1] minute(s) ago', int( $elapsed / 60 ) ) if ( $elapsed < 60*60 );
    return $self->_msg('[_1] hour(s) ago', int( $elapsed / 60 / 60 ) ) if ( $elapsed < 60*60*24 );
    return $self->_msg('[_1] day(s) ago', int( $elapsed / 60 / 60 / 24 ) );
}

sub last_action_epoch_by_user_id {
    my ( $self ) = @_;

    my $action = $self->last_action_by_user_id;
    
    return $action ? $action->time : 0;
}

sub last_action_by_user_id {
    my ( $self ) = @_;

    my $user_id = $self->param('user_id');

    my $objs = CTX->lookup_object('logged_action')->fetch_group( {
            sql => 'SELECT dicole_logged_action.logged_action_id, dicole_logged_action.time, dicole_logged_action.user_id, dicole_logged_action.target_group_id, dicole_logged_action.target_user_id, dicole_logged_action.action, dicole_logged_action.task, dicole_logged_action.url, dicole_logged_action.domain_id FROM dicole_logged_action WHERE user_id = ? ORDER BY time DESC LIMIT 1',
#             where  => 'user_id = ?',
             value  => [ $user_id ],
#             order  => 'time DESC',
#             limit => 1,
    }) || [];
    
    return pop @$objs;
}

sub online_users_logged_actions {
    my ( $self ) = @_;

    my $time = time;
    $time -= CTX->server_config->{dicole}{online_timeout} || 600;

    my $class = CTX->lookup_object('logged_action');

    my $objs = $class->fetch_group( {
            where  => 'time > ?',
            value  => [ $time ],
            order  => 'time DESC',
    }) || [];

    my %check = ();
    my @return = ();

    for my $o ( @$objs ) {
        next if $check{ $o->user_id };
        $check{ $o->user_id }++;
        push @return, $o if ! lc $o->action =~ /logout/;
    }

    return \@return;
}

sub last_active_users {
    my ( $self ) = @_;

    my $gid = $self->param('group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id( $self->param('domain_id') );

    my $limit = $self->param('limit') || 10;
    my $exclude_users = $self->param('exclude_users') || [];

    my @actions_on_last_time = ();
    my $last_time = 0;
    my %found_users = ();
    my @user_ids = ();
    while ( scalar( @user_ids ) < $limit ) {
        # OI2 fetch_group limit is broken so need to use direct sql
        # (we really need the limit here ;))
        # also we need to force the syntax because mysql tries to use user_id based index :/
        my $candidates = CTX->lookup_object('logged_action')->fetch_group( {
            sql => 'select * from dicole_logged_action ignore index (user_id)' .
                ' where domain_id = ' . $domain_id .
                ( ( $last_time ) ? ' and time <= ' . $last_time : '' ) .
                ( ( $gid ) ? ' and target_group_id = ' . $gid : '' ) .
                ' and ' . Dicole::Utils::SQL->column_not_in( user_id => [ 0, @$exclude_users ] ) .
                ' and ' . Dicole::Utils::SQL->column_not_in( logged_action_id => \@actions_on_last_time ) .
                ' order by time desc limit 500',
        } ) || [];

        last unless scalar( @$candidates );

        for my $cand ( @$candidates ) {
            if ( $last_time != $cand->time ) {
                @actions_on_last_time = ( $cand->id );
                $last_time = $cand->time;
            }
            else {
                push @actions_on_last_time, $cand->id;
            }

            next if $found_users{ $cand->user_id }++;
            next if $gid && ! Dicole::Utils::User->belongs_to_group( $cand->user_id, $gid );
            push @user_ids, $cand->user_id;
            last if scalar( @user_ids ) == $limit;
        }
    }

    return \@user_ids;
}

# Retrieves users profile object or creates
# one if it does not exist.
# should be deprecated already..
sub _get_profile {
    my ( $self, $user_id ) = @_;
    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('profile') );
    $data->query_params( {
        where => 'user_id = ?',
        value => [ $user_id ]
    } );
    $data->data_group;
    $data->data( $data->data->[0] );
    if ( !ref( $data->data) || ref( $data->data ) eq 'ARRAY' ) {
        $data->data_new( 1 );
        $data->data->{user_id} = $user_id;
        $data->data_save;
    }
    return $data->data;
}

sub user_information_list {
    my ( $self ) = @_;

    my $users = $self->param('users');
    my $user_ids = $self->param('user_ids');
    my $browse_enabled = $self->param('browse_enabled');
    my $browse_action = $self->param('browse_action');
#    my $sort_by_activity = $self->param('sort_by_activity');
    my $group_id = $self->param('group_id') || CTX->request->target_group_id;
    
    my $browse;
    if ( ! $users ) {
     
        my $where = '1=1';
        if ( $user_ids ) {
            $where = Dicole::Utils::SQL->column_in( 'user_id', $user_ids );
        }
        
        if ( $browse_enabled ) {
            my $total_count = CTX->lookup_object('user')->fetch_count( {
                where => $where,
            } );
            
            $browse_action ||= CTX->request->action_name . '_' .
                    $self->param('target_user_id') . '_' .
                    $self->param('target_group_id');
             
            $browse = Dicole::Generictool::Browse->new( {
                action => [ $browse_action ]
            } );
            
            $browse->default_limit_size( 50 );
            $browse->set_limits;
            $browse->total_count( $total_count );
            
            if ( $total_count && $total_count <= $browse->limit_start ) {
                my $raw_pages = $total_count / $browse->limit_size;
                my $actual_pages = int( $raw_pages );
                $actual_pages -= 1 if $raw_pages == $actual_pages;
                $browse->set_limits( $actual_pages * $browse->limit_size );
            }
        }
        
        $users = CTX->lookup_object('user')->fetch_group( {
            where => $where,
#             order => $sort_by_activity ? 'latest_activity DESC, last_login DESC' : undef,
            limit => $browse ? $browse->get_limit_query : undef,
        } ) || [];
    }

    return unless scalar( @$users );
    $user_ids = [ map { $_->{user_id} } @$users ];

#     # Fetch or create profile data for all of the users
#     my $profile_object = CTX->lookup_object('profile');
#     my $profiles = $profile_object->fetch_group( {
#         where => Dicole::Utils::SQL->column_in( 'user_id', $user_ids ),
#     } ) || [];
#     
#     my %profiles_by_uid = map { $_->{user_id} => $_ } @$profiles;
#     
#     for my $uid ( @$user_ids ) {
#         next if $profiles_by_uid{ $uid };
#         
#         my $profile = $profile_object->new;
#         $profile->user_id( $uid );
#         $profile->save;
#         
#         push @$profiles, $profile;
#         $profiles_by_uid{ $uid } = $profile;
#     }

    # Fetch weblog topics for blog security checking
#     my $topics = CTX->lookup_object('weblog_topics')->fetch_group( {
#         where => Dicole::Utils::SQL->column_in( 'user_id', $user_ids ),
#     } ) || [];
    my $topics = [];
    
    my %topics_by_uid = ();
    for my $topic ( @$topics ) {
        $topics_by_uid{ $topic->{user_id} } ||= [];
        push @{ $topics_by_uid{ $topic->{user_id} } }, $topic;
    }
    
    my $list = Dicole::Widget::Listing->new(
        use_keys => 0,
        widths => [ '2%', '49%', '49%' ],
    );
    
    my $networking_action = CTX->lookup_action('networking');
    my $profile_hash = $networking_action->_get_profile_objects_hash( $user_ids );
    
    for my $user ( @$users ) {
        $list->new_row;
        my @row = $self->_create_user_row(
            $user,
#            $profiles_by_uid{ $user->id },
            $profile_hash->{ $user->id },
#            $topics_by_uid{ $user->id },
            $networking_action,
            $group_id,
        );
        
        foreach my $item ( @row ) {
            $list->add_cell( content => $item );
        }
    }
    
    
    if ( $browse ) {
        my $browse_content = $browse->get_browse;
        if ( $browse_content ) {
            return Dicole::Widget::Vertical->new(
                contents => [
                    $browse_content,
                    $list,
                    $browse->get_browse,
                ],
            );
        }
    }

    return $list;
}

sub _group_online_summary {
    my ( $self ) = @_;

    my $box = Dicole::Box->new();
    
    my $title = Dicole::Widget::Horizontal->new;
    my $more_url = Dicole::URL->create_from_parts(
        action => 'networking',
        task => 'explore',
        target => CTX->request->target_group_id,
    );

    $title->add_content(
        Dicole::Widget::Hyperlink->new(
            content => $self->_msg('Online members'),
            link => $more_url,
        )  
    );

    $box->name( $title->generate_content );

    my $group = CTX->request->target_group;
    return unless $group;

    my $logged = $self->online_users_logged_actions || [];
    my %idcheck = map { $_->user_id => 1 } @$logged;
    my @online_ids = keys %idcheck;
    my $group_online_ids = Dicole::Utils::User->filter_list_to_group_members( \@online_ids, $group->id );

    # Don't show current user. EDIT: show current user :D
    # delete $idcheck{ CTX->request->auth_user_id };

    my $user_data = Dicole::Utils::User->icon_hash_list(
        $group_online_ids, 40,
        CTX->controller->initial_action->param('target_group_id'),
        CTX->controller->initial_action->param('domain_id'),
    );

    my $params = { users => $user_data, more_users_url => $more_url };

    $params->{dump} = Data::Dumper::Dumper( $params );

    $box->content( Dicole::Widget::Raw->new( raw => 
        $self->generate_content( $params, { name => 'dicole_awareness::group_online_users' } )
    ) );

    return $box->output;
}

sub _old_group_online_summary {
    my ( $self ) = @_;

    my $box = Dicole::Box->new();
    
    my $title = Dicole::Widget::Horizontal->new;

    $title->add_content(
        Dicole::Widget::Hyperlink->new(
            content => $self->_msg('Online members'),
            link => Dicole::URL->create_from_parts(
                action => 'networking',
                task => 'explore',
                target => CTX->request->target_group_id,
            ),
        )  
    );

    $box->name( $title->generate_content );

    my $group = CTX->request->target_group;
    return unless $group;

    my $logged = $self->online_users_logged_actions || [];
    my %idcheck = map { $_->user_id => 1 } @$logged;
    my @online_ids = keys %idcheck;
    my $group_online_ids = Dicole::Utils::User->filter_list_to_group_members( \@online_ids, $group->id );

    # Don't show current user. EDIT: show current user :D
    # delete $idcheck{ CTX->request->auth_user_id };

    my $list = CTX->lookup_action('user_information_list')->execute( {
        user_ids => $group_online_ids,
    } );

    # Set the actual content
    if ( $list ) {
        $box->content( $list );
    }
    else {
        $box->content( Dicole::Widget::Text->new(
            text => $self->_msg( 'No online members.' ),
        ) );
    }

    # Add required js for Skype status checking if necessary
    # my @skype_js = $self->_create_skype_js();
    # $box->add_content( $_ ) for @skype_js;

    return $box->output;
}

# Creates an array that contains one users information
# (picture, real name, contact links) and returns it.
sub _create_user_row  {
#	my ($self, $user, $profile, $topics, $networking_action ) = @_;
    my ($self, $user, $profile, $networking_action, $group_id ) = @_;
	my @row;

    # this kind of sucks, but since there is no popup widget yet...
#     my $link = qq{javascript:void(window.open('/profile_popup/professional/} .
#         $user->id . qq{', 'profile', 'toolbar=no,menubar=no,} .
#         qq{statusbar=no,scrollbars=yes,width=640,height=480'))};

    my $link = Dicole::URL->from_parts(
        action => 'networking',
        task => 'profile',
        target => $group_id,
        additional => [ $user->id ],
    );

    # Use the thumbnail version
#     $profile->{pro_image} =~ s/(\.\w+)$/_t$1/;
# 
#     # Get the profile image
#     my $image = $profile->{pro_image}
#         ? Dicole::Widget::Image->new(
#             src => $profile->{pro_image},
#             class => 'profileImage'
#         )
#         : undef;

    my $image = Dicole::Widget::Image->new(
        src => $networking_action->_get_portrait_thumb( $profile ),
        alt => $user->first_name . ' ' . $user->last_name,
        class => 'user_information_list_portrait',
    );

	# Add the profile image and users real name
	push @row, $image;
	push @row, Dicole::Widget::Hyperlink->new(
        content => $user->first_name . ' ' . $user->last_name,
        link => $link
    );
        
	# Create and add the contact icon list
#	my $icons = $self->_create_icon_list( $user, $profile, $topics );
   my $icons = $self->_create_icon_list( $user, $profile );
	push @row, $icons;

	return @row;
}

# Creates an array that contains the necessary javascripts for Skype status
# updating.
sub _create_skype_js {
	my @scripts;

	# Add the Skype checking js
	push @scripts, Dicole::Widget::Javascript->new(
		src => JS_SKYPECHECK_PATH
	);
	# Add the Skype status js
	push @scripts, Dicole::Widget::Javascript->new(
		src => JS_SKYPESTATUS_PATH
	);

	return @scripts;
}

# Creates the icon list for different contact methods (skype, email, etc)
# for user $user with profile information in $profile.
sub _create_icon_list {
    my ($self, $user, $profile, $topics) = @_;

    my $icons = Dicole::Widget::Horizontal->new( class => 'controlImages' );

    return $icons unless CTX->request->auth_user_id;

#     my $show_blog = $self->mchk_y(
#         'OpenInteract2::Action::Weblog', 'user_read', $user->id
#     );
#     if ( ! $show_blog ) {
#         for my $topic ( @$topics ) {
#             if ( $self->mchk_y(
#                'OpenInteract2::Action::Weblog', 'user_read_topic', $topic->id,
#             ) ) {
#                 $show_blog = 1;
#                 last;
#             }
#         }
#     }
# 
#     $icons->add_content( Dicole::Widget::LinkImage->new(
#         src => CONTROL_IMAGE_PATH . '/' . CONTROL_IMAGE_RES . '/blog.gif',
#         link => Dicole::URL->create_from_parts(
#             action => 'personal_weblog', task => 'posts',
#             target => $profile->{user_id},
#         ),
#         width => '20',
#         height => '20',
#         alt => $self->_msg( 'Weblog' )
#     ) ) if $show_blog;

    # Add the Skype status icon with dropdown here
#    if ( $profile->{skype} ) {
    if ( $profile->{contact_skype} ) {
        my $dd = $self->_create_skype_dropdown(
#            $profile->{skype},
            $profile->{contact_skype},
            $user->id
        );
        $icons->add_content( $dd );
    }

#     # Add the other contact icons
#     $icons->add_content( Dicole::Widget::LinkImage->new(
#             src => CONTROL_IMAGE_PATH . '/' . CONTROL_IMAGE_RES . '/icq.gif',
#             link => 'http://web.icq.com/wwp?Uin=' . $profile->{icq_number},
#             target => '_blank',
#             width => '20',
#             height => '20',
#             alt => 'ICQ'
#     ) ) if $profile->{icq_number};
#     $icons->add_content( Dicole::Widget::LinkImage->new(
#         src => CONTROL_IMAGE_PATH . '/' . CONTROL_IMAGE_RES . '/aim.gif',
#         link => 'aim:GoIM?ScreenName=' . $profile->{aim_screenname},
#         width => '20',
#         height => '20',
#         alt => 'AIM'
#     ) ) if $profile->{aim_screenname};
#     $icons->add_content( Dicole::Widget::LinkImage->new(
#         src => CONTROL_IMAGE_PATH . '/' . CONTROL_IMAGE_RES . '/msn.gif',
#         link => 'mailto:' . $profile->{msn_profile},
#         width => '20',
#         height => '20',
#         alt => 'MSN'
#     ) ) if $profile->{msn_profile};
    $icons->add_content( Dicole::Widget::LinkImage->new(
        src => CONTROL_IMAGE_PATH . '/' . CONTROL_IMAGE_RES . '/blog.gif',
#        link => $profile->{weblog_url},
        link => $profile->{personal_blog},
        target => '_blank',
        width => '20',
        height => '20',
        alt => $self->_msg( 'Weblog' )
    ) ) if $profile->{personal_blog};
#    ) ) if $profile->{weblog_url};

#     $icons->add_content( Dicole::Widget::LinkImage->new(
#         src => CONTROL_IMAGE_PATH . '/' . CONTROL_IMAGE_RES . '/jabber.gif',
#         link => 'mailto:' . $profile->{jabber},
#         width => '20',
#         height => '20',
#         alt => 'Jabber'
#     ) ) if $profile->{jabber};

    $icons->add_content( Dicole::Widget::LinkImage->new(
        src => CONTROL_IMAGE_PATH . '/' . CONTROL_IMAGE_RES . '/email.gif',
#        link => 'mailto:' . $profile->{mail},
        link => 'mailto:' . $profile->{contact_email},
        width => '20',
        height => '20',
        alt => $self->_msg( 'Email' )
    ) ) if $profile->{contact_email};
#    ) ) if $profile->{mail};

	return $icons;
}

# Creates the Skype dropdown menu for user $skype_name and Dicole user id $uid 
# containing links to different Skype actions eg. (skype:infe00?call) 
sub _create_skype_dropdown {
	my ($self, $skype_name, $uid) = @_;
		
	my $dd_image = Dicole::Widget::LinkImage->new(
		src => CONTROL_IMAGE_PATH . '/' . CONTROL_IMAGE_RES .
		'/skype.gif',
		id => 'skype_icon_user_' . $uid,
		link => '#',
		onclick => 'return skypeCheck();',
		width => '20',
		height => '20',
		alt => 'Skype'
	);

	my $dropdown = Dicole::Widget::Dropdown->new(
		title => $self->_msg('Skype menu for user') . ' ' . $skype_name,
		image => $dd_image
	);

	# TODO: move to use constant %SKYPE_ACTIONS ?
	my %SKYPE_ACTIONS = (
		call => $self->_msg('Call user'),
		add => $self->_msg('Add user to contact list'),
		chat => $self->_msg('Start a text chat with user'),
		userinfo => $self->_msg('Show the Skype profile of user'),
		sendfile => $self->_msg('Send a file to user')
	);

	# Make the dropdown menu from skype actions hash
	for my $key ( sort keys %SKYPE_ACTIONS ) {
		my $link = SKYPE_ACTION_PREFIX . $skype_name . '?' . $key;
		my $text = $SKYPE_ACTIONS{$key};
		my $icon = Dicole::Widget::Image->new(
			src => CONTROL_IMAGE_PATH . '/' .
			SKYPE_IMG_RES . '/' . 
			SKYPE_IMG_PREFIX . 
			$key . SKYPE_IMG_FORMAT,
			width => SKYPE_IMG_W,
			height => SKYPE_IMG_H,
			alt => $key
		);

		# Add one action element
		$dropdown->add_element(
			link => $link,
			text => $text,
			icon => $icon
		);
	}

	return $dropdown;
}

sub create_share_this_box {
    my ( $self ) = @_;

    return unless CTX->controller->initial_action->param('domain_name') =~ /work\-dev|thelanguagepoint/;
    
    my $return = eval {
        my ( $fb_id, $fb_secret, $fb_disabled ) = Dicole::Utils::Domain->resolve_facebook_connect_settings;

        my $html = <<CODE;
<center>
<div id="fb-root"></div>
<script>(function(d, s, id) {
  var js, fjs = d.getElementsByTagName(s)[0];
  if (d.getElementById(id)) return;
  js = d.createElement(s); js.id = id;
  js.src = "//connect.facebook.net/en_GB/all.js#xfbml=1&appId=$fb_id";
  fjs.parentNode.insertBefore(js, fjs);
}(document, 'script', 'facebook-jssdk'));</script>

<script src="//platform.linkedin.com/in.js" type="text/javascript"></script>
<script type="IN/Share" data-counter="top"></script>


&nbsp;
<!-- Place this tag where you want the +1 button to render -->
<g:plusone size="tall"></g:plusone>

<!-- Place this render call where appropriate -->
<script type="text/javascript">
  (function() {
    var po = document.createElement('script'); po.type = 'text/javascript'; po.async = true;
    po.src = 'https://apis.google.com/js/plusone.js';
    var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(po, s);
  })();
</script>

&nbsp;
<a href="https://twitter.com/share" data-count="vertical" class="twitter-share-button">Tweet</a>
<script>!function(d,s,id){var js,fjs=d.getElementsByTagName(s)[0];if(!d.getElementById(id)){js=d.createElement(s);js.id=id;js.src="//platform.twitter.com/widgets.js";fjs.parentNode.insertBefore(js,fjs);}}(document,"script","twitter-wjs");</script>

&nbsp;
<style>.fb-like span{height:65px !important;}</style>
<div class="fb-like" data-send="false" data-layout="box_count" data-width="50" data-show-faces="false" data-action="like"></div>
</center>
CODE
        # TODO? data-via="sanako" data-related="sanako" to twitter after class?
        
        my $class = $self->param('class');

        return {
            name => $self->_msg('Share this'),
            content => Dicole::Widget::Raw->new( raw => $html ),
            class => $class ? $class : 'share_this_box',
        }
    };
    if ( $@ ) {
        get_logger(LOG_APP)->error($@);
    } 

    return $return;
}

sub add_open_graph_properties {
    my ( $self ) = @_;

    my $type = $self->param('type') || 'website';

    my $site_name = $self->param('site_name');
    if ( ! $site_name && CTX->controller->initial_action->param('target_group') ) { 
       $site_name = CTX->controller->initial_action->param('target_group')->name;
    }

    my $title = $self->param('title');
    if ( $title && $site_name ) {
        $title .= ' (' . $site_name . ')';
    }

    my $url = $self->param('url') || CTX->controller->initial_action->derive_url;

    # NOTE: image must be 200x200 or larger!
    my @images = ( $self->param('image') || () );

    if ( my $html = $self->param('images_from_html') ) {
        my $tree = Dicole::Utils::HTML->safe_tree( $html );
        for my $img ( $tree->find('img') ) {
            push @images, $img->attr('src') || ();
        }
    }

    push @images, CTX->lookup_action( 'domains_api' )->e( get_domain_logo_url => {} ) || ();

    for my $uri ( $url, @images ) {
        next unless $uri;
        next if $uri =~ /^http/;
        my $host = Dicole::URL->get_server_url;
        $uri = $host . $uri;
    }

    my $description = $self->param('description');
    $description = Dicole::Utils::Text->shorten( $description, 250 );
    $description =~ s/\n/ /g;

    my %props = (
        type => $type,
        title => $title,
        url => $url,
        description => $description,
        site_name => $site_name,
    );

    my @props = ();
    for my $key ( keys %props ) {
        next unless $props{ $key };
        push @props, { property => 'og:' . $key, content => $props{ $key } };
    }

    for my $image ( @images ) {
        push @props, { property => 'og:image', content => $image };
    }

    CTX->controller->add_content_param( meta_properties => \@props );
}

1;

