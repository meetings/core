package Dicole::Feed;

use strict;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use XML::RSS;
use DateTime;
use Dicole::Pathutils;
use Dicole::URL;
#use Unicode::MapUTF8;
use XML::Atom;
use XML::Feed;
use Dicole::Utils::HTTP;

$XML::Feed::RSS::PREFERRED_PARSER = "XML::RSS::LibXML";
$XML::Atom::ForceUnicode = 1;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.28 $ =~ /(\d+)\.(\d+)/);

our $TRANS_TABLE = {
    ampers      => "&#38;#38;",
    apos        => "&#x2019;",
    bull        => "&#x8226;",
    caret       => "^",
    chi         => "&#x003C7;",
    copyleft    => "&#x00A9;",
    ditto       => '&#x201D;',
    eacute      => "&#x00E9;",
    eg          => "e.g.",
    etc         => "etc.",
    emsp        => "&#x00A0;&#x00A0;",
    epsilon     => "&#x003B5;",
    eta         => "&#x003B7;",
    euro        => "&#x20AC;",
    frac16      => "1/6",
    greaterthan => "&#38;gt;",
    gtilde      => "g&#x02DC;",
    hash        => "#",
    hellip      => "...",
    ie          => "i.e.",
    inch        => "&#x2033;",
    jnodot      => "j",
    lb          => "<br/>",
    ldquo       => "&#x2018;&#x2018;",
    lessthan    => "&#38;lt;",
    rdquo       => "&#x2019;&#x2019;",
    lsquo       => "&#x2018;",
    lstrok      => "&#x0142;",
    rsquo       => "&#x2019;",
    mdash       => "&#x00A0;&#x2014;",
    mrule       => "&#x2014;",
    mdot        => "mh",
    metafont    => "METAFONT",
    minus       => "&#x2212;",
    nbar        => "n",
    ndash       => "&#x2013;",
    nu          => "&#x003BD;",
    ohbar       => "o",
    olong       => '&#x0151;',
    ootie       => "oo",
    pi          => "&#x03C0;",
    quot        => '"',
    rarr        => "&#x2192;",
    rmfont      => "your current browser serif font",
    sect        => "#167;",
    sffont      => "your current browser sans-serif font",
    smiley      => "&#x2323;",
    shy         => "&#x00AD;",
    sterm       => "s",
    tau         => "&#x003C4;",
    thinsp      => "&#x2009;",
    trade       => "&#x2122;",
    ttfont      => "your current browser monospace font",
    ucaron      => "&#x016D;",
    uline       => "_",
    vbar        => "|",
    wcirc       => "&#x0175;",
};

=pod

=head1 NAME

Class for creating and parsing RSS feeds

=head1 SYNOPSIS

 use Dicole::Feed;

 my $feed = Dicole::Feed->new( version => '1.0' );
 my $rss = $feed->feed(
     action => $self,
     objects => CTX->lookup_object('myobject')->fetch_group,
     return_object => 1

 );
 return $rss->as_string;
 
 my $xml_feed_object = Dicole::Feed->parse( '<xml...' );

=head1 DESCRIPTION

A class for creating and parsing RSS feeds.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors
for the class attributes.

=cut

use base qw( Class::Accessor );

=pod

=head1 CLASS METHODS

=head2 fetch( STRING, INT )

Fetches an url with given timeout. Default timeout is 8 seconds.
Tries to convert data as utf8.

returns an URI::Fetch::Response object.

=cut

sub fetch {
    my( $class, $url, $timeout, $user, $pass ) = @_;

    $timeout ||= 8;

    my $content = Dicole::Utils::HTTP->get( $url, $timeout, $user, $pass );

    return $class->parse( $content );
}

=pod

=head1 CLASS METHODS

=head2 parse( STRING )

Parses the string as an XML::Feed object

=cut

sub parse {
    my($class, $content) = @_;

    # override XML::LibXML with Liberal
    my $sweeper; # XML::Liberal >= 0.13

    eval { require XML::Liberal };
    if (!$@ && $XML::Liberal::VERSION >= 0.10) {
        $sweeper = XML::Liberal->globally_override('LibXML');
    }

    my $remote = eval { XML::Feed->parse(\$content) }
        or Carp::croak("Parsing content failed: " . ($@ || XML::Feed->errstr));

    return $remote;
}

# Not needed since setting category array does not work anyway
sub normalize_feed_tags {
    my( $class, $feed ) = @_;

    for my $entry ( $feed->entries ) {
        # Category handling adapted from Plagger
        my @orig_cats = $entry->category;
        my $category = [ @orig_cats ];

        # XXX XML::Feed doesn't support extracting atom:category yet
        if ($feed->format eq 'Atom' && $entry->{entry}->can('categories')) {
            my @categories = $entry->{entry}->categories;
            for my $cat (@categories) {
                push @$category, $cat->label || $cat->term || ();
            }
        }

        my @cats = ();
        my %pushed_cats = ();
        for ( @$category ) {
            next if exists $pushed_cats{ $_ };
            $pushed_cats{ $_ } = ();
            push @cats, $_;
        }

        $class->_set_categories( $entry, \@cats );
    }

    return $feed;
}

# This does only harm as at least atom feeds return what they wish..
sub convert_to_utf8 {
    my( $class, $feed ) = @_;

    for my $entry ( $feed->entries ) {
        my @category = $entry->category;
        my @cats = map { Dicole::Utils::Text->ensure_utf8( $_ ) } @category;
        $class->_set_categories( $entry, \@cats );

        $entry->title( Dicole::Utils::Text->ensure_utf8( $entry->title ) );
        $entry->content->body( Dicole::Utils::Text->ensure_utf8( $entry->content->body ) )
            if $entry->content;
    }

    return $feed;
}

sub _set_categories {
    my( $class, $entry, $cats ) = @_;

    my $item = $entry->{entry};
    $item->{categories} = $cats;
    $item->{category} = $cats;
}

=pod

=head1 ACCESSORS

=head2 action( Dicole::Action )

The action to use for generating at least the links.

=head2 version( [STRING] )

Sets/gets the RSS feed version which will be used to create the feed.
Valid values are 0.9, 0.91, 1.0 and 2.0.

Default: I<1.0>.

=head2 title( [STRING] )

Sets/gets the title of the feed.

Default: I<Dicole>

=head2 link( [STRING] )

Sets/gets the link to the list of the items in the feed.

Default: current url

=head2 desc( [STRING] )

Sets/gets the description of the feed.

=head2 display_task( [STRING] )

Sets/gets the task of the action which will display a single item.

Default: show

=head2 list_task( [STRING] )

Sets/gets the task of the action which will display the list
of items in the feed.

Default: list

=head2 abstracts_only( [BOOLEAN] )

Sets/gets the abstracts only bit. If this is on, only the abstracts
of the feed items will be displayed in the feed item descriptions.

Default: 0

=head2 charset( [STRING] )

Sets/gets the character set of the content. The feed will be provided
UTF-8 encoded no matter what input character set your content is in.
If your input is encoded in other format than UTF-8, specify it here.

The default is the return value of
I<CTX-E<gt>request-E<gt>session-E<gt>{lang}{charset}>

=head2 creator( [STRING] )

Sets/gets the creator of the feed. This is usually the name of the
generator, e.g. I<Dicole Weblog>.

The default is I<Dicole>.

=head2 publisher( [STRING] )

Sets/gets the publisher of the feed. This is usually the name of the
environment, e.g. I<Dicole>.

The default is I<Dicole>.

=head2 language( [STRING] )

Sets/gets the language of the feed.

The default is I<en-us>.

=head2 date_field( [STRING] )

Sets/gets the field of the SPOPS object which contains the date of the item.
The date field should contain the date in epoch format.

Default: date

=head2 content_field( [STRING] )

Sets/gets the field of the SPOPS object which contains the content of the item.

Default: content

=head2 content_link( [STRING] )

Sets/gets the has_a relation of the object you wish to use. This is useful
if the content is in a different object, accessible through a
has_a relation. The content_field is then read from the has_a object.

=head2 abstract_field( [STRING] )

Sets/gets the field of the SPOPS object which contains the abstract or
excerpt of the item. See also accessor I<abstracts_only()>.

=head2 abstract_link( [STRING] )

Sets/gets the has_a relation of the object you wish to use. This is useful
if the abstract is in a different object, accessible through a
has_a relation. The content_field is then read from the has_a object.

=head2 title_field( [STRING] )

Sets/gets the field of the SPOPS object which contains the title of the item.

Default: title

=head2 subject_field( [STRING] )

Sets/gets the field of the SPOPS object which contains the subject of the item.

Default: subject

=head2 creator_field( [STRING] )

Sets/gets the field of the SPOPS object which contains the creator of the item.
Note: if the SPOPS object has_a I<user> object and the SPOPS object creator
field is empty, the creator is constructed of I<first_name> and I<last_name> of
the has_a I<user> object.

Default: creator

=head2 link_field( [STRING] )

Sets/gets the field of the SPOPS object which contains the link of the item.
Note: if the link field is empty, the link is constructed by using the
current action, task from the accessor I<display_task()> and I<id>
parameter set to SPOPS object id.

=head2 channel_dc( [HASHREF] )

Sets/gets the channel Dublin Core fields. These fields get merged with the
pre-generated ones, overriding any existing pre-generated fields. The pre-generated
fields are I<date, subject, creator, publisher and language>.

=head2 item_dc_field( [STRING] )

Sets/gets the channel item Dublin core field. If this is set, then each SPOPS
object will be read for the field. The field is expected to contain an anonymous
hash of Dublin Core metadata. These fields get merged with the pre-generated
ones, overriding any existing pre-generated fields. The pre-generated
fields are I<date, subject and creator>.

=cut

__PACKAGE__->mk_accessors( qw( action version title link desc
    charset display_task creator publisher language list_task abstracts_only
    date_field content_field content_link abstract_field abstract_link
    title_field subject_field creator_field link_field channel_dc item_dc_field
) );

=pod

=head1 METHODS

=head2 new( [HASH] )

Creates a new I<Dicole::Feed> object and returns it. Accepts
a hash of paramters to pass to the constructor. The constructor
accepts the accessor names as parameters.

=cut

sub new {
    my ($class, %args) = @_;
    my $config = { };
    my $self = bless( $config, $class );
    $self->_init(%args);
    return $self;
}

# "private" method to initialize object attributes
sub _init {
    my ( $self, %args ) = @_;

    $self->action( $args{action} );

    # defaults
    my %default_args = (
        version        => '1.0',
        title          => 'Dicole',
        link           => $self->action->derive_url,
        display_task   => 'show',
        list_task      => 'list',
        abstracts_only => 0,
        date_field     => 'date',
        channel_dc     => {},
        content_field  => 'content',
        title_field    => 'title',
        subject_field  => 'subject',
        creator_field  => 'creator',
        creator        => 'Dicole',
        publisher      => 'Dicole',
        language       => 'en-us',
        charset        => 'ISO-8859-1',
    );

    # If controller is not set or initial action is not current action, this means we do not know
    # the server URL and it's Dicole calling himself. Those feeds are usually
    # aggregated by aggregator, so we can safely generate feeds that have
    # relative URLs
    if ( CTX->controller && $self->action->name eq CTX->controller->initial_action->name ) {
        $default_args{link} = Dicole::Pathutils->new->get_server_url . $default_args{link};
    }

    # Set defaults but prefer user input
    foreach my $key ( keys %default_args ) {
        $self->$key( $default_args{$key} ) if $self->can( $key );
    }
    foreach my $key ( keys %args ) {
        $self->$key( $args{$key} ) if $self->can( $key );
    }
}

=pod

=head2 feed( HASH )

Creates and returns a feed. Sets content type and headers
accordingly for returning the content if content was requested.

Accepts a hash of parameters:

=over 4

=item B<objects> I<arrayref>

An array of SPOPS objects representing the feed items.
This parameter is required.

=item B<return_object> I<boolean>

Returns the L<XML::RSS> object instead of setting content type, headers
and returning the resulting RSS feed.

=back

=cut

sub feed {
    my $self = shift;
    my $args = {
        return_object => 0,
        objects => [],
        additional_prefix => [],
        @_
    };

    # If controller is not set or initial action is not current action, this means we do not know
    # the server URL and it's Dicole calling himself. Those feeds are usually
    # aggregated by aggregator, so we can safely generate feeds that have
    # relative URLs
    my $server_url = undef;
    if ( CTX->controller && $self->action->name eq CTX->controller->initial_action->name ) {
        $server_url = Dicole::Pathutils->new->get_server_url;
    }
    
    $self->link( $server_url . $self->action->derive_url(
        task => $self->list_task,
        additional => $args->{additional_prefix},
    ) ) if $self->list_task;
    $self->link( $server_url . $self->link ) unless $self->link =~ /^http/;

    my $rss = XML::RSS->new( version => $self->version );
    my $dt = DateTime->now;
    $rss->channel(
        title        => $self->title,
        link         => $self->link,
        description  => $self->_encode_xhtml_entities( $self->desc ),
        dc => {
            date       => $dt->ymd . 'T' . $dt->hms . '+00:00',
            subject    => $self->title,
            creator    => $self->creator,
            publisher  => $self->publisher,
            language   => $self->language,
            %{ $self->channel_dc }
       },
        syn => {
            updatePeriod     => "hourly",
            updateFrequency  => "1",
            updateBase       => "1901-01-01T00:00+00:00",
        }
    );

    foreach my $item ( @{ $args->{objects} } ) {
        my $dt = DateTime->from_epoch(
            epoch => $item->{ $self->date_field } || 0
        );

        my $creator = $item->{ $self->creator_field };
        if ( !$creator && ref $item ne 'HASH' && $item->can( 'user' ) ) {
            my $user = $item->user( { skip_security => 1 } );
            $creator = $user->{first_name} . ' ' . $user->{last_name};
        }

        my $content = $item->{ $self->content_field };
        if ( $self->content_link ) {
            my $link = $self->content_link;
            $content = $item->$link( { skip_security => 1 } )
                ->{ $self->content_field };
        }

        if ( $self->abstract_field ) {
            my $abstract = $item->{ $self->abstract_field };
            if ( $self->abstract_link ) {
                my $link = $self->abstract_link;
                $abstract = $item->$link( { skip_security => 1 } )
                    ->{ $args->{abstract_field} };
            }
            if ( $self->abstracts_only ) {
                $content = $abstract;
            }
            elsif ( $abstract ) {
                $content = $abstract . '<br /><br />' . $content
            }
        }

        my $item_url = $server_url;
        
        if ( $self->link_field ) {
            $item_url .= $item->{ $self->link_field };
        }
        else {
            my ( $additional, $params );
            
            # this is a hack.. when URL can form urls using url_additional
            # we can change this to a better one
            if ( $args->{id_in_additional} ) {
                $additional = [ @{ $args->{additional_prefix} }, $item->id ];
                $params = {};
            }
            else {
                $additional = $args->{additional_prefix};
                $params = { id => $item->id };
            }
        
            $item_url .= $self->action->derive_url(
                task => $self->display_task,
                additional => $additional,
                params => $params,
            );
        }

        $rss->add_item(
            title       => $item->{ $self->title_field },
            link        => $item_url,
            description => $self->_encode_xhtml_entities( $content ),
            dc => {
                date     => $dt->ymd . 'T' . $dt->hms . '+00:00',
                subject  => $item->{ $self->subject_field },
                creator  => $creator,
                ( $self->item_dc_field ) ? %{ $item->{ $self->item_dc_field } } : ()
            },
        );
    }
    return $rss if $args->{return_object};

    my $return = $rss->as_string;

    if ( $self->charset ) {
        use Encode ();
        Encode::from_to($return, $self->charset, "UTF-8");
    }

    # Don't show template only if initial action requested the feed

    if ( CTX->controller && $self->action eq CTX->controller->initial_action) {
        CTX->response->content_type( 'text/xml; charset=utf-8' );
        CTX->response->header( 'Content-Length', length( $return ) );
        CTX->controller->no_template( 'yes' );
    }

    return $return;
}

sub _encode_xhtml_entities {
    my ( $self, $content ) = @_;
    while ( my ( $tag, $replacement ) = each %{ $TRANS_TABLE } ) {
        $content =~ s/\&$tag;/$replacement/gms;
    }
    return $content;
}   

=pod

=head1 SEE ALSO

L<XML::RSS>

=head1 AUTHOR

Teemu Arina E<lt>teemu@ionstream.fiE<gt>,

=head1 COPYRIGHT AND LICENSE

 Copyright (c) 2004 Ionstream Oy / Dicole
 http://www.dicole.com

Licence version: MPL 1.1/GPL 2.0/LGPL 2.1

The contents of this file are subject to the Mozilla Public License Version
1.1 (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
for the specific language governing rights and limitations under the
License.

The Original Code is Dicole Code.

The Initial Developer of the Original Code is Ionstream Oy (info@dicole.com).
Portions created by the Initial Developer are Copyright (C) 2004
the Initial Developer. All Rights Reserved.

Contributor(s):

Alternatively, the contents of this file may be used under the terms of
either the GNU General Public License Version 2 or later (the "GPL"), or
the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
in which case the provisions of the GPL or the LGPL are applicable instead
of those above. If you wish to allow use of your version of this file only
under the terms of either the GPL or the LGPL, and not to allow others to
use your version of this file under the terms of the MPL, indicate your
decision by deleting the provisions above and replace them with the notice
and other provisions required by the GPL or the LGPL. If you do not delete
the provisions above, a recipient may use your version of this file under
the terms of any one of the MPL, the GPL or the LGPL.

=cut

1;

