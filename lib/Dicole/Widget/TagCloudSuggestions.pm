package Dicole::Widget::TagCloudSuggestions;

use strict;
use base qw( Dicole::Widget::LinkCloud );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub DEFAULT_TEMPLATE { 'widget_tag_cloud_suggestions' };
sub ACCESSORS { (
    target_id => Dicole::Widget::ACCESSOR_RAW,
    tags => Dicole::Widget::ACCESSOR_SPECIAL,
) };

__PACKAGE__->mk_widget_accessors;

sub template_params {
    my ( $self, $params ) = @_;

    $self->set_tags_to_links;

    return $self->SUPER::template_params( $params );
}

sub set_tags_to_links {
    my ( $self ) = @_;

    my $tags = $self->tags || [];

    my $links = [];
    for my $tag ( @$tags ) {
        push @$links, {
            name => $tag->{name},
            weight => $tag->{weight},
            link => '#',
        };
    }

    $self->links( $links );
}

sub add_weighted_tags_array {
    my ( $self, $array ) = @_;
    for my $obj (@$array) {
        $self->tags( [] ) unless ref( $self->tags ) eq 'ARRAY';
        push @{ $self->tags }, { name => $obj->[0], weight => $obj->[1] };
    }
}


1;