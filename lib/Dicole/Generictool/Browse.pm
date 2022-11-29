package Dicole::Generictool::Browse;

# If you want to inherit this class or create your own to be passed
# for Dicole::Generictool make sure your class implements
# atleast all the methods present in this class, because 
# Generictool rely on those methods blindly

use 5.006;
use strict;

use OpenInteract2::Context   qw( CTX );

use Dicole::Content::Text;
use Dicole::Content::Button;
use Dicole::Content::Hyperlink;
use Dicole::Content::Horizontal;
use Dicole::Calcfunc;
use Dicole::Generictool::SessionStore;

$Dicole::Generictool::Browse::VERSION = sprintf( "%d.%02d", q$Revision: 1.12 $ =~ /(\d+)\.(\d+)/ );

# The default limit for the number of link pages generated in get_browse().
# Must be an even number.
use constant DEF_PAGE_LIMIT => 9;

=pod

=head1 NAME

Browsing for Generictool lists

=head1 SYNOPSIS

  use Dicole::Generictool::Browse;

  my $obj = Dicole::Generictool::Browse->new( action => ['Users','list'] );
  $obj->default_limit_size( '10' );
  $obj->set_limits( '10', '20' );
  $obj->set_total_count( '100' );
  my $browse = $browse->get_browse;

  return $self->generate_content(
 	{ itemparams => $browse->get_template_params },
 	{ name => $browse->get_template }
  );

=head1 DESCRIPTION

The purpose of this class is to provide a way to handle browsing listings in
I<Dicole Generictool>. Basically this means that you want to limit a listing view
to include a certain ammount of objects and the remaining are splitted to
several pages, which you may browse with the browsing navigation.

Limiting information is stored in the session of the user to make sure that
the system I<remembers> the state of the browsing if the user comes back later.

The links for browsing buttons and page links are constructed by modifying
the existing URL GET parameters, not by constructing a new URL. This is to ensure
that any other information we might have in our URL parameters gets passed
along as when we submit the page.

If you want to provide your own browsing logic for I<Generictool>,
this is the class to inherit.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors for
the class attributes.

=cut

use base qw( Class::Accessor );

=pod

=head2 SessionStore( CLASS )

Sets/gets the SessionStore class. You may use this to change the object in 
use which is responsible to store/retrieve browsing information from the
session cache.

=head2 limit_start( [SCALAR] )

Controls where the limiting starts, i.e. since which item in the sequence we
should start displaying items. A accessor method. If optional parameter set
to a scalar value, sets class attribute I<limit_start>. With no parameters
returns class attribute I<limit_start>.

=head2 limit_size( [SCALAR] )

Controls limit size, i.e. how many items to display since limit start.
A accessor method. If optional parameter set to a scalar value, sets
class attribute I<limit_size>. With no parameters returns class attribute
I<limit_size>.

=head2 default_limit_size( [SCALAR] )

Controls the default size of the limit. If no limit size was given,
this is used instead. A accessor method. If optional parameter set to a
scalar value, sets class attribute I<default_limit_size>.
With no parameters returns class attribute I<default_limit_size>.

=head2 total_count( [SCALAR] )

Controls total number of items in the sequence. A accessor method.
If optional parameter set to a scalar value, sets class attribute
I<total_count>. With no parameters returns class attribute I<total_count>.

=cut

# We are lazy...Lets generate some basic accessors for our class
Dicole::Generictool::Browse->mk_accessors(
	qw( SessionStore limit_start limit_size default_limit_size total_count )
);

=pod

=head1 METHODS

=head2 new( { action => ARRAYREF } )

Returns a new I<Browse object>. I<action> parameter is required.
Optionally accepts initial class attributes as parameter passed in the anonymous hash.

=cut

sub new {
	my ($class, $args) = @_;
	my $self = $class->SUPER::new( $args );
	$self->SessionStore( Dicole::Generictool::SessionStore->new(
		{ action => $args->{action} }
	) );
	return $self;
}

=pod

=head2 set_limits( [SCALAR], [SCALAR] )

Looks in the Apache parameters for I<limit_start> and I<limit_size>.
If no parameters passed through Apache, looks the session cache for the
same parameters. Sets class attributes accordingly and saves new values
to session cache.

Optionally takes I<limit_start> and I<limit_size> as parameters.

=cut

sub set_limits {

	my ( $self, $limitstart, $limitsize ) = @_;
	
	unless ( defined $limitstart ) {
		$limitstart = CTX->request->param( 'limit_start' )
			if defined if_int( CTX->request->param( 'limit_start' ) );
	}
	unless ( defined $limitsize ) {
		$limitsize = CTX->request->param( 'limit_size' )
			if defined if_int( CTX->request->param( 'limit_size' ) );
	}

	my $browse = $self->SessionStore->by_key( 'browse' );
	if ( ref( $browse ) eq 'HASH' ) {
		if ( !defined $limitstart && defined $browse->{limit_start} ) {
			$limitstart = $browse->{limit_start};
		}
		if ( !defined $limitsize && defined $browse->{limit_size} ) {
			$limitsize = $browse->{limit_size};
		}
	}
	$limitstart ||= 0;
	
	unless ( $limitsize ) {
		$limitsize = $self->default_limit_size;
	}
	$limitsize ||= 1; # cannot be zero
	
	$self->limit_start( $limitstart );
	$self->limit_size( $limitsize );
	$self->_store_limits( $self->limit_start, $self->limit_size );
}

=pod

=head2 get_limit_query()

Returns valid parameters for SQL query B<ORDER BY>.

=cut

sub get_limit_query {
	my ( $self ) = @_;

	my $browse = $self->SessionStore->by_key( 'browse' );
	
	if ( ref( $browse ) eq 'HASH' ) {
		my $browse_query = undef;
		if ( defined $browse->{limit_start} ) {
			$browse_query = $browse->{limit_start};
		}
		if ( defined $browse_query ) {
			$browse_query .= ',';
		}
		$browse_query .= $browse->{limit_size};
		return $browse_query;
	}
	return undef;
}

=pod

=head2 get_cache_key()

Returns a unique browsing cache key for caching porposes. This is required
for identifying each unique page we are browsing.

=cut

sub get_cache_key {
	my ( $self ) = @_;
	return $self->get_limit_query;
}

=pod

=head2 get_browse( [limit_start => SCALAR], [limit_size => SCALAR], [total_count => SCALAR] )

Returns a L<Dicole::Content::Horizontal|Dicole::Content::Horizontal> object,
that returns text, links and buttons similar to this:

  Page: 1 _2_ 3 [PREVIOUS] [NEXT] ( 11 - 20 / 30 )

Dynamically contains linked page numbers, "previous" button and "next" button
if needed. Returns false if browsing is not required for current page
(i.e. I<total_count> is less than I<limit_size>).

Optionally takes I<limit_start>, I<limit_size> and I<total_count> as parameters.
If no parameters were passed, the required information is read from the
class attributes.

=cut

# TODO :
# - Add option to disable limiting.
# - Limitations work, but the method for limiting is kinda primitive.
# - Maybe move some of the code to own private functions.

sub get_browse {

	my $self = shift;
	
	my $args = {
		limit_start => $self->limit_start,
		limit_size  => $self->limit_size,
		total_count => $self->total_count,
		@_
	};

        my $lh = CTX->request->language_handle;

	my $navigation = Dicole::Content::Horizontal->new;

	my ( $last_item, $si, $href );

	# Don't do anything if all the items fit on one page
	if ( $args->{total_count} <= $args->{limit_size} ) {
		return undef;
	}

	my %query_params = %{ CTX->request->url_query };
		
	$query_params{limit_size} = $args->{limit_size};
	
	# Add the page text
	$navigation->add_content( Dicole::Content::Text->new(
		content => $lh->maketext( "Page:" ) . ' '
	) );

	# Add the page numbers
	if ( $args->{limit_size} < $args->{total_count} ) {
		my ( $pagenum, $page_count, $curr_page, $start_page, $end_page );

		# Calculate the number of total pages
		$page_count = int( $args->{total_count} / $args->{limit_size} );

		# Add one page if division is not even
		if ( ( $args->{total_count} % $args->{limit_size} ) >= 1 ) {
			$page_count++;
		}
		
		# Calculate current page, add one to limit_start because
		# limit_start starts from zero, but page_count from 1, and we
		# can't divide with zero
		$curr_page = int( ($args->{limit_start} + 1) / $args->{limit_size} );

		# Add one page if division is not even
		if ( ( ($args->{limit_start} + 1) % $args->{limit_size} ) >= 1 ) {
			$curr_page++;
		}

		# Get the page link limitations
		($start_page, $end_page) = $self->_get_pagelink_limits(
                    $page_count, $curr_page
		);

                if ( $args->{limit_start} > 0 ) {
                        $si = $args->{limit_start} - $args->{limit_size};
                        $query_params{limit_start} = ( $si >= 0 ) ? $si : 0;
                        # Hack: get rid or GET parameters
                        my $url_abs = CTX->request->url_absolute;
                        $url_abs =~ s/\?.*$//;
                        
                        my $uri = OpenInteract2::URL->create(
                            $url_abs,
                            \%query_params
                        );
                        
                        $navigation->add_content( Dicole::Content::Button->new(
                            type  => 'link',
                            value => $lh->maketext( 'Previous' ),
                            link  => $uri
                        ) );
                            
                }
                
		if( $start_page > 0 ) {

                        # Hack: get rid or GET parameters
                        my $url_abs = CTX->request->url_absolute;
                        $url_abs =~ s/\?.*$//;
 
			$query_params{limit_start} = 0;

                        my $uri = OpenInteract2::URL->create(
                            $url_abs,
                            \%query_params
                        );

			$navigation->add_content( Dicole::Content::Hyperlink->new(
				content => '1',
				attributes => { href => $uri, class => 'browsePageItem' }
			) );
			
			$navigation->add_content( Dicole::Content::Text->new(
				content => '..',
			) );
		}
		
		# Add all the page links
		for ( my $i=$start_page; $i < $end_page; $i++ ) {

			# Displayed pages start from 1
			$pagenum = $i + 1;
			
			# Check if the generated page number link is the
			# page we currently are on, don't make a link if true
			my $obj_class = ( $pagenum == $curr_page )
				? 'Dicole::Content::Text'
				: 'Dicole::Content::Hyperlink';

			# generate content object:
			$si = $i * $args->{limit_size};
				
			$query_params{limit_start} = $si;

                        # Hack: get rid or GET parameters
                        my $url_abs = CTX->request->url_absolute;
                        $url_abs =~ s/\?.*$//;
                                                                        
                        my $uri = OpenInteract2::URL->create(
                            $url_abs,
                            \%query_params
                        );

			# if $obj_class is D::C::Text, discards the 'attributes' argument
			$navigation->add_content( $obj_class->new(
				content => "$pagenum",
				attributes => {
				    ( $pagenum == $curr_page ) ? () : ( href => $uri ),
				    class => 'browsePageItem'
                                }
			) );
			
		}
	
		if( $end_page < $page_count ){
			$query_params{limit_start} = $page_count * $args->{limit_size};

                        # Hack: get rid or GET parameters
                        my $url_abs = CTX->request->url_absolute;
                        $url_abs =~ s/\?.*$//;
                                                                        
                        my $uri = OpenInteract2::URL->create(
                            $url_abs,
                            \%query_params
                        );
			
			$navigation->add_content( Dicole::Content::Text->new(
				content => '..',
			) );
	
			$navigation->add_content( Dicole::Content::Hyperlink->new(
				content => "$page_count",
				attributes => { href => $uri, class => 'browsePageItem' }
			) );
		}
	}
		
	# Calculate the last item displayed
	if( ($args->{limit_start} + $args->{limit_size}) > $args->{total_count} ) {
		$last_item = $args->{total_count};
	} else {
		$last_item = $args->{limit_start} + $args->{limit_size};
	}
	
	# Add the next page link
	if ( ($args->{limit_start} + $args->{limit_size}) < $args->{total_count} ) {

		$query_params{limit_start} = $last_item;

                # Hack: get rid or GET parameters
                my $url_abs = CTX->request->url_absolute;
                $url_abs =~ s/\?.*$//;
                                                                        
                my $uri = OpenInteract2::URL->create(
                    $url_abs,
                    \%query_params
                );
				
		$navigation->add_content( Dicole::Content::Button->new(
			type  => 'link',
			value => $lh->maketext( 'Next' ),
			link  => $uri
		) );
	}

	# Add the info about number of items
	my $infotext;
	if ( ($args->{limit_start} + 1) == $last_item ) {
		$infotext = $last_item;
	} else {
		$infotext = ($args->{limit_start} + 1) . " - " . ($last_item);
	}
	$infotext .= ' / ' . $args->{total_count};

	$navigation->add_content( Dicole::Content::Text->new(
		content => "( $infotext )"
	) );

	return $navigation;
}
		
=pod

=head1 PRIVATE METHODS

=head2 _store_limits( [SCALAR], [SCALAR] )

Stores new values for I<limit_start> and I<limit_size> to session cache. Both
parameters are optional.

=cut

sub _store_limits {
	my ( $self, $limitstart, $limitsize ) = @_;
	if ( defined $limitstart ) {
		$self->SessionStore->by_key( 'browse', $limitstart, 'limit_start' );
	}
	if ( defined $limitsize ) {
		$self->SessionStore->by_key( 'browse', $limitsize, 'limit_size' );
	}
}

=pod

=head2 _get_pagelink_limits( [SCALAR], [SCALAR] )

Returns the range that page numbers are generated for. Used in get_browse().
Requires total page count and the current page as parameters.

=cut

sub _get_pagelink_limits {	

	my ( $class, $page_count, $curr_page ) = @_;
	my ( $start_page, $end_page );

	# Check if we want to limit the number of links to be created
	if ( $page_count > DEF_PAGE_LIMIT ) {
		# Calculate the starting page where we start
		# generating page links.
		if ( ($page_count - $curr_page) < int(DEF_PAGE_LIMIT / 2)) {
			$start_page = $page_count - DEF_PAGE_LIMIT;
		}
		else {
			$start_page = ($curr_page - 1) - int(DEF_PAGE_LIMIT / 2);
		}

		# Calculate the ending page where we stop generating
		# page links.
		if ( $curr_page <= (DEF_PAGE_LIMIT / 2) ) {
			$end_page = DEF_PAGE_LIMIT;
		}
		else {
			$end_page = $curr_page + int((DEF_PAGE_LIMIT - 2) / 2);	
		}
		
		# Check if start and end pages are within range
		if ( $start_page < 0 ) {
			$start_page = 0;
		}
		if ( $end_page > $page_count ) {
			$end_page = $page_count;
		}
	}
	else {
		$start_page = 0;
		$end_page = $page_count;
	}
	
	return ($start_page, $end_page);
}

=pod

=head1 SEE ALSO

L<Dicole::Content::Horizontal|Dicole::Content::Horizontal>, 
L<Dicole::Generictool|Dicole::Generictool>

=head1 AUTHOR

Teemu Arina, E<lt>teemu@ionstream.fiE<gt>

=head1 COPYRIGHT AND LICENSE

 Copyright (c) 2004 Ionstream Oy / Dicole
 http://www.dicole.com

Licence version: MPL 1.1/GPL 2.0/LGPL 2.1

The contents of this file are subject to the Mozilla Public License Version
1.1 (the "License"); you may not use this file except in compliance with
the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
for the specific language governing rights and limitations under the
License.

The Original Code is Dicole Code.

The Initial Developer of the Original Code is Ionstream Oy (info@dicole.com).
Portions created by the Initial Developer are Copyright (C) 2004
the Initial Developer. All Rights Reserved.

Contributor(s):

Alternatively, the contents of this file may be used under the terms of
either the GNU General Public License Version 2 or later (the "GPL"), or
the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
in which case the provisions of the GPL or the LGPL are applicable instead
of those above. If you wish to allow use of your version of this file only
under the terms of either the GPL or the LGPL, and not to allow others to
use your version of this file under the terms of the MPL, indicate your
decision by deleting the provisions above and replace them with the notice
and other provisions required by the GPL or the LGPL. If you do not delete
the provisions above, a recipient may use your version of this file under
the terms of any one of the MPL, the GPL or the LGPL.

=cut

1;

