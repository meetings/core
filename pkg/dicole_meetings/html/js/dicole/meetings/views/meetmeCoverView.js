dojo.provide("dicole.meetings.views.meetmeCoverView");
app.meetmeCoverView = Backbone.View.extend({

    initialize : function(options) {
        _(this).bindAll('render','newScheduler','openCalendar','openBgSelector','openConfig','openVideo','openScheduler','removeScheduler','mmHover','mmHoverStop','editDescription','openMeetmePage','editProfile');

        this.user_model = options.user_model;
        this.matchmaker_collection = options.matchmaker_collection;
        this.user_fragment = options.user_fragment;
        this.mode = options.mode || "normal";
        this.selected_matchmaker_path = options.selected_matchmaker_path;
        this.waiting_for_save = false;
        this.single_preview = false;
    },

    events : {
        'click .edit-desc' : 'editDescription',
        'click .new-scheduler' : 'newScheduler',
        'click .edit-scheduler' : 'editScheduler',
        'click .remove-scheduler' : 'removeScheduler',
        'click .claim' : 'signup',
        'click .meet-me' : 'openCalendar',
        'click .back-to-config' : 'openConfig',
        'mouseenter .matchmaker' : 'mmHover',
        'mouseleave .matchmaker' : 'mmHoverStop',
        'click .open-scheduler' : 'openScheduler',
        'click .video' : 'openVideo',
        'click .view-page' : 'openMeetmePage',
        'click .bg-change' : 'openBgSelector',
        'click .edit-profile' : 'editProfile',
        'click .go-to-share' : 'goToShare',
        'click .skip-continue' : 'skipContinue'
    },

    render : function() {

        var _this = this;

        // 1. Edit mode
        if( this.mode === 'edit'  ) {
            this.$el.html( templatizer.meetmeCover( { user : this.user_model.toJSON(), matchmaker_collection : this.matchmaker_collection.toJSON(), mode : this.mode }) );

            // Highlight next steps & hide header
            if( this.user_model.get('new_user_flow') ) {
                if( ! this.matchmaker_collection.length ) $('.new-scheduler').hintLight({ zindex_override : 1000 });
                if( this.matchmaker_collection.length ) $('.go-to-share').hintLight({ zindex_override : 1000 });
                if( ! this.user_model.get('is_trial_pro') && ! this.user_model.get('is_pro') && ! this.user_model.get('is_free_trial_expired') ) {
                    new app.sellProView({ mode : 'general_trial', model : app.models.user });
                }
            }
        }

        // 2. Cover for a single matchmaker page
        else if( this.selected_matchmaker_path ) {
            // Create temp collection with only the desired view
            if( this.mode === 'preview' ) this.single_preview = true;
            this.mode = 'single';
            this.active_matchmaker = this.matchmaker_collection.findWhere({ 'vanity_url_path' : this.selected_matchmaker_path });

            // If matchmaker is not found, navigate to top level meetme page
            if( ! this.active_matchmaker ) {
                app.router.navigate( '/meet/' + this.user_model.get('meetme_fragment'), {trigger : true});
                return;
            }
            var temp_col = new app.matchmakerCollection(this.active_matchmaker);
            if ( this.active_matchmaker.get('additional_direct_matchmakers') ) {
                this.active_matchmaker.get('additional_direct_matchmakers').forEach(
                    function( mmr_id ) {
                        var mmr = this.matchmaker_collection.get(mmr_id);
                        if ( mmr ) {
                            temp_col.add( mmr );
                        }
                    }, this
                );
            }
            this.$el.html( templatizer.meetmeCover( { user : this.user_model.toJSON(), matchmaker_collection : temp_col.toJSON(), mode : this.mode, preview : this.single_preview }) );
            this.renderExtras();
        }

        // 3. Cover for all
        else {
            this.$el.html( templatizer.meetmeCover( { user : this.user_model.toJSON(), matchmaker_collection : this.matchmaker_collection.toJSON(), mode : this.mode }) );
        }

        this.showBackground(true);

        if( dicole.get_global_variable('meetings_sharing_failed') ){
            var showcase = dicole.create_showcase({
                "disable_close" : true,
                "content" : templatizer.meetmeButtonTips()
            });
            dicole.set_global_variable('meetings_sharing_failed',false);
        }

        app.helpers.preloadMeetmeBackgrounds();

        app.helpers.keepBackgroundCover();

        // setup dragging
        if( this.mode === 'edit'  ) {
            $('.matchmakers').addClass('sortable').sortable({ forcePlaceholderSize : true }).bind('sortupdate', function(e, ui) {
                var order = [];
                $('div.matchmaker').each(function(i) {
                    order.push($(this).attr('data-id'));
                });
                _this.user_model.save({ meetme_order : order });
            });
        }
    },

    skipContinue : function(e) {
        e.preventDefault();
        app.router.navigate('/meetings/wizard_apps', { trigger : true });
    },

    editProfile : function(e) {
        e.preventDefault();

        // If not viewing own page, don't show profile
        if( app.auth.user !== this.user_model.get('id') ) {
            return;
        }

        var $el = $('.js_meetings_edit_my_profile_open');
        if( $el.length ) {
            dicole.click_element( $el[0] );
        }
    },

    openBgSelector : function(e) {
        e.preventDefault();
        new app.meetmeBgSelectorView({
            model : this.user_model,
            uploadSaveCb : function( view, data ) {
                view.model.save({
                    meetme_background_upload_id : data.result.result.upload_id,
                    meetme_background_theme : 'c'
                });
                app.views.current.switchBackground(data.result.result.upload_preview_url);
                view.closeModal();
            },
            themeSaveCb : function( view, id ) {
                app.views.current.switchBackground(app.meetme_themes[id].image);
                view.model.save({meetme_background_theme : id});
                view.closeModal();
            }
        });
    },

    openMeetmePage : function(e) {
        e.preventDefault();
        window.open('/meet/' + this.user_model.get('matchmaker_fragment'));
    },

    goToShare : function(e) {
        e.preventDefault();
        app.router.navigate( '/meetings/meetme_share/', {trigger : true});
    },

    openScheduler : function(e) {
        e.preventDefault();
        if( this.mode === 'edit' ) return;
        var extra = this.single_preview ? '/preview' : '';
        var id = $(e.currentTarget).attr('data-id');
        app.router.navigate( '/meet/' + this.user_fragment + '/' + this.matchmaker_collection.get(id).get('vanity_url_path') + '/calendar' + extra, {trigger : true});
    },

    mmHover : function(e) {
        var id = $(e.currentTarget).attr('data-id');
        var mm = this.matchmaker_collection.get(id);
        if(this.skipBgChange(mm)) return;
        this.showBackgroundForMatchmaker(mm);
    },

    mmHoverStop : function(e) {
        if(this.skipBgChange()) return;
        this.showBackground();
    },

    skipBgChange : function(mm) {
        if(this.mode === 'single') return true;
        else if(mm && ! mm.get('direct_link_enabled')) return true;
        return false;
    },

    switchBackground : function(url) {
        $('#bb-background').show();
        $('#bb-background .bg:last-child').css({'background-image' : 'url('+url+')'});
        $('#content-wrapper').css({'background-image' : 'none'});
    },

    animatedSwitchBackground : _.debounce(function(url) {
        $('#bb-background').show();
        var $bg_bot = $('#bb-background .bg:first-child');
        var $bg_top = $('#bb-background .bg:last-child');
        $('#content-wrapper').css({
            'background-image' : 'none'
        });
        $bg_bot.css({'background-image' : 'url('+url+')'});
        $bg_top.fadeOut('fast',function() {
            $bg_top.insertBefore($bg_bot).fadeIn();
        });
    },300),

    showBackgroundForMatchmaker : function(mm) {
        var url = '';
        if( mm.get('background_theme') == 'c' || mm.get('background_theme') == 'u') {
            url = mm.get('background_preview_url') || mm.get('background_image_url');
        }
        else{
            url = app.meetme_themes[mm.get('background_theme')].image;
        }
        this.animatedSwitchBackground(url);
    },

    showBackground : function(skip_animate) {
        var url = '';
        if( this.mode === 'single' && this.active_matchmaker.get('direct_link_enabled') ) {
            if( this.active_matchmaker.get('background_theme') == 'c' || this.active_matchmaker.get('background_theme') == 'u') {
                url = this.active_matchmaker.get('background_image_url');
            }
            else{
                url = app.meetme_themes[(this.active_matchmaker.get('background_theme') || 0 )].image;
            }
        }
        else{
            if( this.user_model.get('meetme_background_theme') == 'c' || this.user_model.get('meetme_background_theme') == 'u') {
                url = this.user_model.get('meetme_background_image_url');
            }
            else{
                url = app.meetme_themes[(this.user_model.get('meetme_background_theme') || 0 )].image;
            }
        }
        if( skip_animate ) this.switchBackground(url);
        else this.animatedSwitchBackground(url);
    },

    renderExtras : function() {
        var _this = this;
        var $extra = $('.extra', this.el);
        var mm_event = this.active_matchmaker.get('event_data');
        if( mm_event && mm_event.extra_user_matchmaker_html_url_base ) {
            this.$el.addClass('centered');
            //var spinner = new Spinner(app.defaults.spinner_opts).spin( $extra[0] );
            $.ajax( mm_event.extra_user_matchmaker_html_url_base , {
                data : {
                    id : this.user_model.get('id')
                },
                success : function(res) {
                    $extra.html('' + res);
                    if( _this.active_matchmaker.get('youtube_url') ) {
                        $extra.find('.pitch-button').html('<a class="button blue video" href="'+_this.active_matchmaker.get('youtube_url')+'" target="_blank">Watch video</a>');
                    }
                }
            });
        }
    },

    openVideo : function(e) {
        e.preventDefault();

        var url = this.active_matchmaker.get('youtube_url');
        var video_id = url.match(/[a-zA-Z0-9\-\_]{11}/);
        if( ! video_id || ! video_id[0] ) {
            window.open(url,'_blank');
        } else {
            var showcase = dicole.create_showcase({
                "disable_close" : true,
                "content" : templatizer.youtubeEmbed( { video_id : video_id[0], width : 640, height : 390 } )
            });
        }
    },


    openConfig : function(e) {
        e.preventDefault();
        var mm_path = 'default';
        if( this.selected_matchmaker_path !== 'default' ) {
            mm_path = this.selected_matchmaker_path + '/for_event/' + this.active_matchmaker.get('matchmaking_event_id');
        }
        app.router.navigate( '/meetings/meetme_config/' + mm_path, {trigger : true});
    },

    openCalendar : function(e) {
        e.preventDefault();
        app.router.navigate( '/meet/' + this.user_fragment + '/' + ( this.active_matchmaker.get('vanity_url_path') || 'default' ) + '/calendar', {trigger : true});
    },

    signup : function(e) {
        e.preventDefault();
        window.location = '/meetings/wizard';
    },


    newScheduler : function(e) {
        e.preventDefault();
        if( this.user_model.get('is_pro') || _.filter(this.matchmaker_collection.toJSON(), function(o) { return parseInt(o.matchmaking_event_id) > 0 ? false : true; }).length < 1 ) {
            app.router.navigate('/meetings/meetme_config/new', { trigger : true } );
        }
        else {
            new app.sellProView({ mode : 'meetme', callback : function() {
                app.router.navigate('/meetings/meetme_config/new', { trigger : true } );
            }, model : app.models.user });
        }
    },

    removeScheduler : function(e) {
        e.preventDefault();
        // TODO: prevent bgchange when removing
        var _this = this;
        var $el =  $(e.currentTarget);
        var mid = $el.attr('data-id');
        var model = this.matchmaker_collection.get(mid);
        model.url = app.defaults.api_host + '/v1/matchmakers/' + mid;

        var showcase = dicole.create_showcase({
            "disable_close" : true,
            "content" : templatizer.meetmeConfirmDelete( { model : model.toJSON() } )
        });

        $(showcase.nodes.container).on('click', '.confirm-delete', function(e) {
            $(e.currentTarget).text('Removing...');
            model.destroy( { success : function() {
                dojo.publish('showcase.close');
                _this.matchmaker_collection.remove(model);
                _this.render();
            }});
        });
    },

    editScheduler : function(e) {
        e.preventDefault();
        var meetingTypeName = $(e.currentTarget).attr('data-name');
        app.router.navigate('/meetings/meetme_config/' + ( meetingTypeName || 'default' ), { trigger : true } );
    },

    editDescription : function(e) {
        e.preventDefault();
        var _this = this;
        var $desc = $('.meetme-description',this.el);

        var showcase = dicole.create_showcase({
            "disable_close" : true,
            "content" : templatizer.meetmeEditDescription( { user : this.user_model.toJSON() } )
        });

        $(showcase.nodes.container).on('click', '#save-description', function(e) {
            e.preventDefault();
            var $save = $(e.currentTarget).text(MTN.t('Saving...'));
            var $el = $('#meetme-description');
            _this.user_model.save({'meetme_description' : $el.val() }, { success : function(){
                $desc.html($el.val().replace(/\n/g, '<br />'));
                dojo.publish('showcase.close');
            }} );
        });

    },

    beforeClose : function() {
        if ( this.user_model ) {
            this.user_model.unbind();
        }
        if ( this.matchmakers_collection ) {
            this.matchmakers_collection.unbind();
        }
    }
});
