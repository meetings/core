package Dicole::Utils::Tags;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Carp;

# TODO: well quess what :D
sub weighted_to_info {
    my ( $self, $wtags, $action, $prefix_url_params, $limit ) = @_;

    my $limit ||= 60;

    my $widget = Dicole::Widget::TagCloud->new(
        prefix => $self->derive_url( %$prefix_url_params ),
        limit => $limit,
    );
    $widget->add_weighted_tags_array( $wtags );
    return $widget->template_params->{links};
}

1;
