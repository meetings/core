dojo.provide("dicole.meetings.models.userModel");

app.userModel = Backbone.Model.extend({
    idAttribute : "id",
    defaults : {
        "name": "",
        "first_name": "",
        "last_name" : "",
        "primary_email" : "",
        "phone" : "",
        "organization" : "",
        "organization_title" : "",
        "matchmaker_fragment" : "",
        "meetme_fragment" : "",
        "image" : "",
        "linkedin_url" : "",
        "time_zone_offset" : ""
    },
    initialize : function( opts ) {
        if( opts && typeof opts.id !== null ) this.url = app.defaults.api_host + '/v1/users/' + opts.id;
    },
    startTrial : function(cb) {
        var _this = this;
        $.post(app.defaults.api_host + '/v1/users/' + _this.get('id') + '/start_trial', { dic : app.auth.token, user_id : app.auth.user }, function(res) {
            if(res) {
                _this.set('is_pro', true);
                if(cb) cb();
            }
        });
    }
});
