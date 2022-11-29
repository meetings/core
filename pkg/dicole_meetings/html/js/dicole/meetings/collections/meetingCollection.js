dojo.provide("dicole.meetings.collections.meetingCollection");

app.meetingCollection = Backbone.Collection.extend({
    model: app.meetingModel,
    initialize: function( data, options ){
        if( options && options.override_endpoint ){
            this.url = app.defaults.api_host + '/v1/users/' + app.auth.user + '/' + options.override_endpoint;
        }
        else{
            this.url = app.defaults.api_host + '/v1/users/' + app.auth.user + '/meetings';
        }
    },
    reset_sub : function() {

        var tz_offset = app.models.user.get('time_zone_offset') || 0;

        // Get times
        var today = Math.floor ( moment().utc().add(tz_offset, 'seconds').startOf('day') / 1000 ) - tz_offset;
        var today_end = Math.floor ( moment().utc().add(tz_offset, 'seconds').endOf('day') / 1000 ) - tz_offset;
        var this_week_end = Math.floor ( moment().utc().add(tz_offset, 'seconds').day(0).add('weeks', 1).startOf('day') / 1000 ) - tz_offset;
        var next_week_end = Math.floor (moment().utc().add(tz_offset, 'seconds').day(0).add('weeks', 2).startOf('day') / 1000 ) - tz_offset;

        // Create a new collection of todays meetings
        var today_meetings = _.filter( app.collections.upcoming.toJSON(), function(o){
            return ( o['begin_epoch'] >= today && o['begin_epoch'] <= today_end );
        });
        app.collections.today.reset( today_meetings );

        // Create new collection this weeks meetings after today and on this week
        var this_week_meetings = _.filter( app.collections.upcoming.toJSON(), function(o){
            return ( o['begin_epoch'] > today_end &&  o['begin_epoch'] <= this_week_end );
        });
        app.collections.this_week_meetings.reset( this_week_meetings );

        // Create new collection this next weeks meetings
        var next_week_meetings =_.filter( app.collections.upcoming.toJSON(), function(o){
            return ( o['begin_epoch'] > this_week_end && o['begin_epoch'] <= next_week_end );
        });
        app.collections.next_week_meetings.reset( next_week_meetings );

        // Create new collection of future meetings
        var all_future_meetings = _.filter( app.collections.upcoming.toJSON(), function(o){
            return ( o['begin_epoch'] > next_week_end );
        });
        app.collections.all_future.reset( all_future_meetings );
    },

    reset_sub_past : function(){

        var tz_offset = app.models.user.get('time_zone_offset') || 0;

        // Yesterday, This week, Last week, Past
        var today = Math.floor( moment().utc().add(tz_offset, 'seconds').startOf('day') / 1000 ) - tz_offset;
        var yesterday = Math.floor( moment().utc().add(tz_offset, 'seconds').subtract('days', 1).startOf('day') / 1000 ) - tz_offset;
        var this_week_begin = Math.floor( moment().utc().add(tz_offset, 'seconds').day(0).startOf('day') / 1000 ) - tz_offset;
        var last_week_begin = Math.floor( moment().utc().add(tz_offset, 'seconds').day(0).add('weeks', -1).startOf('day') / 1000 ) - tz_offset;

        // Create a new collection of yesterdays meetings
        var yesterday_meetings = app.collections.past.filter(function(model) {
            return ( model.get('begin_epoch') <= today && model.get('begin_epoch') >= yesterday );
        });
        app.collections.yesterday.reset( yesterday_meetings );

        // Create a new collection of this weeks past meetings
        var this_week_past_meetings = app.collections.past.filter(function(model) {
            return ( model.get('begin_epoch') <= yesterday && model.get('begin_epoch') >= this_week_begin );
        });
        app.collections.this_week_past.reset( this_week_past_meetings );

        // Create a new collection of last weeks past meetings
        var last_week_past_meetings = app.collections.past.filter(function(model) {
            return ( model.get('begin_epoch') <= this_week_begin && model.get('begin_epoch') >= last_week_begin );
        });
        app.collections.last_week_past.reset( last_week_past_meetings );

        // Create a new collection of the rest of them
        var all_past_meetings = app.collections.past.filter(function(model) {
            return ( model.get('begin_epoch') <= last_week_begin );
        });
        app.collections.all_past.reset( all_past_meetings );
    }
});
