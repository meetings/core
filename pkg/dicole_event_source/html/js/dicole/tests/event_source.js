dojo.provide('dicole.tests.event_source');

dojo.require('dicole.event_source.LivingObjectList');
dojo.require("dicole.event_source.ServerWorker");

doh.register("LivingObjectList", [
    function object_creation() {
        var lol = new dicole.event_source.LivingObjectList();
    },

    function basic_calls() {
        var lol = new dicole.event_source.LivingObjectList();
        lol.show(1,50);
        lol.kill(1);
        lol.query();
    },

    function functionality() {
        var lol = new dicole.event_source.LivingObjectList();
        lol.kill(5);
        doh.is( [], lol.query() );
        lol.show(1,50);
        doh.is( [{ id : 1, time : 50 }], lol.query() );
        lol.show(2,40);
        doh.is( [{ id : 1, time : 50 },{ id : 2, time : 40 }], lol.query() );
        lol.show(3,60);
        doh.is( [{ id : 3, time : 60 },{ id : 1, time : 50 },{ id : 2, time : 40 }], lol.query() );
        lol.show(1,80);
        doh.is( [{ id : 1, time : 80 },{ id : 3, time : 60 },{ id : 2, time : 40 }], lol.query() );
        lol.show(3,10);
        doh.is( [{ id : 1, time : 80 },{ id : 3, time : 60 },{ id : 2, time : 40 }], lol.query() );
        lol.kill(2);
        doh.is( [{ id : 1, time : 80 },{ id : 3, time : 60 }], lol.query() );
        doh.is( [{ id : 1, time : 80 }], lol.query(1) );
        doh.is( [{ id : 3, time : 60 }], lol.query(10,1) );
        doh.is( [], lol.query(10,2) );
        lol.show(5,10);
        doh.is( [{ id : 1, time : 80 },{ id : 3, time : 60 }], lol.query() );
        lol.hide(3,70);
        doh.is( [{ id : 1, time : 80 }], lol.query() );
        lol.show(3,75);
        doh.is( [{ id : 1, time : 80 },{ id : 3, time : 75 }], lol.query() );
    },

    function reverse_test() {
        var lol1 = new dicole.event_source.LivingObjectList();
        for ( var i = 0; i < 10; i++ ) {
            lol1.show(i,i);
        }
        var lol2 = new dicole.event_source.LivingObjectList();
        for (var j = 9; j > -1; j-- ) {
            lol2.show(j,j);
        }
        doh.is( lol1.query(), lol2.query() );
    },

    function same_time_reverse_test() {
        var lol1 = new dicole.event_source.LivingObjectList();
        for ( var i = 0; i < 10; i++ ) {
            lol1.show(i,1);
        }
        var lol2 = new dicole.event_source.LivingObjectList();
        for (var j = 9; j > -1; j-- ) {
            lol2.show(j,1);
        }
        doh.is( lol1.query(), lol2.query() );
    }
]);
