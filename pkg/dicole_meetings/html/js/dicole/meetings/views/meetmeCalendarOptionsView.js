dojo.provide("dicole.meetings.views.meetmeCalendarOptionsView");

app.meetmeCalendarOptionsView = Backbone.View.extend({

    initialize : function(options) {
        _(this).bindAll('render', 'openOptions', 'closeOptions', 'valueChanged');

        // Setup models
        this.user_model = options.user_model;
        this.matchmaker_model = options.matchmaker_model;
        this.mode = options.mode;
    },

    events : {
        'click .open-cal-options' : 'openOptions',
        'click .close-cal-options' : 'closeOptions',
        'change .cal-box' : 'valueChanged'
    },

    render : function() {

        var _this = this;

        this.$el.html( templatizer.meetmeCalendarOptions({ user : this.user_model.toJSON(), matchmaker : this.matchmaker_model.toJSON(), mode : this.mode }) );

        // Case 1: New mmr /w google/phone already connected --> Default selected (if available), rest unselected, options closed ( should options be open, if no default found? )
        // Case 2: New/old mmr /w new google connect --> Default selected, rest unselected, opts closed, all new
        // Case 3. Old mmr /w google/phone connected --> Show current situation, options closed, show NEW count if new calendars appeared

        // Init values to source_settings, if empty
        if(this.matchmaker_model.get('source_settings') && _.size(this.matchmaker_model.get('source_settings').disabled) === 0 && _.size(this.matchmaker_model.get('source_settings').enabled) === 0) {
            this.initValues();
        }
    },

    initValues : function() {
        var i, l = this.user_model.get('suggestion_sources').length;
        for( i = 0; i < l; i++ ) {
            if( this.user_model.get('suggestion_sources')[i].selected_by_default ) {
                this.matchmaker_model.get('source_settings').enabled[this.user_model.get('suggestion_sources')[i].uid] = 1;
            }
            else{
                this.matchmaker_model.get('source_settings').disabled[this.user_model.get('suggestion_sources')[i].uid] = 1;
            }
        }
    },

    valueChanged : function(e) {
        this.getElementDataToModel(e.currentTarget);
    },

    getElementDataToModel : function(el) {

        // Get needed values
        var id = $(el).attr('data-id');
        var val = $(el).is(':checked');

        // Update model to reflect the dom
        if(val) {
            this.matchmaker_model.get('source_settings').enabled[id] = 1;
            delete this.matchmaker_model.get('source_settings').disabled[id];
        }
        else {
            this.matchmaker_model.get('source_settings').disabled[id] = 1;
            delete this.matchmaker_model.get('source_settings').enabled[id];
        }
    },

    openOptions : function(e) {
        e.preventDefault();
        this.mode = 'open';
        this.render();
    },

    closeOptions : function(e) {
        e.preventDefault();
        this.mode = 'closed';
        this.render();
    }
});

