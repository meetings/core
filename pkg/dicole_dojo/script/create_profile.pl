#!/usr/bin/perl

use Dicole::Utils::Text;
use Dicole::Utils::JSON;

my $data = {
	layers => [ 
		{
			name => "dicole.js",
			dependencies => [
				"dicole",
				"dicole.base",
				"dicole.navigation",
				"dicole.blogs",
#				"dicole.Cafe",
				"dicole.discussion",
				"dicole.comments",
				"dicole.event_source",
				"dicole.events",
				"dicole.groups",
				"dicole.invite",
				"dicole.localization",
				"dicole.networking",
				"dicole.presentations",
				"dicole.settings",
#				"dicole.Shareflect",
				"dicole.tags",
				"dicole.tinymce3.shortcut",
				"dicole.tinymce3",
#				"dicole.twitter",
				"dicole.user_manager",
				"dicole.wiki",
#				"dicole.meetings",
#				"dicole.meetings_navigation",
			]
		},
		{
			name => 'dicole_meetings.js',
#			layerDependencies => [
#				"dicole.js",
#			],
			dependencies => [
				"dicole.meetings",
				"dicole.meetings_navigation",
#				"dicole.navigation",
#				"dicole.groups",
#				"dicole.user_manager",
			]
		},
#                {
#                        name => "dicole_blogs.js",
#                        dependencies => [
#                                "dicole.base",
#                                "dicole.blogs",
#                                "dicole.comments",
#                                "dicole.tags",
#                                "dicole.tinymce",
#                        ]
#                },
	],
	prefixes => [
		[ "dijit", "../dijit" ],
		[ "dojox", "../dojox" ],
		[ "dicole", "../dicole" ],
	],
};

my $json = "dependencies = " . Dicole::Utils::JSON->encode( $data );

print $json . "\n";

