dojo.provide('dicole.shareflect.CustomTooltip');
dojo.declare('dicole.shareflect.CustomTooltip', google.maps.OverlayView, {

	constructor : function( map, point, content ) {
		this.point_ = point;
		this.map_ = map; // needs to be underscored because otherwise setMap(null) overrides it
		this.content = content;
		this.setMap(map);
		this.opts = {};
	},

	onAdd : function() {
		var panes = this.getPanes();
		var paneId = this.opts.pane || "floatPane";
		this.div = dojo.create("div", { 
			"class": "tooltip location",
			"style": {
				"position": "absolute",
				"opacity": 0,
				"display": "none"
			},
			"innerHTML": this.content
		} );
		dojo.place( this.div, panes[paneId] );
	},

	onRemove : function() {
		dojo.destroy( this.div );
	},

	draw : function() {
		var pp = this.getProjection().fromLatLngToDivPixel(this.point_); 
		this.div.style.left = pp.x + 'px';
		this.div.style.top = pp.y + 'px';
	},

	hide : function() {
		if( !this.hide_anim ) {
			this.hide_anim = dojo.animateProperty( {
				node: this.div,
				duration: 150,
				properties: {
					opacity: 0
				},
				onEnd: dojo.hitch(this, function() { 
					dojo.style(this.div, "style", "none");
					dojo.style(this.div, "left", "-666px"); // needs to be done or tooltips block mouseovers on top of other markers
				})
			} );
		}
		this.hide_anim.play();
	},
	
	show : function() {
		if( !this.show_anim ) {
			this.show_anim = dojo.animateProperty( {
				node: this.div,
				duration: 300,
				properties: {
					opacity: 1
				}
			} );
			this.show_anim_connect = dojo.connect( this.show_anim, "beforeBegin", dojo.hitch( this, function() {
				dojo.style(this.div, "display", "block");
				this.draw();
				this._set_offset();
			}) );
		}
		this.show_anim.play();
	},
	
	_set_offset : function() {
		if( !dojo.style(this.div, "marginTop") ) {
			dojo.style(this.div, {
				"marginTop": -(40 + dojo.coords(this.div).h) + "px",
				"marginLeft": -Math.floor(dojo.coords(this.div).w/2) + "px"
				});
		}
	}
});