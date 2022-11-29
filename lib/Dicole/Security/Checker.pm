package Dicole::Security::Checker;

# $Id: Checker.pm,v 1.16 2010-07-20 04:08:04 amv Exp $

use strict;
use Dicole::Security qw( :check :target );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

=pod

=head1 NAME

Module for handling security checks

=head1 SYNOPSIS

To check rights for the current user

  use base qw( Dicole::Security::Checker );

  my $id_string = "id_of_group_right";
  my $group_id = 1;

  # checks from caller module for CHECK_YES, returns 1/0
  do() if $self->chk_y($id_string, $group_id);

  # checks for CHECK_NO, returns 1/0
  do() if $self->mchk_n(__PACKAGE__, $id_string, $group_id);

  # and for security string from another package
  do() if $self->schk_y('OpenInteract2::Action::Moo::read', $group_id);

Or to check rights for an another user:

  use Dicole::Security::Checker;

  my $checker = Dicole::Security::Checker->new( $user_id );
  do() if $checker->chk_y($id_string, $group_id);

=head1 DESCRIPTION

This is a class which helps checking dicole securities. It can be
used as a base class for Dicole::Action for checking current
users rights easily. You should however create a new class for
each other user whose rights you wish to check.

Beware that even if the creation of the object is not a heavy
operation as the base security data is shared with the singleton
Dicole::Security object, the whole rights structure is fetched
for the user upon the first security check. You should not use
this interface if you are for example quering only one security
for a large number of different users!

=head1 CLASS METHODS

=head2 new( [INT] )

Parameter: User id of the user whose securities should be checked.
0 checks for global rights only. Basically this id is just passed to
a Dicole::Security object constructor and thus defaults to
the id of the user who is currently logged in or 0 if no user
is logged in.

Creates a security checker object for given users rights. If the
class is inherited, the singleton Dicole::Security object is used
for checking the rights, which usually means the rights of the
current user.

=cut

sub new {
    my ( $class, $id, $type ) = @_;

    my $self = bless {}, $class;
    $self->{_dicole_security_object} = Dicole::Security->new(
        $id, $type
    );

    return $self;
}

=head1 OBJECT METHODS

There are following methods available for checking securities:

  chk_y, chk_n, chk_u
  schk_y, schk_n, schk_u
  mchk_y, mchk_n, mchk_u

Each of these methods returns 1 or 0 depending on if the
rights check for the specified security level and target id
matches the wanted security status.

The suffix indicates the wanted security status:

  _y : CHECK_YES
  _n : CHECK_NO
  _u : CHECK_UNDEF

Prefix indicates what kind of parameters should be supplied to
define the checked right and the id of the target object.

If the checker is also an instance of Dicole::Action, object
id defaults to target id of the actions target type. For this
to work, actions target tupe MUST be set. Otherwise object id
defaults to 0 (which means right for _all_ targets).

=cut

sub change_current_rights {
    my ( $self, $id, $type ) = @_;

    $self->{_dicole_security_object} = Dicole::Security->new(
        $id, $type
    );
}

sub current_rights {
    my ( $self, $id, $type ) = @_;

    return $self->{_dicole_security_object};
}

=head2 chk_? ( $level_id_string, $object_id )

Uses the calling object package as module name.

=head2 schk_? ( $full_level_string, $object_id )

Separates module name and level id string from full level string.

=head2 mchk_? ( $module_name, $level_id_string, $object_id )

Just uses the parameters.

=cut

sub chk_y { my @c = caller; return _chk( $c[0], CHECK_YES, @_ ); }
sub chk_n { my @c = caller; return _chk( $c[0], CHECK_NO, @_ ); }
sub chk_u { my @c = caller; return _chk( $c[0], CHECK_UNDEF, @_ ); }

sub schk_y { return _schk( CHECK_YES, @_ ); }
sub schk_n { return _schk( CHECK_NO, @_ ); }
sub schk_u { return _schk( CHECK_UNDEF, @_ ); }

sub mchk_y { return _mchk( CHECK_YES, @_ ); }
sub mchk_n { return _mchk( CHECK_NO, @_ ); }
sub mchk_u { return _mchk( CHECK_UNDEF, @_ ); }

=pod

=head2 check_ini_secure( STRING|ARRAYREF, INT )

Receives a secure key value from an ini file and responds wether
it passes.

Joins multiple securities with a comma and calls check_secure.
Go read it.

=cut

sub check_ini_secure {
    my ( $self, $secure, $target ) = @_;
    if ( ref( $secure ) eq 'ARRAY' ) {
        return $self->check_secure( join( ',', @$secure), $target );
    }
    else {
        return $self->check_secure( $secure, $target );
    }
}

=pod

=head2 check_secure( STRING, INT )

When given a CSV format secure-string, returns wether they are met.
Secure string consists of one or several possibilities separated
by a comma. Each possibility consists of one or several needed
securities separated by a plus sign.

Class method uses current user, Object method uses initialized rights

=cut

sub check_secure {
    my ( $self, $secure, $target ) = @_;

    return 1 unless $secure;
    
    my $checker = ( ref( $self ) && $self->can( 'schk_y' ) ) ?
        $self : Dicole::Security::Checker->new;
    
    my @possible = split /\s*,\s*/, $secure;
    foreach my $possibility ( @possible ) {
        my @secs = split /\s*\+\s*/, $possibility;
        my $success = 1;
        foreach my $sec ( @secs ) {
            $success = 0 if $sec && ! $checker->schk_y( $sec, $target );
        }
        return 1 if $success;
    }
    return 0;
}

sub _chk {
    my ( $caller, $wanted, $self, $string, $id ) = @_;

    return _mchk( $wanted, $self, $caller, $string, $id, $wanted );
}

sub _schk {
   my ( $wanted, $self, $str, $id ) = @_;

    my ( $module, $string ) = $str =~ /^(.*)::(.*)$/;

    return 1 unless $module && $string;

    return _mchk( $wanted, $self, $module, $string, $id );
}

sub _mchk {
    my ( $wanted, $self, $module, $string, $id ) = @_;

    $self->{_dicole_security_object} ||= Dicole::Security->new;

    if ( ! defined $id ) {
        my $target_type = $self->{_dicole_security_object}->
            target_type_for_level( $module, $string );
        $id = $self->_find_id_from_action( $target_type );
    }

    return $self->{_dicole_security_object}->
        check( $module, $string, $id ) == $wanted;
}

sub _find_id_from_action {
    my ( $self, $target_type ) = @_;

    return 0 if ! $self->isa('Dicole::Action');

    return $self->param( 'target_user_id' ) if
        $target_type == TARGET_USER;

    return $self->param( 'target_group_id' ) if
        $target_type == TARGET_GROUP;

    return $self->param( 'target_object_id' ) if
        $target_type == TARGET_OBJECT;

    return 0;
}

1;

=head1 AUTHOR

Antti Vähäkotamäki E<lt>antti@ionstream.fiE<gt>,

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

