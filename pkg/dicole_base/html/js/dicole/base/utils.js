dojo.provide("dicole.base.utils");

dojo.config['dojoBlankHtmlUrl'] = '/js/dojo/blank.html';

dojo.addOnLoad( function() { dicole_process_draft_shippers(); } );

dojo.subscribe( 'new_node_created', function( container ) {
    dicole_process_autofills(container);
} );

dicole.uc_click = function( cls, handler, params ) {
    var p = dojo.mixin( {
        container : dojo.body()
    }, params );

    dicole.ucq( cls, p.container ).forEach( function(node) {
        dojo.connect( node, 'onclick', function( evt ) {
            evt.preventDefault();
            if ( !dojo.hasClass( node , 'clicked' ) && handler ) {
                dojo.addClass( node, 'clicked' );
                setTimeout( function(){ dojo.removeClass( node, 'clicked' ); } , 1000 );
                dicole.uc_track( node );
                handler( node, evt );
            }
        } );

        dojo.publish('uc_' + cls + '_processed', [ node, params ] );
    } );
};

dicole.uc_enter = function( cls, handler, params ) {
    var p = dojo.mixin( {
        container : dojo.body()
    }, params );

    dicole.ucq( cls, p.container ).forEach( function(node) {
        dojo.connect( node, 'onkeypress', function( evt ) {
            if ( evt.keyCode == dojo.keys.ENTER ) {
                evt.preventDefault();
                if ( handler ) {
                    dicole.uc_track( node, 'enter' );
                    handler( node, evt );
                }
            }
        } );
        dojo.publish('uc_' + cls + '_processed', [ node, params ] );
    } );
};

dicole.uc_track = function( node, type ) {
    if( meetings_tracker ){
        meetings_tracker.track( node, type );
    }
};

dicole.uc_click_open = function( pkg, prefix, params ) {
    var p = dojo.mixin( {
        container : dojo.body(),
        width: 400,
        post_open_handler : function() {},
        template : pkg + "." + prefix,
        template_params : {}
    }, params );

    dicole.uc_click( 'js_'+ pkg +'_'+ prefix +'_open', function( node, evt ) {
        dicole.uc_common_open( pkg, prefix, dojo.mixin( { node : node }, p ) );
    }, { container : p.container } );
};

dicole.uc_click_fetch_open = function( pkg, prefix, params ) {
    var p = dojo.mixin( {
        container : dojo.body(),
        width: 400,
        template : pkg +"."+ prefix
    }, params );

    dicole.uc_click( 'js_'+ pkg +'_'+ prefix +'_open', function( node ) {
        dicole.uc_common_fetch_open( pkg, prefix, node, params );
	}, { container : p.container } );
};

dicole.uc_common_fetch_open = function( pkg, prefix, node, params ) {
    var p = dojo.mixin( {
        container : dojo.body(),
        width: 400,
        pre_fetch_hook : function() {},
        post_handler : false, // deprecated
        post_fetch_pre_handle_hook : function() {},
        post_fetch_handler : function() {},
        data_url : dicole.get_global_variable( pkg + '_' + prefix + '_data_url'),
        template : pkg +"."+ prefix
    }, params );

    // backwards compatibility
    if ( p.post_handler ) {
        var handler = p.post_handler;
        p.post_fetch_handler = function( result, pkg, prefix, node ) {
            handler( result, prefix, node );
        }
        p.post_handler = false;
    }

    p.pre_fetch_hook( pkg, prefix, node, params );

    var url = p.data_url || dojo.attr( node, 'data-fetch-url' ) || dojo.attr( node, 'data-post-url' ) || dojo.attr( node, 'href' );

    p.gather_template_params = function( handler ) {
        dojo.xhrPost( {
            url : url,
            handleAs : 'json',
            load : function( response ) {
                if ( response && response.result ) {
                    p.post_fetch_pre_handle_hook( response.result, pkg, prefix, node );
                    handler( response.result );
                    p.post_fetch_handler( response.result, pkg, prefix, node );
                }
            }
        } );
    }

    dicole.uc_common_open( pkg, prefix, dojo.mixin( { node : node }, p ) );
};

dicole.uc_common_open = function( pkg, prefix, params ) {
    var p = dojo.mixin( {
        width: 400,
        disable_background_close : false,
        show_duration : 500,
        pre_open_hook : function() {},
        post_open_hook : function() {},
        pre_close_hook : function() {},
        post_handler : false, // deprecated
        template : pkg +"."+ prefix,
        template_params : {},
        override_template_params : {},
        gather_template_params : function( handler, _pkg, _prefix, _p ) {
            return handler( _p.template_params );
        },
        gather_override_template_params : function( handler, _pkg, _prefix, _p ) {
            return handler( _p.override_template_params );
        }
    }, params );

    // backwards compatibility
    if ( p.post_handler ) {
        p.post_open_hook = p.post_handler;
        p.post_handler = false;
    }

    p.pre_open_hook( pkg, prefix, p );

    dicole.create_showcase({
        "show_duration": p.show_duration,
        "width": p.width,
        "disable_close": true,
        "pre_close_hook" : p.pre_close_hook,
        "disable_background_close" : p.disable_background_close,
        "vertical_align" : p.vertical_align,
        "post_content_hook" : dojo.hitch( this, function( _pkg, _prefix, _p ) { _p.post_open_hook( _pkg, _prefix, _p ); }, pkg, prefix, p ),
        "gather_content" : dojo.hitch( this, function( pkg, prefix, p, handler ) {
            return p.gather_template_params( function ( template_params ) {
                return p.gather_override_template_params( function( override_template_params ) {
                    var params = dojo.mixin( template_params, override_template_params );
                    var html = dicole.process_template( p.template, params );
                    return handler( params.override_width ? { width : params.override_width, html : html } : html );
                }, pkg, prefix, p );
            }, pkg, prefix, p );
        }, pkg, prefix, p )
    });
};

// subscriptions are stored here because the form can be deleted and recreated on the page
// multiple times. storing the subscriptions allows us to clear the old subscriptions when
// the form is recreated. otherwise submits for the recreated forms would also submit the
// already deleted form.
dicole.uc_form_subscriptions = {};
dicole.uc_prepare_form = function( pkg, prefix, params ) {
    var p = dojo.mixin( {
        container : dojo.body(),
        submit_handler : false,
        post_error_handler : function() {},
        success_handler : false,
        url : dicole.get_global_variable( pkg + '_' + prefix + '_url')
    }, params );

    var id = prefix;
    var created_node = p.container;
    var post_error_handler = p.post_error_handler;

    var form_element = dojo.byId( pkg + '_' + id + '_form' );
    if ( ! form_element || dojo.hasClass( form_element, 'js_'+ pkg +'_form_subscribed' ) ) {
        return;
    }

    if ( ! dojo.attr( form_element, 'accept-charset' ) ) {
        dojo.attr( form_element, 'accept-charset', 'UTF-8' );
    }

    dojo.addClass( form_element, 'js_'+ pkg +'_form_subscribed' );

    dicole.uc_click( 'js_'+ pkg +'_' + id + '_submit', function( node, evt ) {
        if ( dojo.query('.js_'+ pkg +'_' + id + '_submit>span.gray-inactive' ).length ) {
            return;
        }
        dojo.publish( pkg + '_' + id + '_submit' );
    }, { container : p.container } );

    dicole.uc_enter( 'js_'+ pkg +'_' + id + '_enter_submit', function( node, evt ) {
        if ( dojo.query('.js_'+ pkg +'_' + id + '_submit>span.gray-inactive' ).length ) {
            return;
        }
        dojo.publish( 'enter_intercepted', [ node ] );
        dojo.publish( pkg + '_' + id + '_submit' );
    }, { container : p.container } );

    if ( dicole.uc_form_subscriptions[ pkg + '_' + id ] ) {
        dojo.unsubscribe( dicole.uc_form_subscriptions[ pkg + '_' + id ] );
    }

    dicole.uc_form_subscriptions[ pkg + '_' + id ] = dojo.subscribe( pkg + '_' + id + '_submit', function() {
        if ( p.pre_post_interceptor ) {
            if ( ! p.pre_post_interceptor() ) {
                return;
            }
        }

        dojo.query('.js_'+ pkg +'_' + id + '_error_container', created_node ).forEach( function( container ) {
            dojo.addClass( container, 'error_container_hidden' );
        } );

        var cleared_tip_fields = [];
        dojo.query('.js_tip_field', form_element).forEach( function( clearable_node ) {
            if ( clearable_node.defaultValue == clearable_node.value ) {
                clearable_node.value = '';
                cleared_tip_fields.push( clearable_node );
            }
        } );

        var indicator_queries = [
            '.js_' + pkg + '_' + id + '_submit>span.indicator',
            '.js_' + pkg + '_' + id + '_indicator'
        ];

        dojo.query( indicator_queries.join(", ") ).forEach( function( indicator ) {
            dojo.removeClass( indicator, 'success' );
            dojo.addClass( indicator, 'working' );
        } );

        dojo.query( '.js_' + pkg + '_' + id + '_submit>span.label' ).forEach( function( el ) {
            dojo.addClass(el.parentNode, 'active');
        });

        dojo.query( '.js_' + pkg + '_' + id + '_submit>span.pink' ).forEach( function( button ) {
            dojo.removeClass( button, 'pink' );
            dojo.addClass( button, 'gray-inactive' );
        } );

        var handle_response = function( response ) {
            if ( response && response.result ) {
                if ( p.success_handler ) {
                    p.success_handler( response );
                }
                else if ( response.result.url_after_post ) {
                    window.location = response.result.url_after_post;
                }
                else if ( dicole.get_global_variable( pkg + '_' + id + '_url_after_post') ) {
                    window.location = dicole.get_global_variable( pkg + '_' + id + '_url_after_post');
                }
                else {
                    location.reload(true);
                }
            }
            else {
                dojo.query( '.js_'+ pkg +'_' + id + '_submit>span.gray-inactive').forEach( function( button ) {
                    dojo.removeClass( button, 'gray-inactive');
                    dojo.addClass( button, 'pink');
                });

                dojo.query( indicator_queries.join(", ") ).forEach( function( indicator ) {
                    dojo.removeClass( indicator, 'working' );
                } );

                var message = response.error.message;

                if ( ! message ) {
                    message = 'The service could not be contacted properly. Please try again!';
                }

                var container_found = false;
                dojo.query('.js_'+ pkg +'_' + id + '_error_container', created_node ).forEach( function( container ) {
                    container.innerHTML = dicole.encode_html( message );
                    dojo.removeClass( container, 'error_container_hidden' );
                    container_found = true;
                } );

                if ( ! container_found && ! post_error_handler ) {
                    alert( message );
                }

                if ( post_error_handler ) {
                    post_error_handler( response );
                }
            }
        };

        if ( p.submit_handler ) {
            p.submit_handler( dojo.fromJson( dojo.formToJson( form_element ) ), handle_response );
        }
        else {
            if ( ! p.url ) {
                alert( pkg + '_' + prefix + '_url not specified!');
            }
            dojo.xhrPost( {
                url : p.url,
                form : form_element,
                handleAs : 'json',
                handle: handle_response
    		} );
        }

        dojo.forEach( cleared_tip_fields, function( clearable_node ) {
            clearable_node.value = clearable_node.defaultValue;
        } );
    } );
};

dicole.uc_common_open_and_prepare_form = function( pkg, prefix, params ) {
    dicole._uc_common_append_prepare_form_to_post_open_hook( params );
    dicole.uc_common_open( pkg, prefix, params );
}

dicole.uc_click_open_and_prepare_form = function( pkg, prefix, params ) {
    dicole._uc_common_append_prepare_form_to_post_open_hook( params );
    dicole.uc_click_open( pkg, prefix, params );
};

dicole.uc_click_fetch_open_and_prepare_form = function( pkg, prefix, params ) {
    dicole._uc_common_append_prepare_form_to_post_open_hook( params );
    dicole.uc_click_fetch_open( pkg, prefix, params );
};

dicole.uc_common_fetch_open_and_prepare_form = function( pkg, prefix, params ) {
    dicole._uc_common_append_prepare_form_to_post_open_hook( params );
    dicole.uc_common_fetch_open( pkg, prefix, null, params );
};

dicole._uc_common_append_prepare_form_to_post_open_hook = function( params ) {
    params.old_post_open_hook = params.post_open_hook;
    params.post_open_hook = function( pkg, prefix, params ) {
        // container needs to be body as the showcase was not created inside the
        // same container which that the button is in
        dicole.uc_prepare_form( pkg, prefix, dojo.mixin( params, { container : dojo.body() } ) );

        if ( params.old_post_open_hook ) { params.old_post_open_hook( pkg, prefix, params ); }
    };
}

/*
// Default behaviour with only base_class parameter
// * lookups up all buttons with class my_button_class
// * upon click, sends post request to the url in buttons href-attribute
// * replaces the contents of {effective_id}_container (all of them) with the
//   contents of the 'html' -key in the response json structure
// * there can be multiple effective ids with the same button. one is always the base_class one is
//   the object id (if exists) and one is resolved from class base_class + '_id_????' (if exists)
//
// NOTE: target containers are all prefixed with effective_id: container -> {effective_id} + '_container'
// NOTE: target containers are matched from both class and id values
// NOTE: this functin makes sure the actions are not attached twice so it can be run multiple times
//
// * can specify functions to run upon error and after succesful replace
// * can speficy multiple json keys and containers (prefixed by id or not) to fill from result
// * can specify elements (prexifed by id or not) to be shown or hidden by setting their display-style after replaces
//
dicole_xhrplace( {
    base_class : 'my_button_class',
    // Optional parameters:
    custom_id_container_key : 'new_html',

    // Define containers and elements to alter
    container_key_map : { my_button_container : 'button_html', my_warning_container : 'warning_html' },
    element_display_map : { my_result_container : 'block', my_initial_hints_container : 'none' },

    // These are like the previous ones but containers are prefixed with effective_id
    id_container_key_map : { button_container : 'button_html', warning_container : 'warning_html' },
    id_element_display_map : { result_container : 'block', initial_hints_container : 'none' },

    post_content_procedure : function( node ) { return {}; },
    after_procedure : function( data, node ) {},
    error_procedure : function( error ) {}
} );
*/

var dicole_xhrplace = dicole.xhrplace = function( params ) {
    var base_class = params['base_class'];

    var post_content_procedure = params['post_content_procedure'] || function() { return {}; };
    var after_procedure = params['after_procedure'] || function() {};
    var error_procedure = params['error_procedure'] || function() {
        alert('Error contacting server. Please try again.');
    };

    var element_display_map = params['element_display_map'] || {};
    var container_key_map = params['container_key_map'] || {};

    var id_element_display_map = params['id_element_display_map'] || {};
    var id_container_key_map = params['id_container_key_map'] || {};

    var custom_id_container_key = params['custom_id_container_key'] || 'html';
    id_container_key_map[ 'container' ] = id_container_key_map[ 'container' ] || custom_id_container_key;

    var id_regex = new RegExp( '(^| )(' + base_class + '_id_[^ ]+)( |$)' );

    dojo.query('.' + base_class ).forEach( function( node ) {
        var processed_class = base_class + '_onclick_processed';
        if ( dojo.hasClass( node, processed_class ) ) return;
        dojo.addClass( node, processed_class );
        dojo.connect( node, 'onclick', function( evt ) {
            evt.preventDefault();

            var node_href = dojo.attr( node, 'href') + '';
            if ( ! node_href || node_href.match(/^\#/) ) return;

            var effective_ids = [ base_class ];

            // override effective id if node has id
            var node_id = dojo.attr( node, 'id' ) + '';
            if ( node_id ) effective_ids.push( node_id );

            // override effective id if classes include base_class + '_id_xxx'
            var cls = dojo.attr( node, 'class' ) + '';
            var matches = cls.match( id_regex );
            if ( matches && matches[2] ) {
                effective_ids.push( matches[2] + '' );
            }

            dojo.xhrPost({
                url: node_href,
                handleAs: "json",
                content : post_content_procedure( node ),
                load: function(data, ioArgs) {
                    for ( var key in container_key_map ) {
                        dicole_class_id_query( key ).forEach( function( container ) {
                            container.innerHTML = container_key_map[ key ] ? data[ container_key_map[ key ] ] : '';
                        } );
                    };
                    for ( var key in id_container_key_map ) {
                        dojo.forEach( effective_ids, function( effective_id ) {
                            dicole_class_id_query( effective_id + '_' + key ).forEach( function( container ) {
                                container.innerHTML = id_container_key_map[ key ] ? data[ id_container_key_map[ key ] ] : '';
                            } );
                        } );
                    };
                    for ( var key in element_display_map ) {
                        dicole_class_id_query( key ).forEach( function( container ) {
                            if ( element_display_map[ key ] ) container.style.display = element_display_map[ key ] || '';
                        } );
                    };
                    for ( var key in id_element_display_map ) {
                        dojo.forEach( effective_ids, function( effective_id ) {
                            dicole_class_id_query( effective_id + '_' + key ).forEach( function( container ) {
                                if ( id_element_display_map[ key ] ) container.style.display = id_element_display_map[ key ] || '';
                            } );
                        } );
                    };
                    after_procedure( data, node );
                },
                error: error_procedure
            } );
        } );
    } );
}

function dicole_class_id_query( match_strings ) {
    var strings = match_strings.split(/\s+\|\s+/);
    var nodelist = new dojo.NodeList();
    dojo.forEach( strings, function ( match_string ) {
        nodelist = nodelist.concat( dojo.query( '.' + match_string ) );
        nodelist = nodelist.concat( dojo.query( '#' + match_string ) );
    } );
    return nodelist;
}

/*

If you want your drafts from form, element or tinymce editor with id myId sent to myUrl
periodically, you need to include this tag in your html:

<a class="f_dicole_draft_shipper_link" id="f_myId_draft_shipper_link" href="myUrl"></a>

You can also include an initial draft_id or content in the element title as a json object:

<a class="f_dicole_draft_shipper_link" id="f_myId_draft_shipper_link" href="myUrl" title="{ draft_id : 231, content : &quot;initial content&quot;}"></a>

If you are submitting a form, you may specify special classes (or ids) for objects for which
obj.value will be filled with the appropriate values:

f_myId_draft_shipper_draft_id
f_myId_draft_shipper_time

If you are sure only one shipper exists on the page, you can also use just:

f_draft_shipper_draft_id
f_draft_shipper_time

If your target element is not a form, the content of the post will be:

{ content : content, time : time, draft_id : shipper_log.draft_id }

If you want to add force submit buttons, add the following class to the button:

f_myId_dicole_draft_shipper_force_submit

Your action should return json string (draft_id is optional):

{ success : 1, draft_id : 12313 }

TODO: there might be a need for pushable hooks. dicole_draft_shipper_hooks = { editor_id : { on_error : function () {} } };

*/

var dicole_draft_shipper_logs = {};

function dicole_process_draft_shippers() {
    dojo.query( '.f_dicole_draft_shipper_link' ).forEach( function ( shipper ) {
        var id = dojo.attr( shipper, 'id' ) || '';
        var editor_id = id.replace( /_draft_shipper_link$/, '' );
        editor_id = editor_id.replace( /^f_/, '' );
        if ( editor_id != id && dojo.byId( editor_id ) && shipper.href ) {

            dojo.query( '.f_'+ editor_id +'_dicole_draft_shipper_force_submit' ).forEach( function ( node ) {
                dojo.connect( node, 'onclick', function ( evt ) {
                    evt.preventDefault();
                    dicole_draft_shipper_submit( editor_id, shipper.href )
                } );
            } );

            dicole_draft_shipper_loop( editor_id, shipper.href, shipper.title );
        }
    } );
}

function dicole_draft_shipper_loop( editor_id, url, initial_data ) {
    var date = new Date();
    var time = date.getTime();

    if ( ! dicole_draft_shipper_logs[ editor_id ] ) {
        var data = {
            last_send_time : 0, last_success_time : 0,
            last_success_content : '', draft_id : 0,
            form_fields : []
        };
        if ( initial_data ) {
            try {
                var idata = dojo.fromJson( initial_data );
                data.draft_id = idata.draft_id || 0;
                data.last_success_content = idata.content || '';
                data.form_fields = idata.form_fields || [];
            }
            catch (e) {}
        }

        dicole_draft_shipper_logs[ editor_id ] = data;
    }

    if ( time > dicole_draft_shipper_logs[ editor_id ].last_send_time + 15000 ) {
        dicole_draft_shipper_submit( editor_id, url );
    }

    setTimeout( dojo.hitch( this, function( eid, u ) { dicole_draft_shipper_loop( eid, u ) }, editor_id, url ), 1000 );
}

function dicole_draft_shipper_submit( editor_id, url ) {
    var date = new Date();
    var time = date.getTime();

    var shipper_log = dicole_draft_shipper_logs[ editor_id ];

    var content_found = 0;
    var form_found = 0;
    var content = '';

    var editor = dojo.byId( editor_id );

    if ( tinyMCE ) tinyMCE.triggerSave();

    if ( editor ) {
        if ( editor.tagName.toLowerCase() == 'form' ) {
            form_found = 1;
            var content_values = [];
            dojo.forEach( editor.elements, function ( input_element ) {
                content_values.push( input_element.value );
            } );
            content = 'values: ' + content_values.join(';;;;');
        }
        else {
            content_found = 1;
            content = editor.value;
        }
    }

    // Do we want to stop this for good if editor lookup fails even for once?
    // if ( ! content_found ) {
    //     return;
    // }

    if ( url && ( content_found || form_found ) && content != shipper_log.last_success_content ) {
        var attr = {
            url : url,
            handleAs : 'json',
            timeout : 10000,
            load : function ( data ) {
                if ( data && data.success ) {
                    if ( data.draft_id ) shipper_log.draft_id = data.draft_id;
                    if ( time > shipper_log.last_success_time ) {
                        shipper_log.last_success_time = time;
                        shipper_log.last_success_content = content;
                    }
                }
            },
            error : function ( error ) {}
        };

        if ( form_found ) {
            var draft_id_matcher = 'f_' + editor_id + '_draft_shipper_draft_id | f_draft_shipper_draft_id'
            var time_matcher = 'f_' + editor_id + '_draft_shipper_time | f_draft_shipper_time'

            dicole_class_id_query( draft_id_matcher ).forEach( function ( node ) {
                node.value = shipper_log.draft_id;
            } );
            dicole_class_id_query( time_matcher ).forEach( function ( node ) {
                node.value = shipper_log.time;
            } );

            attr.form = editor_id;
        }
        else {
            attr.content = { content : content, time : time, draft_id : shipper_log.draft_id };
        }

        dojo.xhrPost( attr );
    }

    // Schedule next try after big timeout (15 s) even if content had not changed
    shipper_log.last_send_time = time;
}

var dicole_autofiller_data = {};

function dicole_process_autofills( container ) {
    var input_nodes = container ? dicole.ucq( 'f_dicole_autofill', container ) : dicole.ucq( 'f_dicole_autofill' );
    input_nodes.forEach( function ( input_node ) {
        var input_id = input_node.id;
        if ( 1 ) {
            var send_url_holder = dicole_class_id_query( input_id + '_autofill_url' )[0];
            if ( ! send_url_holder || ! send_url_holder.href ) return;

            dojo.connect( input_node, 'onblur', function ( evt ) {
                setTimeout( function() {
                    var dat = dicole_autofiller_data[ input_id ];
                    if ( dat.select_container ) dojo.destroy( dat.select_container );
                }, 200 );
            } );

            dojo.connect( input_node, 'onkeypress', function ( evt ) {
                if ( evt.keyCode==dojo.keys.ENTER ) {
                    evt.preventDefault();
                    dojo.forEach( dicole_autofiller_data[ input_id ].events.on_go, function( f ) {
                        f( input_id, input_node.value );
                    } );
                }
            } );

            dojo.query( '.js_' + input_id  + '_go' ).forEach( function( button ) {
                dojo.connect( button, 'onclick', function( evt ) {
                    evt.preventDefault();
                    dojo.forEach( dicole_autofiller_data[ input_id ].events.on_go, function( f ) {
                        f( input_id, input_node.value );
                    } );
                } );
            } );


            var events_value = {
                on_select : [],
                on_go : []
            };

            if ( dicole_autofiller_data[ input_id ] && dicole_autofiller_data[ input_id ].events ) {
                events_value = dojo.mixin( events_value, dicole_autofiller_data[ input_id ].events );
            }

            dicole_autofiller_data[ input_id ] = {
                node : input_node,
                url : send_url_holder.href,
                previous_value : input_node.value,
                running : 1,
                previous_value_count : 999,
                events : events_value
            };

            dicole_autofiller_loop( input_id );
        }
    } );
}

function dicole_autofiller_loop( input_id ) {
    var dat = dicole_autofiller_data[ input_id ];
    if ( ! dat.running ) return;

    var new_value = dat.node.value;

    if ( new_value == dat.previous_value ) {
        if ( dat.previous_value_count < 999 )  dat.previous_value_count++;
    }
    else {
        dat.previous_value = new_value;
        dat.previous_value_count = 1;
    }

    if ( dat.previous_value_count == 5 ) {
        dicole_autofiller_update( input_id, new_value );
    }

    setTimeout( function() { dicole_autofiller_loop( input_id ); }, 100 );
}

function dicole_autofiller_update( input_id, new_value ) {
    var dat = dicole_autofiller_data[ input_id ];
    new_value = new_value ? new_value + '' : dat.node.value + '';

    dat.previous_value = new_value;
    dat.previous_value_count = 999;

    var defer = dat.previous_post;
    if ( defer ) defer.cancel();

    if ( new_value.length < 2 ) return;

    dat.previous_post = dojo.xhrPost( {
        url : dat.url,
        handleAs : 'json',
        content : { seed : new_value },
        load : function ( data ) {
            if ( dat.select_container ) dojo.destroy( dat.select_container );
            if ( ! data.results ) return;
            dat.select_container = dojo.create( 'div', {
                'id' : input_id + '_select',
                'style' : {
                    'margin' : '25px 0px 0px 0px',
                    'position' : 'absolute',
                    'background' : 'white',
                    'zIndex' : 4
                }
            }, dat.node, 'before' );

            dojo.forEach( data.results, function( r ) {
                var aelem = dojo.create( 'a', {
                    style : {
                        display: 'block',
                        margin : '3px'
                    },
                    onclick : function ( evt ) {
                        evt.preventDefault();
                        dat.node.value = r.value;
                        dicole_autofiller_reset_previous_value( input_id );
                        if ( dat.select_container ) dojo.destroy( dat.select_container );
                        dojo.forEach( dat.events.on_select, function ( f ) {
                            f( input_id, r, new_value );
                        } );
                    }
                }, dat.select_container );

                dojo.place( document.createTextNode( r.name ), aelem );
            } );
            dicole_process_autofiller_select( input_id );
        }
    } );
}

function dicole_process_autofiller_select( input_id ) {
    return 1;
}

function dicole_autofiller_reset_previous_value( input_id ) {
    var dat = dicole_autofiller_data[ input_id ];
    dat.previous_value = dat.node.value;
    dat.previous_value_count = 999;
}

function dicole_autofiller_stop( input_id ) {
    var dat = dicole_autofiller_data[ input_id ];
    dat.running = 0;
}

function dicole_autofiller_add_event( input_id, event, func ) {
    var dat = dicole_autofiller_data[ input_id ];
    if ( ! dat ) dat = dicole_autofiller_data[ input_id ] = {};
    if ( ! dat.events ) dat.events = {};
    if ( ! dat.events[ event ] ) dat.events[ event ] = [];
    dat.events[ event ].push( func );
}

