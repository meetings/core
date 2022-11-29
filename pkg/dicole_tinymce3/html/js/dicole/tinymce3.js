dojo.provide("dicole.tinymce3");

function _encode_wiki_title( title, anchor ) {
    title = title ? title.replace(/ /g, '  ') : '';
    anchor = anchor ? anchor.replace(/ /g, '  ') : false;

    return ( anchor ) ? title + '   :   ' + anchor : title;
}

function _decode_wiki_title( raw ) {
    var title;
    var anchor;

    var parts = raw.match(/^(([^ ]|  )+)   :   (([^ ]|  )+)$/);

    if ( parts && parts[1] && parts[3] ) {
        title = parts[1].replace(/  /g, ' ');
        anchor = parts[3].replace(/  /g, ' ');
    }
    else {
        title = raw;
        // conditional to try to preserve backwards compatibility
        // in cases where old title had adjacent spaces
        if ( title.match(/^([^ ]|  )+$/) ) {
            title = title.replace(/  /g, ' ');
        }
    }

    return [ title, anchor ];
}

function dicole_tinymce_execute_justify(ed, justify) {
    var s = ed.selection.getNode();
    if(s) {
        var p = ed.dom.getParent(s, 'P');
        if(p) { 
            ed.dom.setStyle(p, 'text-align', justify);
            ed.execCommand('mceRepaint');
        }
    }
}

function dicole_tinymce_execute_image_align( ed, algn ) {
    var e = ed.selection.getNode();

    if (e && e.nodeName == 'IMG') {
        ed.dom.setAttribs(e, { 'align' : algn, 'style' : 'margin: 10px;' });
    }
}

var bm;

function dicole_tinymce_execute_link_open( ed ) {
    bm = ed.selection.getBookmark();

    var link_href = dojo.byId( ed.id + '_dicole_link_href' );
    var wiki_name = dojo.byId( ed.id + '_dicole_wiki_name' );

    var link_node = ed.dom.getParent(ed.selection.getNode(), 'A');
    if ( link_node ) {
        if ( ed.dom.hasClass( link_node, 'wikiLink' ) ) {
            link_href.value = '';
            var ta = _decode_wiki_title( ed.dom.getAttrib(link_node, 'title') );
            wiki_name.value = ta[0];
        }
        else {
            link_href.value = ed.dom.getAttrib(link_node, 'href');
            wiki_name.value = '';
        }
    }
    else {
        var sel = ed.selection.getContent({format : 'text'});
        if ( sel.indexOf('http') == 0 ) {
            link_href.value = sel;
            wiki_name.value = '';
        }
        else {
            link_href.value = '';
            wiki_name.value = sel;
        }
    }

    dicole_tinymce_toolbar_switch( ed, 'link' );
}

function dicole_tinymce_execute_showroom_open( ed ) {
    bm = ed.selection.getBookmark();
    var link_node = ed.dom.getParent(ed.selection.getNode(), 'A');
    var success = 0;
    if ( link_node ) {
        try {
            var attr = dojo.fromJson( ed.dom.getAttrib(link_node, 'title') || [] );
            dojo.byId( ed.id + '_dicole_showroom_title' ).value = attr[0];
            dojo.byId( ed.id + '_dicole_showroom_width' ).value = attr[1];
            dojo.byId( ed.id + '_dicole_showroom_height' ).value = attr[2];

            // lol @ tinymce hacks
            var raw = attr[3] + "";
            var real = raw.replace(/ tinymcehackfix(src|href|style|coords|shape)=/gi, function( m, b ) { return ' '+ b + '='; } );
            dojo.byId( ed.id + '_dicole_showroom_area' ).value = real;

            success = 1;
        }
        catch (e) {}
    }
    if ( ! success ) {
        dojo.forEach( [ 'title', 'width', 'height', 'area' ], function( part ) {
            var node = dojo.byId( ed.id + '_dicole_showroom_'+ part );
            node.value = node.defaultValue;
        } );
    }

    dicole_tinymce_toolbar_switch( ed, 'showroom' );
}

function dicole_tinymce_execute_image_open( ed ) {
    var image_src_node = dojo.byId( ed.id + '_dicole_image_src' );
    var e = ed.selection.getNode();
    image_src_node.value = e ? e.src || '' : '';

    dicole_tinymce_toolbar_switch( ed, 'image' );
}

function dicole_tinymce_execute_html_open( ed ) {
    var html_area_node = dojo.byId( ed.id + '_dicole_html_area' );
    var e = ed.selection.getNode();
    html_area_node.value = e ? e.alt || '' : '';

    dicole_tinymce_toolbar_switch( ed, 'html' );
}

function dicole_tinymce_render_attachment(aeid, at) {
    var ed = tinyMCE.activeEditor;

    var attachment = dojo.create('div', {id: at.filename, 'class': 'attachment_list_attachment'}, dojo.byId(aeid + '_attachment_queue_separator'), 'after');
    var delete_link = dojo.create('a', {'class': dojo.isIE ? 'attachment_list_attachment_delete_ie' : 'attachment_list_attachment_delete', href: '#', innerHTML: ''}, attachment);
    dojo.create('br', {}, attachment);

    var thumbnail_url = at.list_image_url ? at.list_image_url : dojo.isIE ? '/js/generic_attachment.gif' : '/js/generic_attachment.png';

    var confirm_link = dojo.create('a', {'class': 'attachment_list_attachment_confirm_delete', href: '#', 'style': 'background: transparent url(' + thumbnail_url + ') no-repeat scroll center center'}, attachment);
    var confirm_bg = dojo.create('div', {'class': 'attachment_list_attachment_confirm_delete_bg'}, confirm_link);
    dojo.create('span', {'class': 'attachment_list_attachment_confirm_delete_x', innerHTML: 'X'}, confirm_bg);
    dojo.create('br', {}, confirm_bg);
    dojo.create('span', {'class': 'attachment_list_attachment_confirm_delete_text', innerHTML: ed.translate('dicole.button_confirm_delete')}, confirm_bg);

    var add_link = dojo.create('a', {href: '#', 'title' : at.filename}, attachment);
    dojo.create('img', {id: at.list_image_url, 'alt' : at.filename, 'title' : at.filename, src: thumbnail_url}, add_link);

    dojo.connect(confirm_link, 'onclick', function(evt) {
        dojo.destroy(at.filename);
        dojo.xhrPost({
            url: at.delete_url,
            form: 'Form',
            handleAs: 'json'
        });
    });

    dojo.connect(add_link, 'onclick', function(evt) {
        dicole_tinymce_attachment_execute( evt, aeid, at )
    });

    dojo.create('div', {'class': 'attachment_list_attachment_filename', 'title' : at.filename, innerHTML: dicole_tinymce_shorten_filename(escape(at.filename), 22)}, attachment);

    dojo.connect(delete_link, 'onclick', function(evt) {
        dojo.style(delete_link, 'display', 'none');
        dojo.style(add_link, 'display', 'none');
        dojo.style(confirm_link, 'display', 'block');
        hover_timer = setTimeout(function() { 
            dojo.style(delete_link, 'display', 'inline'); 
            dojo.style(add_link, 'display', 'inline'); 
            dojo.style(confirm_link, 'display', 'none');
        }, 5000);
    });

    var hover_timer;
    dojo.connect(confirm_link, 'onmouseover', function(evt) {
        clearTimeout(hover_timer);
    });
    dojo.connect(confirm_link, 'onmouseout', function(evt) {
        hover_timer = setTimeout(function() { 
            dojo.style(delete_link, 'display', 'inline'); 
            dojo.style(add_link, 'display', 'inline'); 
            dojo.style(confirm_link, 'display', 'none');
        }, 5000);
    });
}

function dicole_tinymce_shorten_filename(filename, max_length)
{
    if(filename.length < max_length) return filename;
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
}

function dicole_tinymce_container_postrender( n, cm, aeid ) {

    if ( n == 'dicole_attachment_container' ) {
        var container = dojo.byId( aeid + '_attachment_upload_container' );

        var post_url = tinymce3_data.attachment_post_url_by_id ? tinymce3_data.attachment_post_url_by_id[aeid] : '';
        if ( ! post_url ) post_url = tinymce3_data.attachment_post_url;
        if ( ! post_url || ! container ) {
            cm.setDisabled( n, true );
            return;
        }

        // This button can not be created programmatically because creating a dijit.form.Button object does
        // not work in Safari - probably because it is a reserved word or something..
//         container.innerHTML = '<span id="' + aeid + '_attachment_upload_button' + '"></span>';
//         dojo.parser.parse( container );

//         var uploader = new dojox.form.FileUploader({
//             id : aeid + '_attachment_upload_uploader',
//             swfPath : '/js/dojo/uploader.swf',
//             postData : { i_am_flash : 1 },
//             selectMultipleFiles: false,
//             htmlFieldName : 'upload_attachment',
//             flashFieldName : 'upload_attachment',
//             devMode: false,
//             isDebug: false,
//             button: dijit.byId( aeid + '_attachment_upload_button' ),
//             uploadUrl: post_url,
//             uploadOnChange: true
//         });
// 
//         dojo.connect( uploader, "onComplete", function ( data ) {
//             dojo.xhrPost( {
//                 url : tinymce3_data.attachment_list_url,
//                 form : 'Form',
//                 handleAs: 'json',
//                 load : function ( data ) {
//                     dojo.query('#' + aeid + '_attachment_list_container' ).forEach( function ( container ) {
//                         container.innerHTML = data.content;
//                     } );
//                 }
//             } );
//         } );

        var attachments = dojo.byId(aeid + '_attachment_list_container');
        var queue_separator = dojo.byId(aeid + '_attachment_queue_separator');

        var swfu = new SWFUpload({ 
            upload_url : post_url,
            flash_url : '/js/swfupload.swf', 
            button_placeholder_id : aeid + '_attachment_upload_button_placeholder',
            button_width: 168,
            button_height: 25,
            button_window_mode: SWFUpload.WINDOW_MODE.TRANSPARENT,
            button_action: SWFUpload.BUTTON_ACTION.SELECT_FILES,
            
            swfupload_loaded_handler: function() {
                var upload_link = dojo.byId(aeid + '_attachment_upload_text');
                dojo.attr(upload_link, 'innerHTML', tinyMCE.activeEditor.translate('dicole.uploader_add_attachment'));
            },

            file_queued_handler: function(file) {
                var attachment = dojo.create('div', {id: file.id, 'class': 'attachment_list_attachment'}, queue_separator, 'before');
                dojo.connect(dojo.create('a', {'class': dojo.isIE ? 'attachment_list_attachment_delete_ie' : 'attachment_list_attachment_delete', href: '#', innerHTML: ''}, attachment), 'onclick', function(evt) {
                    dojo.destroy(file.id);
                    swfu.cancelUpload(file.id);
                    swfu.startUpload();
                });
                var progress_bar_container = dojo.create('div', {'class': 'progress_bar_container'}, attachment);
                dojo.create('div', {id: file.id + '_progress_bar', 'class': 'progress_bar', innerHTML: ''}, progress_bar_container);
                dojo.create('span', {innerHTML: dicole_tinymce_shorten_filename(escape(file.name), 22)}, attachment);
                dojo.create('br', {}, attachment);
                dojo.create('span', {id: file.id + '_status', innerHTML: tinyMCE.activeEditor.translate('dicole.uploader_waiting')}, attachment);
            },
            
            file_dialog_complete_handler: function(a, b, c) {
                swfu.startUpload();
            },
            
            upload_progress_handler: function(file, completed, total) {
                dojo.style(dojo.byId(file.id + '_progress_bar'), 'width', Math.round(completed / total * 150) + 'px');
                dojo.attr(dojo.byId(file.id + '_status'), 'innerHTML', tinyMCE.activeEditor.translate('dicole.uploader_uploading') + Math.round(completed / total * 100) + '%');
            },
            
            upload_complete_handler: function(file) {
                dojo.attr(dojo.byId(file.id + '_status'), 'innerHTML', tinyMCE.activeEditor.translate('dicole.uploader_done'));
                dojo.xhrPost( {
                    url : tinymce3_data.attachment_list_url,
                    content : {},
                    handleAs: 'json',
                    load : function ( data ) {
                        dojo.destroy(file.id);
                        dojo.query('#' + aeid + '_attachment_list_container' ).forEach( function ( container ) {
                            dojo.forEach( data, function ( at ) {
                                var attachment = dojo.byId(at.filename);
                                if(!attachment) dicole_tinymce_render_attachment(aeid, at);
                            } );
                        } );
                    }
                } );
                swfu.startUpload();
            }
        });

        dojo.xhrPost( {
            url : tinymce3_data.attachment_list_url,
            content : {},
            handleAs: 'json',
            load : function ( data ) {
                dojo.query('#' + aeid + '_attachment_list_container' ).forEach( function ( container ) {
                    dojo.forEach( data, function ( at ) {
                        dicole_tinymce_render_attachment(aeid, at);
                    } );
                } );
            }
        } );
    }

    else if ( n == 'dicole_link_container' ) {
        var more_link = dojo.byId( aeid + '_wiki_show_more_url' );
        if ( more_link ) dojo.connect( more_link, 'onclick', function( evt ) {
            evt.preventDefault();
            var ed = tinyMCE.activeEditor;
            ed.plugins.dicole.myOpen( ed, tinymce3_data.wiki_url, {} );
        } );

        var link_add = dojo.byId( aeid + '_dicole_link_href_submit' );
        if (link_add ) dojo.connect( link_add, 'onclick', function( evt ) {
            dicole_tinymce_link_execute( evt, aeid, 0 );
        } );
        
        var link_remove = dojo.byId(aeid + '_dicole_link_href_clear');
        if(link_remove) dojo.connect(link_remove, 'onclick', function(evt) {
            dicole_tinymce_link_remove(evt, aeid);
        });

        var wiki_add = dojo.byId( aeid + '_dicole_wiki_name_submit' );
        if ( wiki_add ) dojo.connect( wiki_add, 'onclick', function( evt ) {
            dicole_tinymce_link_execute( evt, aeid, 1 );
        } );
        
        var wiki_remove = dojo.byId(aeid + '_dicole_wiki_name_clear');
        if(wiki_remove) dojo.connect(wiki_remove, 'onclick', function(evt) {
            dicole_tinymce_link_remove(evt, aeid);
        });

        var recent_container = dojo.byId( aeid + '_wiki_page_list_container' );
        if ( recent_container ) {
            dojo.query('.f_recent_wiki_page_link', recent_container ).forEach( function ( node ) {
                dojo.connect( node, 'onclick', function ( evt ) {
                    dojo.byId( aeid + '_dicole_wiki_name' ).value = node.title;
                    dicole_tinymce_link_execute( evt, aeid, 1 );
                } );
            } );
        }

        dicole_process_autofills();

        dicole_autofiller_add_event( aeid + '_dicole_wiki_name', 'on_select', function ( input_id, r ) {
            dicole_tinymce_link_execute( null, aeid, 1 );
        } );
    }
    else if ( n == 'dicole_html_container' ) {
        var html_add = dojo.byId( aeid + '_dicole_html_area_submit' );
        if ( html_add ) dojo.connect( html_add, 'onclick', function( evt ) {
            dicole_tinymce_html_execute( evt, aeid );
        } );
    }
    else if ( n == 'dicole_showroom_container' ) {
        var showroom_add = dojo.byId( aeid + '_dicole_showroom_area_submit' );
        if ( showroom_add ) dojo.connect( showroom_add, 'onclick', function( evt ) {
            dicole_tinymce_showroom_execute( evt, aeid );
        } );
        dojo.forEach( [ aeid + '_dicole_showroom_area', aeid + '_dicole_showroom_title' ], function( id ) {
            var node = dojo.byId( id );
            if ( node ) dojo.connect( node, 'onfocus', function( evt ) {
                if ( node.value == node.defaultValue ) node.value = '';
            } );
        } );
    }
    else if ( n == 'dicole_image_container' ) {
        var image_add = dojo.byId( aeid + '_dicole_image_src_submit' );
        if ( image_add ) dojo.connect( image_add, 'onclick', function( evt ) {
            dicole_tinymce_image_execute( evt, aeid );
        } );
    }
}

function dicole_tinymce_image_execute( evt, aeid ) {
    if ( evt ) evt.preventDefault();

    var ed = tinyMCE.activeEditor;
    var val = dojo.byId( aeid + '_dicole_image_src' ).value;
    var e = ed.selection.getNode();

    var args = {
        src : val,
        alt : val
//        align : getSelectValue(f, 'image_align')
    };

    if (e && e.nodeName == 'IMG') {
        ed.dom.setAttribs(e, args);
    }
    else {
        ed.execCommand('mceInsertContent', false, '<img id="__mce_tmp" />', {skip_undo : 1});
        ed.dom.setAttribs('__mce_tmp', args);
        ed.dom.setAttrib('__mce_tmp', 'id', '');
        ed.undoManager.add();
    }

    dicole_tinymce_toolbar_switch( ed, 'image' );
}

function dicole_tinymce_html_execute( evt, aeid ) {
    if ( evt ) evt.preventDefault();

    var ed = tinyMCE.activeEditor;
    var val = dojo.byId( aeid + '_dicole_html_area' ).value;
    var e = ed.selection.getNode();

    var args = {
        src : '/images/tinymce_embedded_html.gif',
        alt : val,
        'class' : 'dicole_embedded_html'
    };

    if (e && e.nodeName == 'IMG') {
        ed.dom.setAttribs(e, args);
    }
    else {
        ed.execCommand('mceInsertContent', false, '<p class="dicole_embedded_html_container"><img id="__mce_tmp" /></p>', {skip_undo : 1});
        ed.dom.setAttribs('__mce_tmp', args);
        ed.dom.setAttrib('__mce_tmp', 'id', '');
        ed.undoManager.add();
    }

    dicole_tinymce_toolbar_switch( ed, 'html' );
}

function dicole_tinymce_attachment_execute( evt, aeid, dat ) {
    if ( evt ) evt.preventDefault();

    var ed = tinyMCE.activeEditor;
    var e = ed.selection.getNode();
    // insert the new paragraph before current base node
    while ( e && e.parentNode && ( ! ( e.parentNode.nodeName == 'BODY' ) ) && ( ! ( e.parentNode.nodeName == 'HTML' ) ) ) {
       e = e.parentNode;
    }
    if ( e.nodeName == 'BODY' ) e = e.firstChild;

    if ( e ) {
        ed.selection.select( e );
        ed.selection.collapse( true );
    }

    var img_args = {
// these do not work in IE6, converted to use p text-align
//        'align' : 'center',
//        'style' : 'margin: 10px auto; display: block'
    };
    var a_args = {
        'href' : dat.download_url,
        'title' : dat.download_url
    };
    var p_args = {
        style : { 'text-align' : 'center' }
    };
    if ( dat.thumbnail_url ) {
        img_args = tinymce.extend( img_args, {
            'src' : dat.thumbnail_url
        }, img_args );

        ed.execCommand('mceInsertContent', false, '<p id="__mce_tmp_p"><a id="__mce_tmp_a"><img id="__mce_tmp_img" /></a></p>', {skip_undo : 1});
        ed.dom.setAttribs('__mce_tmp_img', img_args);
        ed.dom.setAttrib('__mce_tmp_img', 'id', '');
        ed.dom.setAttribs('__mce_tmp_a', a_args);
        ed.dom.setAttrib('__mce_tmp_a', 'id', '');
        ed.dom.setAttribs('__mce_tmp_p', p_args);
        ed.dom.setAttrib('__mce_tmp_p', 'id', '');
    }
    else {
        img_args = tinymce.extend( img_args, {
            'src' : '/js/generic_attachment.png',
            'class' : 'generic_attachment_png'
        }, img_args );

        ed.execCommand('mceInsertContent', false, '<p id="__mce_tmp_p1"><a id="__mce_tmp_a1"><img id="__mce_tmp_img" /></a></p><p id="__mce_tmp_p2"><a id="__mce_tmp_a2">'+ tinymce.DOM.encode( dat.filename ) +'</a></p>', {skip_undo : 1});
        ed.dom.setAttribs('__mce_tmp_img', img_args);
        ed.dom.setAttrib('__mce_tmp_img', 'id', '');
        ed.dom.setAttribs('__mce_tmp_a1', a_args);
        ed.dom.setAttrib('__mce_tmp_a1', 'id', '');
        ed.dom.setAttribs('__mce_tmp_a2', a_args);
        ed.dom.setAttrib('__mce_tmp_a2', 'id', '');
        ed.dom.setAttribs('__mce_tmp_p1', p_args);
        ed.dom.setAttrib('__mce_tmp_p1', 'id', '');
        ed.dom.setAttribs('__mce_tmp_p2', p_args);
        ed.dom.setAttrib('__mce_tmp_p2', 'id', '');

// run this inside iframe somehow! also in the beginning!
//        tinymce.ScriptLoader.load( '/js/DD_belatedPNG.js' );
//        DD_belatedPNG.fix('.generic_attachment_png');
    }

    var br_tags = ed.dom.select('br');
    dojo.forEach( br_tags, function( br ) {
        if (br.hasAttribute ? br.hasAttribute('mce_bogus') : br.getAttribute('mce_bogus')) {
            ed.dom.remove( br );
        }
    } );

    ed.undoManager.add();

    dicole_tinymce_toolbar_switch( ed, 'attachment' );
}

function dicole_tinymce_link_remove( evt, aeid) {
    if ( evt ) evt.preventDefault();
    var ed = tinyMCE.activeEditor;
    if(bm) ed.selection.moveToBookmark(bm);
    var link_node = ed.dom.getParent(ed.selection.getNode(), 'A');
    if(link_node) {
        tinyMCE.execCommand("mceBeginUndoLevel");
        var b = ed.selection.getBookmark();
        ed.dom.remove(link_node, 1);
        ed.selection.moveToBookmark(b);
        tinyMCE.execCommand("mceEndUndoLevel");
        dicole_tinymce_toolbar_switch( ed, 'link' );
    }
}
function dicole_tinymce_link_execute( evt, aeid, wiki ) {
    return dicole_tinymce_general_link_execute( evt, aeid, wiki ? 'wiki' : 'link', 'link' )

}

function dicole_tinymce_showroom_execute( evt, aeid ) {
    return dicole_tinymce_general_link_execute( evt, aeid, 'show', 'showroom' )
}

function dicole_tinymce_general_link_execute( evt, aeid, type, toolbar ) {
    if ( evt ) evt.preventDefault();

    var ed = tinyMCE.activeEditor;
    if(bm) ed.selection.moveToBookmark(bm);

    var args;
    if ( type == 'wiki' ) {
        var val = dojo.byId( aeid + '_dicole_wiki_name' ).value;
//        var anc = dojo.byId( aeid + '_dicole_wiki_anchor' )
        var anc = '';
        args = { href : '#', title : _encode_wiki_title( val, anc ), 'class' : 'wikiLink' };
    }
    else if ( type == 'show' ) {
        var title = dojo.byId( aeid + '_dicole_showroom_title' ).value;
        var width = dojo.byId( aeid + '_dicole_showroom_width' ).value;
        var height = dojo.byId( aeid + '_dicole_showroom_height' ).value;
        // lo @ tinymce hacks
        var real_val = dojo.byId( aeid + '_dicole_showroom_area' ).value + "";
        var val = real_val.replace(/ (src|href|style|coords|shape)=/gi, function( m, b ) { return ' tinymcehackfix' + b + '='; } );
        var json = dojo.toJson( [ title, width, height, val ] );

        args = { href : '#', title : json, "class" : 'dicole_showroom_link' };
    }
    else {
        val = dojo.byId( aeid + '_dicole_link_href' ).value;
        args = { href : val, title : val };
    }

    var link_node = ed.dom.getParent(ed.selection.getNode(), 'A')

    if ( link_node && ! val ) {
        tinyMCE.execCommand("mceBeginUndoLevel");
        var b = ed.selection.getBookmark();
        ed.dom.remove(link_node, 1);
        ed.selection.moveToBookmark(b);
        tinyMCE.execCommand("mceEndUndoLevel");
        dicole_tinymce_toolbar_switch( ed, toolbar );
        return;
    }

    tinyMCE.execCommand("mceBeginUndoLevel");

    if (link_node) {
        ed.dom.setAttribs(link_node, args);
    }
    else {
        ed.getDoc().execCommand("unlink", false, null);
        tinyMCE.execCommand("CreateLink", false, "#mce_temp_url#", {skip_undo : 1});

        tinymce.each(ed.dom.select("a"), function(n) {
            if (ed.dom.getAttrib(n, 'href') == '#mce_temp_url#') {
                link_node = n;
                ed.dom.setAttribs(link_node, args);
            }
        });
    }

    if (link_node && ( link_node.childNodes.length != 1 || link_node.firstChild.nodeName != 'IMG' )) {
        ed.focus();
        ed.selection.select(link_node);
        ed.selection.collapse(0);
    }

    tinyMCE.execCommand("mceEndUndoLevel");
    dicole_tinymce_toolbar_switch( ed, toolbar );

}

function dicole_tinymce_control_is_active( ed, id ) {
    var ctrl = ed.controlManager.get( id );
    if ( ! ctrl ) return false;
    return ctrl.isActive();
}

function dicole_tinymce_toolbar_switch( ed, id ) {

    var top_level_active = dicole_tinymce_control_is_active( ed, 'dicole_attachment_open' ) ||
            dicole_tinymce_control_is_active( ed, 'dicole_link_open' );

    var button_id = 'dicole_' + id + '_open';
    var control_is_active = dicole_tinymce_control_is_active( ed, button_id );
    if ( control_is_active && ( id != 'advanced' || ! top_level_active ) ) {
        ed.controlManager.setActive( button_id, false );
        if ( id == 'save' || id == 'cancel' ) {
            dicole_tinymce_toolbar_set_main_visibility( ed, true );
        }
    }
    else {
        ed.controlManager.setActive( button_id, true );
        if ( id == 'save' || id == 'cancel' ) {
            dicole_tinymce_toolbar_set_main_visibility( ed, false );
        }
        dojo.forEach( [ 'attachment', 'link', 'embed', 'showroom', 'html', 'image', 'table' ], function( cid ) {
            if ( cid != id ) ed.controlManager.setActive( 'dicole_' + cid + '_open', false );
        } );
    }

    dicole_tinymce_toolbar_set_visibilities( ed );
}

function dicole_tinymce_toolbar_table( ed ) {
    return ( ( ed.id.indexOf('wiki') == 0 ) ? dojo.byId('wiki_toolbar_container_table') : '' )
        || dojo.byId(ed.id + '_tbl');
}

function dicole_tinymce_toolbar_main_visibility( ed ) {
    var main_container = dojo.query('td.tinymce_toolbar_container_main', dicole_tinymce_toolbar_table( ed ) )[0];
    if ( ! main_container ) return false;
    return dojo.hasClass( main_container, 'hiddenBlock' ) ? false : true;
}

function dicole_tinymce_toolbar_set_main_visibility( ed, vis ) {
    var main_container = dojo.query('td.tinymce_toolbar_container_main',  dicole_tinymce_toolbar_table( ed ) )[0];
    if ( ! main_container ) return false;
    if ( vis ) dojo.removeClass( main_container, 'hiddenBlock' );
    else dojo.addClass( main_container, 'hiddenBlock' );
    return vis;
}

var dicole_tinymce_toolbar_imagecontrols_visible = {};

function dicole_tinymce_toolbar_set_imagecontrols_visibility( ed, vis ) {
    if ( dicole_tinymce_toolbar_imagecontrols_visible[ ed.id ] == vis ) return vis;
    var c = dojo.query('td.tinymce_toolbar_container_imagecontrols',  dicole_tinymce_toolbar_table( ed ) )[0];
    if ( ! c ) return false;
    if ( vis ) dojo.removeClass( c, 'hiddenBlock' );
    else dojo.addClass( c, 'hiddenBlock' );
    return dicole_tinymce_toolbar_imagecontrols_visible[ ed.id ] = vis;
}

function dicole_tinymce_set_editor_overlay( ed, is_on ) {
    var overlay_node = dojo.byId(ed.id + '_overlay');
    var ifr = dojo.byId(ed.id + '_ifr');

    if ( ! overlay_node ) {
        overlay_node = dojo.create('a', {
            id : ed.id + '_overlay',
            onclick : function( evt ) { evt.preventDefault(); },
            style : {
                display : 'none',
                position: 'absolute',
                opacity : '0.75',
                'background': 'gray',
                'zIndex' : '2'
            }
        }, ifr, 'before' );

//        ed.onRemove.add( function( ed ) {
//            if ( overlay_node ) dojo.destroy( overlay_node );
//        });
    }

    if ( ! is_on ) {
        overlay_node.style.display = 'none';
    }
    else {
        var coords = dojo.coords( ifr, true );

        var pr = dojo.byId(ed.id + '_path_row');
        var prh = pr ? dojo.coords( pr, true ).h : 0;

        overlay_node.style.width = ( coords.w ) + 'px';
        overlay_node.style.height = ( coords.h + prh + 2 ) + 'px';
        overlay_node.style.display = 'block';
    }
}

function show_td_container( container ) {
    container.style.display = 'table-cell';
}

function hide_td_container( container ) {
    container.style.display = 'none';
}

function dicole_tinymce_toolbar_set_visibilities( ed ) {
    var main_is_active = dicole_tinymce_toolbar_main_visibility( ed );
    var advanced_active = dicole_tinymce_control_is_active( ed, 'dicole_advanced_open' );
    var top_level_active = dicole_tinymce_control_is_active( ed, 'dicole_attachment_open' ) ||
        dicole_tinymce_control_is_active( ed, 'dicole_link_open' );

    dicole_tinymce_set_editor_overlay( ed, 0 );

    dojo.query('.tinymce_toolbar_container', dicole_tinymce_toolbar_table( ed ) ).forEach( function( container ) {
        if ( dojo.hasClass(container, 'tinymce_toolbar_container_main') ) return;
        if ( dojo.hasClass(container, 'tinymce_toolbar_container_imagecontrols') ) return;

        var processed = 0;

        dojo.forEach( [ 'save', 'cancel', 'attachment', 'link', 'embed', 'html', 'showroom', 'image', 'table' ], function( cid ) {
            if ( ! dojo.hasClass(container, 'tinymce_toolbar_container_' + cid ) ) return;

            if ( ( ( cid == 'save' || cid == 'cancel' ) || ( main_is_active && ( cid == 'attachment' || cid == 'link' || advanced_active ) ) ) && dicole_tinymce_control_is_active( ed, 'dicole_'+ cid +'_open' ) ) {
                dojo.removeClass( container, 'hiddenBlock' );
                show_td_container( container );
                if ( cid != 'table' ) {
                    dicole_tinymce_set_editor_overlay( ed, 1 );
                }
            }
            else {
                dojo.addClass( container, 'hiddenBlock' );
                hide_td_container( container );
            }

//             if ( cid == 'attachment' ) {
//                 try { dijit.byId( ed.id + '_attachment_upload_uploader' ).setFlashPosition() } catch ( e ) {}
//             }

            processed = 1;
        } );

        if ( processed ) return;

        if ( dojo.hasClass(container, 'tinymce_toolbar_container_wikicontrols') ) {
            if ( ! main_is_active ) {
                dojo.addClass( container, 'hiddenBlock' );
                hide_td_container( container );
            }
            else {
                dojo.removeClass( container, 'hiddenBlock' );
                show_td_container( container );
            }

            return;
        }

        if ( dojo.hasClass(container, 'tinymce_toolbar_container_advanced') ) {
            if ( ! main_is_active || top_level_active || ! advanced_active ) {
                dojo.addClass( container, 'hiddenBlock' );
                hide_td_container( container );
            }
            else {
                dojo.removeClass( container, 'hiddenBlock' );
                show_td_container( container );
            }

            return;
        }

        dojo.removeClass( container, 'hiddenBlock' );
        show_td_container( container );
    } );

}

function dicole_tinymce_annotation_remove(ed) {
	var annotation = ed.dom.getParent(ed.selection.getNode(), 'span.wiki_anno.wiki_anno_begin.wiki_anno_end');
	if(annotation) {
		ed.selection.select(annotation);
		ed.selection.setContent(annotation.innerHTML);
	}
}
