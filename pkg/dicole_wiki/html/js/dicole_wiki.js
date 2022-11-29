var current_toolbar;
var current_iframe;
var renew_defer_active;
var last_succesfull_renew;
var block_info = {};
var toolbar;
var toolbar_save_query;
var toolbar_cancel_query;
var toolbar_original;
var toolbar_space;
var sh_switch_open_actions = new Array();

// var wiki_rpc = new dojo.rpc.JsonService( { smdObj : {
//     "serviceType": "JSON-RPC", 
//     "serviceURL": "/wiki_json/" + DicoleTargetId + "/", 
//     "methods":[ 
//         {
//             "name": "start_editing",
//             "parameters":[ {"name": "named_params"} ]
//         },
//         {
//             "name": "page_content",
//             "parameters":[ {"name": "named_params"} ]
//         },
//         {
//             "name": "renew_lock",
//             "parameters":[ {"name": "named_params"} ]
//         }
//     ]
// } } );

window.onbeforeunload = function() {
    if ( document.forms["Form"].edit_lock.value && ! document.forms["Form"].cancel.value == 1 &&
            ! document.forms["Form"].save.value == 1 ) {
        return content_data['strings']['warning'];
    }
}

function wiki_init() {
    var changed = _assign_restrictions_to_blocks( content_data.locks )
    _set_buttons_and_locks( changed );
}

function _assign_restrictions_to_blocks( locks, changes ) {

    var modified_blocks = {};

    for (var block_id in content_data.blocks) {

        if ( ! block_info[block_id] ) {
            block_info[block_id] = {
                content_locked : 0,
                block_locked : 0
            };
            modified_blocks[block_id] = 1;
        }

        // lock is never removed
        if ( block_info[block_id]['content_locked'] > 0 ) continue;

        var block = content_data.blocks[block_id];

        if ( !locks ) locks = [];
        for (var lock in locks) {
            lock = locks[lock];
            var ordered = (block.position < lock.position) ?
                [block,lock] : [lock,block];
            if ( ordered[0].position + ordered[0].size >
                    ordered[1].position ) {
                if ( lock.user_id == content_data.user_id &&
                        ordered[0].position == ordered[1].position ) {
                    if ( ordered[0].size == ordered[1].size ) {

                        block_info[block_id]['content_locked'] = 2;
                    }
                    else {
                        block_info[block_id]['content_locked'] = 3;
                    }
                }
                else {
                    if ( ordered[0].position == ordered[1].position ) {
                        block_info[block_id]['content_locked'] = 1;
                    }
                    else {
                        block_info[block_id]['content_locked'] = 4;
                    }
                }
                block_info[block_id]['lock_info'] = lock.message;
                modified_blocks[block_id] = 1;
                break;
            }
        }

        if ( block_info[block_id]['content_locked'] > 0 ) continue;

        if ( !changes ) changes = [];
        for (var change in changes) {
            change = changes[change];
            var ordered = (block.position < change.position) ?
                [block,change] : [change,block];
            if ( ordered[0].position + ordered[0].size >
                    ordered[1].position ) {
                block_info[block_id]['content_locked'] = 1;
                block_info[block_id]['lock_info'] = change.message;
                modified_blocks[block_id] = 1;
                break;
            }
        }
    }

    for (var block_id in content_data.blocks) {
        // lock is never removed
        if ( block_info[block_id]['block_locked'] > 0 ) continue;

        var blocked = 0;

        var block = content_data.blocks[block_id];
        if ( block.children.length > 1 ) {
            for (var c = 0; c < block.children.length; c++) {
                if ( block_info[block.children[c]]['content_locked'] > 0 ) {
                    blocked = 1;
                    break;
                }
            }
        }
        else {
            blocked = 1;
        }

        if ( blocked ) {
            block_info[block_id]['block_locked'] = 1;
            modified_blocks[block_id] = 1;
        }
    }

    var modified = [];
    for ( var block_id in modified_blocks ) modified.push( block_id );

    return modified;
}

function _set_buttons_and_locks( containers ) {

    for (var i = 0; i < containers.length; i++) {
        var id = containers[i];
        var elem = dojo.byId('wiki_content_' + id );

        if (!elem) continue;

        _empty_wiki_controls( id );

        if ( block_info[id]['content_locked'] > 0 ) {
            dojo.addClass( elem, 'wiki_content_locked' );
        }

        if ( block_info[id]['content_locked'] == 1 ) {
            _add_edit_info( id, block_info[id]['lock_info'] );
        }
        else if ( block_info[id]['content_locked'] == 2 ) {
            _add_edit_button( elem, id, 'content', 'own', block_info[id]['lock_info'] );
        }
        else if ( block_info[id]['content_locked'] == 3 ) {
            _add_edit_button( elem, id, 'block', 'own', block_info[id]['lock_info']);
        }
        else if ( block_info[id]['content_locked'] == 0 ) {
            _add_edit_button( elem, id, 'content' );

            if ( block_info[id]['block_locked'] == 0 ) {
                _add_wiki_controls( id, document.createTextNode(' | ') );
                _add_edit_button( elem, id, 'block' );
            }
        }
    }

    var toc_header = dojo.byId('toc_header');
    var toc_block = dojo.byId('toc_block');
    if ( toc_header && toc_block ) {
        var plus = document.createElement('a');
        plus.innerHTML = '[' + content_data.strings['show'] + ']';
        plus.setAttribute('href', '#');
        dojo.addClass( plus, 'sh_switch_open' );
        dojo.addClass( plus, 'sh_switch_open_toc' );

        var minus = document.createElement('a');
        minus.innerHTML = '[' + content_data.strings['hide'] + ']';
        minus.setAttribute('href', '#');
        dojo.addClass( minus, 'sh_switch_close' );
        dojo.addClass( minus, 'sh_switch_close_toc' );

        dojo.addClass( toc_block, 'sh_switch_block' );
        dojo.addClass( toc_block, 'sh_switch_block_toc' );

        dojo.place(plus, toc_header, 'last');
        dojo.place(minus, toc_header, 'last');
    }

    _process_sh_switches();

    sh_switch_open_actions.push( function( alink ) {
        if ( dojo.hasClass( alink, 'wiki_content_fetcher' ) ) {
            dojo.removeClass( alink, 'wiki_content_fetcher' );

            var classes = dojo.attr( alink, 'class' );
            var parts = classes.match(/wiki_content_fetcher_(\d+)_(\d+)/);
            if ( ! parts || ! parts[1] || ! parts[2] ) return true;

            var id = parts[2];

            var hlinks = dojo.query(
                '.wiki_header_link_' + id
            );

            if ( ! hlinks || ! hlinks[0] || ! hlinks[0].title ) return true;

            dojo.xhrPost( {
                url : alink.href,
                content : {
                    raw_title : hlinks[0].title,
                    header_base : parts[1]
                },
                handleAs: 'json',
                load : function(data) {
                    if ( data.content ) {
                        var blocks = dojo.query(
                            '.sh_switch_block_' + id
                        );
                        if ( blocks && blocks[0] ) {
                            blocks[0].innerHTML = data.content;
                        };
                    }
                },
                error : function ( error ) {
                    alert( 'Page content loading error: '+ error );
                }
            } );
        }
        return true;
    } );
}

function _process_sh_switches() {
    var minuses = dojo.query('.sh_switch_close');

    var ids = {};
    dojo.query('.sh_switch_open').forEach( function ( plus ) {
        var classes = dicole_getClasses(plus);
        for ( var j in classes ) {
            var clss = classes[j];
            var parts = clss.match(/^sw_switch_open_(.+)$/);
            if ( parts ) ids[ parts[1] ]++;
        }
    } );

    dojo.query('.sh_switch_close').forEach( function ( minus ) {
        var classes = dicole_getClasses(minus);
        for ( var j in classes ) {
            var clss = classes[j];
            var parts = clss.match(/^sh_switch_close_(.+)$/);
            if ( parts ) ids[ parts[1] ]++;
        }
    } );

    for ( var id in ids ) {
        var id_plusses = dojo.query('.sh_switch_open_'+id );
        var id_minuses = dojo.query('.sh_switch_close_'+id );
        var id_blocks = dojo.query('.sh_switch_block_'+id );

        var open_found = false;
        var closed_found = false;

        dojo.forEach( id_blocks, function ( block ) {
            if ( dojo.hasClass( block, 'hiddenBlock') )
                closed_found = true;
            else
                open_found = true;
        } );

        if ( closed_found && open_found ) {
            _sh_switch_set_visibility( id_blocks, 0 );
            _sh_switch_set_visibility( id_plusses, 1 );
            _sh_switch_set_visibility( id_minuses, 0 );
        }
        else if ( closed_found ) {
            _sh_switch_set_visibility( id_plusses, 1 );
            _sh_switch_set_visibility( id_minuses, 0 );
        }
        else if ( open_found ) {
            _sh_switch_set_visibility( id_plusses, 0 );
            _sh_switch_set_visibility( id_minuses, 1 );
        }
        else continue;

        dojo.forEach( id_plusses, function ( plus ) {
            _sh_switch_connect_toggle(
                plus, id_plusses,
                id_minuses, id_blocks, 1
            );
        } );
        dojo.forEach( id_minuses, function ( minus ) {
            _sh_switch_connect_toggle(
                minus, id_plusses,
                id_minuses, id_blocks, 0
            );
        } );
    }
}

function _sh_switch_connect_toggle( node, plusses, minuses, blocks, if_show) {
    dojo.connect( node, 'onclick', function(e) {
        e.preventDefault();
        if ( if_show ) {
            _sh_switch_set_visibility( blocks, 1 );
            _sh_switch_set_visibility( plusses, 0 );
            _sh_switch_set_visibility( minuses, 1 );

            for (var i in sh_switch_open_actions) {
                var cont = sh_switch_open_actions[i]( node );
                if ( ! cont ) break;
            }
        }
        else {
            _sh_switch_set_visibility( blocks, 0 );
            _sh_switch_set_visibility( plusses, 1 );
            _sh_switch_set_visibility( minuses, 0 );
        }
    } );
}

function _sh_switch_set_visibility( elements, if_show ) {
    if ( if_show ) {
        dojo.forEach( elements, function ( elem ) {
            if ( dojo.hasClass( elem, 'hiddenBlock') ) {
                dojo.removeClass( elem, 'hiddenBlock' );
            }
        } );
    }
    else {
        dojo.forEach( elements, function ( elem ) {
            if ( ! dojo.hasClass( elem, 'hiddenBlock') ) {
                dojo.addClass( elem, 'hiddenBlock' );
            }
        } );
    }
}

function _hide_sh_switches() {
    var plusses = dojo.query('.sh_switch_open');
    var minuses = dojo.query('.sh_switch_close');
    _sh_switch_set_visibility( plusses, 0 );
    _sh_switch_set_visibility( minuses, 0 );
}

function _add_edit_button( elem, id, type, own, info ) {
    var target_element = (type == 'block') ?
        elem.parentNode : elem;

    var alink = document.createElement('a');
    if ( own ) {
        alink.innerHTML = content_data.strings['Resume edit'];
    }
    else if ( id != 1 ) {
        alink.innerHTML = content_data.strings['Edit ' + type];
    }
    else {
        alink.innerHTML = ( type == 'block' ) ?
            content_data.strings['Edit whole'] :
            content_data.strings['Edit begin'];
    }
    dojo.addClass( alink, 'wiki_edit_button' );
//     dojo.addClass( alink, 'linkButton' );
    alink.setAttribute('href', '#');
    dojo.connect(alink, "onclick", function(e) {
        e.preventDefault();
        return _start_edit( target_element, id, type );
    });
    dojo.connect(alink, "onmouseover", function() {
        return _wiki_highlight( target_element );
    });
    dojo.connect(alink, "onmouseout", function() {
        return _wiki_dehighlight( target_element );
    });

    _add_wiki_controls( id, alink );

    if ( own ) {
        _add_wiki_controls( id, document.createTextNode(' | ') );

        var span = document.createElement('span');
        span.innerHTML = info;
        dojo.attr( span, 'class', 'wiki_edit_info' );
        _add_wiki_controls( id, span );
    }
}

function _add_edit_info( id, message ) {
    var span = document.createElement('span');
    span.innerHTML = message;
    dojo.attr( span, 'class', 'wiki_edit_info' );

    _add_wiki_controls( id, span );
}

function _start_edit( elem, id, type ) {

    _wiki_dehighlight( elem );
    
    dojo.style(dojo.byId("wiki_block_1"), "position", "static");

    _set_edit_values(id, type);
    _hide_wiki_controls();
    _hide_sh_switches();
    _gray_backgrounds_except( elem.id );

    _empty_wiki_controls( id );
    _add_edit_info( id, content_data.strings['Reserving lock..'] );
    _show_wiki_controls( id );

    dojo.xhrPost( {
        url : content_data.start_editing_url,
        content : page_params,
        handleAs : 'json',
        load : function(data) {
            _handle_start_response( data, elem, id, type );
        },
        error : function ( error ) {
            alert( 'Error connecting server: ' + error );
        }
    } );

    return false;
}

function _handle_start_response(data, elem, id, type) {
    if ( data && data.lock_granted == 1 ) {
        _remove_wiki_controls();

        elem.innerHTML = data.content;

        document.forms["Form"].edit_lock.value = data.lock_id;

        dojo.query('textarea.mceEditor').forEach( function ( commentEditor ) {
            try {
                var commentEditorId = dojo.attr(commentEditor, 'id');
                tinyMCE.execCommand('mceRemoveControl', false, commentEditorId);
                var pn = commentEditor.parentNode;
                while ( pn ) {
                    if ( dojo.hasClass( pn, 'comments_input_container' ) ) {
                        dojo.style(pn, "display", "none");
                        break;
                    }
                    pn = pn.parentNode;
                }
            }
            catch ( e ) {
                // this try is here so that unitialized mceEditor classed elements
                // won't break the editor initialization
            }
        } )

        wiki_tinymce_init();
        tinyMCE.execCommand('mceAddControl', false, elem.id);

        _delayed_document_actions();
    }
    else if ( data && data.lock_granted == 0 ) {
        var changed = _assign_restrictions_to_blocks(
            data.locks, data.changes
        );
        _set_buttons_and_locks( changed );
        _show_wiki_controls();
        _ungray_backgrounds_except( elem.id );
    }
    else {
        alert( 'Something unexpected happened. Please reload page.' );
    }
}

var previous_toolbar_height = 0;

function _delayed_document_actions() {
    var ae;

    try {
        ae = tinyMCE.activeEditor;
        ae.getDoc();
    }
    catch(e) {
        setTimeout( _delayed_document_actions, 100);
        return;
    }

    // Move tinymce generated toolbar to our own table so that we can position it
    toolbar = dojo.byId('wiki_toolbar_container_table');
    var placeholder = dojo.byId('wiki_toolbar_container_tr');
    dojo.query( 'tr', ae.getContainer() ).forEach( function( toolbar_content ) {
        if ( dojo.query( 'td.mceIframeContainer', toolbar_content ).length > 0 ) return;
        if ( dojo.query( 'td.tinymce_toolbar_container', toolbar_content ).length == 0 ) return;
        dojo.place( toolbar_content, placeholder, 'before');
    } );

    _init_toolbar_queries_and_original(toolbar);

    _delayed_document_actions_2()
}

function _delayed_document_actions_2() {
        try {
            // We also have this slight problem of our newly filled table
            // not actually showing the correct height so we need to wait
            // until it comes to it's senses..
            if ( dojo.coords( toolbar ).h != previous_toolbar_height ) {
                previous_toolbar_height = dojo.coords( toolbar ).h;
                throw new Error();
            }
        }
        catch(e) {
            setTimeout( _delayed_document_actions_2, 100);
            return;
        }

        dojo.byId( tinyMCE.activeEditor.id + '_tbl' ).style.height = '1px';

        _lock_renew_loop();
        _resize_editor_loop();
        _position_toolbar_loop();

        // We don't want auto_resize to make conflicting resize
        // operations but we need the plugin to disable scrolling
        // on the iframe on IE since there it can't be done
        // afterwards.

        tinyMCE.settings['auto_resize'] = false;
}

function _lock_renew_loop() {
    var now = new Date();
    var renew_timeout = 15000;

    if ( ! last_succesfull_renew ||
         last_succesfull_renew + renew_timeout < now.valueOf() ) {

        if ( ! renew_defer_active ) {

            renew_defer_active = true;

            dojo.xhrPost( {
                url : content_data.renew_lock_url,
                content : {
                    lock_id : document.forms["Form"].edit_lock.value,
                    autosave_content : tinyMCE.activeEditor.getContent({ format : 'raw' })
                },
                timeout : 5000,
                handleAs : 'json',
                load : function(data) {
                    if (data && data.renew_succesfull ) {
                        var d = new Date();
                        last_succesfull_renew = d.valueOf();
                    }
                    else {
                        // TODO: Handle failure ?
                    }
                    renew_defer_active = false;
                },
                error : function(data) {
                    // TODO: Handle failure ?
                    renew_defer_active = false;
                }
            } );
        }
    }

    setTimeout( _lock_renew_loop, 1000);
}

function _gray_backgrounds_except( id ) {
    dojo.query('.wiki_content_container').forEach( function ( elem ) {
        if ( dojo.attr( elem, 'id' ) == id ) return;
        dojo.addClass(elem, 'wiki_content_grayed');
    } );
}

function _ungray_backgrounds_except( id ) {
    dojo.query('.wiki_content_container').forEach( function ( elem ) {;
        if ( dojo.attr( elem, 'id' ) == id ) return;
        dojo.removeClass(elem, 'wiki_content_grayed');
    } );
}

function _create_space_for_toolbar() {
    var div = document.createElement('div');
    var parent = tinyMCE.activeEditor.getContainer();
    parent.insertBefore(div, parent.childNodes[0]);
    toolbar_space = div;
}

function _resize_editor_loop() {
/**
    inst.iframeElement.style.height = '300px';

    var dech = doc.documentElement ? doc.documentElement.clientHeight : '';
    var desh = doc.documentElement ? doc.documentElement.scrollHeight : '';

    alert(
        "; body.offsetHeight " + doc.body.offsetHeight + 
        "; body.scrollHeight " + doc.body.scrollHeight + 
        "; body.clientHeight " + doc.body.clientHeight +
        "; documentElement.clientHeight " + dech +
        "; documentElement.scrollHeight " + desh
    );
**/
    _resize_editor();
    setTimeout( _resize_editor_loop, 200);
}

function _resize_editor() {

    var inst = tinyMCE.selectedInstance;
    var doc = inst.getDoc();

    if ( doc.body.scrollTop + doc.documentElement.scrollTop > 0 ) {
        var scrollX = doc.body.scrollLeft + doc.documentElement.scrollLeft;
        inst.contentWindow.scrollTo( scrollX, 0 );
    }

    if ( ! current_iframe ) {
        current_iframe = new Object();
        current_iframe['height'] = 0;
    }

    var wanted_height = doc.body.scrollHeight;
    if ( doc.documentElement ) {
        var de = doc.documentElement;
        if ( de.scrollHeight && de.clientHeight == de.scrollHeight ) {
            wanted_height = de.scrollHeight;
        }
    }

    wanted_height = wanted_height + 1;
    var diff = current_iframe['height'] - wanted_height;
    if ( diff > 2 || diff < -2 ) {
        dojo.byId( inst.id + '_ifr' ).style.height = wanted_height + 'px';
        current_iframe['height'] = wanted_height;
    }
}

function _position_toolbar_loop() {
    _position_toolbar( true );
    setTimeout( _position_toolbar_loop, 200);
}

function _position_toolbar( recalculate ) {
    if ( ! current_toolbar || recalculate ) {
        current_toolbar = new Object();
        current_toolbar['element'] = toolbar;
        _calculate_tb_info( current_toolbar );

        if ( ! toolbar_space ) _create_space_for_toolbar();
        toolbar_space.style.height = 4 + current_toolbar['height'] + 'px';

        _calculate_opt_info( current_toolbar );
        toolbar.style.width = current_toolbar['optimal_width'] + 'px';
        var overlay_node = dojo.byId(tinyMCE.activeEditor.id + '_overlay');
        if ( overlay_node ) {
            overlay_node.style.left = ( current_toolbar['ifr_left'] ) + 'px';
            overlay_node.style.top = ( current_toolbar['ifr_top'] ) + 'px';

        }
    }

    var intended_top;
    var intended_left;

    var minTop = window.pageYOffset || document.documentElement.scrollTop || dojo.body().scrollTop || 0;
    if ( current_toolbar['optimal_top'] < minTop ) {
        intended_top = minTop;
    }
    else {
        intended_top = current_toolbar['optimal_top'];
    }

    var minLeft = window.pageXOffset || document.documentElement.scrollLeft || dojo.body().scrollLeft || 0;
    if ( current_toolbar['optimal_left'] < minLeft ) {
        intended_left = minLeft;
    }
    else {
        intended_left = current_toolbar['optimal_left'];
    }

    if (intended_top != current_toolbar['top']) {
        current_toolbar['top'] = intended_top;
        current_toolbar['element'].style.top = intended_top + 'px'
    }

    if (intended_left != current_toolbar['left']) {
        current_toolbar['left'] = intended_left;
        current_toolbar['element'].style.left = intended_left + 'px'
    }
}

function _calculate_tb_info( object ) {
    var element = object['element'];
    var emb = dojo.coords(element, true);
    object['height'] = emb.h;
    object['width'] = emb.w;
    object['top'] = emb.y;
    object['left'] = emb.x;
}

function _calculate_opt_info( object ) {
    var iframe = dojo.byId( tinyMCE.activeEditor.id + '_ifr' );
    var imb = dojo.coords(iframe, true);
//    object['optimal_top'] = imb.y - object['height'] - 2;
//    object['optimal_left'] = imb.x - 1;
    object['optimal_top'] = imb.y - object['height'] - 2;
    object['optimal_left'] = imb.x - 1;
    object['optimal_width'] = imb.w;
    object['ifr_top'] = imb.y;
    object['ifr_left'] = imb.x;
}

function _calculate_info ( o ) {
    _calculate_tb_info( o );
    _calculate_opt_info( o );
}

function _set_edit_values(edit_id, edit_type) {
    document.forms["Form"].edit_target_id.value = edit_id;
    document.forms["Form"].edit_target_type.value = edit_type;
    page_params.edit_target_id = edit_id;
    page_params.edit_target_type = edit_type;
}

// not used anymore?
function _get_original_html_from_block( elem ) {
    var elems = dojo.query('.wiki_content_container', elem);
    var html = '';
    for (var i = 0; i < elems.length; i++) {
        // Dojo does not work.. IT does not return only
        // Elements below elem :( So we do this:
        if (dojo.isDescendantOf(elems[i], elem) ) {
            html = html + elems[i].innerHTML;
        }
    }
    return html;
}

function _remove_wiki_controls() {
    var elems = dojo.query('.wiki_controls');
    for (var i = 0; i < elems.length; i++) {
        elems[i].parentNode.removeChild(elems[i]);
    }
}

function _empty_wiki_controls( id ) {
    var controls = dojo.byId( 'wiki_controls_' + id );
    controls.innerHTML= '';
}

function _add_wiki_controls( id, elem ) {
    var controls = dojo.byId( 'wiki_controls_' + id );
    dojo.place(elem, controls, 'first');
}

function _hide_wiki_controls( id ) {
    var elems = id ? [ dojo.byId( 'wiki_controls_' + id ) ] :
        dojo.query('.wiki_controls');
    for (var i = 0; i < elems.length; i++) {
        dojo.addClass(elems[i], 'hidden_wiki_controls' );
    }
}

function _show_wiki_controls( id ) {
    var elems = id ? [ dojo.byId( 'wiki_controls_' + id ) ] :
        dojo.query('.wiki_controls');
    for (var i = 0; i < elems.length; i++) {
        dojo.removeClass(elems[i], 'hidden_wiki_controls' );
    }
}

function _wiki_highlight( elem ) {
    dojo.addClass(elem, 'wiki_content_highlight');
}

function _wiki_dehighlight( elem ) {
    dojo.removeClass(elem, 'wiki_content_highlight');
}

function _cancel_wiki_edit() {
    if ( ! toolbar_cancel_query ) {
        _init_toolbar_queries_and_original(toolbar);
    }

    dojo.removeClass( toolbar_cancel_query, 'hiddenBlock' );

    for (i in toolbar_original ) {
        if ( toolbar_original[i] ) {
            dojo.addClass( toolbar_original[i], 'hiddenBlock' );
        }
    }

    _position_toolbar ( true );
}

function _save_wiki_edit() {

    if ( ! toolbar_save_query ) {
        _init_toolbar_queries_and_original(toolbar);
    }

    dojo.removeClass( toolbar_save_query, 'hiddenBlock' );

    for (i in toolbar_original ) {
        if ( toolbar_original[i] ) {
            dojo.addClass( toolbar_original[i], 'hiddenBlock' );
        }
    }

    _position_toolbar ( true );
}

var dicole_wiki_description_has_been_cleared = 0;

function _init_toolbar_queries_and_original(toolbar) {
    // copy just current children
//     toolbar_original = [];
//     var cn = toolbar.childNodes;
//     for (i in cn) toolbar_original.push( cn[i] );

//     toolbar_save_query = dojo.byId('toolbar_comment_query');
//     dojo.place(toolbar_save_query, toolbar, 'first');
// 
//     toolbar_cancel_query = dojo.byId('toolbar_cancel_query');
//     dojo.place(toolbar_cancel_query, toolbar, 'first');

    var descnode = dojo.byId('edit_description');

    if ( descnode ) {
        dojo.connect( descnode, 'onfocus', function(e) {
            if ( dicole_wiki_description_has_been_cleared ) return;
            dicole_wiki_description_has_been_cleared = 1;
            descnode.value = '';
        } );
    }

    var confirm = dojo.byId('confirm_save');
    dojo.connect( confirm, 'onclick', function(e) {
        e.preventDefault();
        var desc = dicole_wiki_description_has_been_cleared ?
            descnode ? descnode.value : '' : '';
        document.forms["Form"].change_description.value = desc;
        document.forms["Form"].change_minor.value = 0;

        document.forms["Form"].base_version_number.value = 
            page_params.base_version_number 
        document.forms["Form"].edit_content.value = tinyMCE.activeEditor.getContent();
        document.forms["Form"].save.value = 1;
        document.forms["Form"].submit();
    } );

    var confirm_i = dojo.byId('confirm_save_invisible');
    dojo.connect( confirm_i, 'onclick', function(e) {
        e.preventDefault();
        var desc = dicole_wiki_description_has_been_cleared ?
            descnode ? descnode.value : '' : '';
        document.forms["Form"].change_description.value = desc;
        document.forms["Form"].change_minor.value = 1;

        document.forms["Form"].base_version_number.value = 
            page_params.base_version_number 
        document.forms["Form"].edit_content.value = tinyMCE.activeEditor.getContent();
        document.forms["Form"].save.value = 1;
        document.forms["Form"].submit();
    } );

    var cancel_accept = dojo.byId('cancel_accept');
    dojo.connect( cancel_accept, 'onclick', function(e) {
        e.preventDefault();
        document.forms["Form"].cancel.value = 1;
        document.forms["Form"].submit();
    } );

    var cancel = dojo.byId('confirm_cancel');
    dojo.connect( cancel, 'onclick', function(e) {
        e.preventDefault();

        dicole_tinymce_toolbar_switch( tinyMCE.activeEditor, 'save' );

        _position_toolbar ( true );
    } );

    var cancel_back = dojo.byId('cancel_back');
    dojo.connect( cancel_back, 'onclick', function(e) {
        e.preventDefault();

        dicole_tinymce_toolbar_switch( tinyMCE.activeEditor, 'cancel' );

        _position_toolbar ( true );
    } );
}

dojo.addOnLoad( function() { process_wiki_attachment_remove() } );

function process_wiki_attachment_remove() {
    dojo.query('.wiki_attachment_remove_link').forEach( function ( remove_link ) {
        if ( dojo.hasClass( remove_link, 'wiki_attachment_remove_link_processed' ) ) return;
        dojo.addClass( remove_link, 'wiki_attachment_remove_link_processed' );
        
        wiki_attachment_remove_attach( remove_link );
    } );
}

function wiki_attachment_remove_attach( remove_link ) {
    dojo.connect( remove_link, 'onclick', function( evt ) {
        evt.preventDefault();
        dojo.xhrPost({
            url: remove_link.href,
            handleAs: 'json',
            content : {},
            load: function(data) {
                var container = wiki_look_up_for_class( remove_link, 'wiki_attachment_container');
                if ( container && data.messages_html ) {;
                    container.innerHTML = data.messages_html;
                    process_wiki_attachment_remove();
                }
            },
            error: function(error) {
                alert('Error removing attachment. Please try again.');
            }
        });
    } );
}

function wiki_look_up_for_class( node, classi ) {
    if ( dojo.hasClass( node, classi ) ) {
        return node;
    }
    else {
        if ( node.parentNode ) {
            return wiki_look_up_for_class( node.parentNode, classi );
        }
        else {
            return false;
        }
    }
}

function dicole_getClasses( node ) {
    var cls = dojo.attr(node, 'class') + '';
    var clsa = cls.split(/\s+/);
    return clsa;
}

