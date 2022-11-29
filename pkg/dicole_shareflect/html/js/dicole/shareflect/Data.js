dojo.provide('dicole.shareflect.Data');
dojo.declare('dicole.shareflect.Data', null, {

	constructor : function( run_with_test_data ) {
		this.users = {};
		this.messages = {};
		this.locations = {};
		this.rivers = {};
		if( run_with_test_data ) this.test_data();
		
		/*
		TODO:
		 - Location: address
		 - Message: timestamp
		*/
	},
	
	add_message : function( location_name, objects ) {
		this._add_item( this.messages, location_name, objects );
		this.locations[location_name].messages = this._sort_array( this._return_array(this.messages.helsinki) );
		this.locations[location_name].callback();
	},

	_add_item : function( storage, parent, objects ) {
		for( var object in objects ) {
			storage[parent][object] = objects[object];
			this.rivers.river_all_messages.messages = this._sort_array( this._return_array_of_all(this.messages) );
			this.rivers.river_all_messages.callback();
			dojo.forEach( objects[object].tags, function( tag ) {
				if( tag == "alert" ) {
					this.rivers.river_alerts.messages.push(objects[object]);
//					shareflect.add_alert( objects[object] );
				}
			}, this );
		}
	},

    get_alerts : function() {
		return this._return_array( this.alerts );
	},

    get_alert : function( alert_name ) {
		return this.alerts[alert_name];
	},

    get_users : function() {
		return this._return_array( this.locations );
	},

    get_user : function( user_name ) {
		return this.users[user_name];
	},
	
    get_locations : function() {
		return this._return_array( this.locations );
	},

    get_location : function( location_name ) {
		return this.locations[location_name];
	},
	
    get_rivers : function() {
		return this.rivers;
	},

    get_river : function( river_name ) {
		return this.rivers[river_name];
	},

	test_data : function( by ) {
		this.users = {
			kaarlo : {
				"id": "user_kaarlo",
				"name": "Kaarlo Lehmuskoski",
				"url": "#url",
				"image": "kuva.png"
			},
			heikki : {
				"id": "user_heikki",
				"name": "Heikki Korpela",
				"url": "#url",
				"image": "kuva.png"
			},
			turo : {
				"id": "user_turo",
				"name": "Turo Juures",
				"url": "#url",
				"image": "kuva.png"
			}
		};
		this.messages = {
			helsinki : {
				message_1 : {
					"id": "21",
					"updated": "1260971028",
					"message_type": "video",
					"excerpt": "Message",
					"location": this.locations.helsinki,
					"author": this.users.kaarlo
				},
				message_2 : {
					"id": "22",
					"updated": "1260971022",
					"message_type": "video",
					"excerpt": "Message",
					"location": this.locations.helsinki,
					"author": this.users.heikki
				}
			},
			lounge : {
				message_2 : {
					"id": "23",
					"updated": "1260971027",
					"message_type": "video",
					"excerpt": "Message",
					"location": this.locations.lounge,
					"author": this.users.kaarlo
				},
				message_3 : {
					"id": "24",
					"updated": "1260971025",
					"message_type": "video",
					"excerpt": "Message",
					"location": this.locations.lounge,
					"author": this.users.heikki
				}
			},
			ahven : {
				message_4 : {
					"id": "25",
					"updated": "1260971027",
					"message_type": "video",
					"excerpt": "Ahvenen eka",
					"location": this.locations.ahven,
					"author": this.users.turo
				},
				message_5 : {
					"id": "26",
					"updated": "1260971025",
					"message_type": "video",
					"excerpt": "Ahvenen toka",
					"location": this.locations.ahven,
					"author": this.users.turo
				},
				message_5 : {
					"id": "27",
					"updated": "1260971025",
					"message_type": "video",
					"excerpt": "Ahvenen kolmas",
					"location": this.locations.ahven,
					"author": this.users.kaarlo
				}
			}
		};
		this.locations = { 
			helsinki : {
				"id": 1,
				"type": "location",
				"title": "Helsinki",
				"tags": [ "tag1", "tag2" ],
				"lat": 60.169012,
				"lng": 24.940681,
				"messages": this._return_array(this.messages.helsinki),
				callback : dojo.hitch( shareflect, "update_element", "location_1" )
			},
			lounge : {
				"id": 2,
				"type": "location",
				"title": "Dicole Lounge",
				"tags": [ "tag1", "tag2" ],
				"lat": 60.1678622,
				"lng": 24.9320063,
				"messages": this._return_array(this.messages.lounge),
				callback : dojo.hitch( shareflect, "update_element", "location_2" )
			},
			espa : {
				"id": 3,
				"type": "location",
				"title": "Espa",
				"tags": [ "tag1", "tag2" ],
				"lat": 60.1677434,
				"lng": 24.9452650
			},
			ahven : {
				"id": 4,
				"type": "location",
				"title": "Punavuoren Ahven",
				"tags": [ "tag1", "tag2" ],
				"lat": 60.1609799,
				"lng": 24.9374277,
				"messages": this._return_array(this.messages.ahven),
				callback : dojo.hitch( shareflect, "update_element", "location_4" )
			},
			turku : {
				"id": 5,
				"type": "location",
				"title": "Temp*",
				"tags": [ "tag1", "tag2" ],
				"lat": 60.4512375,
				"lng": 22.2533264
			}
		};
//		this._fix_relation(this.messages.helsinki, "location", this.locations.helsinki)
//		this._fix_relation(this.messages.lounge, "location", this.locations.lounge)
		this._fix_relations(this.messages, this.locations, "location");
		this.rivers = {
			river_all_messages : {
				"dom_id": "river_all_messages",
				"title": "All messages",
				"messages": this._return_array_of_all(this.messages),
				callback : dojo.hitch( shareflect, "update_element", "river_all_messages" )
			},
			river_mentions : {
				"dom_id": "river_mentions",
				"title": "Mentions",
				"messages": []
			},
			river_alerts : {
				"dom_id": "river_alerts",
				"title": "Alerts",
				"messages": [this.messages.helsinki.message_1, this.messages.helsinki.message_2,  this.messages.lounge.message_3]
			},
			river_tag_cloud : {
				"dom_id": "river_tag_cloud",
				"title": "Mentions",
				"tags": []
			},
			river_locations : {
				"dom_id": "river_locations",
				"title": "Locations",
				"locations": this._return_array(this.locations)
			},
			river_users : {
				"dom_id": "river_users",
				"title": "Users",
				"users": this._return_array(this.users)
			}
		};
	},
	
	_fix_relation : function( objects, key, ref ) {
		console.log( objects, key, ref );
		for( var obj in objects ) {
			objects[obj][key] = ref;
		}
	},

	_fix_relations : function( target_objects, ref_objects, key ) {
		for( var sim in target_objects ) {
			//console.log( "Target", target_objects[sim], ref_objects[sim] );
			for( var obj in target_objects[sim] ) {
				//console.log( key, target_objects[sim][obj], ref_objects[sim] );
				target_objects[sim][obj][key] = ref_objects[sim];
			}
		}
	},

	_return_array : function( objects ) {
		var array = [];
		for( var obj in objects ) {
			if( obj == "callback" ) {
				console.log( type_of (objects[obj]) );
			}
			array.push(objects[obj]);
		}
		return array;
	},

	_sort_array : function( array ) {
		return array.sort( function(a,b) { return b.updated - a.updated; } );
	},

	_return_array_of_all : function( objects ) {
		var array = [];
		for( var obj in objects ) {
			array = array.concat( this._return_array( objects[obj]) );
		}
		return array;
	}
} );