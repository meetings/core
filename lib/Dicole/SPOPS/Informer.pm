package Dicole::SPOPS::Informer;

# $Id: Informer.pm,v 1.3 2007-10-30 23:21:53 amv Exp $

use strict;
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context qw( CTX );


=pod

=head1 NAME

SPOPS inheritable module for registering object changes

=head1 SYNOPSIS

 [myspopsobject]
 ...
 isa = Dicole::SPOPS::Informer

 [myospopsbject inform]
 inform_default @= any,user,group,object,user_object,user_group_object
 inform_random @= user_object

 [myspopsobject inform_default]
 user_key = user_id
 group_key = group_id
 object_key = object_id

 [myspopsobject inform_random]
 append_class = Random
 ignore_keys @= last_checked, next_update
 user_key = user_id
 object_key = category_id

=head1 DESCRIPTION

This class provides save and remove hooks for a spops
object so that it informs of its modifications. Informing
is done with specified keys so that one can inspect if
data has been modified globally, for certain user, for
certain group for certain object or any combinations.

For ignore_keys to work the save call must pass a parameter
changed_keys which holds an array reference with all the
key names that have changed for this save.

NOTE: This class does not handle links_to modifications!

=cut

=pod

=head1 METHODS

=head2 ruleset_factory ( CLASS, RS_TABLE )

Specifies that dataset_update should be run post_save and pre_remove

=cut

sub ruleset_factory {
    my ( $class, $rs_table ) = @_;

    push @{ $rs_table->{post_save_action} }, \&inform;
    push @{ $rs_table->{pre_remove_action} }, \&inform;

    return __PACKAGE__;
}


=pod

=head2 inform ( ITEM, P )

Updates the object modification database with the given
objects change.

=cut

sub inform {

    my ($self, $p) = @_;

    my $action = eval{ CTX->lookup_action( 'record_object_change' ) };
    return 1 if !ref $action;

    my $class = ref $self;
    return 0 if ! $class;
    
    my $time = time();

    for my $key ( keys %{ $self->CONFIG->{inform} } ) {
        my $config = $self->CONFIG->{$key}
        my $types = $self->CONFIG->{ $self->CONFIG->{inform}{$key} } || [];
        my @types = ( ref $types eq 'ARRAY' ) ? ( @$types ) : ( $types );
        
        if ( my $ignore = $config->{ignore_keys} ) {
            if ( my $ckeys = $p->{changed_keys} ) {
                my @ignore = ( ref( $ignore ) eq 'ARRAY' ) ?
                     ( @$ignore ) : ( $ignore );
                my %ignore_lookup = map { $_ => 1 } @ignore;
                return 1 if grep { ! $ignore_lookup{$_} } @$ckeys;
            }
        }
        
        my $current_class = $class;
        $current_class .= '/' . $config->{append_class}
            if $config->{append_class};
        
        foreach my $type ( @types ) {
            my %params = (
                record_class => $current_class,
                record_time => $time,
                record_user => 0,
                record_group => 0,
                recorc_object => 0,
            );
            
            if ( $type =~ /user/ ) {
                $params{record_user} = $self->{ $config->{user_key} };
            }
            if ( $type =~ /group/ ) {
                $params{record_group} = $self->{ $config->{group_key} };
            }
            if ( $type =~ /object/ ) {
                $params{record_object} = $self->{ $config->{object_key} };
            }
            
            $action->execute( \%params );
        }
    }

    return 1;
}

1;

__END__

=head1 AUTHOR

Antti V�h�kotam�ki E<lt>antti@ionstream.fiE<gt>,

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

