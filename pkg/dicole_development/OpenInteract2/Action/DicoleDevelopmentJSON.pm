package OpenInteract2::Action::DicoleDevelopmentJSON;

use strict;
use base qw( OpenInteract2::Action::DicoleDevelopmentCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::Utils::Mail;

my $srcdir = '/usr/local/src/dicole-crmjournal';

sub bundled_templates {
    my ( $self ) = @_;

    my $bundle_string = CTX->request->param('bundle') || '[]';
    my $bundle = Dicole::Utils::JSON->decode( $bundle_string );
    my $htmldir = CTX->lookup_directory( 'html' );
    my $result = {};

    for my $template ( @$bundle ) {
        $template =~ s/\.\.//g;
        local $/;
        open(FILE, $htmldir . $template) or next;
        my $document = <FILE>; 
        close (FILE);  
        $result->{$template} = $document;
    }

    return { result => $result };
}

sub preview_tests {
    my ( $self ) = @_;

    my $pkgdir = "$srcdir/pkg/" . ( $self->param('pkgdir') || 'dicole_meetings' );

    my $base = CTX->request->param('base');
    $base =~ s/[^\w]//g;
    my $lang = CTX->request->param('lang');
    $lang =~ s/[^\w]//g;

    my $testfile = "$pkgdir/src/mail/$base-$lang.test";
    my $mailfile = "$pkgdir/src/mail/$base-$lang.mail";

    my $test = `cat $testfile`;
    my $content = `cat $mailfile`;

    if ( CTX->request->param('type') eq 'mail' ) {
        $content = CTX->request->param('content');
    }
    else {
        $test = CTX->request->param('content');
    }

    # Indented because copied from mail_to_po_templates script :P
    my $template = $self->_prepare_template_params( $pkgdir, $content, $lang );
    for my $target ( keys %$template ) {
        $template->{ $target } =~ s/\\n/\n/g;
        $template->{ $target } = $test . $template->{ $target };
    }

    my $params = { tests => [] };

    my @cases = $test =~ /IF\s+test_case\s*==\s*['"]([^'"]+)['"]/g;
    for my $case ( @cases ) {
        my $text_subject = Dicole::Utils::Template->process( $template->{subject}, { "in_subject" => 1, test_case => $case } );
        $text_subject =~ s/\s*$//m;
        $text_subject =~ s/^\s//m;
        my $subject = Dicole::Utils::HTML->text_to_html( $text_subject );
        for my $target ( keys %$template ) {
            next if $target eq 'subject';
            my $test = { id => "$case-$target", subject => $subject };
            $test->{id} =~ s/ /_/g;
            my $result = Dicole::Utils::Template->process( $template->{ $target }, { "in_$target" => 1, test_case => $case } );
            if ( $target eq 'text' ) {
                $result = Dicole::Utils::HTML->text_to_html( $result );
            }
            $test->{html} = $result;

            push @{ $params->{tests} }, $test;
        }
    }
    
    return { result => {
        html => $self->generate_content( $params, { name => 'dicole_development::part_preview_tests' } ),
    } };
}

1;

