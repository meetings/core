dojo.provide("dicole.comments");

dojo.require("dicole.base");
dojo.require("dicole.event_source");
dojo.require("dicole.event_source.ServerConnection");

dicole.register_template("comments.comment", {templatePath: dojo.moduleUrl("dicole.comments", "comment.html")});
dicole.register_template("comments.no_comments_found", {templatePath: dojo.moduleUrl("dicole.comments", "no_comments_found.html")});
dicole.register_template("comments.delete_comment_confirm", {templatePath: dojo.moduleUrl("dicole.comments", "delete_comment_confirm.html")});
dicole.register_template("comments.edit_comment", {templatePath: dojo.moduleUrl("dicole.comments", "edit_comment.html")});

dicole.comments.init_chat = function( params ) {
    var chat = {
        container_id : params.container_id,
        input_id : params.input_id,
        submit_id : params.submit_id,

        thread_id : params.thread_id,

        state_url : params.state_url,
        info_url : params.info_url,
        add_url : params.add_url,
        delete_url : params.delete_url,
        edit_url : params.edit_url,
        publish_url : params.publish_url,

        commenter_size : params.commenter_size,

        disable_editing : params.disable_editing,
        disable_deleting : params.disable_deleting,

        comment_template : params.comment_template,
        no_comments_found_template : params.no_comments_found_template,
        delete_comment_confirm_template : params.delete_comment_confirm_template,
        edit_comment_template : params.edit_comment_template,

        reverse_state : params.reverse_state,
        disable_enter_submit : params.disable_enter_submit,

        update_scheduled_after_flight : false,
        update_in_flight_since : 0,

        current_request_sent : false
    };

    chat.container = dojo.byId( chat.container_id );
    if ( ! chat.container ) { return; }

    chat.chat_id = chat.container_id;
    dojo.forEach( [ 'comment', 'no_comments_found', 'delete_comment_confirm', 'edit_comment' ], function( template ) {
        if ( ! chat[ template + '_template' ] ) {
            chat[ template + '_template' ] = 'comments.' + template;
        }
    } );

    chat.submit_node = dojo.byId( chat.submit_id );
    chat.input_node = dojo.byId( chat.input_id );

    if ( chat.add_url && chat.submit_node ) {
        dojo.connect( chat.submit_node, 'onclick', function( evt ) {
            evt.preventDefault();
            dicole.comments.send_chat_input( chat, '' );
            chat.input_node.focus();
        });
    }

    if ( chat.add_url && chat.input_node ) {
        if ( ! chat.disable_enter_submit ) {
            dojo.connect( chat.input_node, 'onkeydown', function( evt ) {
                if ( evt.keyCode == dojo.keys.ENTER ) {
                    evt.preventDefault();
                    dicole.comments.send_chat_input( chat, '' );
                }
            });
        }
        dojo.connect( chat.input_node, 'onfocus', function( evt ) {
            if ( chat.input_node.value == chat.input_node.defaultValue ) {
                chat.input_node.value = "";
            }
        });
        dojo.connect( chat.input_node, 'onblur', function( evt ) {
            if ( ! chat.input_node.value ) {
                chat.input_node.value = chat.input_node.defaultValue;
            }
        });

    }

    dicole.comments.update_chat( chat );

    dicole.event_source.subscribe( 'comment_thread_' + chat.container_id,
        {
            "limit_topics": [["comment_thread:" + chat.thread_id]]
        },
        function() { dicole.comments.update_chat( chat ); }
    );

    return chat;
};

dicole.comments.send_chat_input = function( chat, after_send ) {
    // TODO: disable send button and input

    var now = new Date().getTime();

    if ( chat.current_request_sent && chat.current_request_sent + 5000 > now ) {
        return;
    }

    var content = chat.input_node.value;
    if ( ! content || content.match(/^\s*$/) ) {
        return;
    }

    if ( content == chat.input_node.defaultValue ) {
        return;
    }

    if ( chat.submit_node ) {
        dojo.query( 'span.indicator' , chat.submit_node).forEach(function( indicator ){
            dojo.addClass( indicator, 'working' );
        });
        dojo.query( 'span.button-notop' , chat.submit_node).forEach(function( button ){
            dojo.removeClass( button, 'blue' );
            dojo.addClass( button, 'gray' );
        });
    }

    chat.current_request_sent = now;

    dojo.xhrPost( {
        url : chat.add_url,
        handleAs : 'json',
        content : {
            content : chat.input_node.value,
            commenter_size : chat.commenter_size
        },
        load : function( response ) {
            dicole.comments.update_chat( chat, response.result.state );
            chat.input_node.value = after_send;
            chat.current_request_sent = false;
            if ( chat.submit_node ) {
                dojo.query( 'span.indicator' , chat.submit_node).forEach(function( indicator ){
                    dojo.removeClass( indicator, 'working' );
                });
                dojo.query( 'span.button-notop' , chat.submit_node).forEach(function( button ){
                    dojo.removeClass( button, 'gray' );
                    dojo.addClass( button, 'blue' );
                });
            }
        }
    } );
};

dicole.comments.update_chat = function( chat, prefetched_state ) {
    if ( chat.update_in_flight_since ) {
        if ( chat.update_scheduled_after_flight ) {
            return;
        }
        else if ( chat.update_in_flight_since + 15000 > new Date().getTime() ) {
            chat.update_scheduled_after_flight = true;
            // Forget prefetched state if we have a delay
            return setTimeout( function() { dicole.comments.update_chat( chat ); }, 200 );
        }
    }

    chat.update_scheduled_after_flight = false;
    chat.update_in_flight_since = new Date().getTime();

    if ( prefetched_state ) {
        dicole.comments.update_chat_state( chat, prefetched_state );
    }
    else {
        dojo.xhrPost( {
            url : chat.state_url,
            content : {
                commenter_size : chat.commenter_size
            },
            handleAs : 'json',
            load : function( response ) {
                dicole.comments.update_chat_state( chat, response.result.state );
            },
            error : function() {
                chat.update_in_flight_since = 0;
            }
        } );
    }
};

dicole.comments.update_chat_state = function( chat, state ) {
    if ( chat.reverse_state ) {
        state.reverse();
    }

    var missing_list = [];
    var missing_list_lookup = {};

    dojo.forEach( state, function( state_info ) {
        var comment_dom_id = dicole.comments.create_dom_id( chat, state_info.id, state_info.ts );
        if ( ! dojo.byId( comment_dom_id ) ) {
            missing_list.push( state_info.id );
            missing_list_lookup[ state_info.id ] = 1;
        }
    } );

    if ( missing_list.length ) {
        dojo.xhrPost( {
            url : chat.info_url,
            content : {
                comment_id_list : dojo.toJson( missing_list ),
                commenter_size : chat.commenter_size
            },
            handleAs : 'json',
            load : function( response ) {
                dicole.comments.update_chat_comments( chat, state, response.comments );
                chat.update_in_flight_since = 0;
            },
            error : function() {
                chat.update_in_flight_since = 0;
            }
        } );
    }
    else {
        dicole.comments.update_chat_comments( chat, state, {} );
        chat.update_in_flight_since = 0;
    }
};

dicole.comments.update_chat_comments = function( chat, state, comments ) {
    var comment_nodes = dojo.query('.js_chat_comment', chat.container );

    dojo.removeClass( chat.container, 'comments-not-loaded' );

    var node_lookup = {};
    var state_target_id_lookup = {};

    dojo.forEach( comment_nodes, function( node ) {
         node_lookup[ node.id ] = node;
    } );

    dojo.forEach( state, function( state_info ) {
        var state_target_id = dicole.comments.create_dom_id( chat, state_info.id, state_info.ts );
        state_target_id_lookup[ state_target_id ] = 1;
    } );

    var current_node = comment_nodes.shift();
    var current_state_info = state.shift();

    var visible_comment_count = 0;

    while ( current_node || current_state_info ) {
        var state_target_id = current_state_info ? dicole.comments.create_dom_id( chat, current_state_info.id, current_state_info.ts ) : false;
        var comment = current_state_info ? comments[ current_state_info.id ] : false;
        var existing_node = current_state_info ? node_lookup[ state_target_id ] : false;

        if ( ! current_node ) {
            if ( comment ) {
                var node = dicole.comments.create_comment_node( chat, comment );
                if ( node ) {
                    dojo.place( node, chat.container, 'last' );
                    dicole.comments.process_placed_node( chat, comment, node );
                    visible_comment_count++;
                }
            }
            else if ( existing_node ) {
                dojo.place( existing_node, chat.container, 'last' );
                visible_comment_count++;
            }
            current_state_info = state.shift();
        }
        else if ( ! current_state_info ) {
            if ( ! state_target_id_lookup[ current_node.id ] ) {
                dojo.destroy( current_node );
            }
            current_node = comment_nodes.shift();
        }
        else {
           if ( comment ) {
                // Create a placeholder div so that we know where
                // to insert the node if current_node is deleted
                var temp_div = dojo.create( 'div', {} );
                dojo.place( temp_div, current_node, 'before');

                if ( existing_node ) {
                    dojo.destroy( existing_node );
                }

                var node = dicole.comments.create_comment_node( chat, comment );
                if ( node ) {
                    dojo.place( node, temp_div, 'replace' );
                    dicole.comments.process_placed_node( chat, comment, node );
                    visible_comment_count++;
                }

                dojo.destroy( temp_div );
                current_state_info = state.shift();
            }
            else if ( existing_node ) {
                if ( state_target_id == current_node.id ) {
                    current_node = comment_nodes.shift();
                }
                else {
                    dojo.place( existing_node, current_node, 'before' );
                }
                visible_comment_count++;
                current_state_info = state.shift();
            }
            else {
                current_state_info = state.shift();
            }
        }
    }

    var no_comments_nodes = dojo.query(".js_chat_no_comments_container", chat.container );
    if ( ! no_comments_nodes.length && ! visible_comment_count ) {
        var html = dicole.process_template( chat.no_comments_found_template, {} );
        var node = dojo.create('div', { "class" : "js_chat_no_comments_container", innerHTML : html } );
        dojo.addClass( chat.container, 'no_visible_comments' );
        dojo.place( node, chat.container );
    }
    if ( visible_comment_count && no_comments_nodes.length ) {
        dojo.forEach( no_comments_nodes, function( node ) {
            dojo.destroy( node );
        } );
        dojo.removeClass( chat.container, 'no_visible_comments' );
    }
};

dicole.comments.create_comment_node = function( chat, comment ) {
    if ( ! comment.published ) {
        return;
    }

    var html = dicole.process_template( chat.comment_template, { chat : chat, comment : comment } );
    var node = dojo.create('div', { id : dicole.comments.create_dom_id( chat, comment.id, comment.ts ), 'class' : 'js_chat_comment', innerHTML : html } );

    return node;
};

dicole.comments.process_placed_node = function( chat, comment, node ) {
    // TODO: attach publish actions

    var close_and_refresh_function = function( response ) {
        dicole.comments.update_chat( chat, response.result.state );
        dojo.publish('showcase.close');
    }

    dicole.uc_click('js_comment_delete_link', function( delete_node ) {
        var showcase = dicole.create_showcase({
            "width": 400,
            "disable_close": true,
            "content": dicole.process_template( chat.delete_comment_confirm_template, { chat : chat, comment : comment } )
        });
        dicole.uc_prepare_form( 'comments', 'delete_comment_confirm',
            { url : chat.delete_url, success_handler : close_and_refresh_function, container: showcase.nodes.container }
        );
    }, { container: node } );

    dicole.uc_click('js_comment_edit_link', function( edit_node ) {
        var showcase = dicole.create_showcase({
             "width": 400,
             "disable_close": true,
             "content": dicole.process_template( chat.edit_comment_template, { chat : chat, comment : comment } )
        } );
        dicole.uc_prepare_form( 'comments', 'edit_comment',
            { url : chat.edit_url, success_handler : close_and_refresh_function, container: showcase.nodes.container }
        );
    }, { container : node });

    dojo.publish('new_node_created', [ node ] );
};

dicole.comments.create_dom_id = function( chat, comment_id, comment_ts ) {
    return comment_id ? 'chat_comment_' + chat.chat_id + '_' + comment_id + '_' + comment_ts : '';
};

var get_comments_url = null;
var subscription_queue = [];
var comments_event_server_connection = null;
var session = null;
var polling = false;

dojo.addOnLoad( function() { process_comments_containers() } );
dojo.addOnLoad( function() { process_comments_messages() } );

dojo.addOnLoad( function() {
	comments_event_server_connection = new dicole.event_source.ServerConnection(dicole.get_global_variable("event_server_url"));
	var instant_authorization_key_url = dicole.get_global_variable("instant_authorization_key_url");
	var domain_host = dicole.get_global_variable("domain_host");
	var comments_container = dojo.query(".comments_container")[0];
	if(comments_container) {
		get_comments_url = dojo.attr(comments_container, "title");
		dojo.removeAttr(comments_container, "title");
		dojo.xhrPost({
			"url": instant_authorization_key_url,
			"handleAs": "json",
			"handle": function(response) {
				comments_event_server_connection.open(domain_host, {"token": response.result}, function(response) {
					session = response.result.session;
					dojo.forEach(subscription_queue, function(subscription) {
						subscription["session"] = session;
						comments_event_server_connection.subscribe(subscription);
					});
				});

				setTimeout(function() {
					comments_poll_event_server();
					setTimeout(arguments.callee, 5000);
				}, 5000);
			}
		});
	}
});

dojo.addOnWindowUnload( function() { try { comments_event_server_connection.close(); } catch(error) {} } );

function comments_poll_event_server() {
	if(polling) return;
	polling = true;
	comments_event_server_connection.poll(1, function(response) {
		for(var name in response.result) {
			if(response.result[name]['new'].length) {
				dojo.xhrPost({
					"url": get_comments_url,
					"handleAs": "json",
					"content": {"thread_id": name},
					"handle": function(response) {
						if ( response.messages_html ) {
							var messages_container = dojo.byId( 'comments_messages_container_' + name );
							if ( ! messages_container ) return;
							messages_container.innerHTML = response.messages_html;
							process_comments_messages();
						}
					}
				});
			}
		}
		polling = false;
	});
}

var dicole_comments_comment_is_on_the_way = 0;

function process_comments_containers() {
	dojo.query('.comments_container').forEach( function ( comments ) {
		if ( dojo.hasClass( comments, 'comments_container_processed' ) ) return;
		dojo.addClass( comments, 'comments_container_processed' );
		var parts = comments.id.match(/^comments_container_(\d+)$/);
		if ( ! parts || ! parts[1] ) return;

		var thread_id = parts[1];
		var content_submit = dojo.byId( 'comments_submit_' + thread_id );

		if ( ! content_submit ) return;

		subscription_queue.push({
			"name": thread_id,
			"limit_topics": [["comment_thread:" + thread_id]]
		});

		connect_submit( content_submit, thread_id );

        var text_input = dojo.byId( 'comments_text_content_' + thread_id );
        if ( text_input ) {
            dojo.connect( text_input, 'onkeypress', function( event ) {
    			if(event.keyCode=='13'){
	    			event.preventDefault();
		    	}
    		} );
        }
	} );
}

function connect_submit( content_submit, thread_id ) {
	dojo.connect( content_submit, 'onclick', function( evt ) {
		evt.preventDefault();

		if ( dicole_comments_comment_is_on_the_way == 1 ) return;

        var tinymce_content_instance = tinyMCE.get('comments_content_' + thread_id );
        var text_content_node = dojo.byId('comments_text_content_' + thread_id);
        var content = '';
        var content_text = '';
        if ( tinymce_content_instance ) {
    		content = tinymce_content_instance.getContent();
        }
        else if ( text_content_node ) {
            content_text = text_content_node.value;
        }
        else {
            return;
        }

        if ( ( ! content || content == '<p></p>' ) && ( ! content_text ) ) return;

        var f_anon_name = dojo.byId('comments_anon_name_' + thread_id );
		var f_anon_email = dojo.byId('comments_anon_email_' + thread_id );
		var f_anon_url = dojo.byId('comments_anon_url_' + thread_id );
		var f_privately = dojo.byId('comments_submit_' + thread_id + '_privately' );

        dicole_comments_comment_is_on_the_way = 1;

		dojo.xhrPost({
			url: content_submit.href,
			handleAs: "json",
			content : {
				anon_name : f_anon_name ? f_anon_name.value : '',
				anon_email : f_anon_email ? f_anon_email.value : '',
				anon_url : f_anon_url ? f_anon_url.value : '',
                submit_privately : f_privately && f_privately.checked ? f_privately.value : '',
				content : content,
                content_text : content_text,
				thread_id : thread_id
			},
			load: function(data) {
				dicole_comments_comment_is_on_the_way = 0;
				if ( data.messages_html ) {

                    if ( tinymce_content_instance ) {
            	        tinymce_content_instance.setContent('<p></p>');
                    } else if ( text_content_node ) {
                        text_content_node.value = '';
                    }

					var messages_container = dojo.byId( 'comments_messages_container_' + thread_id );
					if ( ! messages_container ) return;
					messages_container.innerHTML = data.messages_html;
					process_comments_messages();
				}
				else if ( data.error_string ) {
					alert( data.error_string );
				}
				else if ( data.error ) {
					if ( data.error.indexOf( 'security error' ) > -1 ) {
						alert( 'A security error occured while sending the message. This might be due to a lost session. Please copy your comment text to a safe location and try again after refreshing the page.' );
					}
					else {
						alert( 'Unprepared error occured while sending comment. Please copy your comment text to a safe location and try again after refreshing the page' );
					}
				}
			},
			error: function(error) {
				dicole_comments_comment_is_on_the_way = 0;
				alert('Unknown error while sending comment. Please try again.');
			}
		});
	} );
}

function process_comments_messages() {
	dojo.query('.comments_message').forEach(function(comment) {
		if ( dojo.hasClass( comment, 'comments_message_processed' ) ) return;
		dojo.addClass( comment, 'comments_message_processed' );
		var parts = dojo.attr(comment, 'id').match(/^comments_message_(\d+)_(\d+)$/);
		if ( ! parts || ! parts[1] || ! parts[2] ) return;

		var thread_id = parts[1];
		var post_id = parts[2];

		var comment_message_truncated = dojo.byId('comment_message_truncated_' + post_id);
		if(comment_message_truncated) {
			var comment_message = dojo.byId('comment_message_' + post_id);
			var show_more_button = dojo.byId('comment_message_show_more_' + post_id);
			var hide_more_button = dojo.byId('comment_message_hide_more_' + post_id);

			dojo.style(comment_message, 'display', 'none');

			dojo.connect(show_more_button, 'onclick', function(event) {
				event.preventDefault();
				dojo.style(comment_message, 'display', 'block');
				dojo.style(comment_message_truncated, 'display', 'none');
			});

			dojo.connect(hide_more_button, 'onclick', function(event) {
				event.preventDefault();
				dojo.style(comment_message, 'display', 'none');
				dojo.style(comment_message_truncated, 'display', 'block');
			});
		}

		var delete_button = dojo.byId( 'comments_delete_' + post_id );
		if ( delete_button ) {
    		connect_delete( delete_button, thread_id, post_id );
        }

		var publish_button = dojo.byId( 'comment_publish_publish_' + post_id );
		if ( publish_button ) {
    		connect_publish( publish_button, thread_id, post_id );
        }

        var publish_delete_button = dojo.byId( 'comment_publish_delete_' + post_id );
        if ( publish_delete_button ) {
            connect_delete( publish_delete_button, thread_id, post_id );
        }

	});
}

function connect_delete( delete_button, thread_id, post_id ) {
    var confirm_container = dojo.byId('comment_confirm_container_' + post_id);
    var x_button = dojo.byId('comments_delete_' + post_id );
    var publish_dialog = dojo.byId('comment_publish_container_' + post_id);

 	dojo.connect( delete_button, 'onclick', function( evt ) {
		evt.preventDefault();

        if ( x_button ) dojo.attr(x_button, 'style', {display: 'none'});
        if ( publish_dialog ) dojo.attr( publish_dialog, 'style', {display: 'none'});
		dojo.attr(confirm_container, 'style', {display: 'block'});
    } );

	dojo.connect(dojo.byId('comment_confirm_delete_' + post_id), 'onclick', function(evt) {
		evt.preventDefault();
		dojo.xhrPost({
			url: delete_button.href,
			handleAs: "json",
			content : {
				post_id : post_id,
				thread_id : thread_id
			},
			load: function(data, evt) {
				var messages_container = dojo.byId( 'comments_messages_container_' + thread_id );
				if ( ! messages_container ) return;
				messages_container.innerHTML = data.messages_html;
				process_comments_messages();
			},
			error: function(type, error) {
				alert('Error deleting comment. Please try again.');
			}
		});
	});

	dojo.connect(dojo.byId('comment_confirm_cancel_' + post_id), 'onclick', function(evt) {
		evt.preventDefault();
        if ( x_button ) dojo.attr(x_button, 'style', {display: 'inline'});
        if ( publish_dialog ) dojo.attr( publish_dialog, 'style', {display: 'block'});
		dojo.attr(confirm_container, 'style', {display: 'none'});
	});
}

function connect_publish( publish_button, thread_id, post_id ) {
	dojo.connect( publish_button, 'onclick', function( evt ) {
		evt.preventDefault();
		dojo.xhrPost({
			url: publish_button.href,
			handleAs: "json",
			content : {
				post_id : post_id,
				thread_id : thread_id
			},
			load: function(data, evt) {
				var messages_container = dojo.byId( 'comments_messages_container_' + thread_id );
				if ( ! messages_container ) return;
				messages_container.innerHTML = data.messages_html;
				process_comments_messages();
			},
			error: function(type, error) {
				alert('Error publishing comment. Please try again.');
			}
		});
	});
}

