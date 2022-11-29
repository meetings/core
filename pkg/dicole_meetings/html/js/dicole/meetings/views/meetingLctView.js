dojo.provide("dicole.meetings.views.meetingLctView");

app.meetingLctView = Backbone.View.extend({

    initialize : function(options) {
        _(this).bindAll('render','save','close','disable','renderHangouts','renderCustom','renderLync','renderTeleconf','renderSkype');
        var showcase = dicole.create_showcase({
            "disable_close": true,
            "content" : '<div class="tempcontainer"></div>',
            "post_content_hook" : this.render
        });
        this.mode = '';
    },

    events : {
        'click .tool.skype' : 'renderSkype',
        'click .tool.custom' : 'renderCustom',
        'click .tool.lync' : 'renderLync',
        'click .tool.teleconf' : 'renderTeleconf',
        'click .tool.hangout' : 'renderHangouts',
        'click .tool.disable' : 'disable',
        'click .save' : 'save',
        'click .close-modal' : 'close',
        'click #com-lync-sip' : 'enableLyncSip',
        'click .back' : 'render'
    },

    render : function() {
        this.$el.html( templatizer.meetingLctPicker({ user : app.models.user.toJSON() }) );
        this.$el.appendTo('.tempcontainer');
        if( this.model.get('online_conferencing_option') ) {
            $('.tool.'+this.model.get('online_conferencing_option'), this.el).addClass('selected');
            $('.tool.disable',this.el).css('display','inline-block');
        }
    },

    close : function(e) {
        if(e) e.preventDefault();
        this.remove();
        dojo.publish('showcase.close');
    },

    disable : function(e) {
        if(e) e.preventDefault();
        var _this = this;
        $('.tool.disable',this.el).html('<i class="ico-cross"></i>Disabling...');
        this.model.save({ online_conferencing_option : '' }, { success : function() {
            _this.close();
            dicole.meetings.refresh_top();
        }});
    },

    save : function(e) {
        if(e) e.preventDefault();
        var _this = this;

        // TODO: Get meeting data before

        $(e.currentTarget).text(MTN.t('Saving...'));

        var conf = this.model.get('online_conferencing_data') || {};
        switch (this.mode) {
            case 'skype':
                conf.skype_account = $('#com-skype').val();
                this.model.set('skype_account', $('#com-skype').val() );
                break;
            case 'custom':
                conf.custom_uri = $('#com-custom-uri').val();
                conf.custom_name = $('#com-custom-name').val();
                conf.custom_description = $('#com-custom-description').val();
                break;
            case 'teleconf':
                conf.teleconf_pin = $('#com-pin').val();
                conf.teleconf_number = $('#com-number').val();
                break;
            case 'hangout':
                break;
            case 'lync':
                conf.lync_mode = $('input[name=lync_mode]:checked').val();
                conf.lync_copypaste = tinyMCE.activeEditor.getContent();
                conf.lync_sip = $('#com-lync-sip').val();
                break;
            default:
                console.log('error, no tool selected');
            break;
        }

        this.model.save({
            online_conferencing_data : conf,
            online_conferencing_option : this.mode
        }, { success : function() {
            _this.remove();
            dojo.publish('showcase.close');
            dicole.meetings.refresh_top();
        } });
    },

    renderHangouts : function(e) {
        if(e) e.preventDefault();

        if( ! app.models.user.get('is_pro') ) {
            this.showTrialPopup(this.renderHangouts);
            return;
        }

        this.mode = 'hangout';
        this.$el.html( templatizer.meetingLctHangouts( { meeting : this.model.toJSON() } ) );
    },

    showTrialPopup : function(f) {
        new app.sellProView({ mode : 'lct', callback : f, model : app.models.user });
    },

    renderSkype : function(e) {
        if(e) e.preventDefault();
        this.mode = 'skype';
        this.$el.html( templatizer.meetingLctSkype( { meeting : this.model.toJSON(), user : app.models.user.toJSON() } ) );
    },

    renderLync : function(e) {
        if(e) e.preventDefault();

        if( ! app.models.user.get('is_pro') ) {
            this.showTrialPopup(this.renderLync);
            return;
        }


        this.mode = 'lync';
        this.$el.html( templatizer.meetingLctLync( { meeting : this.model.toJSON() } ) );

       var _this = this;
       tinyMCE.init( {
            menubar: false,
            statusbar: false,
            toolbar: false,
            selector: "#com-lync-pastearea",
            language: 'en',
            width: 400,
            height: 100,
            plugins: "autolink,paste",

            content_css : "/css/tinymce.css",

            paste_create_paragraphs : true,
            paste_create_linebreaks : false,
            paste_strip_class_attributes: 'all',
            paste_auto_cleanup_on_paste: true,
            setup : function(ed) {
                ed.on('focus', function(e) {
                    _this.enableLyncUri();
                });
            }
        } );

        // Select correct option
        var conf = this.model.get('online_conferencing_data') || {};
        if( ! conf.lync_mode || conf.lync_mode === 'uri' ) {
             $('input:radio[name=lync_mode]').filter('[value=uri]').prop('checked', true);
        }
        else{
             $('input:radio[name=lync_mode]').filter('[value=sip]').prop('checked', true);
        }

    },

    enableLyncUri : function() {
        $('input:radio[name=lync_mode]').filter('[value=uri]').prop('checked', true);
    },
    enableLyncSip : function() {
        $('input:radio[name=lync_mode]').filter('[value=sip]').prop('checked', true);
    },

    renderCustom : function(e) {
        if(e) e.preventDefault();

        if( ! app.models.user.get('is_pro') ) {
            this.showTrialPopup(this.renderCustom);
            return;
        }

        this.mode = 'custom';
        this.$el.html( templatizer.meetingLctCustomUrl( { meeting : this.model.toJSON() } ) );
    },

    renderTeleconf : function(e) {
        if(e) e.preventDefault();
        this.mode = 'teleconf';
        this.$el.html( templatizer.meetingLctTeleconf( { meeting : this.model.toJSON() } ) );
    }
});
