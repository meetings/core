package Dicole::Widget::TagCloud;

use strict;
use base qw( Dicole::Widget::LinkCloud );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use URI::Escape;

sub ACCESSORS { (
    prefix => Dicole::Widget::ACCESSOR_SPECIAL,
    tags => Dicole::Widget::ACCESSOR_SPECIAL,
) };

__PACKAGE__->mk_widget_accessors;

sub template_params {
    my ( $self, $params ) = @_;

    my $prefix = $self->prefix; 
    my $tags = $self->tags || [];

    $prefix .= '/' unless $prefix =~ /\/$/;

    my $links = [];
    for my $tag ( @$tags ) {
        push @$links, {
            name => $tag->{name},
            weight => $tag->{weight},
            'link' => $prefix . Dicole::Utils::Text->ensure_utf8(
                URI::Escape::uri_escape_utf8(
                    Dicole::Utils::Text->ensure_internal( $tag->{name} )
                )
             ),
        };
    }

    $self->links( $links );

    return $self->SUPER::template_params( $params );
}

sub add_weighted_tags_array {
    my ( $self, $array ) = @_;
    for my $obj (@$array) {
        $self->tags( [] ) unless ref( $self->tags ) eq 'ARRAY';
        push @{ $self->tags }, { name => $obj->[0], weight => $obj->[1] };
    }
}


1;
