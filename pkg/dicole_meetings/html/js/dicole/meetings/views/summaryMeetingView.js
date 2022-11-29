dojo.provide("dicole.meetings.views.summaryMeetingView");

app.summaryMeetingView = Backbone.View.extend({

    initialize: function(options) {
        _(this).bindAll('removeSuggestion');
    },

    render: function() {
        this.$el.html( templatizer.meetingCard( this.model.toJSON() ) ); // Render template
        this.$el.attr('id', this.model.id );
        this.$el.attr('href', this.model.get('enter_url'));
        this.$el.addClass('meeting');
        if( this.model.get('source') && this.model.get('source') == 'google' ){
            dojo.publish("new_node_created", [ this.el ]);
        }
        return this;
    },

    events: {
        'click .google-corner' : 'removeSuggestion',
        'click .phone-corner' : 'removeSuggestion',
        'click' : 'openMeeting'
    },

    removeSuggestion : function(e){
        e.preventDefault();
        this.model.collection.remove( this.model );
        this.model.save({ disabled : 1 });
    },

    openMeeting : function(e){
        // Empty handler catches event for tracking
    }
});
