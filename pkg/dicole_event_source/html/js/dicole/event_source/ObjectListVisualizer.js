dojo.require("dojo.fx.easing");
dojo.provide('dicole.event_source.ObjectListVisualizer');
dojo.declare('dicole.event_source.ObjectListVisualizer', null, {

    constructor : function( node_name, container_node, object_cache, visualizer ) {
        this.node_name = node_name;
        this.container_node = container_node;
        this._last_node = null;
        this.object_cache = object_cache;
        this.visualizer = visualizer;
        this._current_objects = [];
        this._animations = [];
    },

    set_visible_objects2 : function( id_list ) {
        this.object_cache.retrieve_dict( id_list, dojo.hitch( this, function( dict ) {
            dojo.empty( this.container_node );
            dojo.forEach( id_list, function( id ) {
                dict[id].object.id = id;
                if ( dict[id].updated != dict[id].object.timestamp ) {
                    dict[id].object.updated = dict[id].updated;
                }
                var html = this.visualizer( dict[id].object );
                var node = dojo.create( 'div', { 
                    "class": "excerpt", 
                    "id": this.node_name + '_' + id, 
                    "innerHTML": html 
                    } );
                dojo.place( node, this.container_node, "last" );
                dojo.anim( node, { opacity: 1.0 }, 2000, dojo.fx.easing.quadIn );
            }, this );
        } ) );
    },
    
    set_visible_objects : function( id_list ) {
        this.object_cache.retrieve_dict( id_list, dojo.hitch( this, function( dict ) {
            var present_nodes = dojo.query("#"+this.container_node.parentNode.id+" div div.excerpt");

            var present_nodes_id_list = [];
            dojo.forEach( present_nodes, function( node ) { present_nodes_id_list.push(node.id); });
            
            present_nodes_id_list.find_value = function( search ) {
                var found_entry = null;
                for ( var index = 0; index < this.length; index++) {
                    if ( search == this[index] ) {
                        found_entry = this[index];
                        this.splice(index, 1);
                    }
                }
                return found_entry;
            };

            dojo.forEach( id_list, function( id ) {
                if ( ! dict[id] || ! dict[id].object ) return;
                var existing_entry = present_nodes_id_list.find_value(this.node_name + "_" + id);
                if ( existing_entry == null ) {
                    this._current_objects.push(this.create_visible_object( id, dict ));
                } else {
                    var node = dojo.byId(existing_entry);
            		if ( dojo.attr(existing_entry, "timestamp") == dict[id].updated ) {
                        this._current_objects.push(node);
            		} else {
                        this._current_objects.push(this.update_visible_object( id, dict ));
            		}
                }
            }, this);

            dojo.forEach( present_nodes_id_list, function(node_id) {
                dojo.attr( node_id, "style", { "display": "none" } );
                dojo.destroy( node_id );
            });
            dojo.forEach( this._current_objects, function(node) {
                dojo.place( node, this.container_node, "last" );
            }, this);
            dojo.forEach( this._animations, function(animation) {
                this._animations.shift().play();
            }, this);
        } ) );
    },
    
    create_visible_object : function( id, dict ) {
        dict[id].object.id = id;
        if ( dict[id].updated != dict[id].object.timestamp ) {
            dict[id].object.updated = dict[id].updated;
        }
        var html = this.visualizer( dict[id].object );
        var node = dojo.create( 'div', { 
            "class": "excerpt", 
            "id": this.node_name + '_' + id, 
            "timestamp": dict[id].updated,
            "innerHTML": html 
            } );
        this._animations.push(
            dojo.animateProperty( { 
                "node": node,
                "duration": 3000,
                "easing": dojo.fx.easing.quadIn,
                "properties": {
                    opacity: { start: 0, end: 1.0 }
                    }
                }) );
        return node;
    },

    update_visible_object : function( id, dict ) {
        dict[id].object.id = id;
        if ( dict[id].updated != dict[id].object.timestamp ) {
            dict[id].object.updated = dict[id].updated;
        }
        var node = dojo.byId( this.node_name + '_' + id);
        node.innerHTML = this.visualizer( dict[id].object );
        dojo.attr( node, "timestamp", dict[id].updated );
        
        var anim_node = dojo.query( '#' + this.node_name + '_' + id + ' .title')[0];
        if ( anim_node ) this._animations.push(
            dojo.animateProperty( { 
                "node": anim_node,
                "duration": 1000,
                "easing": dojo.fx.easing.quadInOut,
                "properties": {
                    backgroundColor: { start: '#fff594', end: 'transparent' }
                    }
                }) );
        return node;
    }
} );
