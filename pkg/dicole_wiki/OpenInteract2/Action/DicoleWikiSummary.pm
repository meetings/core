package OpenInteract2::Action::DicoleWikiSummary;

use strict;
use base qw(
    OpenInteract2::Action::DicoleWikiCommon
    Dicole::Action::Common::Summary
);

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::Settings;
use OpenInteract2::Action::DicoleWiki;

sub summary_page_list {
    my ( $self ) = @_;

    my $a = CTX->lookup_object('wiki_summary_page')->fetch_group( {
        where => 'group_id = ?',
        value => [ $self->param('group_id') ],
    } ) || [];

    return [ map { 'wiki_summary_page::' . $_->page_id } @$a ];
}

sub summary_page {
    my ( $self ) = @_;

    my $page_id = $self->param( 'box_param' );
    my $page = CTX->lookup_object('wiki_page')->fetch( $page_id );

    return undef unless $page;

    my $title = Dicole::Widget::Horizontal->new;

    $title->add_content(
        Dicole::Widget::Hyperlink->new(
            content => $page->readable_title,
            link => Dicole::URL->create_from_parts(
                action => 'wiki',
                task => 'show',
                target => CTX->request->target_group_id,
                additional => [ $page->title ],
            ),
        )
    );

    my $sections = $self->_current_sections_for_page( $page );
    $self->_filter_outgoing_links( $page, $sections );
    $self->_filter_outgoing_images( $page, $sections );
    my $content = $self->_sections_to_html( $sections );

    my $box = Dicole::Box->new();
    $box->name( $title->generate_content );
    $box->content( Dicole::Widget::Raw->new( raw => $content ) );
    $box->class( 'wiki_summary_page_' . $page_id );

    return $box->output;
}

sub summary_front_page {
    my ( $self ) = @_;

    my $starting_page = Dicole::Settings->fetch_single_setting(
        tool => 'wiki',
        attribute => 'starting_page',
        group_id => $self->param('target_group_id'),
    );

    return undef unless $starting_page;

    my $page = $self->_fetch_page( $starting_page, undef, $self->param('target_group_id') );

    return undef unless $page;

    my $title = Dicole::Widget::Horizontal->new;

    $title->add_content(
        Dicole::Widget::Hyperlink->new(
            content => $self->_msg( "[_1] (wiki front page title)", $page->readable_title ),
            link => Dicole::URL->create_from_parts(
                action => 'wiki',
                task => 'show',
                target => $self->param('target_group_id'),
                additional => [ $page->title ],
            ),
        )
    );

    my $sections = $self->_current_sections_for_page( $page );
    $self->_filter_outgoing_links( $page, $sections );
    $self->_filter_outgoing_images( $page, $sections );
    my $content = $self->_sections_to_html( $sections );

    my $box = Dicole::Box->new();
    $box->name( $title->generate_content );

    if ( $content =~ /^\s*$/m ) {
        $box->content( Dicole::Widget::Text->new( text => $self->_msg('The wiki starting page is currently empty. You can add content to the starting page by entering the wiki tool from the top navigation.') ) );
    }
    else {
        $box->content( Dicole::Widget::Raw->new( raw => $content ) );
    }
    $box->class( 'wiki_summary_front_page' );

    return $box->output;
}

sub _summary_customize {
    my ( $self ) = @_;

    my $title = Dicole::Widget::Horizontal->new;
    $title->add_content(
        Dicole::Widget::Hyperlink->new(
            content => $self->_msg('Updates in wiki'),
            link => Dicole::URL->create_from_parts(
                action => 'wiki',
                task => 'history',
                target => $self->param('box_group'),
            )
        )
    );

    return {
        box_title => $title->generate_content,
        object => 'wiki_version',
        query_options => {
            where => 'groups_id = ? AND  change_type = ?',
            value => [
                $self->param('box_group'),
                 OpenInteract2::Action::DicoleWiki::CHANGE_NORMAL
            ],
            limit => 25,
            order => 'creation_time DESC',
        },
        empty_box => $self->_msg( 'No changes found.' ),
        date_field => 'creation_time',
    };
}

sub _summary_add_item {
    my ( $self, $cl, $topic, $item, $config ) = @_;
    # Add new item entry, use _summary_item_href and _summary_item_author
    # to retrieve item href and author
    my $page = $item->wiki_page;
    my $author = $item->creator_id_user( { skip_security => 1 } );

    my $aname = join ' ', ( $author->{first_name}, $author->{last_name} );
    my $text = $item->change_description ? $item->change_description . ' - ' . $aname : $aname;

    my $content =
        Dicole::DateTime->time( $item->{ $config->{date_field} } ) . ' ' .
        $page->{readable_title};

    my $vn = $item->version_number;
    my $href = Dicole::URL->create_from_parts(
            action => 'wiki',
            task => 'show',
            target => $self->param('box_group'),
            other => [ $page->{title} ],
        );

        # FIXME: Try to add links in summary for both the changeset and the page itself
        #Dicole::URL->create_from_parts(
        #    action => 'wiki',
        #    task => 'changes',
        #    target => $self->param('box_group'),
        #    other => [ $page->{title}, $vn - 1, $vn ],
        #) :

    $cl->add_entry(
        topic => $topic,
        elements => [
            {
               width => '99%',
               content => new Dicole::Content::Hyperlink(
                    content => $content,
                    text => $text,
                    attributes => { href => $href },
                ),
            }
        ]
    );
}

sub _post_data_retrieve {
    my ( $self, $data, $config ) = @_;
    
    return unless $data;
    
    my %checkhash = ();
    my @top_changes = ();
    for my $change ( @$data ) {
        my $key = join ",", (
            $change->page_id,
            $change->creator_id,
            $change->change_description,
        );
        next if $checkhash{ $key };
        $checkhash{ $key }++;
        push @top_changes, $change;
        last if scalar( @top_changes ) >= 5;
    }

    return \@top_changes;
}

1;

