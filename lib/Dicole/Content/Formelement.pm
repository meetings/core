package Dicole::Content::Formelement;

use 5.006;
use strict;
use Dicole::Content::Text;

use OpenInteract2::Context   qw( CTX );

$Dicole::Content::Formelement::VERSION = sprintf("%d.%02d", q$Revision: 1.10 $ =~ /(\d+)\.(\d+)/);

use constant _TEXTFIELD_DEFAULT_SIZE => 35;

use base qw( Dicole::Content );

my %TEMPLATE_PARAMS = map { $_ => 1 }
    qw( required error value type name class size id   attributes );

sub TEMPLATE_PARAMS { \%TEMPLATE_PARAMS }

__PACKAGE__->mk_accessors( keys %TEMPLATE_PARAMS );
__PACKAGE__->mk_accessors( qw( modifyable plaintext_link no_filter ) );


sub _init {
        my ($self, %args) = @_;

        $args{template} ||= CTX->server_config->{dicole}{base} . '::input_input';
        $args{required} ||= 0;
        $args{error} ||= 0;
        $args{attributes} = {} unless ref $args{attributes} eq 'HASH';
        $args{modifyable} = 1 if ! defined $args{modifyable};

        $args{attributes}{size} = _TEXTFIELD_DEFAULT_SIZE if
            $args{attributes}{type} eq 'text' && ! $args{attributes}{size};

        $self->SUPER::_init( %args );
}

sub get_template {
        my $self = shift;

        if ( $self->modifyable ) {
            return $self->SUPER::get_template;
        }
        elsif ( $self->plaintext_link ) {
            return Dicole::Content::Hyperlink->new->get_template;
        }
        else {
            return Dicole::Content::Text->new->get_template;
        }
}

sub get_template_params {
        my $self = shift;

        if ( $self->modifyable ) {
            return $self->SUPER::get_template_params;
        }
        elsif ( $self->plaintext_link ) {

            # Cut links with spaces that are too long
            my $content = $self->attributes->{value};
            $content =~ s/([^\s]{39})([^\s]{1})/$1 $2/ while $content =~ /[^\s]{40}/;

            my $hyperlink = Dicole::Content::Hyperlink->new(
                content => $content,
                attributes => {
                    href => $self->plaintext_link,
                    alt => $self->attributes->{value},
                    title => $self->attributes->{value}
                }
            );

            return $hyperlink->get_template_params;
        }
        else {

            my $text = Dicole::Content::Text->new(
                text => $self->attributes->{value},
                no_filter => $self->no_filter
            );

            return $text->get_template_params;
        }
}


######
## COMPAT:


# $c->set_value('new'); # replaces the scalar in $c->{_content}{attributes}->{value};
sub set_value {
        my ($self, $content) = @_;
        $self->attributes->{value} = $content;
}

sub add_value {
        my ($self, $content) = @_;
        $self->attributes->{value} .= $content;
}

sub get_value {
        my $self = shift;
        return $self->attributes->{value};
}

sub clear_value {
        my $self = shift;
        undef $self->attributes->{value};
}

# xyz_content() -functions call the corresponding xyz_value() -function.
# The xyz_value() -functions are overriden in subclasses, but they can still use the xyz_content() -functions defined here.

sub add_content {
        my $self = shift;
        $self->add_value(@_);
}


# $c->set_name('new'); # replaces the scalar in $c->{_content}{attributes}->{name};
sub set_name {
        my ($self, $content) = @_;
        $self->attributes->{name} = $content if (defined $content);
}

sub get_name {
        my $self = shift;
        return $self->attributes->{name};
}

sub clear_name {
        my $self = shift;
        undef $self->attributes->{name};
}


# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Dicole::Content::Formelement - A base class for all the form element objects

=head1 SYNOPSIS

  use Dicole::Content::Formelement;
  my $object = Dicole::Content::Formelement->new(
        required => 1,
        modifyable => 1,
        attributes => { type => 'password', name => 'passwd' }
  );

  return $self->generate_content(
        { itemparams => $object->get_template_params },
        { name => $object->get_template }

=head1 DESCRIPTION

This is the base class of the Dicole::Content::Formelement::* classes, but it can be used to generate output as well.
The default template used is dicole_content::input_input.

=head1 METHODS

B<new( required => SCALAR, error => SCALAR, modifyable => SCALAR, attributes => HASHREF, plaintext_link => SCALAR )>
The 'required' argument defines if the blue arrow is displayed besides the drawn content. The 'error' argument
defines if a red arrow is drawn. 'modifyable' defines if the output is drawn as plain text or as modifyable form element.
'attributes' is a hashref of XHTML attributes for the input field.

If 'plaintext_link' argument is given, Dicole::Content::Hyperlink object is created as the plaintext version of this
object. The argument must contain the url of the link. Unless the argument is given, a normal Dicole::Content::Text
object is used instead.

B<set_value( SCALAR )>
Sets the value in {attributes}->{value} .

B<add_value( SCALAR )>
Same as $object->set_value( $object->get_val().'appended value' ) .

B<get_value()>
Returns {attributes}->{value} .

B<clear_value()>
Empties the value.

B<set_content()>
Calls set_value() and passes on the given arguments.

B<add_content()>
Calls add_value() and passes on the given arguments.

B<get_content()>
Calls get_value() and passes on the given arguments.

B<clear_content()>
Calls clear_value() and passes on the given arguments.

B<set_name( SCALAR )>
Sets the value in {attributes}->{name} .

B<get_name()>
Returns {attributes}->{name} .

B<clear_name()>
Empties the name.


B<get_template()>
Returns a template according to the value of $object->modifyable .

=head1 SEE ALSO

L<Dicole::Content|Dicole::Content>

=head1 AUTHOR

Antti V��otam�i,  E<lt>antti@ionstream.fiE<gt>
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

