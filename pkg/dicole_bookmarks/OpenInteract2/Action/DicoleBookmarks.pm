package OpenInteract2::Action::DicoleBookmarks;

use strict;
use base qw( Dicole::Action );

use OpenInteract2::Context   qw( CTX );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use Dicole::Utils::JSON;

sub _bookmarking_enabled {
    my ( $self, $domain_id ) = @_;

    my $domain = eval { Dicole::Utils::Domain->guess_current( $domain_id ) };

    return 0 unless $domain;

    return 1 if $domain->domain_name =~ /sanako|languagepoint|work\-dev/;

    return 0;
}

sub add_user_bookmark_for_object {
    my ( $self ) = @_;
   
    return 0 unless $self->_bookmarking_enabled( $self->param('domain_id') );

    my $bookmarks = $self->_get_user_bookmarks_for_object;

    unless ( @$bookmarks ) {
        CTX->lookup_object('bookmark')->new({
            domain_id => $self->param('domain_id'),
            group_id => $self->param('group_id'),
            object_id => $self->param('object_id'),
            object_type => $self->param('object_type'),
            creator_id => $self->param('creator_id'),
            created_date => time,            
        })->save;
    
        $bookmarks = $self->_get_user_bookmarks_for_object;    
    }

    my $bookmark = shift @$bookmarks;

    $_->remove for @$bookmarks;

    return $bookmark;
}

sub remove_user_bookmark_for_object {
    my ( $self ) = @_;
   
    return 0 unless $self->_bookmarking_enabled( $self->param('domain_id') );

    my $bookmarks = $self->_get_user_bookmarks_for_object;

    $_->remove for @$bookmarks;

    return 1;
}

sub has_user_bookmarked_object {
    my ( $self ) = @_;
   
    return 0 unless $self->_bookmarking_enabled( $self->param('domain_id') );

    $self->_populate_params;

    my $bookmarks = $self->_get_user_bookmarks_for_object;

    return scalar( @$bookmarks ) ? 1 : 0;
}

sub _get_user_bookmarks_for_object {
    my ( $self ) = @_;
    $self->_populate_params;

    return CTX->lookup_object('bookmark')->fetch_group({
        where => 'domain_id = ? AND group_id = ? AND object_id = ? and object_type = ? AND creator_id = ?',
        value => [
            $self->param('domain_id'), $self->param('group_id'),
            $self->param('object_id'), $self->param('object_type'),
            $self->param('creator_id'),
        ], 
    }) || [];
}

sub get_user_bookmark_action_for_object {
    my ( $self ) = @_;

    return 0 unless $self->_bookmarking_enabled( $self->param('domain_id') );
    return 0 unless $self->param('creator_id');

    return $self->has_user_bookmarked_object ? 'remove' : 'add';
}

sub get_users_who_bookmarked_object {
    my ( $self ) = @_;

    return [] unless $self->_bookmarking_enabled( $self->param('domain_id') );

    $self->_populate_params;

    my $bookmarks = CTX->lookup_object('bookmark')->fetch_group({
        where => 'domain_id = ? AND group_id = ? AND object_id = ? and object_type = ?',
        value => [
            $self->param('domain_id'), $self->param('group_id'),
            $self->param('object_id'), $self->param('object_type'),
        ],
    });

    my $uids = [ map { $_->creator_id } @$bookmarks ];

    return Dicole::Utils::User->ensure_object_list( $uids );
}

sub count_users_who_bookmarked_object {
    my ( $self ) = @_;

    return 0 unless $self->_bookmarking_enabled( $self->param('domain_id') );

    $self->_populate_params;

    # TODO: this still counts users who are not part of the domain/group after they have been removed
    return CTX->lookup_object('bookmark')->fetch_count({
        where => 'domain_id = ? AND group_id = ? AND object_id = ? and object_type = ?',
        value => [
            $self->param('domain_id'), $self->param('group_id'),
            $self->param('object_id'), $self->param('object_type'),
        ],
    }) || 0;
}

sub bookmark_limited_fetch_group {
    my ( $self ) = @_;

    return [] unless $self->_bookmarking_enabled( $self->param('domain_id') );

    $self->_populate_id_params;

    my $object_class = $self->param('object_class');
    
    return [] unless $object_class;
    
    my $object_table = $object_class->base_table;
    my $object_id_field = $object_class->id_field;

    my $from = $self->param('from') || [ $object_table ];
    push @$from, $object_table unless scalar( grep { $_ eq $object_table } @$from );
       
    my $where = 'dicole_bookmark.creator_id = ? AND dicole_bookmark.group_id = ? AND dicole_bookmark.domain_id = ? AND ' .
        $object_table . '.' . $object_id_field . ' = dicole_bookmark.object_id ' .
        'AND dicole_bookmark.object_type = ?';

    $where = $where . ' AND ' . $self->param('where') if $self->param('where');
  
    my $value = [
        $self->param('creator_id'), $self->param('group_id'), $self->param('domain_id'),
        $object_class,
        @{ $self->param('value') || [] },
    ];
    
    return $object_class->fetch_group( {
        from => [ @$from, 'dicole_bookmark' ],
        where => $where,
        value => $value,
        order => $self->param('order'),
        limit => $self->param('limit'),
    } ) || [];
}

sub get_sidebar_html_for_object_bookmarkers {
    my ( $self ) = @_;

    return undef unless $self->_bookmarking_enabled( $self->param('domain_id') );
    
    my $users = $self->get_users_who_bookmarked_object;

    return undef unless @$users;

    my $params = {
        users => Dicole::Utils::User->icon_hash_list( $users, 40, $self->param('group_id'), $self->param('domain_id') ),
    };

    return $self->generate_content( $params, { name => 'dicole_bookmarks::bookmarkers_sidebar'} );
}

sub _populate_params {
    my ( $self ) = @_;
    
    $self->_populate_object_params;
    $self->_populate_id_params;
    $self->_populate_domain_params;
}

sub _populate_id_params {
    my ( $self ) = @_;
    
    if ( CTX->controller && CTX->controller->initial_action ) {
        my $ia = CTX->controller->initial_action;
        $self->param( 'group_id', $ia->param('target_type') eq 'group' ? $ia->param('target_group_id') : 0 )
            unless defined $self->param( 'group_id' );
    }
}

sub _populate_object_params {
    my ( $self, $param ) = @_;
    
    $param ||= 'object';
    if ( my $object = $self->param( $param ) ) {
        $self->param( $param . '_id', $object->id )
            unless defined $self->param( $param . '_id' );
        $self->param( $param . '_type', ref( $object ) )
            unless defined $self->param( $param . '_type' );
    }
}

sub _populate_domain_params {
    my ( $self, $param ) = @_;

    $param ||= 'domain';
    
    unless ( defined( $self->param( $param . '_id' ) ) ) {
        $self->param( $param . '_id', Dicole::Utils::Domain->guess_current_id );
    }
}




=pod

=head1 NAME

Dicole bookmarks system.

=head1 DESCRIPTION

System for handling bookmarks on different content.

=head1 BUGS
=head1 TODO
=head1 AUTHORS

Antti Vähäkotamäki

=head1 COPYRIGHT AND LICENSE

 Copyright (c) 2007 Dicole Oy
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
