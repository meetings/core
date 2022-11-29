package OpenInteract2::SQLInstall::DicoleBlogs;

use strict;
use base qw( OpenInteract2::SQLInstall );

my %FILES = (
          'default' => [
                         'dicole_blogs_deleted_entry.sql',
                         'dicole_blogs_draft_entry.sql',
                         'dicole_blogs_entry.sql',
                         'dicole_blogs_entry_uid.sql',
                         'dicole_blogs_promotion.sql',
                         'dicole_blogs_published.sql',
                         'dicole_blogs_rating.sql',
                         'dicole_blogs_reposted_data.sql',
                         'dicole_blogs_reposted_link.sql',
                         'dicole_blogs_reposter.sql',
                         'dicole_blogs_seed.sql',
                         'dicole_blogs_summary_seed.sql'
                       ]
);

sub get_structure_set {
    return [
          'blogs_entry',
          'blogs_rating',
          'blogs_promotion',
          'blogs_published',
          'blogs_seed',
          'blogs_summary_seed',
          'blogs_deleted_entry',
          'blogs_entry_uid',
          'blogs_draft_entry',
          'blogs_reposted_data',
          'blogs_reposter',
          'blogs_reposted_link'
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
