dojo.provide("dicole.meetings.views.connectionErrorView");

app.connectionErrorView = Backbone.View.extend({

    initialize : function(options) {
        _(this).bindAll('render','retry' );
    },

    events : {
        'click .retry' : 'retry'
    },

    render : function() {
        this.$el.html( templatizer.connectionError() );
    },

    retry : function(e) {
        e.preventDefault();
        window.location.reload();
    }
});

