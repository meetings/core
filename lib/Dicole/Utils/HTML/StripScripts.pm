package Dicole::Utils::HTML::StripScripts;

use base 'HTML::StripScripts::Parser';

sub new {
    my $self = shift @_;
    
    for ( qw/ AllowSrc AllowHref AllowRelURL AllowMailto / ) {
        $_[0]->{$_} = defined $_[0]->{$_} ? $_[0]->{$_} : 1;
    }
    
    return $self->SUPER::new( @_ );
}

# limit text size to 1000 instead of 200
sub _hss_attval_text {
    length $_[3] <= 1000 ? $_[3] : undef;
}

sub init_context_whitelist {
    my ( $self ) = @_;
    my $w = $self->SUPER::init_context_whitelist;
    
    $w->{'Flow'}->{'map'} = 'map';
    $w->{'Flow'}->{'object'} = 'object';
    $w->{'Flow'}->{'embed'} = 'embed';
    $w->{'Flow'}->{'iframe'} = 'iframe';
    
    $w->{'map'} = {
        'area' => 'EMPTY',
    };
    
    $w->{'object'} = {
        'param' => {},
        'embed' => 'embed',
    };
    
    $w->{'embed'} = {};
    
    $w->{'iframe'} = {};
    
    return $w;
}

sub init_attrib_whitelist {
    my ( $self ) = @_;
    my $w = $self->SUPER::init_attrib_whitelist;

    $w->{'a'}->{'class'} = 'text';
    $w->{'a'}->{'id'} = 'text';
    $w->{'a'}->{'title'} = 'text';
    $w->{'span'}->{'class'} = 'text';
    $w->{'span'}->{'id'} = 'text';
    $w->{'span'}->{'title'} = 'text';
    $w->{'img'}->{'usemap'} = 'text';
    $w->{'map'} = {
        id => 'text',
        name => 'word',
    };
    $w->{'area'} = {
        id => 'text',
        shape => 'word',
        coords => 'text',
        href => 'href',
    };
    $w->{'object'} = {
        id => 'text',
        style => 'style',
        align => 'text',
        archive => 'text',
        border => 'text',
        classid => 'text',
        codebase => 'text',
        codetype => 'text',
        data => 'text',
        declare => 'text',
        height => 'text',
        width => 'text',
        hspace => 'text',
        name => 'text',
        standby => 'text',
        type => 'text',
        usemap => 'text',
        vspace => 'text',
    };
    $w->{'param'} = {
        id => 'text',
        name => 'text',
        type => 'text',
        value => 'text',
        valuetype => 'text',
    };
    
    $w->{'embed'} = {
        id => 'text',
        name => 'text',
        src => 'text',
        pluginspage => 'text',
        height => 'text',
        width => 'text',
        swliveconnect => 'text',
        play => 'text',
        loop => 'text',
        menu => 'text',
        quality => 'text',
        scale => 'text',
        align => 'text',
        salign => 'text',
        wmode => 'text',
        bgcolor => 'text',
        base => 'text',
        flashvars => 'text',

        type => 'text',
    };
    
    $w->{'iframe'} = {
        align => 'text',
        frameborder => 'text',
        height => 'text',
        width => 'text',
        marginheight => 'text',
        marginwidth => 'text',
        name => 'text',
        scrolling => 'text',
        src => 'text',
        
        style => 'text',
        id => 'text',
        class => 'text',
        title => 'text',
    };

    return $w;
}

sub init_attval_whitelist {
    my ( $self ) = @_;
    my $w = $self->SUPER::init_attval_whitelist;
    
    # remove a previous limit of 200 chars
    $w->{text} = sub { $_[3] };
    
    return $w;
}

1;
