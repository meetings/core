dojo.provide("dicole.meetings.views.notificationsView");

app.notificationsView = Backbone.View.extend({

    initialize : function(options) {
        _(this).bindAll('render','readNotification');
        this.collection.bind('reset', _.bind(this.render, this));
        this.$counter = $('#header-notifications .counter');
        this.$container = this.$el.find('.notifications-container');
    },

    events : {
        'click .notification' : 'readNotification'
    },

    render : function() {

        // If no notifications
        if( ! this.collection.length ) {
            this.$container.html('<div class="notification"><i class="ico ico-error"></i><p class="text">'+MTN.t("You don't have any notifications yet.")+'</p></div>' );
            this.$counter.hide();
        } else {
            var buffer = '';
            var unseen_count = 0;

            _.each( this.collection.toJSON(), function( o ) {
                if( ! o.is_seen ) unseen_count++;
                buffer += templatizer.notification(o);
            });

            this.$container.html(buffer);

            // Hide or show counter
            if( unseen_count ) {
                this.$counter.text(unseen_count).show();
            } else {
                this.$counter.hide();
            }
        }
    },

    readNotification : function(e) {
        e.preventDefault();
        var $el = $(e.currentTarget).removeClass('unread');
        var id = $el.attr('data-id');

        if( ! id ) return;

        var model = this.collection.get(id);
        var url = model.get('data').meeting.enter_url;

        $('#meeting, #summary').addClass('fade loader');
        if( model.get('is_read') === 1 || model.get('is_read') === '1' ) {
            window.location = url;
        } else {
            model.save({'is_read' : 1}, { success : function() {
                window.location = url;
            }});
        }
    }
});

