#!/usr/bin/perl

use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my %opts = (
    'NAME'            => 'Dicole',
    'VERSION'  => '0.9.0',
    'EXE_FILES'     => [ qw( bin/devinst bin/update_manifest bin/install_dicole_package bin/maptoutf8 ) ],
    'PL_FILES'      => {},
    'NO_META'       => 1,
    'ABSTRACT'      => 'Dicole is a social software with wikis, weblogs, RSS etc.',
    'PREREQ_PM'     => {
        'perl'                                           => '5.6.1',
        'Algorithm::Diff'                                => 0,
        'Archive::Tar'                                   => 1.08,
        'Archive::Zip'                                   => 1.10,
#       'Authen::Radius'                                 => 0.10,
        'Class::Accessor'                                => 0,
        'Crypt::Rijndael'                                => 0,
        'Spreadsheet::ParseExcel'                        => 0.2603,
        'Unicode::MapUTF8'                               => 1.09,
        'Crypt::CBC'                                     => 0,
        'DateTime'                                       => 0.21,
        'DateTime::Locale'                               => 0.09,
        'DateTime::Format::ISO8601'			 => 0,
        'DateTime::Format::Mail'			 => 0,
        'Feed::Find'					 => 0,
        'File::MimeInfo'                                 => 0.10,
        'File::NCopy'                                    => 0.32,
        'File::Spec'                                     => 0.82,
        'File::Temp'                                     => 0.12,
        'Image::Magick'                                  => 0,
        'Locale::Maketext::Lexicon'                      => 0,
        'LWP::UserAgent'				 => 0,
        'Geography::Countries'                           => 0,
        'HTML::Parser'                                   => 3.25,
        'HTML::Scrubber'                                 => 0.06,
        'HTML::Scrubber::StripScripts'                   => 0.01,
        'IO::Zlib'                                       => 1.01,
        'Module::Build'                                  => 0,
        'MP3::Info'                                      => 1.02,
	'Net::LDAP'					 => 0,
	'Net::Subnets'					 => 0,
        'OpenInteract2::Manage'                          => 1.38,
        'RDF::Simple'                                    => 0.12,
        'RPC::XML'					 => 0,
#       'Spreadsheet::WriteExcel'                        => 2.03,
        'Text::CSV_XS'                                   => 0.23,
        'Text::WikiFormat'                               => 0.72,
        'URI'                                            => 1,
        'XML::Atom::Syndication'			 => 0,
        'XML::Parser'                                    => 2.30,
        'XML::RSS'                                       => 1.05,
        'XML::Simple'					 => 0,
        'XML::OPML'					 => 0,
        'XML::Feed' => 0.12,
        'XML::Liberal' => 0.18,
    },
);

if ($ExtUtils::MakeMaker::VERSION >= 5.43) {
    $opts{AUTHOR}   = 'Teemu Arina <teemu@dicole.com>';
    $opts{ABSTRACT} = 'Dicole is a social software with wikis, weblogs, RSS etc.';
}

WriteMakefile( %opts );
