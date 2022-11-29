dojo.provide( 'dicole.tags.TagBrowser2' );

dojo.declare( 'dicole.tags.TagBrowser2', null, {
    constructor : function( filter_container_id, selected_line_container_id, selected_tags_container_id, tags_container_id, results_container_id, filter_nodelist, filter_more_nodelist, show_more_nodelist, results_count_nodelist, keyword_change_url, more_results_url, initial_state, end_of_pages, filter_autofill_id, show_more_filter_nodelist ) {

        this.filter_container = dojo.byId( filter_container_id );
        this.selected_line_container = dojo.byId( selected_line_container_id );
        this.selected_tags_container = dojo.byId( selected_tags_container_id );
        this.tags_container = dojo.byId( tags_container_id );
        this.results_container = dojo.byId( results_container_id );
        this.keyword_change_url = keyword_change_url;
        this.more_results_url = more_results_url;
        this.filter_nodelist = filter_nodelist;
        this.filter_more_nodelist = filter_more_nodelist;
        this.show_more_nodelist = show_more_nodelist;
        this.results_count_nodelist = results_count_nodelist;
        this.filter_autofill_id = filter_autofill_id;
        this.show_more_filter_nodelist = show_more_filter_nodelist;

        this.current_state = '';
        this.tags = [];
        this.filter_open = false;
        this.filter_more_open = false;

        this.show_more_nodelist.forEach( function( more_node ) {
            dojo.connect( more_node, 'onclick', this, function( event ) {
                dojo.stopEvent( event );
                this.on_more();
            } );
        }, this );

        this.filter_nodelist.forEach( function( node ) {
            dojo.connect( node, 'onclick', this, function( event ) {
                dojo.stopEvent( event );
                if ( this.filter_open ) {
                    this.tags = [];
                    this.on_change();
                }
                else {
                    this.set_filter_visibility( true );
                }
            } );
        }, this );

        this.filter_more_nodelist.forEach( function( node ) {
            dojo.connect( node, 'onclick', this, function( event ) {
                dojo.stopEvent( event );
                this.set_filter_more_visibility( this.filter_more_open ? false : true );
            } );
        }, this );

        if ( this.show_more_filter_nodelist ) {
            this.show_more_filter_nodelist.forEach( function( node ) {
                dojo.connect( node, 'onclick', this, function( event ) {
                    dojo.stopEvent( event );
                    this.set_filter_visibility( true );
                    this.set_filter_more_visibility( true );
                    dojo.window.scrollIntoView( this.filter_container );
                } );
            }, this );
        }

        if ( this.filter_autofill_id ) {
            dicole_autofiller_add_event( this.filter_autofill_id, 'on_select', dojo.hitch( this, function( id, tag, val ) {
               this.add_tag( tag.name );
            } ) );
            dicole_autofiller_add_event( this.filter_autofill_id, 'on_go', dojo.hitch( this, function( id, val ) {
               this.add_tag( val );
            } ) );
        }

        this.init_from_html( initial_state, end_of_pages );
    },

    init_from_html : function( state, end_of_pages ) {
        this.process_selected_tags( this.selected_tags_container );
        this.process_tags( this.tags_container );

        if  ( this.tags.length > 0 ) {
            dojo.style( this.selected_line_container, 'display', 'block' );
            this.set_filter_visibility( true );
            this.set_filter_more_visibility( false );
        }
        else {
            dojo.style( this.selected_line_container, 'display', 'none' );
            this.set_filter_visibility( false );
            this.set_filter_more_visibility( true );
        }

        this.current_state = state;
        this._set_more_button_visibility_by_end_of_pages( end_of_pages );
    },

    set_filter_visibility : function( is_visible ) {
        this.filter_open = is_visible;
        dojo.style( this.filter_container, 'display', is_visible ? 'block' : 'none' );
        // i think button openness is better handled with a class
        this.filter_nodelist.forEach( function( node ) {
            dojo.addClass( node, is_visible ? 'filter_open' : 'filter_closed' );
            dojo.removeClass( node, ( ! is_visible ) ? 'filter_open' : 'filter_closed' );
        } );
        this.update_show_more_filter_visibility();
    },

    set_filter_more_visibility : function( is_visible ) {
        this.filter_more_open = is_visible;
        dojo.style( this.tags_container, 'display', is_visible ? 'block' : 'none' );
        // i think button openness is better handled with a class
        this.filter_more_nodelist.forEach( function( node ) {
            dojo.addClass( node, is_visible ? 'filter_more_open' : 'filter_more_closed' );
            dojo.removeClass( node, ( ! is_visible ) ? 'filter_more_open' : 'filter_more_closed' );
        } );
        this.update_show_more_filter_visibility();
    },

    update_show_more_filter_visibility : function() {
        if ( this.show_more_filter_nodelist ) {
            var is_visible = ( this.filter_more_open && this.filter_open ) ? false : true;
            this.show_more_filter_nodelist.forEach( function( node ) {
                dojo.addClass( node, is_visible ? 'show_more_filter_open' : 'show_more_filter_closed' );
                dojo.removeClass( node, ( ! is_visible ) ? 'show_more_filter_open' : 'show_more_filter_closed' );
            } );
        }
    },

    _set_more_button_visibility_by_end_of_pages : function( end_of_pages ) {
        this.show_more_nodelist.forEach( function ( more_node ) {
            dojo.style( more_node, 'display', end_of_pages ? 'none' : 'inline' );
        }, this );
    },

    remove_tag : function( tag ) {
        var new_tags = [];
        dojo.forEach( this.tags, function ( old_tag ) {
            if ( tag != old_tag ) {
                new_tags.push( old_tag );
            }
        }, this );
        this.tags = new_tags;
        this.on_change();
    },

    add_tag : function( tag ) {
        this.tags.push( tag );
        this.on_change();
    },

    on_change : function() {
        dojo.xhrPost( {
            url : this.keyword_change_url,
            handleAs : 'json',
            content : { selected_keywords : dojo.toJson( this.tags ), state : this.current_state },
            load : dojo.hitch( this, function( data ) {
                this.results_container.innerHTML = data.results_html;
                this.tags_container.innerHTML = data.tags_html;
                this.selected_tags_container.innerHTML = data.selected_tags_html;
                this.results_count_nodelist.forEach( function( count_node ) {
                    count_node.innerHTML = data.result_count_html;
                } );

                dicole.process_new_node( this.results_container );
                dicole.process_new_node( this.tags_container );
                dicole.process_new_node( this.selected_tags_container );
                
                this.init_from_html( data.state, data.end_of_pages );
            } )
        } );
    },

    on_more : function() {
        dojo.xhrPost( {
            url : this.more_results_url,
            handleAs : 'json',
            content : { state : this.current_state },
            load : dojo.hitch( this, function( data ) {
                this._set_more_button_visibility_by_end_of_pages( data.end_of_pages );

                // Do this using a temp container because += for innterHTML caused
                // the nodes to be generated again with their _processed classes intact
                // and thus they did not get processed again.

                var new_nodes = dojo.create( "div", { innerHTML : data.results_html }, this.results_container );

                // I tried to move these nodes fro this temp dir to the end of the
                // results container but just got random errors :/

                dicole.process_new_node( new_nodes );
                this.current_state = data.state;
            } )
        } );
    },

    process_selected_tags : function( container ) {
        this.tags = [];
        dojo.query('a.tag', container ).forEach( function( tag_node ) {
            var tag_name = this._name_from_tag_node( tag_node );
            this.tags.push( tag_name );
            dojo.connect( tag_node, 'onclick', this, function( evt ) {
                dojo.stopEvent( evt );
                this.remove_tag( tag_name );
            } );
        }, this );
    },

    process_tags : function( container ) {
        dojo.query('a.tag', container ).forEach( function( tag_node ) {
            dojo.connect( tag_node, 'onclick', this, function( evt ) {
                dojo.stopEvent( evt );
                this.add_tag( this._name_from_tag_node( tag_node ) );
            } );
        }, this );
    },

    _name_from_tag_node : function( tag_node ) {
        return dojo.attr( tag_node, 'title' ) ? dojo.attr( tag_node, 'title' ) : tag_node.innerHTML;
    }
} );
