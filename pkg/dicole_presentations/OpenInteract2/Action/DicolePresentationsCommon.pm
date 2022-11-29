package OpenInteract2::Action::DicolePresentationsCommon;

use strict;
use base qw( Dicole::Action );

use Log::Log4perl            qw( get_logger );
use OpenInteract2::Constants qw( :log );
use OpenInteract2::Context   qw( CTX );
use URI::Escape;
use Digest::SHA;

sub THUMBNAIL_WIDTH { 170 }
sub THUMBNAIL_HEIGHT { 95 }

sub _show_url {
    my ( $self, $prese, $domain_id, $extra ) = @_;

    $prese = $self->_ensure_prese_object( $prese );
    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );
    $extra ||= {};

    return Dicole::URL->from_parts( domain_id => $domain_id, action => 'presentations', task => 'show', target => $prese->group_id,
        additional => [ $prese->id, Dicole::Utils::Text->utf8_to_url_readable( $prese->name ) ],
        %$extra
    );
}

sub _ensure_prese_object {
    my ( $self, $prese ) = @_;

    return $prese if ref $prese;
    return CTX->lookup_object('presentations_prese')->fetch( $prese );
}

sub _generic_preses {
    my ( $self, %p ) = @_;

    my $where = 'dicole_presentations_prese.group_id = ?';
    my $value = [ $p{group_id} ];

    if ( my $s = $p{search} ) {
        $where .= ' AND ( dicole_presentations_prese.name LIKE ? OR dicole_presentations_prese.description LIKE ? )';
        push @$value, ( '%' . $s . '%' );
        push @$value, ( '%' . $s . '%' );
    }

    if ( my $t = $p{type} ) {
        my @separate = ( 'video', 'slideshow', 'image' );
        if ( $t eq 'other' ) {
            $where .= ' AND ' . Dicole::Utils::SQL->column_not_in_strings(
                'dicole_presentations_prese.prese_type' => \@separate,
            )
        }
        elsif ( grep { $t eq $_ } @separate ) {
            $where .= ' AND dicole_presentations_prese.prese_type = ?';
            push @$value, $t;
        }
    }

    my $order = $p{order};

    if ( my $l = $p{listing} ) {
        if ( $l eq 'featured' ) {
            $where .= ' AND dicole_presentations_prese.featured_date != 0';
            $order =  'featured_date desc'
        }
        elsif ( $l eq 'best' ) {
            $order =  'rating desc, featured_date desc, creation_date desc'
        }
        else {
            $order = 'creation_date desc';
        }
    }

    $where .= ' AND ' . $p{where} if $p{where};
    push @$value, @{$p{value}} if $p{value};

    my $tags = ( $p{tags} && ref( $p{tags} ) eq 'ARRAY' ) ? $p{tags} : [];
    push @$tags, $p{tag} if $p{tag};

    my $preses = $tags ?
        eval { CTX->lookup_action('tagging')->execute( 'tag_limited_fetch_group', {
            domain_id => $p{domain_id},
            group_id => $p{group_id},
            user_id => 0,
            object_class => CTX->lookup_object('presentations_prese'),
            tags => $tags,
            where => $where,
            value => $value,
            order => $order,
            limit => $p{limit},
        } ) } || []
        :
        CTX->lookup_object('presentations_prese')->fetch_group( {
            where => $where,
            value => $value,
            order => $order,
            limit => $p{limit},
        } ) || [];

    return $preses;
}

sub _object_info {
    my ( $self, $prese, $domain_id ) = @_;

    my $group_id = $prese->group_id;
    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    my $thread = CTX->lookup_action('comments_api')->e( get_thread => {
        object => $prese,
        user_id => 0,
        group_id => $group_id,
        domain_id => $domain_id,
    } );

    my $attachment = $prese->attachment_id ? CTX->lookup_object('attachment')->fetch( $prese->attachment_id ) : undef;

    my $author_size = 64;
    $author_size = CTX->request->param('author_size') if CTX && CTX->request;

    my $commenter_size = 60;
    $commenter_size = CTX->request->param('commenter_size') if CTX && CTX->request;

    my $info = {
        id => $prese->id,
        title => $prese->name,
        date => $prese->creation_date,
        date_ago => Dicole::Utils::Date->localized_ago( epoch => $prese->creation_date ),
        embed => $self->_embed_for_object( $prese, $attachment ),
        simple_embed => $self->_embed_for_object( $prese, $attachment, 1 ),
        download_url => $attachment ? Dicole::URL->from_parts(
            domain_id => $domain_id,
            action => 'presentations', task => 'attachment_download', target => $attachment->group_id,
            additional => [ $attachment->id, $prese->id || 0, $attachment->filename ]
        ) : '',
        description => $prese->description,
        tags => CTX->lookup_action('tags_api')->e( get_tags_for_object => {
            object => $prese,
            user_id => 0,
            group_id => $group_id,
            domain_id => $domain_id,
        } ),
        author_name => $prese->presenter || Dicole::Utils::User->name( $prese->creator_id ),
        author_url => Dicole::Utils::User->url( $prese->creator_id, $group_id ),
        author_image => Dicole::Utils::User->image( $prese->creator_id, $author_size ),
        presenter => $prese->presenter,
        comments => CTX->lookup_action('comments_api')->e( get_comments_info => {
            thread => $thread,
            object => $prese,
            user_id => 0,
            group_id => $group_id,
            domain_id => $domain_id,
            size => $commenter_size,
        } ),
        comment_thread_id => $thread->id,
        show_url => $self->_show_url( $prese, $domain_id ),
        data_url => Dicole::URL->from_parts(
            domain_id => $domain_id,
            action => 'presentations_json', task => 'object_info',
            target => $group_id, additional => [ $prese->id ],
        ),
        from_file => $prese->attachment_id ? 1 : 0,
        from_url => $prese->url ? 1 : 0,
        readable_type => $attachment ? Dicole::Utils::MIME->type_to_readable( $attachment->mime ) : '',
        readable_size => $attachment ? sprintf( "%.2f", ( $attachment->byte_size / 1024 / 1024 ) ) . 'MB' : '',
    };

    return $info;
}

sub _gather_data_for_objects {
    my ( $self, $objects, $domain_id ) = @_;
    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );

    my @datas = ();

    my $comment_counts = CTX->lookup_action('comments_api')->e(get_comment_counts => {
        objects => $objects
    });

    for my $object ( @$objects ) {
        my $data = {
            name => $object->name,
            creation_date => $object->creation_date,
            image => $self->_get_presentation_image( $object, undef, $domain_id ),
            show_url => $self->_show_url( $object, $domain_id ),
            object => $object,
            comment_count => $comment_counts->{$object->id} || 0,
        };

        push @datas, $data;
    }

    return \@datas;
}

sub _object_data_to_rss_params {
    my ( $self, $data ) = @_;

    my $surl = $self->param('server_url') || Dicole::URL->get_server_url;

    my $tags = CTX->lookup_action('tags_api')->e( get_tags_for_object => {
        object => $data->{object},
        group_id => $data->{object}->group_id,
        user_id => 0,
        domain_id => $self->param('domain_id'),
    } ) || [];

    my $params = {
        link => $surl . $data->{show_url},
        title => $data->{name},
        description => $data->{object}->embed . $data->{object}->description,
        pubDate => $data->{creation_date},
        author => $data->{object}->presenter || Dicole::Utils::User->name( $data->{object}->creator_id ),
        guid => $surl . $data->{show_url},
        category => $tags,
    };

    return $params;
}

sub _remove_object {
    my ( $self, $object, $domain_id, $user_id ) = @_;

   	my $scribd_id = $object->{scribd_id};
  	my $scribd_api_key = CTX->server_config->{dicole}->{scribd_api_key};
   	if($scribd_id && $scribd_api_key) {
    	my $scribd_xml = Dicole::Utils::HTTP->post(
          	'http://api.scribd.com/api',
          	{
          		method => 'docs.delete',
           		api_key => $scribd_api_key,
           		doc_id => $scribd_id
           	}
           );
    }

    $self->_store_delete_event( $object, undef, $domain_id, $user_id );

    eval { CTX->lookup_action('commenting')->execute( remove_comments => {
        object => $object,
    } ) };

    eval { CTX->lookup_action('tagging')->execute( remove_tags => {
        object => $object,
    } ) };


    my $prese_ratings = CTX->lookup_object('presentations_prese_rating')->fetch_group( {
        where => 'object_id = ?',
        value => [ $object->id ],
    } ) || [];

    for my $rating (@$prese_ratings) {
        $rating->remove;
    }

    $object->remove;
}

sub _visualize_prese_list {
    my ( $self, $preses, $paritial ) = @_;

    my @visuals = map { $self->_visualize_prese_list_item( $_ ) } @$preses;
    my $time = time;

    # guess that there are more if 10 was rendered ;)
    if ( scalar( @$preses ) > 9 ) {
        my $button_container = Dicole::Widget::Container->new(
            class => 'presentations_more_container',
            id => 'presentations_more_container_' . $time,
            contents => [
                Dicole::Widget::LinkButton->new(
                    text => $self->_msg( 'Show more media resources' ),
                    class => 'presentations_more_button',
                    id => 'presentations_more_button_' . $time,
                    link => $self->derive_url(
                        action => 'presentations_json',
                    ),
                ),
            ],
        );
        push @visuals, $button_container;
    }

    my $list = Dicole::Widget::Vertical->new(
        contents => \@visuals,
        class => $paritial ? undef : 'presentations_prese_listing',
        id => $paritial ? undef : 'presentations_prese_listing_' . $time,
    );

    return $list;
}

sub _duration_string_for_object {
    my ( $self, $prese ) = @_;

    my $duration = $prese->duration;
    if ( $prese->prese_type eq 'slideshow' && $duration && $duration =~ /^\s*\d+\s*$/ ) {
        $duration = $self->_msg( '[_1] slides', $duration );
    }

    return $duration;
}

sub _visualize_prese_list_item {
    my ( $self, $prese ) = @_;

    my $show_link = $self->_show_url( $prese );

    my $duration = $prese->duration;
    if ( $prese->prese_type eq 'slideshow' && $duration && $duration =~ /^\s*\d+\s*$/ ) {
        $duration = $self->_msg( '[_1] slides', $duration );
    }

    my $content = Dicole::Widget::Columns->new(
        left => Dicole::Widget::Vertical->new( contents => [
            Dicole::Widget::Hyperlink->new(
                link => $show_link,
                content => Dicole::Widget::Image->new(
                    class => 'presentations_prese_image',
                    src => CTX->lookup_action('thumbnails_api')->execute(
                        create => {
                        	url => $self->_get_presentation_image( $prese ),
                        	width => $self->THUMBNAIL_WIDTH,
                        	height => $self->THUMBNAIL_HEIGHT
                        }
                    ) || $self->_get_presentation_placeholder_image($prese),
                    width => $self->THUMBNAIL_WIDTH,
                    height => $self->THUMBNAIL_HEIGHT
                ),
            ),
            Dicole::Widget::Container->new(
                class => 'presentations_prese_controls',
                contents => [
                    $self->_comment_count_widget_for_object( $prese ),
                    $self->_rating_widget_for_object( $prese ),
                ],
            ),
        ] ),
        right => Dicole::Widget::Vertical->new( contents => [
            $self->_date_widget_for_object( $prese ),
            Dicole::Widget::Hyperlink->new(
                link => $show_link,
                content => Dicole::Widget::Text->new(
                    text => $prese->name,
                    class => 'definitionHeader presentations_prese_name',
                ),
            ),
            Dicole::Widget::Inline->new(
                class => 'presentations_prese_stats',
                contents => [
                    Dicole::Widget::Text->new(
                        class => 'presentation_prese_author presentation_' . $prese->prese_type,
                        text => $prese->presenter,
                    ),
                    $duration ? (
                        ' ',
                        Dicole::Widget::Inline->new(
                            class => 'media_separator',
                            contents => [
                                Dicole::Widget::Raw->new( raw => '&bull;' ),
                            ],
                        ),
                        ' ',
                        Dicole::Widget::Text->new(
                            class => 'presentation_prese_duration presentation_' . $prese->prese_type,
                            text => $duration,
                        ),
                    ) : (),
                ],
            ),
            Dicole::Widget::Container->new(
                class => 'presentations_prese_description',
                contents => [ Dicole::Widget::Raw->new(
                    raw => Dicole::Utils::HTML->shorten( $prese->description, 125 )
                ) ],
            ),
            $self->_fake_tag_list_widget( $prese ),
        ] ),
        left_class => 'presentations_prese_columns_left',
        left_td_class => 'presentations_prese_columns_td_left',
        right_class => 'presentations_prese_columns_right',
        right_td_class => 'presentations_prese_columns_td_right',
    );

    return Dicole::Widget::FancyContainer->new(
        id => 'presentations_prese_container_' . $prese->id,
        class => 'presentations_prese_container',
        contents => [ $content ],
     );
}

sub _short_description_for_object {
    my ( $self, $prese ) = @_;

    return Dicole::Utils::Text->shorten( Dicole::Utils::HTML->html_to_text( $prese->description ), 50 );
}

sub _get_presentation_image {
    my ( $self, $prese, $preview, $domain_id ) = @_;

    return $self->_get_presentation_placeholder_image($prese) unless $prese->image;

    if ($prese->image =~ /^\d+$/) {
        return $preview ?
            Dicole::URL->from_parts(
                domain_id => $domain_id,
                action => 'presentations',
                task => 'preview_image',
                target => $prese->group_id,
                additional => [ $prese->image ]
            )
            :
            Dicole::URL->from_parts(
                domain_id => $domain_id,
                action => 'presentations',
                task => 'image',
                target => $prese->group_id,
                additional => [ $prese->id, $prese->image ]
            );
    }
    else {
        return $prese->image;
    }
}

sub _get_presentation_placeholder_image {
	my ($self, $prese) = @_;

    return '/images/presentations/media-icons/thumbnail-placeholder-'
		. $self->_simple_type_for_object( $prese ) . '.png'
}

sub _simple_type_for_object {
    my ( $self, $prese ) = @_;
    my $type = $prese->prese_type;
    $type = 'other' unless $type eq 'video' || $type eq 'slideshow' || $type eq 'image' || $type eq 'audio' || $type eq 'slideshow' || $type eq 'bookmark';
    return $type;
}

my $box_support_raw = <<END
.pdf	application/pdf
.doc	application/msword
.docx	application/vnd.openxmlformats-officedocument.wordprocessingml.document
.ppt	application/vnd.ms-powerpoint
.pptx	application/vnd.openxmlformats-officedocument.presentationml.presentation
.xls	application/vnd.ms-excel
.xlsx	application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
.txt	text/plain
.py	application/x-python
.py	text/x-python
.py	text/x-script.python
.js	text/javascript
.js	application/x-javascript
.js	application/javascript
.xml	text/xml
.xml	application/xml
.html	text/html
.css	text/css
.md	text/x-markdown
.pl	text/x-script.perl
.c	text/x-c
.m	text/x-m
.json	application/json
END
;

my %box_support_map = map { my @a = split( /\s+/, $_ ); $a[1] ? ( $a[1], $a[0] ) : () } ( split /\n/, $box_support_raw );
my %box_suffix_map = reverse %box_support_map;

sub _attachment_is_box_type {
    my ( $self, $a ) = @_;

    return 1 if $box_support_map{ lc( $a->mime ) };

    my ( $ext ) = $a->filename =~ /(\.\w{1,4})$/;

    return 1 if $ext && $box_suffix_map{ lc( $ext ) };

    return 0;
}

sub _embed_for_object {
    my ( $self, $prese, $attachment, $simple, $include_host ) = @_;

    if ( $prese->attachment_id ) {
        my $a = $attachment || CTX->lookup_object('attachment')->fetch( $prese->attachment_id );
        my $filename = Dicole::Utils::HTML->encode_entities( $a->filename );
        my $original_url_raw = Dicole::URL->from_parts(
            action => 'presentations', task => 'attachment_original', target => $a->group_id,
            additional => [ $a->id, $prese->id || 0, $a->filename ]
        );
        my $view_url_raw = Dicole::URL->from_parts(
            action => 'presentations', task => 'attachment_view', target => $a->group_id,
            additional => [ $a->id, $prese->id || 0, $a->filename ]
        );
        my $original_url = Dicole::Utils::HTML->encode_entities( $original_url_raw );
        my $view_url = Dicole::Utils::HTML->encode_entities( $view_url_raw );

        my $base_filename = $a->filename;
        $base_filename =~ s/\..*//;
        $base_filename ||= 'unnamed';

        my $image_url_raw = Dicole::URL->from_parts(
            action => 'presentations', task => 'attachment_image', target => $a->group_id,
            additional => [ $a->id, $simple ? 560 : 320, $base_filename . '.jpg' ]
        );
        my $image_url = Dicole::Utils::HTML->encode_entities( $image_url_raw );
        my $flv_url = Dicole::URL->from_parts(
            action => 'presentations', task => 'attachment_embed', target => $a->group_id,
            additional => [ $a->id, $base_filename . '.flv' ]
        );
        my $mp4_url = Dicole::URL->from_parts(
            action => 'presentations', task => 'attachment_embed_mp4', target => $a->group_id,
            additional => [ $a->id, $base_filename . '.mp4' ]
        );
        my $ogv_url = Dicole::URL->from_parts(
            action => 'presentations', task => 'attachment_embed_ogv', target => $a->group_id,
            additional => [ $a->id, $base_filename . '.ogv' ]
        );

        my $mp3_url = Dicole::URL->from_parts(
            action => 'presentations', task => 'attachment_embed_mp3', target => $a->group_id,
            additional => [ $a->id, $base_filename . '.mp3' ]
        );
        my $ogg_url = Dicole::URL->from_parts(
            action => 'presentations', task => 'attachment_embed_ogg', target => $a->group_id,
            additional => [ $a->id, $base_filename . '.ogg' ]
        );

        if ( $include_host ) {
            my $host = Dicole::URL->get_domain_url;
                for my $url ( $image_url, $image_url_raw, $original_url, $original_url_raw, $flv_url, $mp3_url, $ogg_url, $mp4_url, $ogv_url ) {
                $url = $host . $url unless $url =~ /^\w+\:\/\//;
            }
        }

        if ( $self->_attachment_is_box_type( $a ) ) {
            my $task = $prese->id ? 'box_redirect' : 'box_preview_redirect';
            my $additional = $prese->id ? [ $prese->id, $self->_generate_sec( $prese->id ) ] : [];
            my $box_endpoint = Dicole::URL->get_domain_url . $self->derive_url( action => 'presentations_raw', task => $task, target => 0, additional => $additional );

            return '<iframe src="'.$box_endpoint.'" style="width: 100%; height: 500px; border-radius: 0px; border: 0px solid #d9d9d9;" allowfullscreen="allowfullscreen"></iframe>';
        }
        elsif ( $prese->scribd_id and $prese->scribd_key ) {
            my $doc_type = 'document';
            $doc_type = 'slideshow' if $a->filename =~ /pptx?$/i;

            return '<div id="attachment_embed_scribd_'.$a->id.'" class="js_dicole_scribd_file" data-scribd-args="'. $prese->scribd_id .','. $prese->scribd_key .','. $doc_type .'"></div>';
        }
        elsif ( $a->mime =~ /image\/(jpeg|gif|png)/ ) {
            return '<a class="js_prese_embed_image" href="'.$view_url.'"><img alt="'.$filename.'" src="'.$image_url.'" /></a>';
        }
        elsif ( $a->mime =~ /video/) {
            my $params = {
                type => 'video',
                mp4_file => $mp4_url,
                ogv_file => $ogv_url,
                fallback_file => $flv_url,
                title => $filename,
                image => $image_url_raw,
            };
            return '<span id ="attachment_embed_jw_'.$a->id.'" class="js_dicole_jw_object"' .
                ' title="' . Dicole::Utils::HTML->encode_entities( Dicole::Utils::JSON->encode( $params ) ).'"><a href="'.$original_url.'" title="'.$original_url.'">'.Dicole::Utils::Text->shorten( $filename, 35 ).'</a></span>';
        }
        elsif ( $a->mime =~ /audio/) {
            my $params = {
                type => 'audio',
                mp3_file => $mp3_url,
                ogg_file => $ogg_url,
                fallback_file => $mp3_url,
                title => $filename,
            };
            return '<span id ="attachment_embed_jw_'.$a->id.'" class="js_dicole_jw_object"' .
                ' title="' . Dicole::Utils::HTML->encode_entities( Dicole::Utils::JSON->encode( $params ) ) . '"><a href="'.$original_url.'" title="'.$original_url.'">'.Dicole::Utils::Text->shorten( $filename, 35 ).'</a></span>';
        }
        else {
            return '<a href="'.$original_url.'">'.Dicole::Utils::Text->shorten( $filename, 35 ).'</a>';
        }
    }
    else {
        return $prese->embed;
    }
}

sub _comment_count_for_object {
    my ( $self, $prese ) = @_;

    my $count = eval { CTX->lookup_action('commenting')->execute( get_comment_count => {
        object => $prese,
    } ) } || 0;

    return $count;
}

sub _comment_count_widget_for_object {
    my ( $self, $prese ) = @_;

    my $count = $self->_comment_count_for_object( $prese );

    return Dicole::Widget::Hyperlink->new(
        link => $self->_show_url( $prese, undef, { anchor => 'comments' } ),
        class => 'presentations_prese_comment_count',
        content => Dicole::Widget::Text->new(
            class => 'presentations_prese_comment_count_text',
            text => $count,
        ),
    );
}

sub _date_widget_for_object {
    my ( $self, $prese ) = @_;

    my $dt = DateTime->from_epoch( epoch => $prese->creation_date );

    return Dicole::Widget::Container->new(
        class => 'presentations_prese_date',
        contents => [
            Dicole::Widget::Text->new(
                text => $dt->day,
                class => 'presentations_prese_date_day',
            ),
            Dicole::Widget::Text->new(
                text => $dt->month_abbr,
                class => 'presentations_prese_date_month',
            ),
            Dicole::Widget::Text->new(
                text => $dt->year,
                class => 'presentations_prese_date_year',
            ),
        ],
    );
}

sub _date_string_for_object {
    my ( $self, $prese ) = @_;

    my $dt = DateTime->from_epoch( epoch => $prese->creation_date );

    return join ' ', ( $dt->day, $dt->month_abbr, $dt->year );
}

sub _simple_rating_for_object {
    my ( $self, $prese ) = @_;

    my $r = $prese->rating;
    return 0 unless $r;

    return int( $r / 20 + 0.5 );
}

sub _rating_widget_for_object {
    my ( $self, $object, $conf ) = @_;
    return Dicole::Widget::Container->new(
        id => 'presentations_rate_container_' . $object->id,
        class => 'presentations_rate_container',
        contents => [ $self->_unwrapped_rating_widget_for_object( $object, $conf ) ],
    );
}

sub _unwrapped_rating_widget_for_object {
    my ( $self, $object, $conf ) = @_;
    $conf->{ 'rating_disabled' } = 1 unless CTX->request->auth_user_id;

    my @widgets = ( Dicole::Widget::Container->new(
            class => 'presentations_rating_stars',
            contents => [ $self->_plain_rating_widget_for_object( $object, $conf ) ],
    ) );

    return Dicole::Widget::Container->new( contents => \@widgets );
}

sub _plain_rating_widget_for_object {
    my ( $self, $object, $conf ) = @_;
    my $object_name = 'presentations_prese';

    my $users_objects = CTX->lookup_object($object_name.'_rating')->fetch_group( {
        where => 'object_id = ? AND user_id = ?',
        value => [ $object->id, CTX->request->auth_user_id ],
        order => 'date desc'
    } ) || [];

    my $user_rating = shift @$users_objects;
    my $stars = $user_rating ? int( $user_rating->rating / 20 ) : undef;

    my $rating = $object->rating || 0;
    my $id = $object->id;
    my $gid = $object->group_id;
    my $disabled = $conf->{ 'rating_disabled' } ? ' presentations_rating_disabled' : '';
    my $stats = $user_rating ? ' (Your current is '.$stars.' star(s)).' : '';
    $stats .= ' Total of '.$object->rating_count.' rating(s) so far.';

    my $raw = <<RAW;
<ul class="star-rating presentations_rate_linksDISABLED" id="presentations_rate_links_ID">
<li class="current-rating" style="width:CURRENT%;"></li>
<li><a href="/presentations_json/rate/GID/ID/1" title="Rate with 1 starSTATS" class="presentations_rate_link_ID one-star "></a></li>
<li><a href="/presentations_json/rate/GID/ID/2" title="Rate with 2 starsSTATS" class="presentations_rate_link_ID two-stars"></a></li>
<li><a href="/presentations_json/rate/GID/ID/3" title="Rate with 3 starsSTATS" class="presentations_rate_link_ID three-stars"></a></li>
<li><a href="/presentations_json/rate/GID/ID/4" title="Rate with 4 starsSTATS" class="presentations_rate_link_ID four-stars"></a></li>
<li><a href="/presentations_json/rate/GID/ID/5" title="Rate with 5 starsSTATS" class="presentations_rate_link_ID five-stars"></a></li>
</ul>
RAW
    $raw =~ s/CURRENT/$rating/g;
    $raw =~ s/GID/$gid/g;
    $raw =~ s/ID/$id/g;
    $raw =~ s/DISABLED/$disabled/g;
    $raw =~ s/STATS/$stats/g;

    return Dicole::Widget::Raw->new( raw => $raw );
}

sub _fake_tag_list_widget {
    my ( $self, $prese, $tags ) = @_;

    $tags ||= eval { CTX->lookup_action('tagging')->execute( 'get_tags_for_object', {
        object => $prese,
        group_id => $self->param('target_group_id'),
        user_id => 0,
    } ) } || [];

    return Dicole::Widget::Inline->new( class => 'presentations_tag_list empty', contents => [] ) unless scalar( @$tags );

    # Copy to not alter the incoming tags parameter..
    my $tags_copy = [ @$tags ];
    my $last = pop @$tags_copy;

    return Dicole::Widget::Inline->new( class => 'presentations_tag_list', contents => [
        $self->_msg( 'Tags:'),
        ' ',
        map ( {
            ( Dicole::Widget::Text->new( class => 'presentations_tag_list_item', text => $_ ), ', ' )
        } @$tags_copy ),
        Dicole::Widget::Text->new( class => 'presentations_tag_list_item', text => $last ),
    ] );
}

sub _tags_for_object {
    my ( $self, $prese ) = @_;

    my $tags = eval { CTX->lookup_action('tagging')->execute( 'get_tags_for_object', {
        object => $prese,
        group_id => $self->param('target_group_id'),
        user_id => 0,
    } ) } || [];

    return $tags;
}

sub _send_prese_to_box {
    my ( $self, $prese, $a, $domain_id, $refresh ) = @_;


    # TODO: handle possible errors :)
    # TODO: wrap in a mutex

    unless ( $refresh ) {
        my $da = Dicole::Utils::Data->get_note( new_box_view_document_attachment => $prese );
        return if $da && $da == $prese->attachment_id;
    }

    if ( my $started = Dicole::Utils::Data->get_note( new_box_upload_started => $prese ) ) {
        return if $started + 200 > time;
    }

    if ( Dicole::Utils::Data->get_note( new_box_view_document_id => $prese ) ) {
        my $stash = Dicole::Utils::Data->get_note( new_box_stash => $prese ) || {};
        $stash->{old_ids} ||= [];
        $stash->{old_attachments} ||= [];
        push @{ $stash->{old_ids} }, Dicole::Utils::Data->get_note( new_box_view_document_id => $prese );
        push @{ $stash->{old_attachments} }, Dicole::Utils::Data->get_note( new_box_view_document_attachment => $prese );
        Dicole::Utils::Data->set_note( new_box_stash => $stash, $prese, { skip_save => 1 } );
    }

    Dicole::Utils::Data->set_note( new_box_view_document_id => undef, $prese, { skip_save => 1 } );
    Dicole::Utils::Data->set_note( new_box_view_document_attachment => undef, $prese, { skip_save => 1 } );
    Dicole::Utils::Data->set_note( new_box_upload_started => time, $prese );

    Dicole::Utils::Gearman->do_delayed_task( upload_new_box_file => {
        prese_id => $prese->id,
    }, 0 );

    return 1;
}

sub _get_session_for_box_prese {
    my ( $self, $prese ) = @_;

    my $token = $self->_new_box_token_for_prese( $prese );

    my $current_attachment_id = Dicole::Utils::Data->get_note( new_box_view_document_attachment => $prese );

    my $session = Dicole::Cache->fetch_or_store( 'new_box_session_' + $current_attachment_id, sub {
        my $id = Dicole::Utils::Data->get_note( new_box_view_document_id => $prese );

        ### OLD TLS 1.0 version on old machines, box fails after 15.6.2018
        # my $result = Dicole::Utils::HTTP->get( 'https://api.box.com/2.0/files/'. $id .'?fields=expiring_embed_link', undef, undef, undef, $token );
        # my $data = Dicole::Utils::JSON->decode( $result );

        ### NEW TLS 1.1 version through api machine
        my $api_domain = CTX->server_config->{dicole}->{meetings_api_domain};
        my $helper_url = 'https://'.$api_domain.'/v1/helper_box_com_api_get';
        my $params = Dicole::Utils::JSON->encode( {
            url => 'https://api.box.com/2.0/files/'. $id .'?fields=expiring_embed_link',
            headers => { 'Authorization' => $token },
        } );
        my $result = Dicole::Utils::HTTP->post( $helper_url, { params => $params } );

        my $data = Dicole::Utils::JSON->decode( $result );
        $data = Dicole::Utils::JSON->decode( $data->{result}{body} );

        return $data->{expiring_embed_link}{url};
    }, { expires => 45, no_domain_id => 1, no_group_id => 1 } );

    return $session;
}

sub _process_new_attachment_for_object {
    my ( $self, $object, $a, $domain_id ) = @_;

    $a ||= CTX->lookup_object('attachment')->fetch( $object->attachment_id );

    my $image_url = Dicole::URL->from_parts(
        domain_id => $domain_id,
        action => 'presentations', task => 'attachment_image', target => $a->group_id,
        additional => [ $a->id, $a->filename . '.jpg' ]
    );

    if ( $self->_attachment_is_box_type( $a ) ) {
        $object->image('');
        $object->prese_type( $self->_guess_prese_type_from_filename( $a->filename ) );
    }
    elsif ( $a->mime =~ /image/ ) {
        $object->image( $image_url );
        $object->prese_type('image');
    }
    elsif ( $a->mime =~ /video/ ) {
        $object->image( $image_url );
        $object->prese_type('video');
    }
    elsif ( $a->mime =~ /audio/ ) {
        $object->image('');
        $object->prese_type('audio');
    }
    else {
        $object->image('');
        $object->prese_type('custom');
    }

    if ( $self->_attachment_is_box_type( $a ) ) {
        $self->_send_prese_to_box( $object, $a, $domain_id );
    }

    $object->save;
}

sub _guess_prese_type_from_filename {
    my ( $self, $filename ) = @_;

    my ( $ext ) = $filename =~ /\.(pdf|txt|ps|rtf|epub|odt|odp|ods|odg|odf|sxw|sxc|sxi|sxd|doc|ppt|pps|xls|docx|pptx|ppsx|xlsx|tif|tiff)$/i;

    my %types = (
        slideshow => [ split( /\|/, "odp|ods|sxi|ppt|pps|pptx|ppsx") ],
        image => [ split( /\|/, "tif|tiff|odg|sxd") ],
        bookmark => [ split( /\|/, "pdf|txt|ps|rtf|epub|odt|odf|sxw|sxc|doc|xls|docx|xlsx") ],
    );

    my %prese_types_lookup = ();
    for my $type ( keys %types ) {
        for my $x ( @{ $types{ $type } } ) {
            $prese_types_lookup{ $x } = $type;
        }
    }

    return $prese_types_lookup{ lc( $ext ) } || 'custom';
}

sub _generate_scribd_sec {
    my ( $self, $id ) = @_;

    return Digest::SHA::sha1_hex( $id + '_' + CTX->server_config->{dicole}{scribd_upload_secret} );
}

sub _generate_sec {
    my ( $self, $id ) = @_;

    return Digest::SHA::sha1_hex( $id + '_prese_' + CTX->server_config->{dicole}{meetings_general_secret} );
}

sub _prese_domain_id {
    my ( $self, $prese ) = @_;

    return 0 unless $prese;

    my $domain_id = Dicole::Utils::Data->get_note( domain_id => $prese) || 0;

    if ( ! $domain_id && ! Dicole::Utils::Data->get_note( domain_id_resolved => $prese ) ) {
        $domain_id = eval { CTX->lookup_object('groups')->fetch( $prese->group_id )->domain_id } || 0;
        if ( $domain_id ) {
            Dicole::Utils::Data->set_note( domain_id => $domain_id, $prese );
        }
        else {
            Dicole::Utils::Data->set_note( domain_id_resolved => 1, $prese );
        }
    }

    return $domain_id;
}

sub _box_token_for_prese {
    my ( $self, $prese ) = @_;

    my $domain_id = $self->_prese_domain_id( $prese );
    my $token = $domain_id ? CTX->server_config->{dicole}->{"box_view_api_key_for_domain_$domain_id"} : '';
    return $token || CTX->server_config->{dicole}->{box_view_api_key};
}

sub _new_box_token_for_prese {
    my ( $self, $prese ) = @_;

    my $domain_id = $self->_prese_domain_id( $prese );
    my $token = $domain_id ? CTX->server_config->{dicole}->{"new_box_view_api_key_for_domain_$domain_id"} : '';
    my $bt = $token || CTX->server_config->{dicole}->{new_box_view_api_key};
    return "Bearer $bt";
}

sub _store_creation_event {
    my $self = shift @_;
    return $self->_store_some_event( 'created', @_ );
}

sub _store_editing_event {
    my $self = shift @_;
    return $self->_store_some_event( 'edited', @_ );
}

sub _store_delete_event {
    my $self = shift @_;
    return $self->_store_some_event( 'deleted', @_ );
}

sub _store_some_event {
    my ( $self, $type, $object, $tags, $domain_id, $user ) = @_;
    $domain_id = Dicole::Utils::Domain->guess_current_id( $domain_id );
    eval {
        my $a = CTX->lookup_action('event_source_api');

        eval {
            my $secure_tree = Dicole::Security->serialize_secure(
                'OpenInteract2::Action::DicolePresentations::view', {
                    group_id => $object->group_id,
                    domain_id => $domain_id,
                }
            );

            if ( ! $tags ) {
                $tags = CTX->lookup_action('tags_api')->e( get_tags => {
                    object => $object,
                    group_id => $object->group_id,
                    user_id => 0,
                    domain_id => $domain_id,
                } );
            }

            my $dd = {
                object_id => $object->id,
                object_tags => $tags,
            };

            my $event_time = $object->creation_date;
            if ( $type =~ /deleted|edited/ ) {
                $event_time = time();
            }

            $a->e( add_event => {
                event_type => 'media_object_' . $type,
                author => $user ? Dicole::Utils::User->ensure_id( $user ) : $object->creator_id,
                target_user => 0,
                target_group => $object->group_id,
                target_domain => $domain_id,
                timestamp => $event_time,
                coordinates => [],
                classes => [ 'media_object' ],
                interested => [],
                tags => $tags,
                topics => [ 'media_object::' . $object->id ],
                secure_tree => $secure_tree,
                data => $dd,
            } )
        };
        if ( $@ ) {
            get_logger(LOG_APP)->error( $@ );
        }
    };
}

sub _current_user_can_edit_object {
    my ( $self, $object ) = @_;

    return 1 if $self->mchk_y( 'OpenInteract2::Action::DicolePresentations', 'admin' );
    return 1 if $object->creator_id == CTX->request->auth_user_id;
    return 0;
}

sub _commenting_requires_approval {
    my ( $self ) = @_;

    return Dicole::Settings->fetch_single_setting(
        tool => 'groups',
        attribute => 'commenting_requires_approval',
        group_id => CTX->controller->initial_action->param('target_group_id'),
    ) ? 1 : 0;
}

sub _fetch_state_prese_list_info {
    my ( $self, $gid, $domain_id, $state, $items_per_request ) = @_;

    $items_per_request ||= 30;

    $state ||= { tags => [] };
    my $tags = $state->{tags} ||= [];

    my $shown_materials = $state->{shown_materials} || [];
    my $preses = CTX->lookup_action('tagging')->execute( tag_limited_fetch_group => {
        object_class => CTX->lookup_object('presentations_prese'),
        where => 'dicole_presentations_prese.group_id = ?' .
            ' AND ' . Dicole::Utils::SQL->column_not_in( 'dicole_presentations_prese.prese_id' => $shown_materials ),
        value => [ $gid ],
        order => $state->{order},
        tags => $tags,
        user_id => 0,
        group_id => $gid,
        domain_id => $domain_id,
    } ) || [];

    my $object_info_list = [];
    for my $prese ( @$preses ) {
        push @$shown_materials, $prese->id;

        my $hash = {
            id => $prese->id,
            title => $prese->name,
            description => Dicole::Utils::HTML->html_to_text( $prese->description ),
            type => $self->_simple_type_for_object( $prese ),
            url => $self->_show_url( $prese, $domain_id, scalar( @$tags ) ? { params => { filtered => join(',', @$tags ) } } : () ),
            creator_name => Dicole::Utils::User->name( $prese->creator_id ),
            created_timestamp => '',
            presenter_name => $prese->presenter,
            date => $self->_date_string_for_object( $prese ),

            comment_count => CTX->lookup_action('comments_api')->e( get_comment_count => {
                object => $prese,
                user_id => 0,
                group_id => $gid,
                domain_id => $domain_id,
            } ),

            bookmark_count =>  CTX->lookup_action('bookmarks_api')->e( count_users_who_bookmarked_object => {
                object => $prese,
                group_id => $gid,
                domain_id => $domain_id,
            } ) || 0,

            image => CTX->lookup_action('thumbnails_api')->execute(
                create => {
              	    url => $self->_get_presentation_image( $prese ),
                  	width => $self->THUMBNAIL_WIDTH,
                   	height => $self->THUMBNAIL_HEIGHT
                }
            ),
        };

        my $tags = CTX->lookup_action('tags_api')->e( get_tags_for_object => {
            object => $prese,
            user_id => 0,
            group_id => $gid,
            domain_id => $domain_id,
        } );

        $hash->{tags} = [ map { {
            name => $_,
        } } @$tags ];

        # TODO: bookmark count

        push @$object_info_list, $hash;
        last if scalar( @$object_info_list ) >= $items_per_request;
    }

    $state->{shown_materials} = $shown_materials;

    return {
        object_info_list => $object_info_list,
        state => $state,
        end_of_pages => ( scalar( @$preses ) > scalar( @$object_info_list ) ? 0 : 1 ),
        count => scalar( @$preses ),
    };
}

sub _fetch_state_prese_filter_suggestions {
    my ( $self, $gid, $domain_id, $state ) = @_;

    $state ||= { tags => [] };
    my $tags = $state->{tags} ||= [];

    my $weighted_tags = CTX->lookup_action('tags_api')->execute( 'tag_limited_fetch_group_weighted_tags', {
        object_class => CTX->lookup_object('presentations_prese'),
        tags => $tags,
        where => 'dicole_presentations_prese.group_id = ?',
        value => [ $gid ],
        domain_id => $domain_id,
        group_id => $gid,
        user_id => 0,
    } );

    my $category_data = CTX->lookup_action('tags_api')->execute( 'tag_collection_data', {
        domain_id => $domain_id,
        group_id => $gid,
        user_id => 0,
    } );

    my %tag_lookup = map { $_ => 1 } @$tags;
    my $tags_by_category = {};
    my $other_weighted_tags = [];

    for my $wtag ( @$weighted_tags ) {
        next if $tag_lookup{ $wtag->[0] };

        if ( my $catid = $category_data->{collection_id_by_tag}->{ $wtag->[0] } ) {
            $tags_by_category->{ $catid } ||= [];
            push @{ $tags_by_category->{ $catid } }, $wtag;
        }
        else {
            push @$other_weighted_tags, $wtag;
        }
    }

    my $categorized = [];

    for my $cat ( sort { $a->{order} <=> $b->{order} } @{ $category_data->{collections} } ) {
        next unless $tags_by_category->{ $cat->{id} };
        my %tag_lookup = map { $_->[0] => $_->[1] } @{ $tags_by_category->{ $cat->{id} } };

        my $tags = [];
        for my $tag ( @{ $cat->{tags} } ) {
            next unless $tag_lookup{ $tag };
            push @$tags, { name => $tag, weight => $tag_lookup{ $tag } };
        }

        push @$categorized, {
            title => $cat->{title},
            tags => $tags,
        };
    }

    my $cloud = Dicole::Widget::TagCloud->new(
        prefix => '#',
        limit => 50,
    );

    my $full_cloud = Dicole::Widget::TagCloud->new(
        prefix => '#',
        limit => 999,
    );

    $cloud->add_weighted_tags_array( $other_weighted_tags );
    $full_cloud->add_weighted_tags_array( $other_weighted_tags );

    return {
        categories => $categorized,
        other => $cloud->template_params->{links},
        other_full => $full_cloud->template_params->{links},
    };
}

1;
