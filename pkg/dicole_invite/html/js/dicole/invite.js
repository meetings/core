dojo.provide("dicole.invite");

dojo.require("dicole.base");
dojo.require("dicole.user_manager");

dojo.addOnLoad(function() {
	dicole.register_template("invite_accept_dialog", {templatePath: dojo.moduleUrl("dicole.invite", "invite_accept_dialog.html")});
	dicole.register_template("invite_dialog", {templatePath: dojo.moduleUrl("dicole.invite", "invite_dialog.html")});
	dicole.register_template("invite_dialog_user", {templatePath: dojo.moduleUrl("dicole.invite", "invite_dialog_user.html")});

	if(dicole.get_global_variable("open_invite_accept_dialog") ) {
		dicole.create_showcase({"width": 600, "disable_close": true, "reload_on_close" : true, "content": dicole.process_template("invite_accept_dialog", {
            "terms_of_usage_url": dicole.get_global_variable("tos_url"),
            "service_description_url": dicole.get_global_variable("service_url"),
            "privacy_policy_url": dicole.get_global_variable("privacy_url"),
			"banner_url": dicole.get_global_variable("banner_url"),
			"invite_target_name": dicole.get_global_variable("invite_target_name"),
			"url_after_login": dicole.get_global_variable("url_after_login"),
			"retrieve_password_url": dicole.get_global_variable("retrieve_password_url"),
			"register_url": dicole.get_global_variable("register_url"),
			"facebook_connect_app_id": dicole.get_global_variable("facebook_connect_app_id")
		})});
		
		var invite_login_button = dojo.byId("invite-login-button");
		if(invite_login_button) {
			if ( dojo.byId("invite_login_password") ) {
				dojo.connect(dojo.byId("invite_login_password"), "onkeydown", null, function(event) {
					if(event.keyCode == dojo.keys.ENTER) invite_login(event);
				});
			}
			if ( invite_login_button ) {
				dojo.connect(invite_login_button, "onclick", null, invite_login);
			}
			dojo.connect(dojo.byId("invite-login-form"), "onsubmit", null, invite_login);
		}
	}

	dojo.query(".js_hook_open_invite").forEach(function(invite_button) {
		if(!dicole.get_global_variable("invite_dialog_data_url")) return;
		dojo.connect(invite_button, "onclick", null, function(event) {
			dojo.stopEvent(event);
			dicole.create_showcase({"width": 628, "disable_close": true, "content": dicole.process_template("invite_dialog", {
				"group_name": dicole.get_global_variable("group_name"),
				"dialog_title": dicole.get_global_variable("invite_dialog_title"),
				"disable_force": dicole.get_global_variable("invite_disable_force"),
                "add_instantly_text" : dicole.get_global_variable("invite_add_instantly_text"),
				"default_subject": dicole.get_global_variable("invite_default_subject")
			})});
			
			var close_button = dojo.byId("invite_dialog_close");
			dojo.connect(close_button, "onclick", null, function(event) {
				dojo.stopEvent(event);
				dojo.publish("showcase.close");
			});
			
			var groups = null;
			var levels = null;
			var users = null;
			
			var group_select = dojo.byId("invite_dialog_groups");
			var browse_users_list = dojo.byId("invite_dialog_browse_users_list");
			var level_select = dojo.byId("invite_dialog_user_level");
			var level_select_label = dojo.byId("invite_dialog_user_level_label");
			
			var selected_users = {};
			var selected_users_number = dojo.byId("invite_dialog_selected_users_number");
			var selected_users_list = dojo.byId("invite_dialog_selected_users_list");
		    
            if ( dicole.get_global_variable("invite_levels_dialog_data_url") ) {
    			dojo.xhrPost({
	    			"url": dicole.get_global_variable("invite_levels_dialog_data_url"),
		    		"handleAs": "json",
			    	"handle": function(response) {
				    	if(response && response.result) {
					    	levels = response.result.levels;
						
        					dojo.forEach(levels, function(level) {
	        					dojo.create("option", {"value": level.value, "innerHTML": level.name}, level_select);
		        			});
						
			       			if(levels.length == 1) {
				        		dojo.style(level_select, "display", "none");
			    	    		dojo.style(level_select_label, "display", "none");
					        }
                        }
                    }
                } );
            
            }
			dojo.xhrPost({
				"url": dicole.get_global_variable("invite_dialog_data_url"),
				"handleAs": "json",
				"handle": function(response) {
					if(response && response.result) {
						groups = response.result.groups;
						users = response.result.users;
						
						dojo.forEach(groups, function(group) {
							dojo.create("option", {"value": group.value, "innerHTML": group.name}, group_select);
						});
                        
						if ( ! dicole.get_global_variable("invite_levels_dialog_data_url") ) {
						    levels = response.result.levels;

                            dojo.forEach(levels, function(level) {
	    						dojo.create("option", {"value": level.value, "innerHTML": level.name}, level_select);
		    				});
						
			    			if(levels.length == 1) {
					    		dojo.style(level_select, "display", "none");
				    			dojo.style(level_select_label, "display", "none");
						    }
                        }

						dojo.forEach(users, function(user, index) {
							dojo.place(dicole.process_template("invite_dialog_user", {"user": user}), browse_users_list);
							user.element = dojo.byId(user.id.toString());
							if(!((index + 1) % 7)) dojo.create("div", {"class": "invite_dialog_gridder"}, browse_users_list);
						});
						
						dojo.forEach(users, function(user) {
							dojo.connect(user.element, "onclick", null, function(event) {
								dojo.stopEvent(event);
								if(dojo.hasClass(user.element, "selected")) {
									dojo.removeClass(user.element, "selected");
									dojo.destroy(selected_users[user.id]);
									delete selected_users[user.id];
								}
								else {
									dojo.addClass(user.element, "selected");
									selected_users[user.id] = dojo.create("a", {
											"href": "#", 
											"innerHTML": user.name + " &#10006;",
											"class": "invite_dialog_selected_user"
										},
										selected_users_list
									);
									dojo.connect(selected_users[user.id], "onclick", null, function(event) {
										dojo.stopEvent(event);
										dojo.removeClass(user.element, "selected");
										dojo.destroy(selected_users[user.id]);
										delete selected_users[user.id];
										
										var number_of_selected_users = 0;
										for(var id in selected_users) ++number_of_selected_users;
										selected_users_number.innerHTML = number_of_selected_users.toString();
									});
								}
								var number_of_selected_users = 0;
								for(var id in selected_users) ++number_of_selected_users;
								selected_users_number.innerHTML = number_of_selected_users.toString();
							});
						});
					}
					else alert(response.error);
				}
			});
			
			var browse_users_toggle = dojo.byId("invite_dialog_browse_users_toggle");
			var browse_users = dojo.byId("invite_dialog_browse_users_container");
			dojo.connect(browse_users_toggle, "onclick", null, function(event) {
				dojo.stopEvent(event);
				if(dojo.style(browse_users, "display") == "none") dojo.style(browse_users, "display", "block");
				else dojo.style(browse_users, "display", "none");
			});
			
			var title_toggle = dojo.byId("invite_dialog_title_toggle");
			var title_container = dojo.byId("invite_dialog_title_container");
			dojo.connect(title_toggle, "onclick", null, function(event) {
				dojo.stopEvent(event);
				if(dojo.style(title_container, "display") == "none") dojo.style(title_container, "display", "block");
				else dojo.style(title_container, "display", "none");
			});
			
			var message_toggle = dojo.byId("invite_dialog_message_toggle");
			var message = dojo.byId("invite_dialog_message_container");
			dojo.connect(message_toggle, "onclick", null, function(event) {
				dojo.stopEvent(event);
				if(dojo.style(message, "display") == "none") dojo.style(message, "display", "block");
				else dojo.style(message, "display", "none");	
			});
			
			var search_field = dojo.byId("invite_dialog_search_users");
			dojo.connect(search_field, "onkeyup", null, function(event) {
				dicole.invite.filter_users(users, search_field, selected_group);
			});	
			
			var selected_group = 0;
			dojo.connect(group_select, "onchange", null, function(event) {
				selected_group = Number(group_select.value);
				dicole.invite.filter_users(users, search_field, selected_group);
			});
			
			var add_instantly = dojo.byId("invite_dialog_add_instantly");
			var send_invitation = dojo.byId("invite_dialog_send_invitation");
			if ( add_instantly && send_invitation ) {
				dojo.connect(add_instantly, "onclick", null, function(event) {
					if(add_instantly.checked) send_invitation.disabled = false;
					else {
						send_invitation.disabled = true;
						send_invitation.checked = false;
					}
				});
			}
			
			var emails = dojo.byId("invite_dialog_emails");
			var send_invite_button = dojo.byId("invite_dialog_send_button");
			var greeting_subject = dojo.byId("invite_dialog_title");
			var greeting_message = dojo.byId("invite_dialog_message");

			dojo.connect(send_invite_button, "onclick", null, function(event) {
				dojo.stopEvent(event);
				dojo.xhrPost({
					"url": dicole.get_global_variable("invite_submit_url"),
					"content": {
						"emails": emails.value,
						"users": function(){var u = []; for(var id in selected_users){ u.push(id); } return u.join(",");}(),
						"add_instantly": add_instantly ? add_instantly.checked ? 1 : 0 : 0,
						"send_invitation": send_invitation ? send_invitation.checked ? 1 : 0 : 0,
						"greeting_subject": greeting_subject.value,
						"greeting_message": greeting_message.value,
						"level": level_select.value
					},
					"handleAs": "json",
					"handle": function(response) {
						if(response && response.result && response.result.success) location.reload(true);
						else alert(response.error);
					}
				});
			});
		});
	});
});

var invite_login = function(event) {
	dojo.stopEvent(event);
	dojo.xhrPost({
		"url": "/rpc_login/",
		"content": {
			"login_login_name" : dojo.byId("invite_login_login_name") ? dojo.byId("invite_login_login_name").value : "",
			"login_password" : dojo.byId("invite_login_password") ? dojo.byId("invite_login_password").value : "",
			"login_remember" :  dojo.byId("invite_login_remember") ? dojo.byId("invite_login_remember").value : "",
			"url_after_login" : dojo.byId("invite_url_after_login") ? dojo.byId("invite_url_after_login").value : ""
		},
		"handleAs": "json",
		"handle": function(response) {
			if(response.success) window.location = response.location;
			else {
				var message_box = dojo.byId("invite_accept_dialog_message_box");
				message_box.innerHTML = response.reason;
				dojo.style(message_box, "display", "block");
			}
		}
	});
};

dicole.invite.user_has_group = function(user, selected_group) {
	for(var group in user.groups) if(user.groups[group] == selected_group) return true;
	return false;
};

dicole.invite.filter_users = function(users, search_field, selected_group) {
	if(search_field.value != search_field.defaultValue && search_field.value.length) {
		dojo.forEach(users, function(user) {
			var user_name = user.name;
			if(user_name.toLowerCase().indexOf(search_field.value.toLowerCase()) != -1) {
				if(selected_group) {
					if(dicole.invite.user_has_group(user, selected_group)) user.element.style.display = "block";
					else user.element.style.display = "none";
				}
				else user.element.style.display = "block";
			}
			else user.element.style.display = "none";
		});
	}
	else {
		if(selected_group) {
			dojo.forEach(users, function(user) {
				if(dicole.invite.user_has_group(user, selected_group)) user.element.style.display = "block";
				else user.element.style.display = "none";
			});
		}
		else dojo.forEach(users, function(user) { user.element.style.display = "block" });
	}
	dojo.query(".invite_dialog_gridder").forEach(dojo.destroy);
	var visible_count = 0;
	dojo.forEach(users, function(user) {
		if(user.element.style.display == "block") ++visible_count;
		if(!(visible_count % 7)) dojo.create("div", {"class": "invite_dialog_gridder"}, user.element, "after");
	});
};
