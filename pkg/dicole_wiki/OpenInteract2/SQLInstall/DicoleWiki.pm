package OpenInteract2::SQLInstall::DicoleWiki;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
          'default' => [
                         'dicole_wiki_annotation.sql',
                         'dicole_wiki_content.sql',
                         'dicole_wiki_link.sql',
                         'dicole_wiki_lock.sql',
                         'dicole_wiki_page.sql',
                         'dicole_wiki_redirection.sql',
                         'dicole_wiki_search.sql',
                         'dicole_wiki_summary_page.sql',
                         'dicole_wiki_support.sql',
                         'dicole_wiki_version.sql'
                       ]
);

sub get_structure_set {
    return [
          'wiki_page',
          'wiki_version',
          'wiki_link',
          'wiki_lock',
          'wiki_content',
          'wiki_search',
          'wiki_summary_page',
          'wiki_annotation',
          'wiki_support',
          'wiki_redirection'
    ];
}

sub get_structure_file {
    my ( $self, $set, $type ) = @_;
    return $FILES{pg}     if ( $type eq 'Pg' );
    return $FILES{sqlite} if ( $type eq 'SQLite' );
    return $FILES{default};
}

sub get_data_file {
    return [

    ];
}

1;
