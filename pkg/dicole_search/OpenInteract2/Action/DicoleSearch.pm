package OpenInteract2::Action::DicoleSearch;

use strict;
use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub process {
    my($self) = @_;

    my $object = $self->param('object');
    my $domain_id = $self->param('domain_id');
    
    $self->_populate_params;
    
    my $object_type = $self->param('object_type');
    get_logger(LOG_APP)->error($object_type);
    
    if($object_type eq 'OpenInteract2::CommentsPost')
    {
        $self->_process_comment($object);
    }
    elsif($object_type eq 'OpenInteract2::WikiPage')
    {
    }
    elsif($object_type eq 'OpenInteract2::BlogsEntry')
    {
        $self->_process_blog($object);
    }
    elsif($object_type eq 'OpenInteract2::Media')
    {
    }
    elsif($object_type eq 'OpenInteract2::DicoleTagAttached')
    {
        $self->_process_tag($object, CTX->lookup_object('tag')->fetch($object->tag_id));
    }
}

sub _process_comment {
    my($self, $comment) = @_;
    
    my $search = CTX->lookup_object('search')->new;
    
    $search->{domain_id} = $self->param('domain_id');
    $search->{group_id} = $self->param('group_id');
    $search->{creator_id} = $comment->user_id;
    $search->{object_id} = $comment->post_id;
    $search->{creation_date} = $comment->date;
    $search->{last_modified} = $comment->date;
    $search->{object_type} = $self->param('object_type');
     
    my $html = Dicole::Utils::HTML->html_to_text($comment->content);
    $search->{combined_text} = $html;
    $search->{content_text} = $html;

    $search->save;
}

sub _process_blog {
    my($self, $entry) = @_;
    
    my $searches = CTX->lookup_object('search')->fetch_group({
        where => 'object_id = ? AND object_type = ?',
        value => [$entry->entry_id, $self->param('object_type')]
    });
    
    if(scalar @{ $searches })
    {
        for my $search (@$searches) {
            my $post = CTX->lookup_object('weblog_posts')->fetch(CTX->lookup_object('blogs_entry')->fetch($search->object_id)->post_id);
        
            my $title = Dicole::Utils::HTML->html_to_text($post->title);
            $search->{title_text} = $title;
        
            my $content = Dicole::Utils::HTML->html_to_text($post->content);
            $search->{content_text} = $content;
        
            $search->{combined_text} = $title . $content . $search->{tag_text};
            $search->save;
        }
    }
    else
    {
        my $post = CTX->lookup_object('weblog_posts')->fetch($entry->post_id);
    
        my $search = CTX->lookup_object('search')->new;
        
        $search->{domain_id} = $self->param('domain_id');
        $search->{group_id} = $self->param('group_id');
        $search->{creator_id} = $post->user_id;
        $search->{object_id} = $post->post_id;
        $search->{creation_date} = $post->publish_date;
        $search->{last_modified} = $post->publish_date;
        $search->{object_type} = $self->param('object_type');
        
        my $title = Dicole::Utils::HTML->html_to_text($post->title);
        $search->{title_text} = $title;
        $search->{combined_text} = $title;
    
        my $content = Dicole::Utils::HTML->html_to_text($post->content);
        $search->{content_text} = $content;
        $search->{combined_text} .= " $content";
                
        my $attached_tags = CTX->lookup_object('tag_attached')->fetch_group({
            where => 'object_id = ? AND object_type = ?',
            value => [$entry->entry_id, $self->param('object_type')]
        });
        
        for my $attached_tag (@$attached_tags) {
            my $tag = CTX->lookup_object('tag')->fetch($attached_tag->tag_id)->tag;
            $search->{tag_text} .= $tag;
            $search->{combined_text} .= " $tag";
        }
        
        $search->save;
    }
}

sub _process_tag {
    my($self, $attached, $tag) = @_;
    
    my $searches = CTX->lookup_object('search')->fetch_group({
        where => 'object_id = ? AND object_type = ?',
        value => [$attached->object_id, $attached->object_type]
    });
      
    for my $search (@$searches) {
        $search->remove;
        $search->{combined_text} .= $tag->tag;
        $search->{tag_text} .= $tag->tag;
        $search->save;
    }
}

sub remove {
    my($self) = @_;

    my $object = $self->param('object');
    $self->_populate_params;

    get_logger(LOG_APP)->error($self->param('object_type') .' '. $self->param('object_id') . ' removed.');

    my $searches = CTX->lookup_object('search')->fetch_group({
        where => 'object_id = ? AND object_type = ?',
        value => [$self->param('object_id'), $self->param('object_type')]
    });

    get_logger(LOG_APP)->error(Data::Dumper::Dumper($searches));

    for my $search (@$searches) {
        $search->remove;
    }
}

sub _populate_params {
    my ( $self ) = @_;

    $self->_populate_object_params( 'object' );
    $self->_populate_id_params;
    $self->_populate_domain_params( 'domain' );
}

sub _populate_id_params {
    my ( $self ) = @_;

    if ( CTX->controller && CTX->controller->initial_action ) {
        my $ia = CTX->controller->initial_action;
        $self->param( 'user_id', $ia->param('target_type') eq 'user' ? $ia->param('target_user_id') : 0 )
            unless defined $self->param( 'user_id' );
        $self->param( 'group_id', $ia->param('target_type') eq 'group' ? $ia->param('target_group_id') : 0 )
            unless defined $self->param( 'group_id' );
    }
}

sub _populate_object_params {
    my ( $self, $param ) = @_;

    if ( my $object = $self->param( $param ) ) {
        $self->param( $param . '_id', $object->id )
            unless defined $self->param( $param . '_id' );
        $self->param( $param . '_type', ref( $object ) )
            unless defined $self->param( $param . '_type' );
    }
}

sub _populate_domain_params {
    my ( $self, $param ) = @_;

    unless ( defined( $self->param( $param . '_id' ) ) ) {
        eval { $self->param( $param . '_id', CTX->controller->initial_action->param('target_domain')->id ) };
        # might fail because of old action resolver code or no initial action present
        if ( $@ ) {
            eval { $self->param( $param . '_id', CTX->lookup_action('dicole_domains')->execute( get_current_domain => {} )->id ) };
            if ( $@ ) {
                $self->param( $param . '_id', 0 );
            }
        }
    }
}

1;