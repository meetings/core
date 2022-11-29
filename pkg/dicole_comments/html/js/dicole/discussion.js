dojo.provide("dicole.discussion");

var visible_discussion = 1;
var last_discussion = null;

var navigation = null;
var next_button = null;
var prev_button = null;
var loading_box = null;

var next_connection = null;
var prev_connection = null;

dojo.addOnLoad(function() {
	var current_discussion = dojo.query(".discussion")[0];
	if(current_discussion) {
		dojo.addClass(current_discussion, "1");
		dojo.style(current_discussion, "left", 0);
		calculate_visible_height();
	
		navigation = dojo.byId("discussions_navi");
		next_button = dojo.byId("discussion_next");
		prev_button = dojo.byId("discussion_prev");
	
		modify_button("next", false);
		if(dojo.hasClass(prev_button, "disabled")) modify_button("prev", false);
		else modify_button("prev", true);
	}
});

var calculate_visible_height = function() {
	var discussions = dojo.byId("discussions");
	var entries = dojo.query(".discussion." + visible_discussion + " .discussion_entry", discussions);
	var height = 0;
	entries.forEach(function(entry) {
		height += dojo.marginBox(entry).h;
	});
	dojo.marginBox(discussions, {"h": height});
};

var show_next_discussion = function(event) {
	dojo.stopEvent(event);
	modify_button("next", false);
	modify_button("prev", false);
	dojo.addClass(navigation, "loading");
	
	if(visible_discussion != 1) {
		var current_discussion = dojo.query(".discussion." + visible_discussion)[0];
		var next_discussion = dojo.query(".discussion." + (visible_discussion - 1))[0];
	
		if(dojo.isIE < 8) {
			visible_discussion--;
			dojo.style(current_discussion, "display", "none");
			dojo.style(next_discussion, "left", 0);
			dojo.style(next_discussion, "display", "block");
			dojo.removeClass(navigation, "loading");
			if(visible_discussion != 1) {
				modify_button("next", true);
				modify_button("prev", true);
			}
			else {
				modify_button("prev", true);
			}
			calculate_visible_height();
		}
		else {
			var animation = dojo.fx.combine([
				dojo.animateProperty({"node": current_discussion, "properties": {"left": 650}}),
				dojo.animateProperty({"node": next_discussion, "properties": {"left": 0}})
			]);
			
			dojo.connect(animation, "onEnd", function() {
				visible_discussion--;
				dojo.removeClass(navigation, "loading");
				if(visible_discussion != 1) {
					modify_button("next", true);
					modify_button("prev", true);
				}
				else {
					modify_button("prev", true);
				}
				calculate_visible_height();
			});
			
			animation.play();
		}
	}
};

var show_prev_discussion = function(event) {
	dojo.stopEvent(event);
	modify_button("next", false);
	modify_button("prev", false);
	dojo.addClass(navigation, "loading");
	
	var current_discussion = dojo.query(".discussion." + visible_discussion)[0];
	var prev_discussion = dojo.query(".discussion." + (visible_discussion + 1))[0];
	
	if(!prev_discussion) {
		var json_data = dojo.fromJson(dojo.attr(dojo.query(".discussion_data", current_discussion)[0], "title"));
		dojo.xhrPost({
			"url": json_data.more_url,
			"handleAs": "json",
			"content": {"skip_data": json_data.skip_data},
			"handle": function(response) {
				if(response.result.html) {
					if(dojo.isIE < 8) {
						dojo.style(current_discussion, "display", "none");
						prev_discussion = dojo.place(response.result.html, dojo.byId("discussions"))
						visible_discussion++;
						dojo.addClass(prev_discussion, "" + visible_discussion);
						dojo.style(prev_discussion, "left", 0);
						dojo.removeClass(navigation, "loading");
						modify_button("next", true);
						if(!response.result.end_of_pages) modify_button("prev", true);
						else last_discussion = visible_discussion;
						calculate_visible_height();
					}
					else {
						prev_discussion = dojo.place(response.result.html, dojo.byId("discussions"));
						visible_discussion++;
						dojo.addClass(prev_discussion, "" + visible_discussion);
						
						var animation = dojo.fx.combine([
							dojo.animateProperty({"node": current_discussion, "properties": {"left": -650}}),
							dojo.animateProperty({"node": prev_discussion, "properties": {"left": 0}})
						]);
						
						dojo.connect(animation, "onEnd", function() {
							dojo.removeClass(navigation, "loading");
							modify_button("next", true);
							if(!response.result.end_of_pages) modify_button("prev", true);
							else last_discussion = visible_discussion;
							calculate_visible_height();
						});
						
						animation.play();
					}
				}
				else {
					dojo.removeClass(navigation, "loading");
					modify_button("next", true);
				}
			}
		});
	}
	else {
		if(dojo.isIE < 8) {
			dojo.style(current_discussion, "display", "none");
			dojo.style(prev_discussion, "display", "block");
			visible_discussion++;
			dojo.removeClass(navigation, "loading");
			if(visible_discussion == last_discussion) {
				modify_button("next", true);
			}
			else {
				modify_button("next", true);
				modify_button("prev", true);
			}
			calculate_visible_height();
		}
		else {
			var animation = dojo.fx.combine([
				dojo.animateProperty({"node": current_discussion, "properties": {"left": -650}}),
				dojo.animateProperty({"node": prev_discussion, "properties": {"left": 0}})
			]);
		
			dojo.connect(animation, "onEnd", function() {
				visible_discussion++;
				dojo.removeClass(navigation, "loading");
				if(visible_discussion == last_discussion) {
					modify_button("next", true);
				}
				else {
					modify_button("next", true);
					modify_button("prev", true);
				}
				calculate_visible_height();
			});
			
			animation.play();
		}
	}
};

var modify_button = function(button, enabled) {
	if(button == "next") {
		if(enabled) {
			if(next_connection) dojo.disconnect(next_connection);
			next_connection = dojo.connect(next_button, "onclick", null, show_next_discussion);
			dojo.removeClass(next_button, "disabled");
		}
		else {
			if(next_connection) dojo.disconnect(next_connection);
			next_connection = dojo.connect(next_button, "onclick", null, dojo.stopEvent);
			dojo.addClass(next_button, "disabled");
		}
	}
	else if(button == "prev") {
		if(enabled) {
			if(prev_connection) dojo.disconnect(prev_connection);
			prev_connection = dojo.connect(prev_button, "onclick", null, show_prev_discussion);
			dojo.removeClass(prev_button, "disabled");
		}
		else {
			if(prev_connection) dojo.disconnect(prev_connection);
			prev_connection = dojo.connect(prev_button, "onclick", null, dojo.stopEvent);
			dojo.addClass(prev_button, "disabled");
		}
	}
};