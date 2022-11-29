package OpenInteract2::Action::UserAgent;

# $Id: UserAgent.pm,v 1.4 2009-01-07 14:42:32 amv Exp $

use strict;
use base qw( OpenInteract2::Action );
use OpenInteract2::Context qw( CTX );

# Detect client browser and print as a string

sub ua_browser {
	my ( $self ) = @_;

	return $self->_browser_detect;
}

# Detect client browser and return it as a string

sub _browser_detect {
	my ( $self ) = @_;

	$_ = CTX->request->user_agent;

	if    (/msie\s(\S+);/)      {return "Internet Explorer $1"; }
	elsif (/konqueror\/(\S+);/) {return "Konqueror $1"; }
	elsif (/opera\s(\S+) /)     {return "Opera $1"; }
	elsif (/\ssun/)             {return "Hotjava"; }
	elsif (/omniweb/)           {return "Omniweb"; }
	elsif (/galeon/)            {return "Galeon"; }
	elsif (/mozilla\/(\S+)/) {
		my $version = $1;
		if (/gecko/) {
			/ (\S+)\)/;
			my $type = uc $1;
			return "Mozilla $type";
		}
		return "Netscape $version";
	}
	elsif (/gecko/) 		       {return "Mozilla";}
	elsif (/lynx\/(\S+)/)                  {return "Lynx $1"; }
	elsif (/links\s\((\S+);/)              {return "Links $1"; }
	elsif (/aol(-iweng)?\s?(\d\.\d{0,3})/) {return "AOL's Browser $2"; }
	elsif (/ibrowse/)                      {return "Amiga's iBrowse"; }
	elsif (/googlebot/)                    {return "GoggleBot"; }
	elsif (/lecodechecker/)                {return "LeCodeChecker"; }
	elsif (/architextspider/)              {return "Architext Spider"; }
 	elsif (/slurp/)                        {return "Hotbot's Slurp"; }
 	elsif (/scooter/)                      {return "Altavista's Scooter"; }
 	elsif (/lycos_spider/)                 {return "Lycos' Spider"; }
 	elsif (/ultraseek/)                    {return "UltraSeek's Spider"; }
 	elsif (/infoseek/)                     {return "InfoSeek's Spider"; }
	else                                   {return "Unknown"; }
}

# Detect client operating system and print as a string

sub ua_os {

	my ( $self ) = @_;

	my $os = undef;

	$_ = CTX->request->user_agent;

	if (/linux\s(\S+)\s/) {
		$os = "Linux $1";
		chop $os if $os !~ /\d$/;
	}
	elsif (/mac/) {
		if (/p(ower)?pc/) {
			if (/os(\d+\.?\d?)/) {
				$os = "Macintosh PowerPC os$1";
			} else {
				$os = 'Macintosh PowerPC';
			}
		}
		elsif (/(68k)/) {$os = "Macintosh $1";}
		else            {$os = 'Macintosh';}
	}
	elsif (/dec/ || /alpha/ || /osf1/ || /ultrix/) {$os = "DEC";}
	elsif (/sco/ || /unix_sv/)         {$os = "SCO";}
	elsif (/vax/ || /openvms/)         {$os = "VMS";}
	elsif (/netbsd/)                   {$os = "NetBSD";}
	elsif (/netbsd/)                   {$os = "NetBSD";}
	elsif (/netbsd/)                   {$os = "NetBSD";}
	elsif (/netbsd/)                   {$os = "NetBSD";}
	elsif (/freebsd\s(\d+\.?\d*)/)     {$os = "FreeBSD $1";}
	elsif (/netbsd/)                   {$os = "NetBSD";}
	elsif (/openbsd/)                  {$os = "OpenBSD";}
	elsif (/bsd/)                      {$os = "BSD";}
	elsif (/ncr/)                      {$os = "NCR/MPRAS";}
	elsif (/win 9x 4\.90/)             {$os = "WindowsME";}
	elsif (/win(dows\s)?(\d+)/)        {$os = "Windows $2";}
	elsif (/windows\snt\s5\d*/)        {$os = "Windows 2000";}
	elsif (/windows\snt\s?(\d*)/)      {$os = "Windows NT $1";}
	elsif (/hp-ux/)                    {$os = "HP-UX";}
	elsif (/irix/)                     {$os = "Irix";}
	elsif (/unix_system_v/)            {$os = "Unixware";}
	elsif (/sinix/)                    {$os = "Sinix";}
	elsif (/reliant/)                  {$os = "Reliant Unix";}
	elsif (/aix/)                      {$os = "Aix";}
	elsif (/sunos\s?(\d+\.?\d*)/)      {$os = "SunOS $1";}
	elsif (/os\/2/)                    {$os = "OS/2";}
	elsif (/amiga(os)?\s?(\d*\.?\d*)/) {$os = "AmigaOS $2";}
	elsif (/acorn/)                    {$os = "Acorn";}
	elsif (/x11/)                      {$os = "Unix (Unknown)";}
	elsif (/webtv\/(\d*\.?\d*)/)       {$os = "WebTV $1";}
	else                               {$os = "Unknown";}

	return $os;
}

1;

__END__

=pod

=head1 NAME

OpenInteract2::Action::UserAgent - Analyze and return data based on User-Agent

=head1 DESCRIPTION

Basically creates OI components you can use in TT templates.

Available actions:

B<os>

OpenInteract component. Use with:

   [% OI.comp('ua_os') %]

Returns the operating system of the client.

B<browser>

OpenInteract component. Use with:

   [% OI.comp('ua_browser') %]

Returns the browser of the client.

=head1 TO DO

Return client version separately. Useful for making different stylesheets
for different versions of a browser.

=head1 BUGS

None known.

=head1 COPYRIGHT

Copyright (c) 2003 Ionstream Oy. All rights reserved.

=head1 AUTHORS

Teemu Arina <teemu@ionstream.fi>

=cut
