dojo.provide('dicole.Cafe');
dojo.require('dicole.base');
dojo.require("dicole.event_source.LivingObjectList");
dojo.require("dicole.event_source.ServerWorker");
dojo.require("dicole.event_source.ObjectCache");
dojo.require("dicole.event_source.ObjectListVisualizer");
dojo.require("dojo.date");
dojo.require("dojo.io.script");
dojo.require("dojo.fx.easing");
dojo.require("dojo.dnd.Moveable");
dojo.require("dojo.dnd.move");
dojo.require("dojo.window");

dojo.declare('dicole.Cafe', null, {

    constructor : function( domain_name, auth_token, group_id, tag, columns ) {
        this.domain_name = domain_name;
        this.auth_token = auth_token;
        this.group_id = group_id;
		this.columns = columns;
		this.twitter_query = tag;
		this.filter_tag = tag;
        this.wanted_items = 15;
		this.scroller_data = {};
		this.listeners = {};
		this.timeouts = {};


        // use real filenames here. this is required to achievebuild time template inlining.
        dicole.register_template( 'blog-excerpt' , { templatePath : dojo.moduleUrl("dicole.cafe", "blog_excerpt.html") } );
        dicole.register_template( 'wiki-excerpt' , { templatePath : dojo.moduleUrl("dicole.cafe", "wiki_excerpt.html") } );
        dicole.register_template( 'media-excerpt' , { templatePath : dojo.moduleUrl("dicole.cafe", "media_excerpt.html") } );
        dicole.register_template( 'user-excerpt' , { templatePath : dojo.moduleUrl("dicole.cafe", "user.html") } );
        dicole.register_template( 'twitter-excerpt' , { templatePath : dojo.moduleUrl("dicole.cafe", "twitter_excerpt.html") } );
        dicole.register_template( 'blog-lightbox' , { templatePath : dojo.moduleUrl("dicole.cafe", "blog_lightbox.html") } );
        dicole.register_template( 'wiki-lightbox' , { templatePath : dojo.moduleUrl("dicole.cafe", "wiki_lightbox.html") } );
        dicole.register_template( 'media-lightbox' , { templatePath : dojo.moduleUrl("dicole.cafe", "media_lightbox.html") } );

        this.lol = {};
        this.oc = {};
        this.visualizer = {};
        this.worker = new dicole.event_source.ServerWorker('/event_gateway/', this.domain_name, {"token": this.auth_token } );

		dojo.forEach( this.columns, function( column ) {
			switch( column ) {
				case "hot-in-blogs":
					this._hot_in_blogs( column );
					break;
				case "hot-in-wiki":
					this._hot_in_wiki( column );
					break;
				case "hot-media":
					this._hot_media( column );
					break;
				case "hot-in-twitter":
					this.timeouts['twitter'] = null;
					this._create_column( column, dicole.msg("Hot in Twitter") );
					this.listeners['worker_start'] = dojo.connect( this.worker, "start", this, function() {
						this._hot_in_twitter( column );
					} );
					this.listeners['worker_stop'] = dojo.connect( this.worker, "stop", this, function() {
						clearTimeout(this.timeouts['twitter']);
					} );
					break;
			}
		}, this );

		this._hot_activity( "active-users" );
		this._add_listeners();
        this.run_periodic_tasks();
    },

	_add_listeners : function() {
		this.listeners['show_options'] = dojo.connect( dojo.byId("cafe_toggle_options"), "onclick", dojo.hitch(this, function() {
			dojo.style( dojo.byId('cafe_options_shadow'), "display", "block" );
			dojo.style( dojo.byId('cafe_toggle_options'), "backgroundPosition", "100% 0%" );
			this.listeners['close_options'] = dojo.connect( dojo.byId("cafe_close_options"), "onclick", dojo.hitch(this, function() {
				dojo.style( dojo.byId('cafe_options_shadow'), "display", "none" );
				dojo.style( dojo.byId('cafe_toggle_options'), "backgroundPosition", "0% 0%" );
				dojo.disconnect( this.listeners['close_options'] );
			} ) );
		} ) );
		this.listeners['font_size_big'] = dojo.connect( dojo.byId("cafe_font_size_big"), "onclick", dojo.hitch(this, function() {
			dojo.addClass( dojo.body(), "cafe_font_size_big" );
			dojo.removeClass( dojo.body(), "cafe_font_size_small" );
			dojo.removeClass( dojo.body(), "cafe_font_size_normal" );
		} ) );
		this.listeners['font_size_small'] = dojo.connect( dojo.byId("cafe_font_size_small"), "onclick", dojo.hitch(this, function() {
			dojo.addClass( dojo.body(), "cafe_font_size_small" );
			dojo.removeClass( dojo.body(), "cafe_font_size_big" );
			dojo.removeClass( dojo.body(), "cafe_font_size_normal" );
		} ) );
		this.listeners['font_size_normal'] = dojo.connect( dojo.byId("cafe_font_size_normal"), "onclick", dojo.hitch(this, function() {
			dojo.addClass( dojo.body(), "cafe_font_size_normal" );
			dojo.removeClass( dojo.body(), "cafe_font_size_big" );
			dojo.removeClass( dojo.body(), "cafe_font_size_small" );
		} ) );
		this.listeners['show_scrollbars'] = dojo.connect( dojo.byId("cafe_show_scrollbars"), "onclick", dojo.hitch(this, function() {
			this._show_scrollbars_and_buttons("scrollbars");
		} ) );
		this.listeners['show_scrollbuttons'] = dojo.connect( dojo.byId("cafe_show_scrollbuttons"), "onclick", dojo.hitch(this, function() {
			this._show_scrollbars_and_buttons("scrollbuttons");
		} ) );
		this.listeners['show_activity'] = dojo.connect( dojo.byId("cafe_show_activity"), "onclick", dojo.hitch(this, function() {
			var start = 79;
			var end = 0;
			if( dojo.byId("cafe_show_activity").checked ) {
				start = 0;
				end = 79;
			}
			dojo.animateProperty( { 
                "node": dojo.byId("active-users"),
                "duration": 1000,
                "properties": {
                    height: { start: start, end: end }
                    }
                }).play();
			setTimeout( dojo.hitch(this, function() {
				dojo.forEach( this.columns, function( column ) {
					this.set_column_width( dojo.byId( column ) );
				}, this );
			}), 1000 );
		} ) );
		this.listeners['resize'] = dojo.connect( window, "onresize", dojo.hitch(this, function() {
			//this._get_window_height( true );
			dojo.forEach( this.columns, function( column ) {
				this.set_column_width( dojo.byId( column ) );
			}, this );
		} ) );
	},
	
	_show_scrollbars_and_buttons : function( target ) {
		dojo.forEach( this.columns, function( column_name ) {
			if( dojo.byId("cafe_show_scrollbuttons").checked || dojo.byId("cafe_show_scrollbars").checked ) {
				if( this.timeouts['hide_scroll'] ) clearTimeout( this.timeouts['hide_scroll'] );
				dojo.style( this.scroller_data[column_name].scrollup, "display", "block" );
				dojo.style( this.scroller_data[column_name].scrollarea, "display", "block" );
				dojo.style( this.scroller_data[column_name].scrolldown, "display", "block" );
				dojo.style( this.scroller_data[column_name].container, "paddingRight", "10px" );
			} else if( !dojo.byId("cafe_show_scrollbuttons").checked && !dojo.byId("cafe_show_scrollbars").checked ) {
				this.timeouts['hide_scroll'] = setTimeout( dojo.hitch( this, function() {
					dojo.style( this.scroller_data[column_name].scrollup, "display", "none" );
					dojo.style( this.scroller_data[column_name].scrollarea, "display", "none" );
					dojo.style( this.scroller_data[column_name].scrolldown, "display", "none" );
					dojo.style( this.scroller_data[column_name].container, "paddingRight", "0px" );
				}), 1500 );
			}
				
			var scrollbar_animation = {};
			var scrollbar_start = 1.0;
			var scrollbar_end = 0.0;
			var scrollbar_height = parseInt( dojo.style( this.scroller_data[column_name].scrollarea.parentNode, "height" ) ) - 86;
			if( dojo.byId("cafe_show_scrollbars").checked ) {
				scrollbar_start = 0.0;
				scrollbar_end = 1.0;
			}

			var scrollbutton_animation = {};
			var scrollbutton_start = 1.0;
			var scrollbutton_end = 0.0;
			var scrollbutton_height_start = 34;
			var scrollbutton_height_end = 0;
			if( dojo.byId("cafe_show_scrollbuttons").checked ) {
				scrollbutton_start = 0.0;
				scrollbutton_end = 1.0;
				scrollbar_height = scrollbar_height - 70;
				scrollbutton_height_start = 0;
				scrollbutton_height_end = 34;
			}
			
			if ( !dojo.byId("cafe_show_scrollbuttons").checked && !dojo.byId("cafe_show_scrollbuttons").checked && this.scroller_data[column_name].content_top < 0 ) {
				var top = this.scroller_data[column_name].offset;
				this._scroll_content(top, this.scroller_data[column_name]);
			}

			if( target == "scrollbars" ) {
				scrollbutton_animation = {
					height: { start: dojo.byId("cafe_show_scrollbuttons").checked ? 34 : 0, end: scrollbutton_height_end }
				};
				scrollbar_animation = {
					opacity: { start: scrollbar_start, end: scrollbar_end },
					height: { start: this.scroller_data[column_name].scrollarea_height, end: scrollbar_height }
				};
			} else {
				scrollbar_animation = {
					height: { start: this.scroller_data[column_name].scrollarea_height, end: scrollbar_height }
				};
				scrollbutton_animation = {
					opacity: { start: scrollbutton_start, end: scrollbutton_end },
					height: { start: scrollbutton_height_start, end: scrollbutton_height_end }
				};
			}

			dojo.animateProperty( { 
                "node": this.scroller_data[column_name].scrollup,
                "duration": 500,
                "properties": scrollbutton_animation
                }).play();
			dojo.animateProperty( { 
                "node": this.scroller_data[column_name].scrollarea,
                "duration": 500,
                "properties": scrollbar_animation
                }).play();
			dojo.animateProperty( { 
                "node": this.scroller_data[column_name].scroller,
                "duration": 500,
                "properties": { opacity: scrollbar_animation.opacity }
                }).play();
			dojo.animateProperty( { 
                "node": this.scroller_data[column_name].scrolldown,
                "duration": 500,
                "properties": scrollbutton_animation
                }).play();
		}, this );
		if( !dojo.byId("cafe_show_scrollbars").checked && !dojo.byId("cafe_show_scrollbuttons").checked ) {
			this._start_polling();
		}
	},

	_create_column : function( column_name, topic_title ) {
		var node = dojo.create("div", {
			"id" : column_name,
			"class" : "cafe_paragraph",
			"innerHTML" : "<h2>" + topic_title + "</h2>"
		});
		var container = dojo.create("div", {
			"id" : column_name + "-container",
			"class" : "cafe_container"
		});
		var scroll_button_up = dojo.create("a", {
			"href" : "#",
			"id" : column_name + "-scroll_button_up",
			"class" : "cafe_scroll_button_up",
			"style" : { "display" : "none" }
		});
		var scrollarea = dojo.create("div", {
			"id" : column_name + "-scrollarea",
			"class" : "cafe_scrollarea",
			"style" : { "display" : "none" }
		});
		var scroll_button_down = dojo.create("a", {
			"href" : "#",
			"id" : column_name + "-scroll_button_down",
			"class" : "cafe_scroll_button_down",
			"style" : { "display" : "none" }
		});
		var content = dojo.create("div", {
			"id" : column_name + "-content",
			"class" : "cafe_excerpts"
		});
		var scroller = dojo.create("a", {
			"href" : "#",
			"class" : "cafe_scroller"
		});
		dojo.place( node, dojo.byId("cafe_content"), "last" );
		dojo.place( scroll_button_up, node, "last" );
		dojo.place( scrollarea, scroll_button_up, "after" );
		dojo.place( scroll_button_down, scrollarea, "after" );
		dojo.place( container, node, "last" );
		dojo.place( content, container, "last" );
		dojo.place( scroller, scrollarea, "last" );
		this.set_column_width( node );
		
		var scrollarea_boundaries = function() {
	        var marginBox = dojo.marginBox( scrollarea );
			/* For some reason IE7 doesn't return correct left value for marginBox above, so we have to count it manually */
			for( index in this.columns ) {
			    if ( this.columns[index] == column_name ) {
			        var count = parseInt(index) + 1;
			        break;
			    }
			}
	        var boundary = {};
	        boundary["t"] = 0;
	        boundary["l"] = dojo.coords(node).w * count - marginBox.w + 3; // was: boundary["l"] = marginBox.l + 3;
	        boundary["w"] = marginBox.w - 6;
	        boundary["h"] = marginBox.h + marginBox.t;
	        return boundary;
	    };
		//var moveable = new dojo.dnd.move.parentConstrainedMoveable( scroller, { area: "content", within: true } );
		var moveable = new dojo.dnd.move.constrainedMoveable( scroller, {
		        constraints: dojo.hitch(this, scrollarea_boundaries),
		        within: true
		    });
		this.scroller_data[column_name] = {
			"content" : content,
			"container" : container,
			"scrollarea" : scrollarea,
			"scroller" : scroller,
			"scrollup" : scroll_button_up,
			"scrolldown" : scroll_button_down,
			"content_top" : 0,
			"scroller_top" : 0
		};
		this.listeners[column_name + "_scroll_up"] = dojo.connect( scroll_button_up, "onclick", dojo.hitch( this, function() {
			if ( dojo.hasClass( this.scroller_data[column_name].scrollarea.parentNode, "cafe_disabled_scroller" ) ) return;
			this._stop_polling();
			var top = this.scroller_data[column_name].scroller_top + this.scroller_data[column_name].offset - 30;
			this._scroll_content(top, this.scroller_data[column_name]);
			this._start_polling();
		} ) );
		this.listeners[column_name + "_scroll_down"] = dojo.connect( scroll_button_down, "onclick", dojo.hitch( this, function() {
			if ( dojo.hasClass( this.scroller_data[column_name].scrollarea.parentNode, "cafe_disabled_scroller" ) ) return;
			this._stop_polling();
			var top = 30 + this.scroller_data[column_name].offset + this.scroller_data[column_name].scroller_top;
			this._scroll_content(top, this.scroller_data[column_name]);
			this._start_polling();
		} ) );
		this.listeners[column_name + "_scroller"] = dojo.connect( moveable, "onMove", dojo.hitch( this, function( mover, coords ) {
			if ( dojo.hasClass( this.scroller_data[column_name].scrollarea.parentNode, "cafe_disabled_scroller" ) ) return;
			this._scroll_content(coords.t, this.scroller_data[column_name]);
		} ) );
		this.listeners[column_name + "_start"] = dojo.connect( moveable, "onMoveStart", dojo.hitch( this, function( mover ) {
			dojo.addClass( this.scroller_data[column_name].scroller, "cafe_scroller_active" );
			this._stop_polling();
		} ) );
		this.listeners[column_name + "_stop"] = dojo.connect( moveable, "onMoveStop", dojo.hitch( this, function( mover ) {
			dojo.removeClass( this.scroller_data[column_name].scroller, "cafe_scroller_active" );
			this._start_polling();
		} ) );
	},
	
	_start_polling : function() {
		var i = 0;
		dojo.forEach( this.columns, dojo.hitch( this, function( column_name ) {
			i = this.scroller_data[column_name].content_top + i;
		} ) );
		if( i == 0 ) this.worker.start();
	},

	_stop_polling : function() {
		this.worker.stop();
	},	

	_scroll_content : function( top, data ) {
		// Add Smooth scrolling parameter when using scroll buttons?
		data.scroller_top = parseInt(top - data.offset);
		if ( data.scroller_top < 0 ) data.scroller_top = 0;
		if ( (data.scroller_top + data.scroller_height) > data.scrollarea_height ) data.scroller_top = data.scrollarea_height - data.scroller_height;

		data.content_top = parseInt( 0 - (data.scroller_top * (data.content_height - data.container_height) / data.scroller_dist) );
		if( data.content_top > -30 ) data.content_top = 0;
		if( data.content_top < -(data.content_height - data.scrollarea_height + 30) ) data.content_top = -(data.content_height - data.scrollarea_height);

		dojo.style( data.content, "top", data.content_top + "px" );
		if ( (data.scroller_top + data.offset) != parseInt(dojo.style( data.scroller, "top" )) ) {
			dojo.style( data.scroller, "top", data.scroller_top + data.offset + "px" );
		}
	},
	
	_update_scroller_data : function( id ) {
//		if( this.scroller_data[id].content_height == this.scroller_data[id].content.offsetHeight ) return;

		this.scroller_data[id].offset = dojo.coords(this.scroller_data[id].scrollarea).t;
		this.scroller_data[id].content_height = this.scroller_data[id].content.offsetHeight + 50;
		this.scroller_data[id].container_height = this.scroller_data[id].container.offsetHeight;
		this.scroller_data[id].scrollarea_height = this.scroller_data[id].scrollarea.offsetHeight;
		this.scroller_data[id].scroller_height = Math.round((this.scroller_data[id].container_height * this.scroller_data[id].scrollarea_height) / this.scroller_data[id].content_height);
		if( this.scroller_data[id].scroller_height < 30 ) this.scroller_data[id].scroller_height = 30;
		if( this.scroller_data[id].scroller_height > this.scroller_data[id].scrollarea_height ) this.scroller_data[id].scroller_height = this.scroller_data[id].scrollarea_height;
		this.scroller_data[id].scroller_dist = Math.round(this.scroller_data[id].scrollarea_height - this.scroller_data[id].scroller_height);
		dojo.style( this.scroller_data[id].scroller, "height", this.scroller_data[id].scroller_height + "px");
		if( this.scroller_data[id].content_height < this.scroller_data[id].container_height ) {
			dojo.addClass( this.scroller_data[id].scrollarea.parentNode, "cafe_disabled_scroller" );
			this.scroller_data[id].disabled = true;
		}
		else if (this.scroller_data[id].content_height >= this.scroller_data[id].container_height && this.scroller_data[id].disabled ) {
			dojo.removeClass( this.scroller_data[id].scrollarea.parentNode, "cafe_disabled_scroller" );
			this.scroller_data[id].disabled = false;

		}
	},

	_hot_in_blogs : function( id ) {
		// Blogs column
		this._create_column( id, dicole.msg("Hot in Blogs") );
        this.lol['blogs'] = new dicole.event_source.LivingObjectList();
        this.oc['blogs'] = new dicole.event_source.ObjectCache(
            dojo.hitch( this, function( id_list, return_handle ) {
                this.worker.passthrough(
                    'data_for_blog_entries',
                    { "id_list" : id_list, group_id : this.group_id },
                    dojo.hitch( this, this.generic_objects_to_return_handle, return_handle ) );
            } ) );
        this.visualizer['blogs'] = new dicole.event_source.ObjectListVisualizer(
            "blogs",
            dojo.byId(id + '-content'),
            this.oc["blogs"],
            dojo.hitch( this, this.generic_process_object_template, "blog-excerpt" ) );
        this.worker.add_subscription( "blogs",
            {
                "history" : 50,
                "limit_topics" : this.filter_tag ? [
                    [ "group:" + this.group_id, "tag:" + this.filter_tag, 'class:blog_comment_created' ],
                    [ "group:" + this.group_id, "tag:" + this.filter_tag, 'class:blog_entry' ]
                ] : [
                    [ "group:" + this.group_id, 'class:blog_comment_created' ],
                    [ "group:" + this.group_id, 'class:blog_entry' ]
                ]
            },
            dojo.hitch( this, this._handle_events_from_blogs) );
	},

	_hot_in_wiki : function ( id ) {
        // Wiki column
		this._create_column( id, dicole.msg("Hot in Wiki") );
        this.lol['wiki'] = new dicole.event_source.LivingObjectList();
        this.oc['wiki'] = new dicole.event_source.ObjectCache(
            dojo.hitch( this, function( id_list, return_handle ) {
                this.worker.passthrough(
                    'data_for_wiki_pages',
                    { "id_list" : id_list, group_id : this.group_id },
                    dojo.hitch( this, this.generic_objects_to_return_handle, return_handle ) );
            } ) );
        this.visualizer['wiki'] = new dicole.event_source.ObjectListVisualizer(
            "wiki",
            dojo.byId(id + '-content'),
            this.oc["wiki"],
            dojo.hitch( this, this.generic_process_object_template, "wiki-excerpt" ) );
        this.worker.add_subscription( "wiki",
            {
                "history" : 50,
                "limit_topics" : this.filter_tag ? [
                    [ "group:" + this.group_id, "tag:" + this.filter_tag, 'class:wiki_comment_created' ],
                    [ "group:" + this.group_id, "tag:" + this.filter_tag, 'class:wiki_page' ]
                ] : [
                    [ "group:" + this.group_id, 'class:wiki_comment_created' ],
                    [ "group:" + this.group_id, 'class:wiki_page' ]
                ]
            },
            dojo.hitch( this, this._handle_events_from_wiki) );
	},

	_hot_media : function ( id ) {
        // Media column
		this._create_column( id, dicole.msg("Hot Media") );
        this.lol['media'] = new dicole.event_source.LivingObjectList();
        this.oc['media'] = new dicole.event_source.ObjectCache(
            dojo.hitch( this, function( id_list, return_handle ) {
                this.worker.passthrough(
                    'data_for_media_objects',
                    { "id_list" : id_list, group_id : this.group_id },
                    dojo.hitch( this, this.generic_objects_to_return_handle, return_handle ) );
            } ) );
        this.visualizer['media'] = new dicole.event_source.ObjectListVisualizer(
            "media",
            dojo.byId(id + '-content'),
            this.oc["media"],
            dojo.hitch( this, this.generic_process_object_template, "media-excerpt" ) );
        this.worker.add_subscription( "aamedia",
            {
                "history" : 50,
                "limit_topics" : this.filter_tag ? [
                    [ "group:" + this.group_id, "tag:" + this.filter_tag, 'class:media_comment_created' ],
                    [ "group:" + this.group_id, "tag:" + this.filter_tag, 'class:media_object' ]
                ] : [
                    [ "group:" + this.group_id, 'class:media_comment_created' ],
                    [ "group:" + this.group_id, 'class:media_object' ]
                ]
            },
            dojo.hitch( this, this._handle_events_from_media) );
	},

	_hot_activity : function ( id ) {
        // Activity section
        this.lol['activity'] = new dicole.event_source.LivingObjectList();
        this.oc['activity'] = new dicole.event_source.ObjectCache(
            dojo.hitch( this, function( id_list, return_handle ) {
                this.worker.passthrough(
                    'data_for_users',
                    { "id_list" : id_list, group_id : this.group_id },
                    dojo.hitch( this, this.generic_objects_to_return_handle, return_handle ) );
            } ) );
        this.visualizer['activity'] = new dicole.event_source.ObjectListVisualizer(
            "activity",
            dojo.query('#' + id + ' div')[0],
            this.oc["activity"],
            dojo.hitch( this, this.generic_process_object_template, "user-excerpt" ) );
        var now_epoch = Math.floor( new Date().getTime() / 1000 );
        this.worker.add_subscription( "activity",
            {
                "start" : now_epoch - 60*60*24*90,
                "limit_topics" : [
                    [ "group:" + this.group_id ]
                ]
            },
            dojo.hitch( this, this._handle_events_from_activity) );
	},

	_hot_in_twitter : function ( id ) {
		var last_node = dojo.query(".tweet_result:first")[0];
	    var last_ID = last_node ? dojo.attr( last_node, 'id' ).replace( "tweet", "" ) : '';

	    dojo.io.script.get({
	        url : 'http://search.twitter.com/search.json',
	        callbackParamName : 'callback',
	        content : dojo.mixin( { q : this.twitter_query }, last_ID ? { since_id : last_ID } : { rpp : 5 } ),
	        load : dojo.hitch(this, function( json ) {
	            var results = [];
	            if ( json && json.results ) {
	                dojo.forEach( json.results, function ( result ) {
	                    if ( result && !("id" in result) ) {
	                        results.push( dojo.create("div", {
									"class": "excerpt tweet_result",
									"id": "tweet" + result.id,
									"innerHTML": this.generic_process_object_template("twitter-excerpt", result)
								} ) );
	                    }
	                }, this );
	            }

	            dojo.forEach( results.reverse(), function( html_fragment ) {
	                dojo.place( html_fragment, dojo.byId(id + '-content'), 'first' );
					dojo.animateProperty( { 
		                "node": html_fragment,
		                "duration": 1000,
		                "easing": dojo.fx.easing.quadIn,
		                "properties": {
		                    opacity: { start: 0, end: 1.0 }
		                    }
		                }).play();
	            } );

	            dojo.query( '.tweet_results' ).slice(20).forEach( function( n ) { dojo.destroy( n ); } );
	        })
	    });
	
		this.timeouts['twitter'] = setTimeout( dojo.hitch(this, this._hot_in_twitter, id), 4000 );
	},

    stop_polls : function() {
        this.worker.stop();
    },

    _handle_events_from_blogs : function( event_list ) {
        this._handle_events(event_list, "blogs");
    },

    _handle_events_from_wiki : function( event_list ) {
        this._handle_events(event_list, "wiki");
    },

    _handle_events_from_media : function( event_list ) {
        this._handle_events(event_list, "media");
    },

    _handle_events : function( event_list, subscription ) {
        if ( event_list.length > 0 ) {
            dojo.forEach( event_list, function( event ) {
                if ( event.data.event_type.indexOf('delete') > -1 ) {
                    this.lol[subscription].kill( event.data.object_id, event.data.timestamp );
                }
                else  {
                    this.lol[subscription].show( event.data.object_id, event.data.timestamp );
                    this.oc[subscription].update( event.data.object_id, event.data.timestamp );
                }
            }, this );
        }
        var items = this.lol[subscription].query( this.wanted_items );
        if ( items.length < this.wanted_items ) {
            if ( this.worker.subscription_history_is_extendable( subscription ) ) {
                this.worker.extend_subscription_history( subscription, 50 );
                this.worker.request_poll();
            }
        }
        
        if ( event_list.length > 0 ) {
            this.visualizer[subscription].set_visible_objects( items );
        }
   },

    _handle_events_from_activity : function( event_list ) {
        if ( event_list.length > 0 ) {
            if ( ! this.activity_stash ) this.activity_stash = {};
            dojo.forEach( event_list, function( event ) {
                if ( event.data.author_user_id ) {
                    if ( ! this.activity_stash[ event.data.author_user_id ] )
                        this.activity_stash[ event.data.author_user_id ] = 0;
                    this.activity_stash[ event.data.author_user_id ]++;
                }
                this.oc['activity'].update( event.data.author_user_id, 1 );
            }, this );

            var id_list = [];
            for ( var id in this.activity_stash ) { id_list.push( id ); };
            var as = this.activity_stash;
            id_list = id_list.sort( function(a, b) { return as[b] - as[a]; } );

            if ( event_list.length > 0 ) {
                this.visualizer["activity"].set_visible_objects( id_list );
            }

/*            this.oc["activity"].retrieve_dict( id_list, dojo.hitch( this, function( dict ) {
                console.log( "stash: " + dojo.toJson( as ) );
                console.log( "visualize objects: " + dojo.toJson( id_list ) );
                console.log( "with: " + dojo.toJson( dict ) );
            } ) );*/

// this doesn't work :/
/*            var pic = dojo.query("#active-users div img")[0];
            if ( pic ) {
                dojo.query("#active-users h2 .cafe_most_active_user")[0].innerHTML = dojo.query("#active-users div img")[0].title;
            }*/
        }
    },

	set_column_width : function( node ) {
		// Minus 20 pixels for left margin
		var width = (this._get_window_width( true ) - 20) / this.columns.length - 20;
		// Minus 200 pixels for header+footer
		//var header_height = dojo.coords( dojo.query(".cafe_header")[0] ).h;
		//var footer_height = dojo.coords( dojo.query("#active-users")[0] ).h;
        var height = this._get_window_height( true );// - header_height - footer_height;

		dojo.style( node, {
			"width" : width + "px",
			"height" : height + "px",
			"paddingLeft" : "20px"
		} );
		
		var topic_height = dojo.coords( dojo.query(".cafe_paragraph h2")[0] ).h;
		var button_up_height = dojo.coords( dojo.query(".cafe_scroll_button_up")[0] ).h;
		var button_down_height = dojo.coords( dojo.query(".cafe_scroll_button_down")[0] ).h;
		dojo.style( dojo.byId(node.id + "-scrollarea"), {
			"height" : (height - topic_height - button_up_height - button_down_height) + "px"
		} ); 
		dojo.style( dojo.byId(node.id + "-container"), {
			"height" : (height - topic_height) + "px"
		} ); 
	},

    run_periodic_tasks : function(  ) {
        this._set_div_height( dojo.byId("cafe_content"), this._get_window_height( false ) + "px" );
        this._set_clock( dojo.byId("cafe_clock") );
        this._set_timestamps_to_time_ago( dojo.query(".timestamp") );
		dojo.forEach( this.columns, dojo.hitch( this, function(column_name) {
			if( !([column_name + "_scroller"] in this.listeners) ) this._update_scroller_data(column_name);
			dojo.query("#" + column_name + " .contributors").forEach( function( contributors ) {
				var minus = 10;
				if( column_name == "hot-in-blogs" ) minus = minus + 80 + 43;
				if( column_name == "hot-in-wiki" ) minus = minus + 43;
				if( column_name == "hot-media" ) minus = minus + ( dojo.coords("hot-media-container").w / 2 ) + 43;
				dojo.style( contributors, "width", Math.floor((dojo.coords(column_name + "-container").w - minus)/60)*60 + "px" );
			} );
		} ) );
		dojo.forEach( dojo.query("a[rel=lightbox]"), dojo.hitch( this, function( node ) {
			var url = dojo.attr( node, "href" );
			var template = dojo.attr( node, "id" ).split("_")[1];
			this.listeners[node.id] = dojo.connect( node, "onclick", dojo.hitch(this, function( event ) {
				dojo.xhrPost({
					"url": url,
					"handleAs": "json",
					"load": dojo.hitch( this, this.lightbox, template )
				});
			} ) );
			dojo.removeAttr( node, "rel" );
			dojo.attr( node, "href", "#" );
		} ) );
        setTimeout( dojo.hitch(this, this.run_periodic_tasks), 1000 );
    },

	_get_window_height : function( force ) {
		// return window height minus header and footer
		if( !this._window_height || force ) {
			this._window_height = dojo.window.getBox().h - dojo.coords( dojo.query(".cafe_header")[0] ).h - dojo.coords( dojo.query("#active-users")[0] ).h;
		}
		return this._window_height;
	},

	_get_window_width : function( force ) {
		if( !this._window_width || force ) {
			this._window_width = dojo.window.getBox().w;
		}
		return this._window_width;
	},

    _set_div_height : function( node, height ) {
        dojo.style( node, "height", height);
    },
    
    _set_clock : function( node ) {
        var time = new Date();
        node.innerHTML = time.getHours() + 
            ":" + dojo.string.pad(time.getMinutes(), 2, "0"); /* + 
            "." + pad_with_zero(time.getSeconds()); */
    },
    
    _set_timestamps_to_time_ago : function( nodes ) {
        dojo.forEach( nodes, function(node) {
            var s = this.time_ago_in_minimal_format( dojo.attr(node, "timestamp") );

            if ( node.innerHTML != s) {
                node.innerHTML = s;
            }
        }, this);
    },
    
    time_ago_in_minimal_format : function( plain_timestamp ) {
        var now = new Date().getTime();
        var timestamp = new Date(plain_timestamp*1000).getTime();
		var s;

        if ( timestamp > now ) {
            s = "future";
        } else {
            var diff = now/1000-timestamp/1000;
            var d = 0;
			s;

            if ( d=Math.floor(diff/(60*60*24*365)) ) {s = d + 'Y'; }
            else if ( d=Math.floor(diff/(60*60*24*30)) ) {s = d + 'M'; }
            else if ( d=Math.floor(diff/(60*60*24)) ) {s = d + 'd'; }
            else if ( d=Math.floor(diff/(60*60)) ) {s = d + 'h'; }
            else if ( d=Math.floor(diff/60) ) {s = d + 'm'; }
            else { s = Math.floor(diff) + 's'; }
        }
        return s;
    },
    
    get_rid_of_widows : function( _title ) {
        // WTF? :D
        return _title;
        var words = _title.split(" ");
        if(words.length > 1) {
            words[words.length-2] += "&nbsp;" + words[words.length-1];
            words.pop();
            return words.join(" ");
        } else {
            return _title;
        }
    },

	lightbox : function( template, response ) {
		var node = dicole.process_template( template, response.result );
		this.current_lightbox = dicole.create_showcase( {
			disable_close: true,
			width: 600,
			height: this._get_window_height() + 60,
			content: node
		} );
		dojo.style( dojo.query(".cafe_lightbox_content")[0], "height", this._get_window_height() - 65 + "px" );
		this.listeners['lightbox_close'] = dojo.connect( dojo.query(".cafe_lightbox_close")[0], "onclick", dojo.hitch(this, function() {
			dojo.publish('showcase.close');
		} ) );
	},

    generic_objects_to_return_handle : function( return_handle, response ) {
        return_handle( response.result.result.data_by_object_id );
    },

    generic_process_object_template : function( template, object ) {
        return dicole.process_template( template, object );
    }

} );
