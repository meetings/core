package OpenInteract2::Action::DicoleLocalizationAPI;
use strict;

use base qw( OpenInteract2::Action::DicoleLocalizationCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub lexicon {
    my ( $self ) = @_;

    return $self->_lexicon;
}
1;

