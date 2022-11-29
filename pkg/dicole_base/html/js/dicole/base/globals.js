dojo.provide('dicole.base.globals');

dicole._global_variables = {};

dicole.set_global_variables = function( variable_map ) {
    if ( variable_map.uri_encoded_variables ) {
        variable_map = dojo.fromJson( decodeURIComponent( variable_map.uri_encoded_variables ) );
    }
    for ( var variable in variable_map ) {
        dicole.set_global_variable( variable, variable_map[variable] );
    }
};

dicole.set_global_variable = function( variable, val ) {
    var old_val = dicole._global_variables[ variable ];
    dicole._global_variables[ variable ] = val;
    dojo.publish( 'global_variable_set', [ variable, val, old_val ] );
};

dicole.get_global_variable = function( variable ) {
    return dicole._global_variables[ variable ];
};
