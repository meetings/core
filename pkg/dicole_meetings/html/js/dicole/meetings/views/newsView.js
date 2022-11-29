dojo.provide("dicole.meetings.views.newsView");

app.newsView = Backbone.View.extend({

    initialize : function(options) {
        _(this).bindAll('render','dismissItem');
        this.collection.bind('reset', _.bind(this.render, this));
    },

    events : {
        'click .next-link' : 'dismissItem'
    },

    render : function() {

        // Remove wrong language targeted news
        var lang = dicole.get_global_variable('meetings_lang');
        this.collection.remove( _.filter(this.collection.models, function(m){ return ( m.get('limitlanguage') && m.get('limitlanguage') !== lang ); }) );

        // Ensure we have content to render
        if( ! this.collection.length || ! this.collection.at(0).get('contenthtml') ) return;

        this.$el.html( templatizer.newsBar( { 'item' : this.collection.at(0).toJSON(), 'count_left' : this.collection.length } ) );
        this.$el.show();
    },

    dismissItem : function(e) {
        e.preventDefault();
        var id = $(e.currentTarget).attr('data-id');

        // Remove from current
        if( id && this.collection.get(id) ) {
            this.collection.get(id).destroy();
        } else {
            if( window.qbaka ) qbaka.report(this.collection);
        }

        // Re-render if models left
        if( this.collection.length ) {
            this.render();
        } else {
            this.$el.slideToggle().html('');
        }
    }
});

