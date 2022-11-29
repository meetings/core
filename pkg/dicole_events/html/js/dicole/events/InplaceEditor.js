dojo.provide("dicole.events.InplaceEditor");

dojo.declare("dicole.events.InplaceEditor", null, {
	"constructor": function(display_element) {
		this._display_element = display_element;
		
		this._object_url = dojo.attr(this._display_element, "href");
		this._attribute_name = dojo.attr(this._display_element, "title");
		
		this._editor_container = dojo.create("div", {"class": "js_inplace_editor"}, this._display_element, "after");
		
		this._tooltip = dojo.create("div", {"class": "js_inplace_editor tooltip", "style": "display: none", "innerHTML": "Click to edit!"}, dojo.body());
		dojo.connect(this._display_element, "onmouseover", this, this._onmouseover);
		dojo.connect(this._display_element, "onmousemove", this, this._onmousemove);
		dojo.connect(this._display_element, "onmouseout", this, this._onmouseout);
	},
	
	"load": function() {
	},
	
	"edit": function() {
		dojo.disconnect(this._edit_button_connection);
	},
	
	"save": function() {
		this._edit_button_connection = dojo.connect(this._display_element, "onmouseover", this, this._show_edit);
	},
	
	"_onmouseover": function() {
		dojo.style(this._tooltip, "display", "block");
	},
	
	"_onmousemove": function(event) {
		var tooltip_box = dojo.marginBox(this._tooltip);
		tooltip_box.l = event.clientX + 20;
		tooltip_box.t = event.clientY - 20;
		dojo.marginBox(this._tooltip, tooltip_box);
	},
	
	"_onmouseout": function() {
		dojo.style(this._tooltip, "display", "none");
	}
});