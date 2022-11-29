dojo.provide("dicole.meetings_common");
dojo.require('dicole.base');
dojo.require('dicole.base.utils');

dicole.register_template("meetings.facebook_email", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "facebook_email.html")}, true );
dicole.register_template("meetings.facebook_email_return", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "facebook_email_return.html")}, true );
dicole.register_template("meetings.connect_service_account_return", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "connect_service_account_return.html")}, true );

dicole.meetings_common.client_page_load_time = new Date().getTime();
dicole.meetings_common.timezone_timer_override_values = {};
dicole.meetings_common.jquery_loading = false;
dicole.meetings_common.jquery_loaded = false;

dojo.addOnLoad(function() {
    dicole.meetings_common.update_timezone_timers();
    dicole.meetings_common.ensure_user_caches();
    dojo.subscribe('dicole/facebook/loaded', function() {
        FB.getLoginStatus(function(response) {
            if (response.status === 'connected' && dicole.get_global_variable('meetings_refresh_facebook_friends')) {
                dicole.meetings_common.refresh_facebook_friends(response.authResponse);
            }
        });
    });
});

dojo.subscribe("new_node_created", function(n) {
    dicole.uc_prepare_form( 'meetings', 'connect_service_account', {
        success_handler : function(response){
            if ( response && response.result ) {
                dojo.query('#meetings-connect-service').forEach( function( container ) {
                    container.innerHTML = dicole.process_template( "meetings.connect_service_account_return", response );
                } );
            }
        }
    } );
} );

dicole.meetings_common.truncate_text = function( str, maxChars ) {
    if (str.length <= maxChars) {
        return str;
    }

    var xMaxFit = maxChars - 3;
    var xTruncateAt = str.lastIndexOf(' ', xMaxFit);

    // Break last word only if 4 or more characters would be shown from it
    if (xTruncateAt == -1 || xTruncateAt < maxChars - 7 ) {
        xTruncateAt = xMaxFit;
    }
    return str.substr(0, xTruncateAt) + "...";
};

dicole.meetings_common.truncate_filename = function( filename, max_length ) {
    if(filename.length < max_length) {
        return filename;
    }
    var split = filename.lastIndexOf('.');
    if ( split < 0 ) {
        return filename.substring(0,maxlength -3) + '...';
    }

    var extension = filename.substring(split + 1);
    if ( extension.length > 4 ) {
        return filename.substring(0,maxlength -3) + '...';
    }
    var name = filename.substring(0, split);
    return name.substring(0, max_length - extension.length - 3 ) + '...' + extension;
};

dicole.meetings_common.update_timezone_timers = function( my_caller_time ) {
    if ( my_caller_time && my_caller_time != dicole.meetings_common.last_timezone_timer_time ) { return; }

    var current_timer_date = new Date().getTime();
    dicole.meetings_common.last_timezone_timer_time = current_timer_date;

    dojo.query('.js_meetings_time_with_timezone_container').forEach( function ( container ) {
        var offset_ms = dicole.get_global_variable('meetings_user_timezone_offset_value') * 1000;
        var offset_string = dicole.get_global_variable('meetings_user_timezone_offset_string');

        if ( container.id ) {
            var override_values = dicole.meetings_common.timezone_timer_override_values[ container.id ];
            if ( override_values ) {
                offset_ms = override_values.offset_value * 1000;
                offset_string = override_values.offset_string;
            }
        }

        container.innerHTML = moment().utc().add('milliseconds', offset_ms).format(moment.lang() === 'en' ? 'ddd h:mm A' : 'ddd HH:mm') + ' (' + offset_string + ')';
    } );

    dojo.query('.js_meetings_weekday_and_time_container').forEach( function ( container ) {
        var offset_ms = dicole.get_global_variable('meetings_user_timezone_offset_value') * 1000;

        if ( container.id ) {
            var override_values = dicole.meetings_common.timezone_timer_override_values[ container.id ];
            if ( override_values ) {
                offset_ms = override_values.offset_value * 1000;
            }
        }

        container.innerHTML = moment().utc().add('milliseconds', offset_ms).format(moment.lang() === 'en' ? 'ddd h:mm A' : 'ddd HH:mm');
    } );

    setTimeout( function() { dicole.meetings_common.update_timezone_timers( current_timer_date ); }, 1000 );
};

dicole.meetings_common.generate_utc_weekday_and_time = function( now ) {

    var weekdays = dicole.get_global_variable('meetings_weekday_names');

    return  weekdays[now.getUTCDay()] + ' ' + dicole.meetings_common.generate_utc_time_only_string( now, 'ampm' );
};

dicole.meetings_common.generate_utc_time_only_string = function( now, display_type ) {
    if ( display_type && display_type == 'ampm' ) {
        var h = now.getUTCHours();
        var amh = h > 12 ? h - 12 : h < 1 ? 12 : h;
        var suffix = h > 11 ? 'PM' : 'AM';
        var m = now.getUTCMinutes();
        var amm = m > 0 ? ( m < 10 ? ':0' : ':' ) + m : '';
        return amh + amm + ' ' + suffix;
    }
    else {
        return ( now.getUTCHours() < 10 ? '0' : '' ) + now.getUTCHours() + ':' +
            ( now.getUTCMinutes() < 10 ? '0' : '' ) + now.getUTCMinutes();
    }
}

dicole.meetings_common.login_with_facebook = function() {
    dicole.meetings_common._execute_with_facebook_session( function( session ) {
        return dicole.meetings_common._login_with_facebook( session );
    } );
};

dicole.meetings_common.fill_profile_with_facebook = function( w, h ) {
    dicole.meetings_common._execute_with_facebook_session( function( session ) {
        return dicole.meetings_common._fill_profile_with_facebook( session, w, h );
    } );
};

dicole.meetings_common.connect_profile_with_facebook = function( handler ) {
    dicole.meetings_common._execute_with_facebook_session( function( session ) {
        dojo.query('.js_fb_fillable_facebook_user_id').forEach( function ( node ) {
            node.value = session.userID;
        } );
        if ( handler ) {
            handler( session );
        }
    } );
};

dicole.meetings_common.disconnect_profile_from_facebook = function( handler ) {
    dojo.query('.js_fb_fillable_facebook_user_id').forEach( function ( node ) {
        node.value = 0;
    } );
    if ( handler ) {
        handler( session );
    }
};

dicole.meetings_common._execute_with_facebook_session = function( handler ) {
    FB.getLoginStatus( function( response ) {
        if( response.status === 'connected' ) {
            handler( response.authResponse );
        }
        else {
            FB.login( function( response2 ) {
                if ( response2.authResponse ) {
                    handler( response2.authResponse );
                }
                else {
                    alert("Failed to authorize with Facebook! Please try again.");
                }
            }, {"scope": "email"} );
        }
    } );
};

dicole.meetings_common._login_with_facebook = function( session ) {
	dojo.xhrPost({
		"url": dicole.get_global_variable("who_am_i_url"),
        "content": { login_fb : 1 },
		"handleAs": "json",
		"handle": function(response) {
			if(response.result == 0) dicole.meetings_common._query_email_for_facebook_connection( session );
			else window.location = dicole.get_global_variable("url_after_login");
		}
	});
};

dicole.meetings_common.refresh_facebook_friends = function(session) {
    FB.api("/me/friends?access_token=" + session.accessToken, function(response) {
        if (response.data) {
            dicole.meetings_common._refresh_facebook_friends(response.data);
        }
    });
};

dicole.meetings_common.ensure_user_caches = function() {
    if ( dicole.get_global_variable('meetings_ensure_user_caches_url') ) {
        dojo.xhrPost({
            url: dicole.get_global_variable('meetings_ensure_user_caches_url'),
            content: {},
            handleAs: "json",
            handle: function(response) {}
        });
    }
};

dicole.meetings_common._refresh_facebook_friends = function(friends) {
    dojo.xhrPost({
        url: dicole.get_global_variable('meetings_refresh_facebook_friends_url'),
        content: { friends: dojo.toJson(friends) },
        handleAs: "json",
        handle: function(response) {}
    });
};

dicole.meetings_common._fill_profile_with_facebook = function( session, width, height ) {
    width = width ? width : 200;
    height = height ? height : 200;

    FB.api("/me", function(response) {
        dojo.forEach( [ 'first_name', 'last_name', 'email' ], function( info ) {
            if ( response[ info ] ) {
                dojo.query('.js_fb_fillable_' + info).forEach( function ( node ) {
                    node.value = response[ info ];
                } );
            }
        } );
	});

	var draft_id_nodes = dojo.query('.js_fb_fillable_photo_draft_id');
    var photo_image_nodes = dojo.query('.js_fb_fillable_photo_image');

    var post_url = dicole.get_global_variable("draft_attachment_url_store_url");

    if ( post_url && draft_id_nodes.length > 0 ) {
    	dojo.xhrPost({
    		"url": post_url,
    		"content": {
	    		"width": width,
    			"height": height,
                "filename" : "picture.jpg",
    			"url": "https://graph.facebook.com/me/picture?type=large&access_token=" + session.accessToken
            },
    		"handleAs": "json",
	    	"handle": function(response) {
                dojo.forEach( draft_id_nodes, function( node ) {
                    node.value = response.draft_id;
                } );
                dojo.forEach( photo_image_nodes, function( node ) {
                    node.src = response.draft_thumbnail_url;
                    dojo.style( node, 'display', 'inline' );
                } );
            }
        });
    }
};

dicole.meetings_common._query_email_for_facebook_connection = function( session ) {
    dicole.create_showcase({
        "width": 400,
        "disable_close": true,
        "content": dicole.process_template( "meetings.facebook_email", {
            facebook_user_id : session.userID,
            url_after_action : dicole.get_global_variable('url_after_login')
         } )
    });
    dicole.mocc( 'js_meetings_facebook_email_submit', dojo.body(), function( node, evt ) {
        dojo.xhrPost( {
            url : dicole.get_global_variable( 'meetings_facebook_email_url'),
            form : 'meetings_facebook_email_form',
            handleAs : 'json',
            handle: function( response ) {
                if ( response && response.result ) {
                    dojo.query('#meetings_facebook_email_return').forEach( function( container ) {
                        container.innerHTML = dicole.process_template( "meetings.facebook_email_return", response );
                    } );
                }
            }
		} );
    } );
};

dicole.mocc = function( cls, created_node, handler ) {
    var params = {};
    if ( created_node ) { params.container = created_node; }
    return dicole.uc_click( cls, handler, params );
};

dicole.mocc_enter = function( cls, created_node, handler ) {
    var params = {};
    if ( created_node ) { params.container = created_node; }
    return dicole.uc_enter( cls, handler, params );
};

dicole.mocc_open = function( id, created_node, width, post_handler ) {
    var params = {};
    if ( created_node ) { params.container = created_node; }
    if ( width ) { params.width = width; }
    if ( post_handler ) { params.post_handler = post_handler; }
    return dicole.uc_click_open( 'meetings', id, params );
};

dicole.mocc_node_open = function( id, created_node, width, post_handler ) {
    var params = {};
    if ( created_node ) { params.container = created_node; }
    if ( width ) { params.width = width; }
    if ( post_handler ) { params.post_handler = post_handler; }
    return dicole.uc_click_fetch_open( 'meetings', id, params );
};

dicole.mocc_form = function( id, created_node, post_error_handler ) {
    var params = {};
    if ( created_node ) { params.container = created_node; }
    if ( post_error_handler ) { params.post_error_handler = post_error_handler; }
    return dicole.uc_prepare_form( 'meetings', id, params );
};

dicole.mocc_open_form = function( id, created_node, width, post_handler, error_handler ) {
    dicole.mocc_open( id, created_node, width, post_handler );
    dicole.mocc_form( id, created_node, error_handler );
};

dicole.mocc_node_open_form = function( id, created_node, width, post_handler, error_handler ) {
    dicole.mocc_node_open( id, created_node, width, post_handler );
    dicole.mocc_form( id, created_node, error_handler );
};

dicole.meetings_common.last_page_content_data = {};

dicole.meetings_common.store_page_content_response = function( id, response, launch_time ) {
    if ( id ) {
        dicole.meetings_common.last_page_content_data[ id ] = {
            result : response.result,
            result_hash : response.result_hash,
            launch_time : launch_time
        };
    }
};

dicole.meetings_common.refresh_page_content = function( args ) {
    if ( ! args.url ) { return; }

    args.name = args.name ? args.name : args.url;

    var secret = '';
    if ( args.type == 'user' ) {
        secret = dicole.get_global_variable('meetings_cache_secret_user');
    }
    else if ( args.type == 'meeting' ) {
        secret = dicole.get_global_variable('meetings_cache_secret_meeting');
    }
    else if ( args.type == 'manager' ) {
        secret = dicole.get_global_variable('meetings_cache_secret_manager');
    }

    args.id = secret ? dojo.toJson( [ secret, args.name, args.content ] ) : '';
    args.content = args.content ? args.content : {};

    if ( dicole.meetings_common.last_page_content_data[ args.id ] ) {
        var last_data = dicole.meetings_common.last_page_content_data[ args.id ];
        args.render_handler( last_data.result );
    }

    if ( dicole.get_global_variable('cache_server') && args.id  ) {
        var launch_time = new DateTime().getTime();
        dojo.xhrPost( {
            'url' : dicole.get_global_variable('cache_server'),
            'content' : { key : args.id },
            'handleAs' : 'json',
            'load' : function( response ) {
                if ( response && response.result ) {
                    var last_data = dicole.meetings_common.last_page_content_data[ args.id ];
                    if ( ! last_data || ! last_data.result_hash || last_data.result_hash != response.result_hash ) {
                        if ( ! last_data || launch_time > last_data.launch_time ) {
                            args.render_handler( response.result );
                            dicole.meetings_common.store_page_content_response( args.id, response, launch_time );
                        }
                    }
                }
            }
        } );
    }

    dicole.meetings_common.refresh_page_content_from_server( args );
};

dicole.meetings_common.refresh_page_content_from_server = function( args ) {
    var launch_time = new DateTime().getTime();
    dojo.xhrPost( {
        'url' : args.url,
        'content' : args.id ? dojo.mixin( args.content, { cache_id : args.id } ) : args.content,
        'handleAs' : 'json',
        'load' : function( response ) {
            if ( response && response.result ) {
                var last_data = args.id ? dicole.meetings_common.last_page_content_data[ args.id ] : '';
                if ( ! last_data || ! last_data.result_hash || last_data.result_hash != response.result_hash ) {
                    if ( ! last_data || launch_time > last_data.launch_time ) {
                        args.render_handler( response.result );
                        dicole.meetings_common.store_page_content_response( args.id, response, launch_time );
                    }
                }
            }
            else {
                dicole.meetings_common.retry_page_content_from_server( args );
            }
        },
        'error' : function( response ) {
            dicole.meetings_common.retry_page_content_from_server( args );
        }
    } );
}

dicole.meetings_common.retry_page_content_from_server = function( args ) {
    if ( ! args.retry ) {
        args.retry = 1;
        dicole.meetings_common.refresh_page_content_from_server( args );
    }
    else {
        // moo :(
    }
}

dicole.meetings_common.publish_event = function( name, params ) {
    dicole.set_global_variable( 'meetings_event_' + name + '_published', 1 );
    dicole.set_global_variable( 'meetings_event_' + name + '_params', params );
    dojo.publish( 'meetings_' . name, params );
}

dicole.meetings_common.fire_once_after_event = function( name, handler ) {
    if ( dicole.get_global_variable( 'meetings_event_' + name + '_published' ) ) {
        var params = dicole.set_global_variable( 'meetings_event_' + name + '_params', params );
        handler( params );
    }
    else {
        var sub;
        sub = dojo.subscribe( name, function( params ) {
            dojo.unsubscribe( sub );
            handler( params );
        } );
    }
};

