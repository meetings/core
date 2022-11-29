package OpenInteract2::Action::DicoleLocalizationJSON;
use strict;

use base qw( OpenInteract2::Action::DicoleLocalizationCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Digest::MD5;

sub lexicon {
    my ( $self ) = @_;

    my $list = eval { Dicole::Utils::JSON->decode( CTX->request->param('strings') ) } || [];
    my $lexicon = $self->_lexicon( scalar ( @$list ) ? $list : undef, $self->param('lang') );

    return { result => $lexicon };
}

sub update {
    my ( $self ) = @_;

    my $group_id = $self->param('target_group_id') || 0;

    my $lang = $self->param('lang') || die;
    my $key = CTX->request->param('key') || die;
    my $value = CTX->request->param('value') || '';

    my $domain = Dicole::Utils::Domain->guess_current;
    my $namespace = $domain->localization_namespace;

    unless ( $namespace ) {
        $namespace = $domain->domain_name;
        $domain->localization_namespace( $namespace );
        $domain->save;
    }

    my $object = CTX->lookup_object('custom_localization');

    # at the same time remove all entries with empty keys as they are just used for cache clearing and are not needed anymore
    my $old_objects = $object->fetch_group({
        where => 'namespace_key = ? AND namespace_area = ? AND namespace_lang = ? AND ( localization_key = ? OR localization_key = ? )',
        value => [ $namespace, $group_id || 0, $lang || '', $key, '' ],
    }) || [];
    $_->remove for @$old_objects;

    # if there is no value, just add an empty key entry to for cache clearing
    my $t = $object->new( {
        creation_date => time(),
        namespace_key => $namespace,
        namespace_area => $group_id || 0,
        namespace_lang => $lang || '',
        localization_key => $value ? $key : '',
        localization_value => $value,
    } );
    $t->save;

    return { result => $value };
}

1;

