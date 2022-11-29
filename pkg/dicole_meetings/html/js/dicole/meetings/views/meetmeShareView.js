dojo.provide("dicole.meetings.views.meetmeShareView");

app.meetmeShareView = Backbone.View.extend({

    initialize : function(options) {
        _(this).bindAll('render','returnToSettings','openApps','changeShareTarget','generateButtonCode','addQuickmeet','sendQuickmeet');

        this.selected_matchmaker_path = options.selected_matchmaker_path;
        this.user_model = options.user_model;
        this.matchmaker_collection = options.matchmakers_collection;

    },

    events : {
        'change #mm-select' : 'changeShareTarget',
        'click .return' : 'returnToSettings',
        'click .continue' : 'openApps',
        'click .url-input' : 'selectAll',
        'click #meetme-code' : 'selectAll',
        'change input[name="mmbutton"]' : 'generateButtonCode',
        'click #js_add_quickmeet' : 'addQuickmeet',
        'click .qm-send' : 'sendQuickmeet'
    },

    render : function() {
        var _this = this;

        // Try to find matchmaker by name
        var i, l = this.matchmaker_collection.length;
        for( i = 0; i < l; i++ ) {
            var n = this.matchmaker_collection.at(i).get('vanity_url_path') || '';
            if( n === this.selected_matchmaker_path ) {
                this.active_matchmaker = this.matchmaker_collection.at(i);
            }
        }

        var mm = this.active_matchmaker ? this.active_matchmaker.toJSON() : false;

        this.shareUrl = 'https://' + window.location.hostname + '/meet/' + _this.user_model.get('meetme_fragment') + ( mm ? '/' + mm.vanity_url_path : '');

        // Setup template
        this.$el.html( templatizer.meetmeShare({
            selected_matchmaker_path : this.selected_matchmaker_path,
            user : this.user_model.toJSON(),
            matchmakers : this.matchmaker_collection.toJSON(),
            share_url : this.shareUrl,
            current_matchmaker : mm
        }));
        this.refreshShareButtons();
        this.showBackgroundForUser(mm);
        $('#mm-select').chosen();

        // Remove styles when coming back from preview & show header
        $('#content-wrapper').removeAttr("style");
        $('#header-wrapper').show();

        // Setup copying to clipboard
        $('a#copy-url').zclip({
            path:'/js/dicole/meetings/vendor/zclip/zclip.swf',
            copy:function(){return _this.shareUrl; }
        });

        // Setup select all for signature area
        $('#signature-area').focus(function() {
            var $this = $(this);
            $this.select();

            // Work around Chrome's little problem
            $this.mouseup(function() {
                // Prevent further mouseup intervention
                $this.unbind("mouseup");
                return false;
            });
        });

        app.helpers.keepBackgroundCover();

        // HACKS
        if( dicole.get_global_variable('meetings_feature_quickmeet') && mm ) {

            app.quickmeetModel = Backbone.Model.extend({
                initialize : function() {
                }
            });
            app.quickmeetCollection = Backbone.Collection.extend({
                model : app.quickmeetModel,
                initialize : function() {
                    this.url = app.defaults.api_host + '/v1/matchmakers/' + mm.id + '/quickmeets';
                }
            });
            app.collections.quickmeets = new app.quickmeetCollection();
            app.collections.quickmeets.fetch({ success : function() {
                $('#quickmeets-container').html( templatizer.quickMeets( { quickmeets : app.collections.quickmeets.toJSON() } ));
            }});
        }
    },

    addQuickmeet : function(e) {
        e.preventDefault();
        var _this = this;
        app.collections.quickmeets.create({
            matchmaker_id : this.active_matchmaker.get('id'),
            email : $('#quickmeet_email').val(),
            name : $('#quickmeet_name').val(),
            phone : $('#quickmeet_phone').val(),
            organization : $('#quickmeet_organization').val(),
            title : $('#quickmeet_title').val(),
            meeting_title : $('#quickmeet_meeting_title').val(),
            message : $('#quickmeet_message').val()
        }, { success : function() {
            _this.render();
        }});
    },

    sendQuickmeet : function(e) {
        e.preventDefault();
        var $el = $(e.currentTarget);
        $.post(app.defaults.api_host + '/v1/matchmakers/' + this.active_matchmaker.get('id') + '/quickmeets/' + $el.attr('data-id') + '/send', function(){
            alert('qm sent');
        });
    },

    selectAll : function(e) {
        $(e.currentTarget).select();
    },

    showBackgroundForUser : function() {
        var url = '';
        if( this.user_model.get('meetme_background_theme') == 'c' || this.user_model.get('meetme_background_theme') == 'u') {
            url = this.user_model.get('meetme_background_image_url');
        }
        else{
            url = app.meetme_themes[(this.user_model.get('meetme_background_theme') || 0 )].image;
        }
        this.switchBackground(url);
    },

    switchBackground : function(url) {
        $('#bb-background .bg:last-child').css({'background-image' : 'url('+url+')'});
        $('#content-wrapper').css({'background-image' : 'none'});
    },

    refreshShareButtons : function(){
        // Refresh Linkedin
        try{
            IN.init();
        }
        catch(ex){}

        // Reload twitter
        try{
            twttr.widgets.load();
        }
        catch(ex){}

        // Reload gplus
        try{
            gapi.plus.go();
        }
        catch(ex){}

        // Reload meeting buttons
        try{
            MTN.init();
        }
        catch(ex){}
    },

    changeShareTarget : function(e) {
        var shareTarget = $(e.currentTarget).val();
        app.router.navigate('meetings/meetme_share/' + shareTarget, {trigger:true});
    },

    openApps : function(e) {
        e.preventDefault();
        if(Modernizr.localstorage) localStorage.removeItem('new_meetme_user');
        app.views.header.render();
        app.router.navigate('meetings/wizard_apps', {trigger:true});
    },

    returnToSettings : function(e) {
        e.preventDefault();
        app.router.navigate('meetings/meetme_config', {trigger:true});
    },

    generateButtonCode : function() {
        var user = this.user_model.get('matchmaker_fragment');
        var scheduler = this.active_matchmaker ? this.active_matchmaker.get('vanity_url_path') : '';
        var type = $('input[name="mmbutton"]:checked').attr('data-type');
        var color = $('input[name="mmbutton"]:checked').attr('data-color');
        $('#meetme-code').text('<script defer="defer" src="//platform.meetin.gs/mtn.js" type="text/javascript"></script>' +
            '<script type="MTN/app" data-user="'+user+'" data-type="'+type+'" data-scheduler="'+scheduler+'" data-color="'+color+'"></script>');
    }
});
