package OpenInteract2::Action::DicoleAdminAwareness;

use strict;

use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::Widget::Listing;
use Dicole::Widget::Hyperlink;
use Dicole::Widget::Text;
use Dicole::Widget::Horizontal;
use Dicole::Generictool::Data;
use Dicole::Widget::Image;

$OpenInteract2::Action::DicoleAwareness::VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);


sub _online_users_logged_actions {
    my ( $self ) = @_;

    my $time = time;
    $time -= CTX->server_config->{dicole}{admin_online_timeout} || 
        CTX->server_config->{dicole}{online_timeout} || 600;

    my $class = CTX->lookup_object('logged_action');

    my $objs = $class->fetch_group( {
            where  => 'time > ?',
            value  => [ $time ],
            order  => 'time DESC',
    }) || [];

    my %check = ();
    my @return = ();

    for my $o ( @$objs ) {
        next if $check{ $o->user_id };
        $check{ $o->user_id }++;
        push @return, $o if ! lc $o->action =~ /logout/;
    }

    return \@return;
}


sub list {
    my ( $self ) = @_;

    $self->init_tool;

    my $actions = $self->_online_users_logged_actions || [];

    my $list = Dicole::Widget::Listing->new(
        use_keys => 0,
    );

    my $usercount = 0;

    for my $action ( @$actions ) {

        next if ! $action->user_id;

        # OPTIMIZE: fetch beforehand in one query
        my $user = eval {
            CTX->lookup_object('user')->fetch($action->user_id, {
                skip_security => 1,
            });
        };

        next if ! $user;

        $list->new_row;
        
        $list->add_cell(
            content =>  $user->first_name . ' ' . $user->last_name,
        );

        $list->add_cell( content => $action->url );
        
        my $secs = time - $action->time;

        $list->add_cell( content => $self->_msg( '[_1] seconds ago', $secs ) );
        
        $usercount++;
    }

    my $content = ($usercount) ?
        $list :
        Dicole::Widget::Text->new(
            text => $self->_msg( 'No online users.' ),
        );

	$self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Online users') );
	$self->tool->Container->box_at( 0, 0 )->add_content(
        [ $content ]
	);

    return $self->generate_tool_content;
}


1;

