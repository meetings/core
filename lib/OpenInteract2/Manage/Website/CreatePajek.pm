package OpenInteract2::Manage::Website::CreatePajek;

use strict;
use base qw( OpenInteract2::Manage::Website );
use OpenInteract2::Context   qw( CTX );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Exception qw( oi_error );

my $log = ();

sub get_name {
    return 'create_pajek';
}

sub get_brief_description {
    return "Creates input file for Pajek for social network analysis";
}

sub get_parameters {
    my ( $self ) = @_;
    return {
        group => {
        	description => 'Get network of users who belong to a certain group',
        	is_required => 'no',
    	},
    };
}

sub run_task {
    my ( $self ) = @_;

    my $posts = CTX->lookup_object('weblog_posts');
    my $comments = CTX->lookup_object('weblog_comments');
    my $trackbacks = CTX->lookup_object('weblog_trackbacks');
    my $users = CTX->lookup_object('user');
    
    # Nodes, i.e. user_id's
    my %nodes = ();
    my $number_of_nodes = undef;
    my $user_iter = $users->fetch_iterator( { } );
    while ( $user_iter->has_next ) {
      my $user = $user_iter->get_next;
      $nodes{$user->id} = $user->{first_name} . ' ' . $user->{last_name};
      $number_of_nodes++;
    }    
    
    # Create lookup table for posts, pointing at writers
    my %post_lookup = ();    
    my $post_iter = $posts->fetch_iterator( { } );
    while ( $post_iter->has_next ) {
      my $post = $post_iter->get_next;
      $post_lookup{$post->id} = $post->{writer};
    }

    # Table is in format node1,node2 => weight, i.e. node1 linking to node2 with weight X
    my %pajek_table = ();
    
    # Figure out who comments whom
    my $comment_iter = $comments->fetch_iterator( { } );
    while ( $comment_iter->has_next ) {
      my $comment = $comment_iter->get_next;
      $pajek_table{ $comment->{user_id} . ',' . $post_lookup{$comment->{post_id}} }++;
    }

    # Figure out who trackbacks whom
    my $trackback_iter = $trackbacks->fetch_iterator( { } );
    while ( $trackback_iter->has_next ) {
      my $trackback = $trackback_iter->get_next;
      $pajek_table{ $post_lookup{$trackback->{reply_id}} . ',' . $post_lookup{$trackback->{post_id}} }++;
    }

    # Initial output string
    my $output = "*Network\n";
    
    # Create Vertices
    $output .= "*Vertices $number_of_nodes\n";
    foreach my $node ( sort { $a <=> $b } keys %nodes ) {
      next if !$node || !$nodes{$node};
      $output .= $node . ' "' . $nodes{$node} .'" 0.0 0.0 0.0 ic Red bc Black' . "\n";
    }
    
    # Create Arcs
    $output .= "*Arcs\n";
    foreach my $entry ( sort keys %pajek_table ) {
      my ( $from, $to ) = split ',', $entry;
      next if !$from || !$to;
      $output .= "$from $to " . $pajek_table{$entry} . " c Black\n";
    } 

    open PAJEK, '> dicole.pajek' || die "Cannot open: $!\n";
    print PAJEK $output;
    close PAJEK;
    
    $self->_add_status( {
      is_ok   => 'yes',
      message => 'Pajek input file dicole.pajek created',
    } );

}

OpenInteract2::Manage->register_factory_type( get_name() => __PACKAGE__ );

1;
