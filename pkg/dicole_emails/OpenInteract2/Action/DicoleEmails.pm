package OpenInteract2::Action::DicoleEmails;

use strict;
use warnings;

use base qw( OpenInteract2::Action::DicoleEmailsCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use JSON                     qw( decode_json );
use Dicole::Utils::MailGateway;

sub dispatch {
    my ($self) = @_;

    my $address = Dicole::Utils::MailGateway->get_param('recipient');
    my ( $local ) = split( /@/, $address );

    if ( $local =~ /^\w+$/ ) {
        my $action = eval { CTX->lookup_action('dicole_email_handler_' . $local ) };
        return $action->e if $action;
    }

    my @params = split( /-/, $local );
    my $front  = lc( shift @params );
    my $hash   = lc( pop @params );

    if ( $hash && $self->_dispatch( $front ) && ( $hash eq $self->_get_user_hash( $front, [ @params ] ) || $hash eq $self->_get_hash( [$front, @params] ) || $hash eq $self->_get_hash( [$front, @params], 'legacy' ) ) ) {
        my $result = eval { CTX->lookup_action( $self->_dispatch($front) )->execute( { encoded_params => \@params }) };
        return $@ ? { error => "$@" } : $result;
    }
    elsif ( my @dispatches = $self->_fetch_shortened_params( $local ) ) {
        my $dispatch = $dispatches[0];
        my $data = decode_json($dispatch->{data});
        my $action = $data->{action};
        my $params = $data->{params};
        my $result = eval { CTX->lookup_action( $action )->execute( { encoded_params => $params } ) };
        return $@ ? { error => "$@" } : $result;
    }
    else {
        return { error => 'spam' };
    }
}

sub _debug {
    my ($self) = @_;

    my $req = CTX->request;

    my $address = $req->param('address');
    my $subject = $req->param('subject');
    my $content_text = $req->param('content_text');
    my $content_html = $req->param('content_html');
    my @attachments = $req->upload;

    get_logger(LOG_APP)->error("POST [ address = $address, subject = $subject, content_text = $content_text, content_html = $content_html, attachments = [ " . (join ", ",  map { "(file: " . $_->filename . ", size: " . $_->size . " bytes)" } @attachments) . " ]]");

    for my $attachment (@attachments) {
        my $file = $attachment->save_file;
        get_logger(LOG_APP)->error("Saved attachment to $file");
        get_logger(LOG_APP)->error("-s $file = " . -s $file);
    }

    return { success => "foo" };
}

1;
