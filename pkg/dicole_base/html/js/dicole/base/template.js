dojo.provide('dicole.base.template');

dicole._template_sources = {};
dicole._template_functions = {};

// this allows inlining template strings upbuild time:
// params can also be a string which will be parsed as a template.

dicole.register_template = function( template, params, prepare ) {
    if ( ! params ) throw "Invalid template source";

    if ( dojo.isString( params ) ) {
        dicole._template_sources[ template ] = { templateString : params };
    }
    else if ( params.templateString || params.templatePath ) {
        dicole._template_sources[ template ] = params;
    }
    else throw "Invalid template source";

    if ( prepare ) {
        dicole.prepare_template( template );
    }

    return 1;
};

dicole._template_prepare_queue = [];
dicole._template_prepare_flush_timeout = false;

// prepare template and it's strings asynchronously
dicole.prepare_template = function( template ) {
    dicole._template_prepare_queue.push( template );

    if ( dicole._template_prepare_queue.length > 24 ) {
        dicole.flush_template_prepare_queue();
    }

    if ( ! dicole._template_prepare_flush_timeout ) {
        dicole._template_prepare_flush_timeout = setTimeout( function() {
            dicole._template_prepare_flush_timeout = false;
            dicole.flush_template_prepare_queue();
        }, 1 );
    }
}

dicole.flush_template_prepare_queue = function() {
   var bundle = [];

    dojo.forEach( dicole._template_prepare_queue, function( template ) {
        if ( dicole._template_functions[ template ] ) {
            return;
        }
        var tmpl_source = dicole._template_sources[ template ];
        if ( tmpl_source.templateString ) {
            dicole._get_template( template, true, function( data ) {
                dicole._template_functions[ template ] = dicole._parse_template( data, template );
            } );
        }
        else {
            bundle.push( ""+tmpl_source.templatePath );
        }
    } );

    var sent_templates = dicole._template_prepare_queue;
    dicole._template_prepare_queue = [];

    if ( bundle.length < 1 ) {
        return false;
    }

    dojo.xhrPost({
        url : '/development_json/bundled_templates/',
        content : { bundle : dojo.toJson( bundle ) },
        handleAs : 'json',
        load : function( response ) {
            dojo.forEach( sent_templates, function( template ) {
                var tmpl_source = dicole._template_sources[ template ];
                var string = response.result[ ""+tmpl_source.templatePath ];
                dicole._get_template_strings( string, true );
                dicole._template_functions[ template ] = dicole._parse_template( string, template );
            } );
        }
    } );
}

// template can be either a registered template or an url to fetch template from
dicole.process_template = function( template, params ) {
    if ( ! dicole._template_functions[ template ] ) {
        dicole._template_functions[ template ] = dicole._parse_template(
            dicole._get_template( template, false ), template
        );
    }
    try {
        return dicole._template_functions[ template ]( params );
    }
    catch (e) {
        alert(e);
    }

};

dicole._get_template = function( template, async, callback ) {
    var tmpl_source = dicole._template_sources[ template ];

    var string = null;

    if ( tmpl_source && tmpl_source.templateString ) {
        string = tmpl_source.templateString;

        dicole._get_template_strings( string, async );

        if ( async ) {
            callback( string );
        }
    }
    else {
        dojo.xhrGet({
            url: tmpl_source ? tmpl_source.templatePath : template,
            sync: async ? false : true,
            load: function(data){
                string = data;

                if ( tmpl_source ) {
                    tmpl_source.templateString = string;
                }

                dicole._get_template_strings( string, async );

                if ( async ) {
                    callback( string );
                }
            }
        });
    }

    return string;
};

dicole._get_template_strings = function( string, async ) {
    var matches1 = string.match(/dicole\.msg\(\"([^\"]+)\"/g);
    var matches2 = string.match(/dicole\.msg\('([^']+)'/g);
    var strings = [];
    dojo.forEach(matches1, function(match) {
        strings.push(/dicole\.msg\(\"([^\"]+)\"/.exec(match)[1]);
    });
    dojo.forEach(matches2, function(match) {
        strings.push(/dicole\.msg\('([^']+)'/.exec(match)[1]);
    });
    dicole.load_localization_strings( strings, async );
};

dicole._parse_template = function( raw, template_name ) {
    var parts = raw.split("\n");
    var result_parts = [];
    for ( var i = 0; i < parts.length; i++ ) {
        var buf = parts[i] + "";
        if ( ! buf ) continue;
        var line_parts = [ [ 'l' ] ];
        var match = /(.*)(<%(#|=|==)?\s+(([^%]|%[^>])*)%>)(.*)/.exec( buf );
        while ( match && match[2] ) {
            buf = match[1];
            if ( match[6] ) line_parts.unshift( [ 's', match[6] ] );
            line_parts.unshift( [ match[3], match[4] ] );
            match = /(.*)(<%(#|=|==)?\s+(([^%]|%[^>])*)%>)(.*)/.exec( buf );
        }
        if ( buf ) line_parts.unshift( [ 's', buf ] );
        while ( line_parts.length ) result_parts.push( line_parts.shift() );
    }

    var eval_stack = [ "( dicole.base.template.iefix = function (p) { var _b = []; var _l = \"\\n\";\n" ];
    var push_stack = [];
    for ( var i = 0; i < result_parts.length; i++ ) {
        var type = result_parts[i][0] || '';
        var content = result_parts[i][1];

        if ( type == '' ) {
            if ( push_stack.length ) {
                eval_stack.push( '_b.push( ' + push_stack.join( ",\n" ) + "\n);\n" );
                push_stack = [];
            }
            eval_stack.push( content + "\n" );
        }
        else if ( type == 's' ) {
            content = content.replace( /("|\\)/g, "\\$1" );
            push_stack.push( '"'+ content +'"' );
        }
        else if ( type == '=' ) push_stack.push( content );
        else if ( type == '==' ) push_stack.push( 'dicole.encode_html( '+ content +' )' );
        else if ( type == 'l' ) push_stack.push( '_l' );
    }
    if ( push_stack.length ) eval_stack.push( '_b.push( ' + push_stack.join( ",\n" ) + "\n);\n" );
    eval_stack.push( "return _b.join(\"\"); } )" );

    try {
        eval( eval_stack.join("") );
    }
    catch (e) {
        alert("template parsing failed ("+ template_name +"): " + e );
    }

    return dicole.base.template.iefix;
};
