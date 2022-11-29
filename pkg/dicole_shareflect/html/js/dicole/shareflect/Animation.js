dojo.provide('dicole.shareflect.Animation');
dojo.declare('dicole.shareflect.Animation', null, {

    constructor : function() {
        console.log("Animation created");
        this._animations = [];
    },
    
    test_me : function( by ) {
        console.log("Animation tested by " + by);
    }
} );