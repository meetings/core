dojo.provide('dicole.event_source.ObjectCache');

dojo.declare('dicole.event_source.ObjectCache', null, {

    constructor : function( default_retriever ) {
        this.default_retriever = default_retriever;
        this._object_map = {};
    },

    update : function( id, time ) {
        var object = this._object_map[ id ];
        if ( this._object_map[ id ] && this._object_map[ id ].updated && this._object_map[ id ].updated >= time ) { return; }
        this._object_map[ id ] = { "id" : id, "updated" : time };
    },

    set : function( id, time, object ) {
        if ( this._object_map[ id ] && this._object_map[ id ].updated ) {
            if ( ! time ) return 0
            if ( this._object_map[ id ].updated > time ) return 0;
        }
        this._object_map[ id ] = { "id" : id, "updated" : time, "object" : object };
        return 1;
    },

    get : function( id ) {
        if ( ! this._object_map[ id ] ) this._object_map[ id ] = { "id" : id };
        return dojo.clone( this._object_map[ id ] );
    },

    get_list : function( id_list ) {
        return dojo.map( id_list, function( id ) { return this.get(id); }, this );
    },

    get_dict : function( id_list ) {
        var dict = {};
        dojo.forEach( id_list, function( id ) { dict[id] = this.get(id); }, this );
        return dict;
    },

    retrieve : function( id, result_handler, retriever ) {
        return this._retrieve_objects( [ id ], result_handler, retriever, 'first' );
    },

    retrieve_list : function( id_list, result_handler, retriever ) {
        return this._retrieve_objects( id_list, result_handler, retriever, 'list' );
    },

    retrieve_dict : function( id_list, result_handler, retriever ) {
        return this._retrieve_objects( id_list, result_handler, retriever, 'dict' );
    },

    _retrieve_objects : function( id_list, result_handler, retriever, mode ) {
        var dict = this.get_dict( id_list );
        var missing_id_list = dojo.filter( id_list, function( id ) { return dict[id].object ? false : true; } );

        if ( missing_id_list.length > 0 ) {
            var ret = retriever ? retriever : this.default_retriever;
            ret( missing_id_list, dojo.hitch( this, this._retrieve_handler, id_list, dict, result_handler, mode ) );
        }
        else {
            setTimeout( dojo.hitch( this, this._fire_result_handler, id_list, dict, result_handler, mode ), 1 );
        }
    },

    _retrieve_handler : function( id_list, dict, result_handler, mode, new_object_dict ) {
        for ( var id in new_object_dict ) {
            var object = new_object_dict[id];
            dict[id].object = object;
            this.set( id, dict[id].updated, object );
        }
        setTimeout( dojo.hitch( this, this._fire_result_handler, id_list, dict, result_handler, mode ), 1 );
    },

    _fire_result_handler : function( id_list, dict, result_handler, mode ) {
        switch ( mode ) {
            case "first" : result_handler( dict[ id_list[0] ] );
            case "list" : result_handler( dojo.map( id_list, function( id ) { return dict[id]; } ) );
            case "dict" : result_handler( dict );
        }
    }
} );
