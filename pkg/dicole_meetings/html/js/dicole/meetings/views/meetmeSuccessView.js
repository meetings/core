dojo.provide("dicole.meetings.views.meetmeSuccessView");

app.meetmeSuccessView = Backbone.View.extend({
    initialize : function(options) {
        _(this).bindAll('render');
        //this.model.bind('change', _.bind(this.render, this));
        this.matchmaker = options.matchmaker;
        this.user = options.user;
        this.meetme_user = options.meetme_user;
        this.lock = options.lock;
    },

    render : function() {
        this.$el.html( templatizer.meetmeSuccess( { meetme_user : this.meetme_user.toJSON(), matchmaker : this.matchmaker.toJSON(), lock : this.lock.toJSON(), current_user : this.user.toJSON() }) );
        app.helpers.keepBackgroundCover();
        window.scrollTo(0,0);
    }
});
