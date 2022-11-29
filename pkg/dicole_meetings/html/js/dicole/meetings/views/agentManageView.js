/*jslint todo: true, vars: true, eqeq: true, nomen: true, sloppy: true, white: true, unparam: true, node: true, regexp: true */
/*global app, templatizer, _, $, dojo, Backbone */

dojo.provide("dicole.meetings.views.agentManageView");

app.agentManageView = Backbone.View.extend({
    initialize : function( args ) {
        var bf = _.filter( _.keys( this ), function( key ) { key.indexOf('bound_') == 0 } );
        bf.unshift( this );
        _.bindAll.apply( _, bf );

        this.adminData = {};
    },

    events : {
        'click .select-area' : 'bound_select_area'
    },

    bound_refresh_and_render : function() {
        var adminDataFetch = $.get( '/meetings_json/agent_manage_data', {} );

        $.when(adminDataFetch).then( function( adminData ) {
            this.adminData = adminData.result;
            if ( this.adminData.shared_accounts.length == 1 ) {
                window.location = this.adminData.shared_accounts[0].url;
            }
            this.bound_render();
        }.bind(this) );
    },

    bound_render : function() {
        var templateData = this.adminData;
        templateData.user = this.model.toJSON();

        this.$el.html( templatizer.agentManage( templateData ) );
        dojo.publish("new_node_created", [ this.$el.get(0) ] );

        app.helpers.keepBackgroundCover();
    },

    bound_select_area : function( event) {
        event.preventDefault();
        window.location = this.adminData.shared_accounts_map[ $( event.srcElement ).attr('x-data-area') ].url;
    }
});
