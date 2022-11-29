package OpenInteract2::Action::DicoleMeetingsPayPalJSONP;

use 5.010;
use warnings;
use strict;

use base qw( OpenInteract2::Action::DicoleMeetingsPayPalCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Business::PayPal::NVP;
use DateTime;
use Data::Dump qw/dump/;
use URI;
use LWP;

sub start { shift->_start_subscription }

sub valid_promo { shift->_valid_promo }

1;
