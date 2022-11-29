package Dicole::Task::DatedListSummary;

# TODO: This could be broken into Task::Summary which could handle box titles

use base qw( Dicole::Task );

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::URL;
use Dicole::Box;
use Dicole::Utils::SPOPS;
use Dicole::Widget::Vertical;
use Dicole::Widget::Hyperlink;
use Dicole::Widget::DatedList;

__PACKAGE__->mk_accessors( qw(
  box_title
  box_title_link
  box_title_raw
  object
  query_options
  empty_box_string
  date_field
  title_field
  user_field
  dated_list_separator_set
) );


sub execute {
    my ( $self ) = @_;
    
    my $box = Dicole::Box->new;
    $box->name( $self->_generate_box_title_html );

    if ( $self->action->param( 'box_open' ) ) {
        my $recent = $self->_get_summary_content;
        $box->content( $recent );
    }

    return $box->output;
}

sub _get_summary_content {
    my ( $self ) = @_;

    $self->_pre_data_retrieve;
    
    my $data = $self->_data_retrieve;

    $data = $self->_post_data_retrieve( $data );

    if ( ! scalar @{ $data } ) {
         return Dicole::Widget::Text->new( text => $self->empty_box_string );
    }

    my $users_hash = $self->_retrieve_users_hash( $data );

    my $elements = [];
    for my $item ( @$data ) {
        eval { push @$elements, $self->_create_element( $item, $users_hash ); };
        if ( my $msg = $@ ) {
            get_logger(LOG_APP)->warn( "Problem creating DatedListSummary item: $@" );
        }
    }

    return $self->_create_dated_list( $elements );
}

sub _pre_data_retrieve {
    my ( $self ) = @_;
    
    return 1;
}

sub _data_retrieve  {
    my ( $self ) = @_;
    
    my $object = CTX->lookup_object( $self->object );
    return $object->fetch_group( $self->query_options ) || [];
}

sub _post_data_retrieve {
    my ( $self, $data ) = @_;
    
    return $data;
}

sub _retrieve_users_hash {
    my ( $self, $data ) = @_;
    
    my $users_hash = $self->user_field ? Dicole::Utils::SPOPS->fetch_linked_objects_hash(
        from_elements => $data,
        link_field => $self->user_field,
        object_name => 'user',
    ) : {};
    
    return $users_hash;
}

sub _create_element {
    my ( $self, $item, $users_hash ) = @_;

    return {
        params => { date => $self->_generate_item_date( $item ) },
        content => $self->_generate_item_content( $item, $users_hash ),
    };
}

sub _generate_item_date {
    my ( $self, $item ) = @_;
    
    return $item->{ $self->date_field };
}

sub _generate_item_content {
    my ( $self, $item, $users_hash ) = @_;
    
    my $title_widget = $self->_generate_item_title_widget( $item );
    my $author_widget = $self->_generate_item_author_widget( $item, $users_hash );
    
    return Dicole::Widget::Vertical->new( contents => [
        $title_widget,
        $author_widget || (),
    ] );
}

sub _generate_item_title_widget {
    my ( $self, $item ) = @_;
    
    my $title = $self->_generate_item_title_text( $item );
    my $link = $self->_generate_item_title_link( $item );
    
    if ( $link ) {
        return Dicole::Widget::Hyperlink->new(
            content => $title,
            link => $link,
            class => 'summary_list_title',
        );
    }
    else {
        return $title;
    }
}

sub _generate_item_title_text {
    my ( $self, $item ) = @_;

    return $item->{ $self->title_field };
}

sub _generate_item_title_link {
    my ( $self, $item ) = @_;

    return undef;
}

sub _generate_item_author_widget {
    my ( $self, $item, $users_hash ) = @_;
    
    my $user_name = $self->_generate_item_author_text( $item, $users_hash );
    my $link = $self->_generate_item_author_link( $item, $users_hash );
    
    if ( $link ) {
        return Dicole::Widget::Hyperlink->new(
            content => $user_name,
            link => $link,
            class => 'summary_list_author',
        );
    }
    else {
        return $user_name;
    }
}

sub _generate_item_author_text {
    my ( $self, $item, $users_hash ) = @_;
    
    return '' unless $self->user_field;

    my $user = $users_hash->{ $item->{ $self->user_field } };
    
    return $user ? $user->first_name . ' ' . $user->last_name : $self->action->_msg( 'Unknown user' );
}

sub _generate_item_author_link {
    my ( $self, $item, $users_hash ) = @_;
    
    return undef unless $self->user_field;
    
    my $user = $users_hash->{ $item->{ $self->user_field } };
    
    return undef unless $user;
    
    if ( eval { CTX->lookup_action( 'networking' ) } ) {
        return Dicole::URL->from_parts(
            action => 'networking',
            task => 'profile',
            target => $self->action->param('target_group_id'),
            additional => [ $user->id ]
        );
    }

    return undef;
}

sub _create_dated_list {
    my ( $self, $elements ) = @_;
    
    return Dicole::Widget::DatedList->new(
        elements => $elements,
        separator_set => $self->dated_list_separator_set,
    );
}

sub _generate_box_title_html {
    my ( $self ) = @_;
    
    return $self->box_title_raw if $self->box_title_raw;
    if ( ! $self->box_title_link ) {
        return Dicole::Widget::Text->new(
            text =>$self->box_title
        )->generate_content;
    }
    else {
        return Dicole::Widget::Hyperlink->new(
            content => $self->box_title,
            link => $self->box_title_link
        )->generate_content;
    }
}

1;
