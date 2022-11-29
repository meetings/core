package Dicole::Content::List;

use 5.006;
use strict;

$Dicole::Content::List::VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

use base qw( Dicole::Content );

use OpenInteract2::Context   qw( CTX );

my %TEMPLATE_PARAMS = map { $_ => 1 }
    qw( no_keys );

sub TEMPLATE_PARAMS { \%TEMPLATE_PARAMS; }

__PACKAGE__->mk_accessors( keys %TEMPLATE_PARAMS );
__PACKAGE__->mk_accessors( qw( keys content row_params type ) );

sub _init {
    my ($self, %args) = @_;

    for ('content', 'keys') {
        $args{$_} = [] unless ref $args{$_} eq 'ARRAY';
    }
    $args{row_params} = {} unless ref $args{row_params} eq 'HASH';
    $args{type} ||= 'vertical';

    $self->SUPER::_init( %args );
}


sub get_template {
    my $self = shift;
    return CTX->server_config->{dicole}{base} . "::list_" . $self->type;
}


sub get_template_params {
    my $self = shift;

    my $list = [];

    for(my $i=0; $i<$self->get_key_count(); $i++) {

        # current key.
        my $ck = $self->keys->[$i];

        my $key = {
            name => $ck->{name},
            attributes => $ck->{attributes}
        };

        if(ref($ck->{content}) =~ /^Dicole::Content/ ) {
            $key->{template} = $ck->{content}->get_template();
            $key->{params} = $ck->{content}->get_template_params();
        }

        my $row_ref = {
            key => $key,
            values => []
        };

        foreach my $row (@{$self->content}) {

            # current row
            my $cr = $row->[$i];

            # Generate a new Text object if a plain-text content is given

            if ( $self->type eq 'horizontal_simple' ) {
                if ( ref( $cr->{content} ) eq 'ARRAY' ) {

                    $row_ref->{value_list}{attributes} = $cr->{attributes};

                    foreach my $content_value ( @{ $cr->{content} } ) {

                        my $content_obj = ref( $content_value ) =~ /^Dicole::Content/
                             ? $content_value
                             : Dicole::Content::Text->new( content => $content_value );

                        push @{$row_ref->{value_list}{values}}, {
                            template => $content_obj->get_template(),
                            params => $content_obj->get_template_params()
                        };
                    }
                }
                else {

                    $row_ref->{value_list}{attributes} = $cr->{attributes};

                    my $content_obj = ref($cr->{content}) =~ /^Dicole::Content/
                        ? $cr->{content}
                        : Dicole::Content::Text->new(content => $cr->{content} );

                    push @{$row_ref->{value_list}{values}}, {
                        template => $content_obj->get_template(),
                        params => $content_obj->get_template_params()
                    };
                }

            }
            else {

                my $content_obj = ref($cr->{content}) =~ /^Dicole::Content/
                     ? $cr->{content}
                     : Dicole::Content::Text->new(content => $cr->{content} );
                push @{$row_ref->{values}}, {
                    attributes => $cr->{attributes},
                    template => $content_obj->get_template(),
                    params => $content_obj->get_template_params()
                };
            }
        }

        push @$list, $row_ref;
    }

    my $params = $self->SUPER::get_template_params;

    $params->{list} = $list;
    $params->{row_params} = $self->row_params;

    return $params;
}


# below this mostly compatibility stuff.. ;)


sub set_content {
    my ($self, $content) = @_;
    $self->content( $content );
}

sub add_content {
    my ($self, $content) = @_;
    push @{$self->content}, @{$content};
}

sub add_content_row {
    my ($self, $content) = @_;
    push @{$self->content}, $content;
}


# Returns the arrayref
sub get_content {
    my $self = shift;
    return $self->content;
}

sub clear_content {
    my $self = shift;
    $self->content( [] );
}

# number of "rows"
sub get_content_count {
    my $self = shift;
    my $count = @{$self->content};
    return $count;
}

sub set_keys {
    my ($self, $content) = @_;
    $self->keys( $content );
}

sub add_keys {
    my ($self, $content) = @_;
    push @{$self->keys}, @{$content};
}

sub add_key {
    my ($self, $content) = @_;
    push @{$self->keys}, $content;
}


sub get_keys {
    my $self = shift;
    return $self->keys;
}

sub clear_keys {
    my $self = shift;
    $self->keys( [] );
}

sub get_key_count {
    my $self = shift;
    my $count = @{$self->keys};
    return $count;
}

sub set_type {
    my ($self, $content) = @_;
    $self->type( $content );
}

sub get_type {
    my $self = shift;
    return $self->type;
}

sub set_sort {
}

sub get_sort {
}



# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Dicole::Content::List - A multipurpose list (table) class

=head1 SYNOPSIS

  use Dicole::Content::List;
  my $list = Dicole::Content::List->new(
    sort_primary   => { column => 'name', descending => 0 },
    type => 'vertical',
    keys    => [
        { name => 'name', content => Dicole::Content::Text->new(content => 'Name'), attributes => { class => 'contentTitle' } },
    ],
    content => [
        [ {
            content => Dicole::Content::Text->new(content => 'Joe'),
            attributes => { class => 'content' },
        } ],
    ]
  );

  $list->add_content( [
    [ {
        content => Dicole::Content::Text->new(content => 'Sue'),
    } ]
  ] );


  return $self->generate_content(
    { itemparams => $list->get_template_params },
    { name => $list->get_template }

=head1 DESCRIPTION

This is a general purpose list class that can be used to make horizontal/vertical tables with or without
sorting the columns/rows. Sorting is used mainly with dynamic content, but it can be disabled when
using the list class to make static tables. The template used is either dicole_base::list_horizontal or
dicole_base::list_vertical depending on the given list type. The object is derived from Dicole::Content.

=head1 METHODS

B<new(sort_primary   => { column => SCALAR, descending => BOOLEAN },
      type => SCALAR,
      keys    => [
        { name => SCALAR, content => OBJECT (Dicole::Content::*), attributes => HASHREF },
        ...
      ],
      content => [
         [ {content => OBJECT (Dicole::Content::*), attributes => HASHREF, sort_value => SCALAR },
           ...
         ],
         ...
      ]
     )>

The sort_primary argument defines the list sorting. If the hashref isn't defined (or it contains
invalid content), sorting is disabled and the content is displayed in the order it was entered to the
object. The column argument in sort_primary is the name of the column (or row) according to which the
sorting is done. The column name must be one of the {keys}->[$i]->{name} defined later. If boolean
descending is set to true, reverse alphabetical sorting is done.

The type argument must be either 'horizontal' or 'vertical'. If invalid or undefined argument is given,
default value 'vertical' is used.

The keys array is a list of keys (or columns or rows) used in this list. Think these keys as the headlines
of the corresponding row/column. Each element in the keys array is a hashref containing the following
elements:
- name, which is the name of the key. This is used when searching for the user defined sorting column. If the
  value of {keys}->[$i]->{content} is undefined, this plain text is used as the content of the row/column "headline"
  cell.
- content, which is the content inserted into the "headline" cell of the corresponding row/column (if defined). The value of
  {keys}->[$i]->{content} must be a Dicole::Content::* object.
- attributes, which is a hashref of XHTML attributes for the TD-cell.

The content array is a two-dimensional array of the list content. Each arrayref inside the content array represents
a row/column (depends on given type) of related information in the final list. When sorting, this related information
is kept together. That is, each arrayref in the content array represents the properties of a single entity. Each content
element in the second level array is defined in a hashref.

For example if the key names are 'name', 'address' and 'age', the content argument might contain the following arrayref:
[
 [{content => 'Joe'},{content => 'Road 1'},{content => '18'}],
 [{content => 'Sue'},{content => 'Road 2'},{content => '15'}],
 [{content => 'Paula'},{content => 'Road 3'},{content => '28'}],
]

When sorting the list, each arrayref inside the content array is moved. If the sorting was done according to the age, the
final sorted content array would be like
[
 [{content => 'Sue'},{content => 'Road 2'},{content => '15'}],
 [{content => 'Joe'},{content => 'Road 1'},{content => '18'}],
 [{content => 'Paula'},{content => 'Road 3'},{content => '28'}],
]

The order of the hashrefs inside the second level arrays must be the same as the order of the hashrefs in the keys array. For
example here the third element in the keys array was 'age', and so the third hashref in the content list represents age value.

The hashrefs inside the two-dimensional array can contain the following elements:
- content, which is the value displayed inside the cell. If this is a Dicole::Content::* object, its output is used in the cell.
  If the value is a SCALAR, a Dicole::Content::Text object is automatically generated and the given scalar value is used as its
  content.
- attributes, which is a hashref of XHTML attributes for the TD-cell.
- sort_value, which is an optional value that can be given for the cell. If it is defined, this value is used when doing the
  alphabetical sorting. If it isn't given, the output of the given content object is used by default. This can be used to do
  the sorting according to some invisible variable.

<B set_content( ARRAYREF )>
The argument must be a two-dimensional array containing hashrefs. The format is the same as in content parameter of the
constructor.

<B add_content( ARRAYREF )>
Adds a set of new rows/columns to the end of the list. The argument must be a two-dimensional array containing hashrefs.
The format is the same as in content parameter of the constructor. Only full entities of related data can be entered --
you cannot enter new hashrefs in the second level arrays later.

<B get_content()>
Returns a two-dimensional list of hashes.

<B clear_content()>
Clears the content.

<B get_content_count()>
Returns the number of rows/columns in the list (the number of the "entities of related information").

<B set_keys( ARRAYREF )>
The argument must be a reference to an array of hashes. The format is the same as in keys parameter of the constructor.

<B add_keys( ARRAYREF )>
Adds new keys to the array of keys.
The argument must be a reference to an array of hashes. The format is the same as in keys parameter of the constructor.

<B get_keys()>
Returns the array of hashes.

<B clear_keys()>
Clears the array of keys.

<B get_key_count()>
Returns the number of columns/rows in the list (the number of the distinct "headlines" or "types of data" in the list).

<B set_type( SCALAR )>
Sets the type of the output. Must be either 'horizontal' or 'vertical'. If invalid value is given, the default value
'vertical' is used.

<B get_type()>
Returns either SCALAR 'horizontal' or 'vertical'.

<B set_sort( primary => HASHREF )>
Sets the sorting parameters. The format of the HASHREF is the same as in sort_primary parameter of the constructor. The
primary hash key is used for possible future updates of the class (e.g. a secondary sorting column/row could be added).

<B get_sort()>
Returns a HASH of the sorting parameters. The hash contains at least key 'primary' which points to a hashref.

<B get_template_params()>
Sorts the list according to the current state of the object, and returns the contents of the object
in a format accepted by the dicole_base::list_horizontal and dicole_base::list_vertical templates. The returned format is:
    {
        list =
            [
                {
                    *key    =>
                        {
                            name        => the name of the key is printed on the page
                            *template   => name of the template
                            *params     =>
                                    {
                                        template parameters passed to the template in itemparams
                                    }
                            *attributes =>
                                    {
                                        XHTML attributes for the TD-tag
                                    }
                        }
                    values  =>
                        [
                            {
                                *attributes =>
                                        {
                                            XHTML attributes for the TD-tag
                                        }
                                template    =>  name of the template
                                params      =>
                                        {
                                            template parameters passed to the template in itemparams
                                        }
                            },
                            ...
                        ]
                },
                {
                    ...
                }
            ]
    }

The elements marked with a * are defined only if the corresponding elements are defined in the object.

=head1 SEE ALSO

L<Dicole::Content|Dicole::Content>

=head1 AUTHOR

Hannes Muurinen, E<lt>hannes@ionstream.fiE<gt>
Antti Vähäkotamäki, E<lt>antti@ionstream.fiE<gt>

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

