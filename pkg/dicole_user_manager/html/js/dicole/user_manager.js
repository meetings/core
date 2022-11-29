dojo.provide("dicole.user_manager");

dojo.require("dicole.base");

dojo.addOnLoad( function() {
    if ( dicole.get_global_variable('auto_open_register') ) {
        dicole.user_manager.open_select_register_method_dialog();
    }
} );

dojo.subscribe( 'new_node_created', function( node ) {
    dicole.unprocessed_class_query( 'js_open_register_dialog', node ).forEach( function( register_button ) {
		dojo.connect(register_button, "onclick", null, function(event) {
			dojo.stopEvent(event);
			dicole.user_manager.open_select_register_method_dialog();
		});
	} );
	
	dicole.unprocessed_class_query( 'js_open_user_register_dialog', node ).forEach( function( register_button ) {
		dojo.connect(register_button, "onclick", null, function(event) {
			dojo.stopEvent(event);
			dicole.user_manager.open_register_dialog();
		});
	} );
});

dicole.user_manager.open_select_register_method_dialog = function() {
	var facebook = dicole.get_global_variable("facebook_connect_app_id");
	if(facebook) {
		dicole.register_template("select_register_method", {templatePath: dojo.moduleUrl("dicole.user_manager", "select_register_method.html")});
		var showcase = dicole.process_template("select_register_method", {
			"facebook_connect_app_id": facebook
		});
		dicole.create_showcase({"disable_close": true, "width": 400, "content": showcase});
	}
	else dicole.user_manager.open_register_dialog();
};

dicole.user_manager.open_register_dialog = function() {
	dicole.register_template("user_create", {templatePath: dojo.moduleUrl("dicole.user_manager", "user_create.html")});
	var showcase = dicole.process_template("user_create", {
        "url_after_register" : dicole.get_global_variable("url_after_register"),
        "registration_question" : dicole.get_global_variable("registration_question"),
        "require_location" : dicole.get_global_variable("require_location"),
        "tos_url": dicole.get_global_variable("tos_url")
    });
	dicole.create_showcase({"disable_close": true, "width": 600, "content": showcase});
	
	dicole.user_manager.process_fancy_buttons();
	dicole.init_flash_uploader("user_create_photo", 200, 200);
	
	var user_create_form = dojo.byId("user_create");
	var user_create_button = dojo.byId("user_create_button");
	dojo.connect(user_create_button, "onclick", null, function(event) {
		dojo.stopEvent(event);
		if(!dojo.hasClass(user_create_button, "disabled")) {
			var content = dojo.formToObject(user_create_form);
			content.url_after_register = dicole.get_global_variable('url_after_register');
			dojo.xhrPost({
				"url": dicole.get_global_variable("register_url"),
				"content": content,
				"handleAs": "json",
				"handle": function(response) {
					if(response && response.success) window.location = response.url;
					else alert(response.error.message);
				}
			});
		}
	});
};

dicole.user_manager.prefill_register_dialog_from_facebook = function(access_token) {
	var first_name = dojo.byId("user_first_name");
	var last_name = dojo.byId("user_last_name");
	var email = dojo.byId("user_email");
	var facebook_user_id = dojo.byId("facebook_user_id");
	
	FB.api("/me", function(response) {
		if(response.id) facebook_user_id.value = response.id;
	
		if(response.first_name) {
			first_name.value = response.first_name;
			dojo.removeClass(first_name, "invalid");
		}
		
		if(response.last_name) {
			last_name.value = response.last_name;
			dojo.removeClass(last_name, "invalid");
		}
		
		if(response.email) {
			email.value = response.email;
			dojo.removeClass(email, "invalid");
		}
		
		if(response.first_name && response.last_name && response.email) {
			dojo.query(".js_submit").forEach(function(element) {
				dojo.removeClass(element, "disabled");
			});
		}
	});
	
	var image = dojo.byId("user_create_photo_image");
	var draft_id = dojo.byId("user_create_photo_draft_id");
	
	dojo.xhrPost({
		"url": dicole.get_global_variable("draft_attachment_url_store_url"),
		"content": {
			"width": 200,
			"height": 200,
            "filename" : "picture.jpg",
			"url": "https://graph.facebook.com/me/picture?type=large&access_token=" + access_token
        },
		"handleAs": "json",
		"handle": function(response) {
		 	draft_id.value = response.draft_id;
		 	image.src = response.draft_thumbnail_url;
		}
	});
};

dicole.user_manager.process_fancy_buttons = function() {
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
}
