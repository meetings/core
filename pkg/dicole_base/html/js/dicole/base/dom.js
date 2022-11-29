dojo.provide('dicole.base.dom');

dojo.require('dojo.fx');
dojo.require('dojo.window');
dojo.require('dojo.io.script');

dojo.require("dicole.invite");
dojo.require("dicole.user_manager");

dojo.addOnLoad(function() {
	var logout_link = dojo.byId("navi_logout_link");
	if(logout_link) {
        if ( ! ( typeof( FB ) == 'undefined' ) ) {
    		dojo.connect(logout_link, "onclick", null, function(event) {
                event.preventDefault();
                FB.getLoginStatus(function(response) {
                    if(response.status === 'connected') {
                        FB.logout(function(response) {
                            window.location = logout_link.href;
                        });
                    }
                    else window.location = logout_link.href;
                });
            });
        }
	}
});

dicole.facebook_login = function() {
	FB.getLoginStatus(function(response) {
		if(response.status === 'connected') dicole.handle_facebook_login();
		else {
			FB.login(function(response2) {
				if(response2.authResponse) dicole.handle_facebook_login();
				else alert("Failed to login with Facebook!");
			});
		}
	});
};

dicole.facebook_register = function() {
	FB.getLoginStatus(function(response) {
		if(response.status === 'connected') {
			dicole.user_manager.open_register_dialog();
			dicole.user_manager.prefill_register_dialog_from_facebook(response.authResponse.accessToken);
		}
		else {
			FB.login(function(response2) {
				if(response2.authResponse) {
					dicole.user_manager.open_register_dialog();
					dicole.user_manager.prefill_register_dialog_from_facebook(response2.authResponse.accessToken);
				}
				else alert("Failed to login with Facebook!");
			}, {"scope": "email"});
		}
	});
};

dicole.handle_facebook_login = function() {
	dojo.xhrPost({
		"url": dicole.get_global_variable("who_am_i_url"),
        "content": { login_fb : 1 },
		"handleAs": "json",
		"handle": function(response) {
			if(response.result == 0) dicole.facebook_register();
			else window.location = dicole.get_global_variable("url_after_login");
		}
	});
};

dicole.unprocessed_class_query = function( cls, container ) {
    var results = new dojo.NodeList();
    dojo.query( '.' + cls, container ).forEach( function(node) {
        if ( ! dojo.hasClass( node, cls + '_processed' ) ) {
            dojo.addClass( node, cls + '_processed' );
            results.push( node );
        }
    } );

    return results;
}

dicole.ucq = dicole.unprocessed_class_query;

dojo.subscribe("new_node_created", function(node) {
    dicole.fix_ext_link_targets(node);
});

dojo.subscribe("new_node_created", function(node) {
	dicole.ucq("js_hook_refresh_page", node).forEach(function(element) {
		dojo.connect(element, "onclick", null, function(event) {
			event.preventDefault();
            location.reload(true);
		});
	});
});

dojo.subscribe("new_node_created", function(node) {
	dicole.ucq("js_facebook_login").forEach(function(element) {
		dojo.connect(element, "onclick", null, function(event) {
			event.preventDefault();
			dicole.facebook_login();
		});
	});
});

dojo.subscribe("new_node_created", function(node) {
	dicole.ucq("js_facebook_register").forEach(function(element) {
		dojo.connect(element, "onclick", null, function(event) {
			event.preventDefault();
			dicole.facebook_register();
		});
	});
});

dicole.process_new_node = function( node ) {
    dojo.publish( 'new_node_created', [ node ] );
}

dojo.subscribe( 'new_node_created', function( node ) {
    dicole.ucq('dicole_showroom_link', node ).forEach( function( anode ) {
        var args = dojo.fromJson( dojo.attr( anode, 'title' ) );
        if ( ! args ) {
            return;
        }
        dojo.attr( anode, 'title', args[0] );

        // lol @ tinymce hacks
        var raw = args[3];
        var real = raw.replace(/ tinymcehackfix(src|href|style|coords|shape)=/gi, function( m, b ) { return ' '+ b + '='; } );

        dojo.connect( anode, 'onclick', function( evt ) {
            evt.preventDefault();
            dicole.create_showcase( {
                'title' : args[0],
                'width' : args[1],
                'height' : args[2],
                'show_duration' : 1500, // longer duration for the content to load
                'iframe' : real
            } );
        } );
    } );
} );

dojo.subscribe( 'new_node_created', function( node ) {
    if ( typeof DD_belatedPNG != 'undefined' ) {
        DD_belatedPNG.fix( '.alpha_png' );
    }
} );

dojo.subscribe( 'new_node_created', function( node ) {
	dojo.query(".tip-field", node).forEach(function(tip_field) {
		dojo.connect(tip_field, "onfocus", null, function() {
			dojo.addClass(tip_field, "selected");
			if(tip_field.value == tip_field.defaultValue ) tip_field.value = "";
		});
		dojo.connect(tip_field, "onblur", null, function() {
			if( ! tip_field.value.length && ! dojo.hasClass( tip_field, 'tip-once' ) ) {
				dojo.removeClass(tip_field, "selected");
				tip_field.value = tip_field.defaultValue;
			}
		});
	});
});

dojo.subscribe( 'new_node_created', function( node ) {
	dicole.ucq("js_tip_field", node).forEach(function(tip_field) {
		dojo.connect(tip_field, "onfocus", null, function() {
			dojo.addClass(tip_field, "js_tip_field_selected");
			if(tip_field.value == tip_field.defaultValue ) tip_field.value = "";
		});
		dojo.connect(tip_field, "onblur", null, function() {
			if( ! tip_field.value.length && ! dojo.hasClass( tip_field, 'js_tip_once' ) ) {
				dojo.removeClass(tip_field, "js_tip_field_selected");
				tip_field.value = tip_field.defaultValue;
			}
		});
	});
});

dojo.subscribe( 'new_node_created', function( node ) {
	dicole.ucq("js_focus", node).forEach(function(field) {
        // IE7 and IE8 would die if the field is not visible
        try { field.focus(); }
        catch(e) {}
    } );
});

dojo.subscribe( 'new_node_created', function( node ) {
	dicole.ucq("js_focus_select_all", node).forEach(function(field) {
		dojo.connect(field, "onfocus", null, function() {
            field.select();
		});
	});
});

dojo.subscribe( 'new_node_created', function( node ) {
	dojo.query(".js_open_more").forEach(function(node) {
        var nodeid = dojo.attr( node, 'id' );
        if ( ! nodeid ) { return }
        dicole.ucq( 'js_' + nodeid + '_more_button').forEach( function( open_button ) {
		    dojo.connect(open_button, "onclick", null, function( evt ) {
                evt.preventDefault();
                if ( dojo.hasClass( node, 'js_more_opened' ) ) {
                    dojo.removeClass( node, 'js_more_opened' );
                    dojo.removeClass( open_button, 'js_more_opened' );
                    dojo.style( node, 'display', null );
                    dojo.query( '.js_' + nodeid + '_more_container').forEach( function ( more_container ) {
                        dojo.style( more_container, 'display', 'none' );
                    } );
                }
                else {
                    dojo.addClass( node, 'js_more_opened' );
                    dojo.addClass( open_button, 'js_more_opened' );
                    dojo.style( node, 'display', 'none' );
                    dojo.query( '.js_' + nodeid + '_more_container').forEach( function ( more_container ) {
                        dojo.style( more_container, 'display', 'block' );
                    } );
                    if ( dojo.attr( open_button, 'data-hide-on-more' ) ) {
                        dojo.style( open_button, 'display', 'none');
                    }
                }
      		});
        });
	});
});



dojo.subscribe( 'new_node_created', function( node ) {
    dicole.ucq("js_dicole_jw_object", node ).forEach( function( placeholder_node ) {
        try {
            var dat = dojo.fromJson( dojo.attr( placeholder_node, 'title' ) );
            var dim = dojo.contentBox( placeholder_node.parentNode );
            var w = dim.w ? dim.w : 400;
            var h = dat.type == 'video' ? Math.ceil( w * 3 / 4 ) : '40';

            dojo.attr( placeholder_node, 'title', dat.title );

            var v = document.createElement("video");
            var a = document.createElement("audio");

            if ( dat.type == 'video' && v && v.pause ) {
                var video_tag = [
                    '<video width="' + w + '" height="' + h + '" controls>',
                        '<source src="' + dat.mp4_file + '"  type="video/mp4" />',
                        '<source src="' + dat.ogv_file + '"  type="video/ogg" />',
                    '</video>'
                ].join("");
                dojo.place( video_tag, placeholder_node, 'replace' );
            }
            else if ( dat.type == 'audio' && a && a.pause ) {
                var audio_tag = [
                    '<audio controls>',
                        '<source src="' + dat.mp3_file + '"  type="audio/mp3" />',
                        '<source src="' + dat.ogg_file + '"  type="audio/ogg" />',
                    '</audio>'
                ].join("");
                dojo.place( audio_tag, placeholder_node, 'replace' );
            }
            else {
                var s1 = new SWFObject('/js/player.swf', placeholder_node.id + '-player',w,h,'9');
                s1.addParam('allowfullscreen','true');
                s1.addParam('allowscriptaccess','always');
                s1.addParam('flashvars','controlbar=over&file='  + escape( dat.fallback_file ) + ( dat.image ? '&image=' + escape( dat.image ) : '' ) );
                s1.write(placeholder_node.id);
            }
        }
        catch (e) {}
    } );
} );

dojo.subscribe( 'new_node_created', function( node ) {
    dicole.ucq("js_dicole_scribd_file", node ).forEach( function( divnode ) {
        if ( ! dicole.scribd_javascript_inserted ) {
            var ScribdJsHost = (("https:" == document.location.protocol) ? "https://" : "http://");
            dicole.scribd_javascript_inserted = dojo.io.script.get( {
                url : ScribdJsHost + 'www.scribd.com/javascripts/scribd_api.js',

                load : function() {
                    dojo.transform_scribd_div( divnode );
                }
            } );
        }
        else {
            dojo.transform_scribd_div( divnode );
        }
    } );
} );

dojo.transform_scribd_div = function ( divnode ) {
    if ( dicole.scribd_javascript_inserted.fired == -1 ) {
        dicole.scribd_javascript_inserted.addBoth( function() {
            dojo.transform_scribd_div( divnode );
        } );
    }
    else {
        var args_string = dojo.attr( divnode, 'data-scribd-args') || dojo.attr( divnode, 'title');
        var args = args_string.split(",");

        var scribd_doc = scribd.Document.getDoc( args[0], args[1] );

        // this eventlistener prevents a lot of errors from happening:
        scribd_doc.addEventListener("iPaperReady", function() {});

        scribd_doc.addParam("jsapi_version", 2);

        var type = args[2];
        // TODO: currently no intelligent type is given so use slide, which uses scale to fit
        scribd_doc.addParam( "mode", type == 'slideshow' ? "slide" : "slide" );

        scribd_doc.addParam("hide_disabled_buttons", true);
        if ( 'https:' == document.location.protocol ) {
            scribd_doc.addParam("use_ssl", true);
        }

        if ( args[3] ) {
            scribd_doc.addParam("width", args[3] );
        }

        if ( args[4] ) {
            scribd_doc.addParam("height", args[4] );
        }
        else {
            if ( type == 'slideshow' ) {
                scribd_doc.addParam("height", 500 );
            }
        }

        var is_ipad = navigator.userAgent.match(/iPhone|iPad|iPod/i) != null ? true : false;

        scribd_doc.addParam("default_embed_format", is_ipad ? "html5" : "flash");

        scribd_doc.write( divnode.id );
    }
}

dojo.subscribe( 'new_node_created', function( n ) {
	dicole.ucq('js_tooltip', n).forEach( function ( node ) {
		dojo.connect(node, "onmouseenter", function( evt ) {
			var width = dojo.attr(node, 'data-tooltip-width');
			var max_width = dojo.attr(node, 'data-tooltip-max-width');
			if ( ! width ) { width = null; }
            if ( ! max_width ) { max_width = 300; }

            var tip_class = dojo.attr( node, 'data-tooltip-class' );
			var node_id = dojo.attr( node, 'data-tooltip-nodeid' );
			var content = dojo.attr( node, 'data-tooltip-text' );
			var directions = dojo.attr( node, 'data-tooltip-directions' );

            directions = ( directions ? directions + ',' : '' ) + 'up,down,right,left';
            directions = directions.split(",");

			if ( content ) {
				dicole.tooltip_show( dicole.encode_html( content ), width, max_width, tip_class, evt, directions );
			}
			else if ( node_id ) {
				var content_node = dojo.byId(node_id);
				if ( content_node ) {
					dicole.tooltip_show(content_node.innerHTML, width, max_width, tip_class, evt, directions );
				}
			}
		});
		dojo.connect(node, "onmouseleave", function() {
			dicole.tooltip_hide();
		});
	} );
} );

dicole.tooltip_id = 'dicole_base_tooltip'
dicole.tooltip_bottom_margin = 10;
dicole.tooltip_top_margin = 20;
dicole.tooltip_right_margin = 10;
dicole.tooltip_left_margin = 20;
dicole.tooltip_unique_container;
dicole.tooltip_mousemove_connect;
dicole.tooltip_fadein_animation;

dicole.tooltip_show = function( content, width, max_width, tip_class, enter_event, directions ) {
    var tt = dicole.tooltip_unique_container;

    if ( ! tt ) {
        tt = dicole.tooltip_unique_container = dojo.create( 'div', { id : dicole.tooltip_id } );

        // Position the tooltip to top left of screen, to avoid flashing scroll bars
        dojo.style( tt, {
            position: 'absolute',
            top: 0,
            left: 0
        } );

        dojo.place( tt, dojo.body() );
    }

    tt.innerHTML = content;

    dojo.style( tt, {
        zIndex: 5000,
        display: 'block',
        opacity : 0
    } );

    dojo.attr( tt, 'className', '' );

    if ( tip_class ) {
		dojo.addClass( tt, tip_class);
	}
	else {
		dojo.addClass( tt, 'tooltip-normal');
	}

    if ( width ) {
        dojo.style( tt, { width : width + 'px' } );
    }
    else {
        // These are separate dojo.style -calls so that tt.offsetWidth
        // manages to update for each calculation

        dojo.style( tt, { width : dojo.isIE ? max_width + 'px' : 'auto' } );

        if ( tt.offsetWidth > max_width ){
            dojo.style( tt, { width : max_width + 'px' } );
        }
    }

    if ( dicole.tooltip_mousemove_connect ) {
        dojo.disconnect( dicole.tooltip_mousemove_connect );
        dicole.tooltip_mousemove_connect = false;
    }

    var tooltip_height = parseInt(tt.offsetHeight);
    var tooltip_width = parseInt(tt.offsetWidth);
    var viewport = dojo.window.getBox();

    dicole.tooltip_mousemove_connect = dojo.connect(document, "onmousemove", function( e ) {
        dicole.tooltip_position_by_event( e, tt, tooltip_width, tooltip_height, viewport, directions );
    });

    dicole.tooltip_position_by_event( enter_event, tt, tooltip_width, tooltip_height, viewport, directions );

    dicole.tooltip_fadein_animation = dojo.fadeIn({ node : tt, duration : 300 }).play();
};

dicole.tooltip_position_by_event = function( e, tt, tooltip_width, tooltip_height, viewport, directions ) {
        var t = dojo.isIE ? event.clientY + document.documentElement.scrollTop : e.pageY;
        var l = dojo.isIE ? event.clientX + document.documentElement.scrollLeft : e.pageX;

        var chosen_direction = directions[0];

        for ( var i = 0; i < directions.length; i++ ) {
            if ( dicole.tooltip_fits_in_direction( directions[i], t, l, tooltip_width, tooltip_height, viewport ) ) {
                chosen_direction = directions[i];
                break;
            }
        }

        dojo.style( tt,
            dicole.tooltip_style_in_direction( chosen_direction, t, l, tooltip_width, tooltip_height, viewport )
        );
}

dicole.tooltip_style_in_direction = function( d, t, l, w, h, v ) {
    if ( d == 'up' || d == 'down' ) {
        var top_offset = ( d == 'up' ) ? t - h - dicole.tooltip_bottom_margin : t + dicole.tooltip_top_margin;

        var left_offset = l - ( w / 2 - w % 2 );

        if ( left_offset + w + 2 > v.w + v.l ) {
            left_offset = v.w - w - 2 + v.l;
        }

        if ( left_offset < 2 + v.l ) {
        	left_offset = 2 + v.l;
        }

        return {
            'top' : top_offset + 'px',
            'left' : left_offset + 'px'
        };
    }
    else {
        var left_offset = ( d == 'right' ) ? l + dicole.tooltip_left_margin : l - w - dicole.tooltip_right_margin;

        var top_offset = t - ( h / 2 - h % 2 );

        if ( top_offset + h + 2 > v.h + v.t ) {
            top_offset = v.h - h - 2 + v.t;
        }

        if ( top_offset < 2 + v.t ) {
            top_offset = 2 + v.t;
        }

        return {
            'top' : top_offset + 'px',
            'left' : left_offset + 'px'
        };
    }
}

dicole.tooltip_fits_in_direction = function( d, t, l, w, h, v ) {
    if ( d == 'up' ) {
        if ( t - h - dicole.tooltip_bottom_margin - 2 < v.t ) return false;
    }
    else if ( d == 'down' ) {
        if ( t + h + dicole.tooltip_top_margin + 2 > v.h + v.t ) return false;
    }
    else if ( d == 'right' ) {
        if ( l + w + dicole.tooltip_left_margin + 2 > v.w + v.l ) return false;
    }
    else if ( d == 'left' ) {
        if ( l - w - dicole.tooltip_right_margin - 2 < v.l ) return false;
    }
    return true;
}

dicole.tooltip_hide = function() {
    if ( dicole.tooltip_mousemove_connect ) {
        dojo.disconnect( dicole.tooltip_mousemove_connect );
        dicole.tooltip_mousemove_connect = false;
    }
    if ( dicole.tooltip_fadein_animation ) {
        dicole.tooltip_fadein_animation.stop();
        dicole.tooltip_fadein_animation = false;
    }

    dojo.destroy( dicole.tooltip_unique_container );
    dicole.tooltip_unique_container = '';
};

dicole.fix_ext_link_targets = function( node ) {
    dojo.query('a' , node).forEach( function(element) {
        try {
            if( dicole.url_not_local( element.href ) ) {
                dojo.attr( element, 'target', '_blank' );
            }
            else{
            }
        }
        catch(err) {
        }
    });
}

dicole.url_not_local = function( url ) {
    var match = url.match(/^([^:\/?#]+:)?(?:\/\/([^\/?#]*))?([^?#]+)?(\?[^#]*)?(#.*)?/);
    // Skip protcol checking
    // if (typeof match[1] === "string" && match[1].length > 0 && match[1].toLowerCase() !== location.protocol) return true;
    var host = location.host;
    if( ! match[2] ) return false;
    var test = match[2].replace(new RegExp(":("+{"http:":80,"https:":443}[location.protocol]+")?$"), "");
    test = test.replace(/^www./, ""); // ignore www in the beginnning
    host = host.replace(/^www./, "");
    if (typeof match[2] === "string" && match[2].length > 0 && test !== host) return true;
    return false;
};

/*
// defaults
args = {
    disable_close : false,
    reload_on_close : false,
    disable_background_close : false,
    vertical_align : 'center', // [ center | top ]

    title : '',
    width : 'auto', // note that width: auto is bugged in IE
    height : 'auto',
    show_duration : 500,
    wipe_delay : 2* show_duration / 3,
    hide_duration : 500,

    post_content_hook : FUNCTION,

    // either one of these. they are both content strings but
    // iframe takes precedence and is loaded inside an iframe
    // from an another domain
    iframe : '',
    content : '',

    // this is an another way to define content for showcase
    dom_node : DOM_NODE,

    // and this is an another
    gather_content : FUNCTION( CONTENT_CALLBACK )
}
*/

dicole._showcases = [];

dojo.subscribe("new_node_created", function(node) {
	dicole.ucq("js_hook_showcase_close", node).forEach(function(element) {
		dojo.connect(element, "onclick", null, function(event) {
			event.preventDefault();
			dojo.publish('showcase.close');
		});
	});
});

dojo.subscribe( 'showcase.close', function() {
    var showcase = dicole._showcases.pop();

    if ( ! showcase || showcase.hide_animation ) {
        return;
    }

    if ( showcase.pre_close_hook ) {
        showcase.pre_close_hook();
    }

    dojo.forEach(showcase.hidden_elements, function(element) {
        dojo.style(element, "visibility", "");
    });

    dojo.forEach(dicole._showcases, function(showcase2) {
        dojo.forEach(showcase2.hidden_elements, function(element) {
            dojo.style(element, "visibility", "hidden");
        });
    });

    if( showcase.reload_on_close ) {
        location.reload(true);
        return;
    }

    if ( showcase.fade_animation ) {
        showcase.fade_animation.stop();
    }

    if ( showcase.wipe_animation ) {
        showcase.wipe_animation.stop();
    }

    dojo.style( showcase.nodes.wrapper, 'visibility', 'hidden' );

    // All IE borsers seem to suck with transparency..
    showcase.hide_animation = dojo.isIE ?
        dojo.animateProperty( {
            node : showcase.nodes.fade_container,
            properties : { opacity : { start : 0.6, end : 0 } },
            duration : showcase.hide_duration
        } )
        :
        dojo.fadeOut( {
            node : showcase.nodes.fade_container,
            duration : showcase.hide_duration
        } );

    dojo.connect( showcase.hide_animation, 'onEnd', function() {
        if ( showcase.nodes.dom_node ) {
            dojo.style( showcase.nodes.dom_node, 'display', 'none' );
            dojo.place( showcase.nodes.dom_node, dojo.body() );
        }
        dojo.destroy( showcase.nodes.container );
        // leave hide_animation to hash so that it signals
        // possible wipe timeout to bail
    } );

    showcase.hide_animation.play();
} );

dicole.create_showcase = function( args ) {
    var showcase = {
        "nodes" : {},
        "pre_close_hook" : args.pre_close_hook,
        "last_sanity_test" : 0,
        "reload_on_close" : args.reload_on_close,
        "vertical_align" : args.vertical_align,
        "previous_coords" : "",
        "hidden_elements": []
    };

    showcase.hidden_elements = dojo.query("object, embed");
    showcase.hide_underlying_elements = function() {
        dojo.forEach(showcase.hidden_elements, function(element) {
        	dojo.style(element, "visibility", "hidden");
        });
    };

    if ( ! args.skip_underlying_element_hiding ) {
        showcase.hide_underlying_elements();
    }

    var hide_duration = args.hide_duration;
    if ( ! hide_duration && hide_duration !== 0 ) {
        hide_duration = 200;
    }
    showcase.hide_duration = hide_duration;

    dicole._showcases.push( showcase );
    showcase.z_index = dicole._showcases.length;

    // this container exists so that we can easily demolish the object
    var container = dojo.create('div', {}, dojo.body() );
    dojo.style( container, 'textAlign', 'left' );
    showcase.nodes.container = container;

    // this is an extra container that makes it possible to apply
    // opacity values to the fade in IE6
    var fade_container = dojo.create('div', {}, container );
    dojo.style( fade_container, 'display', 'block' );
    dojo.style( fade_container, 'position', 'absolute' );
    dojo.style( fade_container, 'top', '0px' );
    dojo.style( fade_container, 'left', '0px' );
    dojo.style( fade_container, 'opacity', '0' );
    dojo.style( fade_container, 'zIndex', 1000 + ( showcase.z_index * 10 ) + 1 );
    showcase.nodes.fade_container = fade_container;

    var fade = dojo.create('div', {}, fade_container );
    dojo.style( fade, 'backgroundImage', 'url(/js/overlay.png)' );
    if ( typeof DD_belatedPNG != 'undefined' ) {
        DD_belatedPNG.fixPng( fade );
    }
    showcase.nodes.fade = fade;

    var fade_anchor = dojo.create('a', { "href" : '#' }, container );
    dojo.style( fade_anchor, 'display', 'block' );
    dojo.style( fade_anchor, 'position', 'absolute' );
    dojo.style( fade_anchor, 'top', '0px' );
    dojo.style( fade_anchor, 'left', '0px' );
    dojo.style( fade_anchor, 'zIndex', 1000 + ( showcase.z_index * 10 ) + 2 );
    showcase.nodes.fade_anchor = fade_anchor;

    var wrapper = dojo.create('div', {}, container );
    dojo.style( wrapper, 'position', 'absolute' );
    dojo.style( wrapper, 'top', '0px' );
    dojo.style( wrapper, 'left', '0px' );
//    dojo.style( wrapper, 'height', '0px' );
    dojo.style( wrapper, 'visibility', 'hidden' );
    dojo.style( wrapper, 'overflow', 'visible' );
    dojo.style( wrapper, 'zIndex', 1000 + ( showcase.z_index * 10 ) + 3 );
    showcase.nodes.wrapper = wrapper;

    var head = dojo.create('div', {}, wrapper );

    var close_link = false;
    if ( ! args.disable_close ) {
        close_link = dojo.create('a', { "href" : '#', innerHTML : 'x' }, head );
        dojo.style( close_link, 'color', 'white' );
        dojo.style( close_link, 'float', 'right' );
        dojo.style( close_link, 'fontSize', '16px' );
    }

    if ( args.title ) {
        var tit = dojo.create('span', { innerHTML : dicole.encode_html( args.title ) }, head );
        dojo.style( tit, 'fontSize', '16px' );
        dojo.style( tit, 'color', 'white' );
    }

    if ( args.iframe ) {
        var domain = ( document.location.host.toString().indexOf('dev') == -1 ) ? 'secureframe.dicole.net' : 'secureframe-dev.dicole.net';
        var ifr = dojo.create('iframe', {
            "src" : (("https:" == document.location.protocol) ? "https://" : "http://") +
                domain + '/js/mwrite.html' +
                '?m=' + encodeURIComponent( args.iframe ),
            "width" : args.width,
            "height" : args.height,
            "scrolling" : "no",
            "border" : 0,
            "frameborder" : 0
        }, wrapper );
        showcase.nodes.content = ifr;
    }
    else if ( args.dom_node ) {
        var content = args.dom_node;
        dojo.place( content, wrapper );

        dojo.style( content, 'display', 'block' );

        if ( args.width && args.width > 0 ) {
            dojo.style( content, 'width', args.width + 'px' );
        }
        else {
            dojo.style( content, 'width', 'auto' ); // this does not work well for ie.. :/
        }
        if ( args.height ) {
            dojo.style( content, 'height', args.height + 'px' );
        }
        showcase.nodes.content = content;
        showcase.nodes.dom_node = args.dom_node;
    }
    else if ( args.content ) {
        var content = dojo.create('div', { innerHTML : args.content }, wrapper );

        if ( args.width && args.width > 0 ) {
            dojo.style( content, 'width', args.width + 'px' );
        }
        else {
            dojo.style( content, 'width', 'auto' ); // this does not work well for ie.. :/
        }
        if ( args.height ) {
            dojo.style( content, 'height', args.height + 'px' );
        }
        showcase.nodes.content = content;

        dicole.process_new_node( content );
    }
    else {
        // TODO: Add a spinner animation as content?
        var content = dojo.create('div', { innerHTML : '<p style="text-align:center;"><img src="/js/showcase_spinner.gif" alt="Loading..."/></p>' }, wrapper );
        dojo.style( wrapper, 'height', 'auto' );
        dojo.style( wrapper, 'visibility', 'visible' );

        if ( args.width && args.width > 0 ) {
            dojo.style( content, 'width', args.width + 'px' );
        }
        else {
            dojo.style( content, 'width', 'auto' ); // this does not work well for ie.. :/
        }
        if ( args.height ) {
            dojo.style( content, 'height', args.height + 'px' );
        }
        showcase.nodes.content = content;
    }

    if ( close_link ) {
        dojo.connect( close_link, 'onclick', function( evt ) {
            evt.preventDefault();
            dojo.publish('showcase.close');
        } );
    }

    dojo.forEach( [ fade_container, fade_anchor ], function( node ) {
        if ( node ) {
            dojo.connect( node, 'onclick', function( evt ) {
                evt.preventDefault();
                if ( ! args.disable_background_close ) {
                    dojo.publish('showcase.close');
                }
            } );
        }
    } );

    dicole._position_showcases( [ showcase ], 1 );

    var show_duration = args.show_duration;
    if ( ! show_duration && show_duration !== 0 ) {
        show_duration = 500;
    }

    // All IE borsers seem to suck with transparency..
    showcase.fade_animation = dojo.isIE ?
        dojo.animateProperty( {
            node : fade_container,
            properties : { opacity : { start : 0, end : 0.6 } },
            duration : show_duration
        } )
        :
        dojo.fadeIn( {
            node : fade_container,
            duration : show_duration
        } );

    dojo.connect( showcase.fade_animation, 'onEnd', function() {
        showcase.fade_animation = false;
        // this is needed for IE's as the transparent PNGs
        // are not shown correctly unless all parent's opacity is 1
        dojo.style( fade_container, 'opacity', 1 );
    } );
    showcase.fade_animation.play();
    var wipe_delay = args.wipe_delay;
    if ( ! wipe_delay && wipe_delay !== 0 ) {
        wipe_delay = Math.floor( 2* show_duration / 3 );
    }

    if ( args.gather_content ) {
        args.gather_content( function( content ) {

            dojo.style( wrapper, 'visibility', 'hidden' );

            if ( typeof content === 'string' ) {
                showcase.nodes.content.innerHTML = content;
            }
            else {
                if ( content.width ) {
                    dojo.style( showcase.nodes.content, 'width', content.width + 'px' );
                }
                showcase.nodes.content.innerHTML = content.html;
            }

            dicole.process_new_node( showcase.nodes.content );

            if ( args.post_content_hook ) {
                args.post_content_hook();
            }

            dicole._start_showcase_wipe( showcase );
        } );
    }
    else {
        if ( args.post_content_hook ) {
            args.post_content_hook();
        }
        setTimeout( function() {
            dicole._start_showcase_wipe( showcase );
        }, wipe_delay );
    }

    setTimeout( dicole.position_showcases_loop, 100 );

    return showcase;
};

dicole._start_showcase_wipe = function( showcase ) {
    showcase.execute_wipe_handler = function() {
        if ( showcase.execute_wipe_handler_executed ) {
            return;
        }

        showcase.execute_wipe_handler_executed = 1;

        if ( showcase.hide_animation ) {
           return;
        }

        var wrapper = showcase.nodes.wrapper;

        dojo.style( wrapper, "opacity", "0");
        dojo.style( wrapper, 'visibility', 'visible' );

//        var q = dojo.queryToObject(dojo.doc.location.search.substr((dojo.doc.location.search[0] === "?" ? 1 : 0)));

        showcase.wipe_animation = dojo.fadeIn( {
            node : wrapper,
            duration: 300
//            duration : ( q && q.wipe_delay ) ? q.wipe_delay : 500
        } );
        dojo.connect( showcase.wipe_animation, 'onEnd', function() {
            showcase.wipe_animation = false;
            dojo.query(".js_focus_processed", wrapper ).forEach(function(field) {
                field.focus();
            } );
        } );
        showcase.wipe_animation.play();
    }
}

dicole.position_showcases_connect = false;

dicole.position_showcases_loop = function() {
    if ( ! dicole.position_showcases_connect ) {
        dicole.position_showcases_connect = dojo.connect( document, 'scroll', function () {
            dicole.position_showcases();
        } );
    }

    if ( dicole.position_showcases() ) {
        setTimeout( dicole.position_showcases_loop, 100 );
    }
    else {
        if ( dicole.position_showcases_connect ) {
            dojo.disconnect( dicole.position_showcases_connect );
            dicole.position_showcases_connect = false;
        }
    }
};

dicole.position_showcases = function() {
    return dicole._position_showcases( dicole._showcases );
}

dicole._position_showcases = function( showcases, first_time ) {
    if ( showcases.length < 1 ) {
        return;
    }

    var vp = dojo.window.getBox();
    var vps = dojo.toJson( vp );

//    var bh = Math.max(Math.max(document.body.scrollHeight, document.documentElement.scrollHeight), Math.max(document.body.offsetHeight, document.documentElement.offsetHeight), Math.max(document.body.clientHeight, document.documentElement.clientHeight));
//    var bw = Math.max(Math.max(document.body.scrollWidth, document.documentElement.scrollWidth), Math.max(document.body.offsetWidth, document.documentElement.offsetWidth), Math.max(document.body.clientWidth, document.documentElement.clientWidth));

    var bc = { w : dojo.body().scrollWidth, h : dojo.body().scrollHeight };
    var bcs = dojo.toJson( bc );

    var milliepoch = new Date().toString();

    // the sanity test failback is here because sometimes
    // IE6 renders the backgrounds with a flawed height
    dojo.forEach( showcases, function( showcase ) {
        var valigntop = showcase.vertical_align == 'top' ? true : false;
        var content = showcase.nodes.content;
        var cc = dojo.coords( content );
        delete cc.x;
        delete cc.y;
        var ccs = dojo.toJson( cc );

        var wrapper = showcase.nodes.wrapper;
        var wc = dojo.coords( wrapper );
        var wcs = dojo.toJson( wc );

        var s = vps + ' ' + bcs + ' ' + ccs + ' ' + wcs;

        if ( showcase.previous_coords != s || milliepoch > showcase.last_sanity_test + 1000 ) {

            // iPad checked because viewport is broken with zoom and virtual keyboard
            var is_ipad = navigator.userAgent.match(/iPhone|iPad|iPod/i) != null ? true : false;

            showcase.previous_coords = s;
            showcase.last_sanity_test = milliepoch;

            var fade = showcase.nodes.fade;
            var fade_anchor = showcase.nodes.fade_anchor;

            var maxh = ( bc.h > vp.h + vp.t ) ? bc.h : ( wc.h > vp.h + vp.t ) ? wc.h : is_ipad ? vp.h : vp.h + vp.t;
            var maxw = ( bc.w > vp.w + vp.l ) ? bc.w : ( wc.w > vp.w + vp.l ) ? wc.w : is_ipad ? vp.w : vp.w + vp.l;

            // we need these both because IE6 does not let you specify
            // width and height for anchors (even display:block) properly
            dojo.style( fade, 'width', maxw + 'px' );
            dojo.style( fade_anchor, 'width', maxw + 'px' );
            dojo.style( fade, 'height', maxh + 'px' );
            dojo.style( fade_anchor, 'height', maxh + 'px' );

            var bottom_safe = is_ipad ? 382 : 10;
            var top_safe = 10;
            var wt;

            if ( valigntop || vp.h < wc.h + bottom_safe + top_safe ) {
                if ( wc.t > vp.t || first_time || vp.h >= wc.h + bottom_safe + top_safe ) {
                    wt = vp.t + top_safe;
                    dojo.style( wrapper, 'top', wt + 'px' );
                }
                else if ( wc.t + wc.h + bottom_safe < vp.t + vp.h ) {
                    wt = vp.t + vp.h - bottom_safe - wc.h;
                    dojo.style( wrapper, 'top', wt + 'px' );
                }
            }
            else {
                if ( wc.h <= 50 ) {
                    wt = vp.t + top_safe;
                }
                else {
                    wt = Math.floor( vp.t + ( vp.h - bottom_safe + top_safe - wc.h ) / 2 );
                }
                dojo.style( wrapper, 'top', wt + 'px' );
            }

            dojo.style( wrapper, 'width', ( cc.w && cc.w > 0 ) ? Math.floor( cc.w ) + 'px' : 'auto' );

            if ( first_time || ! is_ipad ) {
                if ( vp.w > cc.w ) {
                    dojo.style( wrapper, 'left', Math.floor( ( is_ipad ? 0 : vp.l ) + ( vp.w - cc.w ) / 2 ) + 'px' );
                }
                else {
                    dojo.style( wrapper, 'left', '0px' );
                }
            }

            if ( wc.h > 50 && showcase.execute_wipe_handler ) {
                showcase.execute_wipe_handler();
            }
        }
    } );

    return 1;
};

dojo.addOnLoad( function() {
    dicole.process_new_node( dojo.body() );
} );

dojo.subscribe("new_node_created", function(node) {
	dojo.query(".js_validate").forEach(function(form) {
		var submit_buttons = dojo.query(".js_submit", form);
		var input_fields = dojo.query(".input_field input", form);
		var form_is_valid = function() {
			var form_is_valid = true;
			input_fields.forEach(function(element) { if(dojo.hasClass(element, "invalid")) form_is_valid = false; });
			return form_is_valid;
		}

		var run_validation = function(element, validator) {
			if(!validator(element)) {
				dojo.addClass(element, "invalid");
				dojo.addClass(element.parentNode, "invalid");
				submit_buttons.addClass("disabled");
			}
			else {
				dojo.removeClass(element, "invalid");
				dojo.removeClass(element.parentNode, "invalid");
				if(form_is_valid()) submit_buttons.removeClass("disabled");
			}
		};

		var validators = [
			{
				"class": ".js_validate_not_empty",
				"validator": validate_not_empty,
				"connect": ["onfocus", "onblur", "onkeyup", "onchange"]
			},
			{
				"class": ".js_validate_email",
				"validator": validate_email,
				"connect": ["onfocus", "onblur", "onkeyup", "onchange"]
			},
			{
				"class": ".js_validate_checked",
				"validator": validate_checked,
				"connect": ["onfocus", "onblur", "onclick"]
			}
		];

		dojo.forEach(validators, function(validator) {
			dojo.query("input" + validator["class"] + ", textarea" + validator["class"], form).forEach(function(element) {
				run_validation(element, validator["validator"]);
				dojo.forEach(validator["connect"], function(event) {
					dojo.connect(element, event, null, dojo.partial(run_validation, element, validator["validator"]));
				});
			});
		});
	});
});

function validate_not_empty(element, event) {
	return element.value.length;
}

var email_regexp = new RegExp("[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?");
function validate_email(element, event) {
	return email_regexp.test(element.value);
}

function validate_checked(element, event) {
	return element.checked;
}

dicole.init_flash_uploader = function(id, width, height, button_image, button_width) {
	width = width ? width : 215;
	height = height ? height : 145;
	button_image = button_image ? button_image : "/images/rytmikorjaamo/button-250px.png";
	button_width = button_width ? button_width : 215;

	var thumbnail_image = dojo.byId(id + "_image");
	var progress_bar = dojo.byId(id + "_progress_bar");
	var upload_button = dojo.byId(id + "_upload_button");
	var cancel_button = dojo.byId(id + "_cancel_button");
	var draft_id = dojo.byId(id + "_draft_id");

	var swfupload = new SWFUpload({
		"upload_url": dicole.get_global_variable("draft_attachment_store_url"),
		"post_params": {
			"width": width,
			"height": height
		},
		"flash_url": "/js/swfupload.swf",
		"button_placeholder_id": id + "_upload_button",
		"button_image_url": button_image,
		"button_width": button_width,
		"button_height": 26,
		"button_text": "<span class=\"flash_text\">" + dicole.msg("Upload a photo") + "</span>",
		"button_text_style": ".flash_text { text-align: center; font-family: Arial, Helvetica, sans-serif; color: #D49603; }",
		"button_text_top_padding": 3,
		"button_action": SWFUpload.BUTTON_ACTION.SELECT_FILE,
		"button_cursor": SWFUpload.CURSOR.HAND,
		"file_dialog_complete_handler": function(selected, queued, queued_total) {
			swfupload.startUpload();
		},
		"upload_start_handler": function(file) {
			dojo.style(cancel_button, "display", "block");
		},
		"upload_progress_handler": function(file, bytes_complete, bytes_total) {
			var progress_bar_dimensions = dojo.coords(progress_bar);
			var one_percent = progress_bar_dimensions.w / 100;
			var percentage_complete = bytes_complete / bytes_total * 100;
			var background_position = Math.ceil(-1047 + one_percent * percentage_complete);
			dojo.style(progress_bar, "backgroundPosition", background_position + "px 0");
		},
		"upload_error_handler": function(file, code, message) {
			if(code != SWFUpload.UPLOAD_ERROR.FILE_CANCELLED) alert("Error #" + code + ": " + message + ".");
			dojo.style(cancel_button, "display", "none");
			dojo.style(progress_bar, "backgroundPosition", "-1047px 0");
		},
		"upload_success_handler": function(file, data, response) {
			var json_data = dojo.fromJson(data);
			dojo.attr(thumbnail_image, "src", json_data["draft_thumbnail_url"]);
			dojo.attr(draft_id, "value", json_data["draft_id"]);
			dojo.style(cancel_button, "display", "none");
			dojo.style(progress_bar, "backgroundPosition", "-1047px 0");
		}
	});

	dojo.connect(cancel_button, "onclick", null, function(event) {
		event.preventDefault();
		swfupload.cancelUpload();
		dojo.style(cancel_button, "display", "none");
		dojo.style(progress_bar, "backgroundPosition", "-1047px 0");
	});
};

function customLoginSubmitEvent( event ) {
	var container = dojo.byId('login_return_message_container');
	if ( container ) {
		container.innerHTML = '';
		container.style.display = 'none';
	}
	event.preventDefault();
	dojo.xhrPost({
		encoding: 'utf-8',
		url: '/rpc_login/',
		handle: function(data, evt){
			if ( data.success ) {
				window.location = data.location;
			}
			else {
				var container = dojo.byId('login_return_message_container');
				if ( container ) {
					container.style.display = 'block';
					container.innerHTML = data.reason;
				}
				var pass = dojo.byId('login_password');
				if ( pass ) pass.value = '';
			}
		},
	handleAs: "json",
		form: dojo.byId("loginForm")
	});
}

dicole.show_login = function(event) {
	if(event) event.preventDefault();
	dicole.create_showcase({"width": 400, "disable_close": true, "content": dicole.process_template("login", {
		"facebook_connect_app_id": dicole.get_global_variable("facebook_connect_app_id"),
		"url_after_login": dicole.get_global_variable("url_after_login")
	})});

	var login_password = dojo.byId("login_password");
	if(login_password) {
		dojo.connect( login_password, 'onkeypress', function( event ) {
			if(event.keyCode=='13'){
				customLoginSubmitEvent( event );
			}
		} );
	}

	var login_button = dojo.byId('light_login_button');
	if(login_button) {
		dojo.connect(login_button, 'onclick', function( event ) {
        	customLoginSubmitEvent( event );
    	});
    }
};

dojo.subscribe("new_node_created", function(node) {
	dicole.ucq("js_hook_show_login").forEach(function(element) {
        dojo.connect( element, 'onclick', dicole.show_login );
    });
});

dojo.addOnLoad( function() {
	dicole.register_template("login", {templatePath: dojo.moduleUrl("dicole.login", "login.html")});

	if ( typeof(dicole) !== 'undefined' ) {
		if ( dicole.get_global_variable('auto_open_login') ) {
			dicole.show_login();
		}
	}
	var lightb = dojo.byId('navi_login_link');
	if ( lightb ) dojo.connect( lightb, 'onclick', dicole.show_login );
	var partb = dojo.byId('navi_participate_link');
	if ( partb ) dojo.connect( partb, 'onclick', dicole.show_login );
} );


dicole.print_element = function (element) {
    dojo.query( element ).forEach( function( content ) {

        // Create tab or iframe
        if( dojo.isOpera ) {
            var tab = window.open( "", "print-preview" );
            tab.document.open();
            var doc = tab.document;
        }
        else
        {
            var iframe = dojo.create( "iframe", null, dojo.body() );

            dojo.attr( iframe, {
                position: "absolute",
                width: "0px",
                height: "0px",
                left: "-600px",
                top: "-600px"
            });


            var doc = iframe.contentWindow.document;
        }

        // Import css
        if ( dojo.query( "link[media=print]" ).length > 0 )
        {
            dojo.query( "link[media=print]" ).forEach( function( node ) {
                doc.write("<link type='text/css' rel='stylesheet' href='" + dojo.attr( node, "href" ) + "' media='print' />");
            });
        }
        else
        {
            dojo.query( "link" ).forEach( function( node ) {
                doc.write("<link type='text/css' rel='stylesheet' href='" + dojo.attr( node, "href" ) + "' />");
            });
        }

        // Write content & print
        doc.write( content.innerHTML );
        doc.close();
        ( dojo.isOpera ? tab : iframe.contentWindow).focus();
        setTimeout( function() { ( dojo.isOpera ? tab : iframe.contentWindow).print(); if (tab) { tab.close(); } }, 1000);
    });
};

dicole.click_element = function ( element, asynchronously ) {

    var action = function() {
        if (document.createEvent) { // Modern browsers etc.
            try {
                event = document.createEvent("HTMLEvents");
                event.initEvent('click', false, true);
                element.dispatchEvent(event);
                console.log( "element_clicked" );
            }
            catch (ex) { // IE 9
                element.click();
            }
        }
        else if( document.createEventObject ) { // IE 8
            var evObj = document.createEventObject();
            element.fireEvent( 'onclick', evObj );
        }
        else {
            element.fireEvent("click");
        }
    };

    // REASONING: The setTimeout option is here because if you have just attached a click event (with dojo at least)
    // before calling this, then Firefox would not fire the event. We don't know why. a big enough setTimeout solves this.

    if ( ! asynchronously ) {
        action();
    }
    else {
        setTimeout( action, 250 );
    }
};

