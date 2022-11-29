dojo.provide("dicole.events.InplaceLineEditor");

dojo.require("dicole.events.InplaceEditor");

dojo.declare("dicole.events.InplaceLineEditor", dicole.events.InplaceEditor, {
	"constructor": function(display_element) {
		dojo.attr(this._display_element, "innerHTML", "Loading...");
		
		this._edit_element = dojo.create("input", {"type": "text"}, this._editor_container);
		dojo.style(this._edit_element, "display", "none");
	},

	"load": function() {
		this.inherited(arguments);
		dojo.xhrPost({
			"url": this._object_url,
			"content": {
				"name": this._attribute_name
			},
			"load": dojo.hitch(this, function(response) {
				if(response.result) {
					dojo.attr(this._display_element, "innerHTML", response.result.value);
					dojo.attr(this._edit_element, "value", response.result.value);
				}
			}),
			"handleAs": "json"
		});
	},
	
	"edit": function() {
		this.inherited(arguments);
		dojo.style(this._display_element, "display", "none");
		dojo.style(this._edit_element, "display", "block");
	},
	
	"save": function() {
		this.inherited(arguments);
		dojo.xhrPost({
			"url": this._object_url,
			"content": {
				"name": this._attribute_name,
				"value": this.value
			},
			"load": dojo.hitch(this, function(response) {
				if(response.result) {
				}
			}),
			"handleAs": "json"
		});
	}
});