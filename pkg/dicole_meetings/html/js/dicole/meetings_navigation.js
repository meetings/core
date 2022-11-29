dojo.provide("dicole.meetings_navigation");

dojo.require('dicole.meetings_common');
dojo.require('dicole.base');

dicole.register_template("meetings.edit_my_profile", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "edit_my_profile.html")}, true );
dicole.register_template("meetings.change_timezone", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "change_timezone.html")}, true );

dicole.flush_template_prepare_queue();

dojo.subscribe("new_node_created", function(n) {
    dicole.meetings_navigation.hide_messages_counter(n);

    dicole.mocc('js_meetings_connect_profile_with_facebook', dojo.body(), function( node ) {
        dicole.meetings_common.connect_profile_with_facebook( function() {
            dojo.style( dojo.byId('profile-edit-facebook-disconnected'), 'display', 'none');
            dojo.style( dojo.byId('profile-edit-facebook-connected'), 'display', 'block');
            dojo.publish('meetings_admin_accounts_submit');
        } );
    } );
    dicole.mocc('js_meetings_disconnect_profile_from_facebook', dojo.body(), function( node ) {
        dicole.meetings_common.disconnect_profile_from_facebook( function() {
            dojo.style( dojo.byId('profile-edit-facebook-disconnected'), 'display', 'block');
            dojo.style( dojo.byId('profile-edit-facebook-connected'), 'display', 'none');
            dojo.publish('meetings_admin_accounts_submit');
        } );
    } );
    dicole.mocc('js_meetings_fill_profile_with_facebook', dojo.body(), function( node ) {
        dicole.meetings_common.fill_profile_with_facebook( 134, 134 );
    } );

    dicole.mocc('js_meetings_send_receipt', n, function(node) {
        dojo.xhrPost({
            url: dojo.attr(node, 'href'),
            handleAs: 'json',
            handle: function(response) {
                if (response && response.result) {
                }
            }
        });
    });
} );

dicole.meetings_navigation.hide_messages_counter = function(n) {
    dicole.ucq('message-box', n).forEach( function ( node ) {
        setTimeout( function() {
            dojo.fadeOut( { node : node, onEnd : function() { dojo.destroy( node ); } } ).play();
        }, 6000 );
    } );
};
