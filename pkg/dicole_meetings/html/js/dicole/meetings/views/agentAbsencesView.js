/*jslint todo: true, vars: true, eqeq: true, nomen: true, sloppy: true, white: true, unparam: true, node: true, regexp: true */
/*global app, templatizer, _, $, dojo, Backbone */

dojo.provide("dicole.meetings.views.agentAbsencesView");

app.agentAbsencesView = Backbone.View.extend({
    initialize : function() {
        _(this).bindAll('refresh_and_render', 'render', 'add_absence', 'remove_absence', 'select_category');
        this.absencesData = {};
    },

    events : {
        'click .select-category' : 'select_category',
        'click .add-absence-button' : 'add_absence',
        'click .remove-absence-button' : 'remove_absence',
        'mouseover .remove-absence-button' : 'highlight_absence',
        'mouseout .remove-absence-button' : 'unhighlight_absence',
        'click .agent-button.plus' : 'show_agent_absence_adding',
        'click .agent-button.minus' : 'hide_agent_absence_adding'
    },

    refresh_and_render : function() {
        var absencesDataFetch = $.get( '/meetings_json/agent_absences_data', {
            category : app.absences_selected_category ? app.absences_selected_category : ''
        } );

        $.when(absencesDataFetch).then( function( absencesData ) {
            this.absencesData = absencesData.result;
            this.render();
        }.bind(this) );
    },

    render : function() {
        var templateData = this.absencesData;
        templateData.user = this.model.toJSON();

        this.$el.html( templatizer.agentAbsences( templateData ) );
        dojo.publish("new_node_created", [ this.$el.get(0) ] );

        app.helpers.keepBackgroundCover();
    },
    select_category : function( event) {
        event.preventDefault();
        app.absences_selected_category = $( event.srcElement ).attr('x-data-category');
        this.refresh_and_render();
    },
    show_agent_absence_adding : function( event ) {
        event.preventDefault();
        var agent_id = $( event.srcElement ).attr('x-data-agent-id');
        var container = $( '#agent-'+agent_id );
        $( '.agent-absence-adder', container ).show();
        $( '.agent-button.plus', container ).hide();
        $( '.agent-button.minus', container ).show();
    },
    hide_agent_absence_adding : function( event ) {
        event.preventDefault();
        var agent_id = $( event.srcElement ).attr('x-data-agent-id');
        var container = $( '#agent-'+agent_id );
        $( '.agent-absence-adder', container ).hide();
        $( '.agent-button.plus', container ).show();
        $( '.agent-button.minus', container ).hide();
    },
    add_absence : function ( event ) {
        event.preventDefault();
        var agent_id = $( event.srcElement ).attr('x-data-agent-id');
        var container = $( '#agent-'+agent_id );

        var absenceAddPost = $.ajax( '/meetings_json/add_agent_absence', {
            data : {
                agent_id : agent_id,
                first_day : $('.first-day', container ).val(),
                last_day : $('.last-day', container ).val(),
                reason : $('.reason', container ).val()
            }
        } );

        $.when(absenceAddPost).then( function( result ) {
            if ( result.error && result.error.message ) {
                alert(result.error.message);
            }
            else {
                this.refresh_and_render();
            }
        }.bind(this) );
    },
    remove_absence : function ( event ) {
        event.preventDefault();
        var agent_id = $( event.srcElement ).attr('x-data-agent-id');
        var absence_id = $( event.srcElement ).attr('x-data-absence-id');

        var absenceRemovePost = $.ajax( '/meetings_json/remove_agent_absence', {
            data : {
                agent_id : agent_id,
                absence_id : absence_id
            }
        } );

        $.when(absenceRemovePost).then( function( result ) {
            if ( result.error && result.error.message ) {
                alert(result.error.message);
            }
            else {
                this.refresh_and_render();
            }
        }.bind(this) );
    },
    highlight_absence : function( event ) {
        var absence_id = $( event.srcElement ).attr('x-data-absence-id');
        var container = $( '#absence-'+absence_id );
        container.addClass('highlighted');
    },
    unhighlight_absence : function( event ) {
        var absence_id = $( event.srcElement ).attr('x-data-absence-id');
        var container = $( '#absence-'+absence_id );
        container.removeClass('highlighted');
    }
});
