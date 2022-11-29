dojo.provide("dicole.development");

dojo.addOnLoad( function() {
    dicole.development.refresh_preview( 1 );
} );

dicole.development.last_mail_content = '';
dicole.development.last_mail_content_changed = 0;
dicole.development.last_mail_content_sent = false;

dicole.development.current_preview = '';

dicole.development.refresh_preview = function( init ) {
    var container = dojo.byId('preview-container');
    if ( ! container ) { return; }
    var content_id = dojo.attr( container, 'data-content-id' );
    var content = dojo.byId( content_id ).value;
    if ( init ) {
        dicole.development.last_mail_content = content;        
    }
    else if ( content != dicole.development.last_mail_content ) {
        dicole.development.last_mail_content = content;
        dicole.development.last_mail_content_changed = new Date().getTime();
        dicole.development.last_mail_content_sent = false;
        setTimeout( function() { dicole.development.refresh_preview(); }, 100 );
        return;
    }
    else if ( dicole.development.last_mail_content_sent || new Date().getTime() < dicole.development.last_mail_content_changed + 2000 ) {
        setTimeout( function() { dicole.development.refresh_preview(); }, 100 );
        return;        
    }

    dicole.development.last_mail_content_sent = true;

    dojo.xhrPost( {
        url : dojo.attr( container, 'data-url' ),
        handleAs : 'json',
        content : {
            content : content,
            base : dojo.attr( container, 'data-base' ),
            type : dojo.attr( container, 'data-type' ),
            lang : dojo.attr( container, 'data-lang' )
        },
        load : function ( response ) {
            container.innerHTML = response.result.html;
            dicole.development.init_preview();
        }
    } );

    setTimeout( function() { dicole.development.refresh_preview(); }, 100 );
};

dicole.development.init_preview = function() {
    if ( ! dojo.byId( dicole.development.current_preview + '_container' ) ) {
        dicole.development.current_preview = '';
    }
    dojo.query('.preview_link').forEach( function( preview_link ) {
        if ( ! dicole.development.current_preview ) {
            dicole.development.current_preview = preview_link.id;
        }
        dojo.connect( preview_link, 'onclick', function( evt ) {
            dojo.stopEvent( evt );
            dicole.development.current_preview = preview_link.id;
            dicole.development.show_preview_container();
        } );
    } );
    dicole.development.show_preview_container();
};

dicole.development.show_preview_container = function() {
    dojo.query('.preview_link').forEach( function( preview_link ) {
        dojo.style( preview_link, { textDecoration : 'none' } );
        if ( dojo.attr( preview_link, 'id' ) == dicole.development.current_preview ) {
            dojo.style( preview_link, { textDecoration : 'underline' } );
        }
    } );
    dojo.query('.preview_container').forEach( function( preview ) {
        dojo.style( preview, { display : 'none' } );
        if ( dojo.attr( preview, 'id' ) == dicole.development.current_preview + '_container' ) {
            dojo.style( preview, { display : 'block' } );
        }
    } );
};
