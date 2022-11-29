dojo.provide("dicole.settings");

dojo.require("dicole.base");

dojo.addOnLoad(function() {
    var facebook_connect_button = dojo.byId("facebook_connect_button");
    if(facebook_connect_button) {
        dojo.connect(facebook_connect_button, "onclick", null, function(event) {
            dojo.stopEvent(event);
            var facebook_connect_url = dicole.get_global_variable("connect_facebook_url");
            FB.getLoginStatus(function(response) {
                if(response.status === 'connected' && response.authResponse ) window.location = facebook_connect_url + "?facebook_user_id=" + response.authResponse.userID;
                else {
                    FB.login(function(response2) {
                        if(response2.authResponse) window.location = facebook_connect_url + "?facebook_user_id=" + response2.authResponse.userID;
                        else alert("Failed to login with Facebook!");
                    });
                }
            });
        });
    }

    var facebook_disconnect_button = dojo.byId("facebook_disconnect_button");
    if(facebook_disconnect_button) {
        dojo.connect(facebook_disconnect_button, "onclick", null, function(event) {
            dojo.stopEvent(event);
            window.location = dicole.get_global_variable("disconnect_facebook_url");
        });
    }
});





