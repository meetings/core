dojo.provide("dicole.meetings.views.footerView");

app.footerView = Backbone.View.extend({
    initialize : function(options) {
        _.bindAll(this, "render");
        this.type = options.type || 'normal';
        this.render();
    },

    render : function() {
        this.$el.html( templatizer.footer({ view_type : this.type }) );
        dojo.publish("new_node_created",[this.el]);
    }
});

