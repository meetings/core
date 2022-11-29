dojo.provide("dicole.meetings.views.summaryHighlightView");

app.summaryHighlightView = Backbone.View.extend({

    initialize: function(options) {
    },

    render: function() {
        this.$el.html( templatizer.highlightCard( this.model.toJSON() ) ); // Render template
        this.$el.attr('id', this.model.id );
        this.$el.attr('href', this.model.get('enter_url'));
        this.$el.addClass('highlight action');
        return this;
    },

    events: {
        'click .google-corner' : 'removeSuggestion'
    },

    removeSuggestion : function(e){
        e.preventDefault();
        this.model.collection.remove( this.model );
        this.model.save({ disabled : 1 });
    }
});

