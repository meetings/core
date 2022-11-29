#!/usr/bin/perl
my $url = $ARGV[0] || 'https://doug1izaerwt3.cloudfront.net/e7187cd865164541d52a7a24415d6b3a4551ac86.1.js';

my $enter_intercepted_class_arrays = [
#    [ example_class_which_matches => [ "record", "This event gets fired", {} ] ]
];
my $enter_intercepted_class_json_arrays = [ map { Dicole::Utils::JSON->encode( $_ ) } @$enter_intercepted_class_arrays ];
my $track_click_json_arrays = [];

my $data = `curl -s '$url'`;
$data =~ s/.*KM\.idr\(\)\}\;//;

for my $call ( split /;/, $data ) {
    next unless $call =~ /trackClick/;
    my ( $json_array ) = $call =~ /^_kmq\.push\((.*)\)$/;
    next unless $json_array;
    push @$track_click_json_arrays, $json_array;

    if ( my ( $class, $json_params ) = $json_array =~ /\.(js_[\w_]*_submit)",(.*)\]$/ ) {
        $class =~ s/_submit/_enter_submit/;
        push @$enter_intercepted_class_json_arrays, "[\"$class\",[\"record\",$json_params]]";
    }
}

my $json_arrays = join ",", @$track_click_json_arrays;
my $json_enter_intercepted_class_arrays = join ",", @$enter_intercepted_class_json_arrays;

my $script = <<TEMPLATE;
dojo.provide('dicole.meetings_kissmetrics');

// This file has been generated with script/extract_kmq_trackclicks "$url"

dicole.meetings_kissmetrics.km_arrays = <<arrays>>;
dicole.meetings_kissmetrics.km_enter_intercepted_class_arrays = <<enter_intercepted_class_arrays>>;

dojo.subscribe( 'new_node_created', function() {
    if ( typeOf _kmq != 'undefined' ) {
        dojo.forEach( dicole.meetings_kissmetrics.km_arrays, function( km_array ) {
            _kmq.push( km_array );
        }
    }
} );

dojo.subscribe( 'enter_intercepted', function( node ) {
    if ( typeOf _kmq != 'undefined' ) {
        dojo.forEach( dicole.meetings_kissmetrics.km_enter_intercepted_class_arrays, function( km_enter_array ) {
            if ( dojo.hasClass( node, km_enter_array[0] ) ) {
                _kmq.push( km_enter_array[1] );
            }
        }
    }        
} );

TEMPLATE

$script =~ s/<<arrays>>/[$json_arrays]/;
$script =~ s/<<enter_intercepted_class_arrays>>/[$json_enter_intercepted_class_arrays]/;

print $script . $/;
