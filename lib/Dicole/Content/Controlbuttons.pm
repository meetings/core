package Dicole::Content::Controlbuttons;

use 5.006;
use strict;

$Dicole::Content::Controlbuttons::VERSION = sprintf("%d.%02d", q$Revision: 1.6 $ =~ /(\d+)\.(\d+)/);

use base qw( Dicole::Content );

use OpenInteract2::Context   qw( CTX );

use Dicole::Content::Button;

__PACKAGE__->mk_accessors(
	qw( buttons )
);


#-------------------------------------------------------------------

# Dicole::Content::Controlbutton->new(buttons => [
#                                                   Dicole::Content::Button->new(),
#                                                   Dicole::Content::Button->new(),
#                                                ]
#                                    );
# new() calls _init() and passes on the arguments.
sub _init {
        my ($self, %args) = @_;
        $args{template} ||= CTX->server_config->{dicole}{base} . '::tool_secnav';
        $args{buttons} = [] if ref $args{buttons} ne 'ARRAY';

        # XXX: this interface is reeeally twisted..
        $self->buttons( [] );
        $self->add_buttons( $args{buttons} );
        delete $args{buttons};

        $self->SUPER::_init( %args );
}


# Accepts both array of classes and class as parameters
# Accepts also hashs. this is mean :(
sub add_buttons {
        my ( $self, $add ) = @_;
        
        my @buttons = ( ref( $add ) eq 'ARRAY' ) ? @{ $add } : ( $add );
        
        foreach my $button ( @buttons ) {
            if ( ref( $button ) eq 'HASH' ) {
                $button = Dicole::Content::Button->new( %{ $button } );
            }
            push @{ $self->buttons }, $button;
        }
}

sub get_template_params {
        my $self = shift;
        
        $self->template_params( [] );

        foreach my $button ( @{ $self->buttons } ) {
                push @{ $self->template_params }, {
                        template => $button->get_template(),
                        params => $button->get_template_params(),
                };
        }
        
        return $self->template_params;
}


# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Dicole::Content::Controlbuttons - A class that defines controlbutton objects

=head1 SYNOPSIS

  use Dicole::Content::Controlbuttons;
  my $buttons = Dicole::Content::Controlbuttons->new(
                  buttons => [ Dicole::Content::Button->new( name => 'change', value => 'Change password' ) ]
                );

  return $self->generate_content(
        { itemparams => $buttons->get_template_params },
        { name => $buttons->get_template }
  );

=head1 DESCRIPTION

This is a controlbutton class which is used to generate sets of control buttons in the programs. It is
simply given an array of buttons, and it returns the correct template values for the program. The class
is derived from Dicole::Content.

=head1 METHODS

B<new( buttons => ARRAYREF )>
The buttons argument must be a reference to an array containing a set of Dicole::Content::Button objects.

B<add_buttons( ARRAYREF )>
The method adds buttons.

This function is mean :/

=head1 SEE ALSO

L<Dicole::Content|Dicole::Content>
L<Dicole::Content::Button|Dicole::Content::Button>

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

