dojo.provide('dicole.events');

dojo.require("dicole.base");
dojo.require("dicole.event_source.ServerConnection");
dojo.require("dojo.window");

var filters = {
	"participant-yes": false,
	"participant-maybe": false,
	"participant-no": false,
	"participant-waiting": false,
	"participant-planner": false
};
var export_url = null;

var event_server_connection = null;
var last_poll_time = 0;
var last_timer_time = 0;
var page_load_time = new Date().getTime();
var timer_has_hit_bottom = 0;
var session = null;
var polling = null;
var flying_chat_message_sent = 0;

var chat_state = [];

dojo.addOnWindowUnload( function() { try { if(event_server_connection) event_server_connection.close(); } catch(error) {} } );

var save_buttons = null;

dojo.addOnLoad(function() {
	dicole.events.process_events_more();

	var comments_container = dojo.byId("comments_container");
    if (comments_container) {
	    dojo.query(".comment", comments_container).forEach(function(comment) {
		    chat_state.push(comment.id);
		});
		process_chat();
    }

    if ( dicole.get_global_variable('events_change_topic') || dicole.get_global_variable('events_comment_state_url') ) {
        start_event_server_polling();
        ensure_continuous_polling();
    }

    start_timer_updating();
	
	save_buttons = dojo.query(".create-button, .save-button");
	
	var export_button = dojo.byId("export-this-list");
	if(export_button) {
		export_url = export_button.href;
		filter_participants();
	}

	var show_description = dojo.byId("show-description");
	var hide_description = dojo.byId("hide-description");
	var shown_container = dojo.byId("events-description-shown");
	var hidden_container = dojo.byId("events-description-hidden");
	if( show_description && hide_description && shown_container && hidden_container ) {
		dojo.connect(show_description, "onclick", null, function(event) {
			dojo.stopEvent(event);
			dojo.style(shown_container, "display", "block");
			dojo.style(hidden_container, "display", "none");
		} );
		dojo.connect(hide_description, "onclick", null, function(event) {
			dojo.stopEvent(event);
			dojo.style(shown_container, "display", "none");
			dojo.style(hidden_container, "display", "block");
		} );
	}
	
	var open_boxes_ids = {"rsvp-yes": "attending-box", "participant-button" : "participant-box", "accept-button": "accept-box", "suggest-invite-button" : "accept-box" };
	dojo.forEach(function() { var keys = []; for( var ke in open_boxes_ids) { keys.push(ke); } return keys; }(), function(open_boxes_id) {
		var open_button = dojo.byId(open_boxes_id);
		if(open_button) {
			dojo.connect(open_button, "onclick", null, function(event) {
				dojo.stopEvent(event);
				open_showcase(open_boxes_ids[open_boxes_id]);
			});
		}
	});

    dojo.query('.js_invite_rsvp').forEach( function( open_button ) {
        dojo.connect(open_button, "onclick", null, function(event) {
            dojo.stopEvent(event);
            open_showcase('accept-box');
            var iual = dojo.byId('invite_url_after_login');
            if ( iual ) {
                iual.value = open_button.href;
            }
            dicole.set_global_variable('url_after_register', open_button.href);
        });
    } );
	
	var twitter_box = dojo.byId("stupid-twitter-box");
	if(twitter_box) {
		dojo.place(twitter_box, "stupid-twitter-box-placeholder", "replace");
	}
	
	var remove_banner_button = dojo.byId("remove-banner");
	if(remove_banner_button) {
		dojo.connect(remove_banner_button, "onclick", null, function(event) {
			dojo.stopEvent(event);
			dojo.destroy("banner");
			dojo.create("input", {"type": "hidden", "name": "remove_banner", "value": "1"}, remove_banner_button, "replace");
		});
	}
	
	var remove_logo_button = dojo.byId("remove-logo");
	if(remove_logo_button) {
		dojo.connect(remove_logo_button, "onclick", null, function(event) {
			dojo.stopEvent(event);
			dojo.destroy("logo");
			dojo.create("input", {"type": "hidden", "name": "remove_logo", "value": "1"}, remove_logo_button, "replace");
		});
	}
	
	var abstract_field = dojo.byId("abstract-edit");
	if(abstract_field) {
		var abstract_letters_left_field = dojo.byId("abstract-letters-left");
		abstract_letters_left_field.innerHTML = abstract_field.value.length;
		if(abstract_field.value.length > 200) dojo.addClass(abstract_letters_left_field, "negative");
		
		var abstract_letters_left = function(event) {
			var letters_left = 200 - abstract_field.value.length;
			abstract_letters_left_field.innerHTML = letters_left;
			if(letters_left <= 0) {
				dojo.addClass(abstract_letters_left_field, "negative");
				modify_save_buttons("abstract", false);
			}
			else {
				dojo.removeClass(abstract_letters_left_field, "negative");
				modify_save_buttons("abstract", true);
			}
		};
		
		dojo.connect(abstract_field, "onkeypress", null, abstract_letters_left);
		dojo.connect(abstract_field, "onkeyup", null, abstract_letters_left);
		dojo.connect(abstract_field, "onfocus", null, abstract_letters_left);
		dojo.connect(abstract_field, "onblur", null, abstract_letters_left);
		
		abstract_letters_left();
	}
	
	var unlimited_seats = dojo.byId("unlimited-seats");
	var limited_seats = dojo.byId("limited-seats");
	if(unlimited_seats && limited_seats) {
		var seats = dojo.byId("seats");
		dojo.connect(unlimited_seats, "onclick", null, function(event) {
			dojo.stopEvent(event);
			dojo.removeClass(limited_seats, "right-button-selected");
			dojo.addClass(unlimited_seats, "left-button-selected");
			dojo.style(seats, "display", "none");
			seats.value = 0;
		});
		dojo.connect(limited_seats, "onclick", null, function(event) {
			dojo.stopEvent(event);
			dojo.removeClass(unlimited_seats, "left-button-selected");
			dojo.addClass(limited_seats, "right-button-selected");
			dojo.style(seats, "display", "inline");
		});
	}
	
	var map_on = dojo.byId("map-on");
	var map_off = dojo.byId("map-off");
	if(map_on && map_off) {
		var map_field = dojo.byId("show-map");
		dojo.connect(map_on, "onclick", null, function(event) {
			dojo.stopEvent(event);
			dojo.removeClass(map_off, "right-button-selected");
			dojo.addClass(map_on, "left-button-selected");
			map_field.value = 'all';
		});
		dojo.connect(map_off, "onclick", null, function(event) {
			dojo.stopEvent(event);
			dojo.removeClass(map_on, "left-button-selected");
			dojo.addClass(map_off, "right-button-selected");
			map_field.value = 'none';
		});
	}
	
	var location_field = dojo.byId("location-field");
	if(location_field) {
        // For some reason the callback parameter does not work if used
        // with the dojo style which generates it's own function and attaches
        // it to the load function.. so we just use our own callback
//            callbackParamName: "callback",
//            load : function() {
//                dicole.events.location_loop();                  
//            },
        dojo.io.script.get( {
            url: "https://maps-api-ssl.google.com/maps/api/js",
            content : {
                v : "3",
                callback: "dicole.events.location_loop",
                sensor: "false"
            }
        } );
    }
	
	var require_phone_box = dojo.byId("require-phone");
	if(require_phone_box) {
		dojo.connect(require_phone_box, "onclick", null, function(event) {
			if(dojo.attr(require_phone_box, "checked")) require_phone_box.value = 1;
			else require_phone_box.value = 0;
		});
	}
	
	var user_invite_box = dojo.byId("user-invite");
	if(user_invite_box) {
		dojo.connect(user_invite_box, "onclick", null, function(event) {
			if(dojo.attr(user_invite_box, "checked")) user_invite_box.value = 1;
			else user_invite_box.value = 0;
		});
	}
	
	var public_button = dojo.byId("public-button");
	var public_description = dojo.byId("public-description");
	var private_button = dojo.byId("private-button");
	var private_description = dojo.byId("private-description");
	if(public_button && private_button) {
		var event_state_field = dojo.byId("event-state");
		dojo.connect(public_button, "onclick", null, function(event) {
			dojo.stopEvent(event);
			dojo.removeClass(private_button, "right-button-selected");
			dojo.addClass(public_button, "left-button-selected");
			event_state_field.value = "public";
			dojo.style(public_description, "display", "block");
			dojo.style(private_description, "display", "none");
			dojo.attr(user_invite_box, "checked", true);
			user_invite_box.value = 1;
		});
		dojo.connect(private_button, "onclick", null, function(event) {
			dojo.stopEvent(event);
			dojo.removeClass(public_button, "left-button-selected");
			dojo.addClass(private_button, "right-button-selected");
			event_state_field.value = "private";
			dojo.style(public_description, "display", "none");
			dojo.style(private_description, "display", "block");
		});
	}
	
	var delete_event_button = dojo.byId("delete-event");
	if(delete_event_button) {
		dojo.connect(delete_event_button, "onclick", null, function(event) {
			dojo.stopEvent(event);
			dojo.style(dojo.byId("delete-event-confirm"), "display", "block");
		});
	}
	
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
			
			dojo.byId(name + "_field").value = value;
		});
	});
	
	if(dojo.byId("open-attending-box-right-now")) open_showcase("attending-box");
	//if(dojo.byId("open-accept-box-right-now")) open_showcase("accept-box");

	var participants_url_node = dojo.byId('participants-url');
	if ( participants_url_node ) {
		dojo.query('.participant-rsvp').forEach( function( participant_rsvp_node ) {
			var user_id = participant_rsvp_node.id.split("-",3)[2];
			dojo.forEach( [ 'yes', 'maybe', 'no' ], function( rsvp_name ) {
				dojo.query("a.participant-" + rsvp_name, participant_rsvp_node ).forEach( function(element) {
					dojo.connect( element, 'onclick', null, function( event ) {
						dojo.stopEvent( event );
						var new_rsvp_name = rsvp_name;
						dojo.forEach( [ 'left', 'middle', 'right' ], function( position ) {
							if ( dojo.hasClass( element, position + '-button-selected' ) ) {
								new_rsvp_name = 'waiting';
							}
						} );
						dojo.xhrPost( {
							url : participants_url_node.href,
							content : { user_id : user_id, rsvp_name : new_rsvp_name },
							handleAs : 'json',
							load : function( data ) {
								if ( data.result ) {
									dojo.forEach( [ 'yes', 'maybe', 'no' ], function( rsvp_name ) {
										dojo.query("a.participant-" + rsvp_name, participant_rsvp_node ).forEach( function(element) {
											if(dojo.hasClass(element, "left-button")) dojo.removeClass(element, "left-button-selected");
											else if(dojo.hasClass(element, "middle-button")) dojo.removeClass(element, "middle-button-selected");
											else if(dojo.hasClass(element, "right-button")) dojo.removeClass(element, "right-button-selected");
										} );
										dojo.query("a.participant-" + data.result.rsvp_name, participant_rsvp_node ).forEach( function(element) {
											if(dojo.hasClass(element, "left-button")) dojo.addClass(element, "left-button-selected");
											else if(dojo.hasClass(element, "middle-button")) dojo.addClass(element, "middle-button-selected");
											else if(dojo.hasClass(element, "right-button")) dojo.addClass(element, "right-button-selected");
										} );
									} );
									filter_participants();
								}
								else {
									alert( data.error.reason );
								}
							}
						} );
					} );
				} );
			} );
		} );
	}
	
	var date_fields = [
		{
			"begin_date": "begin_date", 
			"end_date": "end_date",
			"begin_time": "begin_time",
			"end_time": "end_time"
		}, 
		{
			"begin_date": "reg_begin_date",
			"end_date": "reg_end_date",
			"begin_time": "reg_begin_time",
			"end_time": "reg_end_time"
		}
	];
	
	dojo.forEach(date_fields, function(input_quad) {
		var begin_date_field = dojo.byId(input_quad.begin_date);
		var end_date_field = dojo.byId(input_quad.end_date);
		var begin_time_field = dojo.byId(input_quad.begin_time);
		var end_time_field = dojo.byId(input_quad.end_time);
		
		if(begin_date_field && end_date_field && begin_time_field && end_time_field) {
			var beginFormElements = {};
			beginFormElements[input_quad.begin_date] = "d-sl-m-sl-Y";
			datePickerController.createDatePicker({
				formElements: beginFormElements,
				callbackFunctions: {
					"dateset": [dojo.partial(date_callback, input_quad)]
				}
			});
			var endFormElements = {};
			endFormElements[input_quad.end_date] = "d-sl-m-sl-Y";
			datePickerController.createDatePicker({
				formElements: endFormElements,
				callbackFunctions: {
					"dateset": [dojo.partial(date_callback, input_quad)]
				}
			});
			dojo.connect(begin_date_field, "onclick", null, dojo.partial(datePickerController.show, input_quad.begin_date));
			dojo.connect(end_date_field, "onclick", null, dojo.partial(datePickerController.show, input_quad.end_date));
			dojo.connect(begin_time_field, "onclick", null, function() { begin_time_field.focus(); begin_time_field.select(); });
			dojo.connect(end_time_field, "onclick", null, function() { end_time_field.focus(); end_time_field.select(); });
			dojo.connect(begin_time_field, "onblur", null, dojo.partial(time_callback, input_quad, begin_time_field));
			dojo.connect(end_time_field, "onblur", null, dojo.partial(time_callback, input_quad, end_time_field));
		}
	});
	
	dojo.query(".tip-field").forEach(function(tip_field) {
		var tip = tip_field.value;
		dojo.connect(tip_field, "onfocus", null, function() {
			if(tip_field.value == tip) tip_field.value = "";
		});
		dojo.connect(tip_field, "onblur", null, function() {
			if(!tip_field.value.length) tip_field.value = tip;
		});
	});
	
	var button_types = ["left", "middle", "right"];
	var filter_buttons = dojo.query(".filter-button");
	filter_buttons.forEach(function(filter_button) {
		dojo.connect(filter_button, "onclick", null, function(event) {
			dojo.stopEvent(event);
			dojo.forEach(button_types, function(button_type) {
				if(dojo.hasClass(filter_button, button_type + "-button")) {
					dojo.toggleClass(filter_button, button_type + "-button-selected");
					if(dojo.hasClass(filter_button, button_type + "-button-selected")) filters[filter_button.id] = true;
					else filters[filter_button.id] = false;
					filter_participants();
				}
			});
		});
	});
	
	dojo.query(".participant-rsvp-container").forEach(function(participant) {
		var planner_field = dojo.query(".participant-planner", participant)[0];
		var planner_button = dojo.query("a.planner", participant)[0];
		if(planner_button) {
			dojo.connect(planner_button, "onclick", null, function(event) {
				dojo.stopEvent(event);
				dojo.xhrPost({
					"url": planner_button.href,
					"handleAs": "json",
					"handle": function(response) {
						if(response && response.success) {
							if(response.is_planner) {
								dojo.addClass(planner_field, "left-button-selected");
								dojo.addClass(planner_button, "planner_is_planner");
								filter_participants();
							}
							else {
								dojo.removeClass(planner_field, "left-button-selected");
								dojo.removeClass(planner_button, "planner_is_planner");
								filter_participants();
							}
						}
						else alert("Unexpected error. Please try again.");
					}
				});
			});
		}
	});
		
	var title_field = dojo.byId("title");
    if ( title_field ) {
        dojo.connect(title_field, "onkeyup", null, function() {
            if(!title_field.value.length) modify_save_buttons("title", false);
            else modify_save_buttons("title", true);
        });
        
        if(!title_field.value.length) modify_save_buttons("title", false);
        else modify_save_buttons("title", true);
        
        if(dojo.hasClass(title_field, "default")) modify_save_buttons("title", false);
	}
	
	var mail_button = dojo.byId("mail-participants");
	if(mail_button) {
		var mail_form = dojo.byId("mail-form");
		dojo.connect(mail_button, "onclick", null, function(event) {
			dojo.stopEvent(event);
			dojo.toggleClass(mail_button, "button-selected");
			if(dojo.hasClass(mail_button, "button-selected")) dojo.style(mail_form, "display", "block");    
			else dojo.style(mail_form, "display", "none");
		});
	}
	
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
	
	var register_email = dojo.byId("register_email");
	if(register_email) {
		dojo.forEach(["register_first_name", "register_last_name", "register_email"], function(form_field) {
			dojo.connect(dojo.byId(form_field), "onkeydown", null, function(event) {
				if(event.keyCode == dojo.keys.ENTER) register_submit(event);
			});
		});
		dojo.connect(dojo.byId("register-submit-button"), "onclick", null, register_submit);
		dojo.connect(dojo.byId("register-form"), "onsubmit", null, register_submit);
	}
	
	var remove_links = dojo.byId("remove-links");
	if(remove_links) {
		dojo.query(".tool a").forEach(function(link) {
            if ( ! dojo.hasClass(link, 'js_invite_rsvp') ) {
    			link.href = "#";
            }
		});
	}
	
	var imedia_placeholder = dojo.byId("imedia-placeholder");
	if(imedia_placeholder) {
        dicole.register_template("inline_media", {templatePath: dojo.moduleUrl("dicole.events", "inline_media.html")});
		var imedias = dojo.query(".inline-media");
		imedias.forEach(function(imedia) {
			dojo.query(".inline-media-link", imedia).forEach(function(imedia_link) {
				dojo.connect(imedia_link, "onclick", null, function(event) {
					dojo.stopEvent(event);
					dojo.xhrGet({
						"url": dojo.attr(imedia, "title"),
						"handleAs": "json",
						"handle": function(response) {
							if(response && response.result) {
								imedias.removeClass("selected");
                                dicole.events.select_imedia( imedia, response.result, imedia_placeholder );
							}
						}
					});
				});
			});
		});
		
		if(imedias[0]) {
			dojo.xhrGet({
				"url": dojo.attr(imedias[0], "title"),
				"handleAs": "json",
				"handle": function(response) {
					if(response && response.result) {
                        dicole.events.select_imedia( imedias[0], response.result, imedia_placeholder, true );
					}
				}
			});
		}
	}
	
	var chat_input = dojo.byId("chat_input");
	var chat_send = dojo.byId("chat_send");
	if(chat_input && chat_send) {

		var chat_send_function = function(event) {
			dojo.stopEvent(event);

            if ( flying_chat_message_sent && flying_chat_message_sent + 5 < new Date().getTime() ) {
                return;
            }

            if( ! chat_input.value.length || chat_input.value == chat_input.defaultValue ) {
                return;
            }

            dojo.addClass(chat_send, "button-disabled");
	    	dojo.style(chat_input, "color", "#AAA");

            var this_chat_message_sent = new Date().getTime();
            flying_chat_message_sent = this_chat_message_sent;

            dojo.xhrPost({
				"url": dicole.get_global_variable("events_comment_add_url"),
				"handleAs": "json",
				"content": {"content": dojo.trim(dojo.byId("chat_input").value)},
				"handle": function(response) {
					if(response && response.state) {
						chat_input.value = "";
						update_chat(response.state);
					}
                    if ( flying_chat_message_sent == this_chat_message_sent ) {
                        flying_chat_message_sent = 0;
	                    if( chat_input.value.length && chat_input.value != chat_input.defaultValue ) {
                            dojo.removeClass(chat_send, "button-disabled");
  	    					dojo.style(chat_input, "color", "inherit");
                        }
                    }
				}
			});
		};
		
		dojo.connect(chat_send, "onclick", null, chat_send_function );
		dojo.connect(chat_input, "onkeydown", null, function(event) {
			if(event.keyCode == dojo.keys.ENTER) {
                chat_send_function( event );
            }
        } );
		
		var oninput = function(event) {
			if(!chat_input.value.length || chat_input.value == chat_input.defaultValue) {
				dojo.addClass(chat_send, "button-disabled");
				dojo.style(chat_input, "color", "#AAA");
			}
            else if ( ! flying_chat_message_sent || flying_chat_message_sent + 5 > new Date().getTime() ) {
				dojo.removeClass(chat_send, "button-disabled");
				dojo.style(chat_input, "color", "inherit");
			}
//			if(event && event.type == "focus") dojo.style(chat_input, "color", "inherit");
//			else if(event && event.type == "blur") dojo.style(chat_input, "color", "#AAA");
		};
		
		dojo.connect(chat_input, "onfocus", null, oninput);
		dojo.connect(chat_input, "onblur", null, oninput);
		dojo.connect(chat_input, "onkeyup", null, oninput);	
		dojo.connect(chat_input, "onkeyup", null, dojo.partial(autoresize_textarea, chat_input));
		dojo.connect(chat_input, "onkeydown", null, dojo.partial(autoresize_textarea, chat_input));

        oninput();	
	}
});

var check_for_page_refresh = function() {
    if ( ! timer_has_hit_bottom || ! dojo.byId("event_counter") ) { return }

    dojo.xhrPost({
		"url": dicole.get_global_variable("events_change_refresh_url"),
		"handleAs": "json",
		"handle": function(response) {
			if(response && response.refresh) if(response.refresh == 1) location.reload(true);
		}
	});
};

var build_timeleft_string = function(seconds) {
	if(!seconds) return dicole.msg("The event has started.");
	var days = Math.floor(seconds / 60 / 60 / 24);
	seconds -= days * 60 * 60 * 24;
	var hours = Math.floor(seconds / 60 / 60);
	seconds -= hours * 60 * 60;
	var minutes = Math.floor(seconds / 60);
	seconds -= minutes * 60;
	if(days) return dicole.msg("[_1] days, [_2] hours, [_3] minutes and [_4] seconds until the event starts.", [days, hours, minutes, seconds]);
	if(hours) return dicole.msg("[_1] hours, [_2] minutes and [_3] seconds until the event starts.", [hours, minutes, seconds]);
	if(minutes) return dicole.msg("[_1] minutes and [_2] seconds until the event starts.", [minutes, seconds]);
	return dicole.msg("[_1] seconds until the event starts.", [seconds]);
};

dicole.events.select_imedia = function( imedia, result, imedia_placeholder, skip_scroll ) {
    var imedia_html = dicole.process_template("inline_media", result );
    imedia_placeholder.innerHTML = imedia_html;
    dojo.publish("new_node_created", [imedia_placeholder]);
    dojo.addClass(imedia, "selected");
    if ( ! skip_scroll ) {
        dojo.window.scrollIntoView( imedia_placeholder );
    }
}

var modify_button_states = {"title": true, "abstract": true};
var modify_button_connections = {};
function modify_save_buttons(state_name, state) {
	modify_button_states[state_name] = state;
	if(function() { var state = true; for(var key in modify_button_states) { if(!modify_button_states[key]) state = false; } return state; }()) {
		save_buttons.forEach(function(button) {
			dojo.removeClass(button, "yellow-button-disabled");
			if(modify_button_connections[button.id]) {
				dojo.disconnect(modify_button_connections[button.id]);
				delete modify_button_connections[button.id];
			}
		});
	}
	else {
		save_buttons.forEach(function(button) {
			dojo.addClass(button, "yellow-button-disabled");
			modify_button_connections[button.id] = dojo.connect(dojo.query("input", button)[0], "onclick", null, dojo.stopEvent);
		});
	}
}

function autoresize_textarea(element, event) {
	var cols = dojo.attr(element, "cols");
	var lines = 0;
	dojo.forEach(element.value.split("\n"), function(line) {
		lines += Math.ceil((line.length ? line.length : 1) / cols);
	});
	dojo.attr(element, "rows", lines);
}

function in_array(array, value) {
	for(var index in array) if(array[index] == value) return true;
	return false;
}

function restart_event_server_polling() {
    try { event_server_connection.close(); } catch (error) {}
    start_event_server_polling();
}

function start_event_server_polling() {
    last_poll_time = new Date().getTime();
    event_server_connection = new dicole.event_source.ServerConnection(dicole.get_global_variable("event_server_url"));
	var instant_authorization_key_url = dicole.get_global_variable("instant_authorization_key_url");
	var domain_host = dicole.get_global_variable("domain_host");
	dojo.xhrPost({
		"url": instant_authorization_key_url,
		"handleAs": "json",
		"handle": function(response) {
			event_server_connection.open(domain_host, {"token": response.result}, function(response) {
				session = response.result.session;
				
				if ( dojo.byId("comments_container") ) {
					var thread_id = dicole.get_global_variable("events_comment_thread_id");					
	        		event_server_connection.subscribe({
    		    		"name": thread_id.toString(),
	    			    "limit_topics": [["comment_thread:" + thread_id]] 
		    	    });
				}

                if ( dojo.byId("event_counter") ) {
					var topic = dicole.get_global_variable("events_change_topic");
					event_server_connection.subscribe({
						"name": topic,
						"limit_topics": [[topic]]
					});
                }
                // We need to refresh state here so that we don't miss
                // update events that happened while page was loading
                refresh_chat_state();

                poll_event_server();
			});
		}
	}); 
}

function poll_event_server() {
	var topic = dicole.get_global_variable("events_change_topic");

    var current_poll_start_time = new Date().getTime();
    last_poll_time = current_poll_start_time;
    
	event_server_connection.poll(1, function(response) {
        if ( last_poll_time != current_poll_start_time ) { return; }

        if(response && response.result) {
			if( topic && response.result[topic] && response.result[topic]['new'].length) check_for_page_refresh();

            var keys_in_result = 0;
            for(var name in response.result) {
                keys_in_result = keys_in_result + 1;
				if(response.result[name]['new'].length) {
                    refresh_chat_state();
    			}
			}

            if ( keys_in_result == 0 ) {
                restart_event_server_polling();
            }
            else {
                poll_event_server();
            }
		}
		else if(response && response.error && response.error.code == 603) poll_event_server();
        else restart_event_server_polling();
	});
}

function refresh_chat_state() {
    if ( ! dicole.get_global_variable("events_comment_state_url") ) {
        return;
    }
    dojo.xhrPost({
		"url": dicole.get_global_variable("events_comment_state_url"),
		"handleAs": "json",
		"handle": function(response) {
			if(response && response.state) {
				update_chat(response.state);
			}
		}
	});
}

function start_timer_updating() {
	var event_counter = dojo.byId("event_counter");
	if(event_counter) {
        update_timer();
    }
}

function get_seconds_until_start() {
    var load_seconds_until_start = dicole.get_global_variable("events_seconds_until_start");
    var seconds_until_start = load_seconds_until_start - Math.floor( ( new Date().getTime() - page_load_time ) / 1000 );
    if ( seconds_until_start < 0 ) seconds_until_start = 0;
    return seconds_until_start;
}

function update_timer( my_caller_time ) {
    if ( my_caller_time && my_caller_time != last_timer_time ) { return }

    var current_timer_date = new Date().getTime();
    last_timer_time = current_timer_date;

    var seconds_until_start = get_seconds_until_start();

	var event_counter = dojo.byId("event_counter");
	if ( event_counter ) {
		event_counter.innerHTML = build_timeleft_string( seconds_until_start );
    }

    if ( ! seconds_until_start ) {
        if ( ! timer_has_hit_bottom ) {
            timer_has_hit_bottom = 1;
            check_for_page_refresh();
            return;
        }
    }

    setTimeout( function() { update_timer( current_timer_date ); }, 1000 );
}

function ensure_continuous_polling() {
    var now = new Date().getTime();
    try {
        if ( last_poll_time + 1000*60 < now ) {
            restart_event_server_polling();
        }
    }
    catch (error) {}

    try {
        if ( last_timer_time + 1000*5 < now ) {
            if ( ! timer_has_hit_bottom ) {
                update_timer();
            }
        }
    }
    catch (error) {}

    setTimeout( function() { ensure_continuous_polling() }, 1000 );
}

function filter_array(array, predicate) {
	var new_array = [];
	for(var index in array) if(predicate(array[index])) new_array.push(array[index]);
	return new_array;
}

function update_chat(new_state) {
	var comments_container = dojo.byId("comments_container");

	var new_comments = filter_array(new_state, function(item) {
		return !in_array(chat_state, item);
	});
	
	dojo.forEach(new_comments, function(id) {
		dojo.create("div", {"id": id}, comments_container, "first");
	});
	
	var old_comments = filter_array(chat_state, function(item) {
		return !in_array(new_state, item);
	});
	
	dojo.forEach(old_comments, function(id) {
		dojo.destroy(dojo.byId(id.toString()));
	});
	
	if(new_comments.length) {
		dojo.xhrPost({
			"url": dicole.get_global_variable("events_comment_info_url"),
			"handleAs": "json",
			"content": {"comment_id_list": dojo.toJson(new_comments)},
			"handle": function(response) {
				if(response && response.comments) {
					for(var key in response.comments) {
						dojo.place(response.comments[key], dojo.byId(key), "replace");
					}
					process_chat();
				}
			}
		});
	}
	
	process_chat();
	chat_state = new_state;
}

function process_chat() {
	dicole.ucq("comment", "comments_container").forEach(function(comment) {
		var actions = dojo.query(".comment_actions", comment)[0];
		var confirm = dojo.query(".confirm", comment)[0];
		dojo.query(".delete_comment", actions).forEach(function(delete_comment) {
			dojo.connect(delete_comment, "onclick", null, function(event) {
				dojo.stopEvent(event);
				dojo.style(actions, "display", "none");
				dojo.style(confirm, "display", "block");
			});
		});
		dojo.query(".confirm_delete", confirm).forEach(function(confirm_delete) {
			dojo.connect(confirm_delete, "onclick", null, function(event) {
				dojo.stopEvent(event);
				dojo.xhrPost({
					"url": confirm_delete.href,
					"handleAs": "json",
					"handle": function(response) {
						if(response && response.state) {
							dojo.style(confirm, "display", "none");
							dojo.style(actions, "display", "block");
							update_chat(response.state);
						}
					}
				});
			});
		});
		dojo.query(".cancel_delete", confirm).forEach(function(cancel_delete) {
			dojo.connect(cancel_delete, "onclick", null, function(event) {
				dojo.stopEvent(event);
				dojo.style(confirm, "display", "none");
				dojo.style(actions, "display", "block");
			});
		});
	});
}

var date_callback = function(input_quad, data) {
	var begin_date = datePickerController.getSelectedDate(input_quad.begin_date);
	var end_date = datePickerController.getSelectedDate(input_quad.end_date);
	if(data.id == input_quad.begin_date) {
		if(begin_date.getTime() > end_date.getTime()) {
			var date = "" + data.yyyy;
			data.mm < 10 ? date += "0" + data.mm : date += data.mm;
			data.dd < 10 ? date += "0" + data.dd : date += data.dd;
			datePickerController.setSelectedDate(input_quad.end_date, date);
			time_callback(input_quad);
		}
	}
	else if(data.id == input_quad.end_date) {
		if(end_date.getTime() < begin_date.getTime()) {
			var date = "" + data.yyyy;
			data.mm < 10 ? date += "0" + data.mm : date += data.mm;
			data.dd < 10 ? date += "0" + data.dd : date += data.dd;
			datePickerController.setSelectedDate(input_quad.begin_date, date);
			time_callback(input_quad);
		}
	}
};

var time_callback = function(input_quad, target) {
	var begin_time_field = dojo.byId(input_quad.begin_time);
	var end_time_field = dojo.byId(input_quad.end_time);
	
	var begin = get_time_from_string(begin_time_field.value);
	var end = get_time_from_string(end_time_field.value);
	
	if(!begin) {
		begin_time_field.value = "12:00";
		begin = get_time_from_string(begin_time_field.value);
	}
	
	if(!end) {
		end_time_field.value = "12:00";
		end = get_time_from_string(end_time_field.value);
	}
	
	var begin_time = Number(begin.hours) * 1000 + Number(begin.minutes);
	var end_time = Number(end.hours) * 1000 + Number(end.minutes);
	var begin_date = datePickerController.getSelectedDate(input_quad.begin_date);
	var end_date = datePickerController.getSelectedDate(input_quad.end_date);
	
	if(begin_date.getTime() == end_date.getTime()) {
		if(target) {
			if(target == begin_time_field && begin_time > end_time) end_time_field.value = begin_time_field.value;
			else if(target == end_time_field && end_time < begin_time) begin_time_field.value = end_time_field.value;
		}
		else if(begin_time > end_time || end_time < begin_time) {
			begin_time_field.value = end_time_field.value;
		}
	}
};

var get_time_from_string = function(string) {
	var split = string.split(":");
	if(split && split.length == 2) {
		var hours = Number(split[0]);
		var minutes = Number(split[1]);
		if(isNaN(hours) || isNaN(minutes) || hours < 0 || hours > 24 || minutes < 0 || minutes > 59) return false;
		return {"hours": hours, "minutes": minutes};
	}
};

var open_showcase = function(id) {
	var showcase = dojo.byId(id);
	var showcase_close = dojo.byId("close-" + id);
	if(id == "participant-box") {
		dicole.create_showcase({"disable_close": true, "width": 600, "dom_node": showcase, "reload_on_close": true});
		dojo.addClass(dojo.byId("mail-content"), "mceEditor");
		default_tinymce_init();
	}
	else {
		dicole.create_showcase({"disable_close": true, "width": 600, "dom_node": showcase});
	}
	var flashes = dojo.query("object, embed");
	flashes.forEach(function(flash) {
		dojo.style(flash, "visibility", "hidden");
	});
	dojo.connect(showcase_close, "onclick", null, function(event) {
		dojo.stopEvent(event);
		if(id == "participant-box") {
			dojo.publish("showcase.close", [true]);
		}
		else {
			dojo.publish("showcase.close", []);
		}
		flashes.forEach(function(flash) {
			dojo.style(flash, "visibility", "visible");
		});
	});
};

var register_submit = function(event) {
	dojo.stopEvent(event);
	var message_box = dojo.byId("accept-box-message");
	dojo.style(message_box, "display", "none");
	dojo.xhrPost({
		"url": "/rpc_check_register/",
		"content": {
			"email": dojo.byId("register_email").value,
			"first_name": dojo.byId("register_first_name").value,
			"last_name": dojo.byId("register_last_name").value
		},
		"handleAs": "json",
		"handle": function(response) {
			if(response.success == 0) {
				message_box.innerHTML = response.reason;
				dojo.style(message_box, "display", "block");
			}
			else if(response.success == 1) {
				dojo.byId("register-form").submit();
			}
			else alert("Unexpected error occured, please try again!");
		}
	});
};

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
			if(response.success) {
				var accept_button = dojo.byId("accept-button");
				if( accept_button && accept_button.href ) {
					window.location = accept_button.href;
				}
				else {
					window.location = response.location;
				}
			}
			else {
				var message_box = dojo.byId("accept-box-message");
				message_box.innerHTML = response.reason;
				dojo.style(message_box, "display", "block");
			}
		}
	});
};

var filter_participants = function() {
	var participants = dojo.query(".participant-rsvp-container");

	if(function() { for(var filter in filters) { if(filters[filter]) return true; } return false; }()) {
		participants.style("display", "none");
		participants.forEach(function(participant) {
			dojo.query(".participant-rsvp a", participant).forEach(function(rsvp) {
				for(var filter in filters) {
					if(filters[filter] && dojo.hasClass(rsvp, filter)) {
						dojo.forEach(["left", "middle", "right"], function(button_type) {
							if(dojo.hasClass(rsvp, button_type + "-button-selected")) dojo.style(participant, "display", "block");
						});
					}
				}
			});
		});
	}
	else participants.style("display", "block");
	
	var filtered_amount = 0;
	var target_users = [];
	participants.forEach(function(participant) {
		if(dojo.style(participant, "display") == "block") {
			++filtered_amount;
			target_users.push(dojo.attr(participant, "title"));
		}
	});
	
	var participants_none = dojo.byId("participants-number-none");
	var participants_singular = dojo.byId("participants-number-singular");
	var participants_plural = dojo.byId("participants-number-plural");
	
	if(filtered_amount > 1) {
		dojo.style(participants_none, "display", "none");
		dojo.style(participants_singular, "display", "none");
		dojo.style(participants_plural, "display", "block");
		dojo.byId("participants-number").innerHTML = filtered_amount;
	}
	else if(filtered_amount == 1) {
		dojo.style(participants_none, "display", "none");
		dojo.style(participants_singular, "display", "block");
		dojo.style(participants_plural, "display", "none");
	}
	else {
		dojo.style(participants_none, "display", "block");
		dojo.style(participants_singular, "display", "none");
		dojo.style(participants_plural, "display", "none");
	}

	dojo.byId("target-users").value = target_users.join(",");
	dojo.byId("export-this-list").href = export_url + "?target_users=" + target_users.join(",");
};

dicole.events.location_last_text = '';
dicole.events.location_loop_counter = 0;
dicole.events.location_loop = function() {
	var location_field = dojo.byId("location-field");
	var current_text = location_field.value;
	if ( current_text != dicole.events.location_last_text ) {
		dicole.events.location_loop_counter = 0;
		dicole.events.location_last_text = current_text;
	}
	else {
		if ( dicole.events.location_loop_counter < 3 + 1 ) {
			dicole.events.location_loop_counter++;
		}
	}

	if( dicole.events.location_loop_counter == 3 && current_text.length > 2 ) {
        dicole.events.geocoder = new google.maps.Geocoder();
        dicole.events.geocoder.geocode( { 'address': current_text }, function(results, status) {
            if (status == google.maps.GeocoderStatus.OK) {
                var point = results[0].geometry.location;
                var lat = point.lat();
                var lng = point.lng();
                dojo.attr(dojo.byId("map-link"), "href", "http://maps.google.com/?ll=" + lat + "," + lng + "&z=12&q=" + location_field.value);
                dojo.attr(dojo.byId("map-image"), "src", "https://maps.googleapis.com/maps/api/staticmap?&sensor=false&center=" + lat + "," + lng + "&zoom=12&size=185x150&markers=" + location_field.value);
                dojo.byId("latitude").value = lat;
                dojo.byId("longitude").value = lng;
                dojo.style(dojo.byId("map"), "display", "block");
                dojo.style(dojo.byId("map-help"), "display", "none");
                dojo.style(dojo.byId("map-error"), "display", "none");
            }
            else {
                dojo.style(dojo.byId("map"), "display", "none");
                dojo.style(dojo.byId("map-error"), "display", "block");
            }
        } );
	}
	setTimeout(dicole.events.location_loop, 500);
};

dicole.events.process_events_more = function() {
	dicole.xhrplace( {
		base_class : 'events_more_button',
		custom_id_container_key : 'messages_html',
		post_content_procedure : function ( node ) { return {
			page_load : dicole.events.gather_events_page_load_time(),
			shown_entry_ids : dicole.events.gather_shown_event_ids_json()
		}; },
		after_procedure : function( data ) {
			dicole.events.process_events_more();
		}
	} );
}

dicole.events.gather_shown_event_ids_json = function() {
	var ids = [];
	dojo.query('.events_entry_container').forEach( function ( post ) {
		var node_id = dojo.attr( post, 'id') + '';
		var parts = node_id.match(/^events_entry_container_(\d+)$/);
		if ( ! parts || ! parts[1] ) return;
		ids.push( parts[1] );
	} );
	return dojo.toJson( ids );
}

dicole.events.gather_events_page_load_time = function() {
	var result = 2147483647;
	dojo.query('.events_event_listing').forEach( function ( listing ) {
		var listing_id = dojo.attr( listing, 'id' ) + '';
		var parts = listing_id.match(/^events_event_listing_(\d+)$/);
		if ( ! parts || ! parts[1] ) return;
		result = parts[1];
	} );
	return result;
}

// TODO: move these two utility classes to dicole base?
// dicole.events.params_from_classes = function( node, regex ) {
//     var class_string = dojo.attr( node, 'class' ) + '';
//     var classes = class_string.split( /\s+/ );
//     var matches = [];
//     dojo.forEach( classes, function( cls ) {
//         var result = regex.exec( cls );
//         if ( result ) {
//             matches.push( result );
//         }
//     } );
// 
//     return matches;
// }
// 
// dicole.events.first_value_from_classes = function( node, regex ) {
//     var params = dicole.events.params_from_classes( node, regex );
//     params = params.sort();
//     var first = params.shift();
//     if ( first && first[1] ) {
//         return first[1];
//     }
//     return false;
// };
// 
// dicole.events.render_attr_modes = [ 'loading', 'display', 'starting', 'edit', 'saving' ];
// 
// dicole.events.render_attr = function( mode, attr, value ) {
//                     console.log(mode + attr + value);
//     if( dicole.events.render_attr_functions[mode] && dicole.events.render_attr_functions[mode][attr] ) {
//         dicole.events.render_attr_functions[mode][attr]( mode, attr, value );
//     }
//     else if ( dicole.events.render_attr_functions[mode] && dicole.events.render_attr_functions[mode]._default ) {
//         dicole.events.render_attr_functions[mode]._default( mode, attr, value );
//     }
//     else {
//         dicole.events.render_attr_functions._default( mode, attr, value );
//     }
// };
// 
// dicole.events.render_attr_functions = {
//     'edit' : {
//         'title' : function( mode, attr, value ) {
//             // just an example how to do more complex render initializations
//             // complex stuff here before showing title edit :D
//             dicole.events.render_attr_functions.edit._default( mode, attr, value );
//         },
//         '_default' : function( mode, attr, value ) {
//             if ( value !== false ) {
//                 dojo.query('.js_events_edit_attr_' + attr + '_input').forEach( function( node ) {
//                     dojo.attr( node, 'value', value );
//                 } );
//             }
//             dicole.events.render_attr_functions._default( mode, attr, value );
//         }
//     },
//     'display' : {
//         '_default' : function( mode, attr, value ) {
//             if ( value !== false ) {
//                 dojo.query('.js_events_edit_attr_' + attr + '_display_content').forEach( function( node ) {
//                     dojo.attr( node, 'innerHTML', dicole.encode_html(value) );
//                 } );
//                 dojo.query('.js_events_edit_attr_' + attr + '_display_html_content').forEach( function( node ) {
//                     dojo.attr( node, 'innerHTML', value );
//                 } );
//             }
//             dicole.events.render_attr_functions._default( mode, attr, value );
//         }
//     },
//     '_default' : function( mode, attr, value ) {
//         dojo.forEach( dicole.events.render_attr_modes, function( alt ) {
//             dojo.query('.js_events_edit_attr_' + attr + '_' + alt ).forEach( function( attr_display ) {
//                 dojo.style( attr_display, 'display', 'none' );
//             } );
//         } );
//         dojo.query('.js_events_edit_attr_' + attr + '_' + mode ).forEach( function( attr_edit ) {
//             dojo.style( attr_edit, 'display', 'block' );
//         } );
//     }
// };
// 
// dicole.events.attach_edit = function() {
//     dojo.query('.js_events_edit_attr').forEach( function (node) {
//         var attr = dicole.events.first_value_from_classes( node, /js_events_edit_attr_(.*)/ ) + '';
//         dicole.events.render_attr( 'loading', attr );
//         dojo.xhrPost( {
//             url : node.href,
//             timeout : 5000,
//             content : {
//                 name : attr
//             },
//             handleAs : 'json',
//             load : function( data ) {
//                 if ( data.result ) {
//                     dicole.events.render_attr( 'display', attr, data.result.value );
//                 }
//                 else if ( data.error ) {
//                     // eek? retry?
//                 }
//             },
//             error : function( data ) {
//                 // handle timeout or connection error
//                 // retry?
//             }
//         } );
//     } );
// 
//     dojo.query('.js_events_edit_start_attr').forEach( function (node) {
//         dojo.connect( node, 'onclick', function( evt ) {
//             evt.preventDefault();
//             var attr = dicole.events.first_value_from_classes( node, /js_events_edit_start_attr_(.*)/ ) + '';
//             if ( ! attr ) { return; }
//             dicole.events.render_attr( 'starting', attr );
//             dojo.xhrPost( {
//                 url : node.href,
//                 timeout : 5000,
//                 content : {
//                     name : attr
//                 },
//                 handleAs : 'json',
//                 load : function( data ) {
//                     if ( data.result ) {
//                         dicole.events.render_attr( 'edit', attr, data.result.value );
//                     }
//                     else if ( data.error ) {
//                         // eek? display note?
//                         dicole.events.render_attr( 'display', attr, false );
//                     }
//                 },
//                 error : function( data ) {
//                     // handle timeout or connection error
//                     dicole.events.render_attr( 'display', attr, false );
//                 }
//             } );
//         } );
//     } );
// 
//     dojo.query('.js_events_edit_save_attr').forEach( function (node) {
//         dojo.connect( node, 'onclick', function( evt ) {
//             evt.preventDefault();
//             var attr = dicole.events.first_value_from_classes( node, /js_events_edit_save_attr_(.*)/ ) + '';
//             if ( ! attr ) { return; }
//             var attr_input =  dojo.query('.js_events_edit_attr_' + attr + '_input')[0];
//             if ( ! attr_input ) { return; }
//             dicole.events.render_attr( 'saving', attr );
//             dojo.xhrPost( {
//                 url : node.href,
//                 timeout : 5000,
//                 content : {
//                     name : attr,
//                     value : attr_input.value,
//                 },
//                 handleAs : 'json',
//                 load : function( data ) {
//                     if ( data.result ) {
//                         dicole.events.render_attr( 'display', attr, data.result.value );
//                     }
//                     else if ( data.error ) {
//                         // eek? display note?
//                         dicole.events.render_attr( 'edit', attr, false );
//                     }
//                 },
//                 error : function( data ) {
//                     // handle timeout or connection error
//                     dicole.events.render_attr( 'edit', attr, false );
//                 }
//             } );
//         } );
//     });
// };
// 
// 
// dojo.addOnLoad( function() {
//     dicole.events.attach_edit();
// } );
