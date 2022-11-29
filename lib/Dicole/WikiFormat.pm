package Dicole::WikiFormat;

use base qw( Text::WikiFormat );

use strict;
no warnings; # to maybe get rid of subroutine overwrite warning?
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use URI::Escape;

sub new {
    my ( $class, %p ) = @_;

    my $link = \&grouppages_make_html_link;
    $link = \&grouppages_make_export_html_link if $p{exporting};

    my $tags = {
        link => $link,
        indent => qr/^(?:\t+|\s{2,})/,
        paragraph => [ '<p>', "</p>\n", '', "<br />\n", 1 ],
        extended_link_delimiters => [ '[[', ']]' ],
        strong_tag => qr/''(.+?)''/,
        emphasized_tag => qr/(?<!:)\/\/(.+?)\/\//,
        strike => sub { "<strike>$_[0]</strike>" },
        strike_tag => qr/\-\-(.+?)\-\-/,
        underlined => sub { "<u>$_[0]</u>" },
        underlined_tag => qr/\_\_(.+?)\_\_/,
        acronym => sub { qq|<acronym title="$_[1]">$_[0]</acronym>| },
        acronym_tag => qr/(\w+)\((.+?)\)/,
        superscript => sub { "<sup>$_[0]</sup>" },
        superscript_tag => qr/\^(.+?)\^/,
        subscript => sub { "<sub>$_[0]</sub>" },
        subscript_tag => qr/\~(.+?)\~/,

        r_symb => qr/\(R\)/i,
        tm_symb => qr/\(TM\)/i,
        c_symb => qr/\(C\)/i,
        onefourth_symb => qr{\b1/4\b},
        onehalf_symb => qr{\b1/2\b},
        threefourths_symb => qr{\b3/4\b},
        emdash_symb => qr{\s--\s},
        endash_symb => qr{\s-\s},
    };
    my $opts = {
        prefix => $p{prefix},
        create_prefix => $p{create_prefix},
        extended => 1,
        implicit_links => 0,
        absolute_links => 1,
        linked_pages => {},
    };

    my $newtags = $p{tags};
    my $newopts = $p{opts};

    merge_hash( $newtags, $tags )
        if defined $newtags and UNIVERSAL::isa( $newtags, 'HASH' );

    merge_hash( $newopts, $opts )
        if defined $newopts and UNIVERSAL::isa( $newopts, 'HASH' );

    my $instance = {
        opts => $opts,
        tags => $tags
    };

    return bless $instance, $class;
}

sub Text::WikiFormat::format_line {
    my ( $text, $tags, $opts ) = @_;
    $opts ||= {};

    $text =~ s/$tags->{underlined_tag}/$tags->{underlined}->($1, $opts)/eg;
    $text =~ s/$tags->{strike_tag}/$tags->{strike}->($1, $opts)/eg;
    $text =~ s/$tags->{superscript_tag}/$tags->{superscript}->($1, $opts)/eg;
    $text =~ s/$tags->{subscript_tag}/$tags->{subscript}->($1, $opts)/eg;
    $text =~ s/$tags->{strong_tag}/$tags->{strong}->($1, $opts)/eg;
    $text =~ s/$tags->{emphasized_tag}/$tags->{emphasized}->($1, $opts)/eg;

    $text =~ s/$tags->{r_symb}/\&\#174\;/g;
    $text =~ s/$tags->{tm_symb}/\&\#8482\;/g;
    $text =~ s/$tags->{c_symb}/\&\#169\;/g;
    $text =~ s/$tags->{onefourth_symb}/\&\#188\;/g;
    $text =~ s/$tags->{onehalf_symb}/\&\#189\;/g;
    $text =~ s/$tags->{threefourths_symb}/\&\#190\;/g;
    $text =~ s/$tags->{emdash_symb}/ \&\#8212\; /g;
    $text =~ s/$tags->{endash_symb}/ \&\#8211\; /g;

    $text =~ s/$tags->{acronym_tag}/$tags->{acronym}->($1, $2, $opts)/eg;

    $text = Text::WikiFormat::find_extended_links( $text, $tags, $opts )
        if $opts->{extended};

    $text =~ s|(?<!["/>=])\b([A-Za-z]+(?:[A-Z]\w+)+)|
              $tags->{link}->($1, $opts)|egx
            if !defined $opts->{implicit_links} or $opts->{implicit_links};

    return $text;
}

sub execute {
    my ( $self, $text, $newtags, $newopts ) = @_;

    my %tags = %{ $self->{tags} };
    my %opts = %{ $self->{opts} };

    merge_hash( $newtags, \%tags )
        if defined $newtags and UNIVERSAL::isa( $newtags, 'HASH' );

    merge_hash( $newopts, \%opts )
        if defined $newopts and UNIVERSAL::isa( $newopts, 'HASH' );

    my $html = Text::WikiFormat::format( $text, $self->{tags}, $self->{opts} );

    return ( $html, $self->{opts}{linked_pages} );
}

sub grouppages_make_html_link {
    my ( $link, $opts ) = @_;
    $opts ||= {};
    ( $link, my $title ) = Text::WikiFormat::find_link_title( $link, $opts );
    ( $link, my $is_relative ) = Text::WikiFormat::escape_link( $link, $opts );

    my $clean_link = URI::Escape::uri_unescape( $link );
    if ( $clean_link =~ s/^(image|shockwave|applet|flash|sound|pdf|wmp|real|iframe|qt):(.*)/$2/ ) {
        my $type = $1;
        # Check if has params, e.g. image:300x200:http://...
        my $width_height = undef;
        if ( $clean_link =~ s/^(\d+\%?)x(\d+\%?):(.*)/$3/ ) {
            $width_height = qq|width="$1" height="$2"|;
        }
        my $params = {};
        # Check if has params, e.g. applet:300x200:param1=1,param2=2:http://...
        if ( $clean_link =~ s{^(\w+=.+?):([^/].*)}{$2} ) {
            foreach my $param ( split /,/, $1 ) {
                my ( $key, $value ) = split /=/, $param;
                $params->{$key} = $value;
            }
        }
        return make_special_link( $type, $clean_link, $width_height, $title, $params );
    }
    elsif ( $is_relative || $clean_link !~ m{^(\w+)://} ) {
        my $page_exists = undef;
        if ( $clean_link !~ m{^/} ) {
            $clean_link =~ s/_/ /g;
            $clean_link =~ s{/}{|}g;
            $opts->{linked_pages}{$clean_link}++;
            $page_exists = CTX->controller->initial_action->_check_if_page_exists( $clean_link );

            # Convert spaces to underscores
            $link =~ s/\%20/_/g;
        }
        else {
            return qq|<a class="internalLinks" href="$clean_link">$title</a>|;
        }

        if ( $page_exists ) {
            my $prefix = defined $opts->{prefix} ?
                $opts->{prefix} : '';
            return qq|<a class="wikiLinks" href="$prefix$link">$title</a>|;
        }
        else {
            my $prefix = defined $opts->{create_prefix} ?
                $opts->{create_prefix} : '';
            return qq|<a class="redLinks" href="$prefix$link">$title</a>|;
        }
    }
    else {
        return qq|<a class="externalLinks" target="_blank" href="$link">$title</a>|;
    }
}

sub grouppages_make_export_html_link {
    my ( $link, $opts ) = @_;
    $opts ||= {};
    ( $link, my $title ) = Text::WikiFormat::find_link_title( $link, $opts );
    ( $link, my $is_relative ) = Text::WikiFormat::escape_link( $link, $opts );

    my $clean_link = URI::Escape::uri_unescape( $link );
    my $title_link = $clean_link;
    $title_link =~ s/"/&quot;/g;

    if ( $clean_link =~ s/^(image|shockwave|applet|flash|sound|pdf|wmp|real|iframe|qt):(.*)/$2/ ) {
        my $type = $1;
        # Check if has params, e.g. image:300x200:http://...
        my $width_height = undef;
        if ( $clean_link =~ s/^(\d+\%?)x(\d+\%?):(.*)/$3/ ) {
            $width_height = qq|width="$1" height="$2"|;
        }
        my $params = {};
        # Check if has params, e.g. applet:300x200:param1=1,param2=2:http://...
        if ( $clean_link =~ s{^(\w+=.+?):([^/].*)}{$2} ) {
            foreach my $param ( split /,/, $1 ) {
                my ( $key, $value ) = split /=/, $param;
                $params->{$key} = $value;
            }
        }
        return make_special_link( $type, $clean_link, $width_height, $title, $params );
    }
    elsif ( $is_relative || $clean_link !~ m{^(\w+)://} ) {
        my $page_exists = undef;
        if ( $clean_link !~ m{^/} ) {
            $clean_link =~ s/_/ /g;
            $opts->{linked_pages}{$clean_link}++;

            $link =~ s/\%20/ /g;
        }
        else {
            return qq|<a href="$clean_link">$title</a>|;
        }

        return qq|<a class="wikiLink" href="#" title="$title_link">$title</a>|;
 
    }
    else {
        return qq|<a href="$link">$title</a>|;
    }
}

sub make_special_link {
    my ( $type, $link, $width_height, $title, $params ) = @_;
    if ( $type eq 'image' ) {
        $title = undef if $title =~ /^image:/;
		if ( $title =~ /^frame\|/ ) {
			$title =~ s/^frame\|//;
			return qq|<span class="wikiImageboxRight">|
				. qq|<img src="$link" $width_height alt="$title" title="$title" />|
				. qq|<span class="wikiImageCaption">$title</span>|
				. qq|</span>|;
		}
		else {
	        return qq|<img src="$link" $width_height alt="$title" title="$title" />|;
		}
    }
    elsif ( $type eq 'flash' ) {
        my $flash = qq|<object classid="clsid:D27CDB6E-AE6D-11cf-96B8-444553540000" |
            . qq|codebase="http://download.macromedia.com/pub/shockwave/cabs/flash/swflash.cab#version=6,0,40,0" $width_height>\n|
            . qq|<param name="movie" value="$link" />\n|
            . qq|<param name="quality" value="high" />\n|;
        foreach my $key ( keys %{ $params } ) {
            $flash .= qq|<param name="$key" value ="$params->{$key}">\n|;
        }
        $flash .= qq|<embed src="$link" |
            . qq|pluginspage="http://www.macromedia.com/go/getflashplayer" |
            . qq|quality="high" type="application/x-shockwave-flash" |
            . qq|$width_height></embed>\n</object>\n|;
        return $flash;
    }
    elsif ( $type eq 'sound' ) {
        return qq|<embed src="$link" volume="100" autostart="true" $width_height></embed>\n|;
    }
    elsif ( $type eq 'shockwave' ) {
        return qq|<object classid="clsid:166B1BCA-3F9C-11CF-8075-444553540000" codebase="http://download.macromedia.com/pub/shockwave/cabs/director/sw.cab#version=8,0,0,0" $width_height>\n|
            . qq|<param name="src" value="$link" />\n|
            . qq|<embed src="$link" pluginspage="http://www.macromedia.com/shockwave/download/" $width_height></embed>\n|
            . qq|</object>\n|;
    }
    elsif ( $type eq 'pdf' ) {
        return qq|<object classid="clsid:CA8A9780-280D-11CF-A24D-444553540000" $width_height>\n|
            . qq|<param name="src" value="$link" />\n|
            . qq|<embed src="$link" $width_height></embed>\n</object>\n|;
    }
    elsif ( $type eq 'wmp' ) {
        # Some default parameters for windows media player object
        unless ( keys %{ $params } > 0 ) {
            $params->{'animationatStart'} = 'true';
            $params->{'transparentatStart'} = 'true';
            $params->{'autoStart'} = 'true';
            $params->{'showControls'} = 'true';
        }
        my $wmp = qq|<object id="mediaPlayer" classid="CLSID:22d6f312-b0f6-11d0-94ab-0080c74c7e95" codebase="http://activex.microsoft.com/activex/controls/mplayer/en/nsmp2inf.cab#Version=5,1,52,701" standby="Loading Microsoft Windows Media Player components..." type="application/x-oleobject" $width_height>\n|
            . qq|<param name="fileName" value="$link" />\n|;
        foreach my $key ( keys %{ $params } ) {
            $wmp .= qq|<param name="$key" value ="$params->{$key}">\n|;
        }
        $wmp .= qq|<embed src="$link" $width_height></embed>\n</object>\n|;
        return $wmp;
    }
    elsif ( $type eq 'applet' ) {
        # Rip codebase and archive parameters and place them in the applet tag
        my $codebase_archive = undef;
        if ( $params->{codebase} ) {
            $codebase_archive = qq|codebase="$params->{codebase}"|;
            delete $params->{codebase};
        }
        if ( $params->{archive} ) {
            $codebase_archive .= qq| archive="$params->{archive}"|;
            delete $params->{archive};
        }
        my $applet = qq|<applet code="$link" $codebase_archive $width_height>\n|;
        foreach my $key ( keys %{ $params } ) {
            $applet .= qq|<param name="$key" value ="$params->{$key}">\n|;
        }
        $applet .= qq|</applet>\n|;
        return $applet;
    }
    elsif ( $type eq 'real' ) {
        # set some default parameters for the real applet
        unless ( keys %{ $params } > 0 ) {
            $params->{'controls'} = 'ImageWindow';
            $params->{'console'} = '_master';
            $params->{'nojava'} = 'true';
        }
        my $real = qq|<object id="RVOCX" classid="clsid:CFCDAA03-8BE4-11cf-B84B-0020AFBBCCFA" $width_height>\n|
            . qq|<param name="src" value="$link" />\n|;
        foreach my $key ( keys %{ $params } ) {
            $real .= qq|<param name="$key" value ="$params->{$key}">\n|;
        }
        $real .= qq|<embed src="$link" controls="ImageWindow" console="_master" nojava="true" $width_height></embed>\n|
            . qq|</object>\n|;
        return $real;
    }
    elsif ( $type eq 'iframe' ) {
        # Use random number as we might have multiple iframes on one page
        my $rand = int rand 1000;
        return qq|<script language="JavaScript"><!-- \n|
            . qq|function calcHeight$rand() {\n|
            . qq|document.getElementById("iframe$rand").style.visibility = "hidden";\n|
            . qq|setTimeout('document.getElementById("iframe$rand").style.visibility = "visible"',1);\n } //--></script>\n|
            . qq|<div id="iframe$rand">\n|
            . qq|<iframe src="$link" frameborder="0" scrolling="auto" name="ifrm$rand" id="ifrm$rand" $width_height>|
            . qq|<ilayer src="$link" $width_height></ilayer>\n</iframe>\n</div>\n|;
     }
     elsif ( $type eq 'qt' ) {
        return qq|<embed src="$link" volume="100" autostart="true" pluginspace="http://www.apple.com/quicktime/download/" $width_height></embed>\n|;
     }
}

1;
