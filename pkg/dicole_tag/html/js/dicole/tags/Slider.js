/*
 *  Slider.js: Creates a slider for controlling tag clouds 
 */

dojo.require("dijit.dijit");

dojo.require("dijit.form.HorizontalSlider");
dojo.require("dijit.form.HorizontalRule");
dojo.require("dijit.form.HorizontalRuleLabels");

dojo.require("dijit.form.Button");
dojo.require("dojo.parser"); // scan page for widgets
dojo.require("dicole.base");

dojo.provide("dicole.tags.Slider");

dojo.declare("dicole.tags.Slider", null, {

	constructor : function( container )
	{
		// Get the control and container nodes
		// control node is the span encasing
		// both the actual slider container and the controllable
		// content (tag cloud or something else)
		this.control_node = container.parentNode;
		// The container that we want to add our slider to
		// programatically
		this.container_node = container;
	},

	'init' : function()
	{
		this._create_tag_slider(this.control_node);
	},

	// Create one tag cloud slider attached to
	'_create_tag_slider' : function(control_node)
	{
		var slider = new dijit.form.HorizontalSlider(
		{
			value: 0,
			onChange: dojo.hitch(this, function(slider_val)
			{
				this._controlTagCloud(control_node, slider_val);
			}),
			name:"tagCloudSlider",
			slideDuration: 200,
			maximum:100,
			minimum:0,
			showButtons:false,
			intermediateChanges:true,
			style:"width: 250px height: 20px;"
		}, this.container_node);

		slider.startup();
	},

	// Controls one tag cloud with ID control_id
	// Sets the tag visibility based on the slider arguments
	_controlTagCloud : function( control_node, slider_val )
	{
		dojo.query('.miniTagCloud > a', control_node).forEach(
			function( node )
			{
				this._filterTagVis(node, slider_val);
			}, this
		);
	},

	// Sets node visibility based on it's tag_weights_X_Y
	// values and the filtering level of slider_val
	_filterTagVis : function( node, slider_val )
	{
		// Get the class names of this node
		var classNames = node.className.split(' ');
		var weight_str = "";

		// Find the class name that starts with the weight prefix
		for (var i=0; i<classNames.length; i++)
		{
			var name = classNames[i];
			// Get the class that has the weight
			// of the tag in it
			var weight_prefix = 'tag_weights_';
			if (name.indexOf(weight_prefix) != -1)
			{
				weight_str = name.substr(weight_prefix.length);
				break;
			}
		}
		// Adjust tag visibility based on weight
		if (weight_str != "")
		{
			var weights = weight_str.split('_', 2);
			var weight = parseInt(weights[0] + weights[1]);
			// TODO: change the weight calculation
			weight = (weight - 90) + 1;
			var filter_level = parseInt(slider_val / 10);
	
			// Weight is in the range 0 - 99
			// Slider goes from 0 to 100
			if ( filter_level > weight )
			{
				dojo.style(node, "display", "none");
			}
			else
			{
				dojo.style(node, "display", "inline");
			}
		}
	}
});
