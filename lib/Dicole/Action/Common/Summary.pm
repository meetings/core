package Dicole::Action::Common::Summary;

# $Id: Summary.pm,v 1.3 2008-04-17 10:46:51 amv Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::Box;
use Dicole::Content::CategorizedList;
use Dicole::Content::Hyperlink;
use Dicole::Content::Text;
use Dicole::Generictool::Data;
use Dicole::URL;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

A common action helper for creating tool summaries

=head1 SYNOPSIS

 use base qw( Dicole::Action Dicole::Action::CommonSummary );
 use Dicole::URL;

 sub _summary_customize {
     my ( $self ) = @_;
     return {
         box_title => 'Hello world',
         object => 'myspopsobject',
         empty_box => 'No worlds found.',
         date_field => 'my_date',
         title_field => 'title',
     }
 }

 sub _summary_item_href {
     my ( $self, $item ) = @_;
     return Dicole::URL->create_from_current(
        action => 'myworlds',
        task => 'show',
        params => { id => $item->id },
    );
 }

=head1 DESCRIPTION

A common action helper for implementing tool summaries. The basic idea is
to inherit this class in your action and override some methods to customize
what the summary box should contain.

=head1 TOOL CONFIGURATION

To configure your tool to display summaries on the summary page, you would have to inherit
this class and override necessary methods. Then you have to configure your tool
to notify summary generation about itself.

In I<conf/tool.ini>, add something like this:

 [tool 1]
 toolid = group_myworld
 name = My world
 description = My world tool.
 type = group
 secure =
 summary = my_summary

Notice the value of summary configration option. Now add in your I<conf/action.ini> something
like this:

 [my_summary]
 class  = OpenInteract2::Action::MyWorld
 secure_failure = summary
 method = summary

 [my_summary secure]
 default = OpenInteract2::Action::MyWorld::read

Note: I<secure_failure> must always be set to I<summary>.

The secure part defines the default task security, for which against the security
will be checked. If the security check fails, no summary box will be generated.

=head1 METHODS

=head2 summary()

Returns the summary data structure ready for feeding in the summary
template. This is actually the return value of method I<output()> in
class L<Dicole::Box>.

The method sets the box title and generates content if the box is
open ( action param I<box_open> is true). Then it calls the private
method I<_get_summary()> with summary box configuration (see method
I<_summary_customize()>), which returns either a L<Dicole::Content::CategorizedList>
(box contains items) object or a L<Dicole::Content::Text> object (box is empty).

=cut

sub summary {
    my ( $self ) = @_;

    # Get summary configuration
    my $config = $self->_summary_customize;

    $config->{box_title} ||= $self->_msg( 'Latest items' );
    $config->{object} ||= 'user';
    $config->{query_options} ||= {
        skip_security => 1,
        order => 'date DESC',
        limit => 10,
    };
    $config->{empty_box} ||= $self->_msg( 'No items.' );
    $config->{date_field} ||= 'date';
    $config->{title_field} ||= 'title';

    my $box = Dicole::Box->new;
    $box->name( $config->{box_title} );

    # If box is open, generate box content
    if ( $self->param( 'box_open' ) ) {
        my $recent = $self->_get_summary( $config );
        $box->content( $recent );
    }

    # Return box content
    return $box->output;
}

sub _get_summary {
    my ( $self, $config ) = @_;

    # Fetch data according to provided configuration
    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object( $config->{object} ) );
    $data->query_params( $config->{query_options} );
    $data->data_group;

    my $real_data = $self->_post_data_retrieve( $data->data, $config );
    unless ( $real_data && ref ( $real_data ) eq 'ARRAY' ) {
        $real_data = $data->data;
    }

    # Display empty item box if no data items returned
    if ( ! scalar @{ $real_data } ) {
         return Dicole::Content::Text->new(
            text => $config->{empty_box}
         );
    }

    my $last_month = -1;
    my $last_day = -1;

    my $cl = Dicole::Content::CategorizedList->new;
    my $category;
    my $topic;

    # Create summary box items as a categorized list
    foreach my $item ( @{ $real_data } ) {

        my $month = Dicole::DateTime->month_year_long(
            $item->{ $config->{date_field} }
        );
        my $day = Dicole::DateTime->day( $item->{ $config->{date_field} } );

        # If current month is not the same as previous month,
        # display month along with year as a new category.
        # If current day is not the same as previous day,
        # display day and weekday as a new topic.
        if ( $month ne $last_month || $day ne $last_day ) {
            if ( $month ne $last_month ) {
                $category = $cl->add_category(
                    name => $month,
                );
            }
            $topic = $cl->add_topic(
                category => $category,
                name => $day,
            );
        }

        $last_month = $month;
        $last_day = $day;

        $self->_summary_add_item( $cl, $topic, $item, $config );
    }

    return $cl;
}

=pod

=head1 INHERITABLE PRIVATE METHODS

=head2 _summary_add_item( OBJECT, HASHREF, OBJECT, CONFIG )

This method will be called from I<_get_summary()> to add
a new summary item to a L<Dicole::Content::CategorizedList>
object (the first parameter). The second parameter is the topic,
for which the item will be added. The item SPOPS object will
be in the third parameter.

By default this method adds an entry with two columns: the first
column is the hyperlinked title of the item (see also I<_summary_item_href()>
and I<title_field> customization option) and the second column
contains the item author (see I<_summary_item_author()>).

Override this method if you want to display more complicated items.

=cut

sub _summary_add_item {
    my ( $self, $cl, $topic, $item, $config ) = @_;
    # Add new item entry, use _summary_item_href and _summary_item_author
    # to retrieve item href and author
    $cl->add_entry(
        topic => $topic,
        elements => [
            {
               width => '99%',
               content => new Dicole::Content::Hyperlink(
                    text => $self->_summary_item_author( $item ),
                    content => $item->{ $config->{title_field} },
                    attributes => {
                        href => $self->_summary_item_href( $item )
                    },
                ),
            }
        ]
    );
}

=pod

=head2 _summary_customize()

Returns the configuration for the summary box as a hashref.

Override this method to configure what the summary box displays.

The summary configuration hashref is as follows:

=over 4

=item B<box_title> I<string>

The title of the box.

Default is I<Latest items>

=item B<object> I<string>

The spops class name which will be used.

Default is I<user>

=item B<query_options> I<hashref>

The query options to pass for SPOPS object
I<fetch_group>.

The default is I<limit = 10, order = date DESC and skip_security = 1>.

=item B<empty_box> I<string>

The text to display in an empty box (no items found).

Default is I<No items.>

=item B<date_field> I<string>

The date field name in the SPOPS object to use for sorting
and displaying items in date categories.

Default is I<date>

=item B<title_field> I<string>

The title field name in the SPOPS object to use for
displaying the item name.

Default is I<title>

=back

=cut

sub _summary_customize {
    my ( $self ) = @_;
    return { };
}

=pod

=head2 _summary_item_href( OBJECT )

Returns the URL for an item. Receives the item SPOPS
object as a parameter.

Override this action to configure
where the item title link points to.

=cut

sub _summary_item_href {
    my ( $self, $item ) = @_;
    return Dicole::URL->create_from_current(
        action => 'myaction',
        task => 'show',
        params => { id => $item->id },
    );
}

=pod

=head2 _summary_item_author( OBJECT )

Returns the item author name. Receives the item SPOPS object
as a parameter. By default this method calls I<user() has_a> for
item SPOPS object and tries to catch I<first_name> and I<last_name>
fields to form the author name.

Override this action to configure
who is displayed as the author of an item.

=cut

sub _summary_item_author {
    my ( $self, $item ) = @_;
    my $author = $item->user( { skip_security => 1 } );
    return join ' ', ( $author->{first_name}, $author->{last_name} );
}

=pod

=head2 _post_data_retrieve( OBJECT_ARRAYREF, CONFIG_HASHREF )

Does nothing by default.

Can be used to modify the data or
instantiate some config variables with it.

Return new object arrayref.

=cut

sub _post_data_retrieve {
    my ( $self, $data, $config ) = @_;
    
    return $data;
}

=pod

=head1 SEE ALSO

L<Dicole::Content::CategorizedList>,
L<Dicole::Box>,
L<Dicole::Summary>,
L<Dicole::Content::Text>

=head1 AUTHOR

Teemu Arina E<lt>teemu@ionstream.fiE<gt>

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
