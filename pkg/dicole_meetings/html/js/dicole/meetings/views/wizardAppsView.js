dojo.provide("dicole.meetings.views.wizardAppsView");

app.wizardAppsView = Backbone.View.extend({
    initialize : function(options) {
        _(this).bindAll('render');
    },

    events : {
        'click .next-step' : 'nextStep'
    },

    render : function() {
        // Setup template
        this.$el.html( templatizer.wizardApps() );

        // Remove possible background hiding, when coming from preview
        $('#content-wrapper').removeAttr("style");
        $('#header-wrapper').show();
    },

    nextStep : function(e) {
        e.preventDefault();

        // Check if we need to redirect to event
        $(e.currentTarget).text('Working...');
        var redirect_url = '/meetings';
        if( Modernizr.localstorage && localStorage.getItem('event_organizer_return_url') ) {
            redirect_url = localStorage.getItem('event_organizer_return_url');
            localStorage.setItem('event_organizer_return_url','');
        }

        window.location = redirect_url;
    }
});
