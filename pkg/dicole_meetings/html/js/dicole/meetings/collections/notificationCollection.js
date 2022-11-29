dojo.provide("dicole.meetings.collections.notificationCollection");

app.notificationCollection = Backbone.Collection.extend({
    model: app.notificationModel,
    initialize: function(){
        this.bind('all_seen', _.bind(this.markAllSeen, this));
    },

    markAllSeen : function() {
        var unseen = this.where({ 'is_seen' : 0 });

        if( unseen.length ) {
            // Set all seen
            _.each( unseen, function(o) { o.set({ 'is_seen' : 1 } ); });

            // Get array of ids
            var ids = _.map( unseen, function(o) { return o.id; });

            // Mark them seen
            $.post('/apigw/v1/users/'+app.auth.user+'/notifications/mark_seen', { id_list : ids }, function() {
                app.collections.notifications.fetch({ 'reset' : true});
            });
        }
    }
});
