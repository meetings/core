dojo.provide('dicole.shareflect.River');
dojo.declare('dicole.shareflect.River', null, {

	constructor : function( obj ) {
		this.obj = obj;
		this.filtered = false;
		this.dom_id = this.get_dom_id();
		this.div = this.create_div();
		this.content = this.get_content_container();
		this.refresh();
		this.listeners = {};
		this.connect_listeners();
	},
	
	create_new_message_dialog : function() {
		var html = dicole.process_template( "new_message", this.obj );
		var node = dojo.create("div", { 
			"class": "new_message dialog",
			"innerHTML": html,
			"style" : { 
				"position": "absolute",
				"top": dojo.coords( this.div ).y + 70 + "px",
				"left": dojo.coords( this.div ).x + 5 + "px",
				"zIndex": 1002
			}
		} );
		var modal = this.create_modal();
		dojo.place( modal, this.div.parentNode, "before" );
		dojo.place( node, modal, "first" );
 	},
	
	create_modal : function() {
		var node = dojo.create("div", {
		    "style" : {
		        "position" : "absolute",
		        "top" : "0",
		        "left" : "0",
		        "width" : "100%",
		        "height" : "100%",
		        "backgroundImage" : "url(/images/shareflect/black-66.png)",
		        "zIndex" : 1001
		    }
		});
		dojo.connect( node, "click", node, function() { dojo.destroy(this); } );
		return node;
//		dojo.place( modal, dojo.byId("rivers"), "before" )
	},

	create_div : function() {
		var html = dicole.process_template( "river", this.obj );
		var node = dojo.create("div", { 
			"class": "river",
			"id": this.dom_id,
			"innerHTML": html,
			"style" : { height: shareflect.get_window_height() }
		} );
		dojo.place( node, shareflect.river_container, "last" );
		dojo.style( dojo.query("#" + this.dom_id + " .content")[0], "height", dojo.coords( node ).h - 75 + "px" );

		return node;
	},

	get_content_container : function() {
		return dojo.query("#" + this.dom_id + " .content")[0];
	},
	
	refresh : function() {
		var last_ref = this.content;
		var last_position = "first";
		dojo.forEach( this.obj.messages, function ( message ) {
			message.dom_id = this.dom_id + "_" + message.id;
			var node = dojo.byId( message.dom_id );
			if( node ) {
				if( dojo.attr(node, "updated") != message.updated ) {
					dojo.attr( node, {
						"updated": message.updated,
						"innerHTML": dicole.process_template( "river_message", message )
					} );
				}
				dojo.place( node, last_ref, last_position);
			} else {
				node = dojo.create("div", {
					"id": message.dom_id,
					"class": "message",
					"updated": message.updated,
					"innerHTML": dicole.process_template( "river_message", message )
				} );
				dojo.place( node, last_ref, last_position);
			}
			last_ref = node;
			last_position = "after";
		}, this );
	},

	connect_listeners : function() {
		this.listeners.river_edit_onmouseover = dojo.connect( dojo.query("#" + this.dom_id + " .tools")[0], "onmouseover", dojo.query("[show_id=edit_" + this.dom_id + "]")[0], function() { dojo.style( this.parentNode, "display", "block"); } );
		this.listeners.river_edit_onmouseout = dojo.connect( dojo.query("#" + this.dom_id + " .tools")[0], "onmouseout", dojo.query("[show_id=edit_" + this.dom_id + "]")[0], function() { dojo.style( this.parentNode, "display", "none"); } );
		/*
		dojo.forEach( dojo.query("#" + this.dom_id + " .tools"), function( tools ) {
			//console.log( tools );
			dojo.connect( tools, "onmouseover", dojo.query("#" + this.dom_id + " .tools .edit"), function( event ) {
				console.log( "onmouseover", this );
			} );
		}, this );
		*/
		dojo.forEach( dojo.query("#" + this.dom_id + " .close"), function( link ) {
			dojo.connect( link, "click", this, "close_river" );
		}, this );
		dojo.connect( dojo.byId("new_message_" + this.dom_id), "click", this, "create_new_message_dialog" );
//		dojo.connect( dojo.byId("new_message_" + this.dom_id), "click", this, function() {
//			console.log("create_new_message_dialog", this);
//		} );
		dojo.forEach( dojo.query("#" + this.dom_id + " .edit"), function( link ) {
			dojo.connect( link, "click", dojo.hitch(this, function() {
				// FIXME: There must be toggle display mechanism in dojo
				var menu = dojo.byId( dojo.attr( link, "show_id" ) );
				var display = 'none';

				if( dojo.style( menu, "display") == 'none') {
					//dojo.disconnect( this.listeners.river_edit_onmouseout );
					display = 'block';
				}

				dojo.connect( menu, "onmouseover", this, function() { 
					dojo.style( menu, "display", "block");
					dojo.style( link, "display", "block");
					} );
				
				dojo.connect( menu, "onmouseout", this, function() { 
					dojo.style( menu, "display", "none");
					dojo.style( link.parentNode, "display", "none");
					} );
				
								
				dojo.style( dojo.byId( dojo.attr( link, "show_id" ) ), {
					"display": display,
					"position": "absolute",
					"top": dojo.coords( link ).y + 20 + "px",
					"left": dojo.coords( link ).x - 20 + "px",
					"zIndex": "999"
				} );
			}, link ) );
		}, this );
		dojo.forEach( dojo.query("#" + this.dom_id + " .location-name"), function( location ) {
			dojo.connect( location, "onmouseover", { map: shareflect.map, node: location }, function( event ) {
				google.maps.event.trigger( this.map.get_marker(dojo.attr(this.node, "show_id")), "mouseover" );
			} );
			dojo.connect( location, "onmouseout", { map: shareflect.map, node: location }, function( event ) {
				google.maps.event.trigger( this.map.get_marker(dojo.attr(this.node, "show_id")), "mouseout" );
			} );
			dojo.connect( location, "click", { map: shareflect.map, node: location }, function( event ) {
				google.maps.event.trigger( this.map.get_marker(dojo.attr(this.node, "show_id")), "click" );
			} );
		}, this);
		dojo.connect( this, "close_river", shareflect, "update_containers");
	},
	
	get_dom_id : function() {
		if ( this.dom_id ) { return this.dom_id; }

		var dom_id = (this.obj.dom_id || this.obj.type + "_") + (this.obj.id || "");
		
		if( this._river_exists(dom_id) ) {
			dom_id = dom_id + "_" + new Date().getTime();
		} else {
			dom_id = dom_id;
		}
		
		this.obj.dom_id = dom_id;
		
		return dom_id;
	},
	
	close_river : function() {
		shareflect.rivers.splice(this._get_river_index(), 1);
        dojo.destroy( this.div );
	},
	
	_river_exists : function( dom_id ) {
		if ( dojo.byId( dom_id ) ) {
			return true;
		} else {
			return false;
		}
	},
	
	_get_river_index : function() {
		var found_index = -1;
		dojo.forEach( shareflect.rivers, function( river, index ) {
			if( river == this ) found_index = index;
		}, this );
		return found_index;
	}
} );