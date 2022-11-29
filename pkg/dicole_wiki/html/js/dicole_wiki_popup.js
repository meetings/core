var current_select_id = 0;

function execute_popup() {
    var f = document.forms[0], ed = tinyMCEPopup.editor, e;

    var title = _encode_wiki_title(
        f.page.value,
        f.header.value
    );
    var href = '#';

    tinyMCEPopup.restoreSelection();

    var args = {
        href : href,
        title : title,
        'class' : 'wikiLink'
    };

    e = ed.dom.getParent(ed.selection.getNode(), 'A');

    if ( e && ! title ) {
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
    ed.dom.win.dicole_tinymce_toolbar_switch(ed, 'link');
}

function cancel_popup() {
    tinyMCEPopup.close();
}

function set_title_value( title_value ) {
    var parts = _decode_wiki_title( title_value );
    if ( document.forms[0].page.value != parts[0] ) {
        document.forms[0].page.value = parts[0];
        update_anchors( parts );
    }
}

function update_anchors( parts ) {
    var title = parts[0];
    var anchor = parts[1];

    if ( title ) {
        var t1 = page_input_last_fetched;
        var t2 = title + '';
        if ( t1.toLowerCase() == t2.toLowerCase() ) return;
    }

    var sel = document.forms[0].header;
    sel.options.length = 1;
    sel.disabled = true;

    var found = 0;
    for ( var i in action_data ) {
        var t1 = action_data[i].title + '';
        var t2 = title + '';
        if ( t1.toLowerCase() == t2.toLowerCase() ) found = 1;
    }
    if (found == 0) return;

    page_input_last_fetched = title + '';

    dojo.xhrPost({
        url : select_page_data.page_anchors_url,
        content : { title : title },
        handleAs : 'json',
        load : function ( data ) {
            if ( data.anchors ) {
                for (var i=0; i < data.anchors.length; i++) {
                    var a = data.anchors[i];
                    var text = a.numbers.join('.') + '. ' + a.text;
                    sel.options[i+1] = new Option(text, a.anchor);
                    if ( a.anchor == anchor ) sel.options[i+1].selected = true;
                }
                sel.disabled = false;
            }

        },
        error : function () {}
    });
}

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

function _control_init() {  
    dojo.connect( dojo.byId('latest_bar'), 'onclick',
        function(e) {
            e.preventDefault();
            _set_latest_actions();
        }
    );
    dojo.connect( dojo.byId('alphabetic_bar'), 'onclick',
        function(e) {
            e.preventDefault();
            _set_alphabetic_actions();
        }
    );
    dojo.connect( dojo.byId('page_input'), 'onblur',
        function(e) {
            update_anchors( [ document.forms[0].page.value, false ] );
        }
    );

    _page_input_loop();

    _set_latest_actions();
}

var page_input_last_fetched = '';
var page_input_last = '';
var page_input_count = 0;

function _page_input_loop() {
    var t1 = document.forms[0].page.value + '';
    var t2 = page_input_last;
    if ( t1.toLowerCase() == t2.toLowerCase() ) {
        page_input_count++;
        if ( page_input_count == 3 ) {
            update_anchors( [ page_input_last, false ] );
        }
    }
    else {
        page_input_last = t1;
        page_input_count = 1;
    }

    setTimeout( _page_input_loop, 500 );
}

function _set_alphabetic_actions() {
    var array = select_page_data.action_data.sort(
        function(a,b) {
            var aa = a.title;
            var bb = b.title;
            if (aa) aa = aa.toLowerCase();
            if (bb) bb = bb.toLowerCase();
            return (aa == bb) ? 0 : ((aa < bb) ? -1 : 1);
        }
    );

    _set_actions( array );
}

function _set_latest_actions() {
    var array = select_page_data.action_data.sort(
        function(a,b) { return b.modified - a.modified; }
    );
    _set_actions( array );
}

function _set_actions() {
    var container = dojo.byId('title_select_container');
    if ( !container ) return false;
    container.innerHTML = '';
    for (var i in select_page_data.action_data ) {
        var title = select_page_data.action_data[i].title;
        var id = select_page_data.action_data[i].id;
        var alink = document.createElement('a');
        alink.innerHTML = title;
        dojo.addClass(alink, 'wiki_title_select');
        alink.setAttribute( 'href', '#');
        _add_title_selector_events( alink, title, id );
        dojo.place(alink, container, 'last');
    }
}

// separate function because javascript does not have block scope
// and thus continuations in a for loop would not work as expected
function _add_title_selector_events( alink, title, id ) {
    dojo.connect(alink, "onclick", function(e){
        e.preventDefault();
        if ( current_select_id == id ) {
            execute_popup();
        }
        else {
            set_title_value( title );
            current_select_id = id;
        }
    });
}

function wiki_popup_init() {
    var f = document.forms[0], ed = tinyMCEPopup.editor, e;

    if (e = ed.dom.getParent(ed.selection.getNode(), 'A')) {
        var title = ed.dom.getAttrib(e, 'title');
        set_title_value( title );
    }
    else {
        var title = ed.selection.getContent({format : 'text'});
        set_title_value( title );
    }

   _control_init();
}
