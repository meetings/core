dojo.provide('dicole.networking');

dojo.require('dicole.base');
dojo.require('dicole.tags.TagBrowser2');

dicole.networking.tag_browsers = [];

var levels = [
	{
		"id": "admin",
		"name": "Admin"
	},
	{
		"id": "user",
		"name": "User"
	}
];
dojo.subscribe( 'new_node_created', function ( node ) {
	dicole.unprocessed_class_query('js_open_invite', node ).forEach( function( anode ) {
		dojo.connect( anode, 'onclick', null, function( event ) {
			dojo.stopEvent(event);
			dicole.register_template("invite_users", {templatePath: dojo.moduleUrl("dicole.networking", "invite_users.html")});
			var showcase = dicole.process_template("invite_users", {"levels": levels});
			dicole.create_showcase({"disable_close": true, "width": 800, "content": showcase});
			default_tinymce_init();
			
			var invite_users_form = dojo.byId("invite_users");
			dojo.connect(invite_users_form, "onsubmit", null, function(event) {
				dojo.stopEvent(event);
				if(!dojo.hasClass(dojo.byId("invite_users_button"), "disabled")) {
					dojo.xhrPost({
						"url": dicole.get_global_variable("invite_url"),
						"content": dojo.formToObject(invite_users_form),
						"handleAs": "json",
						"handle": function(response) {
							if(response && response.result && response.result.success) window.location = response.result.url;
							else alert(response.error);
						}
					});
				}
			});
		});
	});
	
	var photo_upload = dojo.byId("user_edit_photo");
	if(photo_upload) dicole.init_flash_uploader("user_edit_photo", 200, 200);
} );

dojo.addOnLoad( function() {
    if ( dojo.byId('networking_tag_browser' ) ) {
        dicole.networking.tag_browsers.push( new dicole.tags.TagBrowser2(
            'browse_filter_container',
            'browse_selected_container',
            'browse_selected_tags_container',
            'browse_suggestions',
            'browse_results',
            dojo.query('#filter_link'),
            dojo.query('#filter_more'),
            dojo.query('#browse_show_more a'),
            dojo.query('#browse_result_count'),
            dicole.get_global_variable( 'networking_keyword_change_url' ),
            dicole.get_global_variable( 'networking_more_profiles_url' ),
            dicole.get_global_variable( 'networking_profiles_state' ),
            dicole.get_global_variable( 'networking_end_of_pages' )
        ) );
    }
    dojo.query("#networking_search_input").forEach(function( input ) {
        dojo.connect(input, 'onkeypress', function( evt ) {
            if ( evt && evt.keyCode == dojo.keys.ENTER ) {
                if ( dojo.byId('Form') ) {
                    dojo.stopEvent( evt );
                    dojo.byId('Form').find.click();
                }
            }
        } );
    } );
} );
