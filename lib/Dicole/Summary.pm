package Dicole::Summary;

use strict;

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );

use Dicole::URL;
use Dicole::Box;
use Dicole::Content::Text;
use Dicole::Settings;

#
# NOTE!
#
# Break this into two pieces. One which handles global stuff and one which
# is to be inherited by all actions implementing summaries.
#



=pod

=head1 METHODS

=head2 parse_cookie( COOKIE_NAME, COOKIE_CONTENT )

parses the received cookie.

returns a hashref of summary layout.

summary layout hash contains keys:

 * action
 * task
 * target
 * columns

target is either a group or a user depending
on the action.

columns contains an array of hashes with keys:

 * width
 * boxes

boxes contain a matrix of hashes which have keys:

 * open
 * box_id

first array contains columns, second contains column content:

 $parsed->{columns}[0]{boxes}[0] == 1st column, 1st row hash
 $parsed->{columns}[0]{boxes}[1]{box_id} == 1st column, 2nd row id
 $parsed->{columns}[1]{boxes}[0]{open} == 2nd column, 1st row state

=cut


sub parse_cookie {
    my ( $self, $name, $content ) = @_;

    return if !$name || !$content;

    my ( $action, $task, $target ) =
        $name =~ /^summary_(.+?)_([^_]+)_(\d+)$/;

    next if !$action;

    my @items = split /#/, $content;

    my $columns = [];

    foreach my $item ( @items ) {

        if ( $item =~ /^width/ ) {

            # HANDLE WIDTH ?!

        }
        else {

            my ( $box_id, $col, $row, $open ) =
                $item =~ /^(.*) (\d+)\.(\d+)(\.\w+)?$/;

            next unless $box_id && defined $col && defined $row;

            $open = ( $open ) ? 0 : 1;

            $columns->[ $col ]->{boxes}->[ $row ]->{box_id} = $box_id;
            $columns->[ $col ]->{boxes}->[ $row ]->{open} = $open;
        }
    }

    return {
        action => $action,
        task => $task,
        target => $target,
        columns => $columns
    };

}




=pod

=head2 open_box( COLUMNS, BOX_ID )

Opens a box from columns.

=cut

sub open_box {
    my ( $self, $columns, $box_id ) = @_;

    return if !ref $columns eq 'ARRAY';

    foreach my $col ( @$columns ) {
        next if !ref $col->{boxes} eq 'ARRAY';

        foreach my $box ( @{ $col->{boxes} } ) {
            next if lc $box->{box_id} ne lc $box_id;

            $box->{open} = 1;

            return 1;
        }
    }

    return 0;
}


=pod

=head2 store_summary_layout( LAYOUT )

passes the summary layout to the layout's action's store_layout.

=cut


sub store_summary_layout {
    my ( $self, $layout ) = @_;

    return if !$layout->{action};

    my $action = CTX->lookup_action( lc $layout->{action} );

    return if !ref $action || !$action->can( 'store_layout' );

    $action->store_layout( $layout );
}





=pod

=head2 store_layout( COLUMNS, ACTION_NAME, USER_ID, GROUP_ID )

Stores the layout in form of dicole_summary_layout objects.

=cut

sub store_layout {
    my ( $self, $columns, $action_name, $uid, $gid ) = @_;

    return 0 if ref $columns ne 'ARRAY';

    my $objects = $self->_fetch_layout_objects(
        $action_name, $uid, $gid,
    ) || [];

    my %by_box_id = map { $_->{box_id} => $_ } @$objects;
    my %exists = ();
    my $colcount = 0;

    foreach my $col ( @{ $columns } ) {
        next if !ref $col eq 'HASH';
        next if !ref $col->{boxes} eq 'ARRAY';

        my $rowcount = 0;

        foreach my $box ( @{ $col->{boxes} } ) {
            next if !ref $box eq 'HASH' || !$box->{box_id};

            # UPDATE BOX LOCATION

            my $obj = $by_box_id{ $box->{box_id} };

            if ( !$obj ) {

                $obj = CTX->lookup_object( 'dicole_summary_layout' )->new;

                $obj->{user_id} = $uid;
                $obj->{group_id} = $gid;
                $obj->{action} = $action_name;
                $obj->{box_id} = $box->{box_id};
            }

            $obj->{col} = $colcount;
            $obj->{row} = $rowcount;
            $obj->{open} = $box->{open};

            $obj->save;

            $exists{ $obj->{box_id} } = 1;

            $rowcount++;
        }

        $colcount++;
    }

    # REMOVE USELESS STUFF

    foreach my $obj ( @$objects ) {
        next if $exists{ $obj->{box_id} };

        $obj->remove;
    }

    # IMPLEMENT WIDTH STORING!

    return 1;
}

=pod

=head2 revert_layout( ACTION_NAME, USER_ID, GROUP_ID )

Reverts to the default layout in form of destroying
personal dicole_summary_layout objects.

=cut

sub revert_layout {
    my ( $self, $action_name, $uid, $gid ) = @_;

    my $objects = $self->_fetch_layout_objects(
        $action_name, $uid, $gid,
    ) || [];

    $_->remove for @$objects;
}

=pod

=head2 get_column_layout( ACTION_NAME, USER_ID, GROUP_ID )

retrieves the layout for specified action, user and group.

returns an array reference similiar to I<parse_cookie> columns array.

=cut

sub get_column_layout {
    my ( $self, $action, $uid, $gid ) = @_;

    my $colwidths = Dicole::Settings->fetch_single_setting(
        tool => 'summary',
        user_id => $uid,
        group_id => $gid,
        attribute => 'column_widths',
    );
    
    $colwidths ||= Dicole::Settings->fetch_single_setting(
        tool => 'summary',
        user_id => 0,
        group_id => $gid,
        attribute => 'column_widths',
    ) if $gid;
    
    $colwidths ||= '270px,100%';
    $colwidths = [ split /\s*,\s*/, $colwidths ];
    my $colnro = scalar( @$colwidths );

    my $columns = [];

    for ( my $i = 0; $i < $colnro; $i++ ) {
        $columns->[$i]{width} = $colwidths->[$i];
        $columns->[$i]{abswidth} = $colwidths->[$i] =~ /px/ ? $colwidths->[$i] : undef;
        $columns->[$i]{boxes} = [];
    }

    my $objects = $self->_fetch_layout_objects(
        $action, $uid, $gid
    );

    foreach my $o ( @$objects ) {

        my $col = $o->{col};
        $col = $colnro - 1 unless $colnro > $col;

        my $row = $o->{row};
        $row++ while exists $columns->[ $col ]{boxes}[ $row ];

        $columns->[ $col ]{boxes}[ $row ]{box_id} = $o->{box_id};
        $columns->[ $col ]{boxes}[ $row ]{open} = $o->{open};
    }

    return $columns;
}





=pod

=head2 generate_summary_content( COLUMNS, TOOLS, USER_ID, GROUP_ID )

Returns the tool content parameters.

=cut

sub generate_summary_content {
    my ( $self, $columns, $tools, $uid, $gid, $open_param, $move_disabled ) = @_;

    return unless ref $columns eq 'ARRAY' && ref $tools eq 'ARRAY';

    my @actions = ();

    for my $tool ( @$tools ) {
        # static summaries
        if ( my $summary = $tool->{summary} ) {
            push @actions, split( /\s*,\s*/, $summary );
        }
        # user or group specific summaries
        if ( my $action_name = $tool->{summary_list} ) {
            my $summaries =  eval {
                CTX->lookup_action( $action_name )->execute( {
                    user_id => $uid,
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

    my %action_check = map { $_ => 1 } @actions;

    my $boxes = [];
    my $column = 0;
    my %exists = ();

    # GENERATE ACCORDING TO LAYOUT

    foreach my $col ( @$columns ) {

        $boxes->[ $column ]{width} = $col->{width};
        $boxes->[ $column ]{abswidth} = $col->{abswidth};

        foreach my $box ( @{ $col->{boxes} } ) {

            my $id = $box->{box_id};
            next unless $id && $action_check{ $id };

            my $content = $self->_generate_box_contents(
                $id, $box->{open}, $uid, $gid
            );

            next if !$content;

            $content->{box_id} = $id;
            $content->{move_disabled} = $move_disabled;
            $content->{submit} = Dicole::URL->create_from_current(
                params => { $open_param => $id }
            );

            undef $content->{content} unless $box->{open}; # template requires

            push @{ $boxes->[ $column ]{boxes} }, $content;

            $exists{ $id } = 1;
        }

        $column++;
    }

    # GENERATE MISSING BOXES

    my $col = 0;

    foreach my $action ( @actions ) {

        next if !$action || $exists{ $action };

        my $content = $self->_generate_box_contents(
            $action, 1, $uid, $gid
        );

        next if !$content;

        $content->{box_id} = $action;
        $content->{move_disabled} = $move_disabled;

        push @{ $boxes->[ $col ]{boxes} }, $content;

        $col = ( $col + 1 ) % $column;
    }

    return $boxes;
}





=pod

=head1 USED PRIVATE FUNCTIONS

 * _fetch_layout_objects
 * _generate_box_contents

=cut


#
# Returns the summary box content parameters from the passed action.
#

sub _generate_box_contents {
    my ( $self, $action_name, $open, $uid, $gid ) = @_;

    # If action name has ::, it means the action will receive
    # a fixed box_param. This is used to use the same action
    # to generate different boxes based on the value of this box_param.
    # An example would be user_feeds::4, in which user_feeds is
    # the action and 4 is the parameter to provide for it.
    my $box_param = undef;
    if ( $action_name =~ /::/ ) {
        ( $action_name, $box_param ) = split( /::/, $action_name, 2);
    }

    my $action = eval{ CTX->lookup_action( $action_name ) };

    return if !ref $action;

    $action->param('box_open', $open );
    $action->param('box_user', $uid );
    $action->param('box_group', $gid );
    $action->param('box_param', $box_param ) if $box_param;

    $action->param('target_user_id', $uid );
    $action->param('target_group_id', $gid );

    my $content = eval { $action->execute; };

    if ( my $msg = $@ ) {
        get_logger( LOG_APP )->error( $msg ) unless $msg =~ /^security error/;
        return undef;
    }

    return undef unless defined( $content );

    unless ( ref $content ) {
        my $box = Dicole::Box->new;
        $box->content( Dicole::Content::Text->new( text => $content ) );
        $content = $box->output;
    }
    return $content;
}


#
# Fetches the layout objects for some action, user and group.
#

sub _fetch_layout_objects {
    my ( $self, $action, $uid, $gid ) = @_;

    return CTX->lookup_object( 'dicole_summary_layout' )->fetch_group( {
                where => 'user_id = ? AND group_id = ? AND action = ?',
                value => [  $uid, $gid, $action ],
    } ) || [];
}

1;
