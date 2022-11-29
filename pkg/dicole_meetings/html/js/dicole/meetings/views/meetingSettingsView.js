dojo.provide("dicole.meetings.views.meetingSettingsView");

app.meetingSettingsView = Backbone.View.extend({

    initialize : function(options) {
        _(this).bindAll('render','save','close','renderRights','renderEmail','changeSetting','removeMeeting','cancelRemove');
        var showcase = dicole.create_showcase({
            'disable_close': true,
            'content' : '<div class="tempcontainer"></div>',
            'post_content_hook' : this.render,
            'vertical_align' : 'top'
        });
        this.delete_lock = 1;
    },

    events : {
        'click .setting.rights' : 'renderRights',
        'click .setting.email' : 'renderEmail',
        'click .save' : 'save',
        'click .remove' : 'removeMeeting',
        'click .cancel-remove' : 'cancelRemove',
        'click .close-modal' : 'close',
        'click .js_form_slider_button' : 'changeSetting',
        'click .back' : 'render'
    },

    render : function() {
        this.$el.html( templatizer.meetingSettings( { user : app.models.user.toJSON() } ) );
        this.$el.appendTo('.tempcontainer');
    },

    close : function(e) {
        if(e) e.preventDefault();
        this.remove();
        dojo.publish('showcase.close');
    },

    cancelRemove : function(e) {
        e.preventDefault();
        this.delete_lock = 1;
        this.render();
    },

    removeMeeting : function(e) {
        var $el = $(e.currentTarget);
        if( this.delete_lock === 1 ) {
            $('.remove-area.normal').hide();
            $('.remove-area.confirm').show();
            this.delete_lock = 0;
        } else {
            $('.remove-area.confirm').hide();
            $('.remove-area.removing').show();
            this.model.destroy({ success : function() {
                $('.remove-area.removing').hide();
                $('.remove-area.removed').show();
                window.location = '/meetings/summary';
            }});
        }
    },

    save : function(e) {
        if(e) e.preventDefault();
        var _this = this;

        $(e.currentTarget).text(MTN.t('Saving...'));

        this.model.save({}, { success : function() {
            _this.render();
        }});
    },

    renderEmail : function(e) {
        if(e) e.preventDefault();
        this.$el.html( templatizer.meetingSettingsEmail( this.model.toJSON().settings || {} ) );
    },

    changeSetting : function(e) {
        e.preventDefault();
        var $el = $(e.currentTarget);

        if( $el.attr('data-setting') === 'participant_digest' ) {
            $('.js_email_subchoices').slideToggle();
        }

        if( $el.hasClass('on-position') ) {
            $el.removeClass('on-position').addClass('off-position');
            this.model.get('settings')[$el.attr('data-setting')] = 0;

        } else {
            $el.removeClass('off-position').addClass('on-position');
            this.model.get('settings')[$el.attr('data-setting')] = 1;
        }
    },

    renderRights : function(e) {
        if(e) e.preventDefault();

        if( ! app.models.user.get('is_pro') ) {
            new app.sellProView({ mode : 'settings', callback : this.renderRights, model : app.models.user });
            return;
        }

        this.$el.html( templatizer.meetingSettingsRights( this.model.toJSON().settings || {} ) );
    }
});
