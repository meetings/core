package OpenInteract2::Action::DicoleDevelopment;

use strict;
use base qw( OpenInteract2::Action::DicoleDevelopmentCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::Utils::Mail;


use Data::Dump qw/dump/;

# This would break OI2 by importing "param" function
# use CGI qw/:standard/;

use CGI;

my $srcdir = '/usr/local/src/dicole-crmjournal';
my $pkgdir = "$srcdir/pkg/dicole_meetings";

sub create_file {
    my ( $self ) = @_;

    $self->_ensure_development;
    my $pkgdir = "$srcdir/pkg/" . ( $self->param('pkgdir') || 'dicole_meetings' );

    my $name = CTX->request->param('name');
    my $type = CTX->request->param('type');

    $name =~ s/[^\w]//;

    my $back_url = $self->derive_url( task => 'list_mail_files', params => { email => CTX->request->param('email') } );

    if ( $type eq 'part' ) {
        system "touch", $pkgdir . '/src/mail/' . $name . '-en.part';
        return $name . " part created <a href=\"$back_url\">Back</a>";
    }
    elsif ( $type eq 'mail' ) {
        system "touch", $pkgdir . '/src/mail/' . $name . '-en.mail';
        system "touch", $pkgdir . '/src/mail/' . $name . '-en.test';
        return $name . " mail and tests created <a href=\"$back_url\">Back</a>";
    }
    else {
        return "error with params name = $name and type = $type :/  <a href=\"$back_url\">Back</a>";
    }
}

sub delete_file {
    my ( $self ) = @_;

    $self->_ensure_development;
    my $pkgdir = "$srcdir/pkg/" . ( $self->param('pkgdir') || 'dicole_meetings' );

    my $name = CTX->request->param('name');
    my $type = CTX->request->param('type');

    $name =~ s/[^\w]//;

    my $back_url = $self->derive_url( task => 'list_mail_files', params => { email => CTX->request->param('email') } );

    if ( $type eq 'part' ) {
        system "rm", $pkgdir . '/src/mail/' . $name . '-en.part';
        return $name . " part deleted <a href=\"$back_url\">Back</a>";
    }
    elsif ( $type eq 'mail' ) {
        system "rm", $pkgdir . '/src/mail/' . $name . '-en.mail';
        system "rm", $pkgdir . '/src/mail/' . $name . '-en.test';
        return $name . " mail and tests deleted <a href=\"$back_url\">Back</a>";
    }
    else {
        return "error with params name = $name and type = $type :/  <a href=\"$back_url\">Back</a>";
    }
}

sub list_mail_files {
    my ( $self ) = @_;

    $self->_ensure_development;
    my $pkgdir = "$srcdir/pkg/" . ( $self->param('pkgdir') || 'dicole_meetings' );

    my $limit_to_lang = CTX->request->param('lang');
    my $email = CTX->request->param('email');
    $email = 'emailtesters@dicole.com' unless $email =~ /\@/;

    my $mailfiles = `ls $pkgdir/src/mail/*.mail`;
    my $partfiles = `ls $pkgdir/src/mail/*.part`;

    my $params = {
        email => $email,
    };

    for my $file ( split /\n/, $mailfiles ) {
        my ( $base, $lang ) = $file =~ /.*\/(.*)\-(\w+)\.mail/;
        next unless $base;
        next if $limit_to_lang && $limit_to_lang ne $lang;

        my $info = {
            name => $base,
            lang => $lang,
            edit_mail_url => $self->derive_url( task => 'edit_mail_file', params => { base => $base, type => 'mail', lang => $lang, email => $email } ),

            edit_test_url => $self->derive_url( task => 'edit_mail_file', params => { base => $base, type => 'test', lang => $lang, email => $email } ),
        };

        my $testfile = "$pkgdir/src/mail/$base-$lang.test";
        if (  -f $testfile ) {
            my $testcontent = `cat $testfile`;
            my @cases = $testcontent =~ /IF\s+test_case\s*==\s*['"]([^'"]+)['"]/g;
            for my $case ( @cases ) {
                $info->{tests} ||= [];
                my $test = {
                    name => $case,
                    send_test_url => $self->derive_url( task => 'send_test', params => { base => $base, lang => $lang, test_case => $case, email => $email } ),
                };
                push @{ $info->{tests} }, $test;
            }
        }

        my $docfile = "$pkgdir/src/mail/$base.doc";
        if (  -f $docfile ) {
            my $doccontent = `cat $docfile` || '';
            my ( $comment ) = split "\n", $doccontent;
            $info->{comment} = $comment;
        }            

        push @{ $params->{mails} }, $info;
    }

    for my $file ( split /\n/, $partfiles ) {
        my ( $base, $lang ) = $file =~ /.*\/(.*)\-(\w+)\.part/;
        next unless $base;
        next if $limit_to_lang && $limit_to_lang ne $lang;

        push @{ $params->{parts} }, {
            name => $base,
            lang => $lang,
            edit_part_url => $self->derive_url( task => 'edit_mail_file', params => { base => $base, type => 'part', lang => $lang, email => $email } ),
        };
    }

    $params->{create_url} = $self->derive_url( task => 'create_file' );
    $params->{delete_url} = $self->derive_url( task => 'delete_file');

    return $self->generate_content( $params, { name => 'dicole_development::main_list_mail_files' } );
}

sub edit_mail_file {
    my ( $self ) = @_;

    $self->_ensure_development;
    my $pkgdir = "$srcdir/pkg/" . ( $self->param('pkgdir') || 'dicole_meetings' );

    my $base = CTX->request->param('base');
    $base =~ s/[^\w]//g;
    my $type = CTX->request->param('type');
    $type =~ s/[^\w]//g;
    my $lang = CTX->request->param('lang');
    $lang =~ s/[^\w]//g;
    my $file = "$pkgdir/src/mail/$base-$lang.$type";
    my $doc_file = "$pkgdir/src/mail/$base.doc";

    if ( CTX->request->param('save') ) {
        my $content = CTX->request->param('content');
        $content =~ s/\r//g;

        open F, ">$file";
        print F $content;
        close F;

        my $design = CTX->request->param('design');

        open F, ">$doc_file";
        print F $design;
        close F;
        
        chdir $srcdir;
        system "$srcdir/bin/mail_to_po_templates", $self->param('pkgdir') || 'dicole_meetings', $base;
    }

    my $content = `cat $file`;
    my $design = `cat $doc_file`;

    my $params = {
        base => $base,
        type => $type,
        lang => $lang,
        email => CTX->request->param('email'),
        content => $content,
        design => $design,
        back_url => $self->derive_url( task => 'list_mail_files', params => { email => CTX->request->param('email') } ),
        preview_url => $self->derive_url( action => 'development_json', task => 'preview_tests' ),
    };

    CTX->controller->add_content_param( 'page_title', "$base ( $lang ) [ $type ]" );
    CTX->controller->init_common_variables(
        disable_navigation => 1,
        disable_default_requires => 1,
        head_widgets => [
            Dicole::Widget::Javascript->new(
                code => 'dojo.require("dicole.development");',
            ),
        ],
    ); 

    return $self->generate_content( $params, { name => 'dicole_development::main_edit_mail_file' } );
}

sub send_test {
    my ( $self ) = @_;
  
    $self->_ensure_development;
    my $pkgdir = "$srcdir/pkg/" . ( $self->param('pkgdir') || 'dicole_meetings' );
  
    my $email = CTX->request->param('email');
    $email = 'emailtesters@dicole.com' unless $email =~ /\@/;

    my $base = CTX->request->param('base');
    $base =~ s/[^\w]//g;
    my $lang = CTX->request->param('lang');
    $lang =~ s/[^\w]//g;
    my $test_case = CTX->request->param('test_case');

    my $testfile = "$pkgdir/src/mail/$base-$lang.test";
    my $mailfile = "$pkgdir/src/mail/$base-$lang.mail";

    my $test = `cat $testfile`;
    my $content = `cat $mailfile`;

    # Indented because copied from mail_to_po_templates script :P
    my $template = $self->_prepare_template_params( $pkgdir, $content, $lang );

    my %mail_params = ();
    for my $target ( keys %$template ) {
        $template->{ $target } =~ s/\\n/\n/g;
        $template->{ $target } = $test . $template->{ $target };
        $mail_params{ $target } = Dicole::Utils::Template->process( $template->{ $target }, { "in_$target" => 1, test_case => $test_case } );
    }

    Dicole::Utils::Mail->send(
        to => $email,
        lang => $lang,
        %mail_params,
    );

    my $back_url = $self->derive_url( task => 'list_mail_files', params => { email => $email } );

    return "<p>$base sent to $email! <a href=\"$back_url\">Back</a></p>";
}

sub _comment_stripping {
    my ($self) = @_;

    my $comments = CTX->lookup_object('dicole_comment')->fetch_group({ });

    my @comments = map { $_->content } reverse sort { $a->date <=> $b->date } @$comments;

    my $content = join '',
    '<!doctype html>',
    CGI::head(
        CGI::script({
                type => "text/javascript",
                src  => "jquery-1.7.min.js"
        }, ""),

        CGI::script({ type => "text/javascript"}, q|
            $(document).ready(function() {
                $('#toggle').click(function() {
                    $('.noescape').add('.escaped').toggle();
                });
            });
        |),

        CGI::style(q|
            html {
                font-family: sans-serif;
            }

            table {
                border-spacing: 0;
            }

            hr {
                margin-top: 10px;
                margin-bottom: 10px;
                height: 1px;
                background-color: #ccc;
                border: none;
            }

            th {
                background: #eee;
            }

            td {
                vertical-align: top;
            }

            td:first-child {
                padding-right: 20px;
            }

            pre {
                width: 40em;
                white-space: pre-wrap;       /* css-3 */
                white-space: -moz-pre-wrap;  /* Mozilla, since 1999 */
                white-space: -pre-wrap;      /* Opera 4-6 */
                white-space: -o-pre-wrap;    /* Opera 7 */
                word-wrap: break-word;       /* Internet Explorer 5.5+ */
            }

            #toggle {
                cursor: pointer;
            }
        |)
    ),

    CGI::div({ id => "toggle" }, CGI::p("Switch between HTML and rendered display")),

    CGI::table(
        CGI::thead(
            Tr(
                th('Original'),
                th('Result'),
            ),
        ),
        CGI::tbody(
            grep defined, map { _strip_comment_content($_) } @comments
        )
    );

    return $content;
}

sub _strip_comment_content {
    my ($content) = @_;

    my $original = $content;

    my $result = Dicole::Utils::Mail->strip_quotes_and_sigs_from_br_html( $original );
    my $i = 1;

    if ($result ne $original) {
        CGI::Tr(CGI::td({colspan => 2}, "Count: " . $i++)),
        CGI::Tr(
            CGI::td(
                CGI::pre({ class => "escaped" },
                    CGI::escapeHTML($original)
                ),
                CGI::pre({ class => "noescape", style => "display: none;" },
                    $original
                )
            ),

            CGI::td(
                CGI::pre({ class => "escaped" },
                    CGI::escapeHTML($result)
                ),
                CGI::pre({ class => "noescape", style => "display: none;" },
                    $result
                )
            )
        ),
        CGI::Tr(CGI::td({colspan => 2}, CGI::hr()))
    } else {
        undef
    }
}



1;

