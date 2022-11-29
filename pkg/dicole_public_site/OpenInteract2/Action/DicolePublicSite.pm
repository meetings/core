package OpenInteract2::Action::DicolePublicSite;

use strict;
use base qw(Dicole::Action);
use Dicole::Tool;
use Dicole::MessageHandler   qw( :message );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Data::Dumper; # DEBUG

our $VERSION = sprintf("%d.%02d", q$Revision: 1.22 $ =~ /(\d+)\.(\d+)/);

sub page {
    my $self = shift;

    my $title = @{$self->{target_additional}}[0];
    my $dump = Data::Dumper::Dumper($self->_get_page_by_title($title));

    return "<pre>PAGE<br><br>$dump</pre>";
}

sub edit {
    my $self = shift;
    
    # XXX: is there a better way to get page id?
    my $page_id = @{$self->{target_additional}}[0];
    my $page;

    my $user_id = $self->param('target_user_id');

    my $tool = $self->init_tool({cols => 2, rows => 1});

    if ((CTX->request->param('save')) && ($page_id)) {
	$self->gtool(Dicole::Generictool->new(object => CTX->lookup_object('ps_page'),
					      skip_security => 1,
					      current_view => 'edit_page'));

	$self->init_fields;
	$self->gtool->set_fields_to_views;

	$page = $self->_get_page_by_id($page_id);

	my ($code, $message) = $self->gtool->validate_and_save($self->gtool->visible_fields,
							       {object => $page});	
	if ($code) {
	    $tool->add_message(MESSAGE_SUCCESS, $self->_msg("Page saved"));
	} else {
	    $tool->add_message(MESSAGE_ERROR, $self->_msg("Failed to save page: $page_id"));
	}
    }

    $tool->Container->box_at(0, 0)->name($self->_msg("Page listing"));
    $tool->Container->box_at(0, 0)->add_content($self->_tree_box);
    $tool->Container->box_at(1, 0)->name("Edit page");
    $tool->Container->box_at(1, 0)->add_content($self->_page_edit_box($page_id, $user_id));

    return $self->generate_tool_content;
}

sub add {
    my $self = shift;

    my $page_id = @{$self->{target_additional}}[0];
    $page_id = 1; # DEBUG
    my $page;
    
    my $tool = $self->init_tool({cols => 2, rows => 1});

    if ((CTX->request->param('save')) && ($page_id)) {
	# save object to database
	$self->gtool(Dicole::Generictool->new(object => CTX->lookup_object('ps_page'),
					      skip_security => 1,
					      current_view => 'edit_page'));
	$self->init_fields;
	$self->gtool->set_fields_to_views;

	$page = $self->_get_page_by_id($page_id);

	my ($code, $message) = $self->gtool->validate_and_save($self->gtool->visible_fields,
							       {object => $page});	
	if ($code) {
	    $tool->add_message(MESSAGE_SUCCESS, $self->_msg("Page saved"));
	} else {
	    $tool->add_message(MESSAGE_ERROR, $self->_msg("Failed to save page: $page_id"));
	}
    }

    $tool->Container->box_at(0, 0)->name($self->_msg("Page listing"));
    $tool->Container->box_at(0, 0)->add_content($self->_tree_box);
    $tool->Container->box_at(1, 0)->name("Add new page");
    $tool->Container->box_at(1, 0)->add_content($self->_page_add_box);

    return $self->generate_tool_content;
}

sub remove {
    my $self = shift;

    my $page_id = @{$self->{target_additional}}[0];
    my $page = $self->_get_page_by_id($page_id);

    my $data = Dicole::Generictool::Data->new;

    my $tool = $self->init_tool;

    if ($data->remove_object($page)) {
	$tool->add_message(MESSAGE_SUCCESS, $self->_msg("Removed page: $page->{title}"));
	return CTX->response->redirect(Dicole::URL->create_from_current(task => 'edit'));
    } else {
	$tool->add_message(MESSAGE_ERROR, $self->_msg("Failed to remove page: $page_id"));
	return CTX->response->redirect( Dicole::URL->create_from_current({
	    task => 'edit',
	    additional => $self->_get_lowest_page_id}));
    }
}

sub _get_lowest_page_id {
    my $self = shift;

    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('ps_page') );

    if ($self->param('target_user_id')) {
	$data->query_params( {
	    select => [ 'page_id' ],
	    from   => [ 'dicole_ps_page' ],
	    where  => 'dicole_ps_page.user_id = ?',
	    value  => [ $self->param('target_user_id') ],
	    order  => [ 'page_id' ]
	    } );
    } elsif ($self->param('target_group_id')) {
	$data->query_params( {
	    select => [ 'page_id' ],
	    from   => [ 'dicole_ps_page' ],
	    where  => 'dicole_ps_page.group_id = ?',
	    value  => [ $self->param('target_group_id') ],
	    order  => [ 'page_id' ]
	    } );
    } else {
	return undef;
    }

    $data->data_single;

    return $data->data->{page_id};
}

sub _get_parent_ids {
    my $self = shift;
    my $page_id = shift;

    my $data = Dicole::Generictool::Data->new;
    $data->object(CTX->lookup_object('ps_page'));

    if ($self->param('target_user_id')) {
	$data->query_params( {
	    from   => [ 'dicole_ps_page' ],
	    where  => 'dicole_ps_page.user_id = ?',
	    value  => [ $self->param('target_user_id') ],
	    order  => 'page_id'
	    } );
    } elsif ($self->param('target_group_id')) {
	$data->query_params( {
	    from   => [ 'dicole_ps_page' ],
	    where  => 'dicole_ps_page.group_id = ?',
	    value  => [ $self->param('target_group_id') ],
	    order  => 'page_id'
	    } );
    } else {
	return undef;
    }

    $data->data_group;

    if (defined($data->data)) {
	# chop off current page id
	my @ret = ();
	# XXX: use delete() ?
	foreach my $r (@{$data->data}) {
	    unless ($r->{page_id} == $page_id) {
		push @ret, $r->{page_id};
	    }
	}
	return @ret;
    } else {
	return undef;
    }
}

sub _get_page_ids {
    my ( $self, $args) = @_;
    my $ordering = ($args->{ordering} || 'ordering, parent_id');

    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('ps_page') );

    if ($self->param('target_user_id')) {
	$data->query_params( {
	    from  => [ "dicole_ps_page" ],
	    where => "dicole_ps_page.user_id = ? ",
	    value => [ $self->param('target_user_id') ],
	    order => $ordering
	    } );
    } elsif ($self->param('target_group_id')) {
        $data->query_params( {
            from  => [ "dicole_ps_page" ],
            where => "dicole_ps_page.group_id = ? ",
            value => [ $self->param('target_group_id') ],
            order => $ordering
            } );
    } else {
	return undef;
    }

    $data->data_group;

    if (defined($data->data)) {
	return $data->data;
    } else {
	return undef;
    }
}

sub _get_pages {
    my ($self, $args) = @_;
    my $ordering = ($args->{ordering} || 'ordering, parent_id');

    my $data = Dicole::Generictool::Data->new;
    $data->object(CTX->lookup_object('ps_page'));

    if ($self->param('target_user_id')) {
    	$data->query_params( {
    	    from  => [ "dicole_ps_page" ],
    	    where => "dicole_ps_page.user_id = ? ",
    	    value => [ $self->param('target_user_id') ],
    	    order => $ordering
    	    } );
    } elsif ($self->param('target_group_id')) {
    	$data->query_params( {
    	    from  => [ "dicole_ps_page" ],
    	    where => "dicole_ps_page.group_id = ? ",
    	    value => [ $self->param('target_group_id') ],
    	    order => $ordering
    	    } );
    } else {
	return undef;
    }

    $data->data_group;

    if (defined($data->data)) {
	return $data->data;
    } else {
	return undef;
    }
}

sub _get_page_by_title {
    my $self = shift;
    my $title = (shift || 'main');

    my $data = Dicole::Generictool::Data->new;
    $data->object(CTX->lookup_object('ps_page'));

    if ($self->param('target_user_id')) {
	$data->query_params( {
	    from  => [ "dicole_ps_page" ],
	    where => "dicole_ps_page.title = ? and dicole_ps_page.user_id = ?",
	    value => [ $title, $self->param('target_user_id') ]
	    } );
    } elsif ($self->param('target_group_id')) {
	$data->query_params( {
	    from  => [ "dicole_ps_page" ],
	    where => "dicole_ps_page.title = ? and dicole_ps_page.group_id = ?",
	    value => [ $title, $self->param('target_group_id') ]
	    } );
    } else {
	return undef;
    }

    $data->data_group;

    if (defined($data->data)) {
	return pop(@{$data->data});
    } else {
	return undef;
    }
}

sub _get_page_by_id {
    my $self = shift;
    my $page_id = (shift || $self->_get_lowest_page_id);

    my $data = Dicole::Generictool::Data->new;
    $data->object(CTX->lookup_object('ps_page'));

    if ($self->param('target_user_id')) {
	$data->query_params( {
	    from  => [ "dicole_ps_page" ],
	    where => "dicole_ps_page.page_id = ? and dicole_ps_page.user_id = ?",
	    value => [ $page_id, $self->param('target_user_id') ]
	    } );
    } elsif ($self->param('target_group_id')) {
	$data->query_params( {
	    from  => [ "dicole_ps_page" ],
	    where => "dicole_ps_page.page_id = ? and dicole_ps_page.group_id = ?",
	    value => [ $page_id, $self->param('target_group_id') ]
	    } );
    } else {
	return undef;
    }

    $data->data_group;

    if (defined($data->data)) {
	return pop(@{$data->data});
    } else {
	return undef;
    }
}

sub _page_add_box {
    my $self = shift;

    # my $page = CTX->lookup_object('ps_page');
    my $page = $self->_get_page_by_id(1); # DEBUG

    $self->gtool(Dicole::Generictool->new(object => $page,
                                          skip_security => 1,
                                          current_view => 'edit_page'));

    # $self->gtool->fake_objects([$page]);

    # $self->init_fields(package => 'dicole_public_site');
    # $self->_init_visible( $page );

    $self->init_fields;

    $self->_parent_id_dropdown($self->gtool->get_field('parent_id'));

    # button 'Save page'
    $self->gtool->add_bottom_buttons([{
	name => 'save',
	value => $self->_msg('Save page'),
    }]);

    open(DD, "> /tmp/dicole_debug/_page_add_box.txt");
    print DD Data::Dumper::Dumper($page);
    close(DD);

    return $self->gtool->get_edit(object => $page);
}

sub _page_edit_box {
    my $self = shift;
    # edit given page id or first page of site (main page)
    my $page_id = (shift || $self->_get_lowest_page_id);
    my $user_id = shift;

    return undef unless $page_id;

    my $page = $self->_get_page_by_id($page_id);

    # open(DD, "> /tmp/dicole_debug/_page_edit_box.txt");
    # print DD Data::Dumper::Dumper($page_id, $page->{parent_id});
    # close(DD);

    if (! $page) {
      $self->tool->add_message(MESSAGE_ERROR, $self->_msg("Page [_1] Not found", $page_id ));
      return undef;
    }

    $self->gtool(Dicole::Generictool->new(object => $page,
					  current_view => 'edit_page'));
    $self->init_fields;

    # parent_id dropdown for non-root nodes
    if ($page->{parent_id}) {
    	# generate parent id dropdown showing page titles
    	$self->_parent_id_dropdown($self->gtool->get_field('parent_id'), $page_id);
    } else {
     	# delete field 'parent id' from fields
	my $new_fields = [];
	my $fields = $self->gtool->visible_fields;
     	foreach my $field (@$fields) {
     	    unless ($field eq 'parent_id') {
     		push (@$new_fields, $field);
     	    }
	}
     	$self->gtool->visible_fields($new_fields);
    }

    # button 'Save page'
    $self->gtool->add_bottom_buttons([{
	name => 'save',
	value => $self->_msg('Save page'),
    }]);

    # button 'Remove page' w/ confirmation dialog
    $self->gtool->add_bottom_buttons([ {
	type  => 'confirm_submit',
	value => $self->_msg( 'Remove page' ),
	confirm_box => {
	    title => $self->_msg( 'Remove page' ),
	    name => $page->id,
	    msg   => $self->_msg( 'Are you sure you want to remove this page?' ),
	    href  => Dicole::URL->create_from_current(task => 'remove', other => [$page_id])
            }
    }] );

    # button 'View page'
    $self->gtool->add_bottom_buttons([{
	value => $self->_msg('View page'),
	type => 'link',
	link => Dicole::URL->create_from_current(task => 'page', other => [$page->{title}])}]);

    # button 'Add new page'
    $self->gtool->add_bottom_buttons([{
	value => $self->_msg('Add new page'),
	type => 'link',
	link => Dicole::URL->create_from_current(task => 'add')}]);

    return $self->gtool->get_edit(object => $page);
}

sub _parent_id_dropdown {
    my $self = shift;
    my $field = shift;
    my $page_id = (shift || 0);
    
    if ($self->param('target_user_id')) {
	$field->mk_dropdown_options(
				    class => CTX->lookup_object('ps_page'),
				    params => {
					where => "user_id = ? AND page_id != ?",
					value => [ $self->param('target_user_id'), $page_id ],
					order => 'parent_id'
					},
				    value_field => 'page_id',
				    content_field => 'title',
				    );
	return $field;
    } elsif ($self->param('target_group_id')) {
	$field->mk_dropdown_options(
				    class => CTX->lookup_object('ps_page'),
				    params => {
					where => "group_id = ? AND page_id != ?",
					value => [ $self->param('target_group_id'), $page_id ],
					order => 'parent_id'
					},
				    value_field => 'page_id',
				    content_field => 'title',
				    );
	return $field;
    } else {
	return undef;
    }
}

sub _tree_box {
    my ( $self ) = @_;
    
    my $group_icons = OpenInteract2::Config::Ini->new({
	filename => File::Spec->catfile(CTX->repository->full_config_dir,
					'dicole_public_site', 
					'public_site_icons.ini'
					)});

    my $creator = Dicole::Tree::Creator::Hash->new (id_key           => 'page_id',
						    parent_id_key    => 'parent_id',
						    order_key        => '',
						    parent_key       => '',
						    sub_elements_key => 'sub_elements');
    
    my $tree = Dicole::Navigation::Tree->new(root_name              => $self->_msg('Add page'),
					     selectable             => 0,
					     tree_id                => 'site_pages',
					     folders_initially_open => 1,
					     no_collapsing          => 1,
					     no_root_select         => 1,
					     icon_files             => $group_icons->{group_icons});
    $tree->root_href(Dicole::URL->create_from_current(task => 'add'));
    $creator->add_element_array($self->_get_pages);
    $self->_rec_create_tree($tree, undef, $creator->create );

    return $tree->get_tree;
}

sub _rec_create_tree {
    my ($self, $tree, $parent, $array) = @_;

    return if ref $array ne 'ARRAY';

    foreach my $page (@$array) {
	# XXX: implement security
        # next unless $self->chk_y( 'show_info', $page->{pages_id} );

        my $element = Dicole::Navigation::Tree::Element->new(
            parent_element => $parent,
            element_id => $page->{page_id},
            name => $page->{title},
            type => $page->{type},
            override_link => $self->derive_url(
                task => 'edit',
                target => $self->param('target_user_id'),
		additional => [ $page->{page_id} ]
            ),
        );

        $tree->add_element( $element );

	$self->_rec_create_tree( $tree, $element, $page->{sub_elements} );
    }
}


1;
