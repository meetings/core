dojo.provide('dicole.Shareflect');
dojo.require('dicole.base');
dojo.require('dicole.shareflect.Data');
dojo.require('dicole.shareflect.Map');
dojo.require('dicole.shareflect.River');
dojo.declare('dicole.Shareflect', null, {

    start : function( domain_name, auth_token, group_id ) {
        this.domain_name = 'work-dev.dicole.net';
        this.auth_token = auth_token;
        this.group_id = group_id;

		this.river_container = dojo.byId("rivers");
//		this.river_container.connect( "place", this, "update_containers" );

		this.data = new dicole.shareflect.Data( true );

		this.rivers = [];
		this.topics = [];
		this.alerts = [];

		this._register_templates();

        this.map = new dicole.shareflect.Map();
        this.map_test_data();

		this.connect_listeners();
		this.add_river( this.data.get_river("river_all_messages") );

//		this._set_dimension_to_viewport();
        this.map_controls();

	},
	
	update_containers : function() {
		shareflect._set_dimension_to_viewport();
		shareflect.map.resize_and_center( null, null );
	},

	map_controls : function() {
		var river = dicole.process_template( "river_controls", {} );
		dojo.place( river, this.map.get_container(), "first" );
		
		dojo.connect( dojo.byId("toggle_all_messages"), "click", this, function() {
			this.add_river( this.data.get_river("river_all_messages") );
		});
		dojo.connect( dojo.byId("toggle_mentions"), "click", this, function() {
			this.add_river( this.data.get_river("river_mentions") );
		});
		dojo.connect( dojo.byId("toggle_alerts"), "click", this, function() {
			this.add_river( this.data.get_river("river_alerts") );
		});
		dojo.connect( dojo.byId("toggle_tag_cloud"), "click", this, function() {
			this.add_river( this.data.get_river("river_tag_cloud") );
		});
		dojo.connect( dojo.byId("toggle_locations"), "click", this, function() {
			this.add_river( this.data.get_river("river_locations") );
		});
		dojo.connect( dojo.byId("toggle_users"), "click", this, function() {
			this.add_river( this.data.get_river("river_users") );
		});
		
		var view = dicole.process_template( "view_controls", {} );
		dojo.place( view, this.map.get_container(), "first" );
	},

	_set_dimension_to_viewport : function() {
		dojo.style( this.map.get_container(), {
			width: ( window.innerWidth - ((this.rivers.length) * 280) ) + "px",
			height: window.innerHeight + "px"
		} );
	},
	
	add_river : function( object ) {
		this.rivers.push( new dicole.shareflect.River( object ) );
	},

	update_element : function( dom_id ) {
		dojo.forEach( shareflect.rivers, function( river ) {
			if( river.dom_id == dom_id ) {
				river.refresh();
			} 
		}, this );
	},
	
	update_river : function( river_name ) {
		this.rivers[0].refresh();
	},
	
	connect_listeners : function() {
		dojo.connect( this, "add_river", this, "update_containers" );
	},

	add_alert : function( obj ) {
		var html = dicole.process_template( "location_alert", obj );
		var node = dojo.create("div", { 
			"class": "alerts",
			"id": "alerts",
			"innerHTML": html
		} );
		dojo.place( node, this.map.get_container(), "last" );
		this.alerts.push(node);
	},
	
	get_window_height : function( without_pixels ) {
		if( without_pixels ) {
			return window.innerHeight;
		} else {
			return window.innerHeight + "px";
		}
	},

	_register_templates : function() {
		// Timestamp after template urls is used to play nice with cache. Remove for production build!
        
	    dicole.register_template( "river" , { templatePath : dojo.moduleUrl("dicole.shareflect", "river.html") } );
	    dicole.register_template( "river_message" , { templatePath : dojo.moduleUrl("dicole.shareflect", "river_message.html") } );
	    dicole.register_template( "new_message" , { templatePath : dojo.moduleUrl("dicole.shareflect", "new_message.html") } );
	    dicole.register_template( "location_tooltip" , { templatePath : dojo.moduleUrl("dicole.shareflect", "location_tooltip.html") } );
	    dicole.register_template( "location_alert" , { templatePath : dojo.moduleUrl("dicole.shareflect", "location_alert.html") } );
	    dicole.register_template( "river_controls" , { templatePath : dojo.moduleUrl("dicole.shareflect", "river_controls.html") } );
	    dicole.register_template( "view_controls" , { templatePath : dojo.moduleUrl("dicole.shareflect", "view_controls.html") } );
	},

    map_test_data : function() {
		dojo.forEach( this.data.get_locations(), function( location ){
			this.map.add_location( location );
		}, this );
    }
} );