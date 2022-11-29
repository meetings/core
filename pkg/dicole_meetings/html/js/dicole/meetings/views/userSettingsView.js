dojo.provide("dicole.meetings.views.userSettingsView");

app.userSettingsView = Backbone.View.extend({

    // TODOS:
    // * use this.model
    // * ensure this is bound for all functions

    initialize : function(options) {
        _(this).bindAll('render','close','renderCover','renderLogin','renderTimezone','renderCalendar','renderAppearance','renderAccount','saveRegional','renderTimeline','saveTimeline','savePassword','removeAccount','disconnectAccount','cancelSubscription');
        this.model.bind('reset', this.render);
        this.mode = options.mode || '';
    },

    events : {
        'click .setting,.menu-link' : 'navigate',
        'click .close-modal' : 'close',
        'click .back' : 'render',
        'click .save-timeline' : 'saveTimeline',
        'click .save-password' : 'savePassword',
        'click .upgrade' : 'upgrade',
        'click .cancel-subscription' : 'cancelSubscription',

        'click .save-regional' : 'saveRegional',
        'click .save-appearance' : 'saveAppearance',
        'click .remove-account' : 'removeAccount',
        'click .js_theme_select_option' : 'selectTheme',
        'click .js_reset_uploaded_logo' : 'resetLogo',
        'click .js_reset_uploaded_bg' : 'resetBackground',
        'click .disconnect-device' : 'disconnectDevice',
        'click .js_form_slider_button' : 'changeSetting',
        'click .send-receipt' : 'sendReceipt',
        'focus #ics-url' : 'handleTextareafocus',
        'click .disconnect' : 'disconnectAccount'
    },

    render : function() {

        var _this = this;

        // Ensure white bg
        $('#content-wrapper').attr('style','');
        $('#bb-background').hide();
        app.helpers.keepBackgroundCover();

        // Remove class, as it prevents the white background form being shown
        $('body').removeClass('action_meetings_task_meet');

        // Ensure full height setting container
        setTimeout( function() {
            _this.fixHeight();
        }, 500);

        // Render menu and base
        this.$el.html( templatizer.userSettings({ user : app.models.user.toJSON(), mode : this.mode }) );

        // Setup setting container
        this.$setting = $('.settings-container',this.el);

        // Call wanted render
        switch(this.mode) {
            case 'login':
                this.renderLogin();
            break;
            case 'calendar':
                this.renderCalendar();
            break;
            case 'timeline':
                this.renderTimeline();
            break;
            case 'timezone':
                this.renderTimezone();
            break;
            case 'branding':
                this.renderAppearance();
            break;
            case 'regional':
                this.renderRegional();
            break;
            case 'account':
                this.renderAccount();
            break;
            default:
                this.renderCover();
        }
    },

    handleTextareafocus : function(e) {
        var $this = $(e.currentTarget);

        $this.select();

        window.setTimeout(function() {
            $this.select();
        }, 1);

        // Work around WebKit's little problem
        function mouseUpHandler() {
            // Prevent further mouseup intervention
            $this.off("mouseup", mouseUpHandler);
            return false;
        }

        $this.mouseup(mouseUpHandler);
    },

    fixHeight : function() {
        $('.settings-container').css({ height : 'auto' });
        setTimeout( function() {
            $('.settings-container').css({ height : $('#content-wrapper').height() - 163 });
        },10);
    },

    upgrade : function(e) {
        e.preventDefault();

        if( ! app.models.user.get('is_pro') && ! app.models.user.get('free_trial_has_expired') ) {
            new app.sellProView({ callback : function(){ window.location.reload(); }, model : app.models.user });
        } else {
            app.router.navigate('/meetings/upgrade',{ trigger : true });
        }
    },

    navigate : function(e) {
        if(e) e.preventDefault();
        var address = $(e.currentTarget).attr('href') || $(e.currentTarget).attr('data-href');
        app.router.navigate(address,{ trigger : true });
    },

    save : function(e) {
        if(e) e.preventDefault();
    },

    sendReceipt : function(e) {
        e.preventDefault();
        var $link = $(e.currentTarget).text( MTN.t('Sending...') );
        $.post('/apigw/v1/users/'+app.auth.user+'/user_payments/'+$link.attr('data-id')+'/send_receipt', function(res) {
            $link.text( MTN.t('Receipt sent.') );
        });
    },

    showReceipts : function() {
        var _this = this;
        var $container = $('.receipts-container');
        $.get('/apigw/v1/users/'+app.auth.user+'/user_payments', function(res) {
            if( ! res.length ) return;
            $container.html( templatizer.userSettingsAccountReceipts({ receipts : res }));
            _this.fixHeight();
        });
    },


    cancelSubscription : function(e) {
        if(e) e.preventDefault();

        var showcase = dicole.create_showcase({
            "disable_close" : true,
            "content" : templatizer.userSettingsCancelSubscription( { user : app.models.user.toJSON() } )
        });

        $(showcase.nodes.container).on('click', '.confirm-cancel', function(e) {
            e.preventDefault();
            $.post('/apigw/v1/users/'+app.auth.user+'/cancel_subscription', function(res) {
                if( res && ! res.error ) {
                    window.location.reload();
                }
            });
        });
    },

    changeSetting : function(e) {
        e.preventDefault();
        var $el = $(e.currentTarget);

        if( $el.hasClass('on-position') ) {
            $el.removeClass('on-position').addClass('off-position');

        } else {
            $el.removeClass('off-position').addClass('on-position');
        }
    },

    saveRegional : function(e) {
        if(e) e.preventDefault();
        var button = new app.helpers.activeButton( e.currentTarget );
        var time_zone = $('#timezone').val();
        var new_lang = $('#language',this.el).val();
        app.models.user.save({ language : new_lang, time_zone : time_zone } , { patch : true, success : function() {
            window.location.reload();
        }});
    },

    disconnectDevice : function(e) {
        e.preventDefault();
        var button = new app.helpers.activeButton( e.currentTarget );
        $.post('/apigw/v1/users/'+app.auth.user+'/suggestion_sources/set_container_batch', {
            container_name : $(e.currentTarget).attr('data-name'),
            container_type : $(e.currentTarget).attr('data-type'),
            container_id : $(e.currentTarget).attr('data-id'),
            sources : [] // empty sources array to disable all
        }, function(res) {
            button.remove();
        });
    },

    savePassword : function(e) {
        if(e) e.preventDefault();
        var button = new app.helpers.activeButton( e.currentTarget );
        var new_password = $('#password',this.el).val();
        app.models.user.save({ password : new_password }, { patch : true, success : function() {
            button.setDone();
        }});
    },

    renderCover : function(){
        this.$setting.html( templatizer.userSettingsCover( { user : app.models.user.toJSON() } ) );
    },

    renderLogin : function(e) {
        if(e) e.preventDefault();
        this.$setting.html( templatizer.userSettingsLogin( { user : app.models.user.toJSON() } ) );
    },

    renderTimezone : function(e) {
        if(e) e.preventDefault();
    },

    renderCalendar : function(e) {
        if(e) e.preventDefault();
        var _this = this;

        // Get suggestion sources
        $.get('/apigw/v1/users/'+app.auth.user+'/suggestion_sources', function(response) {

            // Get containers aka. devices
            var container_ids = _.uniq( _.filter(response, function(r) { return  r.container_type !== 'google'; }), function(o) { return o.container_id; });

            _this.$setting.html( templatizer.userSettingsCalendar( { user : app.models.user.toJSON(), containers : container_ids } ) );
            dicole.uc_click_fetch_open( 'meetings', 'ics_feed_instructions', {
                width : 800,
                container : _this.el
            });

        });
    },

    renderTimeline : function(e) {
        if(e) e.preventDefault();
        var _this = this;

        // Get suggestion sources
        $.get('/apigw/v1/users/'+app.auth.user+'/suggestion_sources', function(response) {

            var sorted_sources = _.groupBy(response, function(r) { return r.container_id; });

            var user_enabled = app.models.user.get('source_settings').enabled || {};
            var user_disabled = app.models.user.get('source_settings').disabled || {};

            // Add enabled value to sources
            _.each( sorted_sources, function(a,b,c) { _.each(c[b], function(v,i,o) {
                o[i].enabled = user_enabled[v.uid] ? 1 : (v.is_primary && ! user_disabled[v.uid]) ? 1 : 0;
            } ); } );

            _this.$setting.html( templatizer.userSettingsTimeline( { user : app.models.user.toJSON(), sources : sorted_sources } ) );

            dojo.publish("new_node_created", [ _this.el ]);
        });
    },

    saveTimeline : function(e) {
        if(e) e.preventDefault();
        var button = new app.helpers.activeButton( e.currentTarget );

        var settings = { disabled : {}, enabled : {} };

        $('.slider-button', this.el).each(function() {
            var $el = $(this);
            if( $el.hasClass('on-position') ) {
                settings.enabled[$el.attr('data-setting')] = 1;
            } else {
                settings.disabled[$el.attr('data-setting')] = 1;
            }
        });

        app.models.user.save({ source_settings :  settings }, { success : function() {
            button.setDone();
        }});
    },

    renderRegional : function(e) {
        if(e) e.preventDefault();

        this.$setting.html( templatizer.userSettingsRegional( { user : app.models.user.toJSON() } ) );

        var tz = dicole.get_global_variable('meetings_time_zone_data');

        var $select = $('#timezone').chosen().change(function(){
            var option = $select.get(0).options[$select.get(0).selectedIndex];
            if ( option && option.value ) {
                $('#js_timezone_preview').html( moment().utc().add('seconds', tz.data[option.value].offset_value ).format('HH:mm dddd'));
            }
        });
    },

    /* Appearance */

    renderAppearance : function(e) {
        if(e) e.preventDefault();
        this.$setting.html( dicole.process_template("meetings.admin_appearance", app.models.user.toJSON() ) );
        dicole.meetings.init_upload(122, 32, '#logo-upload','#js_logo_upload_draft_id','#js_logo_upload_image');
        dicole.meetings.init_upload(120, 120, '#bg-upload','#js_bg_upload_draft_id','#js_bg_upload_image');
    },

    saveAppearance : function(e) {
        e.preventDefault();
        var vals = {
            custom_background_upload_id :  $('#js_bg_upload_draft_id').val(),
            custom_header_upload_id : $('#js_logo_upload_draft_id').val(),
            custom_theme : $('.theme-select-bg.selected>.theme-select').attr('data-theme-name')
        };

        var button = new app.helpers.activeButton( e.currentTarget );
        app.models.user.save( vals, { patch : true, success : function() {
            window.location.reload();
        }});
    },

    resetLogo : function(e) {
        e.preventDefault();
        var $image = $('#js_logo_upload_image');
        var $draft_id_input = $('#js_logo_upload_draft_id');
        $draft_id_input.attr('value', '-1');
        $image.attr('src', '').hide();
        dicole.meetings.redraw_theme();
    },

    resetBackground : function(e) {
        e.preventDefault();
        var $image = $('#js_bg_upload_image');
        var $draft_id_input = $('#js_bg_upload_draft_id');
        $draft_id_input.attr('value', '-1');
        $image.attr('src', '' ).hide();
        dicole.meetings.redraw_theme();
    },

    selectTheme : function(e) {

        e.preventDefault();
        var $el = $(e.currentTarget);
        $('.theme-select-bg').removeClass('selected');
        $el.parent().addClass('selected');

        var $theme_input = $('#theme');
        var theme = $el.attr('data-theme-name');
        $theme_input.attr('value', theme);

        //dicole.meetings.current_theme = theme;
        //dicole.meetings.redraw_theme();
    },

    renderAccount : function(e) {
        if(e) e.preventDefault();
        this.$setting.html( templatizer.userSettingsAccount( { service_name : dicole.get_global_variable('meetings_service_name'), user : app.models.user.toJSON() } ) );
        this.showReceipts();
    },

    removeAccount : function(e) {
        if(e) e.preventDefault();

        var showcase = dicole.create_showcase({
            "disable_close" : true,
            "content" : templatizer.userSettingsAccountRemove( { user : app.models.user.toJSON() } )
        });

        $(showcase.nodes.container).on('click', '.confirm-delete', function(e) {
            e.preventDefault();
            var button = new app.helpers.activeButton(e.currentTarget);
            app.models.user.destroy({ success : function() {
                window.location = 'http://meetin.gs/xlogout?url_after_logout=http://www.meetin.gs/account-deleted';
            }});
        });
    },

    disconnectAccount : function(e) {
        if(e) e.preventDefault();
        var $el = $(e.currentTarget);
        var network = $el.attr('data-network-id');

        $.post(app.helpers.getServiceDisconnectUrl(network), function(response) {
            if ( response.success ) {
                var $container = $('#'+network+'_connect_container');
                $container.find('.connected').hide();
                $container.find('.disconnected').show();
            }
        });
    }
});
