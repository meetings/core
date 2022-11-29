dojo.provide("dicole.meetings.views.agentBookingView");

app.agentBookingView = Backbone.View.extend({

    initialize : function(options) {
        _(this).bindAll('fetch_and_render','render','changeArea','setupSelectors','updateSelectors','checkAndStartFetching','renderCalendar','chooseSlot');


        // Extend jQuery a bit
        $.fn.replaceOptions = function(options) {
            var self, $option;

            this.find('option:gt(0)').remove();
            self = this;

            $.each(options, function(index, option) {
                $option = $("<option></option>")
                .attr("value", option.value)
                .text(option.text);
                self.append($option);
            });
        };

        // And a bit more
        if (jQuery.when.all===undefined) {
            jQuery.when.all = function(deferreds) {
                var deferred = new jQuery.Deferred();
                $.when.apply(jQuery, deferreds).then(
                    function() {
                    deferred.resolve(Array.prototype.slice.call(arguments));
                },
                function() {
                    deferred.fail(Array.prototype.slice.call(arguments));
                });

                return deferred;
            };
        }
    },

    events : {
    },
    fetch_and_render : function( area ) {
        var _this = this;

        if ( app.agent_booking_chosen_data && app.agent_booking_chosen_data.areas ) {
            area = app.agent_booking_chosen_data.areas;
        }

        var area_string = area ? '/' + area : '';
        var bookingDataFetch = $.get( app.defaults.direct_api_host + '/v1/agent_booking_data' + area_string, { dic : app.auth.token, user_id : app.auth.user });
        $.when(bookingDataFetch).then(function( data ) {

            _this.selected_area = data.selected_area;
            _this.booking_data = data.users;
            _this.areas_data = data.areas;
            _this.settings_data = data.settings;
            _this.types_data = data.types || [];

            _this.types_data_by_id = {};
            _this.types_data.forEach( function( data ) { _this.types_data_by_id[ data.id ] = data } );

            _this.types = _.uniq( _.map( _this.types_data, function(o) { return { text : o.name, value : o.id }; }) );

            _this.render();
        } );
    },
    render : function() {

        var _this = this;

        var languages = [{ text: 'Suomi', value : 'suomi' }, { text: 'Svenska', value : 'svenska' }, { text : 'English', value : 'english' }];
        var levels = [{ text : 'Etutaso 0-1', value : 'etutaso0-1' }, { text: 'Etutaso 2-4', value : 'etutaso2-4' }];

        // Calculate selector data
        this.selector_default_data = {
            areas : _.map( this.areas_data, function(o) { return { text : o.name, value : o.id }; } ),
            offices : _.uniq( _.map( this.booking_data, function(o) { return { text : o.toimisto, value : o.toimisto }; } ), function(i) { return i.value; } ),
            agents : _.map( this.booking_data, function(o) { return { text : o.name, value : o.name }; } ),
            types : this.types,
            languages : languages,
            levels : levels
        };

        [ 'areas', 'offices', 'agents', 'types' ].forEach( function( key ) {
            this.selector_default_data[ key ] = this.selector_default_data[ key ].sort(
                function(a, b) { return a.text.localeCompare(b.text); }
            );
        }, this );

        this.$el.html( templatizer.agentBooking( { user : this.model.toJSON(), selector_data : this.selector_default_data, selected_area : this.selected_area } ) );

        this.setupSelectors();

        app.helpers.keepBackgroundCover();
    },

    setupSelectors : function() {

        // Setup chosen
        this.$areas = $('#agent-area').chosen().change( this.changeArea );
        this.$offices = $('#agent-office').chosen().change( this.updateSelectors );
        this.$agents = $('#agent-agent').chosen().change( this.updateSelectors );
        this.$types = $('#agent-type').chosen().change( this.updateSelectors );
        this.$languages = $('#agent-language').chosen().change( this.updateSelectors );
        this.$levels = $('#agent-level').chosen().change( this.updateSelectors );

        // Check if we wanted to get saved values
        if ( app.agent_booking_chosen_data_trigger ) {
            app.agent_booking_chosen_data_trigger = false;

            var data = app.agent_booking_chosen_data;
            _.each( [ 'areas', 'offices', 'agents', 'types', 'languages', 'levels'], function( selector ) {
                this[ '$' + selector ].val( data[ selector ] ).trigger("liszt:updated");
            }.bind(this) );
        }

        this.updateSelectors();
    },

    changeArea : function(e, value ) {
        delete app.agent_booking_chosen_data;
        return this.fetch_and_render( this.$areas.val() );
    },

    updateSelectors : function(e, value) {

        var selected_values = {
            alue : this.$areas.val(),
            toimisto : this.$offices.val(),
            agentti : this.$agents.val(),
            tyyppi : this.$types.val(),
            kieli : this.$languages.val(),
            etutaso : this.$levels.val()
        };

        var checkDesiredKeys = function(filters, filter_data, check_data) {
            var passed = true;

            _.each(filters, function( k )  {
                // If value is selected and differs, disqualify
                if( ! filter_data[k] ) {
                    return;
                }

                if ( k == 'alue' || k == 'toimisto' ) { // matching value in key column?
                    if ( check_data[k] != filter_data[k] ) {
                        passed = false;
                    }
                }
                else { // matching column contains data?
                    if ( ! check_data[ filter_data[k] ] ) {
                        passed = false;
                    }
                }
            });

            return passed;
        };


        // Update offices
        this.$offices.replaceOptions( _.uniq( _.filter( _.map( this.booking_data, function(o) {
            return checkDesiredKeys( ['tyyppi','kieli','etutaso'], selected_values, o ) ? { text : o.toimisto, value : o.toimisto } : {};
        } ), function(o) { return o.value; } ), function(o) { return o.value; } ) );

        this.$agents.replaceOptions( _.uniq( _.filter( _.map( this.booking_data, function(o) {
            return checkDesiredKeys( ['toimisto','tyyppi','kieli','etutaso'], selected_values, o ) ? { text : o.name, value : o.name } : {};
        } ), function(o) { return o.value; } ), function(o) { return o.value; } ) );

        var duplicated_types = [];
        _.each( this.booking_data, function(o) {
            if ( checkDesiredKeys( ['toimisto','kieli','etutaso'], selected_values, o ) ) {
                duplicated_types = duplicated_types.concat( _.map( this.types, function(t) { return o[t.value] ? t : {}; } ) );
            }
        }.bind(this) );

        this.$types.replaceOptions( _.uniq( _.filter( duplicated_types, function(o) { return o.value; } ), function(o) { return o.value; } ) );

        if( selected_values.alue ) this.$areas.val( selected_values.alue );
        if( selected_values.toimisto ) this.$offices.val( selected_values.toimisto );
        if( selected_values.agentti ) this.$agents.val( selected_values.agentti );
        if( selected_values.tyyppi ) this.$types.val( selected_values.tyyppi );

        this.$offices.trigger("liszt:updated");
        this.$agents.trigger("liszt:updated");
        this.$types.trigger("liszt:updated");

        // Start getting data
        this.checkAndStartFetching();
    },

    checkAndStartFetching : function() {

        // Do nothing if only area selected
        if( ! ( this.$types.val() && ( this.$agents.val() || this.$offices.val() ) ) ) {
            $('.js-calendar-guide').show();
            $('.js-calendar-container').html('');
            return;
        }
        else {
            $('.js-calendar-guide').hide();
        }

        var meeting_type = this.$types.val();

        var agent_names = [];
        if( this.$agents.val() ) {
            agent_names.push( this.$agents.val() );
        } else {
            this.$agents.find('option').each(function() { agent_names.push($(this).val()); });
        }

        var level_key = this.$levels.val();
        var lang_key = this.$languages.val();
        var office_key = this.$offices.val();
        var mmr_key = [ level_key, meeting_type, lang_key ].join("-");

        var current_agents = _.filter( this.booking_data, function(o) {
            if ( $.inArray(o.name, agent_names) !== -1 ) {
                if ( ! office_key || office_key == o.toimisto ) {
                    // this could be false if user has multiple calendars in the list
                    if ( o[ mmr_key ] ) {
                        return true;
                    }
                }
            }
            return false;
        } );

        var fetch_matchmaker_urls = _.map( current_agents, function(o) {
            return app.defaults.direct_api_host + '/v1/matchmakers/' + o[ mmr_key ] + '/options';
        } );

        if( fetch_matchmaker_urls.length ) {
            var week = 0;
            if ( app.agent_booking_last_rendered_week && app.agent_booking_last_rendered_week_trigger ) {
                week = app.agent_booking_last_rendered_week;
            }
            this.renderCalendar(week, 0, fetch_matchmaker_urls);
        }

     },

     renderCalendar : function(weekOffset, initCounter, fetch_matchmaker_urls) {
        app.agent_booking_last_rendered_week = weekOffset;

        var _this = this;
        var calendarInPast = false;
        var offset = weekOffset || 0;
        var counter = initCounter || 0;

        // Show spinner
        $('.js-calendar-container').html('<p>'+MTN.t('Loading calendar...')+'</p><div class="loader"></div>');
        var spinner = new Spinner(app.defaults.spinner_opts).spin( $('.loader' , this.el )[0] );

        var weekBegin = Math.round(moment().utc().add('weeks', offset).startOf('isoWeek').valueOf() / 1000);
        var weekEnd = Math.round(moment().utc().add('weeks', offset).endOf('isoWeek').valueOf() / 1000);

        var data = {
            begin_epoch : weekBegin - 25 * 60 * 60,
            end_epoch : weekEnd + 25 * 60 * 60,
            dic : app.auth.token,
            user_id : app.auth.user
        };

        var duration_default = this.$levels.val() == 'etutaso0-1' ? 120 : 90;
        var duration_key = this.$levels.val() == 'etutaso0-1' ? 'etutaso0-1_length_minutes' : 'etutaso2-4_length_minutes';
        var duration = this.settings_data[ duration_key ] || duration_default;

        var tz = app.models.user.attributes.time_zone_offset;
        var tz_changes = app.models.user.attributes.time_zone_dst_change_epoch;
        if ( tz_changes && tz_changes > 0 && weekBegin > tz_changes ) {
            tz = app.models.user.attributes.time_zone_dst_offset;
        }

        var earliestEvent = 8;
        var latestEvent = 20;
        var dateInWeek = new Date( weekBegin * 1000 );

        // Create array of defereds
        var fetches = _.map( fetch_matchmaker_urls, function(url) { return $.get(url, data); } );
        $.when.all(fetches).then( function(responses) {
            // fix "when all" returning no outer array in case of only one fetch
            if ( fetches.length == 1 ) {
                responses = [ responses ];
            }

            var slots = [];
            _.each( responses, function( response ) {
                var response_data = response[0];
                var sorted_data = response_data.sort( function(a, b) { return a.start - b.start; } );

                // combine adjacent slots to form bigger slots
                // note that you can do this only within one users slots
                var user_slots = [];
                _.each( sorted_data, function( slot ) {
                    if ( user_slots.length === 0 ) {
                        user_slots.push( slot );
                    }
                    else {
                        var prev_slot = user_slots[ user_slots.length - 1 ];
                        if ( prev_slot.end < slot.start ) {
                            user_slots.push( slot );
                        }
                        else if ( slot.end > prev_slot.end ) {
                            prev_slot.end = slot.end;
                            prev_slot.end_epoch = slot.end_epoch;
                            prev_slot.id = prev_slot.start_epoch + "_" + prev_slot.end_epoch;
                        }
                    }
                } );

                // remove slots that are too short or outside week
                var valid_user_slots = [];
                _.each( user_slots, function( slot ) {
                    if ( parseInt(slot.end_epoch) + tz < weekBegin ) return;
                    if ( parseInt(slot.start_epoch) + tz > weekEnd ) return;
                    if ( slot.end - slot.start < duration * 60 * 1000 ) return;
                    valid_user_slots.push( slot );
                } );

                slots = slots.concat.apply(slots, valid_user_slots);
            } );


            slots = slots.sort( function(a, b) { return a.start - b.start; } );

            _this.active_slot_data = slots;

            var foundValidSlots = slots.length > 0;

            // Combine overlapping for showing purposes
            var new_slots = [];
            _.each( slots, function( slot ) {
                if ( new_slots.length === 0 ) {
                    new_slots.push( slot );
                }
                else {
                    var prev_slot = new_slots[ new_slots.length - 1 ];
                    if ( prev_slot.end < slot.start ) {
                        new_slots.push( slot );
                    }
                    else if ( slot.end > prev_slot.end ) {
                        // Merbe boses only if they overlap so much that both boxes are
                        // selectable for the whole area of the merge
                        if ( prev_slot.end - slot.start >= duration * 60 * 1000 ) {
                            prev_slot.end = slot.end;
                            prev_slot.end_epoch = slot.end_epoch;
                            prev_slot.id = prev_slot.start_epoch + "_" + prev_slot.end_epoch;
                        }
                        else {
                            new_slots.push( slot );
                        }
                    }
                }
            } );

            // If no results on page or slots outside this week
            var extraMsg = false;
            if( ! foundValidSlots ){
                // If counter is less than 7 , aka searching
                if( counter < 8 ){
                    extraMsg = MTN.t('Searching for free times...');
                    _this.renderCalendar( offset + 1, counter + 1, fetch_matchmaker_urls );
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


            $('.js-calendar-container').html('').btdCal({
                date : dateInWeek,
                mode : 'single_select',
                disableSlotTimeShowing : true,
                timeZoneOffset : tz,
                events: foundValidSlots ? new_slots : [],
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
                    _this.renderCalendar( offset + 1, counter, fetch_matchmaker_urls);
                },
                prevDayHandler : function(){
                    _this.renderCalendar( offset - 1, counter, fetch_matchmaker_urls);
                }
            });

        } );
     },

     chooseSlot : function(data, $slot) {
         var _this = this;

         $slot.html( MTN.t('Reserving...') );

         // Find available matchmaker id's
         var mm_ids = [];
         _.each( this.active_slot_data, function(slot) {
             if( slot.start_epoch <= data.start && slot.end_epoch >= data.end ) {
                 mm_ids.push( slot.matchmaker_id ); // TODO : check name
             }
         } );

         // Set data & get random matchmaker id
         data.start_epoch = data.start;
         data.end_epoch = data.end;
         data.matchmaker_id = mm_ids[Math.floor(Math.random() * mm_ids.length)];

         var mmr_key = [ this.$levels.val(), this.$types.val(), this.$languages.val() ].join("-");
         // Set data for confirm screen
         var $selected_type = this.$types.find('option:selected');
         app.booking_data = {
             meeting_type : $selected_type.text(),
             meeting_type_data : this.types_data_by_id[ $selected_type.val() ],
             language : this.$languages.val(),
             level : this.$levels.val(),
             agent : _.find( this.booking_data, function(o) { return o[mmr_key] == data.matchmaker_id; })
         };

         // Save current chosen options to LS
         app.agent_booking_chosen_data = {};
         _.each( [ 'areas', 'offices', 'agents', 'types', 'languages', 'levels'], function( selector ) {
             app.agent_booking_chosen_data[ selector ] = this[ '$' + selector ].val();
         }.bind(this) );

         // Get lock and proceed
         data.extended_lock = 1;

         app.models.lock = new app.matchmakerLockModel();
         app.models.lock.save( data, { success : function(model, res) {
             if(res.error) {
                 if( res.error.message ) {
                     alert(res.error.message);
                 } else {
                     alert( MTN.t("Oops, something went wrong. Please try again!") );
                 }
             } else {
                 app.router.navigate('/meetings/agent_booking/confirm/' + app.models.lock.get('id'), { trigger : true });
             }
         }});

     }

});
