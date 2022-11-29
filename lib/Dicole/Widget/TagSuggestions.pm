package Dicole::Widget::TagSuggestions;

use strict;
use base qw( Dicole::Widget::Element );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub DEFAULT_TEMPLATE { 'widget_tag_suggestions' };
sub ACCESSORS { (
    target_id => Dicole::Widget::ACCESSOR_RAW,
    tags => Dicole::Widget::ACCESSOR_SPECIAL
) };
__PACKAGE__->mk_widget_accessors;

sub template_params {
  
    my ( $self, $params ) = @_;

    $params = $self->SUPER::template_params( $params );

    my @tag_hold= ();

    for my $tag ( @{ $self->tags } ) { 
        push @tag_hold, lc($tag); 
    }

    $params->{tags} = \@tag_hold; 

    return $params;
}

1;