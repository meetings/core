package Dicole::Content::CategorizedList;

use 5.006;
use strict;

use OpenInteract2::Context   qw( CTX );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

use base qw( Dicole::Content );

my %TEMPLATE_PARAMS = map { $_ => 1 } 
    qw( categories );

sub TEMPLATE_PARAMS { \%TEMPLATE_PARAMS; }

__PACKAGE__->mk_accessors( keys %TEMPLATE_PARAMS );

#-------------------------------------------------------------------

# Dicole::Content::Text->new(content => 'some text');
# new() calls _init() and passes the arguments
sub _init {
    my ($self, %args) = @_;
    $args{template} ||= CTX->server_config->{dicole}{base} . '::categorized_list';
    $args{categories} = [] if ref $args{categories} ne 'ARRAY';

    $self->SUPER::_init( %args );
}

sub add_category {
    my ( $self, %args ) = @_;

    my $category = {
        name => $args{name},
        href => $args{href},
        topics => [],
    };

    push @{ $self->categories }, $category;

    return $category;
}

sub add_topic {
    my ( $self, %args ) = @_;

    my $topic = {
        name => $args{name},
        href => $args{href},
        entries => [],
    };

    push @{ $args{category}{topics} }, $topic;

    return $topic;
}

sub add_entry {
    my ( $self, %args ) = @_;

    my $entry = {
        elements => $args{elements} || [],
    };

    push @{ $args{topic}{entries} }, $entry;

    return $entry;
}

sub get_template_params {
    my ( $self ) = @_;

    my $content = $self->categories;

    foreach my $cat ( @$content ) {
        foreach my $top ( @{ $cat->{topics} } ) {

            my $entries = [];

            foreach my $entry ( @{ $top->{entries} } ) {
                my $elements = [];

                foreach my $element ( @{ $entry->{elements} } ) {
                    push @$elements, {
                        width => $element->{width},
                        no_wrap => $element->{no_wrap},
                        template => $element->{content}->get_template,
                        params => $element->{content}->get_template_params,
                    };
                }

                push @$entries, $elements;
            }
            $top->{entries} = $entries;
        }
    }

    $self->template_params( { categories => $content } );

    return $self->template_params;
}


1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Dicole::Content::CategorizedList - A class that defines Dicole content object.

=head1 SYNOPSIS

  use Dicole::Content::CategorizedList;
  use Dicole::Content::Hyperlink;
  use Dicole::Content::Text;

  $cl = Dicole::Content::CategorizedList->new;

  my $category = $cl->add_category(
    name => 'June 2004',
    href => '/news/',
  );

  my $topic = $cl->add_topic(
    category => $category,
    name => '30th',
    href => "/news/$topic/",
  );

  $cl->add_entry(
    topic => $topic,
    elements => [
        {
            width => '70%',
            content => new Dicole::Content::Hyperlink(
                content => 'News headline',
                attributes => {
                    href => "/news/$topic/234",
                }
            ),
        },
        {
            width => '30%',
            content => new Dicole::Content::Text( text => '12:34 - timmy' ),
        }
    ]
  );

  return $self->generate_content(
    { itemparams => $cl->get_template_params },
    { name => $cl->get_template }
 );


=head1 DESCRIPTION

This is a class frequently used for displaying entries sorted by date x)

=head1 SEE ALSO

L<Dicole::Content|Dicole::Content>

=head1 AUTHOR

Antti V��otam�i, E<lt>antti@ionstream.fiE<gt>

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

