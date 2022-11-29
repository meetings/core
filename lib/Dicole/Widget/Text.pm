package Dicole::Widget::Text;

use strict;
use base qw( Dicole::Widget );
use OpenInteract2::Context qw( CTX );
use Log::Log4perl qw( get_logger );
use OpenInteract2::Constants qw( :log );

use Data::Leaf::Walker;
use Data::Dumper qw(Dumper);
use Clone qw(clone);
use Data::Structure::Util qw(unbless);
use Encode;


our $VERSION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);

sub DEFAULT_TEMPLATE { 'widget_text' };

sub ACCESSORS { (
    text => Dicole::Widget::ACCESSOR_RAW,
    filter => Dicole::Widget::ACCESSOR_RAW,
    preformatted => Dicole::Widget::ACCESSOR_RAW,
    selected => Dicole::Widget::ACCESSOR_RAW,
    class => Dicole::Widget::ACCESSOR_RAW,
) };

__PACKAGE__->mk_widget_accessors;

sub _init {
    my ($self, %args) = @_;

    $args{filter} = 1 unless defined $args{filter};

    $self->SUPER::_init( %args );
}

1;

__END__

=head1 NAME

Dicole::Widget::Text - A class that defines Dicole text widgets

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

