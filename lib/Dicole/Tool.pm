package Dicole::Tool;

use strict;

use base qw( Exporter Dicole::Security::Checker Dicole::RuntimeLogger );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::Navigation::Tabs;
use Dicole::Navigation::Path;
use Dicole::Container;
use Dicole::URL;
use Dicole::Pathutils;
use Dicole::Widget::CSSLink;
use Dicole::Widget::Javascript;
use Dicole::Widget::Hyperlink;
use Dicole::Widget::Horizontal;
use Dicole::Widget::LinkBar;
use Dicole::Widget::ContentBox;

use constant DEFAULT_LOGO_URL => '/images/theme/default/navigation/logo.gif';

our $VERSION = sprintf("%d.%02d", q$Revision: 1.100 $ =~ /(\d+)\.(\d+)/);

=pod

=head1 NAME tool class for creating Dicole tools

=head1 SYNOPSIS

 use Dicole::Tool;
 use Dicole::Content::Text;
 my $tool = Dicole::Tool->new( action_params => $p );

 $tool->Container->generate_boxes( 1, 1 ); # columns,rows
 $tool->Container->box_at( 0, 0 )->name( 'Hello world' );
 $tool->Container->box_at( 0, 0 )->add_content( [
     Dicole::Content::Text->new( content => 'Hello world')
 ] );

 return $self->generate_content( $tool->generate_content_params );

=head1 DESCRIPTION

This class represents a tool in Dicole. It is the heart of Dicole API and
usually ties together all the other Dicole objects. When creating Dicole applications
you usually start by creating a Tool object, add some boxes in the container
and fill the boxes with content objects.

When the request is done you generate the resulting output. Tool object does the job
for you, converting all the internal objects as meaningful data structures ready for
input to your template parser.

=head1 CONSTANTS

These constants can be exported with key :message .

=head2 MESSAGE_ERROR()

Return code error. This code is used for return messages that indicate that
the request had an error and did not complete successfully.

=head2 MESSAGE_SUCCESS()

Return code success. This code is used for return messages that indicate that
the request completed successfully.

=head2 MESSAGE_WARNING()

Return code warning. This code is used for return messages that indicate that
the request completed successfully but had warnings.

=head1 INHERITS

Inherits L<Class::Accessor>, which creates some accessors
for the class attributes.

Inherits L<Dicole::MessageHandler>, which provides message dispatching and
handling functions for our class. See documentation of L<Dicole::MessageHandler>
for more information, since it is an essential part of L<Dicole::Tool>.

=cut

use base qw( Class::Accessor Dicole::MessageHandler );

our @EXPORT_OK = @Dicole::MessageHandler::EXPORT_OK;
our %EXPORT_TAGS = %Dicole::MessageHandler::EXPORT_TAGS;

=pod

=head1 ACCESSORS

=head2 action( [object] )

Sets/gets the action object. This is required to find out about the
action parameters (I<action.ini>).

This is usually initialized by passing I<$self> to I<new()>
constructor from the action itself.

=head2 wrap_form( [BOOLEAN] )

Sets/gets the wrap form bit. If this is true, we wrap a form
around the tool container.

True by default.

See also I<form_params()>.

=head2 form_params( [HASH] )

Sets/gets the tool container form parameters. The parameters are
set with a hash of parameters, for example:

 {
    name => 'Form',
    enctype => 'multipart/form-data'
 }

=head2 tab_override( [STRING] )

Sets/gets the tab which will be used as the task tab instead of trying
to set the task tab as the current task.

This is especially useful if you have a listing view of items and
clicking an item brings you to a display view of the item. In this
case you might want to specify the tab overriding as the task of the list
view, e.g. I<list>.

=head2 structure( [STRING] )

Sets/gets the structure which will be used to generate the tool. The default
is I<tool> and it is often not necessary to modify it.

Dicole supports the following structures for a tool:

=over 4

=item B<tool>

This is the default.

=item B<desktop>

A special case for generating tools that look like desktops: content boxes in
several columns and possibility to move the boxes around.

=item B<popup>

A tool that is in a popup. A popup tool is a stripped-down version of I<tool>:
it only contains the tool path and tool container (no tabs or tool info).

Example use of this tool structure is a file selection dialog.

=item B<custom>

A custom tool structure. Allows you to specify your own content object for the tool.
Use together with I<custom_content()>.

=item B<blank>

A blank tool. Only contains the tool info.

=back

There are cases when you want to specify your own structures,
though. If none of the above is enough for you, you may want to specify your own
tool structure (see template I<container_content.tmpl> in dicole_base package).

=head2 Path( [OBJECT] )

Sets/gets the tool path object. This is usually initialized in the I<new()> constructor
and contains a L<Dicole::Navigation::Path> object.

=head2 Tabs( [OBJECT] )

Sets/gets the tabs object. This is usually initialized in the I<new()> constructor
and contains a L<Dicole::Navigation::Tabs> object.

Tabs are usually read from I<tabs.ini>:

 [order]
 usermanager = tab_1
 usermanager = tab_2
 usermanager = tab_3

 [usermanager tab_1]
 name = List users
 task = list

 [usermanager tab_3]
 name = Remove users
 task = del
 security = OpenInteract2::Action::UserManager::remove_users

 [usermanager tab_2]
 name = Go to profiles
 action = profiles
 task = view

The order key defines an array of tab identifiers for each action.
For each action there is a hash with these identifiers.
Name specifies the text you see in the tab.
Task specifies the task this tab links to.
Action specifies the action this tab links to. It defaults to current action.
Security is used to specify the security needed to view this tab.

=head2 Container( [OBJECT] )

Sets/gets the container object. This is usually initialized in the I<new()> constructor
and contains a L<Dicole::Container> object.

=head2 title( [STRING] )

Sets/gets the title of the page.

=head2 tool_name( [STRING] )

Sets/gets the tool name of the object. This is displayed in the tool info part above
the tool container.

Usually read from the action parameter I<tool_name>.

=head2 tool_icon( [STRING] )

Sets/gets the tool icon name.

Usually read from the action parameter I<tool_icon>.

=head2 tool_icon_path( [STRING] )

Sets/gets the tool icon path.

If no tool icon path is set, then the default tool icon path will be used.

=head2 tool_help( [INTEGER] )

Sets/gets the context sensitive help page id for the generated page in question.

Usually read from the action parameter I<help>. The task name will be used
to identify the help page in the parameters. Here is an example how to
set your context sensitive help pages in your I<action.ini>:

 [help]
  add     = 50
  list    = 51
  show    = 52
  del     = 53
  edit    = 54
  archive = 55

See documentation of package I<dicole_help> for more information about how to register
your own context sensitive help pages.

=head2 summaries( [HASH] )

Sets/gets the summary box parameters.

=head2 custom_content( [OBJECT|HASH] )

Sets/gets the custom content for tools that have structure set as I<custom>. The
custom content may be an L<Dicole::Content> object or a hash. If it is a hash,
the format is as follows:

 {
     template => 'dicole_base::tool_content'
     params => { ... } # parameters for the content template
 }

=head2 no_tool_tabs( [BOOLEAN] )

Sets/gets the no tool tabs bit. If this is true, then there will be no
tool tabs present in the resulting tool.

=head2 no_tool_path( [BOOLEAN] )

Sets/gets the no tool path bit. If this is true, then there will be no
tool path present in the resulting tool.

=head2 selected_tab( [INTEGER] )

Sets/gets the currently selected tab. This is automatically set by I<new()>
constructor.

=head2 feeds( [ARRAYREF] )

Sets/gets the feeds the tool provides. Accepts a array of hashes of feeds, example:

    [
        {
            type => 'atom03',
            url => '/myaction/feed/atom.xml',
            desc => 'Atom feed',
            lang => 1
        },
        {
            type => 'rss090',
            url => '/myaction/feed/feed.rdf',
            desc => 'Feed for my application',
            lang => 0
        }
        ...
    ]

Accepted feed types are:

=over 4

=item atom03

for Atom 0.3

=item rss090

for RSS 0.90

=item rss091

for RSS 0.91

=item rss10

for RSS 1.0

=item rss20

for RSS 2.0

=item opml

for OPML

=item xml

for everything else

=back

=head2 custom_css_class( [STRING] )

Sets/gets custom css class name for the tool. This class will be placed
in the div block that is around the tool itself. Useful if you want to
provide custom CSS behaviour for certain tool pages.

If you have custom css class defined as I<wikiPage>, the div tag will be
as follows:

 <div class="tool wikiPage">

=cut

# We are lazy...Lets generate some basic accessors for our class.
Dicole::Tool->mk_accessors(
    qw( action wrap_form tab_override form_params structure Path
    Tabs title Container tool_name tool_help
    custom_content no_tool_tabs no_tool_path selected_tab
    summaries tool_icon tool_icon_path feeds custom_css_class
    head_widgets end_widgets footer_widgets tool_title_prefix tool_title_suffix tool_title
    
    nice_tabs
    action_buttons
    )
);

=pod

=head2 template( [STRING] )

Sets/gets the template for which the data structure will be generated with
I<get_tool_structure()>.

By default this is I<dicole_base::container_content>.

=cut

sub template {
    my ( $self, $template ) = @_;
    if ( defined $template ) {
        $self->{template} = $template;
    }
    return $self->{template};
}

=pod

=head1 METHODS

=head2 new( HASH )

Creates and returns a new Tool object.

Accepts a hash of parameters. See all accessors for information about
possible parameters to the constructor.

The only requirement is I<action>.

Goes through the parameters and populates I<Path()>, I<Tabs()>,
I<Container()>, tool_name() and tool_help().

=cut

sub new {
    my ($class, %args) = @_;
    my $config = { };
    my $self = bless( $config, $class );
    $self->_init(%args);
    return $self;
}

# "private" method to initialize object attributes
sub _init {
    my ( $self, %args ) = @_;

    # defaults
    my %default_args = (
        action      => undef,
        form_params => {
            method => 'post',
            name => 'Form'
        },
        wrap_form      => 1,
        selected_tab   => 0,
        structure      => 'tool',
        tool_help      => 0,
        action_buttons => [],
        head_widgets   => [],
        end_widgets    => [],
        footer_widgets => [],
    );

    # Set defaults but prefer user input
    foreach my $key ( keys %default_args ) {
        $self->$key( $default_args{$key} ) if $self->can( $key );
    }
    foreach my $key ( keys %args ) {
        $self->$key( $args{$key} ) if $self->can( $key );
    }

    $self->form_params()->{'accept-charset'}
        ||= CTX->request->session->{lang}{charset};
    $self->form_params()->{enctype} ||= 'application/x-www-form-urlencoded';

    $self->action->param(
        'tool_name',
        $self->action->_msg( $self->action->param( 'tool_name' ) )
    ) if $self->action->param( 'tool_name' );

    $self->tool_name( $self->action->param( 'tool_name' ) )
        unless defined $args{tool_name};

    $self->tool_icon( $self->action->param( 'tool_icon' ) )
        unless defined $args{tool_icon};

    if ( ref( my $help = CTX->controller->initial_action->param( 'help' ) ) eq 'HASH' ) {
        $self->tool_help( $help->{ CTX->controller->initial_action->task } )
            unless defined $args{help};
    }

    my $prefix = undef;
    if ( CTX->controller->initial_action->param('target_group') ) { 
       $prefix = CTX->controller->initial_action->param('target_group')->name;
    }
    else {
      $prefix = CTX->server_config->{dicole}{title};
    }

    my $title = $self->action->_msg( $self->tool_name );

    $self->tool_title_prefix($prefix);
    $self->tool_title($title);

    $self->Path( Dicole::Navigation::Path->new(
        initial_path => [ {
            name => $self->tool_name,
            href => Dicole::URL->create_from_current(
                task => $self->tab_override || CTX->request->task_name
            )
        } ]
    ) ) unless defined $args{Path};

    my $tab_options = [];

    my $action = CTX->controller->initial_action;
    my $action_name = lc $action->name;
    my $task_name = lc $action->task;

    my $package = $action->param( 'package_name' );
    $package ||= $action->package_name; # XXX: this is the CVS oi way..

    my $inifile = File::Spec->catfile(
        CTX->repository->full_config_dir, $package, 'tabs.ini'
    );

    my @tabs;
    my $ini;

    if ( ! $inifile ) {
        get_logger( LOG_ACTION )->debug( sprintf(
            'Unable to find conf/tabs.ini in package %s',
            $package
        ) );

        @tabs = ();
    }
    else {
        eval {
            $ini = OpenInteract2::Config::Ini->new(
                { filename => $inifile }
            );
        };
        if ( $@ || ! $ini->{order} ) {
            @tabs = ();
        }
        else {
            my $tabs = $ini->{order}{ $action_name };
            @tabs = ( ref $tabs eq 'ARRAY' ) ? @$tabs : ( $tabs );
        }
    }

    for my $key ( @tabs ) {

        my $tab = $ini->{ $action_name }{ $key };

        unless ( CTX->request && CTX->request->auth_user_id ) {
            next if $tab->{require_logged_in_user};
        }
        next unless $self->action->check_ini_secure(
            $tab->{secure}, CTX->request->target_id
        );

        my %tab_url = ( task => $tab->{task} );

        if ( $tab->{action} ) {
            $tab_url{action} = $tab->{action};
        }

        if ( defined $tab->{target} ) {
            $tab_url{target} = $tab->{target};
        }

        if ( defined $tab->{additional} ) {
            $tab_url{additional} = $tab->{additional};
            $tab_url{additional} = [ $tab_url{additional} ] unless ref( $tab_url{additional} );
        }
        else {
            $tab_url{additional} = [];
        }

        push @{ $tab_options }, {
            key  => $key,
            name => $self->action->_msg( $tab->{name} ),
            href => Dicole::URL->create_from_current(
                %tab_url
            ),
            class => $tab->{class},
        };

        # set this tab as the selected one if tab task is the
        # same as tab_override argument or if the tab task
        # is the same as the current task
        # also action should match if one is defined..

        if ( ( $tab->{task} eq $self->tab_override || $tab->{task} eq $task_name )
        && ( !$tab->{action} || $tab->{action} eq $action_name )
        ) {
            $self->selected_tab( $key );
            my $tab_name = $self->action->_msg( $tab->{name} );
            $self->Path->add( name => $tab_name );
            $self->tool_title_suffix($tab_name);
        }

    }


    # Count which number was the selected tab.
    # somewhat stupid but backwards compatible ;)

    my $count = 0;
    for my $tab ( @$tab_options ) {
        if ( $tab->{key} eq $self->selected_tab ) {
            $tab->{selected} = 1;
            last;
        }
        $count++;
    }

    # Set selected to 0 if none was found.

    #if ( $count == @$tab_options ) {
    #    $count = 0;
    #    $tab_options->[0]->{selected} = 1 if 
    #        scalar( @$tab_options );
    #}

    # Set the tabs.

    $self->Tabs( Dicole::Navigation::Tabs->new(
        options  => $tab_options,
        selected => $count
    ) );

    # Push footer widgets
#     $self->add_footer_widgets(
#         Dicole::Widget::Horizontal->new( contents => [
#             Dicole::Widget::Hyperlink->new( content => $self->action->_msg('About'), link => '/wiki/show/1/About' ),
#             Dicole::Widget::Text->new( text => ' | ' ),
# #             Dicole::Widget::Hyperlink->new( content => $self->action->_msg('Blog'), link => '/wp/' ),
# #             Dicole::Widget::Text->new( text => ' | ' ),
# #             Dicole::Widget::Hyperlink->new( content => $self->action->_msg('FAQ'), link => '/wiki/show/1/FAQ' ),
# #             Dicole::Widget::Text->new( text => ' | ' ),
#             Dicole::Widget::Hyperlink->new( content => $self->action->_msg('Terms Of Service'), link => '/wiki/show/1/Terms_Of_Service' ),
#             Dicole::Widget::Text->new( text => ' | ' ),
#             Dicole::Widget::Hyperlink->new( content => $self->action->_msg('Contact Us'), link => '/wiki/show/1/Contact_Us' ),
#         ] ),
#     ) if CTX->controller->type eq 'tt-template';
#     
#     if ( ! CTX->request->auth_user_id ) {
#         $self->add_end_widgets(
#             Dicole::Widget::Raw->new( raw => <<RAW,
#     <div id="light" class="loginbox">
#         <div class="loginHeader">Login</div>
#         <div id="login_return_message_container"></div>
#         <form name="loginForm" id="loginForm">
#         <table class="loginElements">
#         <tr>
#         <td class="loginTitle">Username</td>
#         <td class="loginField">
# 
#         <input class="req" id="focusElement" name="login_login_name" size="35" type="text" value="" onkeypress="return nextField(event)" />
#         </td>
#         </tr>
#         <tr>
#         <td class="loginTitle">Password</td>
#         <td class="loginField">
#         <input class="req" id="login_password" name="login_password" size="35" type="password" value="" />
#         </td>
#         </tr>
# 
#         <tr>
#         <td class="loginUsernameTitle"></td>
#         <td class="loginUsernameField">
#         <a class="loginLink" href="#" id="light_login_button" rel="lightbox">Login</a>
#         </td>
#         </tr>
#         </table>
#         </form>
#         <div class="loginLinks"><a  href="/lostaccount/">Retrieve lost username and password</a></div>
# 
#     </div>
#     <a id="fade" class="black_overlay"></a>
# RAW
#             ),
#             Dicole::Widget::Javascript->new( src => '/js/lightbox_login.js' ),
#         );
#         $self->add_head_widgets(
#             Dicole::Widget::CSSLink->new( href => '/css/lightbox_login.css' ),
#         );
#     }

    $self->Container( Dicole::Container->new );

}

sub get_tablink_widgets {
    my (  $self, $disabled ) = @_;

    $disabled ||= [];
    my %disabled_hash = map { $_ => 1 } @$disabled;

    my @widgets = ();
    for my $tab ( @{ $self->Tabs->{_options} || [] } ) {
        next if $disabled_hash{ $tab->{key} };
        my @classes = ();
        push @classes, join('_', ($tab->{class}, 'selected')) if $tab->{selected};
        push @classes, 'selected' if $tab->{selected};
        push @classes, $tab->{class} if $tab->{class};
        push @widgets, Dicole::Widget::LinkBar->new(
            content => $tab->{name},
            link => $tab->{href},
            class => join( ' ', @classes ),
        ),
    }
    return Dicole::Widget::Vertical->new( contents => \@widgets );
}

sub get_tablink_box {
    my ( $self, $name, $disabled ) = @_;
    return Dicole::Widget::ContentBox->new(
        name => $name,
        content => $self->get_tablink_widgets( $disabled )
    );
}

=pod

=head2 get_tool_structure()

Returns the tool data strucuture according to class attributes ready
for passing to a tool content template.

=cut

sub get_tool_structure {
    my $self = shift;

    $self->_set_maintmpl_vars;

    my $theme_images = undef;
    $theme_images = CTX->controller->content_params->{theme_images}
        if CTX->controller->can( 'content_params' );

    my $logo_url = DEFAULT_LOGO_URL;
    my $dicole_domains = eval { CTX->lookup_action( 'dicole_domains' ) };
    unless ($@) {
        $dicole_domains->task( 'get_domain_logo_url' );
        my $logo_url_t = $dicole_domains->execute;
        $logo_url_t && ($logo_url = $logo_url_t);
    }

    my $custom_content = $self->custom_content;
    $custom_content = {
            template => $self->custom_content->get_template,
            params => $self->custom_content->get_template_params,
        } if ref $self->custom_content;

    my $help = undef;
    if ( $self->tool_help ) {
        my $action = CTX->controller->initial_action;
        $help = OpenInteract2::URL->create(
            '/context_help/show/' . $action->name . '/' . $action->task . '/' . $self->tool_help
        );
    }

    if ( ref( $self->feeds ) eq 'ARRAY' ) {
      foreach my $feed ( @{ $self->feeds } ) {
        $feed->{lang} = CTX->request->session->{lang}{code} if $feed->{lang};
      }
    }
    
    my $messages = $self->get_messages;
    $self->clear_messages;

    $self->rlog( 'Tool container params output');
    my $container_params = $self->Container->output;
    $self->rlog;

    return {
        theme_images => $theme_images,
    logo_url => $logo_url,
        page => {
            form_params    => $self->form_params,
            wrap_form      => $self->wrap_form,
            structure      => $self->structure,
            custom_content => $custom_content,
        },
        tool => {
            action_buttons => $self->action_buttons,
            info => {
                  messages    => $messages,
                  name        => $self->tool_name,
                  icon        => $self->tool_icon,
                  icon_path   => $self->tool_icon_path
            },
            custom_css_class => $self->custom_css_class,
            feeds => $self->feeds,
            help => $help,
            ( $self->no_tool_tabs ) ? () : ( tabs => $self->Tabs->output ),
            no_tool_tabs => $self->no_tool_tabs,
            ( $self->no_tool_path ) ? () : ( path  => $self->Path->return_data ),
            no_tool_path => $self->no_tool_path,
            summaries => $self->summaries,
            nice_tabs => $self->nice_tabs,
            # (containers, containers_columns, containers_widths)
            %{ $container_params },
        },
    };
}

=pod

=head2 generate_content_params()

Generates parameters ready for I<$self->generate_content()>. Returns
an array of two hashrefs.

=cut

sub generate_content_params {
    my $self = shift;
    my $template = $self->template;
    unless ( $template ) {
        $template = CTX->server_config->{dicole}{base}
            . '::container_' . $self->structure;
    }
    my $structure = $self->get_tool_structure;
    return ( $structure, { name => $template } );
}

=pod

=head1 PRIVATE METHODS

=head2 _set_maintmpl_vars()

The purpose of this function is to set some maintemplate parameters beforehand.
At the moment this function contains a lot of things it should not contain like
the generation of navigation parameters.

=cut

sub _set_maintmpl_vars {
    my ( $self ) = @_;
    
    return unless CTX->controller->can( 'init_common_variables' );

    my %params = ();

    if ($self->title) {
        $params{title} = $self->title;
    }
    else {
        my $title = join( ' - ', ( $self->tool_title_prefix || (),  $self->tool_title || (),  $self->tool_title_suffix || () ) );
        $params{title} = $title;
    }

    if ( ref $self->feeds eq 'ARRAY' ) {
        my $type = $self->feeds->[0]{type};
        $type =~ /^(\D+)(\d)(\d+)$/;
        $type = uc( $1 ) . ' ' . $2 . '.' . $3;
        my $url = $self->feeds->[0]{url};
        if ( $url =~ m{^/} ) {
            $url = Dicole::Pathutils->get_server_url . $url;
        }

        $params{feed} = {
            title => $type,
            href  => $url,
        };
    }

    CTX->controller->init_common_variables(
        tool => $self,
        head_widgets => scalar( $self->head_widgets ),
        footer_widgets => scalar( $self->footer_widgets ),
        end_widgets => scalar( $self->end_widgets ),
        %params,
    );
}

sub add_head_widgets {
    my ($self, @widgets) = @_;

    push @{$self->head_widgets}, @widgets;
}

sub add_footer_widgets {
    my ($self, @widgets) = @_;

    push @{$self->footer_widgets}, @widgets;
}

sub add_end_widgets {
    my ($self, @widgets) = @_;

    push @{$self->end_widgets}, @widgets;
}

sub add_tinymce_widgets {
    my ( $self, $type, $old_version, $params ) = @_;

    return unless CTX->server_config->{dicole}{tinymce};
    $type ||= 'default';

    $params ||= {};

    unshift @{$self->head_widgets}, @{
        CTX->lookup_action('tinymce_api')->execute( get_head_widgets => {
            type => $type,
            old_version => $old_version,
            %$params,
        } )
    };
}

sub add_comments_widgets {
    my ( $self ) = @_;
    
    $self->add_tinymce_widgets( 'comments' );
    
    $self->add_head_widgets(
        Dicole::Widget::Javascript->new(
            code => 'dojo.require("dicole.comments");',
        )
    );
}

sub add_js_variables {
    my ( $self, $vars ) = @_;
    $self->add_head_widgets(
        Dicole::Widget::Javascript->new( code => 'dicole.set_global_variables('.
            Dicole::Utils::JSON->uri_encode( $vars )
        .');' )
    );

}

=pod

=head1 SEE ALSO

L<Dicole::Content>,
L<Dicole::Container>,
L<Dicole::Box>,
L<Dicole::Navigation::Tabs>,
L<Dicole::Navigation::Path>


=head1 AUTHOR

Teemu Arina E<lt>teemu@ionstream.fiE<gt>,
Antti V��otam�i E<lt>antti@ionstream.fiE<gt>,
Hannes Muurinen E<lt>hannes@ionstream.fiE<gt>

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

