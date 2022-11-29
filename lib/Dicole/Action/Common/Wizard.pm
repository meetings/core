package Dicole::Action::Common::Wizard;

# $Id: Wizard.pm,v 1.4 2009-01-07 14:42:32 amv Exp $

use base ( 'Dicole::Action::Common' );

use strict;
use OpenInteract2::Context   qw( CTX );

use Dicole::Content::Text;
use Dicole::Content::List;
use Dicole::Content::Controlbuttons;
use Dicole::URL;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

A common action helper for creating wizards

=head1 SYNOPSIS

 use base qw( Dicole::Action::Common::Wizard );

=head1 DESCRIPTION

A common action helper for implementing wizards.

=cut

__PACKAGE__->mk_accessors( qw( _sequence _unique_wizard_id _cancel_wizard ) );

sub _gen_steps {
    my ( $self ) = @_;

    my $steps = Dicole::Content::List->new( type => 'horizontal_simple' );
    my $s = 0; # Step number
    my $current_step = 0;
    my $content = [];
    foreach my $step ( @{ $self->_sequence } ) {
        my ( $task, $name ) = each %{ $step };
        $steps->add_key( { name => $s + 1 } ); # Step number
        if ( $self->task eq $task ) { # Current task is bold
            $current_step = $s + 1;
            push @{ $content }, { content => Dicole::Content::Text->new(
                content => $name,
                attributes => { style => 'font-weight: bold' },
            ) };
        }
        else {
            push @{ $content }, { content => $name };
        }
        $s++;
    }
    $steps->add_content_row( $content );
    my $cb = Dicole::Content::Controlbuttons->new;
    if ( $self->_cancel_wizard ) {
        $cb->add_buttons( {
            name => 'cancel_wizard',
            value => $self->_msg( 'Cancel' ),
        } );
    }
    if ( $current_step > 1 ) {
        $cb->add_buttons( {
            name => 'previous_step',
            value => $self->_msg( 'Previous' ),
        } );
    }
    if ( $current_step >= 1 && $current_step < $s ) {
        $cb->add_buttons( {
            name => 'next_step',
            value => $self->_msg( 'Next' ),
        } );
    }

    $self->tool->Container->box_at( 0, 0 )->name( $self->_msg( "Steps" ) );
    $self->tool->Container->box_at( 0, 0 )->add_content( [ $cb, $steps ] );
}

sub _change_step {
    my ( $self ) = @_;

    my $i = 0;
    foreach my $step ( @{ $self->_sequence } ) {
        my ( $task ) = keys %{ $step };
        if ( $self->task eq $task ) {
            my $step_number = $i + 1; # Default to next step
            if ( CTX->request->param( 'previous_step' ) ) {
                $step_number = $i - 1;
            }
            my $next_task = undef;
            ( $next_task ) = keys %{ $self->_sequence->[ $step_number ] }
                if ref( $self->_sequence->[ $step_number ] ) eq 'HASH';
            unless ( $next_task ) {
                ( $next_task ) = keys %{ $self->_sequence->[0] };
            }
            return CTX->response->redirect(
                Dicole::URL->create_full_from_current( task => $next_task )
            );
        }
        $i++;
    }
}

sub _store_wizard_objects {
    my ( $self, $objects, $task, $additional ) = @_;
    $task ||= $self->task;
    my @path = ( 'wizard', 'steps', $self->name, $task );

    $additional ||= $self->_unique_wizard_id;
    push @path, $additional if $additional;

    if ( ref( $objects ) eq 'ARRAY' ) {
        CTX->request->sessionstore->set_value( @path, $objects );
    }
    else {
        CTX->request->sessionstore->set_value( @path, $objects );
    }
}

sub _retrieve_wizard_objects {
    my ( $self, $task, $additional ) = @_;
    $task ||= $self->task;
    my @path = ( 'wizard', 'steps', $self->name, $task );

    $additional ||= $self->_unique_wizard_id;
    push @path, $additional if $additional;

    my $objects = CTX->request->sessionstore->get_value( @path );
    if ( ref( $objects ) eq 'ARRAY' ) {
        return $objects;
    }
    elsif ( ref( $objects ) ) {
        return $objects;
    }
    else {
        return undef;
    }
}

sub _clear_wizard_objects {
    my ( $self, $task, $additional ) = @_;
    $task ||= $self->task;
    my @path = ( 'wizard', 'steps', $self->name, $task );

    $additional ||= $self->_unique_wizard_id;
    push @path, $additional if $additional;

    my $objects = CTX->request->sessionstore->delete_value( @path );
    return 1;
}

sub _if_change_step {
    my ( $self ) = @_;
    return 1
        if CTX->request->param( 'next_step' )
        || CTX->request->param( 'previous_step' );
    return undef;
}

=pod

=head1 SEE ALSO

L<Dicole::Action::Common>

=head1 AUTHOR

Teemu Arina E<lt>teemu@dicole.orgE<gt>

=head1 COPYRIGHT AND LICENSE

 Copyright (c) 2005 Ionstream Oy / Dicole
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
