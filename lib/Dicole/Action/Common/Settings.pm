package Dicole::Action::Common::Settings;

# $Id: Settings.pm,v 1.8 2009-01-07 14:42:32 amv Exp $

use strict;
use OpenInteract2::Context   qw( CTX );

use Dicole::Settings;
use Dicole::Generictool;
use Dicole::Generictool::FakeObject;
use Net::Subnets;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.8 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

A common action helper for creating tool settings

=head1 SYNOPSIS

 use base qw( Dicole::Action Dicole::Action::Common::Settings );

 sub _settings_config {
     my ( $self, $settings ) = @_;
     $settings->tool( 'my_tool' );
 }

=head1 DESCRIPTION

A common action helper for implementing tool settings. The basic idea is
to inherit this class in your action and override some methods to customize
the generic settings functionality.

=head1 TOOL CONFIGURATION

The class requires you to override the I<_settings_config()> method and define
a view I<settings> in your I<fields.ini>. Example configuration:

 [views settings]
 fields = public_feed
 fields = ip_addresses_feed
 fields = number_of_items_in_feed

 [fields public_feed]
 id = public_feed
 type = checkbox
 desc = Feed is publicly accessible

 [fields ip_addresses_feed]
 id = ip_addresses_feed
 type = textarea
 desc = Limit feed access by IP addresses (each on a separate line)

 [fields number_of_items_in_feed]
 id = number_of_items_in_feed
 type = dropdown
 desc = Number of items in feed
 localize_dropdown = 1

 [dropdown number_of_items_in_feed]
 content = 5
 value = 5
 content = 10
 value = 10
 content = All
 value = 0

Also remember to add the settings tab into your I<tabs.ini>, similar to this:

[personal_weblog tab_2]
name = Settings
task = settings
secure = OpenInteract2::Action::MyTool::settings

To configure your tool to have a functional settings tab, you would have to inherit
this class and override necessary methods. The class uses the I<settings()> task so make
sure you are not using it before inheriting.

=head1 METHODS

=head2 settings()

The task which returns the settings editing page. Uses L<Dicole::Generictool>, L<Dicole::Generictool::Fakeobject>
and L<Dicole::Settings> to modify the settings in the database.

Uses the I<settings> view from the I<fields.ini> to find out what configuration options are available
and how to modify them.

=cut

sub settings {
    my ( $self ) = @_;

    my $settings = $self->_get_settings;
    $settings->fetch_settings;

    $self->init_tool( $self->_settings_tool_params );

    $self->gtool( Dicole::Generictool->new( current_view => 'settings' ) );
    # Lets fake we are a SPOPS object
    my $fake_object = Dicole::Generictool::FakeObject->new( { id => 'settings_id' } );
    $self->gtool->fake_objects( [ $fake_object ] );
    $self->init_fields;    # Run custom post-init operations

    $self->_post_init_common_settings;

    my $settings_hash = $settings->settings_as_hash;

    foreach my $param ( keys %{ $settings_hash } ) {
        $fake_object->{$param} = $settings_hash->{$param};
    }
    if ( CTX->request->param( 'save' ) ) {
        my ( $code, $message ) = $self->gtool->validate_input(
            $self->gtool->visible_fields
        );

        if ( $code ) {
            foreach my $field ( @{ $self->gtool->visible_fields } ) {
                $settings->setting( $field, $fake_object->{$field} || '' );
            }
            $self->tool->add_message( $code, $self->_msg('Settings saved.') );
        } else {
            $self->tool->add_message( $code,
                $self->_msg("Failed to edit settings: [_1]", $message )
            );
        }
    }

    $self->gtool->add_bottom_button(
        name => 'save',
        value => $self->_msg('Save'),
    );

    my $box = $self->_settings_container_box;

    $box->name( $self->_msg('Edit settings') );
    $box->add_content(
        $self->gtool->get_edit
    );

    $self->_pre_generate_common_settings;

    return $self->generate_tool_content;
}

=pod

=head1 METHODS TO OVERRIDE

=head2 _settings_config( OBJECT )

Usually this method is the only one you have to override to create a simple settings
page for your tool. I<_get_settings()> creates the L<Dicole::Settings> object and
sets the group or user attributes. The rest is up to you through this method.

Example:

 sub _settings_config {
     my ( $self, $settings ) = @_;
     $settings->tool( 'my_tool' );
 }

=cut

sub _settings_config {
    my ( $self, $settings ) = @_;
    $settings->tool( 'my_tool' );
    die "Overide _settings_config() manually.";
}

=head2 _settings_tool_params()

parameters passed to $self->init_tool()
Example:

 sub _settings_tool_params {
     return ( cols => 2 );
 }

=cut

sub _settings_tool_params {
    return ();
}

=pod

=head2 _settings_container_box()

returns the box in which the settings go to
Example:

 sub _settings_container_box {
     my ( $self ) = @_;
     return $self->tool->Container->box_at( 1, 0 );
 }

=cut

sub _settings_container_box {
    my ( $self ) = @_;
    return $self->tool->Container->box_at( 0, 0 );
}

=pod

=head2 _post_init_common_settings()

This method is meant to be overridden. It is run just after I<init_fields()>.

Override this if you want to populate some field dropdowns or otherwise modify
I<tool()> or I<gtool()>.

=cut

sub _post_init_common_settings {
    my ( $self )  = @_;
}

=pod

=head2 _pre_generate_common_settings()

This method is meant to be overridden. It is run just after I<init_fields()>.

Override this if you want to populate some field dropdowns or otherwise modify
I<tool()> or I<gtool()>.

=cut

sub _pre_generate_common_settings {
    my ( $self )  = @_;
}

=pod

=head1 PRIVATE ACTION METHODS

=head2 _get_settings()

Returns the L<Dicole::Settings> object. The object has group/user attribute
set by examining the action parameter I<target_type>. If it reads I<group>,
the group attribute is set. Otherwise the user attribute is set.

Then it calls I<_settings_config()> to set rest of the class attributes.

=cut

sub _get_settings {
    my ( $self ) = @_;
    my $settings = Dicole::Settings->new( action => $self );
    if ( $self->param('target_type') eq 'group' ) {
        $settings->group( 1 );
    }
    else {
        $settings->user( 1 );
    }
    $self->_settings_config( $settings );
    return $settings;
}

=pod

=head2 _check_ip_addresses( STRING )

Used with IP address checking for publicly available resources (for example, feeds).

Accepts a string of IP addresses separated with line breaks. Goes through the IP addresses
and compares the remote host IP address with the IP address with a simple regular expression.
If IP address is found, returns true. If none of the addresses match, returns false.

If string is empty, returns true.

Example content of the string:

 10.10.
 172.164.21.2

Notice that you may allow a complete subnet.

Note: this method is in this class because usually limiting access with
IP addresses are defined through the settings functionality.

If I<X-Forwarded-For> (set by a Squid or similar proxy inbetween) exists and
server configuration key I<trusted_proxy> under section I<dicole> is true,
trusts the proxy and uses the given IP address. This is useful if you are using
a reverse proxy where the remote host IP is masked by your trusted reverse
proxy. This ensures that the IP addresses are checked against the correct remote
host IP address.

=cut

# FIXME: Create as an Generictool field and make appropriate field validity checks?

sub _check_ip_addresses {
    my ( $self, $addresses ) = @_;
    return 1 unless $addresses;
    my $host = CTX->request->remote_host;
    if ( CTX->request->can('forwarded_for') && CTX->request->forwarded_for ) {
        # There might be serveral IPs in the header. Trust only the
        # last one (nearest, given by trusted proxy)
        if ( CTX->server_config->{dicole}{trusted_proxy} ) {
            $host = ( split /,\s+/, CTX->request->forwarded_for )[-1];
        }
    }
    my $sn = Net::Subnets->new;
    foreach my $address ( split /((\r?\n)|\s+)/, $addresses ) {
        next unless $address =~ /^\d+\.\d+\.\d+\.\d+(\/\d+)?$/;
        if ( $address =~ /\/\d+/ ) {
            $sn->subnets( [ $address ] );
            return 1 if $sn->check( \$host );
        }
        return 1 if $host eq $address;
    }
    return undef;
}

=pod

=head1 SEE ALSO

L<Dicole::Settings>

=head1 AUTHOR

Teemu Arina E<lt>teemu@ionstream.fiE<gt>

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
