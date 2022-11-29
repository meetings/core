dojo.provide("dicole.meetings.views.summaryLoadingContactsView");

app.summaryLoadingContactsView = Backbone.View.extend({

    initialize: function(options) {
    },

    events : {
        'click .cancel' : 'showSummary'
    },

    showSummary : function(e){
        e.preventDefault();
        app.router.upcoming();
    },

    render: function() {
        this.$el.html( templatizer.summaryGoogleLoading() ); // Render template
        var spinner = new Spinner(app.defaults.spinner_opts).spin( $('#loader' , this.el )[0] );
        return this;
    },

    connected : function(){
        this.$el.html( templatizer.summaryGoogleLoaded() ); // Render template
        return this;
    }
});
