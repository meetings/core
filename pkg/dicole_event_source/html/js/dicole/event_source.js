dojo.provide("dicole.event_source");
dojo.require("dicole.event_source.ServerWorker");

dicole.event_source.main_worker = false;
dicole.event_source._page_loadish_timestamp = new Date().getTime();
dicole.event_source._main_worker_readd_functions = {};

dicole.event_source.subscribe = function( name, params, handler, after_subscribe_actions ) {
    dicole.event_source._ensure_running_worker();

    after_subscribe_actions = after_subscribe_actions ? after_subscribe_actions : handler;

    dicole.event_source.main_worker.add_subscription( name, params, handler, after_subscribe_actions );

    dicole.event_source._main_worker_readd_functions[ name ] = dojo.hitch( this, dicole.event_source.subscribe, name, params, handler, after_subscribe_actions );
};

dicole.event_source.unsubscribe = function( name ) {
    dicole.event_source._ensure_running_worker();
    dicole.event_source.main_worker.remove_subscription( name );
    delete dicole.event_source._main_worker_readd_functions[ name ];
};

dicole.event_source._ensure_running_worker = function() {
    if ( ! dicole.event_source.main_worker ) {
        dicole.event_source.main_worker = new dicole.event_source.ServerWorker(
            dicole.get_global_variable("event_server_url"),
            dicole.get_global_variable("domain_host"),
            false,
            1
        );

        dicole.event_source.main_worker.invalid_session_handler = function() {
            dicole.event_source.main_worker = false;
            for ( var name in dicole.event_source._main_worker_readd_functions ) {
                dicole.event_source._main_worker_readd_functions[ name ]();
            }
        };

        if ( ! dicole.get_global_variable("instant_authorization_key_url") ) {
            console.log("could not ensure worker yet!");
            return;
        }

        dojo.xhrPost({
            "url": dicole.get_global_variable("instant_authorization_key_url"),
            "handleAs": "json",
            "handle": function( response ) {
                dicole.event_source.main_worker.credentials = { "token": response.result };
                // NOTE: wait 10 seconds before opening worker. otherwise this causes the page
                // to look like it is still loading for the first poll duration = a long time
                var elapsed = new Date().getTime() - dicole.event_source._page_loadish_timestamp;
                setTimeout( function() { dicole.event_source.main_worker.open(); }, ( elapsed < 10000 ) ? 10000 - elapsed : 1 );
            }
        });
    }
};

