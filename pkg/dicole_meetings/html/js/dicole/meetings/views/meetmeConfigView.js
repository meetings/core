dojo.provide("dicole.meetings.views.meetmeConfigView");

app.meetmeConfigView = Backbone.View.extend({

    initialize : function(options) {
        _(this).bindAll('render','generateShareUrl','readCommunicationsSettings','changeCommunicationTool','nameChanged','saveConfig','openBgSelector','previewCover','previewCalendar','handleFocus','connectGoogle','openTypeChanger','toggleDirectUrl','changeAvailabilityMode','_setupTimeSettings','planaheadStepToString', 'hasUnsavedChanges', 'showPresetFeatures');

        // Setup models
        this.user_model = options.user_model;
        this.matchmaker_model = options.matchmaker_model;
        this.matchmaker_collection = options.matchmaker_collection;

        // Setup state
        this.fragment_extra = 0;
        this.check_in_progress = false;
        this.fragment_edit_open = false;
        this.event_id = options.event_id || false;
        this.has_valid_name = false;
        this.zcopy_init_done = false;

        // Setup subviews
        this.subviews = {};

        if( ! this.user_model.attributes.meetme_background_theme ) this.user_model.attributes.meetme_background_theme = 0;
    },

    events : {
        'click .preview-calendar' : 'previewCalendar',
        'click .preview-cover' : 'previewCover',
        'click .preview' : 'previewCover',
        'click .bg-change' : 'openBgSelector',
        'click .connect-google' : 'connectGoogle',
        'click .save' : 'saveConfig',
        'click .cancel' : 'backToCover',
        'click .menu-item' : 'openSettingsPage',
        'click .toggle-direct-url' : 'toggleDirectUrl',
        'click .type-change' : 'openTypeChanger',
        'click .show-preset-features': 'showPresetFeatures',
        'focus #matchmaker-description' : 'handleFocus',
        'keyup .matchmaker-name' : 'nameChanged',
        'click .tool' : 'changeCommunicationTool',
        'change input[name="availability_mode"]' : 'changeAvailabilityMode'
    },

    render : function() {

        var _this = this;

        if( this.matchmaker_model.isNew() && this.event_id ) {
            this.matchmaker_model.set({ 'meetme_hidden' : '1', 'direct_link_enabled' : '1' });
        }

        // Render main template
        this.$el.html( templatizer.meetmeConfig( { user : this.user_model.toJSON(), matchmaker : this.matchmaker_model.toJSON() , in_event_flow : this.event_id }) );

        // Setup plugins & config elements
        this.setupConfig();

        this.showBackground();

        // Focus name field, if new meetme type
        if( this.matchmaker_model.isNew() && ! this.event_id ) setTimeout( function() { $('.matchmaker-name').focus(); }, 1000 );

        app.helpers.keepBackgroundCover();

        // Open calendar tab, if we're coming from google connect or date picker if in eventflow
        if( Modernizr.localstorage && localStorage.getItem('googleConnectReturn') ) {
            localStorage.removeItem('googleConnectReturn', '');
            setTimeout(function() { $('.menu-item.calendars').click(); }, 200);
        } else if( this.event_id || this.matchmaker_model.get('disable_location_edit') ) {
            setTimeout(function() { $('.menu-item.date').click(); }, 200);
        }

        this.nameChanged();
        window.scrollTo(0,0);

        // Setup copying to clipboard already if in event mode
        if( this.event_id || this.matchmaker_model.get('direct_link_enabled')  ) {
            this.zcopy_init_done = true;
            $('a#copy-url').zclip({
                path:'/js/dicole/meetings/vendor/zclip/zclip.swf',
                copy: _this.generateShareUrl
            });
        }

        // Show telco if we have data
        var conf = this.matchmaker_model.get('online_conferencing_option') || false;
        var event_data = this.matchmaker_model.get('event_data') || false;
        if( event_data && event_data.force_online_conferencing_option &&  event_data.force_online_conferencing_option !== 'disabled') {
            //$('.tool').not('.' + event_data.force_tool).hide();
            $('.tool').hide();
            $('.com-texts').hide();
            $('.'+event_data.force_online_conferencing_option+'.m-form').show();
        } else if( event_data && event_data.force_online_conferencing_option === 'disabled' ) {
            $('.page.communication').html('<p class="note"><i class="ico-lock"></i>'+ MTN.t('Live communication tools disabled for this event.')+'</p>');
        } else if( conf ) {
            $('.configs>.' + conf).show();
            $('.lctools>.' + conf).addClass('selected');
            $('.tool.disable').css('display','inline-block');
        }

        // Setup datepickers
        datePickerController.createDatePicker( {
            positioned : '#av_date_start',
            formElements: { av_date_start : "%Y-%m-%d"}
        });

        datePickerController.createDatePicker( {
            positioned : '#av_date_end',
            formElements: { av_date_end : "%Y-%m-%d"}
        });

        $('#av_date_start').on('focus', function() { datePickerController.show('av_date_start'); });
        $('#av_date_end').on('focus', function() { datePickerController.show('av_date_end'); });

        // Setup tinymce for agenda after removing the old instance
        // that might have been left lingering from the last view of this page
        tinyMCE.EditorManager.execCommand('mceRemoveEditor',true, 'meetme-agenda');
        tinyMCE.init( {
            menubar: false,
            statusbar: false,
            selector: ".meetme-agenda",
            language : dicole.get_global_variable('meetings_lang'),
            width: 600,
            height: 210,
            plugins: "autolink,paste",

            toolbar1 : 'bold italic underline strikethrough | forecolor backcolor | formatselect | bullist numlist | removeformat',

            content_css : "/css/tinymce.css",

            paste_create_paragraphs : true,
            paste_create_linebreaks : false,
            paste_strip_class_attributes: 'all',
            paste_auto_cleanup_on_paste: true
        } );

        // Setup file section
        if ( $('#preset-materials').length === 0 ) {
            return;
        }
        this.subviews.meetmePresetFilesView = new app.meetmePresetFilesView({
            el : '#preset-materials',
            model : this.matchmaker_model
        });
    },

    showPresetFeatures : function(e) {
        e.preventDefault();
        var _this = this;
        $(e.currentTarget).text( MTN.t('Working...') );
        this.user_model.startTrial(function() {
            $('#preset-features-pitch').hide();
            $('#preset-features-wrap').show();
        });
    },

    changeCommunicationTool : function(e, t) {
        e.preventDefault();
        var $button = $(e.currentTarget);
        var tool = $button.attr('data-tool-name');

        var _this = this;

        if( ! this.user_model.get('is_pro') && ( tool === 'custom' || tool === 'hangout' || tool === 'lync')) {
            new app.sellProView({ mode : 'lct', model : app.models.user, callback : function(){ _this.changeCommunicationTool(e, tool); } });
            return;
        }

        $('.tool').removeClass('selected');
        $('.tool.disable').css('display','inline-block');

        // Disable if no tool aka. clicked disable
        if( ! tool ) {
            $('.configs>div.m-form').hide();
            this.matchmaker_model.set('online_conferencing_option', '');
            $(e.currentTarget).hide();
            $button.hide();
        }
        else {
            $button.addClass('selected');
            this.matchmaker_model.set('online_conferencing_option', tool);
            $('.configs>div').hide();
            $('.configs>div.' + tool).show();
        }
    },

    hasUnsavedChanges : function() {

        if( this.matchmaker_model.hasChanged() ) return true;

        var currentData = this.getConfig();
        var modelData = this.matchmaker_model.toJSON();

        return false;
    },

    nameChanged : function() {
        // TODO: Don't allow duplicate named schedulers
        var $el = $('.matchmaker-name', this.el);
        if( $el.val() ) {
            this.enableButtons();
        }
        else {
            this.disableButtons();
        }
        if( this.matchmaker_model.get('event_data').force_vanity_url_path ) return;
        if( this.matchmaker_model.isNew() ) $('.vanity-url').text( this.fixMeetingTypeName( $el.val() ));
    },

    disableButtons : function() {
        this.has_valid_name = false;
        $('.button.save').removeClass('pink').addClass('gray-inactive');
        $('.button.preview').removeClass('blue').addClass('gray-inactive');
    },
    enableButtons : function() {
        this.has_valid_name = true;
        $('.button.save').removeClass('gray-inactive').addClass('pink');
        $('.button.preview').removeClass('gray-inactive').addClass('blue');
    },

    openBgSelector : function(e) {
        e.preventDefault();
        new app.meetmeBgSelectorView({
            model : this.matchmaker_model,
            uploadSaveCb : function( view, data ) {
                view.model.set({
                    background_upload_id : data.result.result.upload_id,
                    background_theme : 'c',
                    background_image_url : data.result.result.upload_preview_url
                });
                app.views.current.switchBackground(data.result.result.upload_preview_url);
                view.closeModal();
            },
            themeSaveCb : function( view, id ) {
                // TODO: Check the get config function
                app.views.current.switchBackground(app.meetme_themes[id].image);
                view.model.set({background_theme : id});
                view.closeModal();
            }
        });
    },

    openTypeChanger : function(e) {
        e.preventDefault();
        var _this = this;
        dicole.create_showcase({
            disable_close : true,
            "content" : templatizer.meetmeTypeSelector({ matchmaker : this.matchmaker_model.toJSON() })
        });

        $('.type-icon').on('click', function(e) {
            var id = $(e.currentTarget).attr('data-type-id');
            $('.meeting-type').val(id);
            $('.type-change i').attr('class', app.meetme_types[id].icon_class );
            _this.matchmaker_model.set('meeting_type',id);
            dojo.publish('showcase.close');
        });
    },

    backToCover : function(e) {
        e.preventDefault();
        app.router.navigate('meetings/meetme_config', { trigger : true });
    },

    toggleDirectUrl : function(e) {
        var _this = this;
        var $el = $(e.currentTarget);
        var class_name = ( this.matchmaker_model.get('event_data') && this.matchmaker_model.get('event_data').show_youtube_url ) ? 'open2' : 'open';
        this.matchmaker_model.set('direct_link_enabled', ($('.toggle-direct-url').is(':checked') ? '1' : '0' ) );
        this.showBackground();
        $('.direct-link-container', this.el).toggleClass(class_name);

        if( ! this.zcopy_init_done ) {
            this.zcopy_init_done = true;
            $('a#copy-url').zclip({
                path:'/js/dicole/meetings/vendor/zclip/zclip.swf',
                copy: _this.generateShareUrl
            });
        }
    },

    generateShareUrl : function() {
        return 'https://' + window.location.hostname + '/meet/' +
            this.user_model.get('meetme_fragment') + '/' + (
            this.matchmaker_model.get('vanity_url_path') || this.fixMeetingTypeName($('.matchmaker-name').val()) );
    },

    switchBackground : function(url) {
        $('#bb-background .bg:last-child').css({'background-image' : 'url('+url+')'});
        $('.mm-bg-img').attr('src', url);
        $('#content-wrapper').removeAttr("style");
    },

    openSettingsPage : function(e) {
        e.preventDefault();
        var $el = $(e.currentTarget);
        $('.menu-item').removeClass('selected');
        $('.settings-pages .page').hide();
        $el.addClass('selected');
        $('.settings-pages .' + $el.attr('data-target') ).show();
    },

    setupConfig : function() {
        var _this = this;

        // Quickfix: add users timezone to matchmaker if no timezone
        if( ! this.matchmaker_model.get('time_zone') ) {
            this.matchmaker_model.set('time_zone', this.user_model.get('time_zone'));
        }

        // Render timespan settings
        $('.time-spans', this.el).html( templatizer.meetmeMatchmakerTimespan( this.matchmaker_model.toJSON() ));

        // Render calendar options
        this.subviews.calendar_options = new app.meetmeCalendarOptionsView({
            el : '.calendar-options',
            user_model : this.user_model,
            matchmaker_model : this.matchmaker_model,
            mode : dicole.get_global_variable('meetings_select_new_calendars') ? 'open' : 'closed'
        });
        this.subviews.calendar_options.render();

        // Setup timezone && setup event handling
        var $select = $('#timezone-select');
        $select.chosen().change(function() {
            _this.matchmaker_model.set('time_zone', $select.val() );
        });

        // Setup sliders and visualization
        this._setupTimeSettings();

        // If there are set timespans, we find days covered there and
        // show slots only for those days and only within the timespans
        // if model has not been saved, we can just use the given timespans
        // converted to slots
        // NOTE ( this is a bunch of shit code, there should be a better way to do this )
        var available_timespans = this.matchmaker_model.get('available_timespans');
        if( available_timespans && available_timespans.length ) {

            var pos, len = available_timespans.length;
            var first_slot = Infinity;
            var last_slot = 0;
            var timespans = {};
            var timespans_arr = [];
            var filtered_slots = [];
            var timespan, slot_s, slot_e;
            var skip_slot_manipulation = false;

            for( pos = 0; pos < len; pos++ ) {
                timespan = available_timespans[pos];

                // If any timespan longer than 24 hours, don't limit slots
                if( timespan.end - timespan.start >= 60 * 60 * 24 ) {
                    skip_slot_manipulation = true;
                }

                // Find first and last slots
                if( first_slot < timespan.start ) first_slot = timespan.start;
                if( last_slot > timespan.end ) last_slot = timespan.end;

                // Check if we need to adjust to dst
                var timezone = dicole.get_global_variable('meetings_time_zone_data').data[this.matchmaker_model.get('time_zone')];
                var offset = timezone.offset_value;
                if( timezone.dst_change_epoch &&  timespan.start >= timezone.dst_change_epoch ) {
                    offset = timezone.changed_offset_value;
                }

                slot_s = moment.utc( ( timespan.start + offset ) * 1000 );
                slot_e = moment.utc( ( timespan.end + offset ) * 1000 );
                slot_day_begin = moment.utc( ( timespan.end + offset ) * 1000 ).startOf('day').valueOf();
                // TODO: If slot end & begin for day exist, extend them instead of overwrite

                if ( ! timespans[slot_s.day() - 1] ) {
                    timespans[slot_s.day() - 1] = [];
                }
                timespans[slot_s.day() - 1].push( {
                    weekday : slot_s.day() - 1, // -1 as we want days from 0 - 6
                    begin_second : Math.floor( ( slot_s.valueOf() - slot_day_begin ) / 1000 ),
                    end_second : Math.floor( ( slot_e.valueOf() - slot_day_begin ) / 1000 )
                } );
                timespans_arr.push({
                    weekday : slot_s.day() - 1, // -1 as we want days from 0 - 6
                    begin_second : Math.floor( ( slot_s.valueOf() - slot_day_begin ) / 1000 ),
                    end_second : Math.floor( ( slot_e.valueOf() - slot_day_begin ) / 1000 )
                });

            }

            // Check if first and last slots are more than week apart
            if( last_slot - first_slot > 60 * 60 * 24 * 7 ) {
                skip_slot_manipulation = true;
            }

            // If model is new, we just can show the timespans
            if( ! skip_slot_manipulation && this.matchmaker_model.isNew() ) {
                this.matchmaker_model.set('slots', timespans_arr);
            } else if( ! skip_slot_manipulation ) {

                // Filter slots to show stuff only inside the available slots
                $.each( this.matchmaker_model.get('slots'), function( i, slot ) {
                    if( timespans[slot.weekday] ) {
                        $.each( timespans[slot.weekday], function( j, valid_time ) {
                            var matching_part_of_slot = {
                                weekday : slot.weekday,
                                begin_second : Math.max( slot.begin_second, valid_time.begin_second ),
                                end_second : Math.min( slot.end_second, valid_time.end_second )
                            };
                            if ( matching_part_of_slot.begin_second < matching_part_of_slot.end_second ) {
                                filtered_slots.push(matching_part_of_slot);
                            }
                        } );
                    }
                } );

                this.matchmaker_model.set('slots', filtered_slots);
            }
        }

        // Setup calendar
        $('#btd-cal').btdCal({
            mode : 'multiselect',
            disableSlotTimeShowing : true,
            timeZoneOffset : 0,
            highlightToday : false,
            disableDateShow : true,
            showNav : false,
            businessHours : {
                limitDispay : false,
                start : 8,
                end : 18
            },
            displayWeek : {
                m : 3,
                d : 15,
                y : 2013
            },
            timeslotHeight : 15,
            selectDuration : 30,
            timeslotsPerHour : 2,
            createEvents : true,
            limitTimespans : $.extend(true, {}, this.matchmaker_model.get('available_timespans')),// pass clone instead of reference
            limitTimespansTz : dicole.get_global_variable('meetings_time_zone_data').data[this.matchmaker_model.get('time_zone')],
            slots : this.matchmaker_model.get('slots')
        });


    },

    _setupTimeSettings : function() {

        var _this = this;

        var $meeting_len = $('.meeting-len');
        var $pause_height = $('.reserve-pattern');
        var $pause_len = $('.pause-len');
        var $planahead_len = $('.planahead-len');
        var $demo_meeting = $('#demonstrator_m1');
        var $demo_buffer = $('#demonstrator_buf');
        var $demo_planahead_tip = $('#planahead_tip');
        var $time_slider = $('#timeslider');
        var $pause_slider = $('#pauseslider');
        var $planahead_slider = $('#planaheadslider');

        if( $time_slider.length ) {
            $time_slider.noUiSlider({
                range: {
                    'min': 15,
                    'max': 240
                },
                start: [this.matchmaker_model.get('duration')],
                step: 15,
                connect: "lower",
                serialization: {
                    format: {
                        mark: ',',
                        decimals: 0
                    }
                }
            });
            $time_slider.on('slide', function() {
                var val = $(this).val();
                $meeting_len.text(_this.humanizedTimeFromMinutes(val));
                _this.reCenterDemonstrator();
                if( val < 25 ) {
                    $demo_meeting.html('').css({ height : val * (10 / 15) });
                } else {
                    $demo_meeting.html( MTN.t('Meeting') + ' - ' + _this.humanizedTimeFromMinutes(val)).css({ height : val * (10 / 15)  });
                }
            });
        }

        if( $pause_slider.length ) {
            $pause_slider.noUiSlider({
                range: {
                    'min': 0,
                    'max': 120
                },
                start: [this.matchmaker_model.get('buffer')],
                step: 15,
                connect: "lower",
                serialization: {
                    format: {
                        mark: ',',
                        decimals: 0
                    }
                }
            });
            $pause_slider.on('slide', function() {
                var val = $(this).val();
                $pause_len.text(_this.humanizedTimeFromMinutes(val));
                _this.reCenterDemonstrator();
                if( val === 0 || val === '0' ) {
                    $pause_height.hide();
                } else {
                    $pause_height.css({ height : val * (10 / 15) }).show();
                }
            });
        }

        if( $planahead_slider.length ) {
            $planahead_slider.noUiSlider({
                range: {
                    'min': 0,
                    'max': 12
                },
                start: [this.matchmaker_model.get('planning_buffer') ? _this.planaheadMapReversed(this.matchmaker_model.get('planning_buffer') / 60 / 60) : _this.planaheadMapReversed(0)],
                step: 1,
                connect: "lower",
                serialization: {
                    format: {
                        mark: ',',
                        decimals: 0
                    }
                }
            });
            $planahead_slider.on('slide', function() {
                var val = $(this).val();
                $planahead_len.text( _this.planaheadStepToString(val) );
                var mins = Math.ceil(  (_this.planaheadMap(val) * 60 + moment().get('minutes') ) / 30) * 30;
                var format_string = moment.lang() === 'en' ? 'dddd D.M h:mm A' : 'dddd D.M HH:mm';
                var msg = MTN.t('E.g. if booked now, the first available meeting slot would be on %1$s.',[moment().set('minutes',0).add('minutes', mins ).format(format_string) ]);
                $demo_planahead_tip.html(msg);
            });
        }

        this.reCenterDemonstrator();
    },

    reCenterDemonstrator : function() {
        var $el = $('.other-meeting.first');
        var margin = 190 - ( 4 / 6 * (Math.round($('#timeslider').val()) + Math.round($('#pauseslider').val()) * 2 ) ) / 2;
        $el.css({'margin-top' : margin });
    },

    showBackground : function() {
        var url = '';
        if(  this.matchmaker_model.get('direct_link_enabled') == '1' ) {
            if( this.matchmaker_model.get('background_theme') == 'c' || this.matchmaker_model.get('background_theme') == 'u') {
                url = this.matchmaker_model.get('background_image_url');
            }
            else{
                url = app.meetme_themes[(this.matchmaker_model.get('background_theme') || 0 )].image;
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
        this.switchBackground(url);
    },


    handleFocus : function(e) {
        var $textarea = $(e.currentTarget);
        if( $textarea.val() === this.matchmaker_model.defaults.description ) {
            $textarea.html('');
        }
    },

    getConfig : function(){

        var event_data = this.matchmaker_model.get('event_data');

        var tz_name = event_data.force_time_zone || $('#timezone-select').val() || this.matchmaker_model.get('time_zone');
        var duration = $('#timeslider').length ? Math.round($('#timeslider').val()) : this.matchmaker_model.get('duration');

        var obj = {
            matchmaker : {
                user_id : this.user_model.id,
                vanity_url_path : this.matchmaker_model.get('vanity_url_path') || this.fixMeetingTypeName( $('.matchmaker-name').val() ),
                matchmaking_event_id : this.matchmaker_model.get('matchmaking_event_id') || 0,
                description : $('#matchmaker-description').val(),
                location : event_data.force_location || $('#matchmaker-location').val(),
                background_theme : event_data.force_background_image_url ? 'u' : this.matchmaker_model.get('background_theme'),
                background_upload_id : event_data.force_background_image_url ? 0 : this.matchmaker_model.get('background_upload_id'),
                background_preview_url : event_data.force_background_image_url || this.matchmaker_model.get('background_preview_url'),
                duration : event_data.force_duration || duration,
                buffer : event_data.force_buffer || Math.round($('#pauseslider').val()),
                planning_buffer : event_data.planning_buffer || this.planaheadMap($('#planaheadslider').val()) * 60 * 60,
                slots : $('#btd-cal').btdCal('getSlots'),
                available_timespans : event_data.force_available_timespans || ( this.matchmaker_model.get('disable_available_timespans_edit') ? this.matchmaker_model.get('available_timespans') : this.readTimeSpans( tz_name ) ),
                time_zone : tz_name,
                youtube_url : $('#video').val(),
                time_zone_offset : dicole.get_global_variable('meetings_time_zone_data').data[tz_name].offset_value,
                time_zone_string : dicole.get_global_variable('meetings_time_zone_data').data[tz_name].readable_name,
                source_settings : this.matchmaker_model.get('source_settings'),
                require_verified_user : $('#require-verified-user').is(':checked') ? 1 : 0,

                meeting_type : $('.meeting-type').val(),
                direct_link_enabled : $('.toggle-direct-url').is(':checked') ? '1' : '0',
                meetme_hidden : $('.meetme-hidden').is(':checked') ? '1' : '0',
                name : $('.matchmaker-name').val(),

                preset_agenda : tinyMCE.activeEditor.getContent(),
                preset_title : $('#preset-title').val(),
                preset_materials : this.matchmaker_model.get('preset_materials') || []
            }
        };

        return obj;
    },

    readTimeSpans : function( tz_name ) {
        var time_spans = [];

        var tz_offset = dicole.get_global_variable('meetings_time_zone_data').data[tz_name].offset_value;

        if( $('input[name="availability_mode"]:checked').val()  === 'set-time' ) {
            time_spans.push({
                start : Math.round( moment.utc( $('#av_date_start').val() ).valueOf() / 1000 ) + tz_offset,
                end : Math.round( moment.utc( $('#av_date_end').val() ).add('day',1).valueOf() / 1000 ) + tz_offset
            });
        }

        return time_spans;
    },

    readCommunicationsSettings : function() {
        var option = this.matchmaker_model.get('online_conferencing_option');
        var conf =  this.matchmaker_model.get('online_conferencing_data') || {};
        switch (option) {
            case 'skype':
                conf.skype_account = $('#com-skype').val();
                this.matchmaker_model.set('skype_account', $('#com-skype').val() );
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
                conf.lync_sip = $('#com-lync').val();
                conf.lync_mode = 'sip';
                break;
            default:
                break;
        }

        this.matchmaker_model.set('online_conferencing_data', conf);
    },

    fixMeetingTypeName : function(name) {
        return (name.replace(/[^A-Z0-9]+/ig, "_")+'').toLowerCase();
    },

    saveConfig : function(e){
        e.preventDefault();

        // Preserve this
        var _this = this;

        // Prevent save while editing
        if( ! this.has_valid_name ) return;

        // Show save text
        new app.helpers.activeButton( e.currentTarget );

        this.readCommunicationsSettings();

        // Get the configuration
        var config = this.getConfig();

        // Remove temp background_url
        this.matchmaker_model.set('background_preview_url','');

        // Setup deferreds for saves
        // Was this an unsaved matchmaker
        var mm_is_new = this.matchmaker_model.isNew();
        //this.matchmaker_collection.add( this.matchmaker_model );

        // Save user & matchmaker
        this.matchmaker_model.save(config.matchmaker, { success : function( res , model ) {
            // Clear preview url
            _this.matchmaker_model.set('background_preview_url','');

            // If we are handling a new event, setup redirects
            if( _this.matchmaker_model.get('matchmaking_event_id') && mm_is_new && _this.matchmaker_model.get('name') ) {

                // Set a redirect url to local storage
                if(Modernizr.localstorage) {
                    localStorage.setItem('event_organizer_return_url', _this.matchmaker_model.get('event_data').organizer_return_url );
                }

                // Show the app loading page
                app.router.navigate('meetings/wizard_apps', {trigger:true});

            }
            // Else go back to cover edit
            else {
                app.router.navigate('meetings/meetme_config' , {trigger:true});
            }

        } });
    },

    saveConfigToLocalStorage : function(){
        if(! Modernizr.localstorage ) return;
        var config = this.getConfig();
        this.readCommunicationsSettings();
        this.matchmaker_model.set( config.matchmaker );
        var tempCol = new app.matchmakerCollection();
        tempCol.set( this.matchmaker_model.toJSON() );
        localStorage.setItem('previewUser',JSON.stringify( this.user_model.toJSON() ) );
        localStorage.setItem('previewMatchmakers',JSON.stringify( tempCol.toJSON() ) );
        localStorage.setItem('activeMatchmakerPath', this.matchmaker_model.get('vanity_url_path') );
    },

    previewCalendar : function(e){
        e.preventDefault();
        if( ! this.has_valid_name ) return;
        this.saveConfigToLocalStorage();
        window.open('/meet/' + this.user_model.get('matchmaker_fragment') + '/' + ( this.matchmaker_model.get('vanity_url_path') || 'default' ) + '/calendar/preview');
    },

    previewCover : function(e){
        e.preventDefault();
        if( ! this.has_valid_name ) return;
        var extra = ( ! this.matchmaker_model.get('direct_link_enabled') ) ? '/calendar' : '';
        this.saveConfigToLocalStorage();
        window.open('/meet/' + this.user_model.get('matchmaker_fragment') + '/' + ( this.matchmaker_model.get('vanity_url_path') || 'default' ) + extra + '/preview');
    },

    connectGoogle : function(e){
        e.preventDefault();
        this.saveConfigToLocalStorage();
        if(Modernizr.localstorage) {
            localStorage.setItem('googleConnectReturn', this.matchmaker_model.get('vanity_url_path') );
        }
        window.location = dicole.get_global_variable('meetings_google_connect_url');
    },

    changeAvailabilityMode : function(e) {
        e.preventDefault();
        var $el = $(e.currentTarget);
        var $controls = $('.availability-controls');
        if( $el.val() === 'set-time' ) {
            $controls.show();
        } else {
            $controls.hide();
            this.matchmaker_model.set('available_timespans', []);
        }
    },

    humanizedTimeFromMinutes : function(val) {
        return humanizeDuration( val * 60 * 1000, dicole.get_global_variable('meetings_lang') );
    },

    planaheadMap : function(val) {
        var map = {
            0 : 0.5,
            1 : 1,
            2 : 2,
            3 : 3,
            4 : 4,
            5 : 8,
            6 : 16,
            7 : 24,
            8 : 36,
            9 : 48,
            10 : 96,
            11 : 168,
            12 : 336
        };
        return map[val];
    },

    planaheadMapReversed : function(val) {
        var map = {
        0.5 : 0,
        1 : 1,
        2 : 2,
        3 : 3,
        4 : 4,
        8 : 5,
        16 : 6,
        24 : 7,
        36 : 8,
        48 : 9,
        96 : 10,
        168 : 11,
        336 : 12
        };
        return  map[val];
    },

    planaheadStepToString : function(val) {
        return humanizeDuration( this.planaheadMap(val) * 60 * 60 * 1000, dicole.get_global_variable('meetings_lang') );
    },

    planaheadStepToSeconds : function(val) {
        return  this.planaheadMap(val) * 60 * 60;
    },

    beforeClose : function(){
        if( this.user_model ) this.user_model.unbind();
        if( this.matchmaker_model ) this.matchmaker_model.unbind();
        if( this.matchmaker_collection ) this.matchmaker_collection.unbind();
    }
});
