package Dicole::Widget::Javascript;

use strict;
use base qw( Dicole::Widget );
use OpenInteract2::Context qw( CTX );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

sub DEFAULT_TEMPLATE { 'widget_javascript' };

sub ACCESSORS { (
    defer => Dicole::Widget::ACCESSOR_RAW,
    src => Dicole::Widget::ACCESSOR_RAW,
    code => Dicole::Widget::ACCESSOR_RAW,
) };

sub template_params {
    my ($self, $params) = @_;

    $params = $self->SUPER::template_params( $params );

    my $src = $params->{src};
    my $file_version = CTX->server_config->{dicole}{static_file_version};
    if ( $src && $file_version && ! ( $src =~ /\&v\=|\?v\=/ || $src =~ /^http/ ) ) {
        $params->{src} = $src . ( ( $src =~ /\?/ ) ? '&v=' . $file_version : '?v=' . $file_version );
    }

    return $params;
}

__PACKAGE__->mk_widget_accessors;

1;

__END__

=head1 NAME

Dicole::Widget::Javascript - A class that defines Dicole text widgets

=head1 SEE ALSO

L<Dicole::Widget|Dicole::Widget>

=head1 AUTHOR

Antti V��otam�i E<lt>antti@ionstream.fi<gt>

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
