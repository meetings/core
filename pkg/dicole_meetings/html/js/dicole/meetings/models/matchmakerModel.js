dojo.provide('dicole.meetings.models.matchmakerModel');

app.matchmakerModel = Backbone.Model.extend({
    idAttribute: 'id',
    urlRoot : app.defaults.api_host + '/v1/matchmakers',
    defaults: {
        'event_data': {},
        'user_id': '',
        'description' : 'Hello! I have made my calendar available to you. Please click on the button below to start scheduling the meeting.',
        'location' : '',
        'duration' : 30,
        'youtube_url' : '',
        'buffer' : 30,
        'planning_buffer' : 1800,
        'slots' : _.map( [0,1,2,3,4], function(wd) { return { weekday : wd, begin_second : 8*60*60, end_second : 18*60*60 }; } ),
        'background_url' : '',
        'direct_link_enabled' : '',
        'source_settings' : {
            'enabled' : {},
            'disabled' : {}
        },
        'background_theme' : 0
    },
    initialize : function(){
    }
});
