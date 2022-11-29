dojo.provide("dicole.groups");

dojo.require("dicole.base");
dojo.require("dicole.tags.TagBrowser2");

dicole.groups.tag_browsers = [];

dicole.groups.export_url = null;

dojo.addOnLoad( function() {
	if(dojo.byId("subgroups_tag_browser")) {
		dicole.groups.tag_browsers.push(new dicole.tags.TagBrowser2(
			"browse_filter_container",
			"browse_selected_container",
			"browse_selected_tags_container",
			"browse_suggestions",
			"browse_results",
			dojo.query("#filter_link"),
			dojo.query("#filter_more"),
			dojo.query("#browse_show_more a"),
			dojo.query("#browse_result_count"),
			dicole.get_global_variable("subgroups_keyword_change_url"),
			dicole.get_global_variable("subgroups_more_groups_url"),
			dicole.get_global_variable("subgroups_groups_state"),
			dicole.get_global_variable("subgroups_end_of_pages")
		));
	}
	
	var photo_upload = dojo.byId("group_info_photo");
	if(photo_upload) dicole.init_flash_uploader("group_info_photo", 200, 150);
	
	var custom_banner = dojo.byId("group_custom_banner");
	if(custom_banner) dicole.init_flash_uploader("group_custom_banner", 300, 80);
	
	dicole.groups.process_fancy_buttons();
	
	var subgroups_sections = dojo.query(".summary_box .subgroups_section");
	var subgroups_section_containers = dojo.query(".subgroups_section_container");
	subgroups_sections.forEach(function(subgroups_section) {
		dojo.connect(subgroups_section, "onclick", null, function(event) {
			dojo.stopEvent(event);
			subgroups_sections.removeClass("subgroups_section_selected");
			dojo.addClass(subgroups_section, "subgroups_section_selected");
			subgroups_section_containers.forEach(function(subgroups_section_container) { 
				dojo.style(subgroups_section_container, "display", "none"); 
			});
			var id = subgroups_section.id.split("_")[2];
			dojo.style(dojo.byId("subgroups_section_container_" + id), "display", "block");
		});
	});
	
	if(dojo.byId("group_admin_users")) {
		dicole.register_template("user_confirm_delete", {templatePath: dojo.moduleUrl("dicole.groups", "user_confirm_delete.html")});
		
		var export_button = dojo.byId("group_users_list_button");
		if(export_button) dicole.groups.export_url = export_button.href;
		
		var filters = {};
		dojo.query("#group_users_filter_buttons a").forEach(function(filter) {
			filters[filter.id.split(",")[1]] = false;
		});
		
		var users = {};
		dojo.query("#group_users_table tbody tr").forEach(function(user) {
			var id = user.id.split("_")[1];
			
			users[id] = {
				"element": user,
				"search_filter": true,
				"level_filter": true
			};
			
			var level_field = dojo.byId("user_" + id + "_level");
			dojo.connect(level_field, "onchange", null, function(event) {
				dojo.attr(user, "class", "");
				dojo.addClass(user, level_field.value);
				if(function() { for(var filter in filters) { if(filters[filter]) return true; } return false; }()) {
					for(var filter in filters) {
						if(dojo.hasClass(users[id].element, filter)) {
							if(filters[filter]) {
								users[id].level_filter = true;
								break;
							}
							else {
								users[id].level_filter = false;
								break;
							}
						}
					}
				}
				dojo.xhrPost({
					"url" : dicole.get_global_variable("update_rights_url"),
					"handleAs": "json",
					"content": {"user_id": id, "level": level_field.value},
					"load": function(response) {
						if(response && response.success) dicole.groups.filter_users(users);
						else alert("Virrrrrrrrrhe!");
					}
				});
			});
			
			var remove_link = dojo.byId("user_" + id + "_remove");
			if(remove_link && !dojo.hasClass(remove_link, "processed")) {
				dojo.connect(remove_link, "onclick", null, function(event) {
					dojo.stopEvent(event);
	
					dicole.create_showcase({"disable_close": true, "width": 600, "content": dicole.process_template("user_confirm_delete", {})});
					
					dojo.connect(dojo.byId("user_confirm_delete_confirm"), "onclick", null, function(event) {
						dojo.stopEvent(event);
						dojo.xhrPost({
							"url": dojo.attr(remove_link, "href"),
							"content": {"remove": 1},
							"handleAs": "json",
							"handle": function(response) {
								if(response && response.success) {
									dojo.destroy(user);
									dojo.publish("showcase.close");
									dicole.groups.filter_users(users);
								}
								else alert("Virrrrrrrrrhe!");
							}
						});
					});
					
					dojo.connect(dojo.byId("user_confirm_delete_cancel"), "onclick", null, function(event) {
						dojo.stopEvent(event);
						dojo.publish("showcase.close");
					});
				});
				dojo.addClass(remove_link, "processed");
			}
		});
		
		dicole.groups.filter_users(users);
		
		var search_field = dojo.byId("group_users_search_field");
		if(search_field) {
			var search_filter = function() {
				var search_string = search_field.value.toLowerCase();
				if(search_string.length) {
					for(var user in users) {
						if(dojo.query("a.user_name", users[user].element)[0].innerHTML.toLowerCase().indexOf(search_string) != -1) {
							users[user].search_filter = true;
						}
						else users[user].search_filter = false;
					}
				}
				else for(var user in users) { users[user].search_filter = true; }
				dicole.groups.filter_users(users);
			};
		
			var search_timer = null;
			dojo.connect(search_field, "onkeypress", null, function(event) {
				if(search_timer) clearTimeout(search_timer);
				search_timer = setTimeout(search_filter, 500);
			});
		}
		
		var filter_buttons = dojo.query("#group_users_filter_buttons a");
		filter_buttons.forEach(function(button) {
			dojo.connect(button, "onclick", null, function(event) {
				dojo.stopEvent(event);
				
				var filter = button.id.split(",")[1];
				
				var button_types = ["left", "middle", "right"];
				for(var button_type in button_types) {
					var button_class = button_types[button_type] + "-button";
					if(dojo.hasClass(button, button_class)) {
						var button_class_selected = button_class + "-selected";
						if(dojo.hasClass(button, button_class_selected)) {
							dojo.removeClass(button, button_class_selected);
							filters[filter] = false;
						}
						else {
							dojo.addClass(button, button_class_selected);
							filters[filter] = true;
						}
					}
				}
				
				if(function() { for(var filter in filters) { if(filters[filter]) return true; } return false; }()) {
					for(var user in users) {
						for(var filter in filters) {
							if(dojo.hasClass(users[user].element, filter)) {
								if(filters[filter]) {
									users[user].level_filter = true;
									break;
								}
								else {
									users[user].level_filter = false;
									break;
								}
							}
						}
					}
				}
				else for(var user in users) { users[user].level_filter = true; }
				dicole.groups.filter_users(users);
			});
		});
		
		var filter_toggle = dojo.byId("group_users_filter_toggle");
		var filter_button_container = dojo.byId("group_users_filter_buttons");
		var filter_button_open = dojo.byId("group_users_filter_toggle_open");
		var filter_button_closed = dojo.byId("group_users_filter_toggle_closed");
		dojo.connect(filter_toggle, "onclick", null, function(event) {
			dojo.stopEvent(event);
			if(dojo.style(filter_button_container, "display") == "block") {
				dojo.style(filter_button_container, "display", "none");
				dojo.style(filter_button_open, "display", "none");
				dojo.style(filter_button_closed, "display", "inline");
				for(var user in users) {
					users[user].level_filter = true;
				}
				for(var filter in filters) {
					filters[filter] = false;
				}
				var button_types = ["left", "middle", "right"];
				dojo.forEach(filter_buttons, function(button) {
					for(var button_type in button_types) {
						var button_class = button_types[button_type] + "-button";
						if(dojo.hasClass(button, button_class)) {
							var button_class_selected = button_class + "-selected";
							if(dojo.hasClass(button, button_class_selected)) {
								dojo.removeClass(button, button_class_selected);
							}
						}
					}
				});
				dicole.groups.filter_users(users);
			}
			else {
				dojo.style(filter_button_container, "display", "block");
				dojo.style(filter_button_closed, "display", "none");
				dojo.style(filter_button_open, "display", "inline");
			}
		});
		
		var mail_button = dojo.byId("group_users_mail_button");
		var mail_submit = dojo.byId("group_users_mail_submit");
		var mail_self_submit = dojo.byId("group_users_mail_self_submit");
		var mail_subject = dojo.byId("group_users_mail_subject");
		var mail_content = dojo.byId("group_users_mail_content");
		if(mail_button) {
			dojo.connect(mail_button, "onclick", null, function(event) {
				dojo.stopEvent(event);
				dojo.toggleClass(mail_button, "button-selected");
				dojo.style("group_users_mail", "display", dojo.hasClass(mail_button, "button-selected") ? "block" : "none");
			});
			dojo.connect(mail_submit, "onclick", null, function(event) {
				dojo.stopEvent(event);
                if ( ! mail_subject.value || mail_subject.value == mail_subject.defaultValue ) {
                    alert( dicole.msg("You can not send the mail without a subject.") );
                    return;
                }
				dojo.xhrPost({
					"url": dojo.attr(mail_submit, "href"),
					"content": {
						"subject": mail_subject.value, 
						"content": tinyMCE.get("group_users_mail_content").getContent(), 
						"target_users": dojo.byId("group_users_list").value
					},
					"handleAs": "json",
					"handle": function(response) {
						if(response && response.result && response.result.success) {
							window.location.reload();
						}
						else alert(response.error);
					}
				});
			});
			dojo.connect(mail_self_submit, "onclick", null, function(event) {
				dojo.stopEvent(event);
                if ( ! mail_subject.value || mail_subject.value == mail_subject.defaultValue ) {
                    alert( dicole.msg("You can not send the mail without a subject.") );
                    return;
                }
				dojo.xhrPost({
					"url": dojo.attr(mail_self_submit, "href"),
					"content": {
						"subject": mail_subject.value, 
						"content": tinyMCE.get("group_users_mail_content").getContent(), 
						"target_users": dojo.byId("group_users_list").value
					},
					"handleAs": "json",
					"handle": function(response) {
						if(response && response.result && response.result.success) {
							alert(dicole.msg("Test mail sent to self."));
						}
						else alert(response.error);
					}
				});
			});
		}
	}
});

var dicole_tag_browsers = {};
var tag_browser_count = 0;

dojo.subscribe( 'new_node_created', function( node ) {
	dicole.unprocessed_class_query('js_open_create_subgroup', node ).forEach( function( anode ) {
		dojo.connect( anode, 'onclick', function( event ) {
			dojo.stopEvent(event);
			dicole.register_template("group_create", {templatePath: dojo.moduleUrl("dicole.groups", "group_create.html")});
			var showcase = dicole.process_template("group_create", {"tos_url": dicole.get_global_variable("tos_url")});
			dicole.create_showcase({"disable_close": true, "width": 800, "content": showcase});
			
			dicole.groups.process_fancy_buttons();
			dicole.init_flash_uploader("group_create_photo", 400, 300);
			
			var group_create_form = dojo.byId("group_create");
			dojo.connect(group_create_form, "onsubmit", null, function(event) {
				dojo.stopEvent(event);
				if(!dojo.hasClass(dojo.byId("group_create_button"), "disabled")) {
					dojo.xhrPost({
						"url": dicole.get_global_variable("subgroups_create_url"),
						"content": dojo.formToObject(group_create_form),
						"handleAs": "json",
						"handle": function(response) {
							if(response && response.result && response.result.success) window.location = response.result.url;
							else alert(response.error);
						}
					});
				}
			});
		} );
	} );
});

dicole.groups.filter_users = function(users) {
	var filtered_ids = [];
	for(var user in users) {
		if(users[user].search_filter && users[user].level_filter) {
			dojo.style(users[user].element, "display", dojo.isIE ? "block" : "table-row");
			filtered_ids.push(users[user].element.id.split("_")[1]);
		}
		else dojo.style(users[user].element, "display", "none");
	}
	dojo.byId("group_users_list").value = filtered_ids.join(",");
	var list_button = dojo.byId("group_users_list_button");
	if(list_button) list_button.href = dicole.groups.export_url + "?target_users=" + filtered_ids.join(",");
	dojo.byId("group_users_number_field").innerHTML = filtered_ids.length.toString();
};

dicole.groups.process_fancy_buttons = function() {
	dojo.query(".fancy_radios a").forEach(function(fancy_radio_button) {
		dojo.connect(fancy_radio_button, "onclick", null, function(event) {
			dojo.stopEvent(event);
			
			var id = fancy_radio_button.id;
			var name = id.split(",", 2)[0];
			var value = id.split(",", 2)[1];
			var button = dojo.byId(id);
	
			dojo.query("#fancy_radios_" + name + " a").forEach(function(element) {
				if(dojo.hasClass(element, "left-button")) dojo.removeClass(element, "left-button-selected");
				else if(dojo.hasClass(element, "middle-button")) dojo.removeClass(element, "middle-button-selected");
				else if(dojo.hasClass(element, "right-button")) dojo.removeClass(element, "right-button-selected");
			});
			
			if(dojo.hasClass(button, "left-button")) dojo.addClass(button, "left-button-selected");
			else if(dojo.hasClass(button, "middle-button")) dojo.addClass(button, "middle-button-selected");
			else if(dojo.hasClass(button, "right-button")) dojo.addClass(button, "right-button-selected");
			
			dojo.byId(name).value = value;
		});
	});
};
