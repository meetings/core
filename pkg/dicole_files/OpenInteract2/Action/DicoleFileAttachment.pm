package OpenInteract2::Action::DicoleFileAttachment;

# $Id: DicoleFileAttachment.pm,v 1.5 2008-08-18 23:29:59 amv Exp $

use base qw( Dicole::Action );

use strict;

use OpenInteract2::Context   qw( CTX );
use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use Dicole::Pathutils;
use Dicole::Utils::HTML;
use OpenInteract2::ActionResolver::Dicole;
use Dicole::Files;
use Dicole::Security::Checker;

our $VERSION = sprintf("%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/);

sub serve {
    my ( $self ) = @_;
    
    my $url = $self->param('url');
    my $from_html = $self->param('from_html');
    
    my @links = $self->find_links( $from_html );
    die 'security error' unless grep { $_ eq $url } @links;

    my $owner_type = $self->param('owner_type');
    my $owner_id = $self->param('owner_id');
    
    get_logger( LOG_APP )->debug(
        "Trying to resolve action for url: [$url]"
    );
    
    my $files_action = OpenInteract2::ActionResolver::Dicole->resolve(
        undef, $url
    );
    my $path = Dicole::Pathutils->new->clean_location(
        join '/', @{ $files_action->param('target_additional') }
    );
    
    get_logger( LOG_APP )->debug(
        "Resolved path: [$path]"
    );
    
    my %prefix_lookup = ( groups => 'group', users => 'user' );
    my ( $sec_id, $sec_prefix );
    if ( $path =~ m{^(groups|users)/(\d+)(/.*)?$} ) {
        $sec_prefix = $prefix_lookup{$1};
        $sec_id = $2;
    }
    die 'security error' unless $sec_id && $sec_prefix;
    
    my $checker = Dicole::Security::Checker->new( $owner_id, $owner_type );
    die 'security error' unless $checker->mchk_y(
        'OpenInteract2::Action::DicoleFiles',
        $sec_prefix . '_read',
        $sec_id
    );

    return Dicole::Files->new->download_file( 1, '/' . $path );
}

sub prefix_links {
    my ( $self ) = @_;
    my $html = $self->param('html');
    my $prefix = $self->param('prefix');
    
    return $self->_prefix_links( $html, $prefix );
}

sub find_links {
    my ( $self, $html ) = @_;

    my $tree = Dicole::Utils::HTML->safe_tree( $html );
    my @links = $self->_prepare_links( $tree );
    
    return @links;
}

sub _prefix_links {
    my ( $self, $html, $prefix ) = @_;
    
    my $tree = Dicole::Utils::HTML->safe_tree( $html );
    $self->_prepare_links( $tree, $prefix );
    my $return = Dicole::Utils::HTML->tree_guts_as_xml( $tree );
    
    return $return;
}

sub _prepare_links {
    my ( $self, $tree, $prefix ) = @_;

    my @links = (
        $self->_prepare_attrs( $tree, 'href', $prefix ),
        $self->_prepare_attrs( $tree, 'src', $prefix ),
    );
}

sub _prepare_attrs {
    my ( $self, $tree, $attr, $prefix ) = @_;

    my @elems = $tree->look_down( $attr =>
        qr/^\/(select_file\/view|(personal|group)_files\/(download|view))\//
    );

    my @links = ();
    for my $elem ( @elems ) {
        push @links, $elem->attr( $attr );
        $elem->attr( $attr, $prefix . $elem->attr( $attr ) ) if $prefix;
    }
    return @links;
}

1;

__END__

=pod

=head1 NAME

OpenInteract2::Action::DicoleFilesView - Handler for this package

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 BUGS

=head1 TO DO

=head1 SEE ALSO

=head1 AUTHORS

=cut
