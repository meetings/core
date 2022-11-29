dojo.provide('dicole.base.localization');
dojo.require('dicole.base.globals');
dojo.require('dojo.string');

dicole._localization_api_url = false;
dicole._waiting_localization_lists = [];
dicole._fetched_localization_lists = {};
dicole._localizations = {};

dicole._waiting_localizations = [];
dicole._localizations_fetch_timer = null;

dojo.subscribe( 'global_variable_set', function( variable, val, old_val ) {
    if ( variable == 'localization_api_url' ) {
        dicole.set_localization_api_url( val );
    }
} );

dicole.set_localization_api_url = function( url ) {
    dicole._localization_api_url = url;
    if ( dicole._waiting_localization_lists.length ) {
        dicole.load_localizations( dicole._waiting_localization_lists );
    }
};

dicole.msg_is_ready = function() {
    return dicole._localization_api_url ? 1 : 0;
}

dicole.assign_lexicon = function( lexicon ) {
    for ( var key in lexicon ) {
        dicole._localizations[ key ] = dicole._prepare_localization( lexicon[ key ] );
    }
}

dicole.load_localization_list = function( localization_list ) {
    return dicole.load_localization_lists( [ localization_list ] );
}

dicole.load_localization_lists = function( localization_lists ) {

    var fetch = [];
    dojo.forEach( localization_lists, function( l ) {
        if ( ! dicole._fetched_localization_lists[ l ] ) {
            fetch.push( l );
        }
    } );

    if ( fetch.length && dicole._localization_api_url ) {
        dojo.xhrPost( {
            url : dicole._localization_api_url,
            sync : true,
            content : {
                lists : fetch
            },
            handleAs : 'json',
            load : function( data ) {
                if ( data.result ) {
                    dojo.forEach( fetch, function( l ) {
                        dicole._fetched_localization_lists[ l ] = true;
                    } );
                    dicole.assign_lexicon( data.result );
                }
            }
        } );
    }
    else {
        dicole._waiting_localization_lists.push( localization_lists );
    }
};

dicole.load_localization_strings = function( strs, async ) {

    if ( strs.length < 1 ) {
        return;
    }

	if(!async) {
		var strings = [];
		for ( var i in strs ) {
			strings.push( dicole._reverse_prepare_localization( strs[ i ] ) );
		}
		dojo.xhrPost( {
			url : dicole._localization_api_url,
			sync : true,
			content : {
				strings : dojo.toJson( strings )
			},
			handleAs : 'json',
			load : function( data ) {
				if ( data.result ) {
					dicole.assign_lexicon( data.result );
				}
			}
   		} );

        return;
	}

    for ( var i in strs ) {
        dicole._waiting_localizations.push( dicole._reverse_prepare_localization( strs[ i ] ) );
    }
    
    if ( dicole._localizations_fetch_timer ) {
        clearTimeout(dicole._localizations_fetch_timer);
    }

    dicole._localizations_fetch_timer = setTimeout(dicole.fetch_waiting_localizations, 100);
};

dicole.fetch_waiting_localizations = function() {
    var fetch = dicole._waiting_localizations;
    dicole._waiting_localizations = [];

    dojo.xhrPost( {
        url : dicole._localization_api_url,
        content : {
            strings : dojo.toJson( fetch )
        },
        handleAs : 'json',
        load : function( data ) {
            if ( data.result ) {
                dicole.assign_lexicon( data.result );
            }
        }
    } );
};

dicole.msg = function( str, params ) {
    if ( ! dicole._localizations[ str ] ) {
        dicole.load_localization_strings( [ str ] );
    }

    if ( ! dicole._localizations[ str ] ) {
        dicole._localizations[ str ] = dicole._prepare_localization( str );
    }

    if ( ! params ) params = [];
    return dojo.string.substitute( dicole._localizations[ str ], params );
};

dicole._prepare_localization = function( str ) {
    var template = str+"";
    while ( template.match( /\[\_\d+\]/ ) ) {
        template = template.replace( /\[\_(\d+)\]/, function( m, n ) { return '${' + (n-1) + '}'; } );
    }
    return template;
}

dicole._reverse_prepare_localization  = function( str ) {
    var template = str+"";
    while ( template.match( /\$\{\d+\}/ ) ) {
        template = template.replace( /\$\{(\d+)\}/, function( m, n ) { return '[_' + (n+1) + ']'; } );
    }
    return template;
}

