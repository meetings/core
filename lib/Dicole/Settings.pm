package Dicole::Settings;

use strict;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

Manipulation of global Dicole settings

=head1 SYNOPSIS

 use Dicole::Settings;

 my $settings = Dicole::Settings->new;
 # Modify settings of current action based on current group
 $settings->group( 1 );
 $settings->tool( CTX->request->action_name );
 # Fetch settings based on above configuration
 $settings->fetch_settings;
 # Modify/add user_name setting
 $settings->setting( 'user_name', 'inf' ); # Set user_name setting
 print $settings->setting( 'user_name' ); # inf

 # Class methods for shortcuts:
 Dicole::Settings->fetch_single_setting(
    group_id => $group->id,
    tool => 'blogregator',
    attribute => 'last_update',
 );
 
 Dicole::Settings->store_single_setting(
    group_id => $group->id,
    tool => 'blogregator',
    attribute => 'last_update',
    value => time(),
 );

=head1 DESCRIPTION

The purpose of this class is to universally retrieve and manipulate the global Dicole tool
settings stored in the database. Dicole has a global tool settings database, which is
able to store tool specific configuration of various tools:

=over 4

=item *

Global tool settings for all tools.

Activated with: I<global>

=item *

Global tool settings for a certain tool (usually not group or user tool).

Activated with: I<global, tool>

=item *

Global tool settings for a certain group. Rarely used.

Activated with: I<global, group, group_id>

=item *

Global tool settings for a certain user in a certain group. Rarely used.

Activated with: I<global, group, group_id, user, user_id>

=item *

Global tool settings for a certain user. Rarely used.

Activated with: I<global, user, user_id>

=item *

Tool settings for a certain user tool.

Activated with: I<user, tool, user_id>

=item *

Tool settings for a certain group tool.

Activated with: I<group, tool, group_id>

=item *

Tool settings for a certain group tool for a certain user.

Activated with: I<group, tool, group_id, user, user_id>

=back

With activation we mean that all those class attributes must be defined
to operate on correct target settings.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors
for the class attributes.

=cut

use base qw( Class::Accessor );

=pod

=head1 ACCESSORS

=head2 tool( [STRING] )

Sets/gets the tool name to target with the settings. This enables
to point to a certain tool.

=head2 group( [BOOLEAN] )

Sets/gets the group bit. If this is enabled, then the system uses the
I<group_id()> class attribute.

Default: I<0>

=head2 group_id( [INTEGER] )

Sets/gets the group id. This enables pointing to a certain group tool.

Default: I<request target_id>

=head2 user( [BOOLEAN] )

Sets/gets the user bit. If this is enabled, then the system uses the
I<user_id()> class attribute.

Default: I<0>

=head2 user_id( [INTEGER] )

Sets/gets the user id. This enables pointing to a certain user tool.

Default: I<request target_id> or I<request auth_user_id>

=head2 global( [BOOLEAN] )

Sets/gets the global bit. If this is enabled, then all settings are
considered global. Global settings are something like "all group tools"
or "all tools in the system".

Default: I<0>

=head1 PRIVATE ACCESSORS

=head2 _settings( [ARRAYREF] )

Sets/gets the internally stored settings. This is an arrayref of settings
SPOPS objects.

Default: I<internally generated in fetch_settings()>

=cut

__PACKAGE__->mk_accessors( qw(
    tool group group_id user_id global user _settings _settings_hash
) );

=pod

=head1 CLASS METHODS

=head2 fetch_single_setting( HASH )
=cut
sub fetch_single_setting {
    my ( $class, %params ) = @_;
    
    my $settings = $class->_init_from_params( \%params );
    $settings->fetch_settings;
    
    return $settings->setting( $params{attribute} );
}

=head2 store_single_setting( HASH )
=cut
sub store_single_setting {
    my ( $class, %params ) = @_;
    
    my $settings = $class->_init_from_params( \%params );
    $settings->fetch_settings;
    
    return $settings->setting( $params{attribute}, $params{value} );
}

=head2 new_fetched_from_params( HASH )
=cut
sub new_fetched_from_params {
    my ( $class, %params ) = @_;
    
    my $settings = $class->_init_from_params( \%params );
    $settings->fetch_settings;
    
    return $settings;
}

sub _init_from_params {
    my ( $class, $params ) = @_;
    
    my $settings = Dicole::Settings->new;
    
    if ( ! $params->{tool} || ( !$params->{user_id} && ! $params->{group_id} ) ) {
        $settings->global( 1 );
    }
    
    if ( my $tool = $params->{tool} ) {
        $settings->tool( $tool );
    }
    
    if ( my $uid = $params->{user_id} ) {
        $settings->user( 1 );
        $settings->user_id( $uid );
    }
    
    if ( my $gid = $params->{group_id} ) {
        $settings->group( 1 );
        $settings->group_id( $gid );
    }
    
    return $settings;
}

=head1 METHODS

=head2 new( [HASH] )

Creates a new I<Dicole::Settings> object and returns it. Accepts
a hash of paramters to pass to the constructor. The constructor
accepts the accessor names as parameters.

=cut

sub new {
    my ($class, %args) = @_;
    my $config = { };
    my $self = bless( $config, $class );
    $self->_init(%args);
    return $self;
}

# "private" method to initialize object attributes
sub _init {
    my ( $self, %args ) = @_;

    my $action = $args{action};
    delete $args{action};
    
    # defaults
    my %default_args = (
        group_id    => $action ? $action->param('target_group_id') :
            CTX->request ? CTX->request->target_id : 0,
        user_id     => $action ? $action->param('target_user_id') :
            CTX->request ? CTX->request->target_id : 0,
        tool        => undef,
        global      => 0,
        user        => 0,
        group       => 0,
    );

    # If no target_id is found for user, use authenticated user id
    # ... erm.. why? well.. left here for backwards compatibility
    $default_args{user_id} ||= CTX->request ? CTX->request->auth_user_id : 0;

    # Set defaults but prefer user input
    foreach my $key ( keys %default_args ) {
        $self->$key( $default_args{$key} ) if $self->can( $key );
    }
    foreach my $key ( keys %args ) {
        $self->$key( $args{$key} ) if $self->can( $key );
    }
}

sub _cache_namespace {
    my ( $self ) = @_;
    return join( ":", ( $self->global, $self->tool, $self->user, $self->user_id, $self->group, $self->group_id ) );
}

sub _refresh_settings {
    my ( $self, $settings, $settings_hash ) = @_;

    $self->_settings( $settings || [] );
    $self->_settings_hash( $settings_hash || { map { $_->{attribute} => $_ } @{ $self->_settings } } );
    return unless CTX->request;
    my $namespace = $self->_cache_namespace;
    CTX->request->request_cache->{tool_setting}->{$namespace}->{objects} = $self->_settings;
    CTX->request->request_cache->{tool_setting}->{$namespace}->{objects_hash} = $self->_settings_hash;
}

=pod

=head2 fetch_settings( [BOOLEAN] )

Retrieves the settings based on class accessors. Sets I<_settings()> internally
and returns a reference to an arrayref of SPOPS objects.

If provided with a true boolean parameter, returns a SPOPS iterator instead of
SPOPS objects and does not set the I<_settings()>.

Returns undef upon failure.

Note that this method must be executed before executing most of the other class
methods. This is because the class internally operates with the I<_settings()> data.

=cut

sub fetch_settings {
    my ( $self, $iterator ) = @_;
    
    my $namespace = $self->_cache_namespace;

    if ( ! $iterator && CTX->request ) {
        my $cached = CTX->request->request_cache->{tool_setting}->{$namespace}->{objects};
        if ( $cached ) {
            $self->_refresh_settings(
                $cached,
                CTX->request->request_cache->{tool_setting}->{$namespace}->{objects_hash}
            );
            return $cached;
        }
    }

    my ( $where, $value );

    if ( $self->global ) {
        # Global settings for a certain tool
        if ( $self->tool ) {
            $where = 'tool = ? AND groups_id = 0 AND user_id = 0';
            $value = [ $self->tool ];
        }
        # Global settings for a certain group for a certain user
        elsif ( $self->group && $self->user ) {
            $where = 'tool IS NULL AND groups_id = ? AND user_id = ?';
            $value = [ $self->group_id, $self->user_id ];
        }
        # Global settings for a certain group
        elsif ( $self->group ) {
            $where = 'tool IS NULL AND groups_id = ? AND user_id = 0';
            $value = [ $self->group_id ];
        }
        # Global settings for a certain user
        elsif ( $self->user ) {
            $where = 'tool IS NULL AND user_id = ? and groups_id = 0';
            $value = [ $self->user_id ];
        }
        # Global settings
        else {
            $where = 'tool IS NULL AND groups_id = 0 AND user_id = 0';
        }
    }
    # Tool settings for a certain group for a certain user
    elsif ( $self->group && $self->user && $self->tool ) {
        $where = 'tool = ? AND groups_id = ? AND user_id = ?';
        $value = [ $self->tool, $self->group_id, $self->user_id ];
    }
    # Tool settings for a certain group
    elsif ( $self->group && $self->tool ) {
        $where = 'tool = ? AND groups_id = ? AND user_id = 0';
        $value = [ $self->tool, $self->group_id ];
    }
    # Tool settings for a certain user
    elsif ( $self->user && $self->tool ) {
        $where = 'tool = ? AND user_id = ? AND groups_id = 0';
        $value = [ $self->tool, $self->user_id ];
    }

    if ( $iterator ) {
        return CTX->lookup_object( 'dicole_tool_settings' )->fetch_iterator( {
            where => $where,
            value => $value
        } );
    }
    else {
        my $objects = CTX->lookup_object( 'dicole_tool_settings' )->fetch_group( {
            where => $where,
            value => $value
        } );
        $self->_refresh_settings( $objects );
        return $objects;
    }
}

=pod

=head2 setting( STRING, [STRING] )

With one parameter, gets the value of a requested setting.

With two parameters, sets the requested setting parameter with provided value.
Immediatly creates or modifies the setting and stores it into the database.
Updates the internal state of I<_settings()>.

=cut

sub setting {
    my ( $self, $attribute, $value ) = @_;

    my $object = $self->_get_setting_object( $attribute );

    if ( defined $value ) {
        if ( ref $object ) {
            $object->{value} = $value;
            $object->save;
        }
        else {
            $object = CTX->lookup_object( 'dicole_tool_settings' )->new;
            $object->{attribute} = $attribute;
            $object->{value} = $value;
            $object->{tool} = $self->tool;
            if ( $self->group ) {
                $object->{groups_id} = $self->group_id;
            }
            if ( $self->user ) {
                $object->{user_id} = $self->user_id;
            }
            $object->save;

            my $settings = $self->_settings;
            push @{ $settings }, $object;

            $self->_refresh_settings( $settings );
        }
    }

    return $object ? $object->{value} : undef;
}

=pod

=head2 settings_as_hash()

Returns the settings as a hash reference with I<parameter =E<gt> value> pairs.

=cut

sub settings_as_hash {
    my ( $self ) = @_;
    my $config = {};
    foreach my $key ( keys %{ $self->_settings_hash } ) {
        $config->{ $key } = $self->_settings_hash->{ $key }->{value};
    }
    return $config;
}

=pod

=head2 remove_setting( STRING )

Removes a requested setting from the retrieved settings.

=cut

sub remove_setting {
    my ( $self, $attribute ) = @_;
    my $object = $self->_get_setting_object($attribute);
    return undef unless $object;
    
    my $new = [];
    for my $object ( @{ $self->_settings } ) {
        if ( $object->{attribute} eq $attribute ) {
            $object->remove;
        }
        else {
            push @$new, $object;
        }
    }
    $self->_refresh_settings( $new );

    return 1;
}

=pod

=head2 remove_all_settings()

Removes all the retrieved settings.

=cut

sub remove_all_settings {
    my ( $self ) = @_;
    foreach my $object ( @{ $self->_settings } ) {
        $object->remove;
    }
    $self->_refresh_settings( [] );
    return 1;
}

=pod

=head1 PRIVATE METHODS

=head2 _get_setting_object( STRING )

Returns a requested setting object from the retrieved settings
based on provided parameter name.

=cut

sub _get_setting_object {
    my ( $self, $attribute ) = @_;

    return $self->_settings_hash->{ $attribute };
}

=pod

=head1 SEE ALSO

I<dicole_base package for dicole_tool_settings SPOPS object>

=head1 AUTHOR

Teemu Arina E<lt>teemu@ionstream.fiE<gt>,

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

