dojo.require('dojo.io.iframe');

dojo.addOnLoad( function() { process_blogs_promote() } );
dojo.addOnLoad( function() { process_blogs_rate() } );
dojo.addOnLoad( function() { process_blogs_more() } );
dojo.addOnLoad( function() { process_blogs_attachment_remove() } );
dojo.addOnLoad( function() { process_blogs_attachment_submit() } );

function process_blogs_attachment_submit() {
    var input_field = dojo.byId('blogs_attachment_submit_input');
    if ( input_field ) {
        dojo.connect( input_field, 'onchange', function ( evt ) {
            posss();
        } );
    }

//    setTimeout( 'posss', 10000 );
}

function posss(){
    var input_field = dojo.byId('blogs_attachment_submit_input');
    var target_form = dojo.byId('Form');
    var old_action = dojo.attr( target_form, 'action' );
    var old_target = dojo.attr( target_form, 'target' );
    dojo.io.iframe.send( {
        url : tinymce3_data.attachment_post_url,
        form : 'Form',
        handleAs: 'json',
        load : function ( data ) {
            if ( data.success ) {
                dojo.xhrPost( {
                    url : tinymce3_data.attachment_list_url,
                    form : 'Form',
                    handleAs: 'json',
                    load : function ( data ) {
                        dojo.query('.blogs_attachment_container').forEach( function ( container ) {
                            container.innerHTML = data.content;
                        } );
                    }
                } );
            }
        },
        error : function ( error ) { alert(error); }
    } );
    dojo.attr( target_form, 'action', old_action || '' );
    dojo.attr( target_form, 'target', old_target || '' );
}

function process_blogs_attachment_remove() {
    dicole_xhrplace( {
        base_class : 'blogs_attachment_remove_link',
        container_key_map : { blogs_attachment_container : 'messages_html' },
        after_procedure : function( data ) { process_blogs_attachment_remove(); }
    } );
}

function process_blogs_promote() {
    dojo.forEach( [ 'promote', 'demote' ], function( act ) {
        dicole_xhrplace( {
            base_class : 'blogs_promote_' + act,
            custom_id_container_key : 'messages_html',
            id_container_key_map : { points_container : 'total_points' },
            after_procedure : function( data ) { process_blogs_promote(); }
        } );
    } );
}

function process_blogs_rate() {
    dicole_xhrplace( {
        base_class : 'blogs_rate_link',
        custom_id_container_key : 'messages_html',
        after_procedure : function( data ) { process_blogs_rate(); }
    } );
}

function process_blogs_more() {
    dicole_xhrplace( {
        base_class : 'blogs_more_button',
        custom_id_container_key : 'messages_html',
        post_content_procedure : function ( node ) { return {
            page_load : gather_page_load_time(),
            shown_entry_ids : gather_shown_entry_ids_json()
        }; },
        after_procedure : function( data ) {
            process_blogs_promote();
            process_blogs_rate();
            process_blogs_more();
        }
    } );
}

function gather_shown_entry_ids_json() {
    var ids = [];
    dojo.query('.blogPost').forEach( function ( post ) {
        var node_id = dojo.attr( post, 'id') + '';
        var parts = node_id.match(/^blogs_entry_container_(\d+)$/);
        if ( ! parts || ! parts[1] ) return;
        ids.push( parts[1] );
    } );
    return dojo.toJson( ids );
}

function gather_page_load_time() {
    dojo.query('.blogs_post_listing').forEach( function ( listing ) {
        var listing_id = dojo.attr( listing, 'id' ) + '';
        var parts = listing_id.match(/^blogs_post_listing_(\d+)$/);
        if ( ! parts || ! parts[1] ) return;
        return parts[1];
    } );
    return 2147483647;
}
