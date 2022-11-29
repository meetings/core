package OpenInteract2::Action::DicoleCommentsJSON;

use strict;
use base qw( OpenInteract2::Action::DicoleCommentsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub more_discussions {
    my ( $self ) = @_;

    my $gid = $self->param('target_group_id');
    my $skip_data_json = CTX->request->param('skip_data') || '{}';
    my $skip_data = Dicole::Utils::JSON->decode( $skip_data_json );

    my $info = $self->_fetch_rolling_list_info( $gid, $self->DEFAULT_DISCUSSION_SIZE, $skip_data );

    my $params = {
        entries => $info->{object_info_list},
        script_data_json => $self->_generate_script_data_json( $gid, $info ),
    };

    my $content = $self->generate_content( $params, { name => 'dicole_comments::discussions_entries' } );

    return { result => { html => $content, end_of_pages => $info->{end_of_pages} } };
}


1;

