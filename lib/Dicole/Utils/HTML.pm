package Dicole::Utils::HTML;
use strict;

use base qw(Dicole::Utils::Text);

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use HTML::TreeBuilder;
use HTML::Element;
use HTML::FormatText;
use HTML::Scrubber::StripScripts;
use URI::Find;
use Data::Structure::Util;
use Dicole::Utils::Text;
use Encode ();
use Encode::Guess qw/iso-8859-1/;
use Dicole::Utils::HTML::StripScripts;
use HTML::Entities ();

sub safe_tree {
    my ( $class, $html ) = @_;
    
    my $tree = HTML::TreeBuilder->new_from_content( $class->ensure_internal( $html ) );
    if ( CTX && CTX->controller && CTX->controller->can( 'add_used_htmltree' ) ) {
        CTX->controller->add_used_htmltree( $tree );
    }
    return $tree;
}

sub text_to_html {
    my ( $class, $string ) = @_;
    $string = $class->encode_entities( $string );
    $string =~ s/\r?\n/<br \/>/sg;
    return $string;
}

sub text_to_phtml {
    my ( $class, $string ) = @_;
    $string = $class->encode_entities( $string );
    my @paragraphs = split /(?:\r?\n){2}/, $string;
    $string = '<p>' . join( "</p><p>", @paragraphs ) . '</p>';
    $string =~  s/\r?\n/<br \/>/sg;
    return $string;
}

sub html_to_text {
    my ( $class, $html ) = @_;

    my $tree = $class->safe_tree( $html );
    my $return = $class->_generate_text( $tree );
    $tree->delete;
    return $class->ensure_utf8( $return );
}

sub html_to_htmlencoded_text { # Disabled after transform to UTF8
    my ( $class, $html ) = @_;
    
    # Disabled after transform to UTF8
    return $class->html_to_text( $html );
}

sub _generate_text {
    my ( $class, @elements ) = @_;

    my @texts = ();
    my $exclude = '^(script|style)$';
    my $begin_linefeed = '^(tr|table|p|br|li|dd|dt|h[0-9]+)$';
    my $end_linefeed = '^(tr|table|p|br|li|dd|dt|h[0-9]+)$';
    my $space = '^(td)$';

    my ( $element, $tag, $text );
    $tag = '';
    while ( scalar( @elements ) ) {
        $element = shift @elements;
        if ( ref( $element ) ) {
            push @texts, "\n\n" if $tag =~ /$end_linefeed/i;
            $tag = $element->{'_tag'};
            next if $tag =~ /$exclude/;
            push @texts, "\n\n" if $tag =~ /$begin_linefeed/i;
            push @texts, " " if $tag =~ /$space/i;
            unshift @elements, @{ $element->{'_content'} }
                if ref( $element->{'_content'} );
        }
        elsif ( defined( $element ) && $element ne '' ) {
            $text = $element;
            $text =~ s/\n/ /g;
            push @texts, $text;
        }
    }
    # no final end linefeeds needed

    $text = join '', @texts;

    $text =~ s/[ \t]+/ /gm;
    $text =~ s/\n /\n/gm;
    $text =~ s/\n\n+/\n\n/gm;
    $text =~ s/^ ?(\n\n)?//;
    $text =~ s/(\n\n)? ?$//;

    return $text;
}

sub encode_entities {
    my ( $class, $string ) = @_;
    return $class->ensure_utf8(
        $class->encode_entities_internal(
           $class->ensure_internal( $string )
        )
    );
}

sub encode_entities_internal {
    my ( $class, $string ) = @_;
    $string = HTML::Entities::encode_entities( $string );
    return $string;
}

sub shorten {
    my ( $class, $html, $length ) = @_;

    my $tree = $class->safe_tree( $html );
    my $length_left = $class->_shorten_tree_in_place_rec( $tree, $length );
    my $return = $class->tree_guts_as_xml( $tree );

    $tree->delete;

    return $return;
}

sub _shorten_tree_in_place_rec {
    my ( $class, $element, $length ) = @_;
    
    my $length_left = $length;
    my $text = $class->_generate_text( $element );
    my $text_length = length( $text );
    if ( $text_length <= $length_left ) {
        $length_left -= $text_length;
    }
    elsif ( ref( $element ) ) {
        my @elements = $element->splice_content( 0 );
        for my $elem ( @elements ) {
            next unless $length_left > 0;
            if ( ! ref( $elem ) ) {
                $elem ||= '';
                my $text_length = length( $elem );
                if ( $text_length <= $length_left ) {
                    $element->push_content( $elem );
                    $length_left -= $text_length;
                }
                else {
                    $element->push_content(
                        Dicole::Utils::Text->shorten_internal( $elem, $length_left )
                    );
                    $length_left = 0;
                }
            }
            else {
                $element->push_content( $elem );
                $length_left = $class->_shorten_tree_in_place_rec(
                    $elem, $length_left
                );
            }
        }
    }
    
    return ( $length_left );
}

sub set_inline_style_attributes {
    my ( $class, $html, $styles ) = @_;
    
    my $tree = $class->safe_tree( $html );
    $class->_set_inline_style_attributes_in_place_rec( $tree, $styles );
    my $return = $class->tree_guts_as_xml( $tree );

    $tree->delete;

    return $return;
}

sub _set_inline_style_attributes_in_place_rec {
    my ( $class, $element, $styles ) = @_;

    if ( ref( $element ) ) {
        my @elements = $element->splice_content( 0 );
        for my $elem ( @elements ) {
            $element->push_content( $elem );
            if ( ref( $elem ) ) {
                my $tag = lc( $elem->tag );
                if ( my $s = $styles->{ $tag } ) {
                   $elem->attr( 'style', $s );
                }
                $class->_set_inline_style_attributes_in_place_rec(
                    $elem, $styles
                );
            }
        }
    }
}

sub strip_scripts {
    my ( $class, $string, @params ) = @_;

    my $hss = Dicole::Utils::HTML::StripScripts->new( @params );

    return $class->ensure_utf8( $hss->filter_html( $class->ensure_internal( $string ) ) );
}

sub sanitize_attributes {
    my ( $class, $html ) = @_;

    my $tree = $class->safe_tree( $html );
    $class->_sanitize_attributes_tree_in_place_rec( $tree );
    my $return = $class->tree_guts_as_xml( $tree );

    $tree->delete;

    return $return;
}

my %valid_attributes_map = (
    style => 1,
    title => 1,
    alt => 1,
    href => 1,
    src => 1,
    class => 1,
);

my %valid_classes_map = (
    dicole_embedded_html => 1,
    wikiLink => 1,
    generic_attachment_png => 1,
);

sub _sanitize_attributes_tree_in_place_rec {
    my ( $class, $element ) = @_;

    if ( ref( $element ) ) {
        my @elements = $element->splice_content( 0 );
        for my $elem ( @elements ) {
            if ( ! ref( $elem ) ) {
                $element->push_content( $elem );
            }
            else {
                $elem->id( undef );
                for my $attr ( $elem->all_external_attr_names ) {
                    $elem->attr( $attr, undef ) unless $valid_attributes_map{ $attr };
                }
                my $class_string = $elem->attr( 'class' );
                if ( $class_string ) {
                    my @classes = split /\s+/, $class_string;
                    my @new_classes = map { $valid_classes_map{ $_ } ? $_ : () } @classes;
                    $elem->attr( 'class', scalar( @new_classes ) ? join( ' ', @new_classes ) : undef );
                }
                $element->push_content( $elem );
                $class->_sanitize_attributes_tree_in_place_rec( $elem );
            }
        }
    }
    
    return 1;
}

sub utf8_to_latinhtml {
    my ( $self, $text ) = @_;

    return Encode::encode(
        'iso-8859-15',
        $self->utf8_to_internal( $text ),
        Encode::FB_HTMLCREF
    );
}

sub link_plaintext_urls {
    my ( $class, $html ) = @_;

    my $tree = $class->safe_tree( $html );

    $class->_link_plaintext_urls_tree_in_place_rec( $tree );

    my $return = $class->tree_guts_as_xml( $tree );

    $tree->delete;

    return $return;
}

sub _link_plaintext_urls_tree_in_place_rec {
    my ( $class, $element, $length ) = @_;

    if ( ref( $element ) ) {
        return 1 if lc( $element->tag ) eq 'a';
        my @elements = $element->splice_content( 0 );
        for my $elem ( @elements ) {
            if ( ! ref( $elem ) ) {
                $elem ||= '';
                my @uris = ();
                my $finder = URI::Find->new( sub {
                    my ( $uri, $original_uri ) = @_;
                    push @uris, [ $original_uri, $uri ];
                    return $original_uri;
                } );
                $finder->find( \$elem );
                my @new_elems = ();
                for my $match ( @uris ) {
                    my $index = index( $elem, $match->[0] );
                    my $before = substr( $elem, 0, $index );
                    $element->push_content( $before );

                    my $a = HTML::Element->new('a', href => "" . $match->[1], title => "" . $match->[1] );
                    $a->push_content( $match->[0] );
                    $element->push_content( $a );

                    $elem = substr( $elem, $index + length( $match->[0] ) );
                }
                $element->push_content( $elem );
            }
            else {
                $element->push_content( $elem );
                $class->_link_plaintext_urls_tree_in_place_rec( $elem );
            }
        }
    }
    
    return 1;
}

sub break_long_strings {
    my ( $class, $html, $length ) = @_;

    my $tree = $class->safe_tree( $html );
    $class->_break_long_strings_tree_in_place_rec( $tree, $length );
    my $return = $class->tree_guts_as_xml( $tree );

    $tree->delete;

    return $return;
}

sub _break_long_strings_tree_in_place_rec {
    my ( $class, $element, $length ) = @_;

    if ( ref( $element ) ) {
        my @elements = $element->splice_content( 0 );
        for my $elem ( @elements ) {
            if ( ! ref( $elem ) ) {
                $elem ||= '';
                $element->push_content(
                    $class->break_long_strings_internal( $elem, $length )
                );
            }
            else {
                $element->push_content( $elem );
                $class->_break_long_strings_tree_in_place_rec( $elem, $length );
            }
        }
    }
    
    return 1;
}

sub tree_guts_as_xml {
    my ( $class, $tree ) = @_;
    my @guts = $tree->guts;
    return $class->tree_nodes_as_xml( @guts );
}

sub tree_nodes_as_xml {
    my ( $class, @nodes ) = @_;
    my @htmls = map { $class->node_as_dicole_html( $_ ) } @nodes;
    return $class->ensure_utf8( join '', @htmls );
}

# Copy the as_XML method to gain better control of entity encoding
# and to make sure that the output doesn't magically change as
# is has already done it once when updating to HTML::Tree 3.22

sub node_as_dicole_html {
    my( $class, $this_node ) = @_;

    return $class->_old_xml_escape( $this_node ) unless ref( $this_node );

    my @xml = ();
    my $empty_element_map = $this_node->_empty_element_map;
    my($tag, $node, $start);
    $this_node->traverse(
        sub {
            ($node, $start) = @_;
            if( ref $node ) {
                if( $empty_element_map->{ $node->{'_tag'} } && ! scalar( @{$node->{'_content'} || []} ) ) {
                    push( @xml, $node->starttag_XML( undef, 1 ) ) if $start;
                }
                else {
                    push( @xml, $start ? $node->starttag_XML( undef ) : $node->endtag_XML() );
                }
            }
            else {
                push( @xml, $class->_old_xml_escape( $node ) );
            }
            return 1;
        }
    );
    return join('', @xml, "\n");
}

sub _old_xml_escape {
    my ( $class, $chars ) = @_;
    $chars =~ s/([^\x20\x21\x23\x27-\x3b\x3d\x3F-\x5B\x5D-\x7E])/'&#'.(ord($1)).';'/seg;
    return $chars;
}

1;
