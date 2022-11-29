dojo.provide("dicole.meetings.views.summaryNavView");

app.summaryNavView = Backbone.View.extend({

    initialize: function(options) {
    },

    render: function() {
        return this;
    },

    events: {
        'click .upcoming' : 'openUpcoming',
        'click .past' : 'openPast',
        'click .create-meeting' : 'newMeeting',
        'click .goto-meetme' : 'openMeetme'
    },

    openMeetme : function(e){
        e.preventDefault();
        window.location = '/meetings/meetme_config';
    },

    newMeeting : function(e){
        e.preventDefault();
        dicole.click_element( $('.js_meetings_new_meeting_open').get(0) );
    },

    openUpcoming : function(e){
        e.preventDefault();
        app.router.upcoming();
    },

    openPast : function(e){
        e.preventDefault();
        app.router.past();
    }
});
