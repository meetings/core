dojo.require('dicole');

dojo.config['dojoBlankHtmlUrl'] = '/js/dojo/blank.html';

dojo.addOnLoad( function() { dicole_process_draft_shippers(); } );
dojo.addOnLoad( function() { dicole_process_autofills(); } );

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

function dicole_xhrplace( params ) {
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

    if ( ( content_found || form_found ) && content != shipper_log.last_success_content ) {
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
    var input_nodes = container ? dojo.query( '.f_dicole_autofill', container ) : dojo.query( '.f_dicole_autofill' );
    input_nodes.forEach( function ( input_node ) {
        var input_id = input_node.id;
        if ( dicole_autofiller_data[ input_id ] ) {
            if ( ! dicole_autofiller_data[ input_id ].running ) {
                dicole_autofiller_data[ input_id ].running = 1;
                dicole_autofiller_loop( input_id );
            }
        }
        else {
            var send_url_holder = dicole_class_id_query( input_id + '_autofill_url' )[0];
            if ( ! send_url_holder || ! send_url_holder.href ) return;

            dojo.connect( input_node, 'onblur', function ( evt ) {
                setTimeout( function() {
                    var dat = dicole_autofiller_data[ input_id ];
                    if ( dat.select_container ) dojo.destroy( dat.select_container );
                }, 200 );
            } );

            dicole_autofiller_data[ input_id ] = {
                node : input_node,
                url : send_url_holder.href,
                previous_value : input_node.value,
                running : 1,
                previous_value_count : 999,
                events : {
                    on_select : []
                }
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

