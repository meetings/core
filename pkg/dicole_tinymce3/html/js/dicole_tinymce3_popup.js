dojo.addOnLoad( function() { process_tinymce3_popups(); } );


function process_tinymce3_popups() {
    process_tinymce3_popup_closes();
    process_tinymce3_html_popup();
    process_tinymce3_image_popup();
    process_tinymce3_link_popup();
}

function process_tinymce3_popup_closes() {
    dojo.query('.tinymce3_cancel_popup').forEach( function ( node ) {
        dojo.connect( node, 'onclick', function( evt ) {
            evt.preventDefault();
            tinyMCEPopup.close();
        } );
    } );
}

function process_tinymce3_html_popup() {
    if ( ! dojo.byId( 'embedded_html' ) ) { return; }
    var f = document.forms[0], ed = tinyMCEPopup.editor;

    var e = ed.selection.getNode();

    if (e.nodeName == 'IMG') {
        f.embedded_html.value = ed.dom.getAttrib(e, 'alt');
    }

    dojo.query('.tinymce3_execute_html_popup').forEach( function ( node ) {
        dojo.connect( node, 'onclick', function( evt ) {
            evt.preventDefault();
            tinyMCEPopup.restoreSelection();

            var args = {
                src : '/images/tinymce_embedded_html.gif',
                alt : f.embedded_html.value,
                'class' : 'dicole_embedded_html'
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

            tinyMCEPopup.close();
        } );
    } );

}

function process_tinymce3_image_popup() {
    if ( ! dojo.byId( 'image_url_input' ) ) { return; }
    var f = document.forms[0], ed = tinyMCEPopup.editor;

    var e = ed.selection.getNode();

    if (e.nodeName == 'IMG') {
        f.image_url.value = ed.dom.getAttrib(e, 'src');
        f.image_alt.value = ed.dom.getAttrib(e, 'alt');
        selectByValue(f, 'image_align', ed.dom.getAttrib(e, 'align'));
    }

    dojo.query('.tinymce3_execute_image_popup').forEach( function ( node ) {
        dojo.connect( node, 'onclick', function( evt ) {
            evt.preventDefault();
            tinyMCEPopup.restoreSelection();

            var args = {
                src : f.image_url.value,
                alt : f.image_alt.value,
                align : getSelectValue(f, 'image_align')
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

            tinyMCEPopup.close();
        } );
    } );

}

function process_tinymce3_link_popup() {
    if ( ! dojo.byId( 'link_url_input' ) ) { return; }
    var f = document.forms[0], ed = tinyMCEPopup.editor, e;

   if (e = ed.dom.getParent(ed.selection.getNode(), 'A')) {
        f.link_url.value = ed.dom.getAttrib(e, 'href');
    }
    else {
        var sel = ed.selection.getContent({format : 'text'});
        if ( sel.indexOf('http') == 0 ) {
            f.link_url.value = sel;
        }
        else {
            f.link_url.value = '';
        }
    }

    dojo.query('.tinymce3_execute_link_popup').forEach( function ( node ) {
        dojo.connect( node, 'onclick', function( evt ) {
            evt.preventDefault();
            tinyMCEPopup.restoreSelection();

            var args = {
                href : f.link_url.value,
                title : f.link_url.value
            };

            if ( e && ! f.link_url.value ) {
                tinyMCEPopup.execCommand("mceBeginUndoLevel");
                b = ed.selection.getBookmark();
                ed.dom.remove(e, 1);
                ed.selection.moveToBookmark(b);
                tinyMCEPopup.execCommand("mceEndUndoLevel");
                tinyMCEPopup.close();
                return;
            }

            tinyMCEPopup.execCommand("mceBeginUndoLevel");

            if (e) {
                ed.dom.setAttribs(e, args);
            }
            else {
                ed.getDoc().execCommand("unlink", false, null);
                tinyMCEPopup.execCommand("CreateLink", false, "#mce_temp_url#", {skip_undo : 1});

                tinymce.each(ed.dom.select("a"), function(n) {
                    if (ed.dom.getAttrib(n, 'href') == '#mce_temp_url#') {
                        e = n;
                        ed.dom.setAttribs(e, args);
                    }
                });
            }

            if (e.childNodes.length != 1 || e.firstChild.nodeName != 'IMG') {
                ed.focus();
                ed.selection.select(e);
                ed.selection.collapse(0);
                tinyMCEPopup.storeSelection();
            }

            tinyMCEPopup.execCommand("mceEndUndoLevel");
            tinyMCEPopup.close();
        } );
    } );

}
