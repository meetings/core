dojo.provide("dicole.meetings.router");

app.general_router = Backbone.Router.extend({
   prepare : function( view_type ){

        // Clear current view if available
        if( app.views.current ) {
            app.views.current.close();
            $('#push').before('<div id="bb-content"></div>');
        }

        // Ensure user model
        app.models.user = app.models.user || new app.userModel({ id : app.auth.user });

        // Show loader
        $('#bb-content').html('<div id="loader"></div>');
        var spinner = new Spinner(app.defaults.spinner_opts).spin( $('#loader' , this.el )[0] );

        // Show header
        app.views.header = app.views.header || new app.headerView({ el : '#header-wrapper', model : app.models.user, view_type : view_type || '' });

        // Show footer
        app.views.footer = app.views.footer || new app.footerView({ el : '#bb-footer', view_type : view_type || '' });

        return true;
    }
});

app.backboneRouter = app.general_router.extend({
    routes : {
        'meet' : "signup",
        'meetings/meetme_claim' : 'meetmeClaim',
        'meetings/meetme_claim/' : 'meetmeClaim',
        'meetings/meetme_claim/0' : 'meetmeClaim',
        'meetings/meetme_claim/for_event/:eid' : 'meetmeClaim',
        'meetings/meetme_config' : 'meetmeCoverEdit',
        'meetings/meetme_config/' : 'meetmeCoverEdit',
        'meetings/meetme_config/0' : 'meetmeCoverEdit',
        'meetings/meetme_config/init/:id' : 'initConfigFromEvent',
        'meetings/meetme_config/:vanity_url_path' : 'config',
        'meetings/meetme_config/:vanity_url_path/for_event/:eid' : 'config',
        'meetings/meetme_share' : 'share',
        'meetings/meetme_share/' : 'share',
        'meetings/meetme_share/:mm_name' : 'share',
        'meet/:user' : 'meetmeCover',
        'meet/:user/' : 'meetmeCover',
        'meet/:user/:mm' : 'meetmeCover',
        'meet/:user/:mm/' : 'meetmeCover',
        'meet/:user/:mm/success/:lock' : 'meetmeSuccess',
        'meet/:user/:mm/success/:lock/' : 'meetmeSuccess',
        'meet/:user/:mm/calendar' : 'meetmeCalendar',
        'meet/:user/:mm/calendar/' : 'meetmeCalendar',
        'meet/:user/:mm/calendar/:mode' : 'meetmeCalendar',
        'meet/:user/:mm/calendar/:mode/' : 'meetmeCalendar',
        'meet/:user/:mm/calendar/:mode/:modeparam' : 'meetmeCalendar',
        'meet/:user/:mm/calendar/:mode/:modeparam/' : 'meetmeCalendar',
        'meet/:user/:mm/:mode' : 'meetmeCover',
        'meet/:user/:mm/:mode/' : 'meetmeCover',
        'meetings/wizard_profile' : 'wizardProfile',
        'meetings/wizard_profile/' : 'wizardProfile',
        'meetings/wizard_profile/0/:eid' : 'wizardProfile',
        'meetings/wizard_apps' : 'wizardApps',
        'meetings/user' : 'userSettings',
        'meetings/user/' : 'userSettings',
        //'meetings/user/profile' : 'userProfile',
        'meetings/user/settings' : 'userSettings',
        'meetings/user/settings/:setting' : 'userSettings',
        'meetings/upgrade' : 'upgrade',
        'meetings/upgrade/' : 'upgrade',
        'meetings/upgrade/success/:type' : 'upgradeSuccess',
        'meetings/upgrade/pay' : 'upgradePay',
        'meetings/upgrade/pay/:type' : 'upgradePay',
        'meetings/upgrade/:vendor' : 'upgrade',
        'meetings/upgrade/:vendor/pay' : 'upgradePay',
        'meetings/agent_manage' : 'agentManage',
        'meetings/agent_manage/' : 'agentManage',
        'meetings/agent_admin' : 'agentAdmin',
        'meetings/agent_admin/' : 'agentAdmin',
        'meetings/agent_admin/:area' : 'agentAdmin',
        'meetings/agent_admin/:area/' : 'agentAdmin',
        'meetings/agent_admin/:area/:section' : 'agentAdmin',
        'meetings/agent_admin/:area/:section/' : 'agentAdmin',
        'meetings/agent_absences' : 'agentAbsences',
        'meetings/agent_booking' : 'agentBooking',
        'meetings/agent_booking/' : 'agentBooking',
        'meetings/agent_booking/:area' : 'agentBooking',
        'meetings/agent_booking/:area/' : 'agentBooking',
        'meetings/agent_booking/confirm/:lock_id' : 'agentBookingConfirm'
    },

    signup : function() {
        window.location = 'http://www.meetin.gs';
    },

    wizardProfile : function() {
        this.prepare('ext');

        // Hide footer
        $('#bb-footer').hide();

        // Disable header link
        $('#header-logo a').on('click', function(e) { e.preventDefault(); });

        // Query parameters are not in use so we have to check the existence of the the var from url
        var open_profile = dicole.get_global_variable('meetings_open_profile');

        app.views.current = new app.wizardProfileView({ el : '#bb-content', model : app.models.user, open_profile : open_profile });

        app.models.user.fetch({ data : { image_size : 160 }, success : function(){
            app.views.current.render();
        }});
    },

    wizardApps : function() {
        this.prepare();

        // Disable header link
        $('#header-logo a').on('click', function(e) { e.preventDefault(); });

        $('#bb-footer').hide();

        app.views.current = new app.wizardAppsView({ el : '#bb-content' });
        app.views.current.render();
    },

    meetmeClaim : function(eid) {

        this.prepare();

        eid = eid || false;

        app.views.current = new app.meetmeClaimView({
            el : '#bb-content',
            model : app.models.user,
            event_id : eid
        });

        app.models.user.fetch({ success :function() {
            app.views.current.render();
        }});
    },

    meetmeCoverEdit : function(meetme_fragment) {
        this.prepare();

        if( Modernizr.localstorage && localStorage.getItem('googleConnectReturn') ) {
            app.router.navigate('/meetings/meetme_config/' + localStorage.getItem('googleConnectReturn'), { trigger : true });
            return;
        }

        if( window.location.href.indexOf('new_user') !== -1 || ( Modernizr.localstorage && localStorage.getItem('new_user_flow') === 1 ) ) {
            if(Modernizr.localstorage) localStorage.removeItem('new_user_flow');
            app.models.user.set('new_user_flow', 1);
        }

        // Create matchmaker collection if needed && setup from local storage if wanted
        if( ! app.collections.matchmakers ) app.collections.matchmakers = new app.matchmakerCollection();

        app.collections.matchmakers.url =  app.defaults.api_host + '/v1/users/' + app.auth.user + '/matchmakers';

        // Create the view
        app.views.current = new app.meetmeCoverView({
            el : '#bb-content',
            matchmaker_collection : app.collections.matchmakers,
            user_model : app.models.user,
            user_fragment : meetme_fragment,
            mode : 'edit'
        });

        app.collections.matchmakers.fetch({update : true, remove : false, success: function() {
            app.models.user.fetch({ data : { user_fragment : meetme_fragment, image_size : 140 }, success : function() {

                if( ! app.models.user.get('meetme_fragment') ) {
                    app.router.navigate('/meetings/meetme_claim', { trigger : true });
                    return;
                }

                app.views.current.render();
            }});
        }, data : { user_fragment : meetme_fragment }});
    },


    meetmeCover : function(meetme_fragment, matchmaker_fragment, mode) {

        mode = mode || 'normal';

        this.prepare('ext');

        // Hide header in case no user
        if( ! app.auth.user ) {
            $('#header-wrapper').hide();
        } else {
            app.models.user.fetch();
        }

        // Create matchmaker collection if needed && setup from local storage if wanted
        if( ! app.collections.matchmakers ) app.collections.matchmakers = new app.matchmakerCollection();
        if( mode === 'preview' && Modernizr.localstorage && localStorage.getItem('previewMatchmakers') ) app.collections.matchmakers.set( JSON.parse( localStorage.getItem('previewMatchmakers') ) );

        // Create user model for the user to be met with
        app.models.meetme_user = app.models.meetme_user || new app.userModel();
        if( mode === 'preview' && Modernizr.localstorage && localStorage.getItem('previewUser') ) app.models.meetme_user.set( JSON.parse( localStorage.getItem('previewUser') ) );

        // Setup urls
        app.models.meetme_user.url = app.defaults.api_host + '/v1/users/';
        app.collections.matchmakers.url = app.defaults.api_host + '/v1/matchmakers/';

        // Create the view
        app.views.current = new app.meetmeCoverView({
            el : '#bb-content',
            matchmaker_collection : app.collections.matchmakers,
            user_model : app.models.meetme_user,
            user_fragment : meetme_fragment,
            mode : mode,
            selected_matchmaker_path : matchmaker_fragment || ''
        });

        if( mode === 'preview' && matchmaker_fragment ) {
            var mm = app.collections.matchmakers.findWhere({ 'vanity_url_path' : matchmaker_fragment });
            if( mm && mm.get('direct_link_enabled') != 1 ) {
                app.router.navigate('meet/'+ meetme_fragment +'/'+matchmaker_fragment+'/calendar/preview', { trigger : true } );
            }
            else{
                mm.set('cid', mm.cid);
                app.views.current.render();
            }
            return;
        }

        app.collections.matchmakers.fetch({update : true, remove : false, success: function() {

            // Redirect to calendar if no public cover for matchmaker
            if( matchmaker_fragment ) {
                var mm = app.collections.matchmakers.findWhere({ 'vanity_url_path' : matchmaker_fragment });
                if( mm && mm.get('direct_link_enabled') != 1 ) {
                    app.router.navigate('meet/'+ meetme_fragment +'/'+matchmaker_fragment+'/calendar', { trigger : true } );
                    return;
                }
            }

            app.models.meetme_user.fetch({ data : { user_fragment : meetme_fragment, image_size : 140 }, success : function() {
                app.models.meetme_user.set('meetme_fragment', meetme_fragment );
                app.views.current.render();
            }});
        }, data : { user_fragment : meetme_fragment, matchmaker_fragment : ( matchmaker_fragment || '' ) }});
    },

    meetmeSuccess : function(user_fragment, matchmaker_fragment, lock_id) {
        this.prepare();

        app.models.lock = app.models.lock || new app.matchmakerLockModel({ id : lock_id});
        var lockFetch = app.models.lock.fetch();

        app.models.active_matchmaker = app.models.active_matchmaker || new app.matchmakerModel();
        app.models.active_matchmaker.url = app.defaults.api_host + '/v1/matchmakers/';
        var matchmakerFetch = app.models.active_matchmaker.fetch({ data : { user_fragment : user_fragment, matchmaker_fragment : matchmaker_fragment } });

        app.models.meetme_user = app.models.meetme_user || new app.userModel();
        app.models.meetme_user.url = app.defaults.api_host + '/v1/users/';
        var meetmeUserFetch = app.models.meetme_user.fetch({ data : { user_fragment : user_fragment, image_size : 140  } });

        var userFetch = app.models.user.fetch();

        app.views.current = new app.meetmeSuccessView({ el : '#bb-content', lock : app.models.lock, matchmaker : app.models.active_matchmaker, meetme_user : app.models.meetme_user, user : app.models.user });

        $.when( lockFetch,  matchmakerFetch, userFetch, meetmeUserFetch ).then(function() {
            app.views.current.render();
        });
    },

    meetmeCalendar : function(user_meetme_fragment, matchmaker_fragment, mode, modeparam) {
        mode = mode || 'normal';
        matchmaker_fragment = matchmaker_fragment || 'default';

        this.prepare('ext');

        // Hide header in case no user
        if( ! app.auth.user ) {
            $('#header-wrapper').hide();
        } else {
            app.models.user.fetch();
        }

        if( ! app.collections.matchmakers ) {
            app.collections.matchmakers = new app.matchmakerCollection();
            app.collections.matchmakers.url = app.defaults.api_host + '/v1/matchmakers/';
        }
        if( mode === 'preview' && app.collections.matchmakers.length === 0 && Modernizr.localstorage && localStorage.getItem('previewMatchmakers') ) app.collections.matchmakers.set( JSON.parse( localStorage.getItem('previewMatchmakers') ) );

        app.models.meetme_user = app.models.meetme_user || new app.userModel();
        app.models.meetme_user.url = app.defaults.api_host + '/v1/users/';
        if( mode === 'preview' && Modernizr.localstorage && localStorage.getItem('previewUser') ) app.models.meetme_user.set( JSON.parse( localStorage.getItem('previewUser') ) );

        if ( mode === 'reschedule' ) {
            app.models.rescheduled_meeting = app.models.rescheduled_meeting || new app.meetingModel( { id : modeparam } );
        }

        // Hack the fragment into user model
        app.models.meetme_user.set('matchmaker_fragment', user_meetme_fragment);

        app.views.current = new app.meetmeCalendarView({
            el : '#bb-content',
            matchmakers_collection : app.collections.matchmakers,
            user_model : app.models.meetme_user,
            rescheduled_meeting : app.models.rescheduled_meeting,
            user_fragment : user_meetme_fragment,
            mode : mode,
            modeparam : modeparam,
            selected_matchmaker_path : matchmaker_fragment
        });

        if ( mode == 'preview' ) {
            app.views.current.render();
            return;
        }

        var connection_error_shown = false;
        var view_rendered = false;

        setTimeout( function showErrorAfterLongTimeout(){
            if ( connection_error_shown || view_rendered ) {
                return;
            }
            connection_error_shown = true;
            app.views.current = new app.connectionErrorView({
                el : '#bb-content'
            });
            app.views.current.render();
        }, 30000 );

        var matchmakersFetch = $.Deferred();
        var userFetch = $.Deferred();
        var rescheduleFetch = $.Deferred();

        $.when( matchmakersFetch, userFetch, rescheduleFetch ).then(function() {
            if ( connection_error_shown || view_rendered ) {
                return;
            }
            view_rendered = true;
            app.views.current.render();
        } );

        $.each( [ 1, 1000, 5000, 10000, 15000 ], function( index, delay ){
            setTimeout( function() {
                var timeout = 1000 * Math.pow( 2, index );
                if ( ! connection_error_shown && ! view_rendered ) {
                    if ( matchmakersFetch.state() != 'resolved' ) {
                        app.collections.matchmakers.fetch({
                            timeout : timeout,
                            update : true,
                            remove : false,
                            data : { user_fragment : user_meetme_fragment, matchmaker_fragment : matchmaker_fragment },
                            success: function() {
                                if ( matchmakersFetch.state() != 'resolved' ) {
                                    matchmakersFetch.resolve();
                                }
                            }
                        } );
                    }
                    if ( userFetch.state() != 'resolved' ) {
                        app.models.meetme_user.fetch({
                            timeout : timeout,
                            data : { user_fragment : user_meetme_fragment, image_size : 140 },
                            success: function() {
                                if ( userFetch.state() != 'resolved' ) {
                                    userFetch.resolve();
                                }
                            }
                        } );
                    }
                    if ( rescheduleFetch.state() != 'resolved' ) {
                        if ( mode !== 'reschedule' ) {
                            rescheduleFetch.resolve();
                        }
                        else {
                            app.models.rescheduled_meeting.fetch({
                                timeout : timeout,
                                success: function() {
                                    if ( rescheduleFetch.state() != 'resolved' ) {
                                        rescheduleFetch.resolve();
                                    }
                                }
                            } );
                        }
                    }
                }
            }, delay );
        });
    },

    initConfigFromEvent: function(event_id) {

        // Setup deferreds
        var matchmakersFetch = $.Deferred();
        var eventFetch = $.Deferred();

        // Event info
        var mm_event;

        // Hide header right side
        $('#header-right').hide();

        // wait for ajax requests to succeed, defer show content until that
        $.when(matchmakersFetch, eventFetch).then(function() {

            var event_matchmakers = _.filter( app.collections.matchmakers.models, function( candidate ) {
                return candidate.get('matchmaking_event_id') == mm_event.id;
            } );

            var mm = event_matchmakers.shift();

            if ( ! mm ) {
                mm = new app.matchmakerModel({
                    name : mm_event.name,
                    matchmaking_event_id : mm_event.id,
                    event_data : mm_event,

                    vanity_url_path : mm_event.force_vanity_url_path || mm_event.default_vanity_url_path || '',

                    description : mm_event.force_description || mm_event.default_description || '',

                    timezone : mm_event.force_time_zone || mm_event.default_time_zone || 'UTC',
                    time_zone : mm_event.force_time_zone || mm_event.default_time_zone || 'UTC',

                    location : mm_event.force_location || mm_event.default_location || '',
                    location_string : mm_event.location_string,

                    duration : mm_event.force_duration || mm_event.default_duration || 30,

                    buffer : mm_event.force_buffer || mm_event.default_buffer || 30,
                    planning_buffer : mm_event.force_planning_buffer || mm_event.default_planning_buffer || 0,

                    available_timespans : mm_event.force_available_timespans || mm_event.default_available_timespans || [],
                    available_timespans_string : mm_event.available_timespans_string,

                    background_image_url : mm_event.force_background_image_url || mm_event.default_background_image_url || '',
                    background_theme : ( mm_event.force_background_image_url || mm_event.default_background_image_url ) ? 'u' : '0'
                });

                app.collections.matchmakers.add( [mm] );

                // Client id will be used as a substitute for ID in templates
                mm.set('cid', mm.cid );
            }

            app.router.navigate('meetings/meetme_config/' + mm.get('vanity_url_path') + '/for_event/' + mm_event.id + window.location.search, { trigger : true } );
        });

        // Get user matchmakers
        if( ! app.collections.matchmakers ) app.collections.matchmakers = new app.matchmakerCollection();
        app.collections.matchmakers.url = app.defaults.api_host + '/v1/users/' + app.auth.user + '/matchmakers';
        app.collections.matchmakers.fetch({ success : function(){ matchmakersFetch.resolve(); }});

        // Get event info
        $.ajax( app.defaults.api_host + '/v1/matchmaking_events/' + event_id , { success : function(event) {
            mm_event = event;
            eventFetch.resolve();
        }});
    },

    config : function(vanity_url_path, eid) {
        this.prepare();
        if ( ! dicole.get_global_variable("meetings_time_zone_data") ) {
          window.location.reload();
        }

        if( window.location.href.indexOf('new_user') !== -1 || ( Modernizr.localstorage && localStorage.getItem('new_user_flow') === 1 ) ) {
            if(Modernizr.localstorage) localStorage.removeItem('new_user_flow');
            app.models.user.set('new_user_flow', 1);
        }

        vanity_url_path = vanity_url_path || false;
        var event_id = eid || false;

        if ( ! event_id ) {
            if( dicole.get_global_variable('meetings_init_from_localstorage') && Modernizr.localstorage ) {
                var active_path = localStorage.getItem('activeMatchmakerPath') || 'default';
                if ( active_path != vanity_url_path ) {
                    return app.router.navigate('meetings/meetme_config/' + active_path + window.location.search, { trigger : true } );
                }
            }
        }

        // Check and create models & cols where needed
        if( ! app.collections.matchmakers ) app.collections.matchmakers = new app.matchmakerCollection();
        if( ! app.models.matchmaker || vanity_url_path === 'new' ) app.models.matchmaker = new app.matchmakerModel();

        // Set urls
        app.collections.matchmakers.url = app.defaults.api_host + '/v1/users/' + app.auth.user + '/matchmakers';
        var suggestion_sources_url = app.defaults.api_host + '/v1/users/' + app.auth.user + '/suggestion_sources';

        // Create view
        app.views.current = new app.meetmeConfigView({
            el : '#bb-content',
            event_id : event_id,
            matchmaker_model : app.models.matchmaker,
            matchmaker_collection : app.collections.matchmakers,
            user_model : app.models.user
        });

        // Start fetching
        var userFetch = app.models.user.fetch({ data : { image_size : 140 }});
        var suggestionSourcesFetch = $.get(suggestion_sources_url, { dic : app.auth.token, user_id : app.auth.user });
        var matchmakersFetch = app.collections.matchmakers.fetch({ update : true, remove : false });

        // wait for ajax requests to succeed, defer show content until that
        $.when(userFetch,  suggestionSourcesFetch, matchmakersFetch).then(function( user, suggestion_sources, matchmakers ) {

            app.models.user.set('suggestion_sources', suggestion_sources[0]);

            // Override from local storage if wanted
            if( dicole.get_global_variable('meetings_init_from_localstorage') && Modernizr.localstorage && localStorage.getItem('previewMatchmakers') && localStorage.getItem('previewUser') ) {
                app.collections.matchmakers.set( JSON.parse( localStorage.getItem('previewMatchmakers') ));
                app.models.user.set( JSON.parse( localStorage.getItem('previewUser') ) );
                delete app.models.user.attributes.google_connected;  // Clear stuff, we don't want override from ls
            }

            // Go to claim, if no meetme_fragment set on user
            if( ! app.models.user.get('meetme_fragment') ) {
                if( eid ) app.router.navigate('/meetings/meetme_claim/for_event/'+eid, { trigger : true });
                else app.router.navigate('/meetings/meetme_claim', { trigger : true });
                return;
            }

            if( vanity_url_path !== 'new' ) {

                var temp_model  = app.collections.matchmakers.findWhere({ 'vanity_url_path' : vanity_url_path });

                // Handle case we the matchmaker was not found
                if( ! temp_model ) {
                    app.router.navigate('meetings/meetme_config', {'trigger' : true});
                    return;
                }

                // Handle case where matchmaker is old default with empty vanity_url_path
                if( ! temp_model && vanity_url_path === 'default') {
                    app.models.matchmaker = app.views.current.matchmaker_collection.findWhere({'vanity_url_path' : ''});
                    return;
                }

                // Handle case when there was no matchmaker with id and we have enventid
                if( ! temp_model && eid ) {
                    app.router.navigate('meetings/meetme_config/init/' + eid, {'trigger' : true});
                    return;
                }

                app.models.matchmaker.set( temp_model.toJSON() );
            }

            app.views.current.render();

            // We want to init from local storage only once
            dicole.set_global_variable('meetings_init_from_localstorage', 0 );
        });

    },

    share : function(mm) {
        this.prepare();

        app.collections.matchmakers =  app.collections.matchmakers || new app.matchmakerCollection();
        app.collections.matchmakers.url = app.defaults.api_host + '/v1/users/' + app.auth.user + '/matchmakers';

        app.views.current = new app.meetmeShareView({
            el : '#bb-content',
            matchmakers_collection : app.collections.matchmakers,
            user_model : app.models.user,
            selected_matchmaker_path : mm || ''
        });

        if( app.collections.matchmakers.length === 0 || app.models.user.isNew() ) {
            var userFetch = app.models.user.fetch();
            var matchmakersFetch = app.collections.matchmakers.fetch({update : true, remove : false });
            $.when( userFetch, matchmakersFetch ).then(function() {
                app.views.current.render();
            });
        } else {
            app.views.current.render();
        }
    },

    userSettings : function(setting) {
        this.prepare();
        if ( ! dicole.get_global_variable("meetings_time_zone_data") ) {
           window.location.reload();
        }
        else {
            app.views.current = new app.userSettingsView({ el : '#bb-content', model : app.models.user,   mode : setting || '' });
            app.models.user.fetch({success : function() {
                app.views.current.render();
            }});
        }
    },

    userProfile : function(setting) {
        this.prepare();
        app.views.current = new app.userProfileView({ el : '#bb-content', model : app.models.user });
        app.models.user.fetch({success : function() {
            app.views.current.render();
        }});
    },

    upgradeSuccess : function(type) {
        type = type || 'monthly';
        this.prepare('clean');
        app.views.current = new app.upgradeSuccessView({ el : '#bb-content', model : app.models.user, type : type });
        if( app.auth.user ) {
            app.models.user.fetch();
        } else {
            app.views.current.render();
        }
    },

    upgradePay : function(type) {
        type = type || 'monthly';

        var coupon = app.helpers.getQueryParamByName('coupon');

        this.prepare('clean');
        app.views.current = new app.upgradePayView({ el : '#bb-content', model : app.models.user, type : type, preset_coupon : coupon });
        if( app.auth.user ) {
            app.models.user.fetch();
        } else {
            app.views.current.render();
        }
    },

    upgrade : function(vendor) {
        vendor = vendor || false;
        this.prepare('clean');
        app.views.current = new app.upgradeCoverView({ el : '#bb-content', model : app.models.user, prefered_vendor : vendor });
        if( app.auth.user ) {
            app.models.user.fetch({success : function(user) {
                if( ! vendor ) {
                    // Redirect to vendor store for known vendors
                    var redirect = false;
                    _.each( app.vendors, function(vendor,key) {
                        if( vendor.country_code === user.get('presumed_country_code') ) {
                            redirect = key;
                        }
                    });

                    if( redirect ) {
                        app.router.navigate('/meetings/upgrade/' + redirect,{ trigger : true });
                        return;
                    }
                }
                app.views.current.render();
            }});
        } else {
            app.views.current.render();
        }
    },

    agentBooking : function( area ) {
        this.prepare();

        var userFetch = app.models.user.fetch();

        // wait for ajax requests to succeed, defer show content until that
        $.when(userFetch).then(function( user ) {
            app.views.current = new app.agentBookingView({ el : '#bb-content', model : app.models.user });
            app.views.current.fetch_and_render( area );
        });
    },

    agentBookingConfirm : function(lock_id) {
        this.prepare();

        // IF no data found, return
        if( ! app.booking_data ) {
            app.router.navigate('/meetings/agent_booking', { trigger : true });
            return;
        }

        app.models.lock = app.models.lock || new app.matchmakerLockModel({ id : lock_id });
        //app.models.host_user = new app.userModel();
        app.views.current = new app.agentBookingConfirmView({ el : '#bb-content', model : app.models.user, lock : app.models.lock, booking_data : app.booking_data });

        var userFetch = app.models.user.fetch();
        var lockFetch = app.models.lock.fetch();

        $.when(userFetch,  lockFetch).then(function() {
            app.views.current.render();
        });
    },
    agentAbsences : function() {
        this.prepare();
        var userFetch = app.models.user.fetch();

        $.when(userFetch).then(function() {
            app.views.current = new app.agentAbsencesView({ el : '#bb-content', model : app.models.user });
            app.views.current.refresh_and_render();
        } );
    },
    agentManage : function(area, section) {
        this.prepare();
        var userFetch = app.models.user.fetch();
        $.when(userFetch).then(function() {
            app.views.current = new app.agentManageView({ el : '#bb-content', model : app.models.user, section : section, area : area });
            app.views.current.bound_refresh_and_render();
        } );
    },
    agentAdmin : function(area, section) {
        this.prepare();
        var userFetch = app.models.user.fetch();
        $.when(userFetch).then(function() {
            app.views.current = new app.agentAdminView({ el : '#bb-content', model : app.models.user, section : section, area : area });
            app.views.current.bound_refresh_and_render();
        } );
    }
});

app.router = {
    prepare : function( require_login, hide_loader ) {

        // Clear current view if available
        if( app.views.current ) app.views.current.close();

        // Show nav
        $('#summary-nav').show();

        $('#summary').append('<div id="summary-content"></div>');

        if( ! app.views.summary_nav ) app.views.summary_nav = new app.summaryNavView({ el : '#summary' });

        return true;
    },

    upcoming : function() {
        this.prepare();

        // Setup current view
        app.views.current = new app.summaryUpcomingView({ el : '#summary-content', collection : app.collections.upcoming});
        app.views.current.render();

        // Set navigation
        $('a.past', this.el ).addClass('disabled');
        $('a.upcoming', this.el ).removeClass('disabled');

        var today = Math.floor( moment().utc().startOf('day') / 1000 ) - 24 * 60 * 60;

        // Fetch upcoming & suggestions
        app.collections.upcoming.fetch({ reset : true, data : { start_min : today, limit : 50, sort : "asc", image_size : 50, include_draft : 1 }, success : function(col){ col.reset_sub(); app.views.current.try_to_hide_loader(); } });
        app.collections.highlights.fetch({ reset : true, success : function(col){ app.views.current.try_to_hide_loader(); }});
        app.collections.unscheduled.fetch({ reset : true, data : {  image_size : 50, include_draft : 1 }, success : function(col){ app.views.current.try_to_hide_loader(); } });
    },

    past : function() {
        this.prepare();

        app.views.current = new app.summaryPastView({ el : '#summary-content' });
        app.views.current.render();

        var tz_offset = app.models.user.get('time_zone_offset') || 0;
        var today = Math.floor( moment().utc().add(tz_offset, 'seconds').startOf('day') / 1000 ) - tz_offset;
        app.collections.past.fetch({ reset : true, data : { start_max : today, limit : 20, sort : "desc", include_draft : 1, image_size : 50 }, success : function(col){ col.reset_sub_past(); app.views.current.hide_loader(); } } );

        $('a.past', this.el ).removeClass('disabled');
        $('a.upcoming', this.el ).addClass('disabled');
    },

    googleConnecting : function() {
        this.prepare();
        $('#summary-nav').hide();
        app.views.current = new app.summaryLoadingContactsView({ el : '#summary-content' });
        app.views.current.render();
        var today = Math.floor( moment().startOf('day') / 1000 );
        app.collections.upcoming.fetch({ silent : true, success : function(){
            app.views.current.connected();
        }, data : { force_reload : 1, start_min : today, limit : 50, sort : "asc", image_size : 50, include_draft : 1 } });
    }
};
