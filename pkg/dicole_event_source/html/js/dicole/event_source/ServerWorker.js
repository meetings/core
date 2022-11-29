dojo.provide("dicole.event_source.ServerWorker");

dojo.require("dicole.event_source.ServerConnection");

dojo.declare("dicole.event_source.ServerWorker", null, {

        "constructor": function( url, domain_name, credentials, do_not_open_on_start ) {
//                console.log("constructor");
                this.connection = new dicole.event_source.ServerConnection( url );
                this.domain_name = domain_name;
                this.credentials = credentials;

                this.buffer_size = 50;
                this.timeout_seconds = 30;
                this.poll_interval = 2000;

                this.last_poll = 0;
                this.open_subscriptions = {};
                this.invalid_session_handler = function() {};

                this.pending_calls = [];
                this.connection_state = 'closed';
                this.poll_state = 0;
                this.poll_in_flight = 0;

                if ( ! do_not_open_on_start ) this.open();
        },

        "open": function() {
                if ( this.connection_state != 'closed' ) return;
                this.connection_state = 'opening';
                this.connection.open( this.domain_name, this.credentials, dojo.hitch( this, function( response ) {
                    if ( response && response.result ) {
                        if ( this.connection_state == 'opening' ) {
                            this.connection_state = 'open';
                            this._run_pending_calls();
                            this.start();
                        }
                        else {
                            this.error_handler( 'session opened when not opening', response );
                        }
                    }
                    else {
                        this.error_handler( 'session open failed, retrying in 60 seconds', response );
		                this.connection_state = 'closed';
						setTimeout(dojo.hitch( this, this.open), 60000);
                    }
                } ) );
        },

        "_run_pending_calls" : function() {
            while( this.pending_calls.length ) this.pending_calls.shift()();
        },

        "add_subscription" : function( name, params, events_handler, after_subscription_actions ) {
            if ( this.connection_state != 'open' ) {
                this.pending_calls.push( dojo.hitch(this, this.add_subscription, name, params, events_handler, after_subscription_actions ) );
            }
            else {
                if( this.open_subscriptions[ name ] ) {
                    this.connection.unsubscribe( name, dojo.hitch( this, function() {
                        delete this.open_subscriptions[ name ];
                        this._send_subscription( name, params, events_handler, after_subscription_actions );
                    } ) );
                }
                else {                
                    this._send_subscription( name, params, events_handler, after_subscription_actions );
                }
            }
        },

        "remove_subscription" : function( name ) {
            this.connection.unsubscribe( name );
        },

        "subscription_history_is_extendable" : function( name ) {
            var subscription = this.open_subscriptions[ name ];
            return ( subscription && subscription.limits.start > 0 ) ? true : false;
        },

        "extend_subscription_history" : function( name, amount ) {
            var params = {
                "name" : name,
                "history" : amount
            };
            this.connection.extend( params, dojo.hitch( this, function( response ) {
                this.open_subscriptions[name].limits = response.result;
            } ) );
        },

        "_send_subscription" : function( name, params, events_handler, after_subscription_actions ) {
            try {
                params['name'] = name;
                this.connection.subscribe( params, dojo.hitch( this, function( response ) {
                    if ( response && response.result ) {
                        this.open_subscriptions[name] = {
                            "events_handler" : events_handler,
                            "limits" : response.result
                        };

                        if ( after_subscription_actions ) {
                            after_subscription_actions( [] );
                        }
                    }
                    else {
                         this.error_handler( 'subscription returned error', [ response, name, params, events_handler, after_subscription_actions ] );
                    }
                } ) );
            }
            catch( error ) {
                this.error_handler( 'subscription failed', [ error, name, params, events_handler, after_subscription_actions ] );
            }
        },


        "start" : function() {
            if ( this.poll_state ) return;
            this.poll_state = 1;
            this._ensure_poll(100);
        },

        "stop": function() {
            this.poll_state = 0;
        },
        
        "passthrough": function(method, params, handler) {
            if ( this.connection_state != 'open' ) {
                this.pending_calls.push( dojo.hitch(this, this.passthrough, method, params, handler) );
            }
            else {
                try {
                    this.connection.passthrough(  method, params, handler );
                }
                catch ( error ) {
                   this.error_handler( 'passthrough failed', [ error, method, params, handler ] );
                }
            }
        },

        "request_poll" : function () {
            if ( ! this.poll_in_flight ) this._poll();
        },

        "_ensure_poll" : function( interval ) {
            if ( this.poll_state ) {
                var now = new Date().getTime();
                if ( this.last_poll + this.poll_interval < now ) {
                    if ( this.poll_in_flight + 1000 * ( this.timeout_seconds + 2 ) < now ) this._poll();
                }
                setTimeout( dojo.hitch( this, this._ensure_poll, interval ), interval );
            }
        },

        "_poll" : function() {
            this.last_poll = new Date().getTime();
            this.poll_in_flight = this.last_poll;
            
            var this_request_start = this.last_poll;
            try {
                this.connection.poll( this.buffer_size, dojo.hitch( this, function( response ) {
                    if ( this.poll_in_flight == this_request_start ) {
                        this.poll_in_flight = 0;
                        this.poll_handler( response );
                    }
                    else  {
                        this.error_handler('timed out poll response arrived', [ response ]);
                    }
                } ) );
            }
            catch ( error ) {
               this.poll_in_flight = 0;
               this.error_handler( 'poll failed', [ error, this.buffer_size ] );
            }
        },

        "poll_handler" : function( response ) {
            if ( response && response.result ) {
                for( var subscription in response.result) {
                    if ( this.open_subscriptions[subscription] && response.result[subscription]['new'] && response.result[subscription]['new'].length ) {
                        this.open_subscriptions[subscription].events_handler(
                            response.result[subscription]['new']
                        );
                    }
                    else {
                        this.error_handler( "received unhandled events", [ response.result[subscription]['new'] ] );
                    }
                }
            }
            else if ( response && response.error && response.error.code == 601 ) {
                this.stop();
                this.invalid_session_handler();
            }
            else if ( response && response.error && response.error.code == 603 ) {
                this.request_poll();
            }
            else {
                this.error_handler( 'poll returned error', [ response ] );
            }
        },

        "error_handler" : function ( error, data ) {
            console.log( "unhandled error: '" + error + "' --> " + dojo.toJson( data ) );
        }
});
