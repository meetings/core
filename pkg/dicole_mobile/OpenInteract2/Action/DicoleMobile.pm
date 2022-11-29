package OpenInteract2::Action::DicoleMobile;

# $Id: DicoleMobile.pm,v 1.44 2009-01-07 14:42:33 amv Exp $
# TODO: get things done

use strict;
use Dicole::Action;
use OpenInteract2::Context qw( CTX );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log SESSION_COOKIE );
use Dicole::Security::Encryption;
use Dicole::URL;
use OpenInteract2::SessionManager;
use Dicole::DateTime;
use Unicode::MapUTF8;

use base qw( Dicole::Action );
our $VERSION = sprintf( "%d.%02d", q$Revision: 1.44 $ =~ /(\d+)\.(\d+)/ );

our @ALLOWED_TOOLS = qw(group_wiki group_weblog group_feed_reader);

# Logs in the user into Dicole

sub login {
    my ( $self ) = @_;
    
    my %login_params = (
    	login_name    => CTX->request->param( 'login_login_name' ),
        login_message => undef,
	);  
    

    # Get configuration related to login
    my $login_config = CTX->lookup_login_config;

    # If user is logged in...
    if ( CTX->request->auth_is_logged_in ) {

        # If password was provided, catch it and encrypt it with AES-256.
        # Uses dynamic key for encryption, so no-one knows the key expect
        # the server. Store into user session.
        if ( CTX->request->param( $login_config->{password_field} ) ) {
            my $store = CTX->request->param( $login_config->{password_field} );
            my $sec = Dicole::Security::Encryption->new;
            $sec->use_dynamic( 1 );
            $store = $sec->encrypt( $store );
            CTX->request->session->{login_password} = $store;
        }

        # Increment ammount of logins the user has made. This
        # function also resets the expiration date of the user account.
        CTX->request->auth_user->increment_login;

        CTX->request->auth_user->{last_login} = DateTime->now;
        CTX->request->auth_user->save;

        # The default is to use action parameters action_after_login and
        # task_after_login to determine where to go once the user has logged in.
        # TODO: user-specific action after login
        my $uri = Dicole::URL->create_from_current(
            action => $self->param( 'action_after_login' ),
            task => $self->param( 'task_after_login' ),
        );

        # URL after login is usually set in the GET parameters
        # if the session gets timed out. When the user logins again
        # he is forwarded to the previous page.
        if ( CTX->request->param( 'url_after_login' ) ) {
            $uri = CTX->request->param( 'url_after_login' );
        }
        
        return CTX->response->redirect( $uri );
    }

    # If login buttom is pressed...
    if ( CTX->request->param( 'login' ) ) {    
	    unless ( CTX->request->auth_is_logged_in ) {
            $login_params{ login_message } = $self->_msg( 'Login failure. Please check your username and password.' );
        }
    }
    elsif ( CTX->request->param('logout') == 1 ) {
            $login_params{ login_message } = $self->_msg( 'Thank you for using our system. Always remember to log out after you are done to ensure your own privacy.' );
    }
    elsif ( CTX->request->param('logout') == 2 ) {
            $login_params{ login_message } = $self->_msg( 'Session was not found, this probably means the session timed out. Please login again to proceed.' );
    }
    elsif ( CTX->request->param('logout') == 3 ) {
            $login_params{ login_message } = $self->_msg( CTX->request->param( 'msg' ) );
    }

	CTX->controller->no_template( 'yes' );

    return $self->generate_content(
        \%login_params,
        { name => 'dicole_mobile::mobile_login' }
    );
}

# Logs the user out of Dicole

sub logout {
    my ( $self ) = @_;

    # Clear authentication from this action, delete old session
    # object and create a new anonymous session with the language
    # of the logged out user.

    my $lang = CTX->request->session->{lang}{code};

    CTX->request->auth_clear;
    OpenInteract2::SessionManager->delete_session( CTX->request->session );

    CTX->request->session( { language => $lang } );

    my $uri = Dicole::URL->create_from_current(
    	action => 'm',
    	task   => 'login',
    	params => { logout => 1 }
    );

    return CTX->response->redirect( $uri );
}

# Displays the main menu for accessing mobile features

sub menu {
	my ( $self ) = @_;
    
    unless ( CTX->request->auth_is_logged_in ) {
	    return CTX->response->redirect( Dicole::URL->create_from_current(
    		action => 'm',
    		task   => 'login',
    		params => { logout => 2, url_after_login => '/m/menu' }
	    ) );
    }
    
    my %menu_params = (
    	firstname => CTX->request->auth_user->{first_name},
        lastname  => CTX->request->auth_user->{last_name},
	);

	CTX->controller->no_template( 'yes' );

    return $self->generate_content(
        \%menu_params,
        { name => 'dicole_mobile::mobile_menu' }
    );
	
}

# Displays blog posts from the personal blog

sub blog_posts {
	my ( $self ) = @_;

	CTX->controller->no_template( 'yes' );

  	my %menu_params = ();
    
    if ( CTX->request->target_id =~ m/^\d+$/ ) {
		my $blog_post = CTX->lookup_object( 'weblog_posts' )->fetch( CTX->request->target_id, { skip_security => 1 } );
		return "Unauthorized access." if $blog_post->{user_id} != CTX->request->auth_user_id;
		$blog_post->{date} = Dicole::DateTime->medium_datetime_format( $blog_post->{date} );
		$menu_params{post} = $blog_post;
		$menu_params{author} = CTX->request->auth_user->{first_name} . ' ' . CTX->request->auth_user->{last_name};
    	return $self->generate_content(
        	\%menu_params,
        	{ name => 'dicole_mobile::mobile_post' }
 	    );
    }	
	else {
	    my $blog_posts = CTX->lookup_object( 'weblog_posts' )->fetch_group( {
    		where => 'groups_id = 0 AND user_id = ?',
        	value => [ CTX->request->auth_user_id ],
        	order => 'date DESC',
	    } );
    
		$menu_params{posts} = $blog_posts;

    	return $self->generate_content(
        	\%menu_params,
        	{ name => 'dicole_mobile::mobile_posts' }
 	    );
	}
}

# Displays feed reader items from the group feed reader

sub group_feed_reader {
	my ( $self ) = @_;
	
	CTX->controller->no_template( 'yes' );

  	my %menu_params = ();
    my $gid = $self->param('target_id' );

    $menu_params{group} = CTX->request->auth_user_groups_by_id->{ $gid };
    return "Unauthorized access." unless $menu_params{group};

	if ( $self->param( 'post_id' ) ) {
		my $post = CTX->lookup_object('feeds_items')->fetch( $self->param( 'post_id' ), { skip_security => 1 } );

		my $post_content = {};
   		$post_content->{date} = Dicole::DateTime->medium_datetime_format( $post->{date} );
		$post_content->{title} = $self->_convert_from_utf8( $post->{title} );
	    $post_content->{author} = $self->_convert_from_utf8( $post->{author} );
	    $post_content->{'link'} = $self->_convert_from_utf8( $post->{link} );
	    $post_content->{content} = $self->_convert_from_utf8( $post->{content} );
	    my $feed = CTX->lookup_object('feeds')->fetch( $post->{feed_id} );
        $post_content->{source} = $self->_convert_from_utf8( $feed->{title} );

		$menu_params{post} = $post_content;

    	return $self->generate_content(
        	\%menu_params,
        	{ name => 'dicole_mobile::mobile_feed_post' }
 	    );
	}
	else {
		my $items = CTX->lookup_object('feeds_items')->fetch_group( {
    		from  => [ 'dicole_feeds_items', 'dicole_feeds_users' ],
        	where => 'dicole_feeds_users.feed_id = dicole_feeds_items.feed_id' .
        		' AND dicole_feeds_users.group_id = ?' .
            	' AND dicole_feeds_items.first_fetch_date < ?',
        	value => [ $gid, time ],
        	order => 'dicole_feeds_items.first_fetch_date DESC',
        	limit => '100'
		} );
		my $feed_name_cache = {};
		my $posts = [];
		foreach my $item ( @$items ) {
			my $post = {};
			$post->{title} = $self->_convert_from_utf8( $item->{title} );
	        $post->{id} = $item->id;
        	push @$posts, $post;
		}
		$menu_params{posts} = $posts;

    	return $self->generate_content(
        	\%menu_params,
        	{ name => 'dicole_mobile::mobile_feed_posts' }
 	    );
		
	}
}

# Displays blog posts from the group blog

sub group_weblog {
	my ( $self ) = @_;

	CTX->controller->no_template( 'yes' );

  	my %menu_params = ();
    my $gid = $self->param('target_id' );
    
    $menu_params{group} = CTX->request->auth_user_groups_by_id->{ $gid };
    return "Unauthorized access." unless $menu_params{group};
    
	if ( $self->param( 'post_id' ) ) {
		my $blog_post = CTX->lookup_object( 'weblog_posts' )->fetch( $self->param( 'post_id' ), { skip_security => 1 } );
   		$blog_post->{date} = Dicole::DateTime->medium_datetime_format( $blog_post->{date} );
		$menu_params{post} = $blog_post;
		my $user = CTX->lookup_object( 'user' )->fetch( $blog_post->{writer}, { skip_security => 1 } );
		$menu_params{author} = $user->{first_name} . ' ' . $user->{last_name};
		$menu_params{post}{content} =~ s{/wiki/show/}{/m/group_wiki/}gms;
		$menu_params{post}{abstract} =~ s{/wiki/show/}{/m/group_wiki/}gms;
    	return $self->generate_content(
        	\%menu_params,
        	{ name => 'dicole_mobile::mobile_post' }
 	    );
    }	
	else {
	    my $blog_posts = CTX->lookup_object( 'weblog_posts' )->fetch_group( {
    		where => 'groups_id = ?',
        	value => [ $gid ],
        	order => 'date DESC',
	    } );
    
		$menu_params{posts} = $blog_posts;

    	return $self->generate_content(
        	\%menu_params,
        	{ name => 'dicole_mobile::mobile_posts' }
 	    );
	}
}

# Displays wiki pages

sub group_wiki {
	my ( $self ) = @_;

	CTX->controller->no_template( 'yes' );

  	my %menu_params = ();
    my $gid = $self->param('target_id' );
    
    $menu_params{group} = CTX->request->auth_user_groups_by_id->{ $gid };
    return "Unauthorized access." unless $menu_params{group};
	
	unless ( $self->param( 'title' ) ) {
	    my $pages = CTX->lookup_object('wiki_page')->fetch_group( {
    	    where => 'groups_id = ?',
        	value => [ $gid ],
        	order => 'readable_title',
	    } );
    
		$menu_params{wiki_pages} = $pages;
		
 		return $self->generate_content(
       		\%menu_params,
       		{ name => 'dicole_mobile::mobile_wiki_pages' }
	    );
	}
	else {
 		my $action = CTX->lookup_action( 'wiki' );
        my $page = $action->_fetch_page( $self->param( 'title' ), undef, $gid );

		$menu_params{wiki_readable_title} = $page->readable_title;
		$menu_params{wiki_title} = $page->title;
		$menu_params{wiki_date} = Dicole::DateTime->medium_datetime_format( $page->{last_modified_time} );
    	my $sections = $action->_current_sections_for_page( $page );
    	$action->_filter_outgoing_links( $page, $sections );
    	$menu_params{wiki_content} = $action->_sections_to_html( $sections );
	    $menu_params{wiki_content} =~ s{/wiki/show/}{/m/group_wiki/}gms;
	    
 		return $self->generate_content(
    	   	\%menu_params,
    	   	{ name => 'dicole_mobile::mobile_wiki_page' }
    	);
	}
}

# Lists groups the user belongs to, also tools that belong to a group

sub groups {
	my ( $self ) = @_;

	CTX->controller->no_template( 'yes' );

    unless ( CTX->request->auth_is_logged_in ) {
	    return CTX->response->redirect( Dicole::URL->create_from_current(
    		action => 'm',
    		task   => 'login',
    		params => { logout => 2, url_after_login => '/m/groups' }
	    ) );
    }

  	my %menu_params = ();

    my $gid = $self->param('target_id' );
    
    if ( $gid =~ m/^\d+$/ ) {

	    $menu_params{group} = CTX->request->auth_user_groups_by_id->{ $gid };
    	return "Unauthorized access." unless $menu_params{group};

		$menu_params{tools} = $self->_fetch_group_tools( $menu_params{group} );
    	return $self->generate_content(
        	\%menu_params,
        	{ name => 'dicole_mobile::mobile_group' }
 	    );
    }
	else {
		$menu_params{groups} = $self->_fetch_user_groups;

    	return $self->generate_content(
        	\%menu_params,
        	{ name => 'dicole_mobile::mobile_groups' }
 	    );
	}	
}

# Fetches group tools

sub _fetch_group_tools {
	my ( $self, $group ) = @_;
	my $tools = [];
	
	eval {
		$group->tool;
    	my @tools = ();
        foreach my $tool ( @{ $group->tool } ) {
        	# Skip externally integrated tools and tools that are not in the list of allowed tools
        	# Remove this allowed tools check once all tools are implemented or have a way to announce
        	# mobile capability
            push @tools, $tool if $tool->{package} ne '-external integrator-' && grep { $tool->{toolid} eq $_ } @ALLOWED_TOOLS;
        }
        $tools = \@tools;
	};

	return $tools;	
}

# Fetches groups the user belongs to

sub _fetch_user_groups {
	my ( $self ) = @_;
	my $groups = CTX->lookup_object( 'groups' )->fetch_group( {
       	from => [ qw(dicole_groups dicole_group_user) ],
       	where => 'dicole_groups.has_area = 1 AND dicole_group_user.groups_id = dicole_groups.groups_id AND dicole_group_user.user_id = ?',
       	value => [ CTX->request->auth_user_id ],
       	order => 'name',
    } );

    eval {
    	my @domain_groups = ();
        my $ids = CTX->lookup_action( 'dicole_domains' )
            ->execute( 'groups_by_domain' );
        my %idcheck = map { $_ => 1 } @$ids;
        for ( @$groups ) {
            push @domain_groups, $_ if $idcheck{ $_->id };
        }
        $groups = \@domain_groups;
    };
    
	return $groups;
}

# Convert from UTF8 to iso-8859-1. Temporary for feed processing

sub _convert_from_utf8 {
    my ( $self, $content ) = @_;
    
    # Disabled after change to utf-8
    return $content;
    
    if ( ref $content ) {
        # Data is in UTF8 in the database. Do a conversion for now
        foreach my $field ( @{ $content->field_list } ) {
            $content->{$field} = Unicode::MapUTF8::from_utf8( {
                -string => $content->{$field}, -charset => 'iso-8859-1'
            } );
        }
    }
    else {
        $content = Unicode::MapUTF8::from_utf8( {
            -string => $content, -charset => 'iso-8859-1'
        } );
    }
    return $content;
}

1;

__END__

=pod

=head1 NAME

OpenInteract::Handler::DicoleMobile - Handler for Mobile access

=head1 DESCRIPTION

A page handler for mobile access

=head1 METHODS

Test

=head1 BUGS

Test

=head1 TO DO

Test

=head1 COPYRIGHT

 Copyright (c) 2008 Dicole Oy
 www.dicole.com

=head1 AUTHORS

 Teemu Arina <teemu@dicole.com>

=cut
