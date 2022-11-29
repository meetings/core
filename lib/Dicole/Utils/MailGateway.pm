package Dicole::Utils::MailGateway;

use 5.010;
use strict;
use warnings;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

sub get_param {
    my ($self, $name) = @_;

    return CTX->request->param($name)
        // CTX->request->param($self->_mailgun_to_mailpost_param_name($name));
}

sub _mailgun_to_mailpost_param_name {
    my ($self, $name) = @_;

    if (my ($number) = $name =~ /^attachment(\d)$/) {
        return "attachment-$number";
    }

    return {
        To              => 'to',
        Cc              => 'cc',
        recipient       => 'address',
        'body-plain'    => 'content_text',
        'body-html'     => 'content_html',
        'body-calendar' => 'calendar',
        timestamp       => 'sent',
        'Reply-To'      => 'reply',
        from            => 'from',
        subject         => 'subject',        
    }->{$name} || $name;
}

1;
