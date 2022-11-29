package Dicole::Action;

# $Id: Action.pm,v 1.108 2010-07-20 15:49:43 amv Exp $

use strict;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use OpenInteract2::Exception qw( oi_error );
use OpenInteract2::I18N;
use Dicole::Tool;
use OpenInteract2::Config::Ini;
use File::Spec;
use Dicole::Utility;
use Time::HiRes qw/time/;

use Dicole::Widget::Link;
use Dicole::URL;
use Dicole::Utils::Localization;
use Dicole::Localization;
use Dicole::Utils::Trace;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.108 $ =~ /(\d+)\.(\d+)/);

# Make sure the user is not able to execute tasks in this class
our @INVALID_TASKS = qw(
    init_tool log init_fields active_group
    generate_tool_content tool gtool tool_role
    target_id target_additional target_user_id
    target_group_id language
    target_group target_user skip_secure
    secure_success secure_failure
    current_area
);

my $log = ();

=pod

=head1 NAME

Represent and dispatch actions in Dicole

=head1 SYNOPSIS

 use OpenInteract2::Context qw( CTX );
 use Dicole::Generictool;
 use base qw( Dicole::Action );

 sub view {
    $self->init_tool;
    $self->gtool( Dicole::Generictool->new(
        object => CTX->lookup_object('user') )
    );
    $self->gtool->current_view( 'view' );
    $self->init_fields( package => 'users' );
    $self->tool->Container->box_at( 0, 0 )->set_name( 'View user' );
    $self->tool->Container->box_at( 0, 0 )->add_content(
       $self->gtool->get_add
    );
    $self->generate_tool_content;
 }

=head1 DESCRIPTION

This class inherits L<OpenInteract2::Action> and adds methods useful when
writing applications with the Dicole platform. Dicole developers are encouraged
to inherit this class instead of L<OpenInteract2::Action> in their action
code.

=head1 NOTES

You may specify I<custom_init()> in your Action code. If it is specified,
it will be run before your task gets executed.

For example, in a file manager you might want to initialize the file management
object before a task is executed, because each task will be using file
management functions anyway. Another example is that if you want to initialize
the OpenInteract2 logger before any task is executed, this is where the
initialization could be done instead of in the beginning of each task.

=head1 INHERITS

This class is based on L<OpenInteract2::Action>.
See documentation of L<OpenInteract2::Action> for information about
other available methods not described here.

Inherits L<Class::Accessor|Class::Accessor>, which creates some accessors
for the class attributes.

Inherits L<Dicole::RuntimeLogger> and L<Dicole::Security::Checker>

=cut

use base qw( OpenInteract2::Action Class::Accessor Dicole::RuntimeLogger Dicole::Security::Checker );

=pod

=head1 ACCESSORS

=head2 tool( [OBJECT] )

Sets/gets the L<Dicole::Tool> object. The object is usually created by I<init_tool()>
and it is accessible through this accessor.

=head2 gtool( [OBJECT] )

Sets/gets the L<Dicole::Generictool> object. This is usually created in
the action code. I<init_fields()> uses this accessor by default to set
the field definitions.

=cut

Dicole::Action->mk_accessors( qw(
    tool gtool target_id target_user_id target_group_id
    target_additional language target_group target_user
    skip_secure secure_success secure_failure
) );

=pod

=head1 INHERITABLE TASKS

=head2 detect_tab()

Looks for tool tabs and selects the first one for which
securities match and forwards to that.

=cut

sub detect_tab {
    my ( $self, $p ) = @_;
    
    my $tool = Dicole::Tool->new(
        action => $self,
        no_tool_path => 1,
        title => 'temp',
    );
    
    return $self->redirect( $tool->Tabs->{_options}->[0]->{href} );
}

=pod

=head1 METHODS

=head2 generate_tool_content()

This method is called in the end of each task. It calls I<generate_content()>
with appropriate parameters retrieved from the L<Dicole::Tool> object.

=cut

sub generate_tool_content {
    my ( $self ) = @_;

    return $self->generate_content(
        $self->tool->generate_content_params
    );
}

sub generate_solo_content {
    my ( $self, %params ) = @_;

    CTX->controller->init_common_variables(
        head_widgets => $params{template_params}{head_widgets},
        footer_widgets => $params{template_params}{footer_widgets},
        end_widgets => $params{template_params}{end_widgets},
        title => $params{template_params}{title},
        %params,
    );

    return $self->generate_content(
        $params{template_params}, { name => $params{template_name} }
    );
}

sub generate_content {
    my ( $self, @params ) = @_;

    $self->rlog('Action generate content');
    my $return = $self->SUPER::generate_content( @params );
    $self->rlog('Action generate content');

    return $return;
}

=pod

=head2 log( STRING, STRING )

Logs a message. Accepts the log level (I<debug, info, warn, error and fatal>)
as the first parameter and the log message as the second parameter.

=cut

sub log {
    my ( $self, $log_method, $log_message ) = @_;
    $log ||= get_logger( LOG_APP );
    my $is_log_method = 'is_' . $log_method;
    $log->$is_log_method() && $log->$log_method( $log_message );
}

=pod

=head2 init_tool( [HASH] )

Initializes the L<Dicole::Tool> object, generates the tool container with some boxes
and sets the I<tool()> property based on provided parameters.

Accepts the following parameters as a hash:

=over 4

=item B<tool_args> I<hashref>

Additional arguments to L<Dicole::Tool>.

=item B<cols> I<boolean>

Number of columns in the container.

Default is 1.

=item B<rows> I<boolean>

Number of rows in the container.

Default is 1.

=item B<tab_override> I<string>

The name of the task which tab will be active instead of trying to active
tab for the current task, which is default.

=item B<title> I<string>

The page title.

=item B<upload> I<boolean>

Defines that this form will include upload fields, which means L<Dicole::Tool> has
to set I<multipart/form-data> as the encoding type of the form.

=back

=cut


# TODO: move init_tool, init_fields and init_feeds to Tool istead of Action

sub init_tool {
    my ( $self, $args ) = @_;
    $args = {} unless ref( $args ) eq 'HASH';
    $args->{tool_args} = {} unless ref ( $args->{tool_args} ) eq 'HASH';

    $args->{cols} ||= 1;
    $args->{rows} ||= 1;

    # Create new Tool object
    my $tool = Dicole::Tool->new(
        action => $self,
        no_tool_path => 1,
        tab_override => $args->{tab_override},
        title => $args->{title},
        form_params => {
            name => 'Form',
            method => 'post',
            ( $args->{upload} ) ? ( enctype => 'multipart/form-data' ) : undef,
        },
        %{ $args->{tool_args} }
    );

    if ( ref( $tool->feeds ) eq 'ARRAY' ) {
        $tool->add_head_widgets(
            Dicole::Widget::Link->new(
                rel => "alternate",
                type => "application/rss+xml",
                title => $_->{rss_desc},
                href => $_->{rss_url},
            )
        ) for @{ $tool->feeds };
    }
    
    # Create new container of size rows x columns
    $tool->Container->generate_boxes( $args->{cols}, $args->{rows} );

    $self->tool( $tool );
}

# this should be renamed to init_feed ?
sub init_feeds {
    my ( $self, %p ) = @_;

    %p = (
        additional => [],
        action => '',
        task => 'feed',
        rss_type => 'rss10',
        rss_desc => $self->_msg( 'Syndication feed (RSS 1.0)' ),
        dicole_type => 'sub',
        dicole_desc => $self->_msg( 'Subscribe with feed reader' ),
        additional_file => 'feed.rdf',
        %p,
    );


    my $additional = [ $self->language ];
    push @$additional, @{ $p{additional} } if scalar @{ $p{additional} };
    push @$additional, $p{additional_file} if $p{additional_file};

    my $info = {
        lang => $self->language,

        rss_type => $p{rss_type} || 'rss10',
        rss_desc => $p{rss_desc} || $self->_msg( 'Syndication feed (RSS 1.0)' ),
        rss_url => $self->derive_url(
                $p{action} ? ( action => $p{action} ) : (),
                task => $p{task},
                additional => $additional,
        ),
    };

    # Disabled because personal feedreader is being phased out
    if ( 0 && $self->mchk_y(
            'OpenInteract2::Action::DicoleFeedreader',
            'user_manage',
            CTX->request->auth_user_id ) ) {

        $info = {
            %$info,

            dicole_type => $p{dicole_type} || 'sub',
            dicole_desc => $p{dicole_desc} || $self->_msg( 'Subscribe with feed reader' ),
            dicole_url => Dicole::URL->create_from_parts(
                action => 'personal_feed_reader',
                task => 'add',
                target => CTX->request->auth_user_id,
                params => {
                    discovered_url => $self->derive_url(
                        $p{action} ? ( action => $p{action} ) : (),
                        task => $p{task},
                        additional => $additional,
                    )
                },
            ),
        };

    };

    return [ $info ];
}

sub derive_feedreader_ping {
    my ( $self, %p ) = @_;

    %p = (
        task => 'feed',
        additional => [],
        %p,
    );
    
    # TODO: This should be defined in the server.ini file..?
    my @languages = qw/ en fi /;
    
    for ( @languages ) {
        my $additional = [ $_ ];
        push @$additional, @{ $p{additional} } if scalar @{ $p{additional} };
        push @$additional, 'feed.rdf';
        my $feed_uri = $self->derive_url(
            %p,
            additional => $additional,
        );
        
        eval { CTX->lookup_action('feedreader_ping')->execute( {
            feed_uri => $feed_uri
        } ) };
    }
}


=pod

=head2 init_fields( HASH )

Adds Generictool fields from a I<conf/fields.ini> located in a certain package
to a specified Generictool object.

Accepts the following parameters as a hash:

=over 4

=item B<gtool> I<object>

The generictool object.

The default is the object available through class attribute accessor I<gtool()>.

=item B<view> I<string>

The Generictool view for which the fields will be retrieved from the configuration.

The default is the return value of I<current_view()> method in the Generictool object.

=item B<package> I<string>

The name of the package where the I<fields.ini> is located. You have to provide
this parameter, at least.

=back

Here is an example of the I<fields.ini> configuration syntax:

 [views list]
 fields         = user_title
 fields         = user_fullname
 fields         = user_category
 fields         = user_description
 no_sort        = title
 no_search      = title
 disable_browse = 1
 disable_sort   = 0
 disable_search = 0
 default_sort   = category

 [fields user_title]
 id       = title
 desc     = Title
 type     = textfield
 localize = 1
 required = 1

 [fields user_category]
 id   = category
 desc = Category
 type = dropdown
 localize_dropdown = 1

 [dropdown user_category]
 content = Collection
 value   = col
 content = Dataset
 value   = data
 content = Event
 value   = event

 # Username in form of "last_name, first_name"
 [fields user_fullname]
 id              = user_name
 object_field    = user_id
 relation        = user
 relation_fields = last_name
 relation_fields = first_name
 relation_field_separator = ,

 [fields user_description]
 id   = desc
 desc = Description
 type = textarea

 [fields user_password]
 id       = password
 type     = password
 required =
 desc     = Password
 options  = initial_password

 [options initial_password]
 confirm      = 1
 confirm_text = Verify password

In this example you can see that you have to define each view
with I<[views X]>, where X is the view you want to specify.

Here is a description of view parameters:

=over 4

=item B<fields> I<string>

Each view definition has multiple instances of parameter I<fields>,
which defines all field keys that will be present in the specified view.
Notice that the field key you have to specify here is the field key,
not field id.

=item B<no_sort> I<string>

Field ids that are not sortable. Notice that here you have to use the
field id, not the field key.

=item B<no_search> I<string>

Field ids that are not searchable. Notice that here you have to use the
field id, not the field key.

=item B<disable_browse> I<boolean>

Disables browsing functionality in Generictool, which means that all
items will appear on a single page.

=item B<disable_search> I<boolean>

Disables searching functionality in Generictool.

=item B<disable_sort> I<boolean>

Disables sorting functionality in Generictool.

=item B<default_sort> I<string>

Field id which will be used to sort the list view by default.
Notice that here you have to use the field id, not the field key.
Optionally accepts the sort order as part of the string. See examples:

  default_sort = user_name
  default_sort = user_name DESC
  default_sort = user_name ASC

=back

Then you have to define all the fields that are available in your tool
with I<[fields X]>, where X is the field key to specify.

For available field attributes, see documentation of L<Dicole::Generictool::Field>.

A special case in the configuration is for specifying dropdown elements and
field specific options (see the example).

With dropdowns you specify initial dropdown elements with I<[dropdown X]>, where X
is the field key for which you will specify the dropdown elements. You specify multiple
instances of I<content> and I<value> parameters, where content is the visible text in the dropdown
and value is the actually submitted one which will be saved in the SPOPS object by
Generictool.

If dropdown field has I<localize_dropdown> specified as true, the dropdown content values will be
run through the localization framework.

In I<options> parameter for the field you specify an options key, which will be used to retrieve
the custom options for your field. You specify the custom options with I<[options X]>, where X
is the options key.

=cut

# TODO: horribly big-one.. split into pieces. Also concider moving this elsewhere ;)

sub init_fields {
    my $self = shift;

    my $p = {
        gtool => undef,
        defaults => {},
        package => $self->param( 'package_name' ),
        view => undef,
        @_
    };

    $p->{gtool} ||= $self->gtool;
    $p->{package} ||= $self->package_name; # XXX: this is the CVS oi way..

    return unless $p->{package} && $p->{gtool};

    unless ( $p->{view} ) {
        if ( $p->{gtool}->current_view ) {
            $p->{view} = $p->{gtool}->current_view;
        }
        else {
            $p->{view} = ( caller( 1 ) )[3];
            $p->{view} =~  s/.*\:\://;
        }
    }

    return unless $p->{view};

    my $inifile = File::Spec->catfile(
        CTX->repository->full_config_dir, $p->{package}, 'fields.ini'
    );

    unless ( $inifile ) {
        get_logger( LOG_ACTION )->error( sprintf(
            'Unable to find conf/fields.ini in package %s',
            $p->{package}
        ) );
        return undef;
    }

    my $ini = OpenInteract2::Config::Ini->new( { filename => $inifile } );

    # check for requested [fields $p->{view} *]
    if ( exists $ini->{views}{$p->{view}} ) {

        my $ini_view = $ini->{views}{$p->{view}};
        my $active_fields = Dicole::Utility->make_array( $ini_view->{fields} );
        my @active_field_ids = map { $ini->{fields}{$_}{id} } @$active_fields;

        # get fields
        foreach my $key ( @{ $active_fields } ) {

            # Find the current field in fields hash
            my $field_keys = $ini->{fields}{$key};

            # Add default || try to eval the value if =~ /::/

            if ( exists $p->{defaults}{$key} ) {

                $field_keys->{value} = $p->{defaults}{$key};
            }
            elsif ( $field_keys->{value} =~ /::/ ) {

                my $value = $field_keys->{value};
                $field_keys->{value} = eval $value;
                $field_keys->{value} = $value if $@;
            }

            # Translation
            $field_keys->{desc} = $self->_msg( $field_keys->{desc} )
                if $field_keys->{desc};
            $field_keys->{empty_text} = $self->_msg( $field_keys->{empty_text} )
                if $field_keys->{empty_text};

            # If relation fields exists, make an arrayref of them
            if ( $field_keys->{relation_fields} ) {
                $field_keys->{relation_fields} = Dicole::Utility->make_array(
                    $field_keys->{relation_fields}
                );
            }

            # Add field to GenericTool object
            my $field = $p->{gtool}->add_field( %{ $field_keys } );

            # If field type is dropdown, we look for [dropdown $Field->id]
            # for dropdown items. Dropdown items are in the following format
            # in the ini file:
            # content = Content1
            # value   = Value1
            # content = Content2
            # value   = Value2
            # ... which creates an array for content and value
            if ( $field_keys->{type} eq 'dropdown' ) {
                next unless exists $ini->{dropdown}{ $key };
                my $dropdown = $ini->{dropdown}{ $key };
                my $options = [];
                my $dropdown_values = Dicole::Utility->make_array( $dropdown->{value} );
                my $dropdown_contents = Dicole::Utility->make_array( $dropdown->{content} );
                for ( my $i = 0; $i < @{ $dropdown->{content} }; $i++ ) {

                    my $tval = $dropdown_values->[$i];

                    # Try to evaluate value if it seems like a function call

                    if ( $tval =~ /::/ ) {
                        $tval = eval $tval;
                        $tval = $dropdown_values->[$i] if $@;
                    }

                    my $content = $dropdown_contents->[$i];
                    $content = $self->_msg( $content ) if $field_keys->{localize_dropdown};

                    push @{ $options }, {
                        attributes => { value => $tval },
                        content => $content
                    };
                }
                # Assign options to dropdown
                $field->options( { options => $options } );
            }
            # If field has options specified, we look for [options $options]
            # $options is the value of options field parameter in the config
            elsif ( defined $field_keys->{options}
                && $ini->{options}{ $field_keys->{options} }
            ) {
                $field->options( $ini->{options}{ $field_keys->{options} } );
                if ( $field->options->{htmlarea} ) {
                    CTX->controller->add_content_param( 'htmlarea', 1 );
                }
            }
        }

        $p->{gtool}->disable_sort( $ini_view->{disable_sort} );
        $p->{gtool}->disable_search( $ini_view->{disable_search} );
        $p->{gtool}->disable_browse( $ini_view->{disable_browse} );
        if ( $ini_view->{default_sort} ) {
            my $column = $ini_view->{default_sort};
            my $order = 'ASC';
            ( $column, $order ) = split / /, $column if $column =~ / /;
            $order = 'DESC' unless $order eq 'ASC';
            $p->{gtool}->Sort->default_sort( {
                column => $column, order => $order
            } );
        }

        unless ( $p->{gtool}->disable_sort ) {
            $p->{gtool}->Sort->sortable( \@active_field_ids );
            $p->{gtool}->Sort->del_sortable(
                Dicole::Utility->make_array( $ini_view->{no_sort} )
            );
        }
        unless ( $p->{gtool}->disable_search ) {
            $p->{gtool}->Search->searchable( \@active_field_ids );
            $p->{gtool}->Search->del_searchable(
                Dicole::Utility->make_array( $ini_view->{no_search} )
            );
        }

        # set fields
        $p->{gtool}->visible_fields( $p->{view}, \@active_field_ids );

    } else {
        get_logger( LOG_ACTION )->error( sprintf(
            'View [%s] is not defined in conf/fields.ini',
            $p->{view}
        ) );
        return undef;
    }
    return 1;
}

=pod

=head2 execute()

Executes the task.

This an inherited and overridden method from L<OpenInteract2::Action>.

Adds the following functionality:

=over 4

=item *

redirects the user to login page if the user is not logged in

=item *

redirects the user to default task if no task was provided for the action

=item *

sets CTX->{active_group} to provided group id (see documentation of I<_find_group_id()>)

=item *

calls task I<custom_init()> in the action if I<custom_init()> exists

=back

=cut

sub e { shift->execute( @_ ) }

sub execute {
    my ( $self, $task, $params ) = @_;

    if ( ref $task eq 'HASH' ) {
        $params = $task;
    }
    elsif ( $task ) {
        $self->task( $task );
    }

    my $rlog_name = 'Action execute: ' . $self->name . '::' . $self->task;

    my $trace = Dicole::Utils::Trace->start_trace($rlog_name);

    # make sure the user is not able to execute tasks in this class

    my $invalid_tasks = $self->task_invalid || [];
    push @{ $invalid_tasks }, @INVALID_TASKS;
    $self->task_invalid( $invalid_tasks );


    if ( $self->can( 'custom_init' ) ) {
        if ( ref( $params ) eq 'HASH' && $params->{custom_init_params} ) {
            $self->custom_init( $params->{custom_init_params} );
        }
        else {
            $self->custom_init()
        }
    }

    my $return = $self->SUPER::execute( $params );

    Dicole::Utils::Trace->end_trace($trace);

    return $return;
}

# Override task error to actually die and not warn yet.
# The controller knows what to do and how to log
sub _task_error_content {
    my ( $self, $error, $task_info ) = @_;

    die $error;
}

# Override this so that default OI2 execute does not override
# additional from CTX->request

sub _get_url_additional_names {
    my ( $self, $actually_do_it ) = @_;

    return () if !$actually_do_it;

    return $self->SUPER::_get_url_additional_names;
}


# Override _check_task_validity to return true if
# task came from the "method" accessor.

# This might be OI2 commitable

sub _check_task_validity {
    my ( $self, @p ) = @_;

    return if $self->method && $self->method eq $self->task;

    return $self->SUPER::_check_task_validity( @p );
}

# Override the security checking method to use our securities

sub _check_security {
    my ( $self ) = @_;

    if ( $self->skip_secure ) {
        return;
    }

    if ( CTX && CTX->request && CTX->request->param('dix') ) {
        # TODO: here a security bypassing infrastructure based on url params :P
    }

    if ( my $secure = $self->param( 'secure' ) ) {

        my $security = $secure->{ $self->task };
        $security = $secure->{default} unless defined $security;
        $security = [ $security ] if $security && ref $security ne 'ARRAY';

        if ( ! $security || ! scalar( @$security ) ) {
            return;
        };

        $self->secure_success( [] );
        $self->secure_failure( [] );

        foreach my $sec ( @$security ) {

            if ( $self->schk_y( $sec ) ) {
                push @{ $self->secure_success }, $sec;
            }
            elsif ( $self->schk_n( $sec ) ) {
                push @{ $self->secure_failure }, $sec;
            }
        }

        if ( ! scalar @{ $self->secure_success } ||
               scalar @{ $self->secure_failure } ) {
            
            if ( $self->param('secure_failure') eq 'summary' ) {
                die;
            }

            die "security error";
        }
    }
}

=pod

=head2 redirect()

Forwards the request to the given url and terminates execution
of the action (dies with "redirect")

=cut
sub redirect {
    my ( $self, $url ) = @_;

    CTX->response->redirect( $url );

    die "redirect";
}


=pod

=head2 language_handle()

Determines and returns the language handle
=cut


sub language_handle {
    my ( $self, $value ) = @_;

    if ( defined $value ) {
        return $self->{language_handle} = $value;
    }

    if ( ! $self->{language_handle} ) {
        if ( $self->language ) {
            $self->{language_handle} = OpenInteract2::I18N->get_handle(
                $self->language
            );
        }
        elsif ( CTX->request && CTX->request->language_handle ) {
            $self->{language_handle} = CTX->request->language_handle;
        }
        else {
            # Fall back to 'en' if everything else fails
            # we should probably log an error here
            $self->{language_handle} = OpenInteract2::I18N->get_handle( 'en');
        }
    }

    return $self->{language_handle};
}


# Override this to use the handle present in action, not in request
# Also add the domain specific stuff :)

sub _msg {
    my ( $self, $key, @args ) = @_;

    return Dicole::Utils::Localization->translate( { action => $self }, $key, @args );
}

sub _nmsg {
    my ( $self, @args ) = @_;

    return Dicole::Utils::Localization->ntranslate( { action => $self }, @args );
}

sub _ncmsg {
    my ( $self, @args ) = @_;

    my ( $k, $pk, $c, @other ) = @args;

    if ( ! $pk || ref $pk ) {
        unshift @other, $c;
        $c = $pk;
        $pk = '';
    }    

    return Dicole::Utils::Localization->ntranslate( $c, $k, $pk || (), @other );
}

# Assign a new language from the first additional url part

sub _shift_additional_language {
    my ( $self ) = @_;

    # Previous language handle must be cleared for this to take effect
    undef $self->{language_handle};

    my $additional = $self->target_additional || [];
    my $lang = shift @$additional;
    $self->language( $lang ) if $lang;
}


=pod

=head2 derive_url( [HASH] )

Creates a new url based on this action. does not include params & anchor.

=cut


sub derive_url {
    my ( $self, %params ) = @_;

    return Dicole::URL->create_from_action(
        from_action => $self,
        %params
    );
}
=pod

=head2 derive_full_url( [HASH] )

Creates a full (including params & anchor) new url based on this action.

=cut


sub derive_full_url {
    my ( $self, %params ) = @_;

    return Dicole::URL->create_full_from_action(
        from_action => $self,
        %params
    );
}



=pod

=head2 active_group()

A read-only accessor for the action to retrieve the active group.
DEPRECATED. use CTX->request->active_group

=cut

sub active_group {
    my ( $self ) = @_;
    return CTX->request->active_group;
}

=pod

=head2 current_area()

A read-only accessor that returns hashref structure of
the current area.

=cut

sub current_area {
    my ( $self ) = @_;

    my $params = $self->param('area');
    my $area = {};

    # Defaults from action configuration
    if ( ref( $params ) eq 'HASH' ) {
        $area->{$_} = $params->{$_} for ( qw/ name url disable_visit / );
    }

    if ( ! $params->{disable_target_name} ) {
        if ( $self->param('target_type') eq 'group' &&
            $self->param('target_group') ) {

            my $g = $self->param('target_group');
            $area->{banner} = CTX->lookup_action('groups_api')->e( banner_for_group => { group => $g } );
            $area->{name} = $g->name;
            $area->{url} = $self->derive_url(
                action => 'groups',
                task => 'starting_page',
                target => $g->id,
                additional => [],
            );
        }
        elsif ( $self->param('target_type') eq 'user' &&
            $self->param('target_user') ) {

            my $u = $self->param('target_user');
            $area->{name} = $u->first_name . ' ' . $u->last_name;
            $area->{url} = $self->derive_url(
                action => 'personal_weblog',
                task => 'posts',
                target => $u->id,
                additional =>  [],
            );
        }
        else {
            $area->{name} = $self->_msg( $area->{name} ) if $area->{name};
        }
    }
    else {
        $area->{name} = $self->_msg( $area->{name} ) if $area->{name};
    }

    $area->{disable_visit} = 1 unless $area->{url};
    $area->{name} = $self->_msg('Undefined area') unless $area->{name};

    return $area;
}


# XXX: These should be committed to OI2 - when we reach a conclusion
# That request is not mandatory for action execution
# These are basically copies from OI2::Action with check for
# CTX->request existence added.

sub _is_using_cache {
    my ( $self ) = @_;
    my $expire = $self->cache_expire;
    unless ( ref $expire eq 'HASH' ) {
        return;
    }

    # do not cache admin requests
    return undef if ( CTX->request && CTX->request->auth_is_admin );

    my $expire_time = $expire->{ $self->task } || $expire->{ $self->CACHE_ALL_KEY() } || '';
#    $log->is_debug &&
#        $log->debug( "Action/task ", $self->name, "/", $self->task, " ",
#                     "has cache expiration: ", $expire_time );
    return $expire_time;
}

sub _check_cache {
    my ( $self ) = @_;

    return undef unless ( $self->_is_using_cache );   # ...not using cache
    return undef if ( CTX->request && CTX->request->auth_is_admin );  # ...is admin
    my $cache = CTX->cache;
    return undef unless ( $cache );                   # ...no cache available
    my $cache_key = $self->_create_cache_key;
    return undef unless ( $cache_key );               # ...no cache key
    return $cache->get({ key => $cache_key });
}

=pod

=head1 SEE ALSO

L<OpenInteract2::Action|OpenInteract2::Action>

=head1 AUTHOR

Teemu Arina, E<lt>teemu@ionstream.fiE<gt>,
Antti V��otam�i, E<lt>antti@ionstream.fiE<gt>

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

