package OpenInteract2::Action::DicolePresentationsJSON;

use strict;
use base qw( OpenInteract2::Action::DicolePresentationsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::Utils::MIME;

sub object_info {
    my ( $self ) = @_;

    my $pid = $self->param('presentation_id');
    my $prese = CTX->lookup_object('presentations_prese')->fetch( $pid );

    my $group_id = $self->param('target_group_id');
    die "security error" unless $group_id && $prese->group_id == $group_id;
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $info = $self->_object_info( $prese, $domain_id );

    return { result => $info };
}

sub add_comment {
    my ( $self ) = @_;
    
    my $thread = CTX->lookup_object( 'comments_thread' )->fetch( CTX->request->param('thread_id') );
 
    return 0 unless $thread;
    die 'security error' unless $thread->{group_id} == $self->param('target_group_id');
    
    
    my $response = eval {
        CTX->lookup_action('commenting')->execute('add_comment', {
            thread_id => $thread->id,
            content => CTX->request->param('content'),
            parent_post_id => CTX->request->param('parent_post_id'),
            right_to_remove_comments => $self->mchk_y('OpenInteract2::Action::DicolePresentations', 'admin'),
            requesting_user_id => CTX->request->auth_user_id,
            requires_approval => $self->_commenting_requires_approval,
            right_to_publish_comments =>
                $self->mchk_y( 'OpenInteract2::Action::DicoleComments', 'publish_comments' ),
        } );
    };
    
    return $response || 0;
}

sub get_comments_html {
    my ( $self ) = @_;
    
    my $thread = CTX->lookup_object( 'comments_thread' )->fetch( CTX->request->param('thread_id') );

    return 0 unless $thread;
    die 'security error' unless $thread->{group_id} == $self->param('target_group_id');
    
    my $response = eval {
        CTX->lookup_action('commenting')->execute('get_comments_html', {
            thread_id => $thread->id,
            right_to_remove_comments => $self->mchk_y('OpenInteract2::Action::DicolePresentations', 'admin'),
            requesting_user_id => CTX->request->auth_user_id,
            requires_approval => $self->_commenting_requires_approval,
            right_to_publish_comments =>
                $self->mchk_y( 'OpenInteract2::Action::DicoleComments', 'publish_comments' ),
        } );
    };
    
    return $response || 0;
}

sub delete_comment {
    my ( $self ) = @_;
    
    my $thread = CTX->lookup_object( 'comments_thread' )->fetch( CTX->request->param('thread_id') );

    return 0 unless $thread;
    die 'security error' unless $thread->{group_id} == $self->param('target_group_id');
    
    my $response = eval {
        CTX->lookup_action('commenting')->execute('delete_comment', {
            thread_id => $thread->id,
            post_id => CTX->request->param('post_id'),
            right_to_remove_comments => $self->mchk_y('OpenInteract2::Action::DicolePresentations', 'admin'),
            requesting_user_id => CTX->request->auth_user_id,
            requires_approval => $self->_commenting_requires_approval,
            right_to_publish_comments =>
                $self->mchk_y( 'OpenInteract2::Action::DicoleComments', 'publish_comments' ),
        } );
    };
    
    return $response || 0;
}

sub publish_comment {
    my ( $self ) = @_;
    
    my $thread = CTX->lookup_object( 'comments_thread' )->fetch( CTX->request->param('thread_id') );
 
    return 0 unless $thread;
    die 'security error' unless $thread->{group_id} == $self->param('target_group_id');
    
    my $response = eval {
        CTX->lookup_action('commenting')->execute('publish_comment', {
            thread_id => $thread->id,
            requesting_user_id => CTX->request->auth_user_id,
            requires_approval => $self->_commenting_requires_approval,
            right_to_remove_comments =>
                $self->mchk_y( 'OpenInteract2::Action::DicolePresentations', 'admin' ),
            right_to_publish_comments =>
                $self->mchk_y( 'OpenInteract2::Action::DicoleComments', 'publish_comments' ),
        } );
    };
    
    return $response || 0;
}

sub rate {
    my ( $self ) = @_;
    
    my $object_name = 'presentations_prese';
    
    my $object = CTX->lookup_object($object_name)->fetch( $self->param('object_id') );
    die unless $object && $object->group_id == $self->param('target_group_id');
    
    my $inrating = ( $self->param('rating') + 0 ) * 20;
    $inrating = 0 if $inrating < 0;
    $inrating = 100 if $inrating > 100;
    
    my $rating = CTX->lookup_object($object_name.'_rating')->new;
    $rating->group_id( $self->param('target_group_id') );
    $rating->user_id( CTX->request->auth_user_id );
    $rating->object_id( $object->id );
    $rating->date( time );
    $rating->rating( $inrating );
    $rating->save;
    
    my $users_objects = CTX->lookup_object($object_name.'_rating')->fetch_group( {
        where => 'object_id = ? AND user_id = ?',
        value => [ $object->id, CTX->request->auth_user_id ],
        order => 'date desc'
    } ) || [];
    
    shift @$users_objects;
    $_->remove for @$users_objects;
    
    my $ratings = CTX->lookup_object($object_name.'_rating')->fetch_group( {
        where => 'object_id = ?',
        value => [ $object->id ],
    } ) || [];
    
    $object->rating_count( scalar( @$ratings ) );
    
    my $total = 0;
    $total += $_->rating for @$ratings;
    $object->rating( int( $total / scalar( @$ratings ) ) );
    $object->save;
    
    return { messages_html => $self->_unwrapped_rating_widget_for_object( $object )->generate_content };
}

sub new {
    my $self = shift;
    return $self->_generic_listing(
        'dicole_presentations_prese.creation_date desc',
    );
}

sub top {
    my $self = shift;
    return $self->_generic_listing(
        'dicole_presentations_prese.rating desc, dicole_presentations_prese.creation_date desc',
    );
}

sub featured {
    my $self = shift;
    return $self->_generic_listing(
        'dicole_presentations_prese.featured_date desc',
        'dicole_presentations_prese.featured_date > 0'
    );
}

sub _generic_listing {
    my ( $self, $order, $where ) = @_;

    my $tag = $self->param('tag');
    my $gid = $self->param('target_group_id');
    my $page_load = CTX->request->param('page_load');
    my $shown_ids_json = CTX->request->param('shown_entry_ids');
    my $shown_ids = eval { $shown_ids_json ? JSON->new->jsonToObj( $shown_ids_json ) : [] };
    $shown_ids = [] unless ref( $shown_ids ) eq 'ARRAY';

    my $entries = $self->_generic_preses(
        tag => $tag,
        group_id => $gid,
        order => $order,
        where => 'dicole_presentations_prese.creation_date < ? AND ' . Dicole::Utils::SQL->column_not_in(
            'dicole_presentations_prese.prese_id' => $shown_ids,
        ) . ( $where ? ' AND ' . $where : '' ),
        value => [ $page_load ],
        limit => 10,
    );

    my $widget = $self->_visualize_prese_list( $entries, 1 );
    my $html = $widget->generate_content;

    return { messages_html => $html }
}

sub presentation_info {
    my ( $self ) = @_;

    my $pid = $self->param('presentation_id');
    my $prese = CTX->lookup_object('presentations_prese')->fetch( $pid );

    my $gid = $self->param('target_group_id');
    die "security error" unless $gid && $prese->group_id == $gid;

    my %params = ();

    my $can_admin = $self->schk_y('OpenInteract2::Action::DicolePresentations::admin') ? 1 : 0;

    my $comments = Dicole::Widget::Container->new(
        id => 'comments',
        class => 'presentations_prese_comments',
        contents => [
            CTX->lookup_action('commenting')->execute( get_comment_tree_widget => {
                object => $prese,
                comments_action => 'presentations_json',
                input_anchor => 'prese_comments_' . $prese->id,
                input_hidden => 0,
                start_writing_string => $self->_msg('Add a comment'),
                submit_comment_string => $self->_msg('Submit comment'),
                write_comment_string => $self->_msg('Write your comment:'),
                comment_content_string => $self->_msg('Comment content'),
                right_to_remove_comments => $can_admin,
                
                disable_commenting => $self->schk_y('OpenInteract2::Action::DicolePresentations::comment') ? 0 : 1,
            } )
        ]
    );
    $params{comments_html} = $comments->generate_content;

#    my $ratings = $self->_rating_widget_for_object( $prese );
#    $params{rating_html} = $ratings->generate_content;

    $params{edit_url} = Dicole::URL->from_parts(
        action => 'presentations', task => 'edit',
        target => $self->param('target_group_id'), additional => [ $prese->id ],
    ) if CTX->request->auth_user_id == $prese->creator_id || $can_admin;

    %params = (
        %params,
        title => $prese->name,
        type => $self->_simple_type_for_object( $prese ),
        by_author => $self->_msg( "by [_1]", $prese->presenter || Dicole::Utils::User->short_name( $prese->creator_id ) ),
        by_uploaded => $self->_msg( "Uploaded by [_1]", Dicole::Utils::User->short_name( $prese->creator_id ) ),
        description => $prese->description,
        on_date => $self->_msg( "on [_1]", $self->_date_string_for_object( $prese ) ),
        embed => $self->_embed_for_object( $prese ),
        strings => { comments => $self->_msg('Comments') },
        tags => $self->_tags_for_object( $prese ),
    );

    my $html = $self->generate_content(
        \%params, { name => 'dicole_presentations::show' }
    );

    return { presentation_html => $html };
}

sub tag_completion {
    my ( $self ) = @_;

    my $fragment = lc( CTX->request->param('seed') );
    my $gid = $self->param('target_group_id');

    my $tag_names = CTX->lookup_action('tags_api')->e( tag_name_list => {
        group_id => $gid,
    } );

    my @filtered = grep { index( $_, $fragment ) != -1 } @$tag_names;
    @filtered = sort { $a cmp $b } @filtered;
    @filtered = sort { length( $a ) <=> length( $b ) } @filtered;
    @filtered = sort { ( index( $a, $fragment ) ? 1 : 0 ) <=> ( index( $b, $fragment ) ? 1 : 0 ) } @filtered;

    my $results = [ map { {
        name => $_,
        value => $_,
        url => $self->derive_url( action => 'presentations', task => 'detect', additional => [ $_ ] ),
    } } @filtered ];

    return { results => $results };
}

sub keyword_change {
    my ( $self ) = @_;
    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $state = { tags => eval{ Dicole::Utils::JSON->decode( CTX->request->param('selected_keywords') ) } || [] };
    my $info = $self->_fetch_state_prese_list_info( $gid, $domain_id, $state, 30 );

    $state = $info->{state};
    my $suggestions = $self->_fetch_state_prese_filter_suggestions( $gid, $domain_id, $state );

    return {
        selected_tags_html => $self->generate_content(
            { links => [ map { { name => $_ } } @{ $state->{tags} || [] } ] },
            { name => 'dicole_presentations::component_list_taglist' } 
        ),
        tags_html => $self->generate_content(
            { suggestions => $suggestions, tag_complete_url => $self->derive_url( task => 'tag_completion', target => $gid ), },
            { name => 'dicole_presentations::component_list_tagcloud' } 
        ),
        results_html => $self->generate_content(
            { objects => $info->{object_info_list} },
            { name => 'dicole_presentations::component_list_materials' }
        ),
        result_count => $info->{count},
        result_count_html => $info->{count} == 1 ? $self->_msg("1 material") : $self->_msg( "[_1] materials", $info->{count} ),
        state => Dicole::Utils::JSON->encode( $state ),
        end_of_pages => $info->{end_of_pages},
    };
}

sub more_materials2 {
    my ( $self ) = @_;
    my $gid = $self->param('target_group_id');
    my $domain_id = Dicole::Utils::Domain->guess_current_id;

    my $state = eval{ Dicole::Utils::JSON->decode( CTX->request->param('state') ) } || {};
    my $info = $self->_fetch_state_prese_list_info( $gid, $domain_id, $state, 30 );

    return {
        results_html => $self->generate_content(
            { objects => $info->{object_info_list} },
            { name => 'dicole_presentations::component_list_materials' }
        ),
        state => Dicole::Utils::JSON->encode( $info->{state} ),
        end_of_pages => $info->{end_of_pages},
    };
}

1;
