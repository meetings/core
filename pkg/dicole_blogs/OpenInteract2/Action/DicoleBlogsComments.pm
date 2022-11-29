package OpenInteract2::Action::DicoleBlogsComments;

# TODO: Rerfactor this so that it is basically all inherited from a lib.

use strict;
use base qw( OpenInteract2::Action::DicoleBlogsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Data::Dumper;

$OpenInteract2::Action::DicoleBlogsComments::VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);


sub add_comment {
    my ( $self ) = @_;
    
    my $thread = CTX->lookup_object( 'comments_thread' )->fetch( CTX->request->param('thread_id') );

    return 0 unless $thread;
    die 'security error' unless $thread->{group_id} == $self->param('target_group_id');
    
    my $response = eval {
        CTX->lookup_action('commenting')->execute('add_comment', {
            thread_id => $thread->id,
            requesting_user_id => CTX->request->auth_user_id,
            requires_approval => $self->_commenting_requires_approval,
            right_to_remove_comments => 
            	$self->mchk_y('OpenInteract2::Action::DicoleBlogs', 'remove_comments'),
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
            	$self->mchk_y('OpenInteract2::Action::DicoleBlogs', 'remove_comments'),
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
            requesting_user_id => CTX->request->auth_user_id,
            requires_approval => $self->_commenting_requires_approval,
            right_to_remove_comments =>
                $self->mchk_y( 'OpenInteract2::Action::DicoleBlogs', 'remove_comments' ),
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
                $self->mchk_y( 'OpenInteract2::Action::DicoleBlogs', 'remove_comments' ),
            right_to_publish_comments =>
                $self->mchk_y( 'OpenInteract2::Action::DicoleComments', 'publish_comments' ),
        } );
    };
    
    return $response || 0;
}
