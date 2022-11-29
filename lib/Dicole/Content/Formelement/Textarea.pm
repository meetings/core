package Dicole::Content::Formelement::Textarea;

use 5.006;
use strict;

$Dicole::Content::Formelement::Textarea::VERSION = sprintf("%d.%02d", q$Revision: 1.7 $ =~ /(\d+)\.(\d+)/);

use base qw( Dicole::Content::Formelement Class::Accessor );

use OpenInteract2::Context   qw( CTX );

use constant _TEXTAREA_DEFAULT_ROWS => 8;
use constant _TEXTAREA_DEFAULT_COLUMNS => 30;


my %TEMPLATE_PARAMS = map { $_ => 1 }
        qw( htmlarea wikiedit htmlarea_fullpage content rows cols );

sub TEMPLATE_PARAMS {
    my $self = shift;

    return {
        %{$self->SUPER::TEMPLATE_PARAMS},
        %TEMPLATE_PARAMS
    };
}

__PACKAGE__->mk_accessors( keys %TEMPLATE_PARAMS );

#-------------------------------------------------------------------

# Dicole::Content::Formelement::Textarea->new(required => 1, error => 0, modifyable => 1, plaintext_link => 'http://...', attributes => { name => 'blah', value => 'blahblah', rows => 5, cols => 30 } );
# new() calls _init() and passes on the arguments.
sub _init {
    my ($self, %args) = @_;

    $args{template} ||= CTX->server_config->{dicole}{base} . '::input_textarea';


    ## compatibility for attributes

    for ( qw( rows cols name id ) ) {
        $args{$_} ||= $args{attributes}{$_};
    }

    $args{content} ||= $args{attributes}{value};

    $args{rows} ||= _TEXTAREA_DEFAULT_ROWS;
    $args{cols} ||= _TEXTAREA_DEFAULT_COLUMNS;

    delete $args{attributes};

    $self->SUPER::_init(%args);
}

sub get_template_params {
    my ($self) = @_;

    $self->id( $self->name ) unless $self->id;

    my $return = $self->SUPER::get_template_params;

    for ( qw( id name class rows cols ) ) {
        $return->{attributes}{$_} = $return->{ $_ };
        delete $return->{$_};
    }

    if ( $return->{htmlarea} && CTX->server_config->{dicole}{tinymce} ) {
        $return->{htmlarea} = 0;

        my @classes = split /\s+/, $return->{attributes}{class};
        push @classes, 'mceEditor';
        $return->{attributes}{class} = join ' ', @classes;
    }
    elsif ( $return->{htmlarea} && CTX->server_config->{dicole}{fckeditor} ) {
        $return->{htmlarea} = 0;
        $return->{fckeditor} = 1;
    }

    $return->{lang} = CTX->request->session->{lang}{code};

    return $return;
}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Dicole::Content::Formelement::Textarea - Textarea class

=head1 SYNOPSIS

  use Dicole::Content::Formelement::Textarea;
  my $object = Dicole::Content::Formelement::Textarea->new(
    required => 1,
    modifyable => 1,
    name => 'description',
    value => 'This is the description',
    rows => 5,
    cols => 20
  );

  return $self->generate_content(
    { itemparams => $object->get_template_params },
    { name => $object->get_template }

=head1 DESCRIPTION

This is the Textarea class, that is used to draw HTML form textareas. The
template used is dicole_base::input_textarea.

=head1 METHODS

B<new( required => SCALAR, error => SCALAR, modifyable => SCALAR, plaintext_link => SCALAR, attributes => { name => SCALAR, value => SCALAR, rows => SCALAR, cols => SCALAR } )>
The 'rows' and 'cols' arguments define the rows and columns used in the textarea.
These values do not affect the plaintext output that is given if 'modifyable' argument
is set to FALSE. 'value' argument contains the content of the textarea.

For description of the other parameters (and derived methods), see the documentation of
Dicole::Content::Formelement.

B<set_rows( SCALAR )>
Sets the number of rows used in the textarea.

B<get_rows()>
Returns the number of rows.

B<set_cols( SCALAR )>
Sets the number of columns used in the textarea.

B<get_cols()>
Returns the number of columns.

=head1 SEE ALSO

L<Dicole::Content::Formelement|Dicole::Content::Formelement>

=head1 AUTHOR

Hannes Muurinen, E<lt>hannes@ionstream.fiE<gt>

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

