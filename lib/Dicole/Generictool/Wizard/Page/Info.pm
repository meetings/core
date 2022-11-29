package Dicole::Generictool::Wizard::Page::Info;

use 5.006;
use OpenInteract2::Context   qw( CTX );
use strict;

=pod

=head1 NAME

Dicole::Generictool::Wizard::Page::Info - The info page object used by the wizard

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 INHERITS

Inherits L<Dicole::Generictool::Wizard::Page|Dicole::Generictool::Wizard::Page>, and 
overwrites some of its methods.

=cut

use base qw( Dicole::Generictool::Wizard::Page );
use Dicole::Content::Text;

$Dicole::Generictool::Wizard::Page::Info::VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

Dicole::Generictool::Wizard::Page::Info->mk_accessors(
	qw( info )
);

=pod

=head1 METHODS

=head2 new( HASH )

Constructor. Accepts all superclass's arguments & the following. 

=over 4

=item B<info> I<text on the page> .

=back

=cut


sub _init {
	my ( $self, $args ) = @_;

	$self->SUPER::_init( $args ); # call _init() of the parent class

	$self->info( $args->{info} );
}

=pod

=head2 info( [SCALAR] )

Accessor for shown text the shown text.

=cut

=head2 activate()

This method should be called after initialization. Does all the dirty work.

=cut

sub activate {
	my $self = shift;

	$self->max_page_number( $self->page_number() ) if( $self->page_number > $self->max_page_number );

        my $info = Dicole::Content::Text->new( content => $self->info );

        $self->content( [
            [
                $info,
                $self->_generate_buttons, 
	        $self->_generate_hidden_fields,
            ]
        ] );

}


sub validate_fields {
	my $self = shift;
	return 1;
}


sub save_fields {
	my $self = shift;
        return 1;
}


=pod

=head1 SEE ALSO

L<Dicole|Dicole>, 
L<Dicole::Generictool::Wizard|Dicole::Generictool::Wizard>, 
L<Dicole::Generictool::Wizard::Page|Dicole::Generictool::Wizard::Page>, 
L<Dicole::Generictool::Wizard::Results|Dicole::Generictool::Wizard::Results>, 
L<Dicole::Generictool::Field|Dicole::Generictool::Field>, 
L<Dicole::Generictool::Field::Validate|Dicole::Generictool::Field::Validate>, 
L<Dicole::Generictool::Field::Construct|Dicole::Generictool::Field::Construct>,
L<Dicole::Generictool|Dicole::Generictool>,
L<OpenInteract|OpenInteract>

=head1 AUTHORS

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

