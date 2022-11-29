dojo.provide("dicole.meetings.views.meetingTopView");

app.meetingTopView = Backbone.View.extend({

    initialize : function(options) {
        _(this).bindAll('render','lctOpen','manageOpen');
    },

    events : {
        'click .js_open_lct' : 'lctOpen',
        'click .js_open_manage' : 'manageOpen'
    },

    render : function() {
        this.$el.html( dicole.process_template('meetings.basic_info', this.model.toJSON() ) );
    },

    manageOpen : function(e) {
        e.preventDefault();
        var lctView = new app.meetingSettingsView({
            model : this.model
        });
    },

    lctOpen : function(e) {
        e.preventDefault();
        var lctView = new app.meetingLctView({
            model : this.model
        });
    }
});
