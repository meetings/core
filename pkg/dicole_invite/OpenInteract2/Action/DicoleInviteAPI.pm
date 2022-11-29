package OpenInteract2::Action::DicoleInviteAPI;

# $Id: DicoleInviteAPI.pm,v 1.4 2010-07-20 04:38:57 amv Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );

use Dicole::MessageHandler qw( :message );
use OpenInteract2::Context   qw( CTX );

use base qw( OpenInteract2::Action::DicoleInviteCommon );

sub dialog_data {
    my ( $self ) = @_;

    my $domain_id = $self->param('domain_id') || Dicole::Utils::Domain->guess_current_id;
    my $group_id = $self->param('group_id') || CTX->controller->initial_action->param('target_group_id');

    my $uids = CTX->lookup_action('domains_api')->execute( users_by_domain => { domain_id => $domain_id } );
    my $all_gids = CTX->lookup_action('groups_api')->execute( groups_ids_for_domain => { domain_id => $domain_id } );

    my $gids = [ map { $_ } @$all_gids ];
    # TODO: filter gids here

    my $groups = CTX->lookup_object('groups')->fetch_group( {
        where => Dicole::Utils::SQL->column_in( groups_id => $gids ),
    } );

    my $groups_data = [ map {{ name => $_->name, value => $_->id }} @$groups ];
    unshift @$groups_data, { name => $self->_msg('All groups'), value => 0 };

    my $users = CTX->lookup_object('user')->fetch_group( {
        where => Dicole::Utils::SQL->column_in( user_id => $uids ),
    } );

    my $users_data = Dicole::Utils::User->icon_hash_list( $users, 50, $group_id, $domain_id );
    $users_data = [ sort { $a->{name} cmp $b->{name} } @$users_data ];

    my %ud_by_id = map { $_->{id} => $_ } @$users_data;

    my $group_memberships = CTX->lookup_object('group_user')->fetch_group( {
        where => Dicole::Utils::SQL->column_in( groups_id => $gids ),
    } );

    for my $gm ( @$group_memberships ) {
        my $ud = $ud_by_id{ $gm->user_id };
        next unless $ud;
        $ud->{groups} ||= [];
        push @{ $ud->{groups} }, $gm->groups_id;
    }

    my $levels_data = [
        { name => $self->_msg('User'), value => 'user' },
    ];

    push @$levels_data, { name => $self->_msg('Admin'), value => 'admin' }
        if $self->_current_user_can_invite_as_admin;

#     my @data = ();
#     for my $xx (1..20){
#         for my $d ( @$users_data ) {
#             push @data, { %$d };
#             $data[-1]->{id} += $xx*10000;
#         }
#     }
#     $users_data = \@data;

    return {
        groups => $groups_data,
        levels => $levels_data,
        users => $users_data,
    };
}

sub levels_dialog_data {
    my ( $self ) = @_;

    my $levels_data = [
        { name => $self->_msg('User'), value => 'user' },
    ];

    push @$levels_data, { name => $self->_msg('Admin'), value => 'admin' }
        if $self->_current_user_can_invite_as_admin;

    return {
        levels => $levels_data,
    };
}

sub validate_invite {
    my ( $self ) = @_;

    my $ic = $self->param('invite_code');
    my $tgid = $self->param('target_group_id');
    my $tdid = $self->param('domain_id');

    my $invite = $self->_fetch_invite( $ic, $tgid, $tdid );
    return 0 unless $invite;
    return 1;
}

1;

__END__
