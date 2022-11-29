dojo.provide("dicole.meetings");
dojo.require("dicole.meetings.main");
dojo.require("dicole.meetings_common");
dojo.require("dicole.base");
dojo.require("dicole.comments");
dojo.require("dojo.window");
dojo.require("dojo.cookie");
dojo.require("dojo.fx");

// jQuery Plugins
dojo.require("dicole.meetings.vendor.autocomplete");
dojo.require("dicole.meetings.vendor.charcounter");
dojo.require("dicole.meetings.vendor.chosen");
dojo.require("dicole.meetings.vendor.guiders");
dojo.require("dicole.meetings.vendor.hintlighter");
dojo.require("dicole.meetings.vendor.nouislider");
dojo.require("dicole.meetings.vendor.jqueryuiwidget");
dojo.require("dicole.meetings.vendor.iframe_transport");
dojo.require("dicole.meetings.vendor.fileupload");

dicole.register_template("meetings.inplace", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "inplace.html")}, true);
dicole.register_template("meetings.add_material", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "add_material.html")}, true );
dicole.register_template("meetings.add_material_uploading", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "add_material_uploading.html")}, true );
dicole.register_template("meetings.add_material_wiki", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "add_material_wiki.html")}, true );
dicole.register_template("meetings.add_material_previous", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "add_material_previous.html")}, true );
dicole.register_template("meetings.add_material_previous_file_list", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "add_material_previous_file_list.html")}, true );
dicole.register_template("meetings.edit_media_embed", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "edit_media_embed.html")}, true );
dicole.register_template("meetings.remove_media", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "remove_media.html")}, true );
dicole.register_template("meetings.manage_navi", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "manage_navi.html")}, true );
dicole.register_template("meetings.manage_email", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "manage_email.html")}, true );
dicole.register_template("meetings.manage_password", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "manage_password.html")}, true );
dicole.register_template("meetings.manage_basic", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "manage_basic.html")}, true );
dicole.register_template("meetings.manage_participant_rights", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "manage_participant_rights.html")}, true );
dicole.register_template("meetings.manage_remove", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "manage_remove.html")}, true );
dicole.register_template("meetings.manage_virtual", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "manage_virtual.html")}, true );
dicole.register_template("meetings.invite_participants", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "invite_participants.html")}, true );
dicole.register_template("meetings.invite_participants_new", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "invite_participants_new.html")}, true );
dicole.register_template("meetings.invite_customize_message", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "invite_customize_message.html")}, true );
dicole.register_template("meetings.invite_transfer", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "invite_transfer.html")}, true );
dicole.register_template("meetings.show_user", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "show_user.html")}, true );
dicole.register_template("meetings.meeting_progress_bar", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "meeting_progress_bar.html")}, true );
dicole.register_template("meetings.inplace_comments", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "inplace_comments.html")}, true );
dicole.register_template("meetings.inplace_page_editor", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "inplace_page_editor.html")}, true );
dicole.register_template("meetings.confirm_page_edit_cancel", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "confirm_page_edit_cancel.html")}, true );
dicole.register_template("meetings.login_return", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "login_return.html")}, true );
dicole.register_template("meetings.no_shared_notes_found", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "no_shared_notes_found.html")}, true );
dicole.register_template("meetings.user_guide_menu", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "user_guide_menu.html")}, true );
dicole.register_template("meetings.user_guide", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "user_guide.html")}, true );
dicole.register_template("meetings.user_guide_pro", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "user_guide_pro.html")}, true );
dicole.register_template("meetings.user_guide_email", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "user_guide_email.html")}, true );
dicole.register_template("meetings.ics_feed_instructions", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "ics_feed_instructions.html")}, true );
dicole.register_template("meetings.remove_meeting", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "remove_meeting.html")}, true );
dicole.register_template("meetings.remove_page", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "remove_page.html")}, true );
dicole.register_template("meetings.rename_page", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "rename_page.html")}, true );
dicole.register_template("meetings.rename_media", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "rename_media.html")}, true );
dicole.register_template("meetings.replace_media", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "replace_media.html")}, true );
dicole.register_template("meetings.mobile_upload_instructions", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "mobile_upload_instructions.html")}, true );
dicole.register_template("meetings.admin_appearance", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "admin_appearance.html")}, true );
dicole.register_template("meetings.basic_info", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "basic_info.html")}, true );
dicole.register_template("meetings.comment", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "comment.html")}, true );
dicole.register_template("meetings.edit_comment", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "edit_comment.html")}, true );
dicole.register_template("meetings.delete_comment_confirm", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "delete_comment_confirm.html")}, true );
dicole.register_template("meetings.set_date", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "set_date.html")}, true );
dicole.register_template("meetings.set_date_confirm", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "set_date_confirm.html")}, true );
dicole.register_template("meetings.set_location", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "set_location.html")}, true );
dicole.register_template("meetings.set_title", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "set_title.html")}, true );
dicole.register_template("meetings.timezone_dropdown", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "timezone_dropdown.html")}, true );
dicole.register_template("meetings.edit_my_profile_new_user", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "edit_my_profile.html")}, true );
dicole.register_template("meetings.edit_my_profile", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "edit_my_profile.html")}, true );
dicole.register_template("meetings.remove_self_from_meeting", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "remove_self_from_meeting.html")}, true );
dicole.register_template("meetings.rsvp_bar", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "rsvp_bar.html")}, true );
dicole.register_template("meetings.rsvp_profile", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "rsvp_profile.html")}, true );
dicole.register_template("meetings.template_chooser", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "template_chooser.html")}, true );
dicole.register_template("meetings.tutorial_chooser", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "tutorial_chooser.html")}, true );
dicole.register_template("meetings.gcal_view", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "gcal_view.html")}, true );
dicole.register_template("meetings.next_action_bar", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "next_action_bar.html")}, true );
dicole.register_template("meetings.matchmaking_success", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "matchmaking_success.html")}, true );
dicole.register_template("meetings.matchmaking_validate", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "matchmaking_validate.html")}, true );
dicole.register_template("meetings.matchmaking_list", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "matchmaking_list.html")}, true );
dicole.register_template("meetings.matchmaking_register", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "matchmaking_register.html")}, true );
dicole.register_template("meetings.matchmaking_register_success", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "matchmaking_register_success.html")}, true );
dicole.register_template("meetings.matchmaking_user_register_success", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "matchmaking_user_register_success.html")}, true );
dicole.register_template("meetings.matchmaking_confirm", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "matchmaking_confirm.html")}, true);
dicole.register_template("meetings.matchmaking_limit_reached", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "matchmaking_limit_reached.html")}, true);
dicole.register_template("meetings.matchmaking_lock_expired", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "matchmaking_lock_expired.html")}, true);
dicole.register_template("meetings.matchmaking_confirm_register", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "edit_my_profile.html")}, true );
dicole.register_template("meetings.matchmaking_admin_editor", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "matchmaking_admin_editor.html")}, true );
dicole.register_template("meetings.matchmaking_decline", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "matchmaking_decline.html")}, true );
dicole.register_template("meetings.meeting_cancel", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "meeting_cancel.html")}, true );
dicole.register_template("meetings.meeting_cancel_or_reschedule", {templatePath: dojo.moduleUrl("dicole.meetings.dtmpl", "meeting_cancel_or_reschedule.html")}, true );

dicole.meetings.draft_comments = {};
dicole.meetings.data = {};

var initMeetings = function() {
    if( ! $('body').hasClass('action_meetings') ) return;

    var prevent_timezone_open = app.helpers.checkGlobals([ 'meetings_open_language_selector', 'meetings_open_promo_subscribe', 'meetings_prevent_timezone_open' ]);

    if( (dojo.hasClass( dojo.body() ,'action_meetings_task_summary') || dojo.hasClass( dojo.body() ,'action_meetings_task_meeting') ) && ! prevent_timezone_open ) {
        var ua_tz = jstz.determine_timezone().name();
        var user_tz = dicole.get_global_variable('meetings_user_timezone_name');
        var dismissed = dicole.get_global_variable('meetings_dismissed_timezones');
        if( ua_tz !== user_tz && $.inArray(ua_tz,dismissed) === -1  ) {
            var d = new Date();
            $.get( dicole.get_global_variable('meetings_timezone_data_url'), function(res) {
                var tz_data = res.result.timezone_data;

                // IF user timezone was not something we know, treat it as UTC
                // also if UTC is dismissed, cancel popup swhowing
                if( ! tz_data[ua_tz] ) ua_tz = 'UTC';

                // Check that tz is not dismissed before
                if( $.inArray(ua_tz,dismissed) !== -1 ) {
                    dicole.set_global_variable('meetings_prevent_timezone_open',1);
                    initMeetings();
                    return;
                }

                // Check that offsets are also different
                if( tz_data[ua_tz].offset_value !== tz_data[user_tz].offset_value || tz_data[ua_tz].dst_change_epoch !== tz_data[user_tz].offset_value ) {
                    dicole.set_global_variable('meetings_prevent_timezone_open',1);
                    initMeetings();
                    return;
                }

                var tz_choices  = res.result.timezone_choices;
                var showcase = dicole.create_showcase({
                    "width": 590,
                    "disable_close": true,
                    "disable_background_close": true,
                    "content": templatizer.verifyTimezone({ ua_tz : ua_tz, tz_data : tz_data, tz_choices : tz_choices, user_tz : user_tz, d : d })
                });

                // Timezone dropdown
                var $select = $('#timezone-select', showcase.nodes.content);
                $select.chosen().change(function(e){
                    // Change radio button val
                    var tz = $(e.currentTarget).val();
                    $('#user-tz', showcase.nodes.content).val( tz );

                    // Redraw time
                    var new_time_string = moment.utc(d.getTime() + tz_data[tz].offset_value * 1000).format('hh:mm A');
                    $('#user-time', showcase.nodes.content).html(new_time_string);

                });

                $('.change-timezone', showcase.nodes.content).on('click', function(e){
                    e.preventDefault();
                    $(e.currentTarget).text( MTN.t('Saving...') );
                    var val = $('input[name="tzname"]:radio:checked').val();
                    var dismiss = val === user_tz ? ua_tz : '';
                    $.post( dicole.get_global_variable('meetings_timezone_confirm_url'), { choose : val , dismiss : dismiss }, function(res) {
                        window.location = dicole.get_global_variable('meetings_timezone_confirm_redirect');
                    });
                });

            });
            return;
        }
    }

    dicole.meetings.check_browsers();

    // Call correct init
    var action = $('body').attr('class');
    if( action.indexOf('action_meetings_task_summary') !== -1 ) {
        app.init_summary();
    } else if(action.indexOf('action_meetings_task_meeting') !== -1) {
        app.init_meeting();
    } else if( action.indexOf('action_meetings_task_meet') !== -1 ||
              action.indexOf('action_meetings_task_meetme_config') !== -1 ||
              action.indexOf('action_meetings_task_meetme_share') !== -1 ||
              action.indexOf('action_meetings_task_meetme_claim') !== -1 ||
              action.indexOf('action_meetings_task_wizard_apps') !== -1 ||
              action.indexOf('action_meetings_task_agent_absences') !== -1 ||
              action.indexOf('action_meetings_task_agent_admin') !== -1 ||
              action.indexOf('action_meetings_task_agent_manage') !== -1 ||
              action.indexOf('action_meetings_task_agent_booking') !== -1 ||
              action.indexOf('action_meetings_task_wizard_profile') !== -1 ) {
        app.init_backbone();
    } else if(action.indexOf('matchmaking') !== -1) {
        app.init_ext('matchmaking');
    } else if(action.indexOf('action_meetings_task_new_invited_user') !== -1) {
        app.init_ext('clean');
    } else if($('body').hasClass('action_meetings_task_user') || $('body').hasClass('action_meetings_task_upgrade')) {
        app.init_backbone();
    } else {
        app.init_ext();
    }

    dicole.meetings.subscribe_to_meeting_updates();
    dicole.meetings.show_dialogs();
    dicole.meetings.show_meeting_contents();
    dicole.meetings.preload_datas(['invite_participants_data']);
    dicole.meetings.show_container_content();
    if( window.meetings_tracker ) meetings_tracker.track( null, 'identify', dicole.get_global_variable('meetings_user_id') );


    var matchmaking_event_id = dicole.get_global_variable( 'meetings_matchmaker_matchmaking_event_id' );
    if ( matchmaking_event_id ) {
        dicole.event_source.subscribe(
            'matchmaking_changed',
            {
                limit_topics: [
                    [ "meetings_matchmaking_event:" + matchmaking_event_id ]
                ]
            },
            function(events) {
                dojo.forEach(events, function(e) {
                    dicole.meetings.show_matchmaking_calendar();
                });
            }
        );
    }

    dojo.connect(window, "onbeforeunload", function(event) {
        if (dojo.query('.inplace_editor_container').length == 1) {
            var confirmation_message = MTN.t('Are you sure you want to leave the page? Unsaved changes will be lost. Save changes by clicking the "Save" button below the editor.');
            // IE
            event.returnValue = confirmation_message;
            // Others
            return confirmation_message;
        }
    });
};
dojo.addOnLoad( initMeetings );

dicole.meetings.show_container_content = function() {
    dojo.forEach( [ 'matchmaking_lock_expired', 'matchmaking_limit_reached', 'matchmaking_calendar', 'matchmaking_success', 'matchmaking_list', 'matchmaking_register', 'matchmaking_validate', 'matchmaking_register_success', 'matchmaking_user_register_success', 'matchmaking_admin_editor' ], function( section ) {
        if ( dicole.get_global_variable( 'meetings_show_' + section ) ) {
            dicole.meetings[ 'show_' + section ]();
        }
    } );
};

dojo.subscribe("new_node_created", function(n) {

    dicole.uc_click_open_and_prepare_form( 'meetings', 'meeting_cancel', {
        width: 600,
        template_params : { },
        success_handler : dicole.meetings.open_meeting_cancel_success
    } );

    dicole.uc_click_open_and_prepare_form( 'meetings', 'meeting_cancel_or_reschedule', {
        width: 600,
        template_params : { },
        success_handler : dicole.meetings.open_meeting_cancel_or_reschedule_success
    } );

    dicole.uc_click_open_and_prepare_form( 'meetings', 'remove_self_from_meeting', {
        url : dicole.get_global_variable('meetings_remove_self_from_meeting_url'),
        template_params : { },
        success_handler : function( response ) {
            if( response.result && response.result.success ){
                dojo.publish('showcase.close');
                window.location = dicole.get_global_variable('meetings_summary_url') || '/';
            }
        }
    } );

    // Auto complete for meeting location
    dojo.query('.js_location_autocomplete', n).forEach( function( node ){
        var url = dicole.get_global_variable('meetings_location_autocomplete_url');
        if( url ){
            dojo.xhrPost({
                url: url,
                handleAs: "json",
                handle: function( response ){
                    if ( response.result ) {
                        var ac_array = response.result.data.split("^");
                        if( ac_array && ac_array.length ) {
                            $(node).suggestible({source : ac_array});
                        }
                    }
                }
            });
        }
    });

    // Clicking followup
    dojo.query('#js_create_followup', n).forEach( function( node ){
        dojo.connect( node, 'click', function( evt ) {
            evt.preventDefault();
            meetings_tracker.track(node); // Tracking

            // Fade out the meeting and show loader
            var meeting = dojo.byId('meeting');
            if( meeting ) {
                dojo.addClass( meeting, 'fade' );
                dojo.addClass( meeting, 'loader' );
            }
            node.innerHTML = MTN.t('Creating follow-up...');
            var url = dojo.attr( node , 'href' );
            if( url ){
                dojo.attr( node, 'href', '' );
                window.location = url;
            }
        });
    });

    // Show wiki double click edit tip
    dicole.ucq('js_meetings_inplace_page_container').forEach( function( node ) {
        var el = dojo.byId('js_edit_tip');
        if( el ) {
            dojo.connect( node, 'onmouseenter', function(e){
                dojo.style( el, 'display', 'block' );
            });
            dojo.connect( node, 'onmouseleave', function(e){
                dojo.style( el, 'display', 'none' );
            });
        }
    });

    dojo.query('.js_homescreensafe', n).forEach( function( node ){
        var href = dojo.attr(node, 'href');
        if ( href !== '' && href !== '#' ){
            dojo.connect( node, 'onclick', function( evt ) {
                if ( dicole.meetings.using_mobile ) {
                    evt.preventDefault();
                    window.location = href;
                }
            });
        }
    });

    dicole.mocc('js_meetings_login_with_facebook', n, function( node ) {
        dicole.meetings_common.login_with_facebook();
    } );

    dojo.query('#meetings_login_link_email_submit', n).forEach( function( submit ) {
        dojo.connect( submit, 'onclick', function( evt ) {
            meetings_tracker.track(submit); // Tracking
            dicole.meetings.submit_login_link_email( evt );
        } );
    } );

    if ( dicole.get_global_variable('meetings_login_error_message') ) {
        dojo.query('.js_meetings_login_error_message_container').forEach( function( container ) {
            var data = { result : { failure : dicole.get_global_variable('meetings_login_error_message') } };
            container.innerHTML = dicole.process_template( "meetings.login_return", data );
        } );
    }

    dojo.query('#meetings_login_link_email_input', n).forEach( function( input ) {
        dojo.connect( input, 'onkeydown', function( evt ) {
            if ( evt.keyCode==dojo.keys.ENTER ) {
                meetings_tracker.track(input); // Tracking
                dicole.meetings.submit_login_link_email( evt );
            }
        } );
    } );

    dicole.ucq('js_meetings_new_user_timezone_dropdown_container', n ).forEach( function( node ) {
        // Figure out what timezone needs to be passed to template
        var timezone = jstz.determine_timezone().name();

        if(! ( timezone && dicole.get_global_variable('meetings_timezone_data')[timezone] ) ){
           timezone = dicole.get_global_variable('meetings_user_timezone_fallback_name');
        }
        dicole.meetings_common.timezone_timer_override_values['meetings_new_user_time_preview'] = dicole.get_global_variable('meetings_timezone_data')[ timezone ];
        dicole.meetings_common.update_timezone_timers();
        dicole.meetings_common.publish_event( 'timezone_sniffed' );

        var params = { timezone_name : timezone,
                       timezone_choices : dicole.get_global_variable('meetings_timezone_choices'),
                       timezone_data : dicole.get_global_variable('meetings_timezone_data') };

        // Process template
        node.innerHTML = dicole.process_template('meetings.timezone_dropdown', params );

        // Hook change event & run chosen
        dicole.ucq('js_meetings_change_timezone', node ).forEach( function( select_node ) {
            $(select_node).chosen().change(function(){
                var option = select_node.options[select_node.selectedIndex];
                if ( option && option.value ) {
                    dicole.meetings_common.timezone_timer_override_values['meetings_new_user_time_preview'] = dicole.get_global_variable('meetings_timezone_data')[ option.value ];
                    dicole.meetings_common.update_timezone_timers();
                }
            });
        });
    });

    dicole.uc_prepare_form( 'meetings', 'new_user', { container : n } );

    // Hide comment controls for non touch devices and show on hover
    dicole.ucq('comment', n).forEach( function( element ) {
        var uagent = navigator.userAgent.toLowerCase();
           if ( ! ( uagent.search('iphone') > -1 ||
                   uagent.search('ipad') > -1 ||
                   uagent.search('ipod') > -1 ||
                   uagent.search('blackberry') > -1 ||
                   uagent.search('android') > -1 ) ){
            dojo.query( '.comment-controls', element ).forEach( function( elem ) {
                dojo.style( elem, 'display', 'none' );
            });

            dojo.connect( element, 'onmouseenter', function( evt ){
                dojo.query( '.comment-controls', element ).forEach( function( elem ) {
                    dojo.style( elem, 'display', 'block' );
                    dojo.fadeIn({ node: elem }).play();
                });
            });
            dojo.connect( element, 'onmouseleave', function(evt){
                dojo.query( '.comment-controls', element ).forEach( function( elem ) {
                    dojo.style( elem, 'display', 'none' );
                    dojo.fadeOut({ node: elem }).play();
                });
            });
        }
    });

    // Print material
    dicole.ucq('js_print_wiki', n ).forEach( function( element ) {
        dojo.connect( element, 'onclick', function( evt ) {
            evt.preventDefault();
            meetings_tracker.track(element); // Tracking
            dicole.print_element('#meeting-main-right');
        } );
    });

    // Select a previous meeting and show the materials for import
    dicole.ucq('js_previous_meeting', n ).forEach( function( element ) {
        dojo.connect( element, 'onclick', function( evt ) {
            evt.preventDefault();
            meetings_tracker.track(element); // Tracking

            dojo.query('.js_previous_meeting' ).forEach( function( nav_item ) {
                dojo.removeClass( nav_item, 'selected' );
            });
            dojo.addClass( element, 'selected' );

            var container = dojo.byId('js_previous_meeting_materials');
            container.innerHTML = '<img src="/images/meetings/ajax_loader.gif"/>';

            var url = element.href;
            dojo.xhrPost({
                encoding: 'utf-8',
                url: url,
                handleAs: "json",
                handle: function(response){
                    if( response.result ){
                        var node = dojo.byId('js_previous_meeting_materials');
                        node.innerHTML = dicole.process_template('meetings.add_material_previous_file_list', response.result );
                        dojo.publish("new_node_created", [ node ]);
                    }
                }
            });
        } );
    } );

    // Open and close general drop down containers
    dicole.ucq('js_hook_open_container', n).forEach( function ( node ) {
        dojo.connect( node, 'onclick', function (evt ) {
            evt.preventDefault();
            dojo.query('#' + node.id + '_container', n).forEach( function ( container_node ) {
                if ( dojo.hasClass(container_node, "container_closed") ) {
                    dojo.addClass(container_node,"container_open");
                    dojo.removeClass(container_node,"container_closed");

                    dojo.query('.js_arrow', node).forEach( function ( arrow_node ) {
                        dojo.addClass(arrow_node,"arrow-down");
                        dojo.removeClass(arrow_node,"arrow-right");
                    });
                }
                else {
                    dojo.addClass(container_node,"container_closed");
                    dojo.removeClass(container_node,"container_open");

                    dojo.query('.js_arrow', node).forEach( function ( arrow_node ) {
                        dojo.addClass(arrow_node,"arrow-right");
                        dojo.removeClass(arrow_node,"arrow-down");
                    });
                }
            });
        } );
    } );

    // Create a new meeting
    dicole.uc_click('js_meetings_new_meeting_open', function(){
        var createNew = function() {
            var url = dicole.get_global_variable("meetings_create_url");
            if( ! url ) return;
            $('#meeting, #summary').addClass('fade loader');
            dojo.xhrPost( {
                url : url,
                handleAs : 'json',
                load : function( response ) {
                    if(response.result.url_after_post){
                        window.location.href = response.result.url_after_post;
                    }
                    else{
                        // TODO: handle errors
                    }
                }
            } );
        };

        if( app.models.user && ! app.models.user.get('is_pro') && ! app.models.user.get('is_trial_pro') && ! app.models.user.get('is_free_trial_expired') ) {
            new app.sellProView({ mode : 'general_trial', model : app.models.user, callback : createNew });
        } else {
            createNew();
        }

    });

    // Open calendar instructions
    dicole.uc_click_fetch_open( 'meetings', 'ics_feed_instructions', {
        width : 800,
        container : n
    });

    dicole.mocc_form( 'create', n );
    dicole.mocc_form( 'create_popup', n );

    dicole.mocc_form( 'login', n, function( response ) {
        var pass = dojo.byId('login_password');
        if ( pass ) { pass.value = ''; }
    } );

    dicole.mocc( 'js_material_link', n, function( node ) {
        dicole.meetings.select_material( node );
    } );

    dicole.uc_prepare_form( 'meetings', 'resend_invite', { container : n, success_handler : function( response ) {
        dicole.meetings.add_message( MTN.t('Invite resent for %1$s', { params : [response.result.user_name] } ) , 'message');
        dojo.publish('showcase.close');
    } } );

    dicole.uc_prepare_form( 'meetings', 'remove_participant', { container : n, success_handler : function( response ) {
        dicole.meetings.add_message( MTN.t('%1$s has been removed succesfully', { params : [response.result.user_name] } )  , 'message');
        dicole.meetings.refresh_info();
        dojo.publish('showcase.close');
    } } );

    dicole.mocc_open_form( 'invite_transfer', n );

    dicole.mocc_open( 'add_material', n, 0, function() {
        // Hide guider & hook x to end guide
        if( dicole.meetings.guides.active ){
            guiders.hideAll();
            dicole.uc_click( 'js_end_guide_hook', function( node ) {
                dicole.meetings.guides.end_guide();
            });
        }

        setTimeout( function() { dicole.meetings.init_material_upload(); }, 10 );
    } );

    dicole.mocc_open('mobile_upload_instructions', n, 400);
    dicole.mocc_open('user_guide_menu', n, 400);
    dicole.mocc_open('user_guide', n, 740);
    dicole.mocc_open('user_guide_pro', n, 740);
    dicole.mocc_open('user_guide_email', n, 740);
    //dicole.mocc_open('admin_menu', n, 600);

    var select_material_handler = function( response ) {
        if ( response.result.set_selected_material_url ) {
            dicole.meetings.runtime_selected_material_url = response.result.set_selected_material_url;
            dicole.meetings.refresh_material_list( 0, 1, function() {
                dojo.publish('showcase.close');
                dojo.publish('showcase.close');
            } );

            // End guide
            if( dicole.meetings.guides.active ){
                dicole.meetings.guides.end_guide();
            }
        }
        else {
            location.reload(true);
        }
    };

    if( dicole.meetings.content_shown ) {
        dicole.ucq('js_autogrow' ).forEach( function( element ) {
            setTimeout( function(){
                dicole.meetings.autogrow( element );
            }, 2000 );
        });
    }

    dicole.uc_click_open_and_prepare_form( 'meetings', 'add_material_wiki', {
        container : n, success_handler : select_material_handler
    } );

    dicole.uc_click_fetch_open_and_prepare_form( 'meetings', 'add_material_previous', {
        container : n,
        width: 600,
        success_handler : select_material_handler,
        post_open_hook : function() {
            // Filter meetings list
            var search_field = dojo.byId( "js_filter_meetings" );
            dojo.connect(search_field, "onkeyup", null, function() {
                dicole.meetings.filter_meetings( search_field );
            });

            // Clear selected materials lists
            dicole.meetings.selected_previous_materials.splice(0,dicole.meetings.selected_previous_materials.length);

            var hidden_field = dojo.byId( "js_selected_materials_list" );
            dojo.attr( hidden_field, 'value', '' );
        }
    } );

    dicole.uc_click_fetch_open_and_prepare_form( 'meetings', 'rename_page', {
        container : n,
        width : 460,
        post_open_hook : function() {
            setTimeout(function(){
                $('input[name="title"]').focus();
            },100);
        },
        success_handler : function( response ) {
            dicole.meetings.refresh_material_list( 0, 1, function() {
                dojo.publish('showcase.close');
            } );
        }
    } );

    dicole.uc_click_fetch_open_and_prepare_form( 'meetings', 'rename_media', {
        container : n,
        post_open_hook : function() {
            setTimeout(function(){
                $('input[name="title"]').focus();
            },100);
        },
        success_handler : function( response ) {
            dicole.meetings.refresh_material_list( 0, 1, function() {
                dojo.publish('showcase.close');
            } );
        }
    } );

    dicole.uc_click_fetch_open_and_prepare_form( 'meetings', 'remove_page', {
        container : n,
        success_handler : function( response ) {
            dicole.meetings.refresh_material_list( 1, 0, function() {
                dojo.publish('showcase.close');
            } );
        }
    } );

    dicole.uc_click_fetch_open_and_prepare_form( 'meetings', 'remove_media', {
        container : n,
        width: 300,
        success_handler : function( response ) {
            dicole.meetings.refresh_material_list( 1, 0, function() {
                dojo.publish('showcase.close');
            } );
        }
    } );

    dicole.mocc_node_open_form( 'edit_media_embed', n );
    dicole.mocc_node_open_form( 'remove_meeting', n );
    dicole.mocc_node_open( 'replace_media', n, 460, function( result ) {
        var $input = $('#replace-upload');
        var $parent = $input.parent();
        var $progress_bar = $('.progress-bar', $parent);
        var $text = $('.progress-text', $parent);
        var file;
        var params = {
            paramname : 'file',
            maxNumberOfFiles : 1,
            dataType: 'json',
            formData : {
                user_id : app.auth.user,
                dic : app.auth.token,
                disable_thumbnail : 1,
                broken_ie : dicole.meetings.IEVersion() <= 9 ? 1 : 0 // Sets returned content type to text/html
            },
            maxfilesize:5000000 , // in mb
            url : app.defaults.api_host + '/v1/uploads',
            done : function(e,data){

                $progress_bar.css('width','100%');
                $text.text('Done');

                dojo.xhrPost( {
                    url : dicole.get_global_variable('meetings_replace_media_url'),
                    content : {
                        draft_id : data.result.result.upload_id,
                        prese_id : result.id
                    },
                    handleAs : 'json',
                    load : function( response ) {
                        dicole.meetings.refresh_material_list( 0, 1, function() {
                            dojo.publish('showcase.close');
                        } );
                    }
                } );
            },
            add: function (e, data) {
                file = data.files[0];
                $progress_bar.show();
                data.submit();
            },
            progressall: function(e, data) {
                var progress = parseInt(data.loaded / data.total * 100, 10);
                $progress_bar.css('width', progress + '%');
                $text.text( MTN.t('Uploading %1$s', [progress + '%']) );
            }
        };
        $input.fileupload( params );

    } );

    dicole.mocc_node_open_form( 'manage_virtual', n );

    dicole.mocc( 'js_set_time', n, function( node ) {
        // Hide guider
        if( dicole.meetings.guides.active ){
            guiders.hideAll();
        }
        dicole.uc_common_fetch_open( 'meetings', 'set_date', node, {
            container : n,
            width : 500,
            gather_override_template_params : function( handler, pkg, prefix, p ) {
                return handler( {
                    "initial_date_value" : dicole.get_global_variable('meetings_initial_date_value'),
                    "initial_time_value" : dicole.get_global_variable('meetings_initial_time_value'),
                    "initial_duration_hours_value" : dicole.get_global_variable('meetings_initial_duration_hours_value'),
                    "initial_duration_minutes_value" : dicole.get_global_variable('meetings_initial_duration_minutes_value')
                } );
            },
            post_open_hook : function() {
                dicole.uc_prepare_form( 'meetings', 'set_date', {
                    success_handler : function( data ) {
                        if ( data.result.ask_require_rsvp ) {
                            dicole.uc_common_open_and_prepare_form('meetings', 'set_date_confirm', {
                                submit_handler : function( data, handler ) {
                                    dojo.publish('showcase.close');
                                    dojo.byId('js_require_rsvp_asked_input').value = 1;
                                    dojo.byId('js_require_rsvp_input').value = data.require_rsvp ? 1 : 0;
                                    dojo.publish( 'meetings_set_date_submit' );
                                }
                            });
                        }
                        else {
                            if( dicole.meetings.guides.active ){
                                //guiders.next();
                            }

                            dojo.publish('showcase.close');
                            dicole.meetings.refresh_info();

                            // Reopen meeting edit menu if coming from there
                            if( n.id !== 'meeting-top' ){
                                dojo.publish('showcase.close');
                                dicole.click_element( dojo.byId('edit-meeting-open-button') );
                            }
                        }
                    }
                } );
            },
            pre_close_hook : function(){
                // Show next guider
                if( dicole.meetings.guides.active ){
                    guiders.show();
                }
            }
        } );
    } );

    // Change s2m location button
    dicole.ucq('js_change_location').forEach( function( node ) {
        var container  = dojo.byId('s2mresults');
        if( ! container ) return;
        dojo.connect( node, 'onclick', function( evt ) {
            meetings_tracker.track(node); // Tracking

            // Show search bar and change text
            var el = dojo.byId('location-search-wrapper');
            dojo.style( el, 'display', 'block' );
            var description = dojo.byId('s2m_description');
            var search_field = dojo.byId('s2m_location_input');
            search_field.focus();
            description.innerHTML = MTN.t('Search for a city or a location:');

            // Setup location search
            var timeout;
            dojo.connect( search_field, 'keyup', null, function(){
                var html = '';
                var locations_html = '';
                var cities_html = '';
                clearTimeout(timeout);
                timeout = setTimeout( function(){
                    var term = dojo.attr( search_field, 'value' );
                    container.innerHTML = '<table id="s2m-items"><tr class="heade"><td><p style="text-align:center;"><img src="/images/ajax_loader.gif" alt="loading"/></p></td></tr></table>';
                    dojo.xhrPost( {
                        url : dicole.get_global_variable('meetings_s2m_autocomplete_url'),
                        content : { term : term },
                        handleAs : 'json',
                        load : function( response ) {
                            dojo.forEach( response, function( item ) {
                                var temp_html = '<tr><td class="img"><div class="img-wrapper"><img src="/images/meetings/s2m_small_logo.png" alt="Seats2Meet"/></div></td><td class="info"><a href="'+item.ReservationUrl+'" class="title">' + dicole.encode_html(item.Name) + '</a><!--<span class="info"><i>' + dicole.encode_html(item.Distance) + ' km</i></span>--></td></tr>';
                                if( item.Category == 'City'){
                                    cities_html += temp_html;
                                }
                                else{
                                    locations_html += temp_html;
                                }
                            });
                            if( response.length === 0 ) {
                                html = '<tr class="header"><td>No results.</td></td>';
                            }
                            else{
                                if( locations_html !== '' ) {
                                    html += '<tr class="header"><td>Location(s):</td></tr>';
                                    html += locations_html;
                                }

                                if( cities_html !== '' ) {
                                    html += '<tr class="header"><td>Cities:</td></tr>';
                                    html += cities_html;
                                }
                            }
                            container.innerHTML = '<table id="s2m-items">' + html + '</table>';
                        }
                    });
                }, 300 );
            });
        });
    });

    // Assistive tech not wanted
    dicole.ucq('js_meeting_no_skype').forEach( function( node ) {
        dojo.connect( node, 'onclick', function( evt ) {
            meetings_tracker.track(node);
            dojo.publish('showcase.close');

            dojo.attr( dojo.byId('js_meeting_location'), 'value', 'Online' );
            dojo.attr( dojo.byId('js_meeting_clear_conferencing_option'), 'value', 1 );
            dicole.click_element( dojo.byId('set-location-submit') );
        });
    });

    // Assistive tech wanted
    dicole.ucq('js_meeting_teleconferecing_enable').forEach( function( node ) {
        dojo.publish('showcase.close');
        var lctView = new app.meetingLctView({
            model : app.models.meeting
        });
    });

    dicole.uc_click_fetch_open_and_prepare_form( 'meetings', 'set_location', {
        width: 755,
        container : n,
        post_fetch_pre_handle_hook : function( params ) {
            if ( ! params.geolocation_data ) {
                params.override_width = 520;
            }
        },
        post_open_hook : function() {
            if( dicole.meetings.guides.active ){
                guiders.hideAll();
            }
            var container  = dojo.byId('s2mresults');
            if( ! container ) return;

            // Fetch nearby locations
            var longitude = dojo.attr( dojo.byId('meetings_s2m_longitude'), 'value');
            var latitude = dojo.attr( dojo.byId('meetings_s2m_latitude'), 'value');
            container.innerHTML = '<p style="text-align:center;"><img src="/images/ajax_loader.gif" alt="loading"/></p>';
            dojo.xhrPost( {
                url : dicole.get_global_variable('meetings_s2m_query_url'),
                content : { longitude : longitude, latitude : latitude },
                handleAs : 'json',
                load : function( response ) {
                    var html = '';
                    dojo.forEach( response.result.location_list, function( el ) {
                        html += '<tr><td class="img"><div class="img-wrapper"><img src="/images/meetings/s2m_small_logo.png" alt="Seats2Meet"/></div></td><td class="info"><a href="'+dicole.encode_html(el.ReservationUrl)+'" class="title">' + dicole.encode_html(el.Name) + '</a><span class="info">' + dicole.encode_html(el.Address) + ', ' + dicole.encode_html(el.City) + ' - <i>' + dicole.encode_html(el.Distance) + ' km</i></span></td></tr>';
                    });
                    if( html === '' ) {
                        html = '<tr class="header"><td>';
                        html += MTN.t('No nearby locations found for %1$s people on %2$s.', { params : [response.result.participant_count, response.result.timespan_string] });
                        html += '</td></tr>';
                    }
                    container.innerHTML = '<table id="s2m-items">' + html + '</table>';
                }
            });
        },
        success_handler : function() {
            dojo.publish('showcase.close');
            dicole.meetings.refresh_info();

            if( dicole.meetings.guides.active ){
                //guiders.next();
            }

            // Handle case when coming from edit meeting menu
            if( n.id !== 'meeting-top' ){
                dojo.publish('showcase.close');
                dicole.click_element( dojo.byId('edit-meeting-open-button') );
            }
        },
        pre_close_hook : function(){
            // Show next guider
            if( dicole.meetings.guides.active ){
                guiders.show();
            }
        }
    } );

    dicole.uc_click_fetch_open_and_prepare_form( 'meetings', 'set_title', {
         post_fetch_pre_handle_hook : function( params ) {
            // Hide guide
            if( dicole.meetings.guides.active ){
                guiders.hideAll();
            }
         },
        //        width: 400,
        container : n,
        success_handler : function() {
            dojo.publish('showcase.close');
            dicole.meetings.refresh_info();

            if( dicole.meetings.guides.active ){
                //guiders.next();
            }

            if( n.id !== 'meeting-top' ){
                dojo.publish('showcase.close');
                dicole.clickElement( dojo.byId('edit-meeting-open-button') );
            }
        },
        pre_close_hook : function(){
            // Show nexts guider
            if( dicole.meetings.guides.active ){
                guiders.show();
            }
        }
    } );

    dojo.query('.js_previous_material_select', n).forEach( function( select ) {
        // Add checkmarks
        var id = dojo.attr( select, 'id' );
        if( dojo.indexOf( dicole.meetings.selected_previous_materials, id ) >= 0  ) {
            dojo.attr( select , 'checked' , true);
            dojo.attr( select , 'class' , 'selected');
        }

        // Handle clicks on materials to select / deselect
        dojo.connect( select, "onclick", null, function( event ) {
            var item = dojo.attr( select, 'id' );
            var count_change = 0;
            if(dojo.hasClass( select , 'selected' )){
                dojo.removeClass( select , 'selected' );
                for( var i = dicole.meetings.selected_previous_materials.length-1; i >= 0; i-- ){
                    if( dicole.meetings.selected_previous_materials[i] == item ){
                        dicole.meetings.selected_previous_materials.splice(i,1);
                    }
                }
                count_change = -1;
            }
            else{
                dojo.addClass( select , 'selected' );
                dicole.meetings.selected_previous_materials.push( item );
                count_change = 1;
            }

            // Update hidden field
            var hidden_field = dojo.byId( "js_selected_materials_list" );
            dojo.attr( hidden_field, 'value', dicole.meetings.selected_previous_materials.join() );

            // Update general counter
            var count = dicole.meetings.selected_previous_materials.length;
            var count_div = dojo.byId( "js_selected_materials_count" );
            count_div.innerHTML = count;

            // Update count per meeting
            var splitted_meeting_id = item.split( ':' );
            var meeting_id = splitted_meeting_id.reverse().pop();
            var counter = dojo.byId( meeting_id );
            if( counter.innerHTML === '' ) counter.innerHTML = 0;
            counter.innerHTML = parseInt( counter.innerHTML ) + count_change;
            if( counter.innerHTML == 0 ) counter.innerHTML = '';
        });
    });

    // Open participants open
    dicole.ucq( "js_meetings_invite_participants_open", n ).forEach(function(node) {
        dojo.connect(node, "onclick", null, function(evt) {
            evt.preventDefault();
            meetings_tracker.track(node);
            // Hide guide
            if( dicole.meetings.guides.active ){
                guiders.hideAll();
            }
            dicole.uc_common_open_and_prepare_form( 'meetings', 'invite_participants', {
                'width' : 800,
                'vertical_align' : 'top',
                'template_params' : {},
                'success_handler' : function(response){
                    if ( response.result.meeting_is_a_draft && response.result.draft_participants_added !== '' ) {
                        dicole.meetings.add_message( MTN.t('Added following pending users: %1$s', [ response.result.draft_participants_added ] ) , 'message');
                        dicole.meetings.refresh_info();
                        dojo.publish('showcase.close');
                    } else if( response.result.users && response.result.users !== '' ) {
                        dicole.meetings.invite_customize_message_open('normal', response.result.users);
                    } else {
                        // Show error for no people
                        var error_container = dojo.byId('token-list-wrapper');
                        dojo.place('<p id="add-people-error" class="error">'+MTN.t('You need to add people.')+'</p>', error_container );
                        setTimeout(function(){ dojo.destroy(dojo.byId('add-people-error'));}, 2500);
                        dojo.query('#invite-participants-submit .indicator').forEach(function(indicator){
                            dojo.removeClass( indicator, 'working' );
                        });
                    }
                },
                'pre_post_interceptor' : function() {
                    // NOTE: The input value is a array in string form, so we eval it here =)
                    var invitees = dicole.meetings.ab.addressBook("getUsers");
                    var invitees_count = 0;
                    if( invitees ) invitees_count = invitees.length;

                    // Get existing participants
                    var existing = app.models.meeting.get('participants') ? app.models.meeting.get('participants').length : 1;

                    // Complain if adding more than six for non pro users
                    if( invitees_count + existing > 6 && ! app.models.user.get('is_pro') ) {
                        new app.sellProView({ mode : 'invite', model : app.models.user });
                        return false;
                    } else if( ! app.models.meeting.get('is_draft') ) {
                        dicole.meetings.invite_customize_message_open('normal', invitees);
                        return false;
                    }

                    return true;
                },
                'post_open_hook' : function() {

                    if( dicole.meetings.data.invite_participants_data ){

                        var user_data_list = dicole.meetings.remove_current_meeting_users_from_data( dicole.meetings.data.invite_participants_data.user_data_list );
                        dicole.meetings.ab = $('#invited-users-list').addressBook({
                            'users': user_data_list,
                            'meetings': dicole.meetings.data.invite_participants_data.meeting_data_list
                        });
                    }
                    else{
                        dicole.meetings.ab = $('#invited-users-list').addressBook();
                        dojo.xhrPost({
                            encoding: 'utf-8',
                            url: dicole.get_global_variable('meetings_invite_participants_data_url'),
                            handleAs: "json",
                            handle: function(response){
                                if(response.result){
                                    dicole.meetings.data.invite_participants_data = response.result;
                                    var user_data_list = dicole.meetings.remove_current_meeting_users_from_data( dicole.meetings.data.invite_participants_data.user_data_list );
                                    if( dicole.meetings.ab){
                                        dicole.meetings.ab.addressBook( "updateDataOnce", { 'users' : user_data_list, 'meetings' : dicole.meetings.data.invite_participants_data.meeting_data_list });
                                    }
                                }
                            }
                        });
                    }

                    if( dicole.get_global_variable( 'meetings_open_addressbook' ) ) {
                        dicole.meetings.ab.addressBook("showAddressArea");
                    }
                },
                pre_close_hook : function() {
                    if( dicole.meetings.guides.active ){
                        guiders.show();
                    }
                }
            } );
        });
        // TODO: Remove this hack
        dojo.publish('uc_js_meetings_invite_participants_open_processed', [ node, {} ] );
    });

    dicole.uc_click( 'js_meetings_invite_customize_message_open', function( node ) {
        dicole.meetings.invite_customize_message_open();
    });

    dicole.uc_click_fetch_open_and_prepare_form( 'meetings', 'edit_my_profile', {
        'width' : 600,
        'override_template_params' : { prefix : 'edit_my_profile' },
        'post_open_hook' : function(){
            dicole.meetings.init_upload(134,134, '#profile-upload', '#edit_my_profile_photo_draft_id', '#edit_my_profile_photo_image' );
        },
        'success_handler' : function( send_response ) {
            location.reload(true);
        }
    });

    dicole.uc_click_fetch_open_and_prepare_form( 'meetings', 'edit_my_profile_new_user', {
        'width' : 600,
        'override_template_params' : { prefix : 'edit_my_profile_new_user' },
        'post_open_hook' : function(){
            dicole.meetings.init_upload(134,134, '#profile-upload', '#edit_my_profile_photo_draft_id', '#edit_my_profile_photo_image' );
        },
        'success_handler' : function( send_response ) {
            if( send_response.result.send_now === 1 ) {
                dojo.publish('showcase.close');
                open_customize(send_response.result);
                dicole.meetings.refresh_top();
            }
            else {
                window.location = send_response.result.url_after_post;
            }
        }
    });

    dicole.mocc_node_open( 'show_user', n, 500, function( data ) {
        // Manager status switch
        dicole.ucq( "js_meetings_change_manager_status_switch" ).forEach(function(node) {
            dojo.connect(node, "onclick", null, function(evt) {
                evt.preventDefault();
                meetings_tracker.track(node);
                dojo.xhrPost( {
                    url : data.change_manager_status_url,
                    content : { is_manager : dojo.hasClass(node, "off-position") ? 1 : 0 },
                    handleAs : 'json',
                    load : function( response ) {
                        if ( response && response.result ) {
                            if(dojo.hasClass(node,'on-position')){
                                dojo.removeClass(node,'on-position');
                                dojo.addClass(node,'off-position');
                            }
                            else{
                                dojo.removeClass(node,'off-position');
                                dojo.addClass(node,'on-position');
                            }
                        }
                    }
                });
            });
        });
        var create_rsvp = function( container ) {
            container.innerHTML = dicole.process_template("meetings.rsvp_profile", data );
            dojo.query('.js_set_rsvp_true', container).forEach( function( el ) {
                dojo.connect( el, 'onclick', function(e){
                    e.preventDefault();
                    set_rsvp_state('yes' , container);
                    meetings_tracker.track(el);
                });
            });
            dojo.query('.js_set_rsvp_false', container).forEach( function( el ) {
                dojo.connect( el, 'onclick', function(e){
                    e.preventDefault();
                    set_rsvp_state('no' , container);
                    meetings_tracker.track(el);
                });
            });

        };

        var set_rsvp_state = function( state, container ) {
            dojo.query( 'p.rsvp', container ).forEach( function(el) {
                el.innerHTML = el.innerHTML + ' ' + MTN.t('Saving...');
            });
            var content = '';
            var url = '';
            if( data.draft_object_id ){
                url = dicole.get_global_variable('meetings_set_draft_user_rsvp_url');
                content = { rsvp_status: state, draft_object_id : data.draft_object_id };
            }
            else{
                url = dicole.get_global_variable('meetings_set_user_rsvp_url');
                content = { rsvp_status: state, user_id : data.user_id };
            }
            dojo.xhrPost({
                url : url,
                handleAs : 'json',
                content : content,
                load : function( response ) {
                    if ( response.result ) {
                        data.rsvp = response.result.rsvp_status;
                        create_rsvp(container);
                    }
                    else{
                        // error
                    }
                }
            });
        };

        // RSVP
        dojo.query('.rsvp-container').forEach( function( container ){
            create_rsvp(container);
        });

    });

    // Show / hide comment posting button
    dicole.ucq( "inplace_chat_input", n ).forEach(function(node) {
        var buttons = dojo.query('.publish-button');
        var wrappers = dojo.query(".inplace-chat-input-wrapper");
        dojo.connect(node, "focus", null, function(evt) {
            dojo.forEach( buttons, function( button) {
                dojo.fx.wipeIn({ node : button }).play();
            });
            dojo.forEach( wrappers, function( wrapper) {
                dojo.removeClass( wrapper, 'iciw-closed');
                dojo.addClass( wrapper, 'iciw-open');
            });
        });
        dojo.connect(node, "blur", null, function(evt) {
            if( ( dojo.attr( node, 'value' ) !== '' ) ) return;
            dojo.forEach( buttons, function( button) {
                var animation = dojo.fx.wipeOut({ node : button });
                dojo.connect(animation, "onEnd", function(){
                    dojo.forEach( wrappers, function( wrapper) {
                        dojo.removeClass( wrapper, 'iciw-open');
                        dojo.addClass( wrapper, 'iciw-closed');
                    });
                });
                animation.play();
            });
        });
    });

    dicole.ucq( "js_meetings_send_emails_change", n ).forEach(function(node) {
        dojo.connect(node, "onclick", null, function(evt) {
            meetings_tracker.track(node); // Tracking
            dojo.xhrPost( {
                url : dicole.get_global_variable('meetings_send_emails_change_url'),
                content : { send_emails : dojo.hasClass(node, "off-position") ? 1 : 0 },
                handleAs : 'json',
                load : function( response ) {
                    if(dojo.hasClass(node,'on-position')){
                        dojo.removeClass(node,'on-position');
                        dojo.addClass(node,'off-position');
                    }
                    else{
                        dojo.removeClass(node,'off-position');
                        dojo.addClass(node,'on-position');
                    }
                }
            } );
        });
    });

    dicole.ucq( "js_meetings_edit_page_embed_dblclick_open", n).forEach( function ( node ) {
        var href = dojo.attr(node, 'data-edit-href');
        dojo.connect( node, "ondblclick", function ( evt ) {
            if (href && dojo.query('.inplace_editor_container').length !== 1) {
                dicole.meetings.open_wiki_editor( href );
            }
        });
    });

    dicole.mocc( "js_meetings_edit_page_embed_open", n, function( node ) {
        // Hide guide
        if( dicole.meetings.guides.active ){
            guiders.hideAll();
        }
        dicole.meetings.open_wiki_editor( node.href );
    } );

    dicole.mocc( "js_meetings_continue_page_embed_open", n, function( node ) {
        dojo.xhrPost( {
            "url" : node.href,
            "handleAs" : 'json',
            "load" : function( response ) {
                if ( response && response.result ) {
                    dicole.meetings.init_page_edit( response.result, 'continue' );
                }
            }
        } );
    } );


    dojo.forEach( [ 'meetings_summary_meetings', 'meetings_summary_changes' ], function( id ) {
        dicole.meetings.init_paged_list_controls( id, n );
    } );

    dicole.ucq( "js_dmy_datepicker_input", n).forEach( function ( node ) {
        // Clear previous FD so that DatePicker does not die
        dojo.query("#fd-" + node.id ).forEach( function( fd ) {
            dojo.destroy( fd );
        } );

        var h = {};
        h[ node.id ] =  "%Y-%m-%d";
        datePickerController.createDatePicker( {
            positioned : 'js_dmy_datepicker_' + node.id + '_open_container',
            formElements: h
        });

        dojo.connect( node, "onfocus", function ( evt ) {
            datePickerController.show( node.id );
        } );
    });

    var check_promo_code = function() {
        dojo.xhrPost({
            url: dicole.get_global_variable('meetings_check_promo_code_url'),
            content: { promo_code: dojo.byId('promo_code').value },
            handleAs: 'json',
            handle: function(response) {
                if (response && response.result) {
                    var description = response.result[0].description;
                    var value = response.result[0].value;

                    dojo.byId('promo_label').innerHTML = description;
                    dojo.byId('promo_value').value = value;
                    dojo.byId('promo_value').checked = true;

                    dojo.style(dojo.byId('js_promo_option'), 'display', 'block');
                }
            }
        });
    };
});

// Calculate counts for answers
dicole.meetings.calculate_positive_proposal_answer_counts = function( n ) {
    dojo.query( ".js_meetings_positive_answer_count", n ).forEach(function(node) {
        var count = 0;
        propo_id = dojo.attr( node, 'data-proposal-id' );
        dojo.query('.answer_slot').forEach(function(answer_cell) {
            if( dojo.attr( answer_cell, 'data-proposal-id' ) == propo_id && dojo.hasClass( answer_cell, 'yes' ) ) count++;
        });
        node.innerHTML = count;
    });
};

dicole.meetings.autogrow = function( element, delay ) {
    var d = delay ? delay : '500';

    // Fix height measurement for IE7, IE6
    if( dojo.isIE < 8 ) {
        element.style.width = element.offsetWidth + 'px';
    }

    element.style.resize = 'none';
    element.style.overflow = 'hidden';

    var tVal = element.value;
    element.style.height = '0px';
    element.value = "W\nW\nW";
    var H3 = element.scrollHeight;
    element.value = "W\nW\nW\nW";
    var H4 = element.scrollHeight;
    var H = H4 - H3;
    element.value = tVal;
    tVal = null;

    var container = dojo.create("div", { id: "autogrow_" + dojo.attr( element, 'id' ) }, element, 'before');
    container.style.padding = '0px';
    container.style.margin = '0px';

    dojo.place( element, container );

    var update_height = function(){
        if (tVal != element.value ){
            tVal = element.value;
            element.style.height = '1px';
            var tH = element.scrollHeight; // removed '+ H' to make this work on single line
            if(tH === 0) tH = 18;
            element.style.height = tH + 'px';
            container.style.height = 'auto';
            var cH = container.offsetHeight || 18;
            container.style.height = cH  + 'px';
        }
    };

    element.interval = '';
    dojo.connect( element, 'focus', function( evt ) {
        element.interval = window.setInterval(function(){
            update_height();
        }, d);
    });

    dojo.connect( element, 'blur', function( evt ) {
        clearInterval(element.interval);
        element.timeout = window.setTimeout(function(){
            update_height();
        }, d );
    });

    update_height();
};

dicole.meetings.selected_previous_materials = [];

dicole.meetings.using_mobile = false;
dicole.meetings.check_browsers = function( ) {
    var ua = navigator.userAgent;
    var checker = {
      iphone: ua.match(/(iPhone|iPod|iPad)/),
      blackberry: ua.match(/BlackBerry/),
      android: ua.match(/Android/)
    };

    if( checker.iphone || checker.android || checker.blackberry ) {
        $('meeting-mobile-sharing').show(); // Show mobile share instructions
        dicole.meetings.using_mobile = true;
    }

    var IEVer = dicole.meetings.IEVersion();

    // Warn about old browsers
    if( IEVer < 9 ){
        $('#content-wrapper').prepend(templatizer.browserWarning());
    }
};

dicole.meetings.IEVersion = function(){
    // http://james.padolsey.com/javascript/detect-ie-in-js-using-conditional-comments/
    var undef,
    v = 3,
    div = document.createElement('div'),
    all = div.getElementsByTagName('i');
    while (
        div.innerHTML = '<!--[if gt IE ' + (++v) + ']><i></i><![endif]-->',
            all[0]
    );
    return v > 4 ? v : undef;
};

dicole.meetings.refresh_material_adding = function( first_load ) {
    if ( first_load ) {
        app.views.material_uploader.render();
    }
    else {
        dojo.xhrPost( {
            url : dicole.get_global_variable('meetings_get_info_url'),
            handleAs : 'json',
            load : function( data ) {
                if ( data && data.result ) {
                    dicole.set_global_variable('meetings_user_can_add_material', data.result.user_can_add_material );
                    dicole.set_global_variable('meetings_short_email', data.result.short_email );
                    app.views.material_uploader.render();
                }
            }
        } );
    }
};

dicole.meetings.invite_customize_message_open = function(mode, invitees) {
    var showcase = dicole.create_showcase({
        "disable_close" : true,
        "width" : 650,
        "content" : dicole.process_template("meetings.invite_customize_message", $.extend({ invitees : invitees, mode : mode }, app.models.meeting.toJSON() ))
    });

    // Init tinymce if draft meeting
    if( app.models.meeting.get('is_draft') ) {
        setTimeout( function() {
            tinyMCE.init( {
                menubar : false,
                statusbar : false,
                selector : '.js_invite_agenda_editor',
                language : dicole.get_global_variable('meetings_lang'),
                width: '100%',
                height : 220,
                plugins : 'autolink,paste',

                toolbar1 : 'bold italic underline strikethrough | forecolor backcolor | formatselect | bullist numlist | removeformat',

                content_css : '/css/tinymce.css',

                paste_create_paragraphs : true,
                paste_create_linebreaks : false,
                paste_strip_class_attributes : 'all',
                paste_auto_cleanup_on_paste : true
            } );
        },500);
    }

    // Run new node created, so we hook default show case closing classes etc
    dojo.publish("new_node_created", [ showcase.nodes.wrapper ]);

    $(showcase.nodes.wrapper).on('click', '.js_send_invites', function(e) {
        e.preventDefault();

        var button = new app.helpers.activeButton(e.currentTarget);

        // Case draft meeting
        if( app.models.meeting.get('is_draft') ) {

            var data = {
                agenda : tinyMCE.activeEditor.getContent(),
                title : $('#confirm-title').val(),
                require_rsvp : $('#confirm-rsvp').is(':checked') ? 1 : 0
            };

            $.post('/apigw/v1/meetings/'+app.models.meeting.get('id')+'/send_draft_participant_invites', data, function(res) {
                button.setDone();
                dicole.meetings.refresh_info();
                dicole.meetings.refresh_material();
                dojo.publish('showcase.close');

                if( mode === 'matchmaking' ) {
                    dicole.meetings.add_message( MTN.t('Meeting confirmed'), 'message');
                    $('#meeting').removeClass('fade');
                }

            });

            // IF MATCHMAKING
            // MAYBE TODO: Post to meeting that matchmaking is accepted
            // matchmakign_accepted = 1


        } else if( invitees && invitees.length ) {

            var promises = [];
            var require_rsvp = $('#confirm-rsvp').is(':checked') ? 1 : 0;
            _.each(invitees, function(i) {
                // Remove link to element and add rsvp requirement
                delete i.element;
                i.require_rsvp = require_rsvp;

                promises.push( $.post('/apigw/v1/meetings/'+app.models.meeting.get('id')+'/participants/', i));
            });
            $.when.apply($, promises).then(function() {
                button.setDone();
                dicole.meetings.refresh_info();
                dojo.publish('showcase.close');
                dojo.publish('showcase.close');
            });

        }
    });
};


dicole.meetings.show_dialogs = function() {

    if (dicole.get_global_variable( 'meetings_open_language_selector' )) {
        window.location.href = '/meetings/user/settings/regional';
        return;
    }

    if( dicole.get_global_variable( 'meetings_open_promo_subscribe' ) ) {
        new app.sellProView({ mode : 'trial_ending', model : new app.userModel({ id : dicole.get_global_variable('meetings_user_id') }) });
    }

    if( dicole.get_global_variable( 'meetings_open_addressbook' ) ) {
        var open_ab = function(){
            setTimeout( function(){
                dicole.click_element( dojo.byId('invite-participants-open-button') );
            },250);
        };

        var ab_button = dojo.byId('invite-participants-open-button');
        if( ab_button && dojo.hasClass( ab_button, 'js_meetings_invite_participants_open_processed' ) ){
            open_ab();
        }
        else{
            var sub = dojo.subscribe('uc_js_meetings_invite_participants_open_processed', function(){
                open_ab();
                dojo.unsubscribe( sub );
            });
        }
    }
    if( dicole.get_global_variable( 'meetings_show_followup_helpers' ) ) {
        dicole.meetings.guides.start();
    }

    if( dicole.get_global_variable( 'meetings_open_addressbook_with_guiders' ) ) {
        var open_ab = function(){
            setTimeout( function(){
                dicole.click_element( dojo.byId('invite-participants-open-button') );
            },250);
        };

        dicole.meetings.guides.start();

        var ab_button = dojo.byId('invite-participants-open-button');
        if( ab_button && dojo.hasClass( ab_button, 'js_meetings_invite_participants_open_processed' ) ){
            open_ab();
        }
        else{
            var sub = dojo.subscribe('uc_js_meetings_invite_participants_open_processed', function(){
                open_ab();
                dojo.unsubscribe( sub );
            });
        }
    }

    if( dicole.get_global_variable( 'meetings_open_set_location_data_url' ) ) {
        var open_set_location = function(){
            dicole.click_element( dojo.byId('js_set_location') );
        };

        var location_button = dojo.byId('js_set_location');
        if( location_button && dojo.hasClass( location_button, 'js_meetings_set_location_open_processed' ) ){
            open_set_location();
        }
        else{
            var sub = dojo.subscribe('uc_js_meetings_set_location_open_processed', function(){
                open_set_location();
                dojo.unsubscribe( sub );
            });
        }
    }

    if( dicole.get_global_variable('meetings_show_new_meeting') ) {
        var container3 = dojo.byId("js_new_meeting_container");
        if( container3 ) {
            var params = {
                "topic" : dicole.get_global_variable('meetings_initial_topic_value'),
                "initial_date_value" : dicole.get_global_variable('meetings_initial_date_value'),
                "initial_time_value" : dicole.get_global_variable('meetings_initial_time_value'),
                "initial_duration_hours_value" : dicole.get_global_variable('meetings_initial_duration_hours_value'),
                "initial_duration_minutes_value" : dicole.get_global_variable('meetings_initial_duration_minutes_value'),
                "show_tos" : dicole.get_global_variable('meetings_show_new_meeting_tos'),
                "new_user_email" : dicole.get_global_variable('meetings_new_user_email')
            };
            container3.innerHTML = dicole.process_template( "meetings.new_meeting", params );
            dojo.publish("new_node_created", [ container3 ]);
        }
    }

    if( dicole.get_global_variable('meetings_meeting_cancel_open') ) {
        dicole.set_global_variable('meetings_meeting_cancel_open', 0);
        dicole.meetings.open_meeting_cancel();
    }

    if( dicole.get_global_variable('meetings_meeting_reschedule_open') ) {
         dicole.set_global_variable('meetings_meeting_reschedule_open', 0);
         dicole.meetings.open_meeting_cancel_or_reschedule();
    }
};

dicole.meetings.subscribe_to_meeting_updates = function() {
    var meeting_id = dicole.get_global_variable('meetings_meeting_id');
    if ( meeting_id ) {

        dicole.meetings.refresh_material_adding(1);
        dicole.event_source.subscribe( 'material_adding_changes',
                                      {
                                          "limit_topics": [
                                              [ "meeting:" + meeting_id, 'class:meetings_participant_rights_changed']
                                          ]
                                      },
                                      function() { dicole.meetings.refresh_material_adding(); }
                                     );

        // meeting changed is needed as scheduling discussion might disappear or appear
        dicole.meetings.refresh_material_list(1);
        dicole.event_source.subscribe( 'material_changes',
                                      {
                                          "limit_topics": [
                                              [ "meeting:" + meeting_id, 'class:meetings_participant_rights_changed'],
                                              [ 'meeting:' + meeting_id, 'class:meetings_meeting_changed' ],
                                              [ "meeting:" + meeting_id, 'class:meetings_material' ],
                                              [ "meeting:" + meeting_id, 'class:meetings_comment' ]
                                          ]
                                      },
                                      function() { dicole.meetings.refresh_material_list(); }
                                     );

        dicole.meetings.refresh_info(1);
        dicole.event_source.subscribe( 'info_changes',
                                      {
                                          limit_topics: [
                                              [ "meeting:" + meeting_id, 'class:meetings_participant_rights_changed' ],
                                              [ 'meeting:' + meeting_id, 'class:meetings_meeting_changed' ],
                                              [ 'meeting:' + meeting_id, 'class:meetings_participant' ]
                                          ]
                                      },
                                      function() { dicole.meetings.refresh_info(); }
                                     );

        dicole.event_source.subscribe( 'content_count_changes',
                                      {
                                          "limit_topics": [
                                              [ "meeting:" + meeting_id, 'class:meetings_material' ],
                                              [ "meeting:" + meeting_id, 'class:meetings_comment' ]
                                          ]
                                      },
                                      function() {}
                                     );

        // TODO: handle refreshes and removal within the initial gap
        dicole.event_source.subscribe('removed_from_meeting',
                                      {
                                          limit_topics: [
                                              [ "meeting:" + meeting_id, 'class:meetings_participant_removed' ]
                                          ]
                                      },
                                      function(events) {
                                          dojo.forEach(events, function(e) {
                                              if (e.data.user_id && e.data.user_id == dicole.get_global_variable('auth_user_id')) {
                                                  window.location = dicole.get_global_variable('meetings_removed_from_meeting_url');
                                              }
                                          });
                                      }
                                     );

    }
};


dicole.meetings.init_chosen = function( select_node, handler ) {
    if( ! handler ) {
        handler = function( data ) {
            if( data.result.success ){
                window.location = dicole.get_global_variable('meetings_scheduler_refresh_url');
            }
        };
    }

    if( select_node && ! dojo.hasClass(select_node, 'chzn-done') ) {
        $(select_node).chosen().change(function(){
            var option = select_node.options[ select_node.selectedIndex ];
            if ( option && option.value ) {
                dojo.xhrPost({
                    encoding: 'utf-8',
                    content : { timezone : option.value },
                    url: dicole.get_global_variable('meetings_change_timezone_url'),
                    handleAs: "json",
                    handle: handler
                });
            }
        });
    }
};

dicole.meetings.content_shown = false;

dicole.meetings.show_meeting_contents = function(fadein) {

    var container = dojo.byId('meeting-main');
    if( container ) {
        if(fadein){
            dojo.style( container, 'display', 'inline' );
            dojo.style( container, 'opacity', '0' );
            dojo.fadeIn({ node: container }).play();
        }
        else{
            dojo.style( container, 'opacity', '100' );
            dojo.style( container, 'display', 'inline' );
        }
    }

    var chooser_container = dojo.byId( 'action-chooser-wrapper' );
    if( chooser_container ) {
        if(fadein){
            dojo.style( chooser_container, 'height', '0px' );
            dojo.style( chooser_container, 'display', 'block' );
            dojo.fx.wipeIn( { node: chooser_container } ).play();
        }
        else{
            dojo.style( chooser_container, 'display', 'block' );
        }
    }

    dicole.meetings.content_shown = true;
};

dicole.meetings.hide_meeting_contents = function(fadeout) {

    var container = dojo.byId('meeting-main');
    if( container ) {
        if(fadeout){
            dojo.fadeOut({ node: container, onEnd : function() {
                dojo.style( container, 'display', 'none' );
            } }).play();
        }
        else{
            dojo.style( container, 'display', 'none' );
        }
    }

    var chooser_container = dojo.byId( 'action-chooser-wrapper' );
    if( chooser_container ) {
        if(fadeout) {
            dojo.fx.wipeOut({ node: chooser_container, onEnd : function() {
                dojo.style( chooser_container, 'display', 'none' );
            } }).play();
        }
        else {
            dojo.style( chooser_container, 'display', 'none' );
        }
    }

    dicole.meetings.content_shown = false;
};

dicole.meetings.refresh_info = function( force_rebuild ) {
    dicole.meetings.refresh_top(  force_rebuild );
};

dicole.meetings.refresh_top_hash = '';
dicole.meetings.refresh_top = function( force_rebuild ) {
    app.models.meeting.fetch({ success : function( m, r ) {

        // Add missing param for backwards compatibility
        r.draft_participant_count = _.filter(r.participants, function(o) { return !! o.draft_object_id; }).length;
        r.participant_count = _.filter(r.participants, function(o) { return ! o.draft_object_id; }).length;
        r.create_followup_url = dicole.get_global_variable('meetings_create_followup_url');

        var user = _.find( app.models.meeting.get('participants'), function(o){ return o.user_id == app.auth.user; });

        user.id = user.user_id; // Override wrong type of id

        // Update user model
        app.models.user.set(user);

        app.models.meeting.set('is_manager', parseInt(app.models.user.get('is_manager')) ? true : false );
        app.views.meeting_top.render();
        dojo.publish("new_node_created", [ app.views.meeting_top.el ]); // Ensure backward compatibility

        // Update page title
        if( r.title && r.title !== '' ) {
            document.title = r.title +' | Meetin.gs';
        }

        // Update globals for backwards compatibility
        dicole.set_global_variable('meetings_meeting_title', r.title );
        dicole.set_global_variable('meetings_begin_date_epoch', r.begin_epoch );
        dicole.set_global_variable('meetings_duration', r.end_epoch ? r.end_epoch - r.begin_epoch : 0 );
        dicole.set_global_variable('meetings_skype_uri', r.skype_uri );
        dicole.set_global_variable('meetings_hangout_uri', r.hangout_uri );
        dicole.set_global_variable('meetings_hangout_organizer_uri', r.hangout_organizer_uri );
        dicole.set_global_variable('meetings_custom_uri', r.custom_uri );
        dicole.set_global_variable('meetings_skype_is_organizer', r.skype_is_organizer );
        dicole.set_global_variable('meetings_join_password', r.join_password );
        dicole.set_global_variable('meetings_join_guide_url', r.join_guide_url );

        // This is not in top, but hey.. :P
        var node = dojo.byId('meeting-meeting-cancel-container');

        var cancel_html = ( r.cancelled_epoch == 0 && r.allow_meeting_reschedule ) ? '<p class="meeting_cancel_link"><a href="#" class="js_meetings_meeting_cancel_or_reschedule_open">'+MTN.t('Cancel meeting?')+'</a></p>' : ( r.cancelled_epoch == 0 && r.allow_meeting_cancel ) ? '<p class="meeting_cancel_link"><a href="#" class="js_meetings_meeting_cancel_open">'+MTN.t('Cancel meeting?')+'</a></p>' : '';

        cancel_html += ( app.models.meeting.get('is_manager') && r.cancelled_epoch == 0 && r.express_manager_set_date ) ? '<p class="meeting_cancel_link"><a href="#" class="js_set_time">'+MTN.t('Change date')+'</a></p>' : '';

        node.innerHTML = cancel_html;
        dojo.publish("new_node_created", [ node ]);

        // Next action view
        var container = dojo.byId('next-action');

        var d = new Date();

        dicole.meetings.update_conferencing_bar();

        // NEXT ACTION
        if( ! dicole.get_global_variable('meetings_open_set_location_data_url') &&
           ! dicole.get_global_variable('meetings_open_addressbook') &&
               ! dicole.get_global_variable('meetings_open_customize_message_data_url') &&
                   ! dicole.get_global_variable('meetings_open_set_location_data_url') &&
                       ! dicole.get_global_variable('meetings_disable_template_chooser') &&
                           dicole.get_global_variable('meetings_template_chooser_url') &&
                               dicole.get_global_variable('meetings_is_creator') == 1 &&
                                       r.begin_date === "" &&
                                           ( r.participants  && r.participants.length <= 1 ) &&
                                               ! r.title_value ) {
            dicole.meetings.show_template_chooser(container);
        }
        else if( ! r.matchmaking_accepted ) {
            dicole.meetings.show_matchmaking_bar( r.matchmaking_requester_name, r.matchmaking_event_name );
            if( dicole.get_global_variable('meetings_matchmaking_accept_open')){
                dicole.set_global_variable('meetings_matchmaking_accept_open', 0);
                dicole.meetings.invite_customize_message_open('matchmaking');
            }
        }
        else if( r.is_draft ) {
            container.innerHTML = dicole.process_template("meetings.next_action_bar", { type : 'ready_button', params : r });
            $(container).show();
            dojo.publish("new_node_created", [ container ]);
        }
        else if( r.create_followup_url && parseInt(r.begin_epoch) && parseInt(r.end_epoch) < ( d.getTime() / 1000 )  ) {
            container.innerHTML = dicole.process_template("meetings.next_action_bar", { type : 'followup', params : r });
            $(container).show();
            dojo.publish("new_node_created", [ container ]);
        }
        else if( app.models.user.get('rsvp_required') && app.models.user.get('rsvp_status') === '' ) {
            dicole.meetings.show_rsvp_bar( container );
        }
        else if( dicole.get_global_variable('meetings_dismiss_new_user_guide_url') &&
                ! dicole.get_global_variable('meetings_is_creator') &&
               ! dicole.meetings.guides.active ) {
            dicole.meetings.show_participant_tutorial_bar(container);
        }
        else {
            container.innerHTML = '';
        }
    }});
};

dicole.meetings.show_matchmaking_bar = function( requester_name, event_name ) {
    var container = dojo.byId('next-action');
    container.innerHTML = templatizer.meetingNextAction( { type : 'matchmaking', requester_name : requester_name, event_name : event_name } );
    dojo.style( container, 'display', 'block' );

    dojo.connect( dojo.byId('js_accept_matchmaking'), 'click', function(e){
        e.preventDefault();
        dicole.meetings.invite_customize_message_open('matchmaking');
        meetings_tracker.track(e.currentTarget);
    });

    // Open if global set
    if( dicole.get_global_variable('meetings_matchmaking_decline_open') ) {
        dicole.set_global_variable('meetings_matchmaking_decline_open', 0);
        dicole.meetings.open_matchmaking_decline( requester_name );
     }

     dojo.connect( dojo.byId('js_decline_matchmaking'), 'click', function(e) {
         e.preventDefault();
         dicole.meetings.open_matchmaking_decline( requester_name );
         meetings_tracker.track(e.currentTarget);
     });
};

dicole.meetings.open_matchmaking_decline = function( requester_name ) {
    dicole.uc_common_open_and_prepare_form( 'meetings', 'matchmaking_decline', {
        template_params : { requester_name : requester_name },
        width : 600
    });
};

dicole.meetings.open_meeting_cancel = function() {
    dicole.uc_common_open_and_prepare_form( 'meetings', 'meeting_cancel', {
        width : 600,
        success_handler : dicole.meetings.open_meeting_cancel_success
    });
};

dicole.meetings.open_meeting_cancel_success = function( response ) {
    if( response.result && response.result.success ){
        dojo.publish('showcase.close');
        dojo.publish('showcase.close');
        dicole.meetings.refresh_top();
        dicole.meetings.refresh_material();
    }
}

dicole.meetings.open_meeting_cancel_or_reschedule = function() {
    dicole.uc_common_open_and_prepare_form( 'meetings', 'meeting_cancel_or_reschedule', {
        width : 600,
        success_handler : dicole.meetings.open_meeting_cancel_or_reschedule_success
    });
};

dicole.meetings.open_meeting_cancel_or_reschedule_success = function( response ) {
    if( response.result && response.result.success ){
        if ( response.result.redirect_url ) {
            window.location = response.result.redirect_url;
        }
        else {
            dojo.publish('showcase.close');
            dicole.meetings.refresh_top();
        }
    }
}

dicole.meetings.show_rsvp_bar = function( container ) {
    var set_rsvp_state = function( state, container ) {
        dojo.query( 'p', container ).forEach( function(el) {
            el.innerHTML = MTN.t('Saving...');
        });
        dojo.query( 'span.button', container ).forEach( function(el) {
            dojo.removeClass( el, 'blue' );
            dojo.addClass( el, 'gray' );
        });
        dojo.xhrPost({
            url : dicole.get_global_variable('meetings_set_user_rsvp_url'),
            handleAs : 'json',
            content : { rsvp_status : state },
            load : function( response ) {
                if ( response.result ) {
                    dojo.fx.wipeOut({
                        node: container,
                        duration: 400,
                        onEnd : function(){
                            dojo.style( container, 'display', 'none' );
                            dicole.meetings.refresh_top();
                        }
                    }).play();

                    if ( response.result.rsvp_status == 'yes' ) {
                        dicole.meetings.add_message( MTN.t('You are now "Attending".'), 'message');
                    }
                    else if ( response.result.rsvp_status == 'no' ) {
                        dicole.meetings.add_message( MTN.t('You are now "Not Attending".'), 'message');
                    }
                }
                // Handle error?
            }
        });
    };
    container.innerHTML = dicole.process_template("meetings.next_action_bar", { type : 'rsvp', params : {} });
    dojo.query('.js_set_rsvp_true', container).forEach( function( el ) {
        dojo.connect( el, 'onclick', function(e){
            e.preventDefault();
            set_rsvp_state('yes' , container);
            meetings_tracker.track(el); // Tracking
        });
    });
    dojo.query('.js_set_rsvp_false', container).forEach( function( el ) {
        dojo.connect( el, 'onclick', function(e){
            e.preventDefault();
            set_rsvp_state('no' , container);
            meetings_tracker.track(el); // Tracking
        });
    });
};

dicole.meetings.submit_login_link_email = function( evt ) {
    evt.preventDefault();
    dojo.xhrPost( {
        url : dicole.get_global_variable('meetings_login_link_email_url'),
        form : 'meetings_login_link_email_form',
        handleAs : 'json',
        handle: function( response ) {
            dojo.query('#meetings_login_link_email_return').forEach( function( container ) {
                container.innerHTML = dicole.process_template( "meetings.login_return", response );
            } );
        }
    } );
};

dicole.meetings.init_paged_list_controls = function( id, container_node ) {
    var container = dojo.query( '.js_' + id + '_container', container_node ).pop();
    if ( ! container || dojo.hasClass( container, 'js_' + id + '_container_processed' ) ) {
        return;
    }
    dojo.addClass( container, 'js_' + id + '_container_processed' );

    var data = {
        id : id,
        current_page_id : 0,
        container : container,
        next_buttons : dojo.query(".js_" + id + "_next"),
        previous_buttons : dojo.query(".js_" + id + "_previous"),
        more_next : dicole.get_global_variable( id + '_more_next' ) ? 1 : 0,
        more_previous : dicole.get_global_variable( id + '_more_previous' ) ? 1 : 0,
        state : dicole.get_global_variable( id + '_state' ),
        flying_state : false,
        flying_state_start : new Date().getTime(),
        url : dicole.get_global_variable( id + '_url' ),
        pages : {}
    };

    dicole.meetings.check_page_switcher_states( data );

    data.pages[0] = dojo.create( 'div', {}, dojo.body() );

    // This needs a separate children array because
    // looping through childnodes while removing
    // children causes for loops and dojo.forEach to
    // skip every other node

    var children = [];
    dojo.forEach( container.childNodes, function ( node ) {
        children.push( node );
    } );
    dojo.forEach( children, function ( node ) {
        if ( node ) {
            dojo.place( node, data.pages[0] );
        }
    } );

    dojo.place( data.pages[0], container );

    dicole.mocc( "js_" + id + "_next", container_node, function( node ) {
        dicole.meetings.request_switch_page( data, 'next' );
    } );

    dicole.mocc( "js_" + id + "_previous", container_node, function( node ) {
        dicole.meetings.request_switch_page( data, 'previous' );
    } );
};

dicole.meetings.request_switch_page = function( data, where ) {
    if ( data.flying_state && data.flying_state_start + 3000 > new Date().getTime() ) {
        return;
    }

    data.flying_state = false;

    var new_page_id = data.current_page_id + ( ( where == 'previous' ) ? -1 : 1 );
    if ( data.pages[new_page_id] ) {
        return dicole.meetings.switch_page( data, new_page_id );
    }
    if ( ! data.more_previous ) {
        return;
    }

    data.flying_state = data.state;
    data.flying_state_start = new Date().getTime();

    var content = { state : data.state };
    content[ where ] = 1;

    dojo.xhrPost( {
        url : data.url,
        handleAs : 'json',
        content : content,
        load : dojo.partial( function( expected_flying_state, response ) {
            if ( response.result && data.flying_state && data.flying_state == expected_flying_state ){
                data.state = response.result.state;
                data.more_next = data.more_next && response.result.more_next ? 1 : 0;
                data.more_previous = data.more_previous && response.result.more_previous ? 1 : 0;
                data.pages[new_page_id] = dojo.create( 'div', { innerHTML : response.result.html } );
                dicole.meetings.switch_page( data, new_page_id, 1 );
                data.flying_state = false;
            }
        }, data.flying_state )
    } );
};

dicole.meetings.switch_page = function( data, new_page_id, new_node ) {

    for ( var i in data.pages ) {
        dojo.style( data.pages[i], 'display', 'none' );
    }
    dojo.place( data.pages[ new_page_id ], data.container );
    if ( new_node ) {
        dicole.process_new_node( data.pages[ new_page_id ] );
    }
    dojo.style( data.pages[ new_page_id ], 'display', 'block' );
    data.current_page_id = new_page_id;

    dicole.meetings.check_page_switcher_states( data );
}

dicole.meetings.check_page_switcher_states = function( data ) {
    dojo.forEach( data.next_buttons, function( node ) {
        if ( data.pages[ data.current_page_id + 1 ] || data.more_next ) {
            dojo.removeClass( node, 'inactive' );
        }
        else {
            dojo.addClass( node, 'inactive' );
        }
    } );
    dojo.forEach( data.previous_buttons, function( node ) {
        if ( data.pages[ data.current_page_id - 1 ] || data.more_previous ) {
            dojo.removeClass( node, 'inactive' );
        }
        else {
            dojo.addClass( node, 'inactive' );
        }
    } );
};

dicole.meetings.init_page_edit = function( result, continue_edit ) {
    dojo.query('.js_meetings_inplace_page_container').forEach( function( node ) {
        var ajax_loader = dojo.create( 'img',
                                      {src:'/images/meetings/ajax_loader.gif', alt: 'Loading...' },
                                      dojo.byId('material-edit-btn'),
                                      'first' );
        dojo.xhrPost({
            url : continue_edit ? result.raw_continue_url : result.raw_get_url,
            handleAs : 'json',
            load : function ( response ) {
                if ( response && response.result && response.result.lock_id ) {
                    node.innerHTML = dicole.process_template( 'meetings.inplace_page_editor', {} );
                    var current_editor;
                    dojo.query('.js_meetings_page_editor').forEach( function(n ) {
                        n.value = response.result.html;
                        current_editor = n;
                    } );

                    tinyMCE.init( {
                        menubar : false,
                        statusbar : false,
                        selector : '.js_meetings_page_editor',
                        language : dicole.get_global_variable('meetings_lang'),
                        width:  558,
                        height : 320,
                        plugins : 'autolink,paste',

                        toolbar1 : 'bold italic underline strikethrough | forecolor backcolor | formatselect | bullist numlist | removeformat',

                        content_css : '/css/tinymce.css',

                        paste_create_paragraphs : true,
                        paste_create_linebreaks : false,
                        paste_strip_class_attributes : 'all',
                        paste_auto_cleanup_on_paste : true
                    } );

                    // Remove ajax laoder
                    dojo.destroy(ajax_loader);

                    // Hide buttons
                    $('.material-top .controls').fadeOut();

                    // Remove double click to edit tooltip & cursor style
                    dojo.query('.js_meetings_inplace_page_container').forEach(function( node ){
                        dojo.attr( node, 'title', '' );
                        dojo.style( node, 'cursor', 'arrow' );
                    });

                    dicole.mocc('js_meetings_inplace_page_submit', dojo.body(), function ( node, evt ) {
                        dojo.xhrPost({
                            url : result.raw_put_url,
                            content : {
                                old_html : response.result.html,
                                html : tinyMCE.activeEditor.getContent(),
                                lock_id : response.result.lock_id
                            },
                            handleAs : 'json',
                            load : function ( r ) {
                                if ( r.error ) {
                                    alert( r.error );
                                }
                                else {
                                    dicole.meetings._inplace_editor_button_pressed = true;
                                    dicole.meetings.refresh_material();
                                    dicole.meetings.refresh_top();

                                    // Show buttons
                                    $('.material-top .controls').fadeIn();

                                    // Show next guide
                                    if( dicole.meetings.guides.active ){
                                        //guiders.next();
                                    }
                                }
                            }
                        } );
                    } );

                    dicole.uc_click_open_and_prepare_form( 'meetings', 'confirm_page_edit_cancel', {
                        url : result.cancel_edit_url,
                        template_params : {
                            lock_id : response.result.lock_id
                        },
                        success_handler : function( response ) {
                            dicole.meetings._inplace_editor_button_pressed = true;
                            dicole.meetings.refresh_material();
                            dojo.publish('showcase.close');

                            // Show buttons
                            $('.material-top .controls').fadeIn();

                            // Show next guide
                            if( dicole.meetings.guides.active ){
                                guiders.show();
                            }
                        }
                    } );

                    setTimeout( function() { dicole.meetings.ensure_page_lock( result, response.result, current_editor ) }, 5000 );
                }
                else {
                    dicole.meetings.refresh_material();
                }
            }
        });
    } );
};

dicole.meetings.last_page_lock_ensure = 0;
dicole.meetings.last_page_lock_content = '';

dicole.meetings.ensure_page_lock = function( data_result, raw_result, current_editor ) {
    var parent_node = current_editor.parentNode;
    var exists = 0;
    while ( parent_node ) {
        if ( parent_node === dojo.body() ) {
            exists = 1;
        }
        parent_node = parent_node.parentNode;
    }
    if ( ! exists ) {
        return;
    }

    var current_time = new Date().getTime();
    var current_content = tinyMCE.activeEditor ? tinyMCE.activeEditor.getContent() : '';

    if ( ! tinyMCE.activeEditor || ( dicole.meetings.last_page_lock_content == current_content && current_time < dicole.meetings.last_page_lock_ensure + 300000 ) ) {
        setTimeout( function() { dicole.meetings.ensure_page_lock( data_result, raw_result, current_editor ); }, 5000 );
        return;
    }

    dojo.xhrPost( {
        url : data_result.ensure_lock_url,
        content : {
            lock_id : raw_result.lock_id,
            autosave_content : current_content
        },
        handleAs : 'json',
        handle : function( response ) {
            if ( response.result.renew_succesfull ) {
                dicole.meetings.last_page_lock_ensure = new Date().getTime();
                dicole.meetings.last_page_lock_content = current_content;
            }
            setTimeout( function() { dicole.meetings.ensure_page_lock( data_result, raw_result, current_editor ); }, 5000 );
        }
    } );
};

dicole.meetings.init_upload = function(w, h, input_id, data_id, preview_id ) {
    var $input = $(input_id);
    var $parent = $input.parent();
    var $progress_bar = $('.progress-bar', $parent);
    var $text = $('.progress-text', $parent);
    var file;
    // TODO: Filetype checks
    var params = {
        paramname : 'file',
        maxNumberOfFiles : 1,
        dataType: 'json',
        formData : {
            width : w || 90,
            height : h || 90,
            user_id : app.auth.user,
            dic : app.auth.token,
            create_thumbnail: 1,
            broken_ie : dicole.meetings.IEVersion() <= 9 ? 1 : 0 // Sets returned content type to text/html
        },
        maxfilesize : 5000000 , // in mb
        dropZone : null,
        url : app.defaults.api_host + '/v1/uploads',
        done : function(e,data){

            $progress_bar.css('width','100%');
            $text.text( MTN.t('Done') );
            setTimeout( function(){
                $text.text( MTN.t('Upload photo') );
                $progress_bar.hide();
            }, 2000 );

            // Set values to form
            $(data_id).attr('value',data.result.result.upload_id);
            $(preview_id).attr('src',data.result.result.upload_thumbnail_url).show();
        },
        add: function (e, data) {
            file = data.files[0];
            $progress_bar.show();
            data.submit();
        },
        progressall: function(e, data) {
            var progress = parseInt(data.loaded / data.total * 100, 10);
            $progress_bar.css('width', progress + '%');
            $text.text( MTN.t('Uploading %1$s', [progress + '%']) );
        }
    };
    $(input_id).fileupload( params );
};

dicole.meetings.init_material_upload = function() {
    var $progress_bar = $('.progress-bar');
    var $text = $('.progress-text');
    var file;
    var params = {
        paramname : 'file',
        maxNumberOfFiles : 1,
        dataType: 'json',
        formData : {
            user_id : app.auth.user,
            dic : app.auth.token,
            disable_thumbnail : 1,
            broken_ie : dicole.meetings.IEVersion() <= 9 ? 1 : 0 // Sets returned content type to text/html
        },
        dropZone : null,
        maxfilesize : 5000000 , // in mb
        url : app.defaults.api_host + '/v1/uploads',
        done : function(e,data){
            $progress_bar.css('width','100%');
            $text.text( MTN.t('Uploading done. Processing.') );
            var meeting_id = dicole.get_global_variable('meetings_meeting_id');

            $.ajax(app.defaults.api_host + '/v1/meetings/'+meeting_id+'/materials', {
                type : 'POST',
                data : {
                    user_id : app.auth.user,
                    dic : app.auth.token,
                    meetin_id : meeting_id,
                    upload_id : data.result.result.upload_id,
                    material_name : file.name
                },
                success : function( res ) {
                    if( res && res.result ) {

                        dicole.meetings.refresh_material_list( 0, 1, function() {
                            // TODO: Select last material
                            dojo.publish('showcase.close');
                        } );

                        if( dicole.meetings.guides.active ) {
                            dicole.meetings.guides.end_guide();
                        }
                    }

                }
            });
        },
        add: function (e, data) {
            file = data.files[0];
            $progress_bar.show();
            data.submit();
        },
        progressall: function(e, data) {
            var progress = parseInt(data.loaded / data.total * 100, 10);
            $progress_bar.css('width', progress + '%');
            $text.text( MTN.t('Uploading %1$s', [progress + '%']) );
        }
    };
    $('#fileupload').fileupload( params );
};


dicole.meetings.refresh_material_list = function( initial_load, reload_material, run_after_refresh ) {
    if ( ! dicole.get_global_variable('meetings_get_material_list_url') ) {
        return;
    }
    dojo.xhrPost( {
        url : dicole.get_global_variable('meetings_get_material_list_url'),
        handleAs : 'json',
        load : function( response ) {
            if ( response && response.result ) {
                var container = dojo.byId('meeting-materials-container');
                if ( container ) {
                    container.innerHTML = templatizer.meetingMaterials( response.result );
                    dojo.publish("new_node_created", [ container ]);
                    dicole.meetings.set_selected_material( initial_load, reload_material );
                    if ( run_after_refresh ) {
                        run_after_refresh();
                    }
                }
            }
        }
    });
};

dicole.meetings.setup_trash_drop = function(){
    // Drop event for trash
    var trash = $('#meeting-trash-container');
    trash.bind('drop', function(e) {
        console.log('drop on trash');
        e.preventDefault();
        e.stopPropagation();
        var el = $('#'+e.originalEvent.dataTransfer.getData('Text'));
        el.remove();
        dicole.meetings.fixMaterialList();
        $('.material-item').first().click();
        trash.css('');
        $('#meeting-dropzone-container').slideToggle();
        $('#meeting-trash-container').slideToggle();
        // TODO: Handle deleting last file
        // Do a post to delete the file
    });
    trash.bind('dragover', function(e) {
        e.preventDefault();
        $(this).addClass('active');
    });
    trash.bind('dragenter', function(e) {
        $(this).addClass('active');
    });
    trash.bind('dragleave', function(e) {
        $(this).removeClass('active');
    });
};

dicole.meetings.fixMaterialList = function(){
    $('.material-item').each(function(index){
        $(this).attr('data-order-num', index);
        $(this).removeClass('item-first');
        $(this).removeClass('item-last');
    });
    $('.material-item').first().addClass('item-first');
    $('.material-item').last().addClass('item-last');
};

// There is a separate runtime selected material url which takes
// precedence over the one found in the cookie. This is to prevent
// actions in other tabs from affecting the reloaded material selecting.

dicole.meetings.runtime_selected_material_url = false;

dicole.meetings.set_selected_material = function( initial_load, reload_material ) {

    var materials = dojo.query( '.js_material_link' );
    var selected_node = false;

    var selected_url = dicole.meetings.runtime_selected_material_url ? dicole.meetings.runtime_selected_material_url : dojo.cookie( 'meetings_selected_material_url' );

    dojo.forEach( materials, function(node) {
        dojo.removeClass( node, 'selected' );
        if ( ! selected_node && selected_url && node.href.toString().indexOf( selected_url ) > -1 ) {
            selected_node = node;
            dojo.addClass( selected_node, 'selected' );
        }
    } );

    if ( ! selected_node && materials[0] ) {
        selected_node = materials[0];
        dojo.addClass( selected_node, 'selected' );
    }

    if ( selected_node && ( initial_load || reload_material ) ) {
        dicole.meetings.select_material( selected_node, 1 );
    }
}

dicole.meetings.refresh_material = function() {
    dojo.forEach( dojo.query('.js_material_link'), function( node ) {
        if ( dojo.hasClass( node, 'selected' ) ) {
            dicole.meetings.select_material( node, true );
        }
    } );
};

dicole.meetings.select_material_using_url = function( url, skip_scroll ) {
    var materials = dojo.query( '.js_material_link' );

    dojo.forEach( materials, function(node) {
        if ( url && node.href.toString().indexOf( url ) > -1 ) {
            dicole.meetings.select_material( node, skip_scroll );
            url = '';
        }
    } );
};

dicole.meetings._inplace_editor_button_pressed = false;
dicole.meetings.select_material = function( node, skip_scroll ) {
    if ( dojo.query('.inplace_editor_container').length == 1 ) {
        if ( ! dicole.meetings._inplace_editor_button_pressed && ! window.confirm (
            app.helpers.unescapeHTML( MTN.t('Are you sure you want to change the material? Unsaved changes will be lost. Save changes by clicking the "Save" button below the editor.') )
        ) ) {
            return;
        }
    }

    dicole.meetings._inplace_editor_button_pressed = false;

    var comment_node = dojo.byId('inplace_comments_input_' + dicole.meetings.current_comment_thread_id);

    if (comment_node) {
        dicole.meetings.draft_comments[dicole.meetings.runtime_selected_material_url] = comment_node.value;
    }

    dicole.meetings.runtime_selected_material_url = node.href;
    dojo.cookie( 'meetings_selected_material_url', node.href, { path : '/' } );

    dojo.xhrPost( {
        url : node.href,
        handleAs : 'json',
        load : function( response ) {
            if ( response && response.result ) {
                dojo.forEach( dojo.query('.js_material_link'), function( other_node ) {
                    dojo.removeClass( other_node, 'selected' );
                } );

                dojo.addClass(node, "selected");

                if ( dojo.hasClass( node, 'js_media' ) ) {
                    response.result.type = 'media';
                }
                if ( dojo.hasClass( node, 'js_page' ) ) {
                    response.result.type = 'page';
                }

                dicole.meetings.process_material( response.result, node );

                if ( ! skip_scroll ) {
                    dojo.window.scrollIntoView( dojo.byId('meetings_inplace_main_container') );
                }
            }
        }
    } );
};
dicole.meetings.themes = {};
dicole.meetings.current_theme = '';
dicole.meetings.bg_positions = {};
dicole.meetings.user_defaults= [];

    dicole.meetings.redraw_theme = function() {
        // Pick the last stylesheet
        // TODO: Add id to main stylesheet and use it to find it
        var stylesheet = '';
        // Find theme css filename
        var template = dojo.attr( dojo.byId('theme'), 'value');

        // Background image, if set
        var style_string = '';
        var bg_image = dojo.byId('js_bg_upload_image');
        var bg_image_url = dojo.attr( bg_image, 'src' );
        if( bg_image_url !== '' ) {
            style_string = 'div.content{ background-image: url("' + bg_image_url + '"); background-repeat:no-repeat; background-size:cover; -moz-background-size:cover; }';
        }

        var logo_image = dojo.byId('js_logo_upload_image');
        var logo_image_url = dojo.attr( logo_image, 'src' );
        if( logo_image_url ) {
            style_string += ' div#header-wrapper div#header div#header-logo h1, div#header-wrapper div#header div#header-logo h1.pro { background: url("' + logo_image_url + '") no-repeat top left transparent; }';
        }

        var style_modifier = dojo.byId( 'js_mod_images' );
        if( ! style_modifier ) {

            dojo.place( '<style id="js_mod_images" type="text/css" media="all">' + style_string + '</div>' , dojo.body(), 'first' );
        }
        else{
            style_modifier.innerHTML = style_string;
        }

        // Delete old stylesheet
        dojo.query('#stylesheet').forEach(function(n) {
             setTimeout( function() { dojo.destroy( n ); }, 3000 );
        });
        // Template key

        var fileref=document.createElement("link");
        fileref.setAttribute("rel", "stylesheet");
        fileref.setAttribute("id", "stylesheet");
        fileref.setAttribute("type", "text/css");
        fileref.setAttribute("href", '/css/meetings/'+template+'.css');
        document.getElementsByTagName("head")[0].appendChild(fileref);
    };

    dicole.meetings.refresh_autosave_content = function( material, node ) {
        dojo.xhrPost({
            url: dicole.get_global_variable('meetings_get_autosave_content_url'),
            content: { material_id: material.id },
            handleAs: 'json',
            error: function() { /* ignore */ },
            handle: function(response) {
                if (!dojo.hasClass(node, 'selected')) {
                    return;
                }

                if (dojo.query('.inplace_editor_container').length == 1) {
                    return;
                }

                if (response && response.result && response.result.autosave_content != null) {
                    if (!dicole.meetings.had_autosave_content) {
                        dicole.meetings.had_autosave_content = true;
                        dicole.meetings.refresh_material();
                        return; // refresh_material sets a new timeout
                    }

                    dojo.query('.js_meetings_inplace_page_content_container').forEach(function(n) {
                        n.innerHTML = response.result.autosave_content;
                    });
                } else {
                    if (dicole.meetings.had_autosave_content) {
                        dicole.meetings.had_autosave_content = false;
                        dicole.meetings.refresh_material();
                        return; // refresh_material sets a new timeout
                    }
                }

                setTimeout(function() { dicole.meetings.refresh_autosave_content(material, node); }, 5000);
            }
        });
    };

    dicole.meetings.process_material = function( material, node ) {
        if ( material.type == 'page' ) {
            var rt = material.readable_title + '';
            rt = rt.replace(/\s+\(\#.*\)\s*$/, '');
            material.readable_title = rt;
        }

        var inplace_html = dicole.process_template("meetings.inplace", material );
        var container = dojo.byId('meetings_inplace_main_container');
        container.innerHTML = inplace_html;

        if (material.type == 'page') {
            dicole.meetings.refresh_autosave_content(material, node);
        }

        if ( material.comment_thread_id ) {
            dicole.meetings.current_comment_thread_id = material.comment_thread_id;

            dojo.forEach( dicole.ucq( 'js_inplace_comments_container', container ), function( node ) {
                var comments_html = dicole.process_template("meetings.inplace_comments", material );
                node.innerHTML = comments_html;
            } );

            var draft_comment = dicole.meetings.draft_comments[dicole.meetings.runtime_selected_material_url];

            if (draft_comment) {
                dojo.byId('inplace_comments_input_' + material.comment_thread_id).value = draft_comment;
            }

            dojo.publish("new_node_created", [ container ]);

            dicole.comments.init_chat({
                container_id : 'inplace_comments_container_' + material.comment_thread_id,
                input_id : 'inplace_comments_input_' + material.comment_thread_id,
                submit_id : 'inplace_comments_submit_' + material.comment_thread_id,
                thread_id : material.comment_thread_id,
                state_url : material.comment_state_url,
                info_url : material.comment_info_url,
                add_url : material.comment_add_url,
                delete_url : material.comment_delete_url,
                edit_url : material.comment_edit_url,
                comment_template : 'meetings.comment',
                edit_comment_template : 'meetings.edit_comment',
                delete_comment_confirm_template: 'meetings.delete_comment_confirm',
                no_comments_found_template : 'meetings.no_shared_notes_found',
                //            disable_editing : true,
                reverse_state : true,
                disable_enter_submit : true,
                commenter_size : 50
            });
            if ( material.from_file && typeof( gapi ) !== 'undefined' && gapi.savetodrive ) {
                if ( ! dicole.meetings.IEVersion() ) {
                    gapi.savetodrive.render('js_possible_save_to_drive', {
                        src: material.download_url,
                        filename: material.title,
                        sitename: 'Meetin.gs'
                    });
                }
            }
        }
        else {
            dojo.publish("new_node_created", [ container ]);
        }

        dicole.mocc( 'js_prese_embed_image', container, function( node, evt ) {
            dicole.create_showcase({
                "disable_close": true,
                //            "content": dicole.process_template( "meetings." + id, {} )
                "content" : '<a href="#" class="js_hook_showcase_close"><img src="' + node.href + '" /></a>'
            });
        } );
    };

    dicole.meetings.update_conferencing_bar = function() {

        var $conference_bar = $('#meeting-center-bar-wrapper');
        var option = app.models.meeting.get('online_conferencing_option');

        if ( dicole.get_global_variable( 'meetings_begin_date_epoch' ) && dicole.get_global_variable( 'meetings_begin_date_epoch' ) !== '0' ) {
            var seconds_at_page_load = dicole.get_global_variable( 'meetings_begin_date_epoch' ) - dicole.get_global_variable( 'meetings_server_time_epoch' );
            var duration = dicole.get_global_variable( 'meetings_duration' );
            var before_event = seconds_at_page_load - Math.floor( ( new Date().getTime() - dicole.meetings_common.client_page_load_time ) / 1000 );
            var duration_percent = ( duration - ( duration + before_event ) ) / duration * 100;
            var elapsed_time = duration - ( duration + before_event );
            if( duration_percent <= 0 ) duration_percent = 1;

            if( ( elapsed_time + 60 * 30 ) > 0 && ( elapsed_time - 60 * 15 ) <= duration ) {

                if( option && option !== '' ) {
                    $conference_bar.html( templatizer.meetingLctBar( app.models.meeting.toJSON() ) ).show();
                }
                else {
                    $conference_bar.html('');
                }
            }
            else {
                $conference_bar.hide();
            }
        } else if( app.models.meeting.get('current_scheduling_id') && app.models.meeting.get('current_scheduling_id') !== '0' ) {
            $('#meeting-center-bar-wrapper').html( templatizer.schedulingBar() ).show();
        }
    };

dicole.meetings.filter_meetings = function( search_field ) {
    if(search_field.value != search_field.defaultValue && search_field.value.length) {
        dojo.query('.js_previous_meeting').forEach( function(meeting) {
            var meeting_title = meeting.innerHTML;
            if(meeting_title.toLowerCase().indexOf(search_field.value.toLowerCase()) != -1) {
                dojo.style( meeting, 'display', 'block' );
            }
            else dojo.style( meeting, 'display', 'none' );
        });
    }
    else {
        dojo.query('.js_previous_meeting').forEach( function(meeting) { dojo.style( meeting, 'display', 'block' ); });
    }
};

dicole.meetings.filter_users = function( users, search_field ) {
    if(search_field.value != search_field.defaultValue && search_field.value.length) {
        dojo.forEach(users, function(user) {
            var user_name = user.name;
            if(user_name.toLowerCase().indexOf(search_field.value.toLowerCase()) != -1) {
                dojo.byId(user.id).style.display = "block";
            }
            else dojo.byId(user.id).style.display = "none";
        });
    }
    else {
        dojo.forEach(users, function(user) { dojo.byId(user.id).style.display = "block"; });
    }
    dojo.query(".js_invite_userlist_separator").forEach(dojo.destroy);
    var visible_count = 0;
    dojo.forEach(users, function(user) {
        if(dojo.byId(user.id).style.display == "block") ++visible_count;
        if(!(visible_count % 5)) dojo.create("div", {"class": "js_invite_userlist_separator"}, dojo.byId(user.id), "after");
    });
};

dicole.meetings.formatSize = function(bytes) {
	var str = ['bytes', 'kb', 'MB', 'GB', 'TB', 'PB'];
	var num = Math.floor(Math.log(bytes)/Math.log(1024));
	bytes = bytes === 0 ? 0 : (bytes / Math.pow(1024, Math.floor(num))).toFixed(1) + ' ' + str[num];
	return bytes;
};

dicole.meetings.add_message = function( message, type ) {
    return dicole.meetings.add_messages( [ message ], type );
};

dicole.meetings.preload_datas = function( preloads ) {
    dojo.forEach( preloads, function( item ) {
        if ( ! dicole.get_global_variable('meetings_' + item + '_url') ) {
            return;
        }
        dicole.meetings.data[item] = false;
        dojo.xhrPost({
            encoding: 'utf-8',
            url: dicole.get_global_variable('meetings_' + item + '_url'),
            handleAs: "json",
            handle: function(response){
                if(response.result){
                    dicole.meetings.data[item] = response.result;
                    // Handle special case address book
                    if( item === 'invite_participants_data' && dicole.meetings.ab){
                        dicole.meetings.ab.addressBook( "updateDataOnce", {'users': dicole.meetings.data.invite_participants_data.user_data_list, 'meetings': dicole.meetings.data.invite_participants_data.meeting_data_list });
                    }

                }
            }
        });
    });

};

dicole.meetings.close_template_chooser = function(container){
    dojo.fx.wipeOut({
        node: container,
        duration: 200,
        onEnd : function(){
            // Show next action
            container.innerHTML = '';
            var meeting = dojo.byId( 'meeting' );
            dojo.removeClass( meeting, 'fade' );

            // Start guides with a delay
            setTimeout( function(){ dicole.meetings.guides.start(); }, 1000);

            dicole.meetings.refresh_top( true );
            dicole.set_global_variable( 'meetings_disable_template_chooser', true );

            // Post to disable the drawer for this meeting
            dojo.xhrPost({
                encoding: 'utf-8',
                url: dicole.get_global_variable( 'meetings_template_chooser_url' ),
                handleAs: 'json',
                handle: function(response) {
                    // done
                }
            });
        }
    }).play();
};

dicole.meetings.close_tutorial_chooser = function(container, disable){
    dojo.fx.wipeOut({
        node: container,
        duration: 200,
        onEnd : function(){
            container.innerHTML = '';
            var meeting = dojo.byId( 'meeting' );
            dojo.removeClass( meeting, 'fade' );
            if( disable ){
                dicole.meetings.guides.toggle_disable();
            }
            dicole.meetings.refresh_top();
        }
    }).play();
};

dicole.meetings.show_template_chooser = function(container) {
    // parse and show template chooser
    container.innerHTML = dicole.process_template('meetings.template_chooser', {} );

    // set opacity for #meeting-main to 0.5
    var meeting = dojo.byId( 'meeting' );
    dojo.addClass( meeting, 'fade' );

    // Setup handlers
    dicole.uc_click( 'js_start_blank', function( node ) {
        dicole.meetings.close_template_chooser( container );
    });

    dicole.uc_click_open( 'meetings', 'gcal_view', {
        width : 500,
        container : container,
        template_params : {},
        post_open_hook : function(){
            if( dicole.get_global_variable('meetings_google_connected') === 0 ) return; // do nothing if googel not connected
            dojo.xhrPost({
                encoding: 'utf-8',
                url: dicole.get_global_variable('meetings_get_gcal_meetings'),
                handleAs: "json",
                handle: function(data){
                    if(data.result){
                        var html = '';
                        var event = {};
                        var gcal_events_array = [];
                        dojo.forEach(data.result.items , function( item ){
                            if(item['kind'] == "calendar#event" &&
                               item['status'] !== "cancelled" ) {
                                html += dicole.meetings.get_html_for_gcal_event(item);
                            gcal_events_array[item.id] = item;
                            }
                        });

                        // Show message & change button text, if no meetings displayed
                        if( html === '' ){
                            html = '<tr><td class="error">'+ MTN.t("Oops, we couldn't find any future meetings. Please click \"Continue with blank\" to continue manually.") + '</td></tr>';
                            dojo.query( ".js_submit_gcal span").forEach( function( button ){
                                button.innerHTML = 'Continue with blank';
                            });
                            event.title = MTN.t('Untitled meeting'); // Set title blank
                        }

                        // Insert data
                        var container = dojo.byId('gcal_meetings');
                        container.innerHTML = html;

                        // Add event handlers
                        dojo.query( "tr.meeting", container ).forEach(function( cal_node ){
                            dojo.connect( cal_node, 'onclick', function(e){
                                e.preventDefault();
                                event = {};
                                dojo.query( "tr.meeting", container ).forEach(function(i){dojo.removeClass(i,'selected');});
                                dojo.addClass( cal_node, 'selected' );
                                var ge = gcal_events_array[dojo.attr( cal_node, 'data-id' )];
                                // Set start and end times
                                if(ge['start_epoch'] && ge['duration_minutes']){
                                    event.begin_epoch = ge['start_epoch'];
                                    event.duration = ge['duration_minutes']
                                    event.schedule = 'set';
                                    dicole.meetings.guides.date_set = true;
                                }
                                // Set people
                                if(ge['attendees']){
                                    event.participants = dojo.toJson(ge['attendees']);
                                    dicole.meetings.guides.participants_set = true;
                                }
                                // Set location
                                if(ge['location']){
                                    event.location = ge['location'];
                                    dicole.meetings.guides.location_set = true;
                                }
                                // Set title
                                if(ge['summary']){
                                    event.title = ge['summary'];
                                    dicole.meetings.guides.title_set = true;
                                }
                                meetings_tracker.track(cal_node); // Tracking
                            });
                        });

                        dojo.query( ".js_submit_gcal" ).forEach( function( button ) {
                            dojo.connect( button, 'onclick', function(e){
                                e.preventDefault();
                                if( ! event.title ) return;
                                dojo.xhrPost({
                                    encoding: 'utf-8',
                                    content: event,
                                    url: dicole.get_global_variable('meetings_update_url'),
                                    handleAs: "json",
                                    handle: function(data){
                                        if(data.result){
                                            dojo.publish('showcase.close');
                                            dicole.meetings.close_template_chooser( dojo.byId( 'next-action' ) );
                                            dicole.set_global_variable('meetings_disable_template_chooser', true);
                                            dicole.meetings.refresh_top(true);
                                        }
                                    }
                                });
                                meetings_tracker.track(button); // Tracking
                            });
                        });

                        // Add filtering functionality
                        var fe = $("#filter_gcal");
                        fe.quicksearch('table#gcal_meetings tr');
                    }
                }
            });
        }
    });
    // Hack to display this on return from gcal
    if( dicole.get_global_variable( 'meetings_open_meeting_chooser' ) ){
        dicole.click_element( dojo.byId('start-gcal') );
    }
}

dicole.meetings.show_participant_tutorial_bar = function( container ){
    container.innerHTML = dicole.process_template('meetings.next_action_bar', { type : 'tutorial' } );
    dojo.style( container, 'display', 'block' );
    var show_button = dojo.byId( 'js_start_tutorial' );
    var disable_button = dojo.byId( 'js_disable_tutorial' );
    dojo.connect( show_button, 'onclick', function(e){
        e.preventDefault();
        dicole.meetings.guides.start();
        dicole.meetings.close_tutorial_chooser(container);
        meetings_tracker.track(show_button); // Tracking
    });
    dojo.connect( disable_button, 'onclick', function(e){
        e.preventDefault();
        dicole.meetings.guides.disable_guide( dicole.get_global_variable('meetings_dismiss_new_user_guide_url') );
        dicole.set_global_variable('meetings_dismiss_new_user_guide_url', false);
        dicole.meetings.close_tutorial_chooser(container);
        meetings_tracker.track(disable_button); // Tracking
    });
}

dicole.meetings.get_html_for_gcal_event = function(evt) {
    var loc = evt.location || false;
    var html = '<tr class="meeting" data-id="'+_.escape(evt.id)+'"><td class="cal"><div class="calendar cal-medium after"><div class="cal-wrap">';
    html += '<div class="cal-day-text">'+_.escape(evt.start_cal.weekday)+'</div>';
    html += '<div class="cal-day">'+_.escape(evt.start_cal.day)+'</div>';
    html += '<div class="cal-mon">'+_.escape(evt.start_cal.month)+'</div>';
    html += '</div></div></td>';
    html += '<td class="info"><span class="name">'+_.escape(evt.summary)+'</span><span class="time">';
    if( evt.start_hm && evt.end_hm ) html += _.escape(evt.start_hm) + ' - ' + _.escape(evt.end_hm);
    if( evt.start_hm && evt.end_hm && loc ) html += ', ';
    if( loc ) html += _.escape(loc);
    html += '</span></td></tr>';
    return html;
}

dicole.meetings.guides = {
    active: false, // Are the guides shown
    never_show_again: false, // Has the user set it not shown
    guide_type: false, // Which type of guide is active
    guide_ids: ['first','second','third','fourth','fifth','sixth','seventh','eight'],
    disable_url: false,
    participants_set: false,
    location_set: false,
    title_set: false,
    date_set: false,

    // Starts guides
    start: function(){
        // Get some globals
        var settings = {
            active: false,
            creator: dicole.get_global_variable('meetings_is_creator'),
            user_created_meetings: dicole.get_global_variable('meetings_user_created_meetings'),
            user_participated_meetings: dicole.get_global_variable('meetings_user_meetings'),
            show_followup_guide: dicole.get_global_variable('meetings_show_followup_helpers'),
            dismiss_admin_guide_url: dicole.get_global_variable('meetings_dismiss_admin_guide_url'),
            dismiss_visitor_guide_url: dicole.get_global_variable('meetings_dismiss_new_user_guide_url')
        };

        dojo.mixin( this, settings);

        if ( this.creator === 1 &&
            this.show_followup_guide
           ) {
               this.active = true;
               this.followup_guide();
           }
           else if( this.creator === 1 && // User is creator
                   this.dismiss_admin_guide_url !== undefined // Not dismissed
               // && this.user_created_meetings < 5 // Has created less than 5 meetings
                  ) {
                      this.guide_type = 'admin';
                      this.disable_url = this.dismiss_admin_guide_url;
                      this.active = true;
                      this.admin_guide();
                  }
                  else if ( this.creator === 0 && // User is not creator
                           this.dismiss_visitor_guide_url !== undefined // Not dismissed
                      // && this.user_participated_meetings < 5 // Has been to less than 5 meetings
                          ) {
                              this.guide_type = 'visitor';
                              this.disable_url = this.dismiss_visitor_guide_url;
                              this.active = true;
                              this.visitor_guide();
                          }
    },

    disable_guide: function( url_override ){
        if( url_override ){
            this.disable_url = dicole.get_global_variable('meetings_dismiss_new_user_guide_url');
        }
        dojo.xhrPost({
            encoding: 'utf-8',
            url: this.disable_url,
            handleAs: "json",
            handle: function(data){
                if(data.result.success == 1){
                    // success
                }
            }
        });
    },

    toggle_disable: function(){
        if(this.never_show_again){
            this.never_show_again = false;
        }
        else{
            this.never_show_again = true;
        }
    },

    end_guide: function(){
        // Add glows for admin
        if( this.guide_type === 'admin'){
            var query = '';
            var ready_button = dojo.byId('meeting-ready-button');
            if( ready_button ){
                query = '#draft-box div.ready a span.draft-button';
            }
            else{
                query = '#invite-more a span.button-small';
            }
            $(query).hintLight();
        }

        guiders.hideAll();
        this.active = false;

        // Disable if needed
        if( this.never_show_again ){
            this.disable_guide();
        }
    },

    visitor_guide: function() {
        var g = this;
        /*guiders.createGuider({
buttons: [{name: "Next", onclick: guiders.next}],
description: "Got a minute? Click Next to get a quick tour on how to get the most out of your meeting.",
id: "first",
next: "second",
overlay: true,
title: "Welcome to the Meeting Page",
xButton: function(){ g.end_guide(); },
width: 320
});*/

        guiders.createGuider({
            attachTo: "#meeting-materials-guide-positioner",
            buttons: [{name: MTN.t("Next"), onclick: function(e){ meetings_tracker.track(e.currentTarget ); guiders.next(); } }],
            description: MTN.t("People have shared these materials. Click on a material to see more of it."),
            id: "second",
            next: "third",
            position: 3,
            title: MTN.t("Meeting Materials"),
            width: 320,
            xButton: function(){ g.end_guide(); }
        });

        guiders.createGuider({
            attachTo: "#current-material-guide-positioner",
            buttons: [{name: MTN.t("Next"), onclick: function(e){ meetings_tracker.track(e.currentTarget ); guiders.next(); } }],
            description: MTN.t("Here you can comment and print the selected material."),
            id: "third",
            next: "fourth",
            position: 12,
            title: MTN.t("Current Material Preview"),
            width: 280,
            xButton: function(){ g.end_guide(); }
        });

        guiders.createGuider({
            attachTo: "#invite-guide-positioner",
            buttons: [{name: MTN.t("Next"), onclick: function(e){ meetings_tracker.track(e.currentTarget ); guiders.next(); } }],
            description: MTN.t("These people will get notified if materials or meeting details change. You can invite more people from the 'invite' button."),
            id: "fourth",
            next: "fifth",
            position: 7,
            title: MTN.t("Meeting Participants"),
            width: 380,
            xButton: function(){ g.end_guide(); }
        });

        guiders.createGuider({
            attachTo: "#header-menu-positioner",
            buttons: [{name: MTN.t("Thanks!"), onclick: function(e){ meetings_tracker.track(e.currentTarget ); g.end_guide(); } } ],
            description: MTN.t("Do you like what you see? Open the menu and click the Add new -button to start organizing meetings - give it a try, it's free."),
            id: "fifth",
            next: "sixth",
            position: 5,
            title: MTN.t("Organize Your Own Meetings"),
            width: 330,
            xButton: function(){ g.end_guide(); }
        });
        guiders.show('second');

    },

    followup_guide : function() {
        var g = this;
        guiders.createGuider({
            buttons: [{name: MTN.t("Ok"), onclick: function(e) { meetings_tracker.track(e.currentTarget ); g.end_guide(); } }],
            description: MTN.t("To help you out, we copied over the previous meeting's title, location, participants and materials.  The meeting is now a draft. Feel free to change everything as you like. You at least need to specify the date."),
            id: "first",
            overlay: true,
            title: MTN.t("Meeting contents copied over"),
            xButton: function(){ g.end_guide(); },
            width: 320
        });

        guiders.show('first');
    },

    admin_guide : function() {
        var g = this;
        var id_index = 0;

        // Set title guider
        if( ! g.title_set && ! dicole.get_global_variable( 'meetings_open_addressbook_with_guiders' ) ){
            guiders.createGuider({
                attachTo: '#title-guide-positioner',
                position: 6,
                buttons: [ {name: MTN.t("Hide"), onclick: function(e){ meetings_tracker.track(e.currentTarget ); g.end_guide(); }, classString: "guider_cancel" }, {type: "checkbox", name: MTN.t("Never show again"), change: function(){ g.toggle_disable(); }, classString: 'guider_disable'}, { name: MTN.t("Next"), onclick: guiders.next }],
                description: MTN.t("Note: This will be in the title of the invitation email."),
                id: g.guide_ids[id_index],
                next: g.guide_ids[id_index + 1],
                overlay: false,
                title: MTN.t("Set the meeting title"),
                // xButton: function(){ guideShownOnce(admin,never_show_again); },
                width: 320
            });
            id_index++;
        }

        // Set date guider
        if( ! g.date_set && ! dicole.get_global_variable( 'meetings_open_addressbook_with_guiders' ) ){
            guiders.createGuider({
                attachTo: '#date-guide-positioner',
                position: 6,
                buttons: [{ name: MTN.t("Next"), onclick : function(e){ meetings_tracker.track(e.currentTarget); guiders.next(); } }],
                description: MTN.t("Hint: You can add multiple suggestions, if you don't know the date yet."),
                id: g.guide_ids[id_index],
                next: g.guide_ids[id_index + 1],
                overlay: false,
                title: MTN.t("Set the meeting date"),
                //xButton: function(){ guideShownOnce(admin,never_show_again); },
                width: 320
            });
            id_index++;
        }

        // Add participants guider
        if( ! g.participants_set || dicole.get_global_variable( 'meetings_open_addressbook_with_guiders' ) ){
            guiders.createGuider({
                attachTo: '#invite-participants-open-button',
                position: 6,
                buttons: [ { name: MTN.t("Next"), onclick : function(e){ meetings_tracker.track(e.currentTarget ); guiders.next(); } } ],
                description: MTN.t("Note: We won't send the invitations until you are ready."),
                id: g.guide_ids[id_index],
                next: g.guide_ids[id_index + 1],
                overlay: false,
                title: MTN.t("Add meeting participants"),
                //xButton: function(){ guideShownOnce(admin,never_show_again); },
                width: 320
            });
            id_index++;
        }

        // Set location guider
        if( ! g.location_set ){
            guiders.createGuider({
                attachTo: '#js_set_location',
                position: 6,
                buttons: [ { name: MTN.t("Next"), onclick : function(e){ meetings_tracker.track(e.currentTarget ); guiders.next(); } }],
                description: MTN.t("Hint: The meeting can be online, face-to-face or both."),
                id: g.guide_ids[id_index],
                next: g.guide_ids[id_index + 1],
                overlay: false,
                title: MTN.t("Set the meeting location"),
                //xButton: function(){ guideShownOnce(admin,never_show_again); },
                width: 320
            })
            id_index++;
        }

        // Fill agenda guider
        guiders.createGuider({
            attachTo: '#shared-document-edit-open',
            position: 9,
            buttons: [  { name: MTN.t("Next"), onclick : function(e){ meetings_tracker.track(e.currentTarget ); guiders.next(); } }],
            description: MTN.t("Note: We will send the agenda later with the invitation email."),
            id: g.guide_ids[id_index],
            next: g.guide_ids[id_index + 1],
            overlay: false,
            title: MTN.t("Fill in the agenda"),
            //xButton: function(){ guideShownOnce(admin,never_show_again); },
            width: 320
        })
        id_index++;

        // Add materials guider
        guiders.createGuider({
            attachTo: '#material-uploads',
            position: 3,
            buttons: [{ name: MTN.t("End tutorial"), onclick: function(e){ meetings_tracker.track(e.currentTarget ); g.end_guide('admin'); } }],
            description: MTN.t("You can also drag & drop materials from your desktop.%(N$%)%(N$%) Hint: Participants will be able to comment the materials."),
            id: g.guide_ids[id_index],
            next: g.guide_ids[id_index + 1],
            title: MTN.t("Add materials"),
            //xButton: function(){ guideShownOnce(admin,never_show_again); },
            width: 320
        })
        id_index++;
        guiders.show('first');
        if( dicole.get_global_variable( 'meetings_open_addressbook_with_guiders' ) ){
            guiders.hideAll();
        }
        guiders.addCountDown();
    }

} // END dicole.meetings.guides

dicole.meetings.add_messages = function( messages, type ) {
    var container = dojo.byId('message-box-container');
    var box = dojo.create('a', { "class" : "message-box", onclick : function(evt) { meetings_tracker.track(evt.currentTarget ); dojo.destroy(this); } }, container );
    dojo.forEach( messages, function( message ) {
        var message_container = dojo.create( 'div', { style : { clear : 'both' } }, box );
        dojo.create( 'span', { "class" : type + '-icon' }, message_container );
        dojo.create( 'span', { "class" : type, innerHTML : dicole.encode_html( message ) }, message_container );
    } );
    dojo.publish("new_node_created", [ container ] );
}

// SHown when an unloggedin organization registers for matchmaking
dicole.meetings.show_matchmaking_validate = function(){
    $('#matchmaking').html( dicole.process_template( 'meetings.matchmaking_validate', { email : dicole.get_global_variable('meetings_user_email') } ) );
}

// Shown when orgaization finalizes the registration for matchmaking
dicole.meetings.show_matchmaking_register_success = function(){
    $('#matchmaking').html( dicole.process_template( 'meetings.matchmaking_register_success', {} ) );
    dojo.publish("new_node_created", [ dojo.byId('matchmaking') ]);
}

// Shown when user has succesfully reserved a matchmaking slot
dicole.meetings.show_matchmaking_success = function(){
    // TODO: Pass meeting info (title, location, time) to the template
    $('#matchmaking').html( dicole.process_template( 'meetings.matchmaking_success', dicole.get_global_variable('meetings_matchmaking_success_params') ) );
    dicole.event_source.subscribe(
        'requested_meeting_changed',
        {
            limit_topics: [
                [ "meeting:" + dicole.get_global_variable('meetings_requested_meeting_id') ]
            ]
        },
        function(events) {
            var reload = false;
            dojo.forEach(events, function(e) {
                reload = true;
            });

            if ( reload ) {
                window.location.reload();
            }
        }
    );
}
// Shown when user has used an expired 1h lock
dicole.meetings.show_matchmaking_lock_expired = function(){
    // TODO: Pass meeting info (title, location, time) to the template
    $('#matchmaking').html( dicole.process_template( 'meetings.matchmaking_lock_expired', dicole.get_global_variable('meetings_matchmaking_lock_expired_params') ) );
}
// Shown when user has tried to reserve too many
dicole.meetings.show_matchmaking_limit_reached = function(){
    // TODO: Pass meeting info (title, location, time) to the template
    $('#matchmaking').html( dicole.process_template( 'meetings.matchmaking_limit_reached', dicole.get_global_variable('meetings_matchmaking_limit_reached_params') ) );
}
// Shown when unloggedin user makes an reservation
dicole.meetings.show_matchmaking_user_register_success = function(){
    $('#matchmaking').html( dicole.process_template( 'meetings.matchmaking_user_register_success', dicole.get_global_variable('meetings_matchmaking_user_register_success_params') ) );
}

// Shows a list of parties you can matchmake with
dicole.meetings.show_matchmaking_list = function() {



    var do_filter = function(filters) {
        var count = 0;

        $('.startup').each( function( i, startup ) {
            var $startup = $(startup);
            var show = true;

            $.each(filters, function(i,f) {
                var value = $startup.attr('data-search-' + f.key ) || '';
                if( f.match && f.match.toLowerCase() != value.toLowerCase() ) show = false;
            });

            if( show ){
                count++;
                $startup.show();
            }
            else{
                $startup.hide();
            }
        });

        $(window).trigger('resize'); // Updates lazyload

        if( count === 0 ){
            $empty_search.show();
        }
        else{
            $empty_search.hide();
        }
    }

    var event_id = dicole.get_global_variable('meetings_matchmaking_event_id');

    var eventFetch = $.Deferred();
    var registrationsFetch = $.Deferred();
    var tmpl_params = {};
    var $empty_search = $('<p style="display:none;">' + MTN.t('No results found.') + '</p>');

    $.when( eventFetch, registrationsFetch ).then(function() {

        if( ! tmpl_params.event || ! tmpl_params.registrations ) {
            $('#matchmaking').html('<p>' + MTN.t('We screwed up. Please try refreshing the page.') + '</p>');
            return;
        }

        var processed_filters = [];

        $.each( tmpl_params.event.profile_data_filters || [], function(i,f){
            var first_values = f.first_values || [];

            var value_map = {};
            $.each( first_values, function( ii, value ) {
                value_map[ value ] = 1;
            } );

            var extra_values = [];
            $.each( tmpl_params.registrations, function( ii, matchmaker ) {
                if ( matchmaker[ f.key ] && ! value_map[ matchmaker[ f.key ] ] ) {
                    value_map[ matchmaker[ f.key ] ] = 1;
                    extra_values.push( matchmaker[ f.key ] );
                }
            } );

            extra_values.sort();
            f.values = first_values.concat( extra_values );

            processed_filters.push( f );
        });

        $.each( tmpl_params.registrations, function( i, matchmaker ) {
            matchmaker.filter_attributes = [];
            $.each( processed_filters, function( ii, filter ) {
                matchmaker.filter_attributes.push( {
                    "key" : filter.key,
                    "string" : matchmaker[ filter.key ]
                } );
            } );
        } );

        $('#matchmaking').html( dicole.process_template('meetings.matchmaking_list', {
            processed_filters : processed_filters,
            matchmakers : tmpl_params.registrations,
            event : tmpl_params.event
        } ) );

        $('#matchmaking').on('click', '.pitch', function(e) {
            e.preventDefault();
            var url = $(e.currentTarget).attr('href');
            var video_id = url.match(/[a-zA-Z0-9\-\_]{11}/);
            if( ! video_id || ! video_id[0] ) {
                window.open(url,'_blank');
            } else {
                var showcase = dicole.create_showcase({
                    "disable_close" : true,
                    "content" : templatizer.youtubeEmbed( { video_id : video_id[0], width : 640, height : 390 } )
                });
            }
        });
        $('.lazy').lazyload({ threshold : 600, effect : "fadeIn" });


        app.helpers.keepBackgroundCover();
        dojo.publish("new_node_created", [ dojo.byId('matchmaking') ]);

        $('#matchmaking-list').append( $empty_search );

        var $cat = $('.filter-menu').chosen({ disable_search_threshold: 3, allow_single_deselect: true });

        $('.filter-menu').on( 'change', function(e) {
            var filters = _.map( $('.filter-menu'), function(o) {
                return { "match" : $(o).val() || '', "key" : $(o).attr("data-track-key") };
            });
            do_filter(filters);
            return;
        });
    });

    $.get( app.defaults.api_host + '/v1/matchmaking_events/'+event_id, function(response) {
        tmpl_params.event = response;
        eventFetch.resolve();
    });

    $.get( app.defaults.api_host + '/v1/matchmaking_events/'+event_id+'/registrations', function(response) {
        // collate responses so that same company has only one entry with an array of contacts
        var collated = [];
        var collated_lookup = {};
        var show_all = dicole.get_global_variable('meetings_matchmaking_event_list_unregistered_profiles');
        $.each( response, function( index, value ) {
            if ( ! show_all && ! value.desktop_url ) {
                return;
            }
            if ( ! collated_lookup[ value.title ] ) {
                collated_lookup[ value.title ] = value;

                value.contacts = [];
                collated.push( value )
            }

            if ( value.desktop_url ) {
                collated_lookup[ value.title ].configured = true;
            }

            var contact = {};
            $.each( [ 'contact_name', 'contact_title', 'desktop_url', 'desktop_calendar_url', 'contact_image' ], function( index, key ) {
                contact[key] = value[key];
                delete value[key];
            } );

            collated_lookup[ value.title ].contacts.push( contact );
        } );

        response = collated;

        // randomize order
        $.each( response, function( index, value ) {
            var target = Math.floor( index + Math.random() * ( response.length - index ) );
            response[ index ] = response[ target ];
            response[ target ] = value;
        } );

        // Lift startups /w meeetme page to top
        var temp_arr = [];
        $.each( response, function( index, value ) {
            if(value.configured) temp_arr.unshift(value);
            else temp_arr.push(value);
        });

        tmpl_params.registrations = temp_arr;

        registrationsFetch.resolve();
    });
};

dicole.meetings.accounts = function() {
    dojo.xhrPost( {
        url : '/meetings_json/admin_accounts',
        handleAs : 'json',
        load : function( response ) {
            dicole.uc_common_open_and_prepare_form( 'meetings', 'admin_accounts', {
                'width' : 785,
                'template_params' : response.result,
                'success_handler' : function( send_response ) {

                }
            } );
        }
    });
};

dicole.meetings.wiki_editor_opening = false;
dicole.meetings.open_wiki_editor = function(href) {

    // Lock to prevent double opening of editor
    if(dicole.meetings.wiki_editor_opening) return;
    dicole.meetings.wiki_editor_opening = true;

    dojo.xhrPost( {
        "url" : href,
        "handleAs" : 'json',
        "load" : function( response ) {
            setTimeout(function() {
                dicole.meetings.wiki_editor_opening = false;
            }, 500);
            if ( response && response.result ) {
                dicole.meetings.init_page_edit( response.result );
            }
        }
    });
};

dicole.meetings.remove_current_meeting_users_from_data = function( data ) {
    if( app.models && app.models.meeting && app.models.meeting.attributes.participants ) {
        var filter_arr = _.map( app.models.meeting.get('participants'), function( o ){ return o.user_id; });
        return _.filter( data, function(o){ return ($.inArray(o.user_id, filter_arr) === -1); });
    }
    else{
        return data;
    }
};

dicole.meetings.highlight_form_field = function(id, time){
    var el = dojo.byId( id );
    var old_style = dojo.style( el, 'border');
    dojo.style( el, 'border', '1px solid red');
    setTimeout( function(){
        dojo.style( el, 'border', old_style );
    },time);
}

if ( dojo.cookie("homescreen_advice_shown") != '1' // Cookie not set
    && window.location.href.search('dic=') > -1 // Url contains login token
&& 'standalone' in navigator // Browser has navigator.standalone value
&& ! navigator.standalone // Not in fullscreen mode
&& (/iphone|ipod|ipad/gi).test(navigator.platform) // Proper device
&& (/Safari/i).test(navigator.appVersion) // PRoper browser
   ) {

       var addToHomeConfig = {
           animationIn:'bubble', // Animation In
           animationOut:'drop',  // Animation Out
           lifespan:30000, // The popup lives 30 seconds
           touchIcon:true
       };

       document.title = 'Meetin.gs';
       document.write('<link rel="stylesheet" href="\/css\/add2home.css">');
       document.write('<script type="application\/javascript" src="\/js\/add2home.js" charset="utf-8"><\/s' + 'cript>');

       dojo.cookie("homescreen_advice_shown", "1", { expires: 30 } );
   }


// Translate
window.MTN = window.MTN || {};
MTN.t = function(a, b, c, d) {

    var key = a;
    var p = {};

    var other = [b, c, d]
    if ( other[2] || ( other[0] && typeof other[0] === 'string' ) ) {
        p.plural_value = other.shift() || '';
    }
    if ( other[1] || ( other[0] && $.isArray(other[0]) ) ) {
        p.params = other.shift() || [];
    }
    if ( other[0] ) {
        _.extend( p, other[0] || {} );
    }

    if( ! p.do_not_escape_params ) {
        p.params = _.map( p.params, function(param) { return _.escape(param) });
    }

    var value = MTN.jed_instance.dcnpgettext('messages', null, key, key, p.plural_value );

    return MTN.jed_instance.sprintf( parseTokens(value), p.params || [] );

    function searchAfter( s, pos ) {
        var p  = s.substr(pos).search(/%\(|%\)/);
        if( p !== -1 ) {
            p = p + pos;
            return p;
        }
        else{
            return false;
        }
    }

    function fixEscapes( s ) {
        var pos  = s.search(/%%/);
        if( pos === -1 ) return s;
        s = s.substr(0, pos) + s.substr(pos+1);
        return fixEscapes(s);
    }

    function removeContextComment( s ) {
        return s.replace(/\s*\/\/context\:.*/,"");
    }

    function parseTokens(input) {
        var depth = 0;
        var pos = 0;
        var token_length = 0;
        var open_token_start = 0;
        var open_token_operator = '';
        var result = '';
        var prev_pos = 0;
        var prev_tag_end = 0;
        var operator_params = {};
        input = fixEscapes( removeContextComment( input ) );
        while( true ) {
            prev_pos = pos;
            pos = searchAfter(input, pos);
            if( ! pos && pos !== 0 ) {
                result += _.escape(input.substr(prev_pos));
                break;
            }
            if( input.substr(pos,2) === '%(' ) {
                // TODO: Handle case where no operator
                token_length = input.substr(pos).search(/\$/) + 1;
                if( depth === 0 ) {
                    open_token_start = pos;
                    open_token_operator = input.substr(pos+2,token_length-3);
                    result += input.substr(prev_tag_end,pos - prev_tag_end);
                }
                pos = pos+token_length;
                depth++;
            }
            else if( input.substr(pos,2) === '%)' ) {
                tok_end = pos;
                pos = pos+2;
                prev_tag_end = pos;
                depth--;
            }

            if( depth === 0 ) {
                if( p && p[open_token_operator] ) operator_params = p[open_token_operator];
                else operator_params = {};
                result += MTN.decorators[open_token_operator](parseTokens( input.substr(open_token_start+4, tok_end - open_token_start - 4 ) ), operator_params);
            }
        }
        return result;
    }
}
MTN.decorators = {
    '' : function(val) {
        return val;
    },

    B : function(val) {
        return '<strong>' + val + '</strong>';
    },

    S : function(val, params) {
        return '<span id="'+(params.id || '')+'" class="'+(params.classes || params['class'] || '')+'">' + val + '</span>';
    },

    L : function(val, params) {
        if( ! params.href ) console.log('Translator is trying to create link with no href.');
        // TODO: Target attribute
        return '<a target="'+(params.target || '')+'" id="'+(params.id || '')+'" href="'+(params.href || '#')+'" class="'+(params.classes || params['class'] || '')+'">' + val + '</a>';
    },

    A : function(val, params) {
        if( ! params.href ) console.log('Translator is trying to create link with no href.');
        // TODO: Target attribute
        return '<a target="'+(params.target || '')+'" id="'+(params.id || '')+'" href="'+(params.href || '#')+'" class="'+(params.classes || params['class'] || '')+'">' + val + '</a>';
    },

    N : function() {
        return '<br/>';
    }
}
MTN.on_translation_load = function() {
}
MTN.trigger_translation_load = function() {
    MTN.on_translation_load();
}
