dojo.provide("dicole.presentations");
dojo.require("dicole.base.swfobject");

dicole.presentations.tag_browsers = [];

dojo.addOnLoad( function() { process_presentations() } );
dojo.addOnLoad( function() {
    if ( dojo.byId('presentations_tag_browser' ) ) {
        dicole.presentations.tag_browsers.push( new dicole.tags.TagBrowser2(
            'browse_filter_container',
            'browse_selected_container',
            'browse_selected_tags_container',
            'browse_suggestions',
            'browse_results',
            dojo.query('#filter_link'),
            dojo.query('#filter_more'),
            dojo.query('#browse_show_more a.show'),
            dojo.query('#browse_result_count'),
            dicole.get_global_variable( 'presentations_keyword_change_url' ),
            dicole.get_global_variable( 'presentations_more_materials2_url' ),
            dicole.get_global_variable( 'presentations_materials_state' ),
            dicole.get_global_variable( 'presentations_end_of_pages' ),
            'presentations_tagsearch_input',
            dojo.query('#browse_show_more a.filter')
        ) );
    }
} );



function process_presentations_more() {
    var more_containers = dojo.query('.presentations_more_container');
    var load_time = gather_page_load_time()
    var ids_json = gather_shown_entry_ids_json();
    
   dojo.forEach(more_containers, function(item, index, array) {
        if (!dojo.hasClass( item, 'presentations_more_container_processed' ) )
	{
		dojo.addClass( item, 'presentations_more_container_processed' );
		var parts = dojo.attr(item, 'id').match(/^presentations_more_container_(\d+)$/);
		if (parts  && parts[1])
		{
			var last_epoch = parts[1];
			var more_button = dojo.byId( 'presentations_more_button_' + last_epoch );
			presentations_more_attach( more_button, last_epoch, load_time, ids_json );
		}
	}
    });
}

function gather_shown_entry_ids_json() {
    var posts = dojo.query('.presentations_prese_container');
    var ids = [];
    dojo.forEach(posts, function(item, index, array) {
        var parts =dojo.attr(item, 'id').match(/^presentations_prese_container_(\d+)$/);
        if (parts && parts[1] ) ids.push( parts[1] );
    });
    return dojo.toJson( ids );
}

function gather_page_load_time() {
    var listings = dojo.query('.presentations_prese_listing');
    var page_load_time = 2147483647;
    dojo.forEach(listings, function( item, idx, array ) {
	var id = dojo.attr(item, 'id');
        var parts = id.match(/^presentations_prese_listing_(\d+)$/);
        if (parts && parts[1] ) page_load_time = parts[1];
    });
    return page_load_time;
}

function presentations_more_attach( button, container_id, load_time, ids_json ) {
    dojo.connect( button, 'onclick', function( evt ) {
        evt.preventDefault();
        dojo.xhrPost({
            url: button.href,
            handleAs: "json",
            content : {
                page_load : load_time,
                shown_entry_ids : ids_json
            },
            load: function(data, evt) {
                var container = dojo.byId( 'presentations_more_container_' + container_id );
                if ( ! container ) return;
                container.innerHTML = data.messages_html;
                process_presentations();
            },
            error: function(type, error) {
                alert('Could not fetch more messages. Please try again.');
            }
        });
    } );
}

function process_presentations_rate() {
    var links_containers = dojo.query('.presentations_rate_links');
    
    for ( var i = 0; i < links_containers.length; ++i) {
        var links_div = links_containers[i];
        if ( dojo.hasClass( links_div, 'presentations_rate_links_processed' ) ) continue;
        dojo.addClass( links_div, 'presentations_rate_links_processed' );
        var parts = dojo.attr(links_div, 'id').match(/^presentations_rate_links_(\d+)$/);
        if ( ! parts || ! parts[1] ) continue;
        
        var enabled = 1;
        if ( dojo.hasClass( links_div, 'presentations_rating_disabled' ) ) enabled = 0;
        
        var post_id = parts[1];
        var buttons = dojo.query('.presentations_rate_link_'  + post_id);
        for ( var j in buttons ) {
            presentations_rate_attach( buttons[j], post_id, enabled );
        }
    }
}

function presentations_rate_attach( button, post_id, enabled ) {
    dojo.connect( button, 'onclick', function( evt ) {
        evt.preventDefault();
        if ( enabled ) dojo.xhrPost({
            url: button.href,
            handleAs: "json",
            content : {},
            load: function(data, evt) {
                var container = dojo.byId( 'presentations_rate_container_' + post_id );
                if ( ! container ) return;
                container.innerHTML = data.messages_html;
                process_presentations();
            },
            error: function(type, error) {
                alert('Error sending vote. Please try again.');
            }
        });
    } );
}

function process_presentations_select() {
    var links_containers = dojo.query('.presentations_type_select');
    
    for ( var i = 0; i < links_containers.length; ++i ) {
        var links_div = links_containers[i];
        if ( dojo.hasClass( links_div, 'presentations_type_select_processed' ) ) continue;
        dojo.addClass( links_div, 'presentations_type_select_processed' );
        var input_element = dojo.byId('presentations_type_select_input');
        var buttons = dojo.query('.presentations_type_select_link');
        for ( var j = 0; j < buttons.length; ++j ) {
            presentations_select_attach( buttons[j], input_element );
            presentations_select_refresh( buttons[j], input_element );
        }
    }
}

function presentations_select_attach( button, input_element ) {
    dojo.connect( button, 'onclick', function( evt ) {
        evt.preventDefault();
        input_element.value = button.title;
        presentations_select_refresh_all( input_element );
    } );
}

function presentations_select_refresh_all( input_element ) {
    var buttons = dojo.query('.presentations_type_select_link');
    for ( var i = 0; i < buttons.length; ++i) {
        presentations_select_refresh( buttons[i], input_element );
    }
}

function presentations_select_refresh( button, input_element ) {
    if ( input_element.value == button.title ) {
        dojo.addClass( button, 'selected' );
    }
    else {
        dojo.removeClass( button, 'selected' );
    }
}

var presentations_mediacard_current_id = '';

function process_presentations_mediacards() {
    var controls = dojo.query('.function-mediacard-control');
    
    for ( var i in controls ) {
        var control = controls[i];
        presentations_mediacard_connect( control );
    }

    presentations_select_mediacard( 'mediacard-control-1' );

    var prev_controls = dojo.query('.function-mediacard-control-prev');
    for ( var i in prev_controls ) {
        var prev_control = prev_controls[i];
        presentations_mediacard_connect_move( prev_control, 'prev' );
    }
    var next_controls = dojo.query('.function-mediacard-control-next');
    for ( var i in next_controls ) {
        var next_control = next_controls[i];
        presentations_mediacard_connect_move( next_control, 'next' );
    }
}


function presentations_mediacard_connect( control ) {
    dojo.connect( control, 'onclick', function( evt ) {
        evt.preventDefault();
        presentations_select_mediacard( control.id );
    } );
}


function presentations_select_mediacard( id ) {
    // clear previous selecteds, hide previous pages
    var controls = dojo.query('.function-mediacard-control');
    
    for ( var i in controls ) {
        var control = controls[i];
        dojo.removeClass( control, 'selected' );
        var page = dojo.byId( control.id + '-list');
        if (page) page.style.display = 'none';
    }
    
    // find new control, add selected, show page, connect next & prev
    var control = dojo.byId( id );
    if ( ! control ) { return false; }

    presentations_mediacard_current_id = control.id;

    dojo.addClass( control, 'selected' );
    var page = dojo.byId( control.id + '-list');
    if (page) page.style.display = 'block';
}

function presentations_mediacard_connect_move( move_control, move_type ) {
    dojo.connect( move_control, 'onclick', function( evt ) {
        evt.preventDefault();
        var imitate = dojo.query('.function-'+presentations_mediacard_current_id+'-'+move_type);
        if ( imitate && imitate[0] ) {
            presentations_select_mediacard( imitate[0].id );
        }
    } );
}

function process_presentations_show() {
    var cards = dojo.query('.function-presentations-show');
    for ( var i in cards ) {
        var card = cards[i];
        presentations_show_connect( card );
    }
}

function process_presentations_show_hide() {
    dojo.query('.function-presentations-show-hide').forEach( function ( hide ) {
        dojo.connect( hide, 'onclick', function( evt ) {
            evt.preventDefault();
            presentations_show_hide_execute();
        } );
    } );
}

function process_presentations_show_initial() {
    var template_node = dojo.byId('presentations-initial-open-template');
    if ( ! template_node || ! template_node.href ) return;
    var url = document.location.href + "";
    var anc = url.match(/#(\d+)_(\d+)_(\d+).*/);
    if ( anc ) {
        var template = template_node.href;
        var prese_url = template.replace(/---id---/, anc[1] );
        presentations_show_open( prese_url, anc[2], anc[3]);
    }
}

function presentations_show_connect( card ) {
    dojo.connect( card, 'onclick', function( evt ) {
        evt.preventDefault();
        presentations_show_open( card.href );
    } );
}

function presentations_show_open( prese_url, thread_id, comment_id ) {
    var show_wrapper = dojo.byId('presentations-show-container-wrapper');
    var viewportHeight = getViewport().height;
    show_wrapper.style.width = "100%";
    show_wrapper.style.height = ( viewportHeight + 1000 ) + "px";
    show_wrapper.style.display = 'block';
    if (document.all && !window.opera && !window.XMLHttpRequest) {
        var viewportWidth = getViewport().width;
        show_wrapper.style.width = ( viewportWidth - 5 ) + 'px';
    }

    dojo.xhrGet({
        encoding: 'utf-8',
        url: prese_url,
	handleAs: "json",
        load: function( data ){
            if ( data.presentation_html ) {
                dojo.query('.mceEditor').forEach( function ( e ) {
                    tinyMCE.execCommand('mceRemoveControl', false, e.id);
                } );

                var show_container = dojo.byId('presentations-show-container');
                show_container.innerHTML = data.presentation_html;
                process_presentations_rate();
                process_comments_containers();
                process_comments_messages();
                process_presentations_show_hide();
                process_presentations_jw_player();

                dojo.query('.mceEditor').forEach( function ( e ) {
                    tinyMCE.execCommand('mceAddControl',false,e.id);
                } );

                var elementWidth = ( getViewport().width - 492 ) / 2;

                show_container.style.top = "35px";
                show_container.style.left = elementWidth + "px";
                show_container.style.width = "492px";
                show_container.style.display = 'block';

                if(thread_id && comment_id)
                {
                    var comment_id_tag = "#comments_message_".concat(thread_id, "_", comment_id);
                    var comment = dojo.query(comment_id_tag)[0];
                    var coordinates = dojo.coords(comment);
                    window.scrollTo(coordinates.x, coordinates.y);
                }

                // TODO: adjust wrapper size?
            }
            else {
                presentations_show_hide_execute();
                alert('Failed to fetch presentation data. Please try again later.');
            }
        },
        error: function( error ) {
            presentations_show_hide_execute();
            alert('Failed to fetch presentation data. Please try again later.');
        }
    } );
}

function presentations_show_hide_execute() {
    var show_container = dojo.byId('presentations-show-container');
    show_container.style.display = 'none';
    show_container.innertHTML = '';
    var show_wrapper = dojo.byId('presentations-show-container-wrapper');
    show_wrapper.style.display = 'none';
}

function process_presentations_jw_player() {
    var jwobjects = dojo.query('.function-presentations-jw-object');
    for ( var i = 0; i < jwobjects.length; ++i ) {
        var obj = jwobjects[i];
        var id = obj.id;
        var s1 = new SWFObject('/js/player.swf', obj.id + '-player','400','300','9');
        s1.addParam('allowfullscreen','true');
        s1.addParam('allowscriptaccess','always');
        s1.addParam('flashvars','file='  + escape( obj.href ) + '&image=' + escape( obj.title ) );
        s1.write(obj.id);
    }
}

function process_presentations_search() {
    var inp = dojo.byId('media-search');
    if ( ! inp ) return;
    dojo.connect( inp, 'onfocus', function ( evt ) { inp.value=""; } );
    var frm = dojo.byId('media-search-form');
    if ( ! frm ) return;
    dojo.connect( inp, 'onkeypress', function ( evt ) { frm.submit(); } );
}

function process_presentations_add() {
    var upload = dojo.byId('media-add-tab-upload');
    var fetch = dojo.byId('media-add-tab-fetch');
    if ( ! upload || ! fetch ) return;

    dojo.connect( upload, 'onclick', function( evt ) {
        evt.preventDefault();
        process_presentations_add_select( upload, fetch );
    } );

    dojo.connect( fetch, 'onclick', function( evt ) {
        evt.preventDefault();
        process_presentations_add_select( fetch, upload );
    } );
}

function process_presentations_add_select( on, off ) {
    var onli = dojo.byId(on.id + '-li');
    var offli = dojo.byId(off.id + '-li');

    if ( offli ) dojo.addClass(offli, 'unselected');
    if ( offli ) dojo.removeClass(offli, 'selected');
    if ( onli ) dojo.addClass(onli, 'selected');
    if ( onli ) dojo.removeClass(onli, 'unselected');
    
    var onc = dojo.byId(on.id + '-content');
    var offc = dojo.byId(off.id + '-content');
    if ( onc ) onc.style.display = '';
    if ( offc ) offc.style.display = 'none';

    var one = dojo.byId(on.id + '-explanation');
    var offe = dojo.byId(off.id + '-explanation');
    if ( one ) one.style.display = '';
    if ( offe ) offe.style.display = 'none';
}

function process_presentations_ie6_tooltips() {
    if (document.all && !window.opera && !window.XMLHttpRequest) {
        dojo.query('.function-presentations-show').forEach( function ( card ) {
            var tooltip = dojo.byId( card.id + '-tooltip' );
            if ( ! tooltip ) return;
            dojo.connect( card, 'onmouseover', function( evt ) {
                tooltip.style.display = 'block';
            } );
            dojo.connect( card, 'onmouseout', function( evt ) {
                tooltip.style.display = 'none';
            } );
        } );
    }
}

function process_presentations() {
    process_presentations_more();
    process_presentations_rate();
    process_presentations_select();

// Breaks atleast the links in the old media section... fix later
/*    process_presentations_mediacards();
    process_presentations_show();
    process_presentations_jw_player();
    process_presentations_add();
    process_presentations_ie6_tooltips();
    process_presentations_show_initial();*/
    
    dojo.query(".js_dicole_scribd_file").forEach(function(scribd_tag) {
    	var id = scribd_tag.title.split(",")[0];
    	var key = scribd_tag.title.split(",")[1];
    	var type = scribd_tag.title.split(",")[2];
    	var scribd_doc = scribd.Document.getDoc(id, key);
    	scribd_doc.addEventListener("iPaperReady", function(event) {});
		scribd_doc.addParam("jsapi_version", 1);
		scribd_doc.addParam("height", 400);
		if(type == "slideshow") scribd_doc.addParam("mode", "slide");
		else scribd_doc.addParam("mode", "list");
		scribd_doc.write(scribd_tag.id);
    });
}

function getViewport() {
	if ( typeof window.innerWidth != 'undefined' ) {
    		return { width : window.innerWidth, height : window.innerHeight };
        }
        else if ( typeof document.documentElement != 'undefined' &&
            typeof document.documentElement.clientWidth != 'undefined' &&
            document.documentElement.clientWidth != 0 ) {
	    	return { width : document.documentElement.clientWidth, height : document.documentElement.clientHeight };
        }
        else {
	    	return { width : document.getElementsByTagName('body')[0].clientWidth, height : document.getElementsByTagName('body')[0].clientHeight };
        }
}
