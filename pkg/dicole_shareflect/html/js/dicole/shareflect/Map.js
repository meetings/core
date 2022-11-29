dojo.provide('dicole.shareflect.Map');
dojo.require('dicole.shareflect.CustomTooltip');
dojo.declare('dicole.shareflect.Map', null, {

    constructor : function() {
        this.container = dojo.byId("map_canvas");
		// Change this to world view
        this.map_default_position = new google.maps.LatLng(60.169012, 24.940681);
		this.options = {
			zoom: 13,
			center: this.map_default_position,
			mapTypeId: google.maps.MapTypeId.ROADMAP,
			navigationControl: true,
			mapTypeControl: false,
			scaleControl: true
		};
		this.create_map();
		this.markers = [];
	},

	get_container : function() {
		return this.container;
	},
	
	get_marker : function( marker_id ) {
		var found_marker = null;
		dojo.forEach( this.markers, function( marker ) {
			if( marker_id == marker.marker_id ) {
				found_marker = marker;
			}
		}, this );
		return found_marker;
	},
	
    create_map : function() {
        this.map = new google.maps.Map(this.container, this.options);

		// TODO: Remove listeners after development phase
        google.maps.event.addListener(this.map, 'bounds_changed', function() {
			//console.log( "bounds changed");
            }
        );
        google.maps.event.addListener(this.map, 'center_changed', function() {
			//console.log( "center changed");
            }
        );
        google.maps.event.addListener(this.map, 'zoom_changed', function() {
			//console.log( "zoom changed");
            }
        );
        google.maps.event.addListener(this.map, 'dragstart', function() {
			//console.log( "drag started", this.markers[0].projectionController.pixelPosition);
			}
        );
        google.maps.event.addListener(this.map, 'dragend', function() {
			//console.log( "drag ended  ", this.markers[0].projectionController.pixelPosition);
			}
        );
    },

	resize_and_center : function( lat, lng ) {
		var point = new google.maps.LatLng( lat || this.map.getCenter().lat(), lng || this.map.getCenter().lng() );
		google.maps.event.trigger(this.map, 'resize');
		this.map.setCenter( point );
	},

	add_location : function( map_point ) {
        var point = new google.maps.LatLng(map_point.lat, map_point.lng);
/*        if( !this.map.getBounds().contains(point) ) {
            console.log("Map point " + map_point.title + " is out of the map!");
        }*/

		var marker = this._add_marker( { 
			marker_id: "location_" + map_point.id,
			position: point,
			map: this.map
		} );
		var html = dicole.process_template( "location_tooltip", map_point );
		var tooltip = this._attach_tooltip( marker, html );

        google.maps.event.addListener(marker, 'click', dojo.hitch(this, function( event ) {
			shareflect.add_river( map_point );
        }));
	},

	_add_marker : function( options ) {
		var marker = new google.maps.Marker(options);
		this.markers.push(marker);
		return marker;
	},
	
	_attach_tooltip : function ( marker, html, opt_options ){
		var position = marker.getPosition();
		var map_ = marker.getMap();
		marker.custom_tooltip = new dicole.shareflect.CustomTooltip(this.map, position, html);
		google.maps.event.addListener(marker, 'mouseover', function () { 
			this.custom_tooltip.show();
			clearTimeout(this.custom_tooltip.timer);
		});
		google.maps.event.addListener(marker, 'mouseout', function () {
			clearTimeout(this.custom_tooltip.timer);
			this.custom_tooltip.timer = setTimeout( dojo.hitch(this, function(){
				this.custom_tooltip.hide();
			} ), 200);
		});
	},
        
    set_map_zoom : function( zoom ) {
        this.map.setZoom( zoom );
    }
} );