package Dicole::Widget::TagSuggestionListing;

use strict;
use base qw( Dicole::Widget::Element );

sub DEFAULT_TEMPLATE { 'widget_tag_suggestion_listing' };
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