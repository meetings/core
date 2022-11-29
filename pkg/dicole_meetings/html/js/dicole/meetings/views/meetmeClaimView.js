dojo.provide("dicole.meetings.views.meetmeClaimView");

app.meetmeClaimView = Backbone.View.extend({

    initialize : function(options) {
        _(this).bindAll('render','saveContinue','skipContinue' );

        // Setup state
        this.check_in_progress = false;
        this.fragment_edit_open = false;
        this.fragment_extra = 0;
        this.event_id = options.event_id || false;

    },

    events : {
        'click .save' : 'saveContinue',
        'click .skip' : 'skipContinue'
    },

    render : function() {

        var _this = this;

        // Render main template
        this.$el.html( templatizer.meetmeClaim( { user : this.model.toJSON(), in_event_flow : this.event_id }) );

        this.findAndShowFragment();

        this.switchBackground(app.meetme_themes[0].image);

        app.helpers.keepBackgroundCover();
    },

    skipContinue : function(e) {
        e.preventDefault();
        app.router.navigate('/meetings/wizard_apps', { trigger : true });
    },

    saveContinue : function(e) {
        e.preventDefault();

        var _this = this;

        if( this.check_in_progress === false ) {
            var $save = $('.change-url', this.el);
            var $warn = $('.warning', this.el);
            $save.html('checking...');
            var val = $('.handle-value').val();

            if( ! val ){
                $warn.html('min 3 chars');
                setTimeout(function(){$save.html('check'); },2000);
                return;
            }

            if( ! /^(.{3,})$/.test( val ) ) {
                $warn.html('min 3 chars');
                setTimeout(function(){$save.html('check'); },2000);
                return;
            }

            if ( ! /[a-zA-Z]/.test( val ) ) {
                $warn.html('must have one alphabet');
                setTimeout(function(){$save.html('check'); },2000);
                return;
            }

            if ( ! /^([a-zA-Z0-9\.\_-]+)$/.test( val ) ) {
                $warn.html('invalid characters');
                setTimeout(function(){$save.html('check'); },2000);
                return;
            }

            $.ajax({
                url : app.defaults.api_host + '/v1/users/',
                data : { user_fragment : val },
                type : 'GET',
                error : function(){
                    _this.check_in_progress = false;
                    _this.fragment_edit_open = false;
                    _this.model.save({ 'meetme_fragment' : val, 'matchmaker_fragment' : val }, { success : function() {
                        dicole.meetings.add_message('Your Meet Me address claimed succesfully!', 'message');
                        if( _this.event_id ) app.router.navigate('meetings/meetme_config/init/'+ _this.event_id , { trigger : true });
                        else  app.router.navigate('meetings/meetme_config', { trigger : true });
                    }});
                },
                success : function(res){
                    $warn.html('sorry, url taken');
                    _this.check_in_progress = false;
                    $('.handle-value').focus();
                    setTimeout( function(){
                        $save.html('Save');
                        $warn.hide();
                    },3000);
                }
            });
        }

    },

        switchBackground : function(url) {
        $('.content').css({
            'background-image' : 'url('+url+')',
            'background-size' : 'cover',
            'background-position' : '50% 50%',
            'background-attachment' : 'fixed'
        });
        $('#content-wrapper').css({
            'background-image' : 'none'
        });
    },

    getNextFreeFragment : function( fragment ) {
        var _this = this;

        if( this.fragment_extra !== 0 ) {
            fragment = fragment + this.fragment_extra;
        }
        this.fragment_extra++;

        $.ajax({
            url : app.defaults.api_host + '/v1/users/',
            data : { user_fragment : fragment },
            type : 'GET',
            error : function(){

                _this.model.set('meetme_fragment', fragment);

                // URL not taken, redraw template
                _this.renderUserURL();
            },
            success : function(res){

                // URL not free, find next
                _this.getNextFreeFragment( fragment );
            }
        });
    },

    findAndShowFragment : function() {

        // Show initial template
        this.renderUserURL();

        // If we don't have URL, start searching
        if( ! this.model.get('meetme_fragment') ) {
            this.url_extra = 0;
            this.getNextFreeFragment( this.buildUserFragment() );
        }
    },

    buildUserFragment : function() {
        var url = '' + this.model.get('name');
        return app.helpers.normalizeUrl(url);
    },

    renderUserURL : function() {
        $('.url-container', this.el).html( templatizer.meetmeMatchmakerUrl({
            meetme_fragment : this.model.get('meetme_fragment')
        }));
    },

    checkOpenEdit : function(){
        if( this.fragment_edit_open ) {
            var $save = $('.change-url');
            var $handle = $('.handle-value');
            $save.addClass('red').html('choose url first');
            $handle.focus();
            setTimeout(function(){$save.removeClass('red').html('check'); },2000);
            return true;
        }
        else{
            return false;
        }
    },

    beforeClose : function(){
        this.model.unbind();
    }
});

