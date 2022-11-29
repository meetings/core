package OpenInteract2::Action::DicoleForums;

use strict;
use base qw(
    Dicole::Action
    Dicole::Action::Common::Summary
    Dicole::Action::Common::Settings
    OpenInteract2::Action::CommonForums
    OpenInteract2::Action::CommonThreads
    OpenInteract2::Action::CommonMessages
);

use OpenInteract2::Context   qw( CTX );
use Dicole::Content::Text;
use Dicole::Box;
use Dicole::Generictool::Data;
use Dicole::Content::Hyperlink;
use Dicole::URL;
use Dicole::Content::Image;
use Dicole::Feed;
use Dicole::Pathutils;

sub _init_tool {

    my $self = shift;

    $self->init_tool( {
        tool_args => {
            feeds => $self->init_feeds,
        },
        @_
    } );

    my $p = {@_};

    $p->{view} ||= ( split '::', ( caller(1) )[3] )[-1];

    $self->gtool(
        Dicole::Generictool->new(
            object => $p->{object},
            skip_security => 1,
            current_view => $p->{view},
        )
    );

    $self->init_fields( package => 'dicole_forums', view => $p->{view} );
}

########################################
# Summary box
########################################

sub _summary_customize {
    my ( $self ) = @_;

    my $title = Dicole::Widget::Horizontal->new;

    $title->add_content(
        Dicole::Widget::Hyperlink->new(
            content => $self->_msg('Unread messages'),
            link => Dicole::URL->create_from_parts(
                action => 'forums',
                task => 'forums',
                target => CTX->request->target_group_id,
            ),
        )
    );

    return {
        box_title => $title->generate_content,
        object => 'forums_messages',
        query_options => {
            from  => [ qw( dicole_forums_messages_unread dicole_forums_messages ) ],
            where => 'dicole_forums_messages.groups_id = ? AND dicole_forums_messages.active = ? AND '
              . 'dicole_forums_messages_unread.user_id = ? AND dicole_forums_messages_unread.msg_id = dicole_forums_messages.msg_id',
            value => [ $self->param( 'box_group' ), 1, CTX->request->auth_user_id ],
            limit => 5,
            order => 'date DESC'
        },
        empty_box => $self->_msg( 'No posts.' ),
    };
}

sub _summary_item_href {
    my ( $self, $item ) = @_;
    return Dicole::URL->create_from_current(
        action => 'forums',
        task => 'messages',
        other => [ $item->{forum_id}, $item->{thread_id}, $item->{msg_id} ],
    );
}

# Removed because we don't need already read messages
#sub _post_data_retrieve {
#    my ($self, $objects, $config) = @_;

#    if (ref $objects eq 'ARRAY' && scalar(@$objects) &&
#        CTX->request->auth_user_id ) {

#        my @ids = map { $_->id } @$objects;
#        my $in = '(' . join (",", @ids) . ')';
#        my $unread = CTX->lookup_object('forums_messages_unread')->fetch_group({
#            where => 'user_id = ? AND msg_id IN ' . $in,
#            value => [CTX->request->auth_user_id],
#        }) || [];

#        $config->{unread_by_id} = { map { $_->msg_id => $_ } @$unread };
#    }
#}

sub _summary_add_item {
    my ( $self, $cl, $topic, $item, $config ) = @_;

    unless ( ref $self->{_summary_types} ) {
        my $type_data = Dicole::Generictool::Data->new;
        $type_data->object( CTX->lookup_object('typeset_types') );
        $type_data->data_group;
        foreach my $type ( @{ $type_data->data } ) {
            $self->{_summary_types}{$type->id} = $type->{icon};
        }
    }

    $cl->add_entry(
        topic => $topic,
        elements => [ {
               width => '1%',
               content => Dicole::Content::Image->new(
                    src => $self->{_summary_types}{ $item->{type} },
                    width => 16,
                    height => 16
               ),
            }, {
               width => '99%',
               content => new Dicole::Content::Hyperlink(
                    text => $self->_summary_item_author( $item ),
                    content => $item->{ $config->{title_field} },
                    attributes => {
#                        class => $config->{unread_by_id}{$item->{msg_id}} ? 'unread' : '',
                        href => $self->_summary_item_href( $item )
                    },
                ),
        } ]
    );
}

sub _digest {
    my ( $self ) = @_;

   # Previous language handle must be cleared for this to take effect
    undef $self->{language_handle};
    $self->language( $self->param('lang') );

    my $group_id = $self->param('group_id');
    my $user_id = $self->param('user_id');
    my $domain_host = $self->param('domain_host');
    my $start_time = $self->param('start_time');
    my $end_time = $self->param('end_time');

    my $items = [];

    if ( $group_id ) {
        $items = CTX->lookup_object('forums_messages')->fetch_group( {
            where => 'groups_id = ? AND active = ? AND date > ?',
            value => [ $group_id, 1, $start_time ],
            order => 'date DESC'
        } ) || [];
    }

    if (! scalar( @$items ) ) {
        return undef;
    }

    my $return = {
        tool_name => $self->_msg( 'Forums' ),
        items_html => [],
        items_plain => []
    };

    for my $item ( @$items ) {
        my $date_string = Dicole::DateTime->medium_datetime_format(
            $item->{date}, $self->param('timezone'), $self->param('lang')
        );
        my $link = $domain_host . Dicole::URL->create_from_parts(
            action => 'forums',
            task => 'messages',
            target => $group_id,
            additional => [ $item->{forum_id}, $item->{thread_id}, $item->id ],
        );
        my $user = CTX->lookup_object('user')->fetch( $item->{writer}, { skip_security => 1 } );
        my $user_name = $user->first_name . ' ' . $user->last_name;

        push @{ $return->{items_html} },
            '<span class="date">' . $date_string
            . '</span> - <a href="' . $link . '">' . $item->{title}
            . '</a> - <span class="author">' . $user_name . '</span>';

        push @{ $return->{items_plain} },
            $date_string . ' - ' . $item->{title}
            . ' - ' . $user_name . "\n  - " . $link;
    }

    return $return;
}

########################################
# RSS feed
########################################

# Provide RSS feed for the tool
sub feed {
    my ( $self ) = @_;

    # use the first additional to set a new language
    $self->_shift_additional_language;

    my $settings = $self->_get_settings;
    $settings->fetch_settings;
    my $settings_hash = $settings->settings_as_hash;

    if ( ! $self->skip_secure ) {
        unless ( CTX->request->auth_is_logged_in ) {
            if ( $settings_hash->{ 'ip_addresses_feed'} =~ /^\d+/ ) {
                if ( $self->_check_ip_addresses(
                $settings_hash->{ 'ip_addresses_feed'} )
                ) {
                    return 'Access denied.';
                }
            }
            elsif ( !$settings_hash->{ 'public_feed' } ) {
                return 'Access denied.';
            }
        }
        else {
            return 'Access denied.' unless $self->schk_y( 'OpenInteract2::Action::CommonMessages::read', $self->target_group_id );
        }
    }

    my $feed = Dicole::Feed->new( action => $self );

    $feed->list_task( 'forums' );

    my $data = Dicole::Generictool::Data->new;
    $data->object( CTX->lookup_object('forums_messages') );

    $feed->creator( 'Dicole forums' );

    my $group = CTX->lookup_object( 'groups' )->fetch(
        $self->target_group_id
    );
    $feed->title( $group->{name} . ' - ' . $self->_msg( 'Forums' ) );
    $feed->desc( $group->{description} );
    # Fetch latest 10 group pages
    $data->query_params( {
        where => 'groups_id = ? AND active = ?',
        value => [ $self->target_group_id, 1 ],
        limit => $settings_hash->{ 'number_of_items_in_feed' } || 5,
        order => 'date DESC'
    } );
    $data->data_group;

    foreach my $object ( @{ $data->data } ) {
        $object->{title_link} = $self->derive_url(
            action => 'forums',
            task => 'messages',
            additional => [ $object->{forum_id}, $object->{thread_id}, $object->{msg_id} ],
        );

        my $parts = Dicole::Generictool::Data->new;
        $parts->object( CTX->lookup_object('forums_parts') );
        $parts->query_params( {
            where => 'version_id = ?',
            value => [ $object->{version_id} ],
            order => 'part_id'
        } );
        $parts->data_group;

        my @content = ();
        foreach my $part_data ( @{ $parts->data } ) {
            if ( $part_data->{origin_part_id} ) {
                $part_data->{content} = '<span class="textQuoted">"'
                    . $part_data->{content} . '"</span>';
            }
            next unless $part_data->{content};
            push @content, $part_data->{content};
        }
        $object->{content} = join '<br /><br />', @content;
    }
    $feed->subject_field( 'title' );
    $feed->link_field( 'title_link' );

    return $feed->feed(
        objects => $data->data,
    );
}

########################################
# Settings tab
########################################

sub _settings_config {
    my ( $self, $settings ) = @_;
    $settings->tool( 'forums' );
    $settings->user( 0 );
    $settings->group( 1 );
}

#############################################################

sub _author_dropdown {
    my ( $self ) = @_;
    my $field = $self->gtool->get_field( 'user_id' );

    my $users = CTX->lookup_object('groups')->fetch(
        CTX->request->target_group_id
    )->user( { skip_security => 1 } );

    foreach my $user ( @{ $users } ) {
        $field->add_dropdown_item( $user->id,
            join " ", ( $user->{first_name}, $user->{last_name} )
        );
    }
}

sub _type_dropdown {
    my ( $self, $field, $typeset_id ) = @_;
    $field->mk_dropdown_options(
        class => CTX->lookup_object('typeset_types'),
        params => {
            where => "typeset_id = ?",
            value => [ $typeset_id ],
            order => 'type_id'
        },
        value_field => 'type_id',
        content_field => 'title',
        localize => 1
    );
}

sub _return_to_main {
    my ( $self ) = @_;
    my $redirect = Dicole::URL->create_from_current( task => 'forums' );
    return CTX->response->redirect( $redirect );
}

1;

__END__

=head1 NAME

OpenInteract2::Action::DicoleForums - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS
