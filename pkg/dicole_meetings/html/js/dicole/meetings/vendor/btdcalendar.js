dojo.provide("dicole.meetings.vendor.btdcalendar");

dojo.require('dicole.meetings.vendor.jquery');
dojo.require('dicole.meetings.vendor.moment');

/*
 * jQuery Plugin: Meetin.gs btdCalendar plugin
 * Version 0.1
 *
 * Copyright (c) 2012 Meetin.gs Ltd
 * Licensed jointly under the GPL and MIT licenses,
 * choose which one suits your project best!
 *
*/
(function($) {
    // Default settings
    var DEFAULT_SETTINGS = {
        showNav : true,
        weekChangingEnabled : true,
        businessHours : {
            start : 8,
            end : 18,
            color : false,
            limitDisplay : true,
            limitByEvents : true
        },
        showTimeRanges : true,
        highlightToday : false,
        daysToShow : 7,
        timeslotHeight: 15,
        timeslotsPerHour : 4,
        use24Hour : false,
        firstDayOfWeek : 1,
        date: null,
        timeFormat : "hh:mm a",
        dateFormat : "MM/DD",
        timeSeparator : " - ",
        mode : 'single_select',
        useShortDayNames : true,
        useShortMonthNames : false,
        dontShowPastEvents : true, // TODO
        disableSlotTimeShowing : false,
        timeZoneOffset : 0,
        disableDateShow : false,
        createEvents : false,
        limitToTimespans : false,
        limitTimespans : [],
        locked : false,
        shortMonths : [],
        longMonths : [],
        shortDays : [],
        longDays : []
    };

    var methods = {
        init: function(options) {

            // Get translations
            var translations = {
                shortMonths : moment.langData()._monthsShort,
                longMonths : moment.langData()._months,
                shortDays : moment.langData()._weekdaysShort,
                longDays : moment.langData()._weekdays
            };

            options.timeFormat = moment.lang() === 'en' ? 'hh A' : 'HH:mm';

            var opt = $.extend({}, DEFAULT_SETTINGS, options || {}, translations );

            return this.each(function () {
                $(this).data("btdCalOject", new $.btd(this, opt));
            });
        }
    };

    // Expose the btdCal function to jQuery as a plugin
    $.fn.btdCal = function (method) {
        // Method calling and initialization logic
        if(methods[method]) {
            return methods[method].apply(this, Array.prototype.slice.call(arguments, 1));
        } else {
            return methods.init.apply(this, arguments);
        }
    };

    // hl class for each element
    $.btd = function (el, options) {
        $el = $(el);
        var MILLIS_IN_DAY = 86400000;
        var MILLIS_IN_WEEK = MILLIS_IN_DAY * 7;

        // Override default timeSlot height & slots per hour
        if( options.selectDuration ) {
            if( options.selectDuration === 20 ) {
                options.timeslotHeight = 20;
                options.timeslotsPerHour = 3;
            }
        }

        function _cloneDate(d) {
            return new Date(d.getTime());
        }

        function _lockCalendar(){
            options.locked = true;
        }
        methods.lock = _lockCalendar;

        function _unlockCalendar(){
            options.locked = false;
        }
        methods.unlock = _unlockCalendar;

        function _rotate(a /*array*/, p /* integer, positive integer rotate to the right, negative to the left... */) {
            for (var l = a.length, p = (Math.abs(p) >= l && (p %= l),p < 0 && (p += l),p), i, x; p; p = (Math.ceil(l / p) - 1) * p - l + (l = p)) {
                for (i = l; i > p; x = a[--i],a[i] = a[i - p],a[i - p] = x);
            }
            return a;
        }

        // Find the earliest event date
        function _firstEventDate() {
            var earliest_date = false;
            $.each( options.events, function(i, event) {
                var test = new Date(event.start);
                if( ! earliest_date || test.getTime() < earliest_date ) earliest_date = test;
            });
            return earliest_date;
        }

        // Function get slots
        function _getSlots() {
            var slots = [];

            // Filter broken slots
            options.events = $.grep( options.events, function( o, i ) { return o.start.getTime() < o.end.getTime(); });

            // Sort events first
            var cmp = function(a,b) {
                return a.start.getTime() - b.start.getTime();
            };
            options.events.sort(cmp);

            // Loop and combine
            var l = options.events.length;
            var slot,evt;
            for( var i = 0; i < l; i++ ) {
                evt = options.events[i];

                // First event, create a slot beginning from there
                if( i === 0 ) {
                    slot = {
                        weekday : _getAdjustedDayIndexUTC(evt.start ),
                        begin_second : evt.start.getUTCHours() * 3600 + evt.start.getUTCMinutes() * 60,
                        end_second : ( evt.end.getUTCHours() || 24 ) * 3600 + evt.end.getUTCMinutes() * 60
                    };
                }

                // Check if the end time of the last slot is the same as begin of the next slot and extend slot
                // also check that were not passing over to the next day
                else if( options.events[i-1].end.getTime() === evt.start.getTime() &&
                       options.events[i-1].start.getUTCDay() === evt.start.getUTCDay() ) {
                    slot.end_second = ( evt.end.getUTCHours() || 24 ) * 3600 + evt.end.getUTCMinutes() * 60;
                }

                // Push the current slot to slots array and create new slot
                else {
                    var temp = jQuery.extend({}, slot);
                    slots.push(temp);
                    slot = {
                        weekday : _getAdjustedDayIndexUTC( evt.start ),
                        begin_second : evt.start.getUTCHours() * 3600 + evt.start.getUTCMinutes() * 60,
                        end_second : ( evt.end.getUTCHours() || 24 ) * 3600 + evt.end.getUTCMinutes() * 60
                    };
                }
            }
            if( slot ) {
                slots.push(slot);
            }
            return slots;
        }
        methods.getSlots = _getSlots;

        function _24HourForIndex(index) {
            if (index === 0) { //midnight
                return "00:00";
            } else if (index < 10) {
                return "0" + index + ":00";
            } else {
                return index + ":00";
            }
        }

        function _formatDate(date, format) {
            return moment(date).utc().format(format);
        }

        function _isToday(date) {
            var clonedDate = _cloneDate(date);
            _clearTime(clonedDate);
            var today = new Date();
            _clearTime(today);
            return today.getTime() === clonedDate.getTime();
        }
        function _dateLastMilliOfDayUTC(date) {
            var midnightCurrentDate = new Date(Date.UTC( date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate() ));
            return new Date(midnightCurrentDate.getTime() + (MILLIS_IN_DAY));
        }

        function _dateLastMilliOfWeek(date) {
            var lastDayOfWeek = _dateLastDayOfWeek(date);
            return new Date(lastDayOfWeek.getTime() + (MILLIS_IN_DAY));
        }
        function _clearTime(d) {
            d.setUTCHours(0);
            d.setUTCMinutes(0);
            d.setUTCSeconds(0);
            d.setUTCMilliseconds(0);
            return d;
        }
        function _addDays(d, n, keepTime) {
            d.setUTCDate(d.getUTCDate() + n);
            if (keepTime) {
                return d;
            }
            return _clearTime(d);
        }

        function _dateFirstDayOfWeek(date){
            var midnightCurrentDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());
            var millisToSubtract = _getAdjustedDayIndex(midnightCurrentDate) * 86400000;
            var first_day = new Date(midnightCurrentDate.getTime() - millisToSubtract);
            return  first_day;
        }

        function _dateFirstDayOfWeekUTC(date){
            var midnightCurrentDate = new Date(Date.UTC( date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate() ));
            var millisToSubtract = _getAdjustedDayIndexUTC(midnightCurrentDate) * 86400000;
            var first_day = new Date(midnightCurrentDate.getTime() - millisToSubtract);
            return  first_day;
        }

        function _dateLastDayOfWeek(date){
            var midnightCurrentDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());
            var millisToAdd = (6 - _getAdjustedDayIndex(midnightCurrentDate)) * MILLIS_IN_DAY;
            return new Date(midnightCurrentDate.getTime() + millisToAdd);
        }

        function _getAdjustedDayIndex(date){
            var midnightCurrentDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());
            var currentDayOfStandardWeek = midnightCurrentDate.getUTCDay();
            var days = [0,1,2,3,4,5,6];
            _rotate(days, options.firstDayOfWeek);
            return days[currentDayOfStandardWeek];
        }

        function _getAdjustedDayIndexUTC(date){
            var midnightCurrentDate = new Date(Date.UTC( date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate() ));
            var currentDayOfStandardWeek = midnightCurrentDate.getUTCDay();
            var days = [0,1,2,3,4,5,6];
            _rotate(days, options.firstDayOfWeek);
            return days[currentDayOfStandardWeek];
        }


        function _updateDayColumnHeader($weekDayColumns) {
            var currentDay = _cloneDate($el.data("startDate"));

            $el.find(".btd-header td.btd-day-column-header").each(function(i, val) {

                var dayName = options.useShortDayNames ? options.shortDays[currentDay.getUTCDay()] : options.longDays[currentDay.getUTCDay()];

                var dayHtml = dayName;
                if( ! options.disableDateShow ) dayHtml += ' ' + _formatDate(currentDay, options.dateFormat);
                $(this).html(dayHtml);
                if (_isToday(currentDay) && options.highlightToday === true) {
                    $(this).addClass("btd-today");
                } else {
                    $(this).removeClass("btd-today");
                }
                currentDay = _addDays(currentDay, 1, true);

            });

            currentDay = _dateFirstDayOfWeekUTC(_cloneDate($el.data("startDate")));

            $weekDayColumns.each(function(i, val) {

                $(this).data("startDate", _cloneDate(currentDay));
                $(this).data("endDate", new Date(currentDay.getTime() + (MILLIS_IN_DAY)));

                if (_isToday(currentDay) && options.highlightToday === true) {
                    $(this).parent().addClass("btd-today");
                } else {
                    $(this).parent().removeClass("btd-today");
                }

                currentDay = _addDays(currentDay, 1, true);
            });

        }

        function _renderCalendar(){
            var calendarNavHtml, calendarHeaderHtml, calendarBodyHtml, $weekDayColumns;

            if (options.showNav && options.weekChangingEnabled) {
                // TODO: Fix this to show the actual week currently shown
                //var week_date_string = _formatDate(_dateFirstDayOfWeek(options.date),'d M') + options.timeSeparator + _formatDate(_dateLastDayOfWeek(options.date),'d M Y');
                //calendarNavHtml = '<p class="btd-week">'+ week_date_string +
                //'</p><a class="btd-today">' + options.buttonText.today + '</a>';

                if( options.weekChangingEnabled ){
                    var tempd = new Date();
                    if( ! ( options.dontShowPastEvents && $el.data('startDate').getTime() <= tempd.getTime() )  ) calendarNavHtml += '<a href="#" class="btd-prev"><i class="ico-leftarrow"></i></a>';
                    calendarNavHtml += '<a href="#" class="btd-next"><i class="ico-rightarrow"></i></a>';
                }

                $(calendarNavHtml).appendTo($el);

                $el.find(".btd-nav .btd-today").click(function(e) {
                    return false;
                });

                $el.find(".btd-prev").click(function(e) {
                    e.preventDefault();
                    options.prevDayHandler();
                });

                $el.find(".btd-next").click(function(e) {
                    e.preventDefault();
                    options.nextDayHandler();
                });

            }

            //render calendar header
            calendarHeaderHtml = "<table class=\"btd-header\"><tbody><tr><td class=\"btd-time-column-header\"></td>";
            for (var i = 1; i <= options.daysToShow; i++) {
                calendarHeaderHtml += "<td class=\"btd-day-column-header btd-day-" + i + "\"></td>";
            }
            calendarHeaderHtml += "<td class=\"btd-scrollbar-shim\"></td></tr></tbody></table>";

            //render calendar body
            calendarBodyHtml = "<div class=\"btd-scrollable-grid\">\
            <table class=\"btd-time-slots\">\
            <tbody>\
            <tr>\
            <td class=\"btd-grid-timeslot-header\"></td>\
            <td colspan=\"" + options.daysToShow + "\">\
            <div class=\"btd-time-slot-wrapper\">\
            <div class=\"btd-time-slots\">";

            var start = options.businessHours.limitDisplay ? options.businessHours.start : 0;
            var end = options.businessHours.limitDisplay ? options.businessHours.end : 24;

            for (var i = start; i < end; i++) {
                for (var j = 0; j < options.timeslotsPerHour - 1; j++) {
                    calendarBodyHtml += "<div class=\"btd-time-slot\"></div>";
                }
                calendarBodyHtml += "<div class=\"btd-time-slot btd-hour-end\"></div>";
            }

            calendarBodyHtml += "</div></div></td></tr><tr><td class=\"btd-grid-timeslot-header\">";

            for (var i = start; i < end; i++) {

                var bhClass = (options.businessHours.color === true && options.businessHours.start <= i && options.businessHours.end > i) ? "btd-business-hours" : "";
                calendarBodyHtml += "<div class=\"btd-hour-header " + bhClass + "\">";
                if (options.use24Hour) {
                    calendarBodyHtml += "<div class=\"btd-time-header-cell\">" + _24HourForIndex(i) + "</div>";
                } else {
                    if( options.showTimeRanges ){
                        calendarBodyHtml += "<div class=\"btd-time-header-cell\">" + moment().minute(0).hour(i).format(options.timeFormat) + " - " + moment().minute(0).hour(i+1).format(options.timeFormat) + "</div>";
                    }
                    else{
                        calendarBodyHtml += "<div class=\"btd-time-header-cell\">" + moment().minute(0).hour(i).format(options.timeFormat) + "</div>";
                    }
                }
                calendarBodyHtml += "</div>";
            }

            calendarBodyHtml += "</td>";

            for (var i = 1; i <= options.daysToShow; i++) {
                calendarBodyHtml += "<td class=\"btd-day-column day-" + i + "\"><div class=\"btd-day-column-inner\"></div></td>";
            }

            calendarBodyHtml += "</tr></tbody></table></div>";

            //append all calendar parts to container
            $(calendarHeaderHtml + calendarBodyHtml).appendTo($el);

            $weekDayColumns = $el.find(".btd-day-column-inner");
            $weekDayColumns.each(function(i, val) {
                $(this).height(options.timeslotHeight * options.timeslotsPerDay);
                if (!options.read_only) {
                    _setupEventCreationForWeekDay($(this));
                }
            });

            $el.find(".btd-time-slot").height(options.timeslotHeight - 1); //account for border

            $el.find(".btd-time-header-cell").css({
                height :  (options.timeslotHeight * options.timeslotsPerHour) - 11,
                padding: 5
            });

        }
        function _computeOptions() {
            if(options.businessHours.limitByEvents && options.events && options.events.length > 0 ){
                var f = 23, l = 0;
                $.each( options.events, function(i){
                    var dl = new Date(this.end);
                    var df = new Date(this.start);
                    if( dl.getUTCHours() >= l ) {
                        l = dl.getUTCHours();
                        if( dl.getUTCMinutes() > 0 ) l = l + 1; // Fix case where last is xx:30
                    }
                    if( df.getUTCHours() < f ) f = df.getUTCHours();
                });
                options.businessHours.end = l;
                options.businessHours.start = f;

                // TODO: REmove this hack
                if( options.businessHours.end < 18 ) options.businessHours.end = 17;
                if( options.businessHours.start > 7 ) options.businessHours.start = 9;

            }

            if( options.calendarAddEmptyPadding ){
                if( options.businessHours.end < 24 ){
                    options.businessHours.end++;
                }
                if( options.businessHours.start > 0 ){
                    options.businessHours.start--;
                }
            }

            // Round floor and ceil start and end respectively as calendar is always drawn from full hour and not half
            options.businessHours.start = Math.floor(options.businessHours.start);
            options.businessHours.end = Math.ceil(options.businessHours.end);

            if (options.businessHours.limitDisplay) {
                options.timeslotsPerDay = options.timeslotsPerHour * (options.businessHours.end - options.businessHours.start);
                options.millisToDisplay = (options.businessHours.end - options.businessHours.start) * 60 * 60 * 1000;
                options.millisPerTimeslot = options.millisToDisplay / options.timeslotsPerDay;
            }
            else {
                options.timeslotsPerDay = options.timeslotsPerHour * 24;
                options.millisToDisplay = MILLIS_IN_DAY;
                options.millisPerTimeslot = MILLIS_IN_DAY / options.timeslotsPerDay;
            }

            if( options.limitTimespans && options.limitTimespans.length ) {
                options.limitToTimespans = true;

                // DST change check
                options.limitTimespansTzOffset = options.limitTimespansTz.offset_value;
                if( options.limitTimespansTz.dst_change_epoch && options.limitTimespansTz.dst_change_epoch < options.limitTimespans[0].start ) {
                    options.limitTimespansTzOffset = options.limitTimespansTz.changed_offset_value;
                }
            }

            if(options.mode === 'single_select'){
                options.read_only = true;
            }
            else{
                options.read_only = false;
            }
        }
        function _loadCalEvents(dateWithinWeek) {

            var date, weekStartDate, endDate, $weekDayColumns;
            date = dateWithinWeek || options.date;
            weekStartDate = _dateFirstDayOfWeekUTC(date);
            weekEndDate = new Date( weekStartDate.getTime() + 60 * 60 * 24 * 7 * 1000 );

            $el.data("startDate", weekStartDate);
            $el.data("endDate", weekEndDate);

            $weekDayColumns = $el.find(".btd-day-column-inner");

            _updateDayColumnHeader($weekDayColumns);

            _renderEvents( options.events, $weekDayColumns);
        }
        function _clearCalendar() {
            $el.find(".btd-day-column-inner div").remove();
        }
        function _findWeekDayForEvent(calEvent, $weekDayColumns) {

            var $weekDay;
            $weekDayColumns.each(function(i) {
                if ($(this).data("startDate").getTime() <= calEvent.start.getTime() && $(this).data("endDate").getTime() >= calEvent.end.getTime()) {
                    $weekDay = $(this);
                    return false;
                }
            });
            return $weekDay;
        }
        function _cleanEvents(events) {
            var cleaned_events = [];
            var split_events = [];
            var new_events = [];

            // Clean events & add timezone offset
            $.each(events, function(i, event) {
                var new_event = _cleanEvent(event);
                cleaned_events.push(new_event);
            });

            // Split events if they go over day boundaries
            $.each(cleaned_events, function(i,event){
                var cont = true;
                var count = 0;
                while(cont){
                    // Find the end of day milli from the event begin
                    count++;
                    if(count > 5) cont = false;
                    var start_of_next_day = _dateLastMilliOfDayUTC(event.start);

                    // If event end is still larger than day end, we need to split it
                    if( start_of_next_day.getTime() < event.end.getTime() ){

                        // Create the new event
                        var new_event = { start : event.start, end : new Date(start_of_next_day.getTime()) };

                        // Update event start so we can continue the loop
                        event.start = new Date(start_of_next_day.getTime());

                        // Add new split event to array
                        split_events.push(new_event);
                    }
                    else{
                        // Add the remainder to array
                        split_events.push(event);

                        // Stop while
                        cont = false;
                    }

                }
            });

            // Remove too short events if needed
            if ( options.selectDuration ) {
                $.each(split_events, function(i,event){
                    // Keep event only if duration more than minimum duration
                    if ( event.end.getTime() - event.start.getTime() >= options.selectDuration * 1000 * 60 ) {
                        new_events.push( event );
                    }
                });
            }
            else{
                new_events = split_events;
            }

            return new_events;
        }

        function _cleanDate(d) {
            if ( options.timeZoneOffset ) {
                return new Date( new Date(d).getTime() + 1000 * options.timeZoneOffset );
            }
            else {
                return new Date( d );
            }
        }
        /*
         * Clean specific event
         */
        function _cleanEvent(event) {
            if (event.date) {
                event.start = event.date;
            }
            // Fix events to start & end inside slots

            // WARNING: this IF is just a hack to rescue _some_ of the options this code hides by accident
            if ( event.end - event.start > options.selectDuration * 60 * 1000 ) {
                if( moment(event.start).get('minutes') % ( 60 / options.timeslotsPerHour ) ) {
                    event.start = moment(event.start).set('minute', Math.ceil( moment(event.start).get('minutes') / ( 60 / options.timeslotsPerHour ) ) * ( 60 / options.timeslotsPerHour ) ).valueOf();
                }
                if( moment(event.end).get('minutes') % ( 60 / options.timeslotsPerHour ) ) {
                    event.end = moment(event.end).set('minute', Math.floor( moment(event.end).get('minutes') / ( 60 / options.timeslotsPerHour ) ) * ( 60 / options.timeslotsPerHour ) ).valueOf();
                }
            }

            event.start = _cleanDate(event.start);
            event.end = _cleanDate(event.end);
            if (!event.end) {
                event.end = _addDays(_cloneDate(event.start), 1);
            }

            return event;
        }

        function getWeek (getdate) {
            var a, b, c, d, e, f, g, n, s, w;
            $y = getdate.getFullYear();
            $m = getdate.getMonth() + 1;
            $d = getdate.getDate();
            if ($m <= 2) {
                a = $y - 1;
                b = (a / 4 | 0) - (a / 100 | 0) + (a / 400 | 0);
                c = ((a - 1) / 4 | 0) - ((a - 1) / 100 | 0) + ((a - 1) / 400 | 0);
                s = b - c;
                e = 0;
                f = $d - 1 + (31 * ($m - 1));
            } else {
                a = $y;
                b = (a / 4 | 0) - (a / 100 | 0) + (a / 400 | 0);
                c = ((a - 1) / 4 | 0) - ((a - 1) / 100 | 0) + ((a - 1) / 400 | 0);
                s = b - c;
                e = s + 1;
                f = $d + ((153 * ($m - 3) + 2) / 5) + 58 + s;
            }
            g = (a + b) % 7;
            d = (f + g - e) % 7;
            n = (f + 3 - d) | 0;
            if (n < 0) {
                w = 53 - ((g - s) / 5 | 0);
            } else if (n > 364 + s) {
                w = 1;
            } else {
                w = (n / 7 | 0) + 1;
            }
            $y = $m = $d = null;
            return w;
        }
        function _renderEvents(events, $weekDayColumns) {
            _clearCalendar();
            // TODO: resizing calendar
            $.each(events, function(i, calEvent) {
                var $weekDay = _findWeekDayForEvent(calEvent, $weekDayColumns);
                if ($weekDay) {
                    _renderEvent(calEvent, $weekDay);
                }
            });

            // Show empty cal note
            if( ! events.length && options.warnOnEmpty === true ){
                var weeknum = getWeek( options.date );
                var str = '<div class="message m-modal"><div class="modal-content"><p>' + MTN.t('No free times for week %1$s.',[weeknum]) + '</p>';
                if( options.extraMessage ) {
                    str += '<p>'+options.extraMessage+'</p></div></div>';
                }
                else{
                    str += '</div></div>';
                }
                var $note = $(str);
                $el.append($note);
            }

        }
        function _setupEventDelegation() {
            $('.btd-cal-event').on( 'click', function(e){
                var $t = $(this);
                options.eventClick($t.data("calEvent"), $t, e);
            });
            $('.btd-cal-event').on( 'mouseenter', function(e){
                var $t = $(this);
                options.eventMouseover($t.data("calEvent"), $t, e);
            });
            $('.btd-cal-event').on( 'mouseleave', function(e){
                var $t = $(this);
                options.eventMouseout($t.data("calEvent"), $t, e);
            });
        }
        function _positionEvent($weekDay, $calEvent) {
            var calEvent = $calEvent.data("calEvent");
            var pxPerMillis = $weekDay.height() / options.millisToDisplay;
            var firstHourDisplayed = options.businessHours.limitDisplay ? options.businessHours.start : 0;
            var startMillis = ( calEvent.start.getUTCHours() - firstHourDisplayed ) * 60 * 60 * 1000;
            startMillis = startMillis + calEvent.start.getUTCMinutes() * 60 * 1000; // Add minutes
            var eventMillis = calEvent.end.getTime() - calEvent.start.getTime();
            var pxTop = pxPerMillis * startMillis;
            var pxHeight = pxPerMillis * eventMillis;
            $calEvent.css({top: pxTop, height: pxHeight});
        }
        function _refreshEventDetails(calEvent, $calEvent) {
            if( ! options.disableSlotTimeShowing ) {
                $calEvent.find(".btd-time").html(_formatDate(calEvent.start, options.timeFormat) + options.timeSeparator + _formatDate(calEvent.end, options.timeFormat));
            }
            //$calEvent.find(".btd-title").html(calEvent.start.toString() );
            if( ! options.mode === 'multiselect' ){
                $calEvent.find(".btd-title").html(calEvent.title || MTN.t('Choose') );
            }
            $calEvent.data("calEvent", calEvent);
        }
        function _renderEvent(calEvent, $weekDay) {
            if (calEvent.start.getTime() > calEvent.end.getTime()) {
                return; // can't render a negative height
            }
            var eventClass, eventHtml, $calEvent, $modifiedEvent;
            var lineHeight = options.timeslotHeight - 2;
            eventClass = calEvent.id ? "btd-cal-event" : "btd-cal-event btd-new-cal-event";
            eventHtml = "<div class=\"" + eventClass + " ui-corner-all\">\
            <div class=\"btd-time ui-corner-all\"></div>\
            <div class=\"btd-title\"></div></div>";

            $calEvent = $(eventHtml);
            $calEvent = $modifiedEvent ? $modifiedEvent.appendTo($weekDay) : $calEvent.appendTo($weekDay);
            $calEvent.css({lineHeight: lineHeight + "px", fontSize: (options.timeslotHeight / 2) + "px"});

            _refreshEventDetails(calEvent, $calEvent);
            _positionEvent($weekDay, $calEvent);
            $calEvent.show();

            $calEvent.data('startDate',calEvent.start);

            if( options.mode === 'single_select' ){
                _setupSlotSelectionForEvent($calEvent);
            }

            return $calEvent;

        }

        function _addOrRemoveEvents(evts, $weekday ){

            // TODO: Don't draw if no changes

            _.each(evts, function(evt) {

                // Find and remove if found
                var l = options.events.length;
                var removed = false;
                for( var i = 0; i < l; i++ ){
                    if( options.events[i].start.getTime() === evt.start.getTime() ){
                        options.events.splice(i,1);
                        removed = true;
                        break;
                    }
                }

                // Add if not found
                if( ! removed ){
                    options.events.push(evt);
                }
            });

            // Redraw events to calendar
            _loadCalEvents();
        }


        function _setupSlotSelectionForEvent($event){
            var $slot_el;
            var event_height = $event.height();
            var slot_height = Math.floor(options.timeslotHeight * options.timeslotsPerHour / 60 * options.selectDuration);
            var eventOffset = $event.offset();
            $event.mousemove(function(e){
                if($slot_el && !options.locked){
                    var y = (e.pageY - eventOffset.top); // How much event begin is from the top of event
                    var roundedYPos = Math.floor( y / options.timeslotHeight) * options.timeslotHeight;
                    // Prevent highlight outside of the box
                    if( roundedYPos + slot_height >= event_height ) roundedYPos = event_height - slot_height;
                    $slot_el.css('top',roundedYPos );
                }
            }).mouseenter(function(e){

                // Don't show if slot too small
                if( event_height < slot_height || options.locked ) return;
                $slot_el = $('<div class="btd-slot-in-event"><i class="ico-check"></i> '+MTN.t('Choose')+'</div>').css({'height' : slot_height ,'line-height' : slot_height+'px'});
                $event.append($slot_el);
            }).mouseleave(function(e){
                if(options.locked) return;
                if($slot_el) $slot_el.remove();
            }).click(function(e){
                if(options.locked) return;
                options.locked = true;

                // Calculate hour
                var y = (e.pageY - eventOffset.top);
                var roundedYPos = Math.floor( y / options.timeslotHeight) * options.timeslotHeight;
                // TODO: Handle case when clicking the end of the world
                if( roundedYPos + slot_height >= event_height ) roundedYPos = event_height - slot_height;

                var slot_number = roundedYPos / options.timeslotHeight;

                var hour = slot_number / options.timeslotsPerHour;

                var start = _cloneDate( $event.data('startDate') );
                var end = _cloneDate( $event.data('startDate') );

                var start_add = hour * 3600;
                var end_add = hour * 3600 + options.selectDuration * 60;

                var evt = {
                    start : Math.floor(start.getTime() / 1000 + start_add - options.timeZoneOffset),
                    end : Math.floor(end.getTime() / 1000 + end_add - options.timeZoneOffset)
                };

                options.slotChoose(evt,$slot_el);

            });
        }

        function _getSlotNumberForMouseEvent(e,el) {
            var parentOffset = $(el).parent().offset();
            var y = (e.pageY - parentOffset.top);
            var roundedYPos = Math.floor( y / options.timeslotHeight) * options.timeslotHeight;
            return roundedYPos / options.timeslotHeight;
        }

        function _calculateSlot(date, slotNumber) {

            // TODO: Take into account  if the calendar does not start from 00:00
            var start = _cloneDate( date );
            var end = _cloneDate( date );

            var minutesInSlot = 60 / options.timeslotsPerHour;
            var minutes = slotNumber * minutesInSlot;

            var start_hour = Math.floor( minutes / 60 );
            var end_hour = Math.floor( (minutes + minutesInSlot) / 60 );
            var start_minutes = minutes % 60;
            var end_minutes = (minutes + minutesInSlot) % 60;

            start.setUTCHours(start_hour);
            start.setUTCMinutes(start_minutes);

            end.setUTCHours(end_hour);
            end.setUTCMinutes(end_minutes);

            return {
                start : start,
                end : end,
                num : slotNumber
            };
        }

        function _getSlotDataFromMouseEvent(e, el, $weekDay, lastEvent) {

            var curSlotNumber = _getSlotNumberForMouseEvent(e,el);
            var prevSlotNumber = lastEvent ? _getSlotNumberForMouseEvent(lastEvent,el) : curSlotNumber;

            var max = Math.max(curSlotNumber,prevSlotNumber);
            var min = Math.min(curSlotNumber,prevSlotNumber);

            var slots = [];

            while( min <= max ) {
                slots.push( _calculateSlot ($weekDay.data('startDate'), min) );
                min++;
            }

            return slots;
        }

        function _slotOutsideOfLimitSpans(slot) {
            var ret = true;
            // TODO: optimize maybe?
            var weekstart = _dateFirstDayOfWeekUTC(options.date);
            var mm = weekstart.getTime();
            $.each( options.limitTimespans, function(i, span) {
                if( slot.start.getTime() - mm >= ( span.start + options.limitTimespansTzOffset ) * 1000 && slot.end.getTime() - mm <= ( span.end + options.limitTimespansTzOffset ) *1000 ) ret = false;
            });
            return ret;
        }

        function _setupEventCreationForWeekDay($weekDay){
            var $event_el;
            var disable_events = false;
            var weekDayHeight = $weekDay.height();
            var lastEvent = false;
            var lastSlot = false;
            options.mouseDown = false;
            options.protectedSlots = [];
            options.activeDay = $weekDay.parent().attr('class');

            $weekDay.mousemove(function(e) {
                if(! disable_events && $event_el) {
                    var parentOffset = $(this).parent().offset();
                    var y = (e.pageY - parentOffset.top);
                    var roundedYPos = Math.floor( y / options.timeslotHeight) * options.timeslotHeight;
                    var slotNumber = roundedYPos / options.timeslotHeight;
                    // Prevent highlight outside of the box
                    if( roundedYPos + options.timeslotHeight >= weekDayHeight ) roundedYPos = weekDayHeight - options.timeslotHeight;
                    var css = { top : roundedYPos - 1, 'background-color' : '' };
                    var slots = _getSlotDataFromMouseEvent(e, this, $weekDay, lastEvent);

                    if(options.mouseDown) {
                        // Remove protected slots from selection
                        slots = _.filter(slots, function(slot) { return $.inArray(slot.num, options.protectedSlots ) === -1 });
                    }

                    if( options.limitToTimespans && _slotOutsideOfLimitSpans(slot) ) css['background-color'] = 'transparent';
                    $event_el.show().css(css);
                    if(options.mouseDown && lastSlot !== slotNumber ) _addOrRemoveEvents(slots, $weekDay);

                    if(options.mouseDown) {
                        // Add to protected slots
                        options.protectedSlots = options.protectedSlots.concat(_.map(slots, function(slot) { return slot.num; }));
                    }
                    lastSlot = slotNumber;
                    lastEvent = e;
                }
            }).mouseenter(function(e) {
                if( disable_events ) return;

                // Disable painting entering new day
                if( options.activeDay !== $weekDay.parent().attr('class') ) {
                    options.mouseDown = false;
                    options.activeDay = $weekDay.parent().attr('class');
                    options.protectedSlots = [];
                }

                $event_el = $('<div class="green btd-event-hovering"></div>').css('height',options.timeslotHeight);
                $weekDay.append($event_el);
            }).mouseleave(function(e) {
                if($event_el ) $event_el.remove();
            }).click(function(e) {
                // Do nothing
            }).mousedown(function(e) {
                if( disable_events ) return;
                var slots = _getSlotDataFromMouseEvent(e, this, $weekDay);
                disable_events = true;
                setTimeout(function(){
                    disable_events = false;
                    $event_el = $('<div class="green btd-event-hovering"></div>').css('height',options.timeslotHeight).hide();
                    $weekDay.append($event_el);
                },200);
                if( options.limitToTimespans && _slotOutsideOfLimitSpans(slot) ) return;
                _addOrRemoveEvents( slots, $weekDay );

                options.mouseDown = true;
            }).mouseup(function(e) {
                options.protectedSlots = [];
                options.mouseDown = false;
            });
        }

        function _createEvents( slots, split_seconds ) {
            slots = slots || _.map( [0,1,2,3,4], function(wd) { return { weekday : wd, begin_second : 8*60*60, end_second : 16*60*60 }; } );
            options.events = [];
            var w = options.displayWeek;

            // IF no slots, we need to set the date
            if( ! slots.length ){
                options.date = new Date( Date.UTC( w.y, w.m, w.d, 0, 0, 0, 0 ) );
            }

            _.each( slots, function( slot ) {
                var day_start_milliepoch = Date.UTC(w.y, w.m, w.d + slot.weekday, 0, 0, 0, 0);
                if ( split_seconds ) {
                    var s = slot.begin_second;
                    var e = 0;
                    while ( e < slot.end_second ) {
                        e = e ? e + split_seconds : s + split_seconds;
                        e = e > slot.end_second ? slot.end_second : e;
                        options.events.push( {
                            start : new Date( day_start_milliepoch + s * 1000 ),
                            end : new Date( day_start_milliepoch + e * 1000 )
                        });
                        s = s + split_seconds;
                    }
                } else {
                    options.events.push( {
                        start : new Date( day_start_milliepoch + slot.begin_second * 1000 ),
                        end : new Date( day_start_milliepoch + slot.end_second * 1000 )
                    } );
                }
            } );
        }

        function _cleanLimitTimespans() {
            var d = new Date(options.limitTimespans[0].start*1000);
            var weekstart = _dateFirstDayOfWeekUTC(d);
            var s_weekstart = weekstart.getTime() / 1000;
            $.each( options.limitTimespans, function(i, span) {
                options.limitTimespans[i].start = span.start - s_weekstart;
                options.limitTimespans[i].end = span.end - s_weekstart;
            });
        }

        // Create empty events if wanted
        if( options.createEvents ) _createEvents( options.slots, 60*60 / options.timeslotsPerHour );

        // Fix times with offset
        options.events = _cleanEvents(options.events);

        // Setup dates
        if( ! options.date ) options.date = _firstEventDate();

        var weekStartDate = _dateFirstDayOfWeekUTC(options.date);
        var weekEndDate = new Date( weekStartDate.getTime() + 60 * 60 * 24 * 7 * 1000 );

        $el.data("startDate", weekStartDate);
        $el.data("endDate", weekEndDate);

        // Initialize the plugin
        _computeOptions();

        _renderCalendar();
        _updateDayColumnHeader($el.find(".btd-day-column-inner"));
        _loadCalEvents();

        // Fix limit timespans to seconds from week begin
        if( options.limitToTimespans ) _cleanLimitTimespans();


        return this;
    };
}(jQuery));
