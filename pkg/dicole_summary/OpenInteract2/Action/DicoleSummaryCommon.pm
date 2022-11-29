package OpenInteract2::Action::DicoleSummaryCommon;

use strict;

use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub _valid_invite_exists {
    my ( $self ) = @_;

    return CTX->lookup_action('invite_api')->e('validate_invite' => {
        invite_code => CTX->request->param('k'),
        group_id => $self->param('target_group_id'),
    } );
}

sub _gather_common_globals {
    my ( $self, $valid_invite ) = @_;

    my $globals = {};

    if ( $valid_invite ) {
        my $url = $self->derive_url(
            action => 'invite',
            task => 'claim_invite',
            params => { invite_code => CTX->request->param('k') }
        );

        my $group = $self->param('target_group');

        $globals = {
            %$globals,
            url_after_login => $url,
            url_after_register => $url,
            invite_target_name => $group ? $group->name : $self->_msg('Dicole community platform (invite system name)'),
        };
    }

    return $globals;
}

1;

__END__

=head1 NAME

OpenInteract2::Action::DicoleGroupsSummary - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS
