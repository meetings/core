dojo.provide("dicole.meetings.views.upgradeSuccessView");

app.upgradeSuccessView = Backbone.View.extend({

    initialize : function(options) {
        _(this).bindAll('render');
        this.model.bind('change', _.bind(this.render, this));
    },

    events : {
    },

    render : function() {
        this.$el.html( templatizer.upgradeSuccess( { user : this.model.toJSON() }) );
        window.scrollTo(0, 0);
    }
});

