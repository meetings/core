package OpenInteract2::Action::DicoleFilesPopup;

use strict;

use base qw( Dicole::Action );

use OpenInteract2::Context   qw( CTX );

use Dicole::Widget::Columns;
use Dicole::Widget::FormControl::TextField;
use Dicole::Widget::LinkButton;
use Dicole::Widget::Horizontal;
use Dicole::Widget::Text;
use Dicole::Widget::FormControl::Select;


sub tinymce_select_file {
    my ($self) = @_;
    $self->init_tool();
    $self->tool->structure('popup');

    $self->tool->add_head_widgets(
#        Dicole::Widget::CSSLink->new(
#            href => '/css/dicole_file_popup.css',
#        ),
        Dicole::Widget::Javascript->new(
            src => '/tinymce/jscripts/tiny_mce/tiny_mce_popup.js',
        ),
        Dicole::Widget::Javascript->new(
            src => '/js/dicole_file_popup.js',
        ),
#        Dicole::Widget::Javascript->new(
#            src => '/js/dojo.js',
#        ),
    );

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg('Link selector')
    );

    my $link_row = Dicole::Widget::Columns->new(
        center => Dicole::Widget::FormControl::TextField->new(
            id => 'link_url_input',
            name => 'link_url',
            field_size => 50,
        )
    );

    if ( (
            $self->param('target_type') eq 'group' &&
            $self->schk_y( 'OpenInteract2::Action::DicoleFiles::group_read' )
        ) ||
        (
            $self->param('target_type') eq 'user' &&
            $self->schk_y( 'OpenInteract2::Action::DicoleFiles::user_read' )
         
        ) ) {
        $link_row->{right} = Dicole::Widget::LinkButton->new(
            id => 'browse_button',
            onclick => 'execute_browse(); return false;',
            text => $self->_msg('Browse local files'),
        );
        $link_row->{right_width} = '10%';
    }

    $self->tool->Container->box_at( 0, 0 )->add_content( [
        Dicole::Widget::Text->new( text => $self->_msg('Link URL:') ),
        $link_row,
        Dicole::Widget::Horizontal->new( contents => [
            Dicole::Widget::LinkButton->new(
                onclick => 'execute_popup(); return false;',
                text => $self->_msg('Select'),
            ),
            Dicole::Widget::LinkButton->new(
                onclick => 'cancel_popup(); return false;',
                text => $self->_msg('Cancel'),
            )
        ] ),
    ] );

    return $self->generate_tool_content;
}

sub tinymce_select_image {
    my ($self) = @_;
    $self->init_tool();
    $self->tool->structure('popup');

    $self->tool->add_head_widgets(
        Dicole::Widget::Javascript->new(
            src => '/tinymce/jscripts/tiny_mce/tiny_mce_popup.js',
        ),
        Dicole::Widget::Javascript->new(
            src => '/js/dicole_image_popup.js',
        ),
    );

    $self->tool->Container->box_at( 0, 0 )->name(
        $self->_msg('Image selector')
    );

    my $link_row = Dicole::Widget::Columns->new(
        center => Dicole::Widget::FormControl::TextField->new(
            id => 'image_url_input',
            name => 'image_url',
            field_size => 40,
        ),
    );
    
    if ( (
            $self->param('target_type') eq 'group' &&
            $self->schk_y( 'OpenInteract2::Action::DicoleFiles::group_read' )
        ) ||
        (
            $self->param('target_type') eq 'user' &&
            $self->schk_y( 'OpenInteract2::Action::DicoleFiles::user_read' )
         
        ) ) {
        $link_row->{right} = Dicole::Widget::LinkButton->new(
            id => 'browse_button',
            onclick => 'execute_browse(); return false;',
            text => $self->_msg('Browse local files'),
        );
        $link_row->{right_width} = '10%';
    }

    my $location_select = Dicole::Widget::FormControl::Select->new(
        id => 'image_align_input',
        name => 'image_align',
        options => [
            { text => $self->_msg('In line'), value => '' },
            { text => $self->_msg('Right'), value => 'right' },
            { text => $self->_msg('Left'), value => 'left' },
        ],
    );

    $self->tool->Container->box_at( 0, 0 )->add_content( [
        Dicole::Widget::Text->new( text => $self->_msg('Image URL:') ),
        $link_row,
        Dicole::Widget::Text->new( text => $self->_msg('Image description:') ),
        Dicole::Widget::FormControl::TextField->new(
            id => 'image_alt_input',
            name => 'image_alt',
            field_size => 40,
        ),
        Dicole::Widget::Text->new( text => $self->_msg('Image location:') ),
        $location_select,
        Dicole::Widget::Horizontal->new( contents => [
            Dicole::Widget::LinkButton->new(
                onclick => 'execute_popup(); return false;',
                text => $self->_msg('Select'),
            ),
            Dicole::Widget::LinkButton->new(
                onclick => 'cancel_popup(); return false;',
                text => $self->_msg('Cancel'),
            )
        ] ),
    ] );

    return $self->generate_tool_content;
}

1;
 