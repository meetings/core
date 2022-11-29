package OpenInteract2::Action::DicoleXmlAwareness;

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
use Dicole::Widget::Image;
use Time::Local; 
use DateTime;
use Data::Dumper; 

$OpenInteract2::Action::DicoleXmlAwareness::VERSION = sprintf("%d.%02d", q$Revision: 1.16 $ =~ /(\d+)\.(\d+)/);

# user based usage
sub xml_query {
    my ( $self ) = @_;
    
    my $params = {};

    $params->{blocks} = [
        CTX->request->param('logins_form') ? { name => $self->_msg("Activity"), key => 'activity' } : (),
        CTX->request->param('wiki_edits_form') ? { name => $self->_msg("Wiki edits"), key => 'wiki_total' } : (),
        CTX->request->param('blogs_form') ? { name => $self->_msg("Blog posts"), key => 'blog_total' } : (),
        CTX->request->param('comments_form') ? { name => $self->_msg("Comments"), key => 'comment_total' } : (),

    ];

    my $start_time = CTX->request->param('start_date');
    my $end_time = CTX->request->param('end_date');

    my $data = eval { 
        CTX->lookup_action('statistics')->execute( 'get_user_based_data', {
        group_id => $self->param('target_group_id'),
        domain_id => CTX->lookup_action('dicole_domains')->get_current_domain->id,
        begin_epoch => $start_time,
        end_epoch => $end_time,
        } ) 
    };

#     my $user_data = CTX->lookup_object( 'logged_usage_user' )->fetch_group({
#         where  => 'domain_id = ? AND user_id != 1',
#         value  => [ eval{ CTX->lookup_action('dicole_domains')->get_current_domain->id } || 0 ],
#     }) || [];

    #count height to template 
    $params->{blocks_total_height} = int( scalar(@$data) * 17 );
   
    #sort from most active user to laziest
    my @containers_to_sort = ();
    for my $object (@$data) {
        $object->{activity} = $object->{user_active_daily};
        $object->{blog_total} = $object->{blog_post_daily};
        $object->{wiki_total} = $object->{wiki_change_daily};
        $object->{comment_total} = $object->{given_comment_daily};
        my $object_weight=0;
        $object_weight += $object->{wiki_total} if CTX->request->param('wiki_edits_form');
        $object_weight += $object->{blog_total} if CTX->request->param('blogs_form');
        $object_weight += $object->{comment_total} if CTX->request->param('comments_form');
        $object_weight += $object->{activity} if CTX->request->param('logins_form');

        my $hash_container_to_object = { object => $object, total => $object_weight };
        push @containers_to_sort, $hash_container_to_object; 
    }

    my @sorted_containers = sort { $a->{total} <=> $b->{total} } @containers_to_sort;
    my @sorted_objects = map { $_->{object} } @sorted_containers;

    my $users = Dicole::Utils::SPOPS->fetch_linked_objects(
        from_elements => $data,
        link_field => 'user_id',
        object_name => 'user',
    );
    my %users = map {
        my $user = $_->first_name . ' ' . $_->last_name;
        $user = Dicole::Utils::Text->shorten( $user, 21 );
        $_->{user_id} => $user
    } @$users;

    my $array = [];
    my $sorted_array = [];
    for my $object (@sorted_objects) {
        my $block = { 
            name => $users{ $object->{user_id} } || $self->_msg('Unknown'),
            activity => $object->{activity},
            wiki_total => $object->{wiki_total},
            blog_total => $object->{blog_total},
            comment_total => $object->{comment_total},
        };
        push @$array, $block;
    }
    CTX->response->content_type( 'text/xml; charset=utf-8' );
    $params->{information} = $array;

    return $self->generate_content(
        $params, { name => 'dicole_awareness::userBased' }
    );
}

#weekly usage
sub xml_query_weekly {
    my ( $self ) = @_;
    return $self->_xml_query_generic('weekly');
}
#daily usage
sub xml_query_date {
    my ( $self ) = @_;
    return $self->_xml_query_generic('daily');
}

sub _xml_query_generic {
   my ( $self, $mode ) = @_;

    my $params = {};

    my $start_time = CTX->request->param('start_date');
    my $end_time = CTX->request->param('end_date');

    $params->{blocks} = [
       $mode eq 'daily' ? { name => $self->_msg("Total"), key => 'total' }:(),
        CTX->request->param('logins_form') ? 
            { name => $self->_msg("Activity"), key => 'activity' } : (),
        CTX->request->param('wiki_edits_form') ? 
            { name => $self->_msg("Wiki edits"), key => 'wiki_total' } : (),
        CTX->request->param('blogs_form') ? 
            { name => $self->_msg("Blog posts"), key => 'blog_total' } : (),
        CTX->request->param('comments_form') ? 
            { name => $self->_msg("Comments"), key => 'comment_total' } : (),
    ];

#     my $user_data = CTX->lookup_object( 'logged_usage_' . $mode )->fetch_group({
#         where  => 'domain_id = ? AND date > ? AND date < ?',
#         value  => [ eval{ CTX->lookup_action('dicole_domains')->get_current_domain->id } || 0, $start_time, $end_time ],
#         order => 'date ASC',
#     }) || [];


    my $data = eval { 
        CTX->lookup_action('statistics')->execute( 'get_'.$mode.'_based_data', {
            group_id => $self->param('target_group_id'),
            domain_id => CTX->lookup_action('dicole_domains')->get_current_domain->id,
            start_time => CTX->request->param('start_date'),
            end_time => CTX->request->param('end_date'),
        } ) 
    };

#     get_logger( LOG_ACTION )->error( Data::Dumper::Dumper($test));
    
    my $tot =();
    #count how many rows
    my $rows=int(scalar(@$data)/10)-1;
    $rows = 0 if $rows < 0;
 
    my $array = [];    
    for my $object (@$data) {
        my $dt = DateTime->from_epoch( epoch => $object->{epoch} );
        my $ymd = ( $mode eq 'weekly' ) ? $dt->week.'/'.$dt->year : $dt->day.'.'.$dt->month.'.'.$dt->year;

        $tot = $object->{'wiki_change_' . $mode} + $object->{'blog_post_' . $mode} + $object->{'given_comment_' . $mode} + $object->{'user_active_' . $mode};

        my $block = {
            name => $ymd,
            total => $tot,
            wiki_total => $object->{'wiki_change_' . $mode},
            blog_total => $object->{'blog_post_' . $mode},
            comment_total => $object->{'given_comment_' . $mode},
            activity => $object->{'user_active_' . $mode},
        };
#  get_logger( LOG_ACTION )->error( Data::Dumper::Dumper($block));
        push @$array, $block; 
    }
    CTX->response->content_type( 'text/xml; charset=utf-8' );
    $params -> {information} = $array;
    $params -> {row} = $rows;
    return $self->generate_content(
        $params, { name => 'dicole_awareness::'.$mode }
    );
}

sub get_user_based_as_csv {
  my ( $self ) = @_;
    
    my $params = {};

    $params->{blocks} = [
        CTX->request->param('logins_form') ? { name => $self->_msg("Activity"), key => 'activity' } : (),
        CTX->request->param('wiki_edits_form') ? { name => $self->_msg("Wiki edits"), key => 'wiki_total' } : (),
        CTX->request->param('blogs_form') ? { name => $self->_msg("Blog posts"), key => 'blog_total' } : (),
        CTX->request->param('comments_form') ? { name => $self->_msg("Comments"), key => 'comment_total' } : (),

    ];

    my $start_time = CTX->request->param('start_date');
    my $end_time = CTX->request->param('end_date');

    my $data = eval { 
        CTX->lookup_action('statistics')->execute( 'get_user_based_data', {
        group_id => $self->param('target_group_id'),
        domain_id => CTX->lookup_action('dicole_domains')->get_current_domain->id,
        begin_epoch => $start_time,
        end_epoch => $end_time,
        } ) 
    };

    #count height to template 
    $params->{blocks_total_height} = int( scalar(@$data) * 17 );
   
    #sort from most active user to laziest
    my @containers_to_sort = ();
    for my $object (@$data) {
        $object->{activity} = $object->{user_active_daily};
        $object->{blog_total} = $object->{blog_post_daily};
        $object->{wiki_total} = $object->{wiki_change_daily};
        $object->{comment_total} = $object->{given_comment_daily};
        my $object_weight=0;
        $object_weight += $object->{wiki_total} if CTX->request->param('wiki_edits_form');
        $object_weight += $object->{blog_total} if CTX->request->param('blogs_form');
        $object_weight += $object->{comment_total} if CTX->request->param('comments_form');
        $object_weight += $object->{activity} if CTX->request->param('logins_form');

        my $hash_container_to_object = { object => $object, total => $object_weight };
        push @containers_to_sort, $hash_container_to_object; 
    }

    my @sorted_containers = sort { $a->{total} <=> $b->{total} } @containers_to_sort;
    my @sorted_objects = map { $_->{object} } @containers_to_sort;

    my $users = Dicole::Utils::SPOPS->fetch_linked_objects(
        from_elements => $data,
        link_field => 'user_id',
        object_name => 'user',
    );
    my %users = map {
        my $user = $_->last_name . ', ' . $_->first_name;
#         $user = Dicole::Utils::Text->shorten( $user, 21 );
        $_->{user_id} => $user
    } @$users;

    my $array = [];
    my $sorted_array = [];
    for my $object (@sorted_objects) {
        my $block = { 
            name => $users{ $object->{user_id} } || $self->_msg('Unknown'),
            activity => $object->{activity},
            wiki_total => $object->{wiki_total},
            blog_total => $object->{blog_total},
            comment_total => $object->{comment_total},
        };
        push @$array, $block;
    }
    my @sorted_array = sort { $a->{name} cmp $b->{name} } @$array;

    CTX->response->content_type( 'text/plain; charset=utf-8' );
    $params->{information} = \@sorted_array;

    return $self->generate_content(
        $params, { name => 'dicole_awareness::userBasedAsText' }
    );
}

#weekly usage
sub get_weekly_as_csv {
    my ( $self ) = @_;
    return $self->_csv_generic('weekly');
}
#daily usage
sub get_daily_as_csv {
    my ( $self ) = @_;
    return $self->_csv_generic('daily');
}

sub _csv_generic {
   my ( $self, $mode ) = @_;

    my $params = {};

    my $start_time = CTX->request->param('start_date');
    my $end_time = CTX->request->param('end_date');

    $params->{blocks} = [
       $mode eq 'daily' ? { name => $self->_msg("Total"), key => 'total' }:(),
        CTX->request->param('logins_form') ? 
            { name => $self->_msg("Activity"), key => 'activity' } : (),
        CTX->request->param('wiki_edits_form') ? 
            { name => $self->_msg("Wiki edits"), key => 'wiki_total' } : (),
        CTX->request->param('blogs_form') ? 
            { name => $self->_msg("Blog posts"), key => 'blog_total' } : (),
        CTX->request->param('comments_form') ? 
            { name => $self->_msg("Comments"), key => 'comment_total' } : (),
    ];

#     my $user_data = CTX->lookup_object( 'logged_usage_' . $mode )->fetch_group({
#         where  => 'domain_id = ? AND date > ? AND date < ?',
#         value  => [ eval{ CTX->lookup_action('dicole_domains')->get_current_domain->id } || 0, $start_time, $end_time ],
#         order => 'date ASC',
#     }) || [];


    my $data = eval { 
        CTX->lookup_action('statistics')->execute( 'get_'.$mode.'_based_data', {
            group_id => $self->param('target_group_id'),
            domain_id => CTX->lookup_action('dicole_domains')->get_current_domain->id,
            start_time => CTX->request->param('start_date'),
            end_time => CTX->request->param('end_date'),
        } ) 
    };

#     get_logger( LOG_ACTION )->error( Data::Dumper::Dumper($test));
    
    my $tot =();
    #count how many rows
    my $rows=int(scalar(@$data)/10)-1;
    $rows = 0 if $rows < 0;
 
    my $array = [];    
    for my $object (@$data) {
        my $dt = DateTime->from_epoch( epoch => $object->{epoch} );
        my $ymd = ( $mode eq 'weekly' ) ? $dt->week.'/'.$dt->year : $dt->day.'.'.$dt->month.'.'.$dt->year;

        $tot = $object->{'wiki_change_' . $mode} + $object->{'blog_post_' . $mode} + $object->{'given_comment_' . $mode} + $object->{'user_active_' . $mode};

        my $block = {
            name => $ymd,
            total => $tot,
            wiki_total => $object->{'wiki_change_' . $mode},
            blog_total => $object->{'blog_post_' . $mode},
            comment_total => $object->{'given_comment_' . $mode},
            activity => $object->{'user_active_' . $mode},
        };
#  get_logger( LOG_ACTION )->error( Data::Dumper::Dumper($block));
        push @$array, $block; 
    }
    CTX->response->content_type( 'text/plain; charset=utf-8' );
    $params -> {information} = $array;
    $params -> {row} = $rows;
    return $self->generate_content(
        $params, { name => 'dicole_awareness::'.$mode.'Csv' }
    );
}


1;

