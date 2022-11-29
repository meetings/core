dojo.provide('dicole.tags');

// Commented out because it added 100kb of dijit stuff (even after compressing)
//dojo.require('dicole.tags.Slider');

//var dicole_sliders = {};
//var dicole_slider_count = 0;

// Our array of slider controls
//var dicole_sliders = {};

//function addSlider( slider_container ) {
//	var slider_control = new dicole.tags.Slider(slider_container);
//
//	dicole_sliders[ dicole_slider_count ] = slider_control;
//	dicole_sliders[ dicole_slider_count ].init();
//	dicole_slider_count++;
//}

//dojo.subscribe( 'new_node_created', function( node ) {
//	// Get all the slider controllers
//	dojo.query('.slider_container').forEach(
//		function ( control ) {
//			// Check if already processed the sliders on this page
//			if ( dojo.hasClass( control, 'slider_processed' ) ) 
//			{
//				return;
//			}
//			// Mark that processing is done
//			dojo.addClass( control, 'slider_processed' );
//	
//			// Get the slider container inside the slider_control
//			// There's only one, but we use forEach
//			dojo.query('.slider_control', control).forEach(
//				function (container)
//				{
//					addSlider(container);
//				}
//			);
//		}
//	);
//});

dojo.subscribe('new_node_created', function(node) {
	process_tag_controls();
});

var dicole_tag_controls = {};

function DicoleTagControl( id ) {
    this.id = id;
    this.data_input = dojo.byId( 'tag_data_' + id );
    this.old_data_input = dojo.byId( 'tag_data_old_' + id );
    this.list = dojo.byId( 'tag_list_' + id );
    this.add_link = dojo.byId( 'tag_add_link_' + id );
    this.add_input_submit = dojo.byId( 'tag_add_input_submit_' + id );
    this.add_input_field = dojo.byId( 'tag_add_input_field_' + id );

    this.init = function() {
        this.current_data = this.data_input_value( this.data_input );
        this.current_data_keys = this.data_to_keys( this.current_data );
        this.old_data = this.data_input_value( this.old_data_input );
        this.old_data_keys = this.data_to_keys( this.old_data );
        this.visible_tags = {};
        

        this.update_tag_list();
        this.update_tag_suggestions();
        
        if ( this.add_link ) {
            dojo.connect( this.add_link, 'onclick', function( evt ) {
                evt.preventDefault();
                var link_container = dojo.byId( 'tag_add_link_container_' + id );
                var input_container = dojo.byId( 'tag_add_input_container_' + id );
                if ( link_container ) link_container.style.display = 'none';
                if ( input_container ) input_container.style.display = 'block';
            } );
        }
        if ( this.add_input_submit ) {
            dojo.connect( this.add_input_submit, 'onclick', function( evt ) {
                evt.preventDefault();
                var add_input_field = dojo.byId( 'tag_add_input_field_' + id );
                if ( add_input_field ) {
                    dicole_tag_controls[ id ].add_tag_string(
                        add_input_field.value
                    );
                    add_input_field.value = '';
                    add_input_field.focus();
                }
            } );
        }
        if ( this.add_input_field ) {
            dojo.connect( this.add_input_field, 'onkeypress', function( evt ) { 
                var key = evt.keyCode || evt.charCode;
                if ( key != dojo.keys.ENTER ) return;
                evt.preventDefault();
                var add_input_field = dojo.byId( 'tag_add_input_field_' + id );
                if ( add_input_field ) {
                    dicole_tag_controls[ id ].add_tag_string(
                        add_input_field.value
                    );
                    add_input_field.value = '';
                }
            } );
        }
    }

    this.update_input_value = function() {
        this.data_input_value( this.data_input, this.current_data, 1 );
    };

    this.update_tag_list = function() {
        var reorder_tags = 0;
        // loop supposed tags to add yet nonexisting
        dojo.forEach(this.current_data, function(tag) {
            var element = this.visible_tags[ tag ];
            if ( ! element ) {
                element = this.create_tag( tag );
                this.visible_tags[ tag ] = element;
                reorder_tags = 1;
            }
            if ( dojo.hasClass( element, 'tag_deleted' ) ) {
                dojo.removeClass( element, 'tag_deleted' );
            }
            if ( ! this.old_data_keys[ tag ] ) {
                if ( ! dojo.hasClass( element, 'tag_added' ) ) {
                    dojo.addClass( element, 'tag_added' );
                }
            }
        }, this);
        // loop old list to add nonexisting overcrossed
        dojo.forEach(this.old_data, function(tag) {
            if ( this.current_data_keys[ tag ] ) return;
            var element = this.visible_tags[ tag ];
            if ( ! element ) {
                element = this.create_tag( tag );
                this.visible_tags[ tag ] = element;
                reorder_tags = 1;
            }
            if ( ! dojo.hasClass( element, 'tag_deleted' ) ) {
                dojo.addClass( element, 'tag_deleted' );
            }
        }, this);
        // loop existing tags to remove removed
        for ( var tag in this.visible_tags ) {
            if ( this.current_data_keys[ tag ] ) continue;
            if ( this.old_data_keys[ tag ] ) continue;
            delete this.visible_tags[ tag ];
            reorder_tags = 1;
        }

        if ( reorder_tags ) {
            // remove all content and add visible in order
            if ( this.list.hasChildNodes() ) {
                while ( this.list.childNodes.length >= 1 )
                    this.list.removeChild( this.list.firstChild );
            }

            var keys = new Array();
            for(var key in this.visible_tags) { keys.push( key ); }
            keys.sort();

            var first = 1;
            dojo.forEach(keys, function(asdfasdf, i) {
                if ( first ) first = 0;
                else if ( ! dojo.hasClass( this.list, 'js-disable-commas') ) {
                    this.list.appendChild( document.createTextNode( ", " ) );
                }
                this.list.appendChild( this.visible_tags[ keys[i] ] );
            }, this);
        }

    };
    
    this.create_tag = function( tag ) {
    	var element = dojo.create('a', {'class': 'tag', 'innerHTML': dicole.encode_html( tag )})
        dojo.connect( element, 'onclick', function( evt ) {
            evt.preventDefault();
            dicole_tag_controls[ id ].toggle_tag( tag );
        } );
        return element;
    };

    this.update_tag_suggestions = function() {
        var suggestions = dojo.query('.tag_suggestions_' + id );
	for(var i = 0; i < suggestions.length; ++i)
	{
            this.update_tag_suggestions_rec( suggestions[i] );
        }
    };

    this.update_tag_suggestions_rec = function( element ) {
        if ( dojo.hasClass( element, 'tag_suggestion') ) {
            var text = element.innerText || element.textContent;
            text = this.prepare_tag( text );
            
            if ( this.current_data_keys[ text ] ) {
                if ( ! dojo.hasClass( element, 'tag_selected' ) )
                    dojo.addClass( element, 'tag_selected' );
            }
            else {
                if ( dojo.hasClass( element, 'tag_selected' ) ) {
                    dojo.removeClass( element, 'tag_selected' );
                }
            }
            
            if ( dojo.hasClass( element, 'tag_suggestion_connected' ) )
                return false;

            dojo.addClass( element, 'tag_suggestion_connected' );
            dojo.connect( element, 'onclick', function( evt ) {
                evt.preventDefault();
                dicole_tag_controls[ id ].toggle_tag( text );
            } );
        }
        else {
            try {
                for ( var i = 0; i < element.childNodes.length; i++ ) {
                    this.update_tag_suggestions_rec( element.childNodes[i] );
                }
            }
            catch (e) {}
        }
    }
    
    this.toggle_tag = function( tag ) {
        tag = this.prepare_tag( tag );
        if ( ! tag ) return false;
        if ( this.current_data_keys[ tag ] ) this.remove_tag( tag );
        else this.add_tag( tag );
    }

    this.add_tag_string = function( tag_string ) {
        if ( ! tag_string ) return false;
        var tags = tag_string.split( /\s*,\s*/ );
        for ( var i in tags ) {
            this.add_tag( tags[i] );
        }
    };
    
    this.add_tag = function( tag ) {
        tag = this.prepare_tag( tag );
        if ( ! tag ) return false;
        if ( ! this.current_data_keys[ tag ] ) {
            this.current_data_keys[ tag ] = 1;
            this.current_data.push( tag );
        }
        this.update_input_value();
        this.update_tag_list();
        this.update_tag_suggestions();
    };

    this.remove_tag = function( tag ) {
        tag = this.prepare_tag( tag );
        if ( ! tag ) return false;
        if ( this.current_data_keys[ tag ] ) {
            this.current_data_keys[ tag ] = 0;
            var new_data = new Array();
            for ( var i in this.current_data ) {
                var t = this.current_data[i];
                if ( this.current_data_keys[ t ] ) {
                    new_data.push( t );
                }
            }
            this.current_data = new_data;
        }

        this.update_input_value();
        this.update_tag_list();
        this.update_tag_suggestions();
    };

    this.prepare_tag = function( tag ) {
        var stag = new String( tag );
        stag = stag.replace(/^\s*/, '');
        stag = stag.replace(/\s*$/, '');
        stag = stag.replace(/\s\s+/g, ' ');
        return stag.toLowerCase();
    };

    this.data_input_value = function( data_input, value, force ) {
        if ( ! data_input ) return new Array();
        if ( value || force ) {
            data_input.value = dojo.toJson( value );
            return value;
        }
        else {
            value = dojo.fromJson( data_input.value );
            return value ? value : new Array();
        }
    };

    this.data_to_keys = function( dat ) {
        if(!dat.length) return {};
        var keys = {};
        for ( var i in dat ) {
            keys[ dat[i] ] = 1;
        }
        return keys;
    };
}

function process_tag_controls() {
    dojo.query('.tag_control').forEach( function ( control ) {
        if ( dojo.hasClass( control, 'tag_control_processed' ) ) return;
        dojo.addClass( control, 'tag_control_processed' );
        var id = control.id;
        var data_input = dojo.byId( 'tag_data_' + id );
        var list = dojo.byId( 'tag_list_' + id );
        
        if ( ! data_input || ! list ) return;
        dicole_tag_controls[ id ] = new DicoleTagControl( id );
        dicole_tag_controls[ id ].init();
    } );
}

