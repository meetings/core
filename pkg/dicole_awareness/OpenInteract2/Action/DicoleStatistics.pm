package OpenInteract2::Action::DicoleStatistics;
use strict;
use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use Dicole::Utility;

my $log;

# If the tasks are not specified, OI2 logs an error.
# This way we can just catch and ignore it without error messages in log ;)
sub get_user_points { die "not implemented yet"; }
sub get_user_ranking { die "not implemented yet"; }

sub get_most_active_users {
    my ( $self ) = @_;
    
    my $domain_id = $self->param('domain_id');
    my $group_id = $self->param('group_id');
    my $limit = $self->param('limit');
    my $exclude_users = $self->param('exclude_users') || [];

    my %found_user_ids = ();
    my @valid_actions = ();
    while ( scalar( @valid_actions ) < $limit ) {
        my $actions = CTX->lookup_object('statistics_action')->fetch_group( {
            where => 'domain_id = ?' .
                ' AND group_id = ? AND user_id != ?' .
                ' AND date = ? AND action = ?' .
                ' AND ' . Dicole::Utils::SQL->column_not_in( user_id => [ @$exclude_users, keys %found_user_ids ] ),
            value => [ $domain_id, $group_id ? $group_id : 0, 0, 0, 'user_active_daily_total' ],
            order => 'count desc',
            limit => 20,
        } );

        last unless scalar( @$actions );

        for my $action ( @$actions ) {
            $found_user_ids{ $action->user_id }++;
            next if $group_id &&  ! Dicole::Utils::User->belongs_to_group( $action->user_id, $group_id );
            push @valid_actions, $action;
            last if scalar( @valid_actions ) == $limit;
        }
    }

    my $users = Dicole::Utils::SPOPS->fetch_linked_objects(
        object_name => 'user',
        from_elements => \@valid_actions,
        link_field => 'user_id',
    );

    return $users;
}

sub get_most_active_groups {
    my ( $self ) = @_;
    
    my $domain_id = $self->param('domain_id');
    my $limit = $self->param('limit');
    my $from_groups = $self->param('from_groups') || [];
    my %groups_by_id = map { $_->id => $_ } @$from_groups;

    my $actions = CTX->lookup_object('statistics_action')->fetch_group( {
        where => 'domain_id = ? AND user_id = ?' .
            ' AND date = ? AND action = ?' .
            ' AND ' . Dicole::Utils::SQL->column_in( group_id => [ keys %groups_by_id ] ),
        value => [ $domain_id, 0, 0, 'user_active_daily_total' ],
        order => 'count desc',
    } );

    my @result = ();
    for my $action ( @$actions ) {
        push @result, $groups_by_id{ $action->group_id };
        last if scalar( @result ) == $limit;
    }

    return \@result;
}

sub get_user_count {
    my ( $self ) = @_;
    
    my $domain_id = $self->param('domain_id');
    my $group_id = $self->param('group_id');
    
    # Just get empty slots and count them
    my $slots = $group_id ? 
        $self->_all_group_user_usage_slots( $domain_id, $group_id, time + 100, time + 101 )
        :
        $self->_all_domain_user_usage_slots( $domain_id, time + 100, time + 101 );
    
    return scalar( @$slots );
}

sub get_user_based_data {
    my ( $self ) = @_;
    
    my $domain_id = $self->param('domain_id');
    my $group_id = $self->param('group_id');
    my $begin = $self->param('begin_epoch') || -1;
    my $end = $self->param('end_epoch') || time + 1;
    my $slots = $group_id ?
        $self->_all_group_user_usage_slots( $domain_id, $group_id, $begin, $end )
        :
        $self->_all_domain_user_usage_slots( $domain_id, $begin, $end );
    
    return $slots;
}

sub get_daily_based_data {
    my ( $self ) = @_;
    
    my $domain_id = $self->param('domain_id');
    my $group_id = $self->param('group_id');
    my $begin = $self->param('start_time') || -1;
    my $end = $self->param('end_time') || time + 1;
    my $slots = $group_id ?
        $self->_all_group_time_mode_usage_slots( $domain_id, $group_id, 'daily', $begin, $end )
        :
        $self->_all_domain_time_mode_usage_slots( $domain_id, 'daily', $begin, $end );
    
    return $slots;

}





sub get_weekly_based_data {
    my ( $self ) = @_;
    
    my $domain_id = $self->param('domain_id');
    my $group_id = $self->param('group_id');
    my $begin = $self->param('start_time') || -1;
    my $end = $self->param('end_time') || time + 1;
    my $slots = $group_id ?
        $self->_all_group_time_mode_usage_slots( $domain_id, $group_id, 'weekly', $begin, $end )
        :
        $self->_all_domain_time_mode_usage_slots( $domain_id, 'weekly', $begin, $end );
    
    return $slots;

}

sub domain_user_usage_csv {
    my ( $self ) = @_;

    my $domain_id = $self->param('domain_id');
    my $begin = $self->param('begin_epoch') || -1;
    my $end = $self->param('end_epoch') || time + 1;
    
    my $slots = $self->_all_domain_user_usage_slots( $domain_id, $begin, $end );
    
    print "name, active days, post count, comment count, edit count\n";
    for my $slot ( sort { lc($a->{last_name}) cmp lc($b->{last_name}) } @$slots ) {
        print join ', ', ( map { $slot->{$_} || 0 }
            ( qw/name user_active_daily blog_post_daily given_comment_daily wiki_change_daily / ) );
        print $/;
    }
}

sub _all_domain_user_usage_slots {
    my ( $self, $domain_id, $begin, $end ) = @_;
    
    my $ids = eval { CTX->lookup_action('dicole_domains')->execute(
        users_by_domain => { domain_id => $domain_id }
    ) } || [];
    
    return $self->_form_user_usage_slots_from_actions(
        $self->_fetch_domain_user_usage_objects( $domain_id, $begin, $end ), $ids
    );
}

sub _fetch_domain_user_usage_slots {
    my ( $self, $domain_id, $begin, $end ) = @_;
    
    return $self->_form_user_usage_slots_from_actions(
        $self->_fetch_domain_user_usage_objects( $domain_id, $begin, $end )
    );
}

sub _fetch_domain_user_usage_objects {
    my ( $self, $domain_id, $begin, $end ) = @_;
    
    return CTX->lookup_object('statistics_action')->fetch_group( {
        where => 'domain_id = ? AND group_id = ? AND user_id != ? AND date != ? AND date < ?' .
           ( $begin < 0 ? '' : ' AND date > ?'),
        value => [ $domain_id, 0, 0, 0, $end, ( $begin < 0 ? () : $begin ) ],
    } ) || [];
}

sub _form_user_usage_slots_from_actions {
    my ( $self, $objects, $return_users ) = @_;
    
    my @uids = $return_users ? @$return_users : map { $_->user_id } @$objects;
    my $users = Dicole::Utils::SPOPS->fetch_objects_hash(
        ids => \@uids,
        object_name => 'user',
    ) || {};
    
    my %slots = ();
    
    for my $user ( values %$users ) {
        $slots{ $user->id } = {
            user_id => $user->id,
            last_name => $user->last_name,
            first_name => $user->first_name,
            name => $user->first_name . ' ' . $user->last_name
        };
    }
    
    for my $o ( @$objects ) {
        next unless $users->{ $o->user_id };
        $slots{ $o->user_id }{ $o->action } ||= 0;
        $slots{ $o->user_id }{ $o->action } += $o->count;
    }
    
    return [ values %slots ];
}


sub domain_daily_usage_csv {
    my ( $self ) = @_;
    
    my $domain_id = $self->param('domain_id');
    my $begin = $self->param('begin_epoch') || -1;
    my $end = $self->param('end_epoch') || time + 1;
    
    my $slots = $self->_all_domain_time_mode_usage_slots( $domain_id, 'daily', $begin, $end );
    
    print "day, post count, comment count, edit count, active users\n";
    for my $s ( @$slots ) {
        print join ', ', ( map { $s->{$_} || 0 }
            ( qw/slot blog_post_daily given_comment_daily wiki_change_daily user_active_daily / ) );
        print $/;
    }
}

sub domain_weekly_usage_csv {
    my ( $self ) = @_;
    
    my $domain_id = $self->param('domain_id');
    my $begin = $self->param('begin_epoch') || -1;
    my $end = $self->param('end_epoch') || time + 1;
    
    my $slots = $self->_all_domain_time_mode_usage_slots( $domain_id, 'weekly', $begin, $end );
    
    print "week, post count, comment count, edit count, active users\n";
    for my $s ( @$slots ) {
        print join ', ', ( map { $s->{$_} || 0 }
            ( qw/slot blog_post_weekly given_comment_weekly wiki_change_weekly user_active_weekly / ) );
        print $/;
    }
}

sub _all_domain_time_mode_usage_slots {
    my ( $self, $domain_id, $mode, $begin, $end ) = @_;
    
    my $slots = $self->_fetch_domain_time_mode_usage_slots( $domain_id, $mode, $begin, $end );
    
    return $self->_fill_empty_time_mode_slots( $mode, $slots, $begin, $end );
}

sub _fetch_domain_time_mode_usage_slots {
    my ( $self, $domain_id, $mode, $begin, $end ) = @_;
    
    my $objects = CTX->lookup_object('statistics_action')->fetch_group( {
        where => 'domain_id = ? AND group_id = ? AND user_id = ? AND date != ? AND date < ?' .
            ( $begin < 0 ? '' : ' AND date > ?'),
        value => [ $domain_id, 0, 0, 0, $end, ( $begin < 0 ? () : $begin ) ],
    } ) || [];
    
    my %slots = ();
    
    for my $o ( @$objects ) {
        next unless $o->action =~ /$mode/;
        my $slot = _epoch2modeslot( $mode, $o->{date} );
        $slots{ $slot } ||= { slot => $slot, epoch => $o->date };
        $slots{ $slot }{ $o->action } = $o->count;
    }
    
    return [ values %slots ];
}


sub group_user_usage_csv {
    my ( $self ) = @_;

    my $domain_id = $self->param('domain_id');
    my $group_id = $self->param('group_id');
    my $begin = $self->param('begin_epoch') || -1;
    my $end = $self->param('end_epoch') || time + 1;
    
    my $slots = $self->_all_group_user_usage_slots( $domain_id, $group_id, $begin, $end );
    
    print "name, active days, post count, comment count, edit count\n";
    for my $slot ( sort { lc($a->{last_name}) cmp lc($b->{last_name}) } @$slots ) {
        print join ', ', ( map { $slot->{$_} || 0 }
            ( qw/name user_active_daily blog_post_daily given_comment_daily wiki_change_daily / ) );
        print $/;
    }
}

sub _all_group_user_usage_slots {
    my ( $self, $domain_id, $group_id, $begin, $end ) = @_;
    
    my $possible_ids = eval { CTX->lookup_action('dicole_domains')->execute(
        users_by_group => { domain_id => $domain_id, group_id => $group_id }
    ) };
    my %possible_ids = $possible_ids ? map { $_ => 1 } @$possible_ids : undef;
    
    my $group = CTX->lookup_object('groups')->fetch( $group_id );
    die unless $group;
    
    my $users = $group->user;
    my $ids = [ map { $_->id } @$users ];
    $ids = [ grep { $possible_ids{ $_ } } @$ids ];
    
    return $self->_form_user_usage_slots_from_actions(
        $self->_fetch_group_user_usage_objects( $domain_id, $group_id, $begin, $end ), $ids
    );
}

sub _fetch_group_user_usage_slots {
    my ( $self, $domain_id, $group_id, $begin, $end ) = @_;
    
    return $self->_form_user_usage_slots_from_actions(
        $self->_fetch_group_user_usage_objects( $domain_id, $group_id, $begin, $end )
    );
}

sub _fetch_group_user_usage_objects {
    my ( $self, $domain_id, $group_id, $begin, $end ) = @_;
    
    return CTX->lookup_object('statistics_action')->fetch_group( {
        where => 'domain_id = ? AND group_id = ? AND user_id != ? AND date != ? AND date < ?' .
           ( $begin < 0 ? '' : ' AND date > ?'),
        value => [ $domain_id, $group_id, 0, 0, $end, ( $begin < 0 ? () : $begin ) ],
    } ) || [];
}


sub group_daily_usage_csv {
    my ( $self ) = @_;
    
    my $domain_id = $self->param('domain_id');
    my $group_id = $self->param('group_id');
    my $begin = $self->param('begin_epoch') || -1;
    my $end = $self->param('end_epoch') || time + 1;
    
    my $slots = $self->_all_group_time_mode_usage_slots( $domain_id, $group_id, 'daily', $begin, $end );
    
    print "day, post count, comment count, edit count, active users\n";
    for my $s ( @$slots ) {
        print join ', ', ( map { $s->{$_} || 0 }
            ( qw/slot blog_post_daily given_comment_daily wiki_change_daily user_active_daily / ) );
        print $/;
    }
}

sub group_weekly_usage_csv {
    my ( $self ) = @_;
    
    my $domain_id = $self->param('domain_id');
    my $group_id = $self->param('group_id');
    my $begin = $self->param('begin_epoch') || -1;
    my $end = $self->param('end_epoch') || time + 1;
    
    my $slots = $self->_all_group_time_mode_usage_slots( $domain_id, $group_id, 'weekly', $begin, $end );
    
    print "week, post count, comment count, edit count, active users\n";
    for my $s ( @$slots ) {
        print join ', ', ( map { $s->{$_} || 0 }
            ( qw/slot blog_post_weekly given_comment_weekly wiki_change_weekly user_active_weekly / ) );
        print $/;
    }
}

sub _all_group_time_mode_usage_slots {
    my ( $self, $domain_id, $group_id, $mode, $begin, $end ) = @_;
    
    my $slots = $self->_fetch_group_time_mode_usage_slots( $domain_id, $group_id, $mode, $begin, $end );
    
    return $self->_fill_empty_time_mode_slots( $mode, $slots, $begin, $end );
}

sub _fetch_group_time_mode_usage_slots {
    my ( $self, $domain_id, $group_id, $mode, $begin, $end ) = @_;
    
    my $objects = CTX->lookup_object('statistics_action')->fetch_group( {
        where => 'domain_id = ? AND group_id = ? AND user_id = ? AND date != ? AND date < ?' .
            ( $begin < 0 ? '' : ' AND date > ?'),
        value => [ $domain_id, $group_id, 0, 0, $end, ( $begin < 0 ? () : $begin ) ],
    } ) || [];
    
    my %slots = ();
    
    for my $o ( @$objects ) {
        next unless $o->action =~ /$mode/;
        my $slot = _epoch2modeslot( $mode, $o->{date} );
        $slots{ $slot } ||= { slot => $slot, epoch => $o->date };
        $slots{ $slot }{ $o->action } = $o->count;
    }
    
    return [ values %slots ];
}



sub _fill_empty_time_mode_slots {
    my ( $self, $mode, $slots, $begin, $end ) = @_;
    
    my @ordered_slots = sort { $a->{epoch} <=> $b->{epoch} } @$slots;
    my @all_slots = ();
    my $last_slot;
    
    unless ( $begin < 0 ) {
        $last_slot = { slot => _epoch2modeslot( $mode, $begin ), epoch => $begin }
    }
    
    for my $slot ( @ordered_slots ) {
        push @all_slots, @{ $self->_get_empty_time_mode_slots( $mode, $last_slot, $slot ) };
        push @all_slots, $slot;
        $last_slot = $slot;
    }
    
    my $end_slot_name = _epoch2modeslot( $mode, $end );
    if ( $last_slot->{epoch} < $end && $last_slot->{slot} ne $end_slot_name ) {
        push @all_slots, @{ $self->_get_empty_time_mode_slots(
            $mode, $last_slot, { slot => $end_slot_name, epoch => $end }
        ) };
    }
    
    return \@all_slots
    
}

sub _get_empty_time_mode_slots {
    my ( $self, $mode, $last_slot, $now_slot ) = @_;
    
    return $mode eq 'daily' ? $self->_get_empty_time_slots( $last_slot, $now_slot ) :
        $self->_get_empty_time_weekslots( $last_slot, $now_slot );
}

sub _get_empty_time_slots {
    my ( $self, $last_slot, $now_slot ) = @_;
    return [] unless $last_slot && $last_slot->{slot} && $now_slot && $now_slot->{slot};
    my $last = _slot2date( $last_slot->{slot} );
    $last->add( days => 1 );
    my @slots = ();
    while ( $last->epoch < $now_slot->{epoch} && _epoch2slot( $last->epoch ) ne $now_slot->{slot} ) {
        push @slots, { slot => _epoch2slot( $last->epoch ), epoch => $last->epoch };
        $last->add( days => 1 );
    }
    return \@slots;
}

sub _get_empty_time_weekslots {
    my ( $self, $last_slot, $now_slot ) = @_;
    return [] unless $last_slot && $last_slot->{slot} && $now_slot && $now_slot->{slot};
    my $last = _weekslot2date( $last_slot->{slot} );
    $last->add( days => 7 );
    my @slots = ();
    while ( $last->epoch < $now_slot->{epoch} && _epoch2weekslot( $last->epoch ) ne $now_slot->{slot} ) {
        push @slots, { slot => _epoch2weekslot( $last->epoch ), epoch => $last->epoch };
        $last->add( days => 7 );
    }
    return \@slots;
}



# DATA GATHERING FUNCTIONS

sub update_domains {
    my ( $self ) = @_;
    
    my $domains = CTX->lookup_object('dicole_domain')->fetch_group || [];
    
    for my $domain ( @$domains ) {
        if ( my $skip_list = $self->param('skip_domains') ) {
            my %skip_lookup = map { $_ => 1 } @$skip_list;
            next if $skip_lookup{ $domain->id };
        }
        if ( my $only_list = $self->param('only_domains') ) {
            my %only_lookup = map { $_ => 1 } @$only_list;
            next unless $only_lookup{ $domain->id };
        }
        $self->_update_domain( $domain->id );
    }
    
    return 1;
}

sub update_domain {
    my ( $self ) = @_;

    return $self->_update_domain( $self->param('domain_id') );
}

sub update_group {
    my ( $self ) = @_;

    $self->_update_group( $self->param('domain_id'), $self->param('group_id') );
}

sub update_user_in_group {
    my ( $self ) = @_;

    $self->_update_user_in_group( $self->param('domain_id'), $self->param('group_id'), $self->param('user_id') );
}



sub _update_domain {
    my ( $self, $domain_id ) = @_;

    my $group_ids = CTX->lookup_action('dicole_domains')->execute(
        groups_by_domain => { domain_id => $domain_id }
    );

    foreach my $group_id ( @$group_ids ) {
        $self->_update_group( $domain_id, $group_id );
    }
    
    $self->_update_domain_totals( $domain_id );
    $self->_update_domain_user_totals( $domain_id );
}

sub _update_domain_totals {
    my ( $self, $domain_id ) = @_;

    
    print "Updating domain $domain_id blogs totals$/";
    $self->_store_sum_both_domain_actions( $domain_id, 'blog_post' );
    print "Updating domain $domain_id comments totals$/";
    $self->_store_sum_both_domain_actions( $domain_id, 'given_comment' );
    print "Updating domain $domain_id wiki_edits totals$/";
    $self->_store_sum_both_domain_actions( $domain_id, 'wiki_change' );
    print "Updating domain $domain_id event_createds totals$/";
    $self->_store_sum_both_domain_actions( $domain_id, 'event_created' );
    
    print "Updating domain $domain_id activity totals$/";
    $self->_update_domain_activity_actions( $domain_id );

    print "Updating domain $domain_id all alltime totals$/";
    $self->_update_alltime_totals( $domain_id, 0, 0 );
}

sub _store_sum_both_domain_actions {
    my ( $self, $domain_id, $action ) = @_;

    $self->_store_sum_domain_actions(
        $domain_id, $action . '_daily'
    );

    $self->_store_sum_domain_actions(
        $domain_id, $action . '_weekly'
    );
}

sub _store_sum_domain_actions {
    my ( $self, $domain_id, $action ) = @_;
    
    my $objects = CTX->lookup_object('statistics_action')->fetch_group( {
        where => 'domain_id = ? AND group_id != ? AND user_id = ? AND action = ? ',
        value => [ $domain_id, 0, 0, $action ],
        order => 'date desc',
    } );
    
    my %totals = ();
    for my $object ( @$objects ) {
        $totals{ $object->date } ||= 0;
        $totals{ $object->date } += $object->count;
    }
    
    for my $epoch ( keys %totals ) {
        $self->_create_or_update_object(
            $domain_id, 0, 0, $action, $epoch, $totals{ $epoch }
        );
    }
}

sub _update_domain_activity_actions {
    my ( $self, $domain_id ) = @_;
    
    # iterate all activities with group as target
    # add point for each individual day
    my $actions = CTX->lookup_object('logged_action')->fetch_iterator( {
        where => 'domain_id = ? AND user_id != ?',
        value => [ $domain_id, 0 ],
    } );
    
    my %slots = ();
    my %week_slots = ();
    my %slots_check = ();
    my %week_slots_check = ();
    while ( $actions->has_next ) {
        my $a = $actions->get_next;
        
        my $slot = _epoch2slot( $a->time );
        unless ( $slots_check{ $slot }{$a->user_id} ) {
            $slots_check{ $slot }{$a->user_id}++;
            push @{ $slots{ $slot } }, $a->user_id;
        }
        my $week_slot = _epoch2weekslot( $a->time );
        unless ( $week_slots_check{ $week_slot }{$a->user_id} ) {
            $week_slots_check{ $week_slot }{$a->user_id}++;
            push @{ $week_slots{ $week_slot } }, $a->user_id;
        }
    }
    
    $self->_store_actions_from_slots(
        'daily', $domain_id, 0, 0, 'user_active_daily', \%slots
    );
    $self->_store_actions_from_slots(
        'weekly', $domain_id, 0, 0, 'user_active_weekly', \%week_slots
    );
}



sub _update_domain_user_totals {
    my ( $self, $domain_id ) = @_;
    
    print "Updating domain $domain_id user blogs totals$/";
    $self->_store_sum_both_domain_user_actions( $domain_id, 'blog_post' );
    print "Updating domain $domain_id user comments totals$/";
    $self->_store_sum_both_domain_user_actions( $domain_id, 'given_comment' );
    print "Updating domain $domain_id user wiki_edits totals$/";
    $self->_store_sum_both_domain_user_actions( $domain_id, 'wiki_change' );
    print "Updating domain $domain_id user event_createds totals$/";
    $self->_store_sum_both_domain_user_actions( $domain_id, 'event_created' );
    
    print "Updating domain $domain_id user activity totals$/";
    $self->_update_domain_user_activity_actions( $domain_id );

    print "Updating domain $domain_id user all alltime totals$/";
    my $user_ids = CTX->lookup_action('dicole_domains')->execute(
        users_by_domain => { domain_id => $domain_id }
    );
    $self->_update_alltime_totals( $domain_id, 0, $_ ) for @$user_ids;
}

sub _store_sum_both_domain_user_actions {
    my ( $self, $domain_id, $action ) = @_;

    $self->_store_sum_domain_user_actions(
        $domain_id, $action . '_daily'
    );

    $self->_store_sum_domain_user_actions(
        $domain_id, $action . '_weekly'
    );
}

sub _store_sum_domain_user_actions {
    my ( $self, $domain_id, $action ) = @_;
    
    my $objects = CTX->lookup_object('statistics_action')->fetch_group( {
        where => 'domain_id = ? AND group_id != ? AND user_id != ? AND date != ? AND action = ?',
        value => [ $domain_id, 0, 0, 0, $action ],
        order => 'date desc',
    } );
    
    my %totals = ();
    for my $object ( @$objects ) {
        $totals{ $object->user_id }{ $object->date } ||= 0;
        $totals{ $object->user_id }{ $object->date } += $object->count;
    }
    
    for my $uid ( keys %totals ) {
#         my $sum = 0;
        for my $epoch ( keys %{ $totals{ $uid } } ) {
            my $count = $totals{ $uid }->{ $epoch };
            $self->_create_or_update_object(
                $domain_id, 0, $uid, $action, $epoch, $count
            );
#             $sum += $count;
        }
#         $self->_create_or_update_object(
#             $domain_id, 0, $uid, $action, 0, $sum
#         );
    }
}

sub _update_domain_user_activity_actions {
    my ( $self, $domain_id ) = @_;
    
    # iterate all activities with group as target
    # add point for each individual day
    my $actions = CTX->lookup_object('logged_action')->fetch_iterator( {
        where => 'domain_id = ? AND user_id != ?',
        value => [ $domain_id, 0 ],
    } );
    
    my %counts = ();
    my %week_counts = ();
    while ( $actions->has_next ) {
        my $a = $actions->get_next;
        
        my $epoch = _slot2epoch( _epoch2slot( $a->time ) );
        $counts{ $a->user_id }{ $epoch } = 1;
        
        my $week_epoch = _weekslot2epoch( _epoch2weekslot( $a->time ) );
        $week_counts{ $a->user_id }{ $week_epoch } = 1;
    }
    
    for my $uid ( keys %counts ) {
#         my $sum = 0;
        for my $epoch ( keys %{ $counts{ $uid } } ) {
            my $count = $counts{ $uid }->{ $epoch };
            $self->_create_or_update_object(
                $domain_id, 0, $uid, 'user_active_daily', $epoch, $count
            );
#             $sum += $count;
        }
#         $self->_create_or_update_object(
#             $domain_id, 0, $uid,  'user_active_daily', 0, $sum
#         );
    }
    
    for my $uid ( keys %week_counts ) {
#         my $sum = 0;
        for my $epoch ( keys %{ $week_counts{ $uid } } ) {
            my $count = $week_counts{ $uid }->{ $epoch };
            $self->_create_or_update_object(
                $domain_id, 0, $uid, 'user_active_weekly', $epoch, $count
            );
#             $sum += $count;
        }
#         $self->_create_or_update_object(
#             $domain_id, 0, $uid,  'user_active_weekly', 0, $sum
#         );
    }
}



sub _update_group {
    my ( $self, $domain_id, $group_id ) = @_;
    
    my $group = CTX->lookup_object('groups')->fetch( $group_id );
    next unless $group;
    my $users = $group->user || [];
    
    for my $user ( @$users ) {
        $self->_update_user_in_group( $domain_id, $group_id, $user->id );
    }
    
    $self->_update_group_totals( $domain_id, $group_id );
}

sub _update_group_totals {
    my ( $self, $domain_id, $group_id ) = @_;

    print "Updating group $group_id blogs totals$/";
    $self->_store_sum_both_group_actions( $domain_id, $group_id, 'blog_post' );
    print "Updating group $group_id comments totals$/";
    $self->_store_sum_both_group_actions( $domain_id, $group_id, 'given_comment' );
    print "Updating group $group_id wiki_edits totals$/";
    $self->_store_sum_both_group_actions( $domain_id, $group_id, 'wiki_change' );
    print "Updating group $group_id event_createds totals$/";
    $self->_store_sum_both_group_actions( $domain_id, $group_id, 'event_created' );

    print "Updating group $group_id activity totals$/";
    $self->_store_sum_both_group_actions( $domain_id, $group_id, 'user_active' );

    print "Updating group $group_id all alltime totals$/";
    $self->_update_alltime_totals( $domain_id, $group_id, 0 );
}

sub _store_sum_both_group_actions {
    my ( $self, $domain_id, $group_id, $action ) = @_;

    $self->_store_sum_group_actions(
        $domain_id, $group_id, $action . '_daily'
    );

    $self->_store_sum_group_actions(
        $domain_id, $group_id, $action . '_weekly'
    );
}

sub _store_sum_group_actions {
    my ( $self, $domain_id, $group_id, $action ) = @_;
    
    my $objects = CTX->lookup_object('statistics_action')->fetch_group( {
        where => 'domain_id = ? AND group_id = ? AND user_id != ? AND action = ? ',
        value => [ $domain_id, $group_id, 0, $action ],
        order => 'date desc',
    } );
    
    my %totals = ();
    for my $object ( @$objects ) {
        $totals{ $object->date } ||= 0;
        $totals{ $object->date } += $object->count;
    }
    
    for my $epoch ( keys %totals ) {
        $self->_create_or_update_object(
            $domain_id, $group_id, 0, $action, $epoch, $totals{ $epoch }
        );
    }
}



sub _update_user_in_group {
    my ( $self, $domain_id, $group_id, $user_id ) = @_;
    
    print "Updating group $group_id user $user_id blogs$/";
    $self->_update_blogs_actions( $domain_id, $group_id, $user_id );
    print "Updating group $group_id user $user_id comments$/";
    $self->_update_comments_actions( $domain_id, $group_id, $user_id );
    print "Updating group $group_id user $user_id wiki_edits$/";
    $self->_update_wiki_actions( $domain_id, $group_id, $user_id );
    print "Updating group $group_id user $user_id event_createds$/";
    $self->_update_event_actions( $domain_id, $group_id, $user_id );
    print "Updating group $group_id user $user_id activity$/";
    $self->_update_activity_actions( $domain_id, $group_id, $user_id );

    print "Updating group $group_id user $user_id all alltime totals$/";
    $self->_update_alltime_totals( $domain_id, $group_id, $user_id );

}

sub _update_activity_actions {
    my ( $self, $domain_id, $group_id, $user_id ) = @_;
    
    # iterate all activities with group as target
    # add point for each individual day
    my $actions = CTX->lookup_object('logged_action')->fetch_iterator( {
        where => 'domain_id = ? AND target_group_id = ? AND user_id = ?',
        value => [ $domain_id, $group_id, $user_id ],
    } );
    
    my %slots = ();
    my %week_slots = ();
    my %slots_check = ();
    my %week_slots_check = ();
    while ( $actions->has_next ) {
        my $a = $actions->get_next;
        
        my $slot = _epoch2slot( $a->time );
        unless ( $slots_check{ $slot } ) {
            $slots_check{ $slot }++;
            push @{ $slots{ $slot } }, 1;
        }
        my $week_slot = _epoch2weekslot( $a->time );
        unless ( $week_slots_check{ $week_slot } ) {
            $week_slots_check{ $week_slot }++;
            push @{ $week_slots{ $week_slot } }, 1;
        }
    }
    
    $self->_store_actions_from_slots(
        'daily', $domain_id, $group_id, $user_id, 'user_active_daily', \%slots
    );
    $self->_store_actions_from_slots(
        'weekly', $domain_id, $group_id, $user_id, 'user_active_weekly', \%week_slots
    );
}

sub _update_wiki_actions {
    my ( $self, $domain_id, $group_id, $user_id ) = @_;

    my $versions = CTX->lookup_object('wiki_version')->fetch_group( {
        where => 'groups_id = ? AND creator_id = ?',
        value => [ $group_id, $user_id ],
    } );
    
    my %slots = ();
    my %week_slots = ();
    my %slots_check = ();
    my %week_slots_check = ();
    
    for my $vn ( @$versions ) {
        # All change types, one change per page per day
        my $slot = _epoch2slot( $vn->creation_time );
        unless ( $slots_check{ $slot }{ $vn->page_id } ) {
            $slots_check{ $slot }{ $vn->page_id }++;
            
            push @{ $slots{ $slot } }, $vn->page_id;
        }
        
        # Also per one change per page per day for weekly
        my $week_slot = _epoch2weekslot( $vn->creation_time );
        unless ( $week_slots_check{ $week_slot }{$slot}{ $vn->page_id } ) {
            $week_slots_check{ $week_slot }{$slot}{ $vn->page_id }++;
            push @{ $week_slots{ $week_slot } }, [ $vn->creation_time, $vn->page_id ];
        }
    }

    $self->_store_actions_from_slots(
        'daily', $domain_id, $group_id, $user_id, 'wiki_change_daily', \%slots
    );
    $self->_store_actions_from_slots(
        'weekly', $domain_id, $group_id, $user_id, 'wiki_change_weekly', \%week_slots
    );
}

sub _update_event_actions {
    my ( $self, $domain_id, $group_id, $user_id ) = @_;

    my $events = CTX->lookup_object('events_event')->fetch_group( {
        where => 'group_id = ? AND creator_id = ?',
        value => [ $group_id, $user_id ],
    } );
    
    my %slots = ();
    my %week_slots = ();
    
    for my $event ( @$events ) {
        my $slot = _epoch2slot( $event->created_date );
        push @{ $slots{ $slot } }, $event->event_id;
        
        my $week_slot = _epoch2weekslot( $event->created_date );
        push @{ $week_slots{ $week_slot } }, $event->event_id;
    }

    $self->_store_actions_from_slots(
        'daily', $domain_id, $group_id, $user_id, 'event_created_daily', \%slots
    );
    $self->_store_actions_from_slots(
        'weekly', $domain_id, $group_id, $user_id, 'event_created_weekly', \%week_slots
    );
}

sub _update_blogs_actions {
    my ( $self, $domain_id, $group_id, $user_id ) = @_;

   
    my $entries = CTX->lookup_object('blogs_entry')->fetch_group( {
        where => 'user_id = ? AND group_id = ?',
        value => [ $user_id, $group_id ],
    } );
    
    $self->_store_both_actions_from_objects(
        $domain_id, $group_id, $user_id, 'blog_post', $entries, 'date'
    );
    
}

sub _update_comments_actions {
    my ( $self, $domain_id, $group_id, $user_id ) = @_;
    
    my $comments_given = CTX->lookup_object('comments_post')->fetch_group( {
        from => [ qw( dicole_comments_thread dicole_comments_post ) ],
        where => 'dicole_comments_post.user_id = ? AND ' .
            'dicole_comments_thread.thread_id = dicole_comments_post.thread_id AND ' .
            'dicole_comments_thread.group_id = ?',
        value => [ $user_id, $group_id ],
    } );

    $self->_store_both_actions_from_objects(
        $domain_id, $group_id, $user_id, 'given_comment', $comments_given, 'date'
    );
}


# It might be a problem that this does not add objects for 0 counts
# If this becomes a problem, it can be fixed by collecting all
# passed through domains, user ids, grou ids and actions to bins
# and cycle through the bins to store objects..
# this still does not store 0 counts for actions which haven't got
# a single acion in the db. For this a list of actions should
# be provided for the function. And still users and groups with
# no actions would result in no 0 count entries :(
# for this, lists of users and groups should be present.
sub _update_alltime_totals {
    my ( $self, $domain_id, $group_id, $user_id ) = @_;

    my $actions = CTX->lookup_object('statistics_action')->fetch_iterator( {
        where => 'domain_id = ?' .
            ( $user_id ? ' AND user_id = ?' : '' ) .
            ( $group_id ? ' AND group_id = ?' : '' ) .
            ' AND date != ?',
        value => [ $domain_id, $user_id ? $user_id : (), $group_id ? $group_id : () , 0 ],
    } );

    my %totals = ();

    while ( $actions->has_next ) {
        my $a = $actions->get_next;
        my $string = join '-', ( $a->domain_id, $a->group_id, $a->user_id, $a->action );
        $totals{ $string } ||= 0;
        $totals{ $string } += $a->count;
    }

    for my $key ( keys %totals ) {
        my ( $domain_id, $group_id, $user_id, $action ) = split '-', $key, 4;
        $action .= '_total';
        $self->_create_or_update_object(
            $domain_id, $group_id, $user_id, $action, 0, $totals{ $key }
        );
    }
}



sub _store_both_actions_from_objects {
    my ( $self, $domain_id, $group_id, $user_id, $action, $objects, $key ) = @_;
    
    $self->_store_actions_from_objects(
        'daily', $domain_id, $group_id, $user_id, $action . '_daily', $objects, $key
    );
    $self->_store_actions_from_objects(
        'weekly', $domain_id, $group_id, $user_id, $action . '_weekly', $objects, $key
    );
}

sub _store_actions_from_objects {
    my ( $self, $mode, $domain_id, $group_id, $user_id, $action, $objects, $key ) = @_;
    
    $self->_store_actions_from_slots(
        $mode, $domain_id, $group_id, $user_id, $action,
        $self->_create_slots_from_objects( $mode, $objects, $key ),
    );
}

sub _store_actions_from_slots {
    my ( $self, $mode, $domain_id, $group_id, $user_id, $action, $slots ) = @_;
    
    $log ||= get_logger( LOG_APP );

    my @data = ();
    for my $slot ( keys %$slots ) {
        my $epoch = $mode eq 'daily' ? _slot2epoch( $slot ) : _weekslot2epoch( $slot );
        push @data, { date => $epoch, count => scalar( @{ $slots->{ $slot } } ) };
    }
    
    @data = sort { $a->{date} <=> $b->{date} } @data;
    
    my $objects = CTX->lookup_object('statistics_action')->fetch_group( {
        where => 'domain_id = ? AND group_id = ? AND user_id = ? AND action = ? ',
        value => [ $domain_id, $group_id, $user_id, $action ],
        order => 'date asc',
    } );
    
    my $new;
    my $old;
    
    while ( scalar( @data ) || scalar( @$objects ) ) {
        $new ||= pop @data;
        $old ||= pop @$objects;
        
        if ( $new->{date} > $old->{date} ) {
            my $object = $self->_create_object(
                $domain_id, $group_id, $user_id,
                $action, $new->{date}, $new->{count}
            );
            $log->is_info && $log->info(
                "Created statistics action " . join (' ,', ( $domain_id, $group_id, $user_id, $action, $new->{date}, $new->{count} ) )
            );
            $new = undef;
        }
        elsif ( $new->{date} < $old->{date} ) {
            $old->remove;
            $log->is_info && $log->info(
                "Removed statistics action " . join (' ,', ( $domain_id, $group_id, $user_id, $action, $new->{date}, $new->{count} ) )
            );
            $old = undef;
        }
        elsif ( $new->{ count } != $old->{count} ) {
            $old->count( $new->{count} );
            $old->save;
            $log->is_info && $log->info(
                "Updated statistics action " . join (' ,', ( $domain_id, $group_id, $user_id, $action, $new->{date}, $new->{count} ) )
            );
            $old = undef;
            $new = undef;
        }
        else {
            $log->is_info && $log->info(
                "Skipped statistics action " . join (' ,', ( $domain_id, $group_id, $user_id, $action, $new->{date}, $new->{count} ) )
            );
            $old = undef;
            $new = undef;
        }
    }
    
}



sub _create_object {
    my ( $self, $domain_id, $group_id, $user_id, $action, $date, $count ) = @_;

    my $o = CTX->lookup_object('statistics_action')->new;
    $o->domain_id( $domain_id );
    $o->group_id( $group_id );
    $o->user_id( $user_id );
    $o->action( $action );
    $o->date( $date );
    $o->count( $count );
    
    $o->save;
}

sub _create_or_update_object {
    my ( $self, $domain_id, $group_id, $user_id, $action, $date, $count ) = @_;
    
    $log ||= get_logger( LOG_APP );
    
    my $objects = CTX->lookup_object('statistics_action')->fetch_group( {
        where => 'domain_id = ? AND group_id = ? AND user_id = ? AND action = ? AND date = ?',
        value => [ $domain_id, $group_id, $user_id, $action, $date ],
    } ) || [];
    
    my $object = shift @$objects;
    $_->remove for @$objects;
    
    if ( $object ) {
        if ( $count == $object->count ) {
            $log->is_info && $log->info(
                "Skipped statistics action " . join (' ,', ( $domain_id, $group_id, $user_id, $action, $date, $count ) )
            );
        }
        else {
            $object->count( $count );
            $object->save;
            $log->is_info && $log->info(
                "Updated statistics action " . join (' ,', ( $domain_id, $group_id, $user_id, $action, $date, $count ) )
            );
        }
    }
    else {
        my $object = $self->_create_object(
            $domain_id, $group_id, $user_id,
            $action, $date, $count
        );
        $log->is_info && $log->info(
            "Created statistics action " . join (' ,', ( $domain_id, $group_id, $user_id, $action, $date, $count ) )
        );
    }
}

sub _create_slots_from_objects {
    my ( $self, $mode, $objects, $key ) = @_;
    
    my %slots = ();
    for my $object ( @$objects ) {
        my $slot = $mode eq 'daily' ? _epoch2slot( $object->{$key} ) : _epoch2weekslot( $object->{$key} );
        push @{ $slots{ $slot } }, $object;
    }
    return \%slots;
}

sub _sum_actions_from_slots {
    my ( $self, $slots ) = @_;
    
    my @values = values %$slots;
    my $total = 0;
    for my $value ( @values ) {
        $total += scalar( @$value );
    }

    return $total;
}



sub _epoch2modeslot {
    my ( $mode, $epoch ) = @_;
    return ( $mode eq 'daily' ? _epoch2slot( $epoch ) : _epoch2weekslot( $epoch ) );
}

sub _epoch2slot {
    my ( $date ) = @_;
    my $dt = DateTime->from_epoch( epoch => $date );
    $dt->set_time_zone( 'Europe/Helsinki' );
    return $dt->ymd;
}

sub _slot2date {
    my ( $slot , $day_start ) = @_;
    my ( $year, $month, $day ) = split '-', $slot;
    return DateTime->new(
        year => $year, month => $month, day => $day, hour => $day_start ? 0 : 12, time_zone => 'Europe/Helsinki'
    );
}

sub _slot2epoch {
    return _slot2date( @_ )->epoch;
}

sub _epoch2weekslot {
    my ( $date ) = @_;
    my $dt = DateTime->from_epoch( epoch => $date );
    $dt->set_time_zone( 'Europe/Helsinki' );
    my ($week_year, $week_number) = $dt->week;
    return $week_year .'-'. sprintf("%02d",$week_number );
}

sub _weekslot2date {
    my ( $slot ) = @_;
    my ( $year, $week ) = split '-', $slot;
    my $dt = DateTime->new(
        year => $year, hour => 12, time_zone => 'Europe/Helsinki'
    );
    $dt->add( days => 7 * ( $week - 1 ) );
    return $dt;
}

sub _weekslot2epoch {
    return _weekslot2date( @_ )->epoch;
}

1;
