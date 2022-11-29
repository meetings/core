package OpenInteract2::Action::DicoleGroupAwareness;

use strict;

use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::MessageHandler   qw( :message );

use Dicole::Widget::Listing;
use Dicole::Widget::Hyperlink;
use Dicole::Widget::Text;
use Dicole::Widget::Horizontal;
use Dicole::Generictool::Data;
use Dicole::Widget::Image;

$OpenInteract2::Action::DicoleGroupAwareness::VERSION = sprintf("%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/);

sub send {
    my ( $self ) = @_;
    
    my $send_pressed = CTX->request->param('send');
    my $self_preview_pressed = CTX->request->param('self_preview');
    
    $self->init_tool( { tool_args => { no_tool_tabs => 1 } } );
    
    if ( $send_pressed || $self_preview_pressed ) {
        if (
            ! CTX->request->param('sender_name') ||
            ! CTX->request->param('sender_address') ||
            ! CTX->request->param('title') ||
            ! CTX->request->param('content') ||
            CTX->request->param('content') eq '<p></p>'
        ) {
            $self->tool->add_message(
                MESSAGE_ERROR, $self->_msg('You must fill all fields.')
            );
        }
        else {
            my $users = $self_preview_pressed ? [ CTX->request->auth_user ]
                : $self->param('target_group')->user || [];
            
            my @failures = ();
            for my $user ( @$users ) {
                my $msg = MIME::Lite->new(
                    OpenInteract2::Util->_build_header_info( {
                        from => CTX->request->param('sender_name') . '<' .
                    CTX->request->param('sender_address') . '>',
                        to => $user->email,
                        subject => CTX->request->param('title'),
                    } ),
                    Type =>'multipart/alternative'
                );
                $msg->attr( 'content-type.charset' => 'utf-8' );

                $msg->attach(
                    Type => 'text/html',
                    Data => CTX->request->param('content'),
                );
            
                $msg->send || push @failures, $user->email . ': ' . $!;
            }
            if ( @failures ) {
                $self->tool->add_message(
                    MESSAGE_WARNING, $self->_msg( "Some messages could not be sent: [_1]", join( ', ',  @failures ) )
                );
            }
            else {
                $self->tool->add_message(
                    MESSAGE_SUCCESS, $self_preview_pressed ? 
                    $self->_msg( "Message sent to you succesfully." )
                    : $self->_msg( "Messages were sent succesfully." )
                );
            }
        }
    }
    
    $self->init_tool( { tool_args => { no_tool_tabs => 1 } } );
    $self->tool->add_tinymce_widgets;
    
    my $submitted = $send_pressed || $self_preview_pressed;

    my $fields = Dicole::Widget::Vertical->new( contents => [
        Dicole::Widget::Text->new( text => $self->_msg('Sender name'), class => 'definitionHeader' ),
        Dicole::Widget::FormControl::TextField->new(
            name => 'sender_name',
            id => 'sender_name',
            value => $submitted ? CTX->request->param('sender_name') || '' :
                CTX->request->auth_user->first_name . ' ' . CTX->request->auth_user->last_name,
        ),
        Dicole::Widget::Text->new( text => $self->_msg('Sender address'), class => 'definitionHeader' ),
        Dicole::Widget::FormControl::TextField->new(
            name => 'sender_address',
            id => 'sender_address',
            value => $submitted ? CTX->request->param('sender_address') || '' :
                CTX->request->auth_user->email,
        ),
        Dicole::Widget::Text->new( text => $self->_msg('Title'), class => 'definitionHeader' ),
        Dicole::Widget::FormControl::TextField->new(
            name => 'title',
            id => 'mail_title',
            value => $submitted ? CTX->request->param('title') || '' : '',
        ),
        Dicole::Widget::Text->new( text => $self->_msg('Content'), class => 'definitionHeader' ),
        Dicole::Widget::FormControl::TextArea->new(
            name => 'content',
            id => 'mail_content',
            value => $submitted ? CTX->request->param('content') || '<p></p>' : '<p></p>',
            rows => 15,
            html_editor => 1,
        ),
        Dicole::Widget::Horizontal->new( contents => [
            Dicole::Widget::FormControl::SubmitButton->new(
                name => 'send',
                value => '1',
                text => $self->_msg('Send mail'),
            ),
            Dicole::Widget::FormControl::SubmitButton->new(
                name => 'self_preview',
                value => '1',
                text => $self->_msg('Send test mail to self'),
            ),
        ] ),
    ] );

	$self->tool->Container->box_at( 0, 0 )->name( $self->_msg('Mail information') );
	$self->tool->Container->box_at( 0, 0 )->add_content(
        [ $fields ]
	);

    return $self->generate_tool_content;
}


1;

