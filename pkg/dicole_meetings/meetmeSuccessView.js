dojo.provide("dicole.meetings.views.meetmeSuccessView");

app.meetmeSuccessView = Backbone.View.extend({

    initialize : function(options) {
        _(this).bindAll('render');
        //this.model.bind('change', _.bind(this.render, this));
        // TODO: pass event if available
        this.quickmeet_key = options.quickmeet_key || '';
        this.matchmaker = options.matchmaker;
        this.user = options.user;
        this.meetme_user = options.meetme_user;
        this.lock = options.lock;
    },

    events : {
    },

    render : function() {
        this.$el.html( templatizer.meetmeSuccess( { user : this.meetme_user, matchmaker : this.matchmaker.toJSON(), lock : this.lock.toJSON(), quickmeet : this.quickmeet_key, current_user : this.user }) );
        app.helpers.keepBackgroundCover();
    },

    beforeClose : function(){
        this.model.unbind();
    }
});

