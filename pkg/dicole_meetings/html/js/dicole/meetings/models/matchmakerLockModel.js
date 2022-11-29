dojo.provide("dicole.meetings.models.matchmakerLockModel");

app.matchmakerLockModel = Backbone.Model.extend({
    urlRoot : app.defaults.api_host + '/v1/matchmaker_locks'
});
