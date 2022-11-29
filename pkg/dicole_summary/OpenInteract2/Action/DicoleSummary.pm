package OpenInteract2::Action::DicoleSummary;

use strict;

use base qw( OpenInteract2::Action::DicoleSummaryCommon );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

our $VERSION = sprintf("%d.%02d", q$Revision: 1.9 $ =~ /(\d+)\.(\d+)/);

sub _freeform_summary_list {
    my ( $self ) = @_;
    
    my $gid = $self->param('group_id') || 0;
    my $uid = $gid ? 0 : $self->param('user_id') || 0;
    
    my $ffs = CTX->lookup_object('freeform_summary')->fetch_group( {
        where => 'user_id = ? AND group_id = ?',
        value => [ $uid, $gid ],
    } ) || [];

    my $prefix = $gid ? 'group' : 'personal';
    my @ffs = map { $prefix . '_freeform_summary::' . $_->id } @$ffs;
    
    return \@ffs;
}

sub summary {
    my ( $self ) = @_;

    my $gid = $self->param('target_group_id');
    my $valid_invite = $self->_valid_invite_exists;
    die "security error" unless $valid_invite || $self->mchk_y( 'OpenInteract2::Action::DicoleGroupsSummary', 'read' );

    if ( $valid_invite && ! CTX->request->auth_user_id ) {
        $self->change_current_rights( $gid, 'group' );
    }

    my $layout = $self->_fetch_layout( $gid );
    my $actions = $self->_get_summary_actions( $gid );

    my %action_lookup = ();
    my @process_queue = ( @$layout );
    while ( my $a = shift @process_queue ) {
        if ( $a->{box_id} ) {
            $action_lookup{ $a->{box_id} } = $a;
        }
        else {
            unshift @process_queue, ( @{ $a->{left} || [] }, @{ $a->{right} || [] } );
        }
    }

    for my $action ( @$actions ) {
        my ( $action_name, $box_param ) = split( /::/, $action, 2);
        my $content = eval{ CTX->lookup_action( $action_name )->e( {
            box_open => 1,
            box_user => 0,
            box_group => $gid,
            ( $box_param ? ( box_param => $box_param ) : () ),
            target_user_id => 0,
            target_group_id => $gid,
        } ) };

        if ( my $msg = $@ ) {
            get_logger( LOG_APP )->error( $msg ) unless $msg =~ /^security error/;
        }
        elsif ( $content ) {
            unless ( $action_lookup{ $action } ) {
                $action_lookup{ $action } = { box_id => $action };
                push @$layout, $action_lookup{ $action };
            }
            if ( ref $content ) {
                $action_lookup{ $action }->{name} = $content->{name};
                $action_lookup{ $action }->{class} = $content->{class};
                $action_lookup{ $action }->{contents} = [];
                for my $widget ( @{ $content->{content} } ) {
                    push @{ $action_lookup{ $action }->{contents} }, $self->generate_content(
                        { itemparams => $widget->{params} }, { name => $widget->{template} }
                    );
                }
                $action_lookup{ $action }->{content} = '' .
                    '<div class="summary_box' . ( $content->{class} ? ' ' . $content->{class} : '' ) . '">' .
                    '<div class="summary_box_title">' . $content->{name} . '</div>' .
                    '<div class="summary_box_container">' .
                    '<div class="summary_box_content">' . join( '</div><div class="summary_box_content">', @{ $action_lookup{ $action }->{contents} } ) . '</div>' .
                    '</div>' .
                    '</div>';
            }
            else {
                $action_lookup{ $action }->{content} = '<div class="summary_box">' . $content . '</div>';
            }
        }
    }

    my $params = { boxes => $layout };

    my $globals = $self->_gather_common_globals( $valid_invite );

    my $title = $self->_msg('Summary');

    if ( $self->param('target_group') ) {
        $title = $self->param('target_group')->name . ' - ' . $title;
    }

    CTX->controller->add_content_param( 'page_title', $title );

    CTX->controller->init_common_variables( head_widgets => [
        Dicole::Widget::Javascript->new( code => 'dicole.set_global_variables('.
            Dicole::Utils::JSON->uri_encode( $globals )
        .');' )
    ] );

    return '<div class="summary_top_container">' . $self->generate_content( $params, { name => 'dicole_summary::summary_layout' } ) . '</div>';
}

sub _get_summary_actions {
    my ( $self, $gid ) = @_;

    my $tools = CTX->lookup_object( 'groups' )->fetch( $gid )->tool || [];
    push @$tools, { summary_list => 'freeform_summary_list' };

    my @actions = ();

    for my $tool ( @$tools ) {
        if ( my $summary = $tool->{summary} ) {
            push @actions, split( /\s*,\s*/, $summary );
        }
        if ( my $action_name = $tool->{summary_list} ) {
            my $summaries =  eval {
                CTX->lookup_action( $action_name )->execute( {
                    user_id => 0,
                    group_id => $gid,
                } );
            };
            if ( $@ ) {
                get_logger(LOG_APP)->error( $@ );
            }
            else {
                push @actions, @$summaries if ref $summaries eq 'ARRAY';
            }
        }
    }

    return \@actions;
}

sub _fetch_layout {
    my ( $self ) = @_;

    my $layout = Dicole::Settings->fetch_single_setting(
        tool => 'summary',
        attribute => 'layout',
        group_id => $self->param('target_group_id'),
    );
    my $data = $layout ?
        Dicole::Utils::JSON->decode( $layout) : 
        [
            {
                left_width => '50%',
                left => [
                    {
                        box_id => 'group_summary_browser',
                    },
                    {
                        box_id => 'group_discussions_summary',
                    },
                ],
                right => [
                    {
                        box_id => 'presentations_featured_summary',
                    },
                    {
                        right_width => '50%',
                        left => [
                            {
                                box_id => 'events_upcoming_summary',
                            },
                        ],
                        right => [
                            {
                                box_id => 'presentations_new_summary',
                            },
                        ]
                    },
                ],
            },
        ];

    return $data;
}

1;

__END__

=head1 NAME

OpenInteract2::Action::DicoleGroupsSummary - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS
