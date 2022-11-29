dojo.provide('dicole.event_source.LivingObjectList');

// this is an object which holds an ordered state of objects which
// is controlled by show, hide and kill events.
//
// the living objects are stored in a list ordered by descending time.
//
// object's time is the largest time it has ever been shown.
//
// events can be killed before and after they are shown and if they
// are killed they are removed from (or never enter) the list.
//
// latest living and visible objects can be queried by offset and limit

// you can use it synchronously like this:

/*
var lol = new dicole.event_source.LivingObjectList();
var displayed_object_count = 0;
while ( displayed_object_count < 10 ) {
    var new_events = get_some_more_events();
    dojo.forEach( new_events, function(event) {
        if ( event.type == 'delete' )
            lol.kill( event.object_id );
        if ( event.type == 'create' )
            lol.show( event.object_id, event.time );
    });
    var living_object_list = lol.query(10);
    set_currently_displayed_objects( living_object_list );
    displayed_object_count = living_object_id_list.length;
}
*/

// or you can use it asynchronously like this:

/*
var lol = new dicole.event_source.LivingObjectList();
server_connection.event_arrived_callback = function( event ) {
    if ( event.type == 'delete' )
        lol.kill( event.object_id );
    if ( event.type == 'create' || event.type == 'update' )
        if ( contains_wanted_tags( event.object_current_tags ) )
            lol.show( event.object_id, event.time );
        else
            lol.hide( event.object_id, event.time );
    set_currently_displayed_objects( lol.query( 10 ) );
}
*/

dojo.declare('dicole.event_source.LivingObjectList', null, {

    constructor : function() {
        this._visible_objects = [];
        this._object_map = {};
    },

    show : function( id, time ) {
        this._set( id, time, true )
    },

    hide : function( id, time ) {
        this._set( id, time, false );
    },

    _set : function( id, time, show ) {
        var old_object = this._object_map[id];
        var new_object = { id : id, time : time };
        if ( old_object ) {
            if ( old_object.dead ) return;
            if ( this._comparator( new_object, old_object ) <= 0 ) return;
            this._remove_object( old_object );
        }
        this._object_map[id] = new_object;
        if ( show ) this._add_object( new_object );
    },

    kill : function( id ) {
        this._remove_object( this._object_map[id] );
        this._object_map[id] = { dead : true };
    },

    query : function( limit, offset ) {
        if ( ! offset ) offset = 0;
        return dojo.map(
            limit ? this._visible_objects.slice( offset, offset + limit ) : this._visible_objects,
            function( object ) { return object.id; }
        );
    },

    _add_object : function( object ) {
        this._visible_objects.splice( this._get_supposed_index( object ), 0, object );
    },

    _remove_object : function( object ) {
        if ( ! object ) return;
        var object_index = this._get_real_index( object );
        if ( object_index > -1 ) this._visible_objects.splice( object_index, 1 );
    },

    _get_real_index : function( object ) {
        return  this._get_index( object, true )
    },

    _get_supposed_index : function( object ) {
        return  this._get_index( object, false )
    },

    _get_index : function( object, real ) {
        return this._bin_index_search( this._visible_objects, object, 0, this._visible_objects.length - 1 , real );
    },

    _bin_index_search : function( objects, object, start, end, real ) {
        if ( end < start ) return real ? -1 : start;
        var mid = Math.floor( start + ( end - start ) / 2 );
        var difference = this._comparator( object, objects[mid] );
        if ( difference > 0 ) {
//            if ( start == end ) return real ? -1 : mid;
            return this._bin_index_search( objects, object, start, mid - 1, real );
        }
        if ( difference < 0 ) {
//            if ( start == end ) return real ? -1 : mid + 1;
            return this._bin_index_search( objects, object, mid + 1, end, real );
        }
        return mid;
    },

    _comparator : function ( a, b ) {
        if ( a.time > b.time ) return 1;
        if ( a.time < b.time ) return -1

        // it does not matter how we order things with the same time
        // but we must give a consistent order and return 0 only
        // of comparing the exact same objects
        if ( a.id > b.id ) return 1;
        if ( a.id < b.id ) return -1
        return 0;
    }
} );
