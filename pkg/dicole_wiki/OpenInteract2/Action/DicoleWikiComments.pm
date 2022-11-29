package OpenInteract2::Action::DicoleWikiComments;

# TODO: Rerfactor this so that it is basically all inherited from a lib.

use strict;
use base qw( OpenInteract2::Action::DicoleWikiCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Data::Dumper;

$OpenInteract2::Action::DicoleWikiComments::VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);


sub add_comment {
    my ( $self ) = @_;

    my $thread = $self->_get_thread;
    $self->_die_unless_commenting_ok( $thread );

    die "security error" unless $self->mchk_y( 'OpenInteract2::Action::DicoleWiki', 'comment' );

    my $response = eval {
        CTX->lookup_action('commenting')->execute('add_comment', {
            thread_id => $thread->id,
            requesting_user_id => CTX->request->auth_user_id,
            requires_approval => $self->_commenting_requires_approval,
            right_to_remove_comments =>
                $self->mchk_y( 'OpenInteract2::Action::DicoleWiki', 'remove_comments' ),
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
            requesting_user_id => CTX->request->auth_user_id,
            requires_approval => $self->_commenting_requires_approval,
            right_to_remove_comments =>
                $self->mchk_y( 'OpenInteract2::Action::DicoleWiki', 'remove_comments' ),
            right_to_publish_comments =>
                $self->mchk_y( 'OpenInteract2::Action::DicoleComments', 'publish_comments' ),
        } );
    };
    
    return $response || 0;
}

sub delete_comment {
    my ( $self ) = @_;

    my $thread = $self->_get_thread;
    $self->_die_unless_commenting_ok( $thread );

    my $response = eval {
        CTX->lookup_action('commenting')->execute('delete_comment', {
            thread_id => $thread->id,
            requesting_user_id => CTX->request->auth_user_id,
            requires_approval => $self->_commenting_requires_approval,
            right_to_remove_comments =>
                $self->mchk_y( 'OpenInteract2::Action::DicoleWiki', 'remove_comments' ),
            right_to_publish_comments =>
                $self->mchk_y( 'OpenInteract2::Action::DicoleComments', 'publish_comments' ),
        } );
    };

    return $response || 0;
}

sub publish_comment {
    my ( $self ) = @_;
    
    my $thread = $self->_get_thread;
    $self->_die_unless_commenting_ok( $thread );
    
    my $response = eval {
        CTX->lookup_action('commenting')->execute('publish_comment', {
            thread_id => $thread->id,
            requesting_user_id => CTX->request->auth_user_id,
            requires_approval => $self->_commenting_requires_approval,
            right_to_remove_comments =>
                $self->mchk_y( 'OpenInteract2::Action::DicoleWiki', 'remove_comments' ),
            right_to_publish_comments =>
                $self->mchk_y( 'OpenInteract2::Action::DicoleComments', 'publish_comments' ),
        } );
    };
    
    return $response || 0;
}


sub get_annotation_comments {
    my ( $self ) = @_;

    my $anno = CTX->lookup_object('wiki_annotation')->fetch( $self->param('annotation_id') );
    die unless $anno;

    my $comments_info = CTX->lookup_action('comments_api')->e( get_comments_info => {
        object => $anno,
        group_id => $anno->group_id,
        user_id => 0,
        domain_id => Dicole::Utils::Domain->guess_current_id,
        size => 40,
        requesting_user_id => CTX->request->auth_user_id,
        requires_approval => $self->_commenting_requires_approval,
        right_to_remove_comments => 
        	$self->mchk_y('OpenInteract2::Action::DicoleWiki', 'remove_annotations'),
        right_to_publish_comments =>
        	$self->mchk_y( 'OpenInteract2::Action::DicoleComments', 'publish_comments' ),
    } );

    return {
        comments => $self->_process_comments_info_for_annos( $anno, $comments_info ),
        comment_count => $anno->comment_count,
    };
}

sub add_annotation_comment {
    my ( $self ) = @_;

    my $anno = CTX->lookup_object('wiki_annotation')->fetch( $self->param('annotation_id') );
    die unless $anno;

    my $comment_content = CTX->request->param('comment_content');
    my $comment_html = Dicole::Utils::HTML->text_to_html( $comment_content );

    CTX->lookup_action('comments_api')->e( add_comment_and_return_thread => {
        object => $anno,
        group_id => $anno->group_id,
        user_id => 0,
        content => $comment_html,
        requesting_user_id => CTX->request->auth_user_id,
        requires_approval => $self->_commenting_requires_approval,
        right_to_remove_comments => 
            $self->mchk_y('OpenInteract2::Action::DicoleWiki', 'remove_annotations'),
        right_to_publish_comments =>
            $self->mchk_y( 'OpenInteract2::Action::DicoleComments', 'publish_comments' ),
    } );

    my $comments_info = CTX->lookup_action('comments_api')->e( get_comments_info => {
        object => $anno,
        group_id => $anno->group_id,
        user_id => 0,
        domain_id => Dicole::Utils::Domain->guess_current_id,
        size => 40,
        requesting_user_id => CTX->request->auth_user_id,
        requires_approval => $self->_commenting_requires_approval,
        right_to_remove_comments => 
        	$self->mchk_y('OpenInteract2::Action::DicoleWiki', 'remove_annotations'),
        right_to_publish_comments =>
        	$self->mchk_y( 'OpenInteract2::Action::DicoleComments', 'publish_comments' ),
    } );

    $anno->comment_count( $self->_count_anno_comments( $anno, $comments_info ) );
    $anno->save;

    return {
        comments => $self->_process_comments_info_for_annos( $anno, $comments_info ),
        comment_count => $anno->comment_count,
    };
}

sub delete_annotation_comment {
    my ( $self ) = @_;

    my $anno = CTX->lookup_object('wiki_annotation')->fetch( $self->param('annotation_id') );
    die unless $anno;

    my $comment_content = CTX->request->param('comment_content');
    my $comment_html = Dicole::Utils::HTML->text_to_html( $comment_content );

    CTX->lookup_action('comments_api')->e( delete_comment => {
        object => $anno,
        group_id => $anno->group_id,
        user_id => 0,
        post_id => $self->param('comment_id'),
        right_to_remove_comments => $self->mchk_y( 'OpenInteract2::Action::DicoleWiki', 'remove_annotations' ),
        requesting_user_id => CTX->request->auth_user_id,
        requires_approval => $self->_commenting_requires_approval,
        right_to_publish_comments =>
            $self->mchk_y( 'OpenInteract2::Action::DicoleComments', 'publish_comments' ),
    } );

    my $comments_info = CTX->lookup_action('comments_api')->e( get_comments_info => {
        object => $anno,
        group_id => $anno->group_id,
        user_id => 0,
        domain_id => Dicole::Utils::Domain->guess_current_id,
        size => 40,
        requesting_user_id => CTX->request->auth_user_id,
        requires_approval => $self->_commenting_requires_approval,
        right_to_remove_comments => 
        	$self->mchk_y('OpenInteract2::Action::DicoleWiki', 'remove_annotations'),
        right_to_publish_comments =>
        	$self->mchk_y( 'OpenInteract2::Action::DicoleComments', 'publish_comments' ),
    } );

    $anno->comment_count( $self->_count_anno_comments( $anno, $comments_info ) );
    $anno->save;

    return {
        comments => $self->_process_comments_info_for_annos( $anno, $comments_info ),
        comment_count => $anno->comment_count,
    };
}

sub publish_annotation_comment {
    my ( $self ) = @_;

    my $anno = CTX->lookup_object('wiki_annotation')->fetch( $self->param('annotation_id') );
    die unless $anno;

    my $comment_content = CTX->request->param('comment_content');
    my $comment_html = Dicole::Utils::HTML->text_to_html( $comment_content );

    CTX->lookup_action('comments_api')->e( publish_comment => {
        object => $anno,
        group_id => $anno->group_id,
        user_id => 0,
        post_id => $self->param('comment_id'),
        right_to_remove_comments => $self->mchk_y( 'OpenInteract2::Action::DicoleWiki', 'remove_annotations' ),
        requesting_user_id => CTX->request->auth_user_id,
        requires_approval => $self->_commenting_requires_approval,
        right_to_publish_comments =>
            $self->mchk_y( 'OpenInteract2::Action::DicoleComments', 'publish_comments' ),
    } );

    my $comments_info = CTX->lookup_action('comments_api')->e( get_comments_info => {
        object => $anno,
        group_id => $anno->group_id,
        user_id => 0,
        domain_id => Dicole::Utils::Domain->guess_current_id,
        size => 40,
        requesting_user_id => CTX->request->auth_user_id,
        requires_approval => $self->_commenting_requires_approval,
        right_to_remove_comments => 
        	$self->mchk_y('OpenInteract2::Action::DicoleWiki', 'remove_annotations'),
        right_to_publish_comments =>
        	$self->mchk_y( 'OpenInteract2::Action::DicoleComments', 'publish_comments' ),
    } );

    $anno->comment_count( $self->_count_anno_comments( $anno, $comments_info ) );
    $anno->save;

    return {
        comments => $self->_process_comments_info_for_annos( $anno, $comments_info ),
        comment_count => $anno->comment_count,
    };
}

sub support_annotation_comment {
    my ( $self ) = @_;

    my $anno = CTX->lookup_object('wiki_annotation')->fetch( $self->param('annotation_id') );
    die unless $anno;

    my $support = CTX->lookup_object('wiki_support')->new;
    $support->domain_id( $anno->domain_id );
    $support->group_id( $anno->group_id );
    $support->annotation_id( $anno->id );
    # TODO: check that this comment actually belongs to this anno's thread ;)
    $support->comment_id( $self->param('comment_id') );
    $support->creator_id( CTX->request->auth_user_id );
    $support->creation_date( time() );
    $support->save;

    my $supports = CTX->lookup_object('wiki_support')->fetch_group( {
        where => 'comment_id = ? AND creator_id = ?',
        value => [ $self->param('comment_id'), CTX->request->auth_user_id ],
    }) || [];

    pop @$supports;

    $_->remove for @$supports;

    my $comments_info = CTX->lookup_action('comments_api')->e( get_comments_info => {
        object => $anno,
        group_id => $anno->group_id,
        user_id => 0,
        domain_id => Dicole::Utils::Domain->guess_current_id,
        size => 40,
    } );

    return {
        comments => $self->_process_comments_info_for_annos( $anno, $comments_info ),
        comment_count => $anno->comment_count,
    };
}

sub unsupport_annotation_comment {
    my ( $self ) = @_;

    my $anno = CTX->lookup_object('wiki_annotation')->fetch( $self->param('annotation_id') );
    die unless $anno;

    my $supports = CTX->lookup_object('wiki_support')->fetch_group( {
        where => 'comment_id = ? AND creator_id = ?',
        value => [ $self->param('comment_id'), CTX->request->auth_user_id ],
    }) || [];

    $_->remove for @$supports;

    my $comments_info = CTX->lookup_action('comments_api')->e( get_comments_info => {
        object => $anno,
        group_id => $anno->group_id,
        user_id => 0,
        domain_id => Dicole::Utils::Domain->guess_current_id,
        size => 40,
    } );

    return {
        comments => $self->_process_comments_info_for_annos( $anno, $comments_info ),
        comment_count => $anno->comment_count,
    };
}

sub _get_thread {
    my ( $self ) = @_;

    my $thread = CTX->lookup_object( 'comments_thread' )->fetch( CTX->request->param('thread_id') );

    die 'security error' unless $thread;
    die 'security error' unless $thread->{group_id} == $self->param('target_group_id');

    return $thread;
}

sub _die_unless_commenting_ok {
    my ( $self, $thread ) = @_;

    my $page = CTX->lookup_object('wiki_page')->fetch( $thread->object_id );

    die "security error" unless $page;
    die "security error" if $page->moderator_lock || $page->hide_comments;
}

1;
