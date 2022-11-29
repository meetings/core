package OpenInteract2::Action::DicoleShareflect;
use strict;
use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub display {
    my ( $self ) = @_;

#    die "security error" unless CTX->request->auth_user_id;

    my $gid = $self->param('target_group_id');
    my $ginfo = CTX->lookup_action('groups_api')->e( info_for_groups => { group_ids => [ $gid ] } );

    my %params = (
        group_id => $gid,
        group_name => $ginfo->{ $gid }->{name},
        auth_token => CTX->request->auth_user_id ? Dicole::Utils::User->permanent_authorization_key( CTX->request->auth_user ) : '',
    );

    return $self->generate_content(
        \%params, { name => 'dicole_shareflect::main_display' }
    );
}

1;

