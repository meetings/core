dojo.provide("dicole.meetings.views.meetmeCalendarView");

app.meetmeCalendarView = Backbone.View.extend({

    initialize : function(options) {

        // Bind this to methods
        _(this).bindAll('render','renderCalendar','chooseSlot','openCover','openConfig','goToSuccess','saveProfile');

        var _this = this;

        // Setup variables passed from router
        this.user_model = options.user_model;
        this.matchmaker_collection = options.matchmakers_collection;
        this.rescheduled_meeting = options.rescheduled_meeting;
        this.user_fragment = options.user_fragment;
        this.mode = options.mode || 'normal';
        this.modeparam = options.modeparam;
        this.selected_matchmaker_path = options.selected_matchmaker_path || 'default';
        this.now = new Date();
        this.tz_data = dicole.get_global_variable('meetings_time_zone_data');
        this.quickmeet_key = false;

        // Sniff user timezone
        app.options.ua_time_zone = jstz.determine_timezone().name();
        if( ! this.tz_data.data[app.options.ua_time_zone] ) app.options.ua_time_zone = 'UTC';
    },
    events : {
        'click .back-to-config' : 'openConfig',
        'click .js-save-profile' : 'saveProfile',
        'click .login' : 'login',
        'click .back-to-cover' : 'openCover'
    },

    beforeClose : function() {
        this.user_model.unbind();
    },

    render : function() {

        var _this = this;

        // Try to find matchmaker by name
        var i, l = this.matchmaker_collection.length;
        for( i = 0; i < l; i++ ) {
            var n = this.matchmaker_collection.at(i).get('vanity_url_path') || '';
            // TODO: This should select either a matching named matchmaker or in case we are searching for default it should select empty or 'default'
            if( n === this.selected_matchmaker_path || ( this.selected_matchmaker_path === 'default' && ( ! n || n === 'default' ) ) ) {
                this.active_matchmaker = this.matchmaker_collection.at(i);
            }
        }

        // If no active matchmaker found, go to users front page
        if( ! this.active_matchmaker ) {
            app.router.navigate( 'meet/' + this.user_model.get('matchmaker_fragment'), {trigger : true});
            return;
        }

        var rescheduledMeeting = {};
        if ( this.rescheduled_meeting ) {
            rescheduledMeeting = this.rescheduled_meeting.toJSON()
        }

        this.$el.html( templatizer.meetmeCalendar( { user : this.user_model.toJSON(), matchmaker : this.active_matchmaker.toJSON(), rescheduled_meeting : rescheduledMeeting, mode : this.mode }) );

        app.helpers.matchElHeight($('.content',this.el));

        // Set background if not set
        var $content = $('.content');
        if( ! $content.attr('style') ) {
            var bg_image = '';
            if( this.active_matchmaker.get('background_theme') == 'c' || this.active_matchmaker.get('background_theme') == 'u') {
                bg_image = this.active_matchmaker.get('background_preview_url') || this.active_matchmaker.get('background_image_url');
            }
            else{
                bg_image = app.meetme_themes[this.active_matchmaker.get('background_theme')].image;
            }
            $content.css({
                'background-image' : 'url('+bg_image+')',
                'background-size' : 'cover',
                'background-position' : '50% 50%',
                'background-attachment' : 'fixed'
            });
        }
        $('#content-wrapper').css({
            'background-image' : 'none'
        });

        // Non preview mode stuff
        if( this.mode !== 'preview' ){
            $('.top-wrapper').addClass('transition');
        }

        // Preview mode stuff
        else{
            $('#header-wrapper').hide();
            $('.top-wrapper').addClass('no-transition');
        }


        // Save the original timezone
        this.active_matchmaker.set('time_zone_offset_original',this.active_matchmaker.get('time_zone_offset'));
        this.active_matchmaker.set('time_zone_original',this.active_matchmaker.get('time_zone'));

        // Check user timezone
        if( app.options.ua_time_zone !== this.active_matchmaker.get('time_zone') ) {
            var showcase = dicole.create_showcase({
                "width": 590,
                "disable_close": true,
                "disable_background_close": true,
                "content": templatizer.meetmeTimezonePrefs({ matchmaker : this.active_matchmaker.toJSON(), user : this.user_model.toJSON(), ua_tz : app.options.ua_time_zone, d : this.now, tz_data : this.tz_data })
            });

            // Timezone dropdown
            var $select = $('#timezone-select', showcase.nodes.content);
            $select.chosen().change(function(e){
                // Change radio button val
                var tz = $(e.currentTarget).val();
                $('#user-tz', showcase.nodes.content).val( tz );

                // Redraw time
                var d = new Date();
                var new_time_string = moment.utc(d.getTime() + _this.tz_data.data[tz].offset_value * 1000).format('hh:mm A');
                $('#user-time', showcase.nodes.content).html(new_time_string);

            });

            $('.set-time-zone', showcase.nodes.content).on('click', function(e){
                e.preventDefault();
                var val = $('input[name=offset]:checked', showcase.nodes.content).val();
                dojo.publish('showcase.close');

                _this.active_matchmaker.set('time_zone',val);
                var tz = dicole.get_global_variable('meetings_time_zone_data').data[val];
                _this.active_matchmaker.set('time_zone_offset',tz.offset_value);
                _this.active_matchmaker.set('time_zone_string',tz.readable_name);
                _this.renderCalendar();
                $('p.timezone', _this.el).text(tz.readable_name);
            });
        }
        else{
            this.renderCalendar();
        }

        app.helpers.keepBackgroundCover(true);
    },

    renderCalendar : function(weekOffset, initCounter, retryCount) {

        var _this = this;
        var calendarInPast = false;
        var offset = weekOffset || 0;
        var counter = initCounter || 0;
        var retry = retryCount || 0;

        // Set initial offset if the matchmaker is set for a specific time
        // also show message, if that time is in past
        if( this.active_matchmaker.get('event_data') && this.active_matchmaker.get('event_data').id && this.active_matchmaker.get('available_timespans') && this.active_matchmaker.get('available_timespans').length ) {

            // Find first time
            var ft = Infinity, i, len = this.active_matchmaker.get('available_timespans').length;
            for( i = 0; i < len; i++ ) {
                if( this.active_matchmaker.get('available_timespans')[i].start < ft ) ft = this.active_matchmaker.get('available_timespans')[i].start;
            }

           // Calculate week offset from now
           // NOTE: multiply by 1000, as moment works in milliepochs
           var diff = moment(ft * 1000).utc().startOf('isoWeek').valueOf() - moment().utc().startOf('isoWeek').valueOf();

           if( diff < 0 ) {
               calendarInPast = true;
           }

           // Override offset
           offset = Math.round( diff / ( 1000 * 60 * 60 * 24 * 7 ) );
        }

        // Show spinner
        $('#calendar-container').html('<p>'+MTN.t('Loading calendar...')+'</p><div class="loader"></div>');
        var spinner = new Spinner(app.defaults.spinner_opts).spin( $('.loader' , this.el )[0] );

        // Get calendar events (using isoWeek ensures week starts on monday)
        var weekBegin = Math.round(moment().utc().add('weeks', offset).startOf('isoWeek').valueOf() / 1000);
        var weekEnd = Math.round(moment().utc().add('weeks', offset).endOf('isoWeek').valueOf() / 1000);

        // Include 24 hours before the week & after the week so that when changing
        // the timezone we will definitely have all events for display
        var data = { begin_epoch : weekBegin - 25 * 60 * 60, end_epoch : weekEnd + 25 * 60 * 60 };
        var tz = this.active_matchmaker.get('time_zone_offset');
        var duration = this.active_matchmaker.get('duration');

        var url = app.defaults.api_host;
        if( this.mode === 'preview' ) {
            url += '/v1/users/'+app.auth.user+'/preview_matchmaker_options';
            data.slots = this.active_matchmaker.get('slots');
            data.time_zone = this.active_matchmaker.get('time_zone');
            data.buffer = this.active_matchmaker.get('buffer');
            data.available_timespans = this.active_matchmaker.get('available_timespans');
            data.source_settings = this.active_matchmaker.get('source_settings');
            data.buffer = this.active_matchmaker.get('buffer');
            data.planning_buffer = this.active_matchmaker.get('planning_buffer');
            data.matchmaking_event_id = this.active_matchmaker.get('matchmaking_event_id');
            data.user_id = app.auth.user;
            data.dic = app.auth.token;
        }
        else {
            // Set url for slot fetch
            url += '/v1/matchmakers/'+this.active_matchmaker.get('id')+'/options';
        }

        // Calculate possible first and last event times so we can display calendar intelligently
        var earliestEvent = 1000000, latestEvent = 0;
        if(this.active_matchmaker.get('slots').length) {
            for( var i = 0; i < this.active_matchmaker.get('slots').length; i++ ){
                var s = this.active_matchmaker.get('slots')[i];
                if( s.begin_second < earliestEvent ) earliestEvent = s.begin_second;
                if( s.end_second > latestEvent ) latestEvent = s.end_second;
            }
            earliestEvent = earliestEvent / 3600;
            latestEvent = latestEvent / 3600;

            // If we other timezone than the matchmaker original, we need
            // to make space for all options
            var diff = ( parseInt(this.active_matchmaker.get('time_zone_offset'), 10) - parseInt(this.active_matchmaker.get('time_zone_offset_original'), 10) ) / 3600;

            // Adjust both
            earliestEvent = earliestEvent + diff;
            latestEvent = latestEvent + diff;

            // If either wraps around, show whole calendar
            if( earliestEvent < 0 || latestEvent > 24 ){
                latestEvent = 23;
                earliestEvent = 0;
            }
        }
        else {
            earliestEvent = 8;
            latestEvent = 18;
        }

        var httpMethod = _this.mode === 'preview' ? 'POST' : 'GET';

        $.ajax({
            timeout : 3000 + ( 1000 * Math.pow( 2, retry ) ),
            url : url,
            data :data,
            type : httpMethod,
            error : function(res){
                if ( retry > 5 ) {
                    var response_string = JSON && JSON.stringify ? JSON.stringify(res) : 'JSON stringify not supported';
                    if(window.qbaka) qbaka.report('error in meetme calendar data fetch with response: ' + response_string );
                    return alert( MTN.t("please check your network connection and reload the page") );
                }
                return _this.renderCalendar(weekOffset, initCounter, retry + 1 );
            },
            success : function(res){

                var foundValidSlots = false;
                if ( res.length ) {
                    $.each(res, function(i,event){
                        if ( parseInt(event.end_epoch) + tz < weekBegin ) return;
                        if ( parseInt(event.start_epoch) + tz > weekEnd ) return;
                        if ( event.end_epoch - event.start_epoch < duration * 60 ) return;

                        foundValidSlots = true;
                    });
                }

                // If no results on page or slots outside this week
                var extraMsg = false;
                if( ! foundValidSlots ){
                    // If counter is less than 7 , aka searching
                    if( counter < 8 ){
                        extraMsg = MTN.t('Searching for free times...');
                        _this.renderCalendar( offset + 1, counter + 1 );
                    }
                    // If counter at eight, aka last week to search
                    else if( counter == 8 ){
                        extraMsg = MTN.t('Stopped searching after 8 weeks with no free times.');
                        counter++;
                    }
                    // Otherwise no extra message
                    else{
                        extraMsg = false;
                    }
                }
                else{
                    counter = 9;
                }

                // Generate a date for the week being viewed
                var dateInWeek = new Date( weekBegin * 1000 );

                // Check if we reached DST change
                var tzObject = _this.tz_data.data[_this.active_matchmaker.get('time_zone')];
                if( tzObject.dst_change_epoch && dateInWeek.getTime() > tzObject.dst_change_epoch * 1000 ) {

                    // Change timezone string
                    $('p.timezone').html( tzObject.changed_readable_name );

                    // Update offset
                    tz = tzObject.changed_offset_value;
                }
                // If not, revert in case we are going backwards in calendar
                else {

                    // Change timezone string
                    $('p.timezone').html( tzObject.readable_name );

                    // Update offset
                    tz = tzObject.offset_value;
                }

                if( calendarInPast ) {
                    $('#calendar-container').html('').btdCal({
                        date : dateInWeek,
                        mode : 'single_select',
                        disableSlotTimeShowing : true,
                        timeZoneOffset : tz,
                        events: [],
                        extraMessage : MTN.t('Sorry, this Meet Me calendar has expired.'),
                        warnOnEmpty : true,
                        showTimeRanges : false,
                        calendarAddEmptyPadding : true,
                        selectDuration : duration
                    });
                    return;
                }

                $('#calendar-container').html('').btdCal({
                    date : dateInWeek,
                    mode : 'single_select',
                    disableSlotTimeShowing : true,
                    timeZoneOffset : tz,
                    events: foundValidSlots ? res : [],
                    extraMessage : extraMsg,
                    warnOnEmpty : true,
                    businessHours : {
                        limitByEvents : false,
                        limitDisplay : true,
                        start : earliestEvent,
                        end : latestEvent
                    },
                    showTimeRanges : false,
                    calendarAddEmptyPadding : true,
                    selectDuration : duration,
                    slotChoose : function(cal_event, $slot){
                        _this.chooseSlot( cal_event, $slot );
                    },
                    nextDayHandler : function(){
                        _this.renderCalendar( offset + 1, counter);
                    },
                    prevDayHandler : function(){
                        _this.renderCalendar( offset - 1, counter );
                    }
                });

            }
        });

    },

    chooseSlot : function(data, $slot) {
        var _this = this;

        // Change param names api
        data.start_epoch = data.start;
        data.end_epoch = data.end;
        data.matchmaker_id = this.active_matchmaker.get('id');
        if ( this.rescheduled_meeting ) {
            data.location = this.rescheduled_meeting.get('location');
        }

        if( this.mode === 'preview' ) return;

        $slot.html( MTN.t('Reserving...') );

        // Send user timezone as ua if user chose to use the target timezone
        // else use matchmaker timezone
        var show_user_tz_as = '';
        if( this.active_matchmaker.get('time_zone_original') !== this.active_matchmaker.get('time_zone') ){
            data.user_time_zone = this.active_matchmaker.get('time_zone');
            show_user_tz_as = data.user_time_zone;
        } else {
            data.user_time_zone = app.options.ua_time_zone;
            show_user_tz_as = app.options.ua_time_zone;
        }

        // Extra params to the template
        var mm_tz = _this.active_matchmaker.get('time_zone');
        var mm_tz_offset = this.tz_data.data[mm_tz].offset_value;
        if ( this.tz_data.data[mm_tz].dst_change_epoch && data.start > this.tz_data.data[mm_tz].dst_change_epoch ) {
            mm_tz_offset = this.tz_data.data[mm_tz].changed_offset_value;
        }
        var orig_mm_tz = _this.active_matchmaker.get('time_zone_original');
        var orig_mm_tz_offset = this.tz_data.data[orig_mm_tz].offset_value;
        if ( this.tz_data.data[orig_mm_tz].dst_change_epoch && data.start > this.tz_data.data[orig_mm_tz].dst_change_epoch ) {
            orig_mm_tz_offset = this.tz_data.data[orig_mm_tz].changed_offset_value;
        }
        var ua_tz = app.options.ua_time_zone;
        var user_tz_offset = this.tz_data.data[show_user_tz_as].offset_value;
        if ( this.tz_data.data[show_user_tz_as].dst_change_epoch && data.start > this.tz_data.data[show_user_tz_as].dst_change_epoch ) {
            user_tz_offset = this.tz_data.data[show_user_tz_as].changed_offset_value;
        }
        // Use original mm timezone here for matchmaker, so we can show times in mm original timezone also
        var mm_moment_start = moment.utc(data.start * 1000 + orig_mm_tz_offset * 1000);
        var en_mm_moment_start = moment.utc(data.start * 1000 + orig_mm_tz_offset * 1000).lang('en');
        var mm_moment_end = moment.utc(data.end * 1000 + orig_mm_tz_offset * 1000);

        var user_moment_start = moment.utc(data.start * 1000 + user_tz_offset * 1000);
        var en_user_moment_start = moment.utc(data.start * 1000 + user_tz_offset * 1000).lang('en');
        var user_moment_end = moment.utc(data.end * 1000 + user_tz_offset * 1000);

        var moment_start = moment.utc( data.start * 1000 );

        // MTN.t( '%1$s of January');
        // MTN.t( '%1$s of February');
        // MTN.t( '%1$s of March');
        // MTN.t( '%1$s of April');
        // MTN.t( '%1$s of May');
        // MTN.t( '%1$s of June');
        // MTN.t( '%1$s of July');
        // MTN.t( '%1$s of August');
        // MTN.t( '%1$s of September');
        // MTN.t( '%1$s of October');
        // MTN.t( '%1$s of November');
        // MTN.t( '%1$s of December');

        var mm_d_and_m_translateable = '%1$s of ' + en_mm_moment_start.format('MMMM');
        var mm_d_and_m_day = app.language === 'en' ? mm_moment_start.format('Do') : mm_moment_start.format('D');
        var user_d_and_m_translateable = '%1$s of ' + en_user_moment_start.format('MMMM');
        var user_d_and_m_day = app.language === 'en' ? user_moment_start.format('Do') : user_moment_start.format('D');

        var extra_template_params = {
            event_data : _this.active_matchmaker.get('event_data'),
            matchmaker_timezone : mm_tz,
            original_matchmaker_timezone : orig_mm_tz,
            user_agent_timezone : ua_tz,
            default_time_display : app.language === 'en' ? 'am_pm' : '24h',

            time_parts : {
                weekday_readable : mm_moment_start.format('dddd'),
                day_and_month_readable : MTN.t( mm_d_and_m_translateable, [ mm_d_and_m_day ] ),
                start_time_ampm : mm_moment_start.format('h:mm A'),
                end_time_ampm : mm_moment_end.format('h:mm A'),
                start_time_24h : mm_moment_start.format('H:mm'),
                end_time_24h : mm_moment_end.format('H:mm'),
                in_days_readable : moment_start.fromNow(),
                timezone_readable : orig_mm_tz
            },

            user_time_parts : {
                weekday_readable : user_moment_start.format('dddd'),
                day_and_month_readable : MTN.t( user_d_and_m_translateable, [ user_d_and_m_day ] ),
                start_time_ampm : user_moment_start.format('h:mm A'),
                end_time_ampm : user_moment_end.format('h:mm A'),
                start_time_24h : user_moment_start.format('H:mm'),
                end_time_24h : user_moment_end.format('H:mm'),
                in_days_readable : moment_start.fromNow(),
                timezone_readable : show_user_tz_as
            }
        };

        var quickmeet_data = $.parseJSON( app.helpers.getQueryParamByName("quickmeet") );
        if( quickmeet_data && quickmeet_data.key ) {
            extra_template_params.quickmeet = quickmeet_data;
            this.quickmeet_key = quickmeet_data.key;
        }

        // TODO: Refactor to use lock API
        this.lock = new app.matchmakerLockModel();

        this.lock.save( data, { success : function(model, res) {
            $slot.remove();
            $('#calendar-container').btdCal('unlock');
            if(res.error) {
                if( res.error.message ) {
                    alert(res.error.message);
                } else {
                    alert( MTN.t("Oops, something went wrong. Please try again!") );
                }
            } else {
                var showcase = dicole.create_showcase({
                    "width": 590,
                    "disable_close": true,
                    "disable_background_close": true,
                    "content": dicole.process_template('meetings.matchmaking_confirm', $.extend(res, extra_template_params) )
                });

                $(".timezone_change_users").click( function(e) {
                    e.preventDefault();
                    $(".timezone_users").show();
                    $(".timezone_theirs").hide();
                });
                $(".timezone_change_theirs").click( function(e) {
                    e.preventDefault();
                    $(".timezone_theirs").show();
                    $(".timezone_users").hide();
                });
                $(".times_change_ampm").click( function(e) {
                    e.preventDefault();
                    $(".times_ampm").show();
                    $(".times_24h").hide();
                    $(".times_change_24h").show();
                    $(".times_change_ampm").hide();
                });
                $(".times_change_24h").click( function(e) {
                    e.preventDefault();
                    $(".times_24h").show();
                    $(".times_ampm").hide();
                    $(".times_change_ampm").show();
                    $(".times_change_24h").hide();
                });

                $('.matchmaking-submit').click( function(e) {
                    e.preventDefault();
                    $(e.currentTarget).text('Confirming...');

                    if( app.auth.user || _this.quickmeet_key ) {
                        var data = {};

                        if( _this.quickmeet_key ) {
                            data.quickmeet_key = _this.quickmeet_key;
                        } else {
                            data.agenda = $('#meetme-agenda').val();
                        }

                        _this.lock.save(data, { success : function(res) {
                            if( res.error && res.error.message ) return alert(res.error.message);
                            clearTimeout( _this.lock_timeout );

                            if( _this.lock.get('desktop_accepted_meeting_url') ) {
                                window.location = _this.lock.get('desktop_accepted_meeting_url');
                            } else {
                                dojo.publish('showcase.close');
                                _this.goToSuccess();
                            }
                        }});
                    } else {
                        clearTimeout( _this.lock_timeout );
                        _this.lock.save({ agenda : $('#meetme-agenda').val() });
                        _this.new_user = new app.userModel();
                        _this.new_user.url = app.defaults.api_host + '/v1/users';
                        _this.$el.html( templatizer.userProfile({ user : _this.new_user.toJSON(), meetme_explain : true, lock : _this.lock.toJSON() }) );

                        // Setup file upload
                        var params = {
                            paramname : 'file',
                            maxNumberOfFiles : 1,
                            formData : {
                                user_id : app.auth.user,
                                dic : app.auth.token,
                                create_thumbnail : 1,
                                width : 160,
                                height : 160
                            },
                            maxfilesize:5000000 , // in mb
                            url : app.defaults.api_host + '/v1/uploads',
                            acceptFileTypes : /(\.|\/)(gif|jpe?g|png)$/i,

                            done : function(e,data){
                                _this.new_user.set({upload_id : data.response().result.result.upload_id });

                                $('img#profile-image').attr('src', data.response().result.result.upload_thumbnail_url);
                                $('img#profile-image').fadeIn();

                                $('a#upload-button').removeClass('disabled');
                                $('a#upload-button span.text').text(MTN.t('Upload photo'));
                            },

                            start:function(e){
                                $('a#upload-button').addClass('disabled');
                                $('img#profile-image').fadeOut();
                            },
                            progressall: function(e, data) {
                                var progress = parseInt(data.loaded / data.total * 100, 10);
                                $('a#upload-button span.text').text(progress + '%');
                            }
                        };
                        $('#fileupload').fileupload( params );

                        // Chosen for timezones
                        var $select = $('#timezone-select');
                        $select.chosen().change(function(e) {
                            var tz = $select.val();
                            var new_time_string = moment.utc(_this.now.getTime() + _this.tz_data.data[tz].offset_value * 1000).format('hh:mm A');
                            $('#current-time', _this.el).html(new_time_string);
                        });

                        $(window).off('resize');
                        $('#bb-content').css('overflow','hidden');
                        window.scrollTo(0,0);
                        dojo.publish('showcase.close');
                    }
                });

                $('.cancel-lock').click(function(e){
                    e.preventDefault();
                    meetings_tracker.track(e.currentTarget); // Tracking
                    clearTimeout( _this.lock_timeout );
                    _this.lock.destroy({ success : function() {
                        dojo.publish('showcase.close');
                    }});
                });
                // 15 min timeout to close the dialog
                _this.lock_timeout = setTimeout( function(){
                    alert( MTN.t('Sorry, the 15 min reservation on the slot expired and we freed it. Please try again.') );
                    dojo.publish('showcase.close');
                    $('#calendar-container').btdCal('unlock');
                }, 1000 * 60 * 15 /* 15 min */ );

            }
        }});
    },

    goToSuccess : function() {
        app.router.navigate('/meet/' +
                            this.user_model.get('matchmaker_fragment') + '/' +
                            this.active_matchmaker.get('vanity_url_path') + '/success/' +
                            this.lock.get('id') , { trigger : true });
    },

    saveProfile : function(e) {
        e.preventDefault();

        var button = new app.helpers.activeButton(e.currentTarget);

        var _this = this;

        if( ! $('#profile-email').val() ) {
            alert('You need to type in an email!');
            return;
        }

        this.new_user.save({
            matchmaker_lock_id : this.lock.get('id'),
            primary_email : $('#profile-email').val(),
            first_name : $('#profile-first-name').val(),
            last_name : $('#profile-last-name').val(),
            organization : $('#profile-organization').val(),
            organization_title : $('#profile-organization-title').val(),
            phone : $('#profile-phone').val(),
            skype : $('#profile-skype').val(),
            linkedin : $('#profile-linkedin').val(),
            timezone : $('#timezone-select').val(),
            tos_accepted : '1'
        }, {
            success : function() {
                _this.lock.save({ expected_confirmer_id : _this.new_user.id }, { success : function(res) {
                    if( res.error && res.error.message ) return alert(res.error.message);
                    _this.goToSuccess();
                }});
            },
            error: function() {
                alert(MTN.t('Saving profile failed. Please try again!'));
            }
        });
    },

    openConfig : function(e) {
        e.preventDefault();
        var mm_path = 'default';
        if( this.selected_matchmaker_path !== 'default' ) {
            mm_path = this.selected_matchmaker_path + '/for_event/' + this.active_matchmaker.get('matchmaking_event_id');
        }
        app.router.navigate( 'meetings/meetme_config/' + mm_path, {trigger : true});
    },

    openCover : function(e) {
        e.preventDefault();
        app.router.navigate( 'meet/' + this.user_model.get('matchmaker_fragment'), {trigger : true});
    },

    login : function(e) {
        e.preventDefault();
        window.location = '/meetings/login?url_after_login='+window.location.pathname;
    }
});
