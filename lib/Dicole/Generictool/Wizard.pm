package Dicole::Generictool::Wizard;

use 5.006;
use strict;

use OpenInteract2::Context qw( CTX );

use Dicole::Generictool::Field::Validate;
use Dicole::Generictool::Wizard::Results;
use Dicole::Generictool::Wizard::Page;
use Dicole::Generictool::Wizard::Page::Switch;
use Dicole::Generictool::Wizard::Page::AdvancedSelect;
use Dicole::Generictool::Wizard::Page::Select;
use Dicole::MessageHandler qw( :message );
use Dicole::Tool;

$Dicole::Generictool::Wizard::VERSION = sprintf("%d.%02d", q$Revision: 1.13 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME

Allows creation of generic wizards for Generictool

=head1 SYNOPSIS

  use Dicole::Generictool::Wizard;
  use Dicole::Tool;
  
  # Create new wizard object:
  my $wizard = Dicole::Generictool::Wizard->new();
  
  # Where should we go when cancel button is pressed
  $wizard->cancel_redirect( '/url/to/the/page.html' );
  
  # Add new (basic) page to the wizard
  my $page1 = $wizard->add_page( name => 'Basic information' );
  $page1->name( 'New name' );
  
  # Add new fields to the page (a field is a Dicole::Generictool::Field object)
  my $login_name = $page1->add_field( id => 'login_name' );
  $login_name->type( 'textfield' );
  $login_name->required( 1 );
  $login_name->desc( 'Login name' );
  
  # add new field using the constructor parameters
  my $lang = $page1->add_field(
  	id => 'language',
  	type => 'dropdown',
  	desc => 'Language',
  );
  $lang->mk_dropdown_options(
  	class => $R->lang,
  	params => { order => 'lang_name' },
  	value_field => 'lang_code',
  	content_field => 'lang_name',
  );
  
  # Add page switch (wizard page content depends on the earlier answers)
  my $page2 = $wizard->add_page_switch( name => 'Additional language settings' );
  
  # add new page to the switch
  my $page2a = $page2->add_page( 
  	name => 'English',  # the displayed name of the page in this case is "Additional language settings >> English"
  	display_if => { 
  		language => 'en' # a hash of "$field_id => $value" pairs
  	}
  );
  
  # add fields to the page
  $page2a->add_field(  
  	id => 'custom_notes',
  	type => 'textfield',
  	desc => 'Add your custom stuff here'
  );
  
  # add another page to the switch
  my $page2b = $page2->add_page(
  	name => 'Finnish',
  	display_if => {
  		language => 'fi'
  	}
  );
  
  # etc...
  
  # The first page in the array of switch's pages whose 'display_if' requirements are met is shown.
  # If none of the 'display_if' requirements in the page switch is fulfilled, the page is skipped.
  # For example in this case if the user selects some language that isn't Finnish or English, the
  # page 2 is skipped, and the user is taken to page 3 after the first page.
  
  # Activation means that we have done initialization (specifying pages etc).
  # Automatical actions such as saving user input in database is done in the activation phase
  $wizard->activate();
  
  # Generate Tool object
  my $tool = Dicole::Tool->new( action_params => $p );
  $tool->Container->generate_boxes( 1, 1 );
  
  if( $wizard->has_more_pages() ) {
  	# Add the wizard content into the tool
        $wizard->apply_to_tool($tool);
  }
  elsif( $wizard->finished() ) { # wizard has finished
  	my $results = $wizard->results(); # returns a hashref of a hash containing "$field_id => $value" pairs of all the wizard pages
	save_results( $results ); # do something with the results
	redirect_to_somewhere_or_return_another_page();
  }

=head1 DESCRIPTION

The purpose of this class is to provide generic methods that allow easy
creation of wizards (multi-page configuration tools) in web-based applications.
The results the wizard gathers are temporarily stored in database, and they can 
be accessed through a data structure returned by the results() method. The form
of the data structure depends on the type of L<Dicole::Generictool::Field|Dicole::Generictool::Field>
objects used on the wizard pages, but usually the results are returned as
a hash with the field-ids as the hash-keys.

The wizard-instances are identified by a unique randomly selected wizard_id. 
Thus the user can open simultaneously several instances of the same configuration
wizard (e.g. adding multiple users with a wizard at the same time in different
browser windows).

This wizard class doesn't provide automatical data saving in spops-objects. The
wizard cannot be used like L<Dicole::Generictool|Dicole::Generictool> to save the
results automatically in database. Wizards can be used to gather information that
we don't want to store in a database, or that needs additional preprocessing before
storing it into the db. That's why we want to return the results as a data structure
for the handler to process. However, if we want to make the developer's life easier, it should 
be pretty simple to implement later an additional wrapper class that can save the data automatically 
according to the class's configuration.

=head2 Wizard functionality

A wizard object can contain multiple L<Dicole::Generictool::Wizard::Page|Dicole::Generictool::Wizard::Page>
objects, which can contain multiple L<Dicole::Generictool::Field|Dicole::Generictool::Field> objects. These
are initialized during the wizard initialization phase. After all the pages and their fields are added and the
initialization is done, the wizard should be activated by calling the method activate(). This starts maintenance
routines like validating and saving user input. After this the wizard object can be queried for new page content,
or if all the pages have been processed, the results can be queried.

The wizard pages are presented to the user in the order they are added to the wizard object. When showing a page
to the user, each of the page's field and it's description are displayed to the user. The user can modify the
values of the fields (how modifying is actually done depends on the type of the field). When clicking "Next" or
"Previous" button the user input is validated, and if valid input was given, the user is taken to next or previous 
wizard page, respectively. In the last page of the wizard the "Next" button is replaced with "Finish" button.

=head1 INHERITS

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors
for the class attributes.

=cut

use base qw( Class::Accessor );

=pod

=head2 cancel_redirect( [SCALAR] )

Sets/returns the url that the user is taken to when the cancel button is pressed. Unless the
parameter is defined, the cancel button isn't shown to the user.

=head2 _current_page( [SCALAR] )

Sets/returns the current wizard page index.

=head2 _active( [BOOLEAN] )

Defines if the wizard has already been activated with the activate()-method.

=head2 _wizard_data( [HASHREF] )

Sets/returns the wizard data as a reference to a hash. The hash contains
$field_id => $wizard_data_spops_object -pairs. The spops objects contain for example values for 
http_name (same as $field_id) and http_value (the value of the field).

=head2 _wizard_instance_object( [SCALAR] )

Sets/returns the wizard instance spops object.

=cut

=head2 hidden_fields( [HASH] )

Sets/returns the hash containing extra hidden fields applied to wizard pages.

=head2 _page_id_counter( [HASH] )

Sets/returns the number of the last page id assigned.

=cut

Dicole::Generictool::Wizard->mk_accessors(
	qw( _current_page _active _wizard_data _wizard_instance_object
            cancel_redirect hidden_fields _page_id_counter )
);

=pod

=head1 CONSTANTS

=head2 MAX_RANDOM_ID = 4294967295

Defines the largest id that can be returned by the wizard id generator.
The generator returns integer values between 1..MAX_RANDOM_ID .
The value used is the maximum value of unsigned int type in SQL-92 standard.

=head2 EXPIRE_TIME = 36000

Defines the expiration time of the wizard temporary data in seconds. The current value
is 10 hours, which should be more than enough.

=head2 EXPIRE_UPDATE_INTERVAL = 600

Defines the expiration time updating interval in seconds. The expiration time is not updated earlier
than $last_update_time + EXPIRE_UPDATE_INTERVAL.

=cut

use constant MAX_RANDOM_ID => 4294967295; # unsigned int maximum value (SQL-92 standard)
use constant EXPIRE_TIME => 36000; # 10 hours in seconds. The wizard temporary data expires at $wizard_access_time + EXPIRE_TIME
use constant EXPIRE_UPDATE_INTERVAL => 600; # 10 miuntes in seconds. The expiration time is updated earliest at $last_update_time + EXPIRE_UPDATE_INTERVAL

=pod

=head1 METHODS

=head2 new( HASH )

The constructor. The object parameters can be given in the argument hash.

Parameters:

=over 4

=item B<pages> I<array of objects>

=back

=cut

sub new {
	my ($class, %args) = @_;
	my $config = { };
	my $self = bless( $config, $class );

	# Initialization is handled in _init because we want our object to be
	# easily inheritable.
	$self->_init( \%args );

	return $self;
} 

=pod

=cut

sub _init {
	my ( $self, $args ) = @_;

	$self->_random_id( CTX->request->param('dicole_wizard_random_id') || 0 ); # get the wizard_id from apache
	$self->_current_page( CTX->request->param('dicole_wizard_page_number') || 0 ); # get the page from apache
	$self->pages( $args->{pages} ); # set the arrayref of page objects
        $self->hidden_fields( $args->{hidden_fields} );
        $self->cancel_redirect( $args->{cancel_redirect} );
        $self->_page_id_counter( 0 );

	# fetch all the data that's related to this wizard instance from database 
	$self->_fetch_data();
}

=pod

=head2 pages( [ARRAY] )

Sets/returns the page array reference. Unless the argument is defined, the
page array is unaltered.

=cut

sub pages {
	my ( $self, $pagesref ) = @_;
	
	$self->{pages} = $pagesref if( ref $pagesref eq 'ARRAY' );
	$self->{pages} = [] unless( ref $self->{pages} eq 'ARRAY' );
	
	return $self->{pages};
}

=pod

=head2 add_page_object( OBJECT )

Pushes a page object in the end of the page array.

=cut

# adds a pregenerated page object
sub add_page_object {
	my ( $self, $page_obj ) = @_;
	push @{ $self->{pages} }, $page_obj if( ref($page_obj) =~ /^Dicole::Generictool::Wizard::Page/ ); # all the page classes should be named Dicole::Generictool::Wizard::Page::*
}

=pod

=head2 add_page( HASH )

Creates a new L<Dicole::Generictool::Wizard::Page|Dicole::Generictool::Wizard::Page> object
and passes the given arguments to the constructor. The created page object is pushed in the
end of the page array.

=cut

# generates,adds and returns a new Page object
sub add_page {
	my ( $self, %page_args ) = @_;
	my $new_page = Dicole::Generictool::Wizard::Page->new( 
		wizard_id => $self->_random_id(), 
		page_number => $self->page_count() + 1,
                page_id => $self->next_page_id(),
		%page_args 
	);
	push @{$self->{pages}}, $new_page;
	return $new_page;
}

=pod

=head2 add_page_switch( HASH )

Creates a new L<Dicole::Generictool::Wizard::Page::Switch|Dicole::Generictool::Wizard::Page::Switch> object
and passes the given arguments to the constructor. The created page object is pushed in the
end of the page array.

=cut

# adds a Page::Switch object in the end of the page array
sub add_page_switch {
	my ( $self, %page_args ) = @_;
	my $new_page = Dicole::Generictool::Wizard::Page::Switch->new(
		wizard_id => $self->_random_id(), 
		page_number => $self->page_count() + 1,
                page_id => $self->next_page_id(),
		%page_args 
	);
	push @{$self->{pages}}, $new_page;
	return $new_page;
	
}

=pod

=head2 add_advanced_select_page( HASH )

Creates a new L<Dicole::Generictool::Wizard::Page::AdvancedSelect|Dicole::Generictool::Wizard::Page::AdvancedSelect> object
and passes the given arguments to the constructor. The created page object is pushed in the
end of the page array.

=cut

sub add_advanced_select_page {
	my ( $self, %page_args ) = @_;
	my $new_page = Dicole::Generictool::Wizard::Page::AdvancedSelect->new(
		wizard_id => $self->_random_id(), 
		page_number => $self->page_count() + 1,
                page_id => $self->next_page_id(),
		%page_args 
	);
	push @{$self->{pages}}, $new_page;
	return $new_page;
	
}

=pod

=head2 add_select_page( HASH )

Creates a new L<Dicole::Generictool::Wizard::Page::elect|Dicole::Generictool::Wizard::Page::Select> object
and passes the given arguments to the constructor. The created page object is pushed in the
end of the page array.

=cut

sub add_select_page {
	my ( $self, %page_args ) = @_;
	my $new_page = Dicole::Generictool::Wizard::Page::Select->new(
		wizard_id => $self->_random_id(), 
		page_number => $self->page_count() + 1,
        page_id => $self->next_page_id(),
		%page_args 
	);
	push @{$self->{pages}}, $new_page;
	return $new_page;
	
}

=pod

=head2 add_info_page( HASH )

Creates a new L<Dicole::Generictool::Wizard::Page::Info|Dicole::Generictool::Wizard::Page::Info> object
and passes the given arguments to the constructor. The created page object is pushed in the
end of the page array.

=cut

sub add_info_page {
	my ( $self, %page_args ) = @_;
	my $new_page = Dicole::Generictool::Wizard::Page::Info->new(
		wizard_id => $self->_random_id(), 
		page_number => $self->page_count() + 1,
                page_id => $self->next_page_id(),
		%page_args 
	);
	push @{$self->{pages}}, $new_page;
	return $new_page;
	
}


=pod

=head2 page_count()

Returns the number of pages in the page array.

=cut

sub page_count {
	my $self = shift;
	return scalar @{ $self->pages() };
}

=pod

=head2 has_more_pages()

Returns false if current wizard page exceeds the total page count. Otherwise
returns true.

=cut

sub has_more_pages {
	my $self = shift;
	return $self->_current_page() < $self->page_count();
}

=pod

=head2 finished()

Returns true if wizard hasn't any more pages and the finish button was pressed.

=cut

sub finished {
	my $self = shift;
	return !$self->has_more_pages() && $self->_finish_button_pressed();
}

=pod

=head2 return_msg( [SCALAR, SCALAR] )

Sets/returns the error code & message. If the parameters are given, the first parameter sets
the return code, and the second sets the message.

=cut

sub return_msg {
	my ($self, $code, $value) = @_;
	( $self->{_return_code}, $self->{_return_msg} ) = ( $code, $value ) if( defined $code && defined $value );
	$self->{_return_code} = MESSAGE_SUCCESS unless( defined $self->{_return_code} );
	return ( $self->{_return_code}, $self->{_return_msg} );
}

### _fetch_data() must be called before calling this function
#sub _save_fields {
#	my $self = shift;
#	my $R = OpenInteract::Request->instance;
#	
#	foreach my $field ( @{ $self->CurrentPage()->fields() } ) {
#		# get old object / create new (unless exists)
#		my $object = exists $self->_wizard_data()->{ $field->id() } ? 
#			$self->_wizard_data()->{ $field->id() } : $R->dicole_wizard_data->new();
#		
#		$object->{http_value} = $R->apache->param( $field->id() );
#		$object->save();
#	}
#}

#sub _validate_fields {
#	my $self = shift;
#	my $R = OpenInteract::Request->instance;
#	
#	my $validator =  Dicole::Generictool::Field::Validate->new();
#	
#	foreach my $field ( @{ $self->CurrentPage()->fields() } ) {
#		$validator->field( $field );
#		if( $field->type() eq 'password' ) { $validator->validate_password(); }
#		elsif( $field->type() eq 'date' )  { $validator->validate_date(); }
#		else                               { $validator->validate_default(); }
#		$validator->check_required();
#		
#		my $error = $validator->error_msg();
#		$self->_error_msg( $error ) if( $error );
#	}
#	
#	return $self->_error_msg() ? 0 : 1;
#}

=pod

=head2 activate()

This method must be called after initializing the wizard. The method saves the
temporary data in database, validates user input, moves to next/previous page
according to user actions, and activates the new current page.

=cut

sub activate {
	my $self = shift;

	# activated only once
	return if $self->_active();
	$self->_active(1);
	
	# check for invalid initialization variables
	$self->_current_page(0) if( $self->_current_page() >= $self->page_count() );

	# check if any buttons were pressed, and react
	return $self->_cancel_wizard if( $self->_cancel_button_pressed );
	
	my( $next, $prev, $finish ) = ( $self->_next_button_pressed, $self->_previous_button_pressed, $self->_finish_button_pressed );
	
	if( $next || $prev || $finish ) {
		$self->CurrentPage()->wizard_data( $self->_wizard_data() );
		$self->CurrentPage()->validate_fields();
		unless( $self->CurrentPage()->Validator()->error_msg() ) {
			$self->CurrentPage()->save_fields();
			$self->_current_page( $self->_current_page()+1 ) if( $next || $finish );
			$self->_current_page( $self->_current_page()-1 ) if( $prev );
		}
		else { $self->return_msg( MESSAGE_ERROR, $self->CurrentPage()->Validator()->error_msg() ); }
	}

	if( $self->has_more_pages() ) {
		# Send the wizard db data to the current page, figure out which buttons are to be shown, and activate the page
		$self->CurrentPage()->wizard_data( $self->_wizard_data() );
		$self->CurrentPage()->hidden_fields( $self->hidden_fields );
		$self->CurrentPage()->page_number( $self->_current_page() );
		$self->CurrentPage()->page_count( $self->page_count() );

		$self->CurrentPage()->use_button_previous(1) if( $self->_current_page() > 0 );
		$self->CurrentPage()->use_button_next(1) if( $self->_current_page() < $self->page_count() - 1 );
		$self->CurrentPage()->use_button_finish(1) if( $self->_current_page() == $self->page_count() - 1 );
		$self->CurrentPage()->use_button_cancel(1) if( $self->cancel_redirect() );

		$self->CurrentPage()->activate();
	}
}

=pod

=head2 CurrentPage()

Returns the currently shown page object.

=cut

sub CurrentPage {
	my $self = shift;
	return $self->pages()->[ $self->_current_page() ];
}

=pod

=head2 Results( [SCALAR] )

Returns the result handler. Unless the handler is initialized, a new
L<Dicole::Generictool::Wizard::Results|Dicole::Generictool::Wizard::Results> object
is created. The developer can provide a custom class name as argument if he/she wants
to set a custom result handler class.

=cut

sub Results {
	my ( $self, $class ) = @_;
	if ( defined $class ) {
		$self->{_Results} = $class->new;
	}
	unless ( ref $self->{_Results} ) {
		$self->{_Results} = Dicole::Generictool::Wizard::Results->new;
	}
	return $self->{_Results};
}

=pod

=head2 results( [HASH] )

Returns the wizard result hash. The hash contains an element for each of the fields in the
wizard pages. The data the hash element contains depends on the type of the field. After
processing the results, the method clears the temporary wizard data from the database. This
behaviour can be changed with the optional arguments.

Optional arguments can be given to the results()-function:

=over 4

=item B<no_data_clearing> I<true/false>

=back

=cut

sub results {
	my ($self, %options) = @_;

	my $results = {};
	$self->Results()->wizard_data( $self->_wizard_data() );

	foreach my $page ( @{ $self->pages() } ) {
		$page->wizard_data( $self->_wizard_data() );
		foreach my $field ( @{ $page->fields() } ) {
			$self->Results()->field( $field );
			
			my $method =  $self->Results()->can( 'results_' . $field->type() );
			$results->{ $field->id() } = $method ?
				$self->Results()->$method : $self->Results()->results_default();
		}
	}
	$self->_clear_wizard_data() unless( $options{no_data_clearing} );
	
	return $results;
}

=pod

=head2 apply_to_tool( [REF] )

Regenerates referenced Tool's boxes and places wizards data into them.
Sets tools form action to current task (strips parameters).

Returns the modified tool reference.

=cut

sub apply_to_tool {
    my ( $self, $tool ) = @_;

    my $content = $self->CurrentPage->content;
    my $name = $self->CurrentPage->name;

    $tool->Container->generate_boxes( 1, scalar(@$content) );

    for (my $i=0; $i < scalar(@$content); $i++) {
    
        $tool->Container->box_at( 0, $i )->name( $name->[$i] );
        $tool->Container->box_at( 0, $i )->add_content( $content->[$i] );
   }

    $tool->add_message( $self->return_msg );

    # Required so that there are no ?params in the post url which would
    # cause wizard id to be posted twice ;)
    $tool->form_params->{action} = Dicole::URL->create_from_current;

    return $tool;
}

=pod

=head2 next_page_id()

Adds one to _page_id_counter and returns the new count.

=cut

sub next_page_id {
	my $self = shift;
        return $self->_page_id_counter( $self->_page_id_counter + 1 );
}

=pod

=head1 PRIVATE METHODS

=head2 _random_id_2_user_id( SCALAR )

Finds the user id corresponding to the given wizard id. 
First checks if the given wizard_random_id exists in the wizard temporary db table.
If it exists, and the wizard instance with the given id has not expired, returns 
the corresponding user_id. Else returns undef.

=cut

#### First checks if the given random_id exists in the wizard temporary db.
#### If it exists, returns the corresponding user_id. Else returns undef
sub _random_id_2_user_id {
	my ( $self, $random_id ) = @_;

	my $obj = $self->_fetch_wizard_instance_object( $random_id );
	if( $obj && $obj->{expire_time} >= time() ) { return $obj->{user_id}; }
	else                                        { return undef; }
}

=pod

=head2 _register_random_id( SCALAR )

Inserts a new dicole_wizard -object with the given id to the database. When
registered, other wizards can't use this given id. The new spops object is cached
to the internal object variables for later use.

=cut

sub _register_random_id {
	my ( $self, $random_id ) = @_;

	my $new_wizard = CTX->lookup_object( 'dicole_wizard' )->new();
	$new_wizard->{wizard_id} = $random_id;
	$new_wizard->{user_id} = CTX->request->auth_user_id;
	$new_wizard->{expire_time} = time() + EXPIRE_TIME;
	$new_wizard->save();
	
	$self->_wizard_instance_object( $new_wizard );
}

=pod

=head2 _random_id_exists( SCALAR )

Returs true if there already is a wizard with the given id. Otherwise returns false.

=cut

sub _random_id_exists {
	my ( $self, $random_id ) = @_;
	return $self->_random_id_2_user_id( $random_id );
}

=pod

=head2 _user_can_use_random_id( SCALAR )

Checks if the current user can use the given wizard id. The wizard id can be
used only if the wizard instance with the given id belongs to the current user.

=cut

sub _user_can_use_random_id {
	my ( $self, $random_id ) = @_;

	#### User can use some random_id if the user_id corresponding to given random_id is equal to the user_id in this session
	return $self->_random_id_2_user_id( $random_id ) == CTX->request->auth_user_id;
}

=pod

=head2 _generate_random_id()

Generates, validates and finally returns an unused unique random wizard id. 
The current page is set to 0 (for example if the wizard instance has
expired, we'll have to start over).

=cut

#### Generates, validates and returns random number
sub _generate_random_id {
	my $self = shift;
	
	# initial random number
	my $id = int(rand(MAX_RANDOM_ID-1)+1); # must be >= 1, since 0 is reserved

	# Generate new random number until we get a unique one.
	# (WARNING: Althought it's very unlikely, INFINITE LOOP IS POSSIBLE! Perhaps we should build some
	# kind of fallback?)
	$id = int(rand(MAX_RANDOM_ID-1)+1) while( $self->_random_id_exists( $id ) ); 
	
	$self->_register_random_id( $id );
	$self->_current_page( 0 );
	return $id;
}

=pod

=head2 _random_id( [SCALAR] )

If the argument is defined, tries to use the given wizard id. If the given id is
empty or 0, or if the user is not allowed to use this id (wizard instance
expired, invalid id, or the wizard instance registered to another user),
a new wizard id is generated.

If the given wizard id can be used by the current user, the expiration time of
the wizard instance is updated.

Returns the wizard id.

=cut

sub _random_id {
	my( $self, $wizard_id ) = @_;

	if( defined $wizard_id ) {
		if( $wizard_id && $self->_user_can_use_random_id( $wizard_id ) ) { 
			$self->_update_expiration_time( $wizard_id );
		}
		else { # $wizard_id == 0 || '' , OR the user can't use the given id --> generate new
			$wizard_id = $self->_generate_random_id(); 
		}
		$self->{_random_id} = $wizard_id;
	}
	return $self->{_random_id};
}

=pod

=head2 _update_expiration_time( SCALAR )

Updates the expiration time of the wizard instance with the given id. The updating
is done only if sufficient time has elapsed since the last update.

=cut

sub _update_expiration_time {
	my ( $self, $wizard_id ) = @_;

	my $obj = $self->_fetch_wizard_instance_object( $wizard_id );
	if( $obj ) {
		my $last_update_time = $obj->{expire_time} - EXPIRE_TIME;
		my $current_time = time();
		
		if( $current_time - $last_update_time >= EXPIRE_UPDATE_INTERVAL ) {
			$obj->{expire_time} = $current_time + EXPIRE_TIME;
			$obj->save();
		}
	}
}

=pod

=head2 _fetch_wizard_instance_object( SCALAR )

Fetches the instance spops object of the wizard instance with the given id.
Caches the previously fetched object, and returns the cached version if 
the object with the same id is requested again.

=cut

sub _fetch_wizard_instance_object {
	my ( $self, $wizard_id ) = @_;

	my $ins_obj = $self->_wizard_instance_object();
	if( $ins_obj && $ins_obj->{wizard_id} == $wizard_id ) { return $ins_obj; }
	else {
		return $self->_wizard_instance_object( CTX->lookup_object('dicole_wizard')->fetch( $wizard_id ) );
	}
}

=pod

=head2 _fetch_data()

Fetches all the data related to this wizard instance from the database. The data can be accessed with
$self->_wizard_data() -method after calling this method.

The data is stored into a hash which has the http_name of the various objects as its key, and the spops
object as its value. If there are multiple spops objects with the same http_name (used in checkbox lists etc),
an anonymous array is created for that hash key, and the http_name points to an array which contains all the 
corresponding spops objects.

=cut

sub _fetch_data {
	my $self = shift;
	
	my $data = CTX->lookup_object('dicole_wizard_data')->fetch_group( { where => 'wizard_id = ?', value => [ $self->_random_id() ] } );
	#my %datahash = map { $_->{http_name}, $_  } @{ $data }; # make a hash of $http_name => $spops_object -pairs
	my %datahash;
	foreach my $obj ( @{ $data } ) {
		unless( exists $datahash{ $obj->{http_name} } ) {
			$datahash{ $obj->{http_name} } = $obj;
		}
		else {
			# Unless the hash element already is an array, create a new array with the spops object stored in the hash as its first element
			$datahash{ $obj->{http_name} } = [ $datahash{ $obj->{http_name} } ] 
				unless( ref $datahash{ $obj->{http_name} } eq 'ARRAY' );
			push @{ $datahash{ $obj->{http_name} } }, $obj;
		}
	}

	$self->_wizard_data( \%datahash );
	return $self->_wizard_data();
}

=pod

=head2 _next_button_pressed()

Returns true if the Next button was pressed.

=cut

sub _next_button_pressed {
	my $self = shift;
	return CTX->request->param('dicole_wizard_next_button') ? 1 : 0;
}

=pod

=head2 _previous_button_pressed()

Returns true if the Previous button was pressed.

=cut

sub _previous_button_pressed {
	my $self = shift;
	return CTX->request->param('dicole_wizard_previous_button') ? 1 : 0;
}

=pod

=head2 _cancel_button_pressed()

Returns true if the Cancel button was pressed.

=cut

sub _cancel_button_pressed {
	my $self = shift;
	return CTX->request->param('dicole_wizard_cancel_button') ? 1 : 0;
}

=pod

=head2 _finish_button_pressed()

Returns true if the Finish button was pressed.

=cut

sub _finish_button_pressed {
	my $self = shift;
	return CTX->request->param('dicole_wizard_finish_button') ? 1 : 0;
}

=pod

=head2 _clear_wizard_data()

Removes all wizard data form db and releases the registered wizard id for others
to use.

=cut
## Removes all wizard data from db.

sub _clear_wizard_data {
	my $self = shift;
	
	foreach my $key ( keys %{ $self->_wizard_data } ) {
		# the elements stored in the wizard_data hash are either arrays of spops objects, or single spops objects:
		if( ref $self->_wizard_data()->{$key} eq 'ARRAY' ) {
			foreach my $obj ( @{ $self->_wizard_data()->{$key} } ) {
				$obj->remove();
			}
		}
		else { $self->_wizard_data()->{$key}->remove(); }
	}
	my $obj = CTX->lookup_object('dicole_wizard')->fetch( $self->_random_id() );
	$obj->remove();
}

=pod

=head2 _redirect_to( SCALAR )

Redirects the user to the given url.

=cut

sub _redirect_to {
	my ($self, $url) = @_;
	
	my ( $redir_class, $redir_method ) = CTX->lookup_action( 'redirect' );
	return $redir_class->$redir_method( { url => $url } );}

=pod

=head2 _cancel_wizard()

Clears the wizard data, and redirects to the page defined during wizard initialization.

=cut

sub _cancel_wizard {
	my $self = shift;
	$self->_clear_wizard_data();
	return CTX->response->redirect( $self->cancel_redirect );
}

=pod

=head1 SEE ALSO

L<Dicole|Dicole>, 
L<OpenInteract|OpenInteract>,
L<Dicole::Generictool::Field::Validate|Dicole::Generictool::Field::Validate>,
L<Dicole::Generictool::Field::Construct|Dicole::Generictool::Field::Construct>,
L<Dicole::Generictool::Wizard::Results|Dicole::Generictool::Wizard::Results>,
L<Dicole::Generictool::Wizard::Datasaver|Dicole::Generictool::Wizard::Datasaver>,
L<Dicole::Generictool::Wizard::Page|Dicole::Generictool::Wizard::Page>,
L<Dicole::Generictool::Wizard::Page::Switch|Dicole::Generictool::Wizard::Page::Switch>

=head1 AUTHOR

Hannes Muurinen, E<lt>hannes@ionstream.fiE<gt>

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

