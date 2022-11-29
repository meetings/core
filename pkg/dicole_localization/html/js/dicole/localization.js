dojo.provide('dicole.localization');

dojo.require('dicole.base');

dojo.addOnLoad( function() {
    dojo.query('.js-localization-row').forEach( function( container ) {
        dicole.localization.update_text_cache( container );
        dicole.localization.rows.push( container );
    } );
    dojo.query('#js-localization-filter-input').forEach( function( node ) {
        dojo.connect( node, 'onkeypress', function( evt ) {
            if ( evt.keyCode == dojo.keys.ENTER ) {
                dojo.stopEvent( evt );
                dicole.localization.filter( node.value );
            }
            else {
                dicole.localization.track_filter( node, node.value, 0, 0 );
            }
        } );
        dicole.localization.filter( node.value );
    } );
} );

dicole.localization.rows = [];
dicole.localization.current_show_container = false;
dicole.localization.last_filter_text = '---not';

dicole.localization.show_row = function( container ) {
    dicole.localization.connect_row_events( container );
    dojo.style( container, 'display', 'hidden');
    dojo.place( container, dicole.localization.current_show_container );
//    dojo.fadeIn( { node : container, duration: 200 } ).play();
    dojo.style( container, 'display', 'block');
};

dicole.localization.hide_row = function( container ) {
    dojo.style( container, 'display', 'none');
};

dicole.localization.connect_row_events = function( container ) {
    if ( dojo.hasClass( container, 'js-row-events-connected') ) { return; }
    dojo.addClass( container, 'js-row-events-connected');

    dojo.query('.js-localization-save', container ).forEach( function( node ) {
        dojo.connect( node, 'onclick', function( evt ) {
            dojo.stopEvent( evt );
            dicole.localization.update( node );
        } );
    } );
    dojo.query('.js-localization-input', container ).forEach( function( node ) {
        dojo.connect( node, 'onkeypress', function( evt ) {
            if ( evt.keyCode == dojo.keys.ENTER ) {
                dojo.stopEvent( evt );
                dicole.localization.update( node );
            }
        } );
    } );
};

dicole.localization.begin_async_filter = function( txt ) {
    if ( dicole.localization.last_filter_text == txt ) { return; }
    dicole.localization.last_filter_text = txt;

    if ( dicole.localization.current_show_container ) {
        dojo.style( dicole.localization.current_show_container, 'display', 'none' );
    }
    dicole.localization.current_show_container = dojo.create('div', {}, dojo.byId('js-search-containers'), 'first');
    dicole.localization.async_filter( txt, 0 );
};

dicole.localization.async_filter = function( txt, idx ) {
    if ( dicole.localization.last_filter_text != txt ) { return; }

    txt = txt.toLowerCase();

    var at_a_time = 10;
    for ( x = 0; x < at_a_time; x++ ) {
        var container = dicole.localization.rows[ idx + x ];
        if ( ! container ) return;
        if ( ! txt || dojo.attr( container, '_text_cache' ).indexOf( txt ) != -1 ) {
            dicole.localization.show_row( container );
        }
        else {
            dicole.localization.hide_row( container );
        }
    }

    setTimeout( dojo.hitch( null, dicole.localization.async_filter, txt, idx + at_a_time ), 10 );
};

dicole.localization.filter = function( txt ) {
    return dicole.localization.begin_async_filter( txt );

    if ( dicole.localization.last_filter_text == txt ) { return; }
    dicole.localization.last_filter_text = txt;

    dojo.query('.js-localization-row-shown').forEach( function( container ) {
        dojo.style( container, 'display', 'none');
        dojo.removeClass( container, 'js-localization-row-shown' );
    } );

    if ( txt && txt.length > 2 ) {
        dojo.query('.js-localization-labels').forEach( function( labels ) {
            dojo.style( labels, 'display', 'block' );
        } );
        dojo.query('.js-localization-row').forEach( function( container ) {
            if ( dojo.attr( container, '_text_cache' ).indexOf( txt.toLowerCase() ) != -1 ) {
                dojo.addClass( container, 'js-localization-row-shown' );
                dojo.style( container, 'display', 'block');
            }
        } );
    }
    else {
        dojo.query('.js-localization-labels').forEach( function( labels ) {
            dojo.style( labels, 'display', 'none' );
        } );
    }
};

dicole.localization.track_filter = function( node, txt, txt_count, count ) {
    if ( txt_count > 10 || count > 1 ) { return; }
    if ( txt == node.value ) {
        if ( txt_count == 0 ) { dicole.localization.filter( txt ) };
        setTimeout( dojo.hitch( this, dicole.localization.track_filter, node, txt, txt_count + 1, count ), 50 );
    }
    else {
        setTimeout( dojo.hitch( this, dicole.localization.track_filter, node, node.value, 0, count + 1 ), 50 );
    }
};

dicole.localization.update_text_cache = function( container ) {
    while ( container && ! dojo.hasClass( container, 'js-localization-row') ) {
        container = container.parentNode;
    }
    if ( ! container ) { return; }

    var string = '';
    dojo.query('.js-localization-key', container ).forEach( function( n ) {
        string = ( ( n.innerText ) ? n.innerText : ( n.textContent ) ? n.textContent : '' );
    } );
    dojo.query('.js-localization-default', container ).forEach( function( n ) {
        string = string + '----' + ( ( n.innerText ) ? n.innerText : ( n.textContent ) ? n.textContent : '' );
    } );
    dojo.query('.js-localization-input', container ).forEach( function( n ) {
        string = string + '----' + n.value;
    } );

    dojo.attr( container, '_text_cache', string.toLowerCase() );
};

dicole.localization.update = function( node ) {
    var update_url_node = dojo.query('#js-localization-update-url')[0];
    var input_node = dojo.query('.js-localization-input', node.parentNode )[0];
    var save_node = dojo.query('.js-localization-save', node.parentNode )[0];
    if ( update_url_node && input_node && save_node ) {
        dojo.attr( input_node, 'readonly', "true" );
        dojo.xhrPost( {
            url : update_url_node.href,
            content : {
                'key' : save_node.title,
                'value' : input_node.value
            },
            handleAs : 'json',
            load : function( data ) {
                input_node.value = data.result;
                input_node.removeAttribute('readonly');
                dicole.localization.update_text_cache( node );
            },
            error : function( data ) {
                alert("Unknown error. Try again.");
                input_node.removeAttribute('readonly');
            }
        } );
    }
};
