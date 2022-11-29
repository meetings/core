/*jslint todo: true, vars: true, eqeq: true, nomen: true, sloppy: true, white: true, unparam: true, node: true, regexp: true */
/*global app, templatizer, _, $, dojo, Backbone */

dojo.provide("dicole.meetings.views.agentAdminView");

app.agentAdminView = Backbone.View.extend({
    initialize : function( args ) {
        var bf = _.filter( _.keys( this ), function( key ) { key.indexOf('bound_') == 0 } );
        bf.unshift( this );
        _.bindAll.apply( _, bf );

        this.area = args.area;
        this.section = args.section;
        this.adminData = {};
    },

    events : {
        'click .select-area' : 'bound_select_area',
        'click .deselect-area' : 'bound_deselect_area',
        'click .select-section' : 'bound_select_section',

        'click .add-user-button' : 'bound_add_user',
        'click .edit-user-button' : 'bound_edit_user',
        'click .remove-user-button' : 'bound_remove_user',

        'click .add-office-button' : 'bound_add_office',
        'click .edit-office-button' : 'bound_edit_office',
        'click .remove-office-button' : 'bound_remove_office',

        'click .add-calendar-button' : 'bound_add_calendar',
        'click .edit-calendar-button' : 'bound_edit_calendar',
        'click .remove-calendar-button' : 'bound_remove_calendar',

        'click .edit-setting-button' : 'bound_edit_setting',

        'click .object-edit-button.plus' : 'bound_show_object_edit',
        'click .object-edit-button.minus' : 'bound_hide_object_edit',
        'click .show-object-adding' : 'bound_show_object_adding',
        'click .hide-object-adding' : 'bound_hide_object_adding',
    },

    bound_refresh_and_render : function() {
        var adminDataFetch = $.get( '/meetings_json/agent_admin_data', {
            area : this.area, section: this.section
        } );

        $.when(adminDataFetch).then( function( adminData ) {
            this.adminData = adminData.result;
            if ( this.adminData ) {
                [ 'calendars', 'users', 'offices' ].forEach( function( kind ) {
                    if ( this.adminData[ kind ] ) {
                        this.adminData[ kind ].sort( function(a,b) {
                            return a['uid'].localeCompare(b['uid']);
                        } );
                    };
                }.bind(this) );
            }
            this.bound_render();
        }.bind(this) );
    },

    bound_render : function() {
        var templateData = this.adminData;
        templateData.user = this.model.toJSON();
        templateData.just_saved_uid = this.just_saved_uid;

        this.$el.html( templatizer.agentAdmin( templateData ) );
        dojo.publish("new_node_created", [ this.$el.get(0) ] );

        if ( this.just_saved_uid ) {
            if ( this.just_saved_uid == 'new' ) {
                this.bound_show_object_adding_without_hide( true );
            }
            else if ( this.just_saved_uid == 'general' ) {
                var container = $('#object-general');
                this.bound_display_container_save_reopen_indicator( container, true );
            }
            else {
                var objects = templateData[ templateData.selected_section ];
                for ( var i in objects ) {
                    if ( objects[i].uid == this.just_saved_uid ) {
                        this.bound_show_object_edit_by_id( objects[i].safe_uid, true );
                        break;
                    }
                }
            }
            delete this.just_saved_uid;
        }

        app.helpers.keepBackgroundCover();
    },
    bound_select_area : function( event) {
        event.preventDefault();
        this.area = $( event.srcElement ).attr('x-data-area');
        this.bound_refresh_and_render();
    },
    bound_deselect_area : function( event) {
        event.preventDefault();
        this.area = undefined;
        this.bound_refresh_and_render();
    },
    bound_select_section : function( event) {
        event.preventDefault();
        this.section = $( event.srcElement ).attr('x-data-section');
        this.bound_refresh_and_render();
    },
    bound_hide_all : function( event ) {
        $( '#object-adding-container' ).hide();
        $( '.show-object-adding' ).show();
        $( '.hide-object-adding' ).hide();

        $( '.object-edit-button.minus').each( function( index, element ) {
            var object_id = $( element ).attr('x-data-object-id');
            var container = $( '#object-'+object_id );
            $( '.object-editor', container ).hide();
            $( '.object-edit-button.plus', container ).show();
            $( '.object-edit-button.minus', container ).hide();
        } );
    },
    bound_show_object_adding : function( event ) {
        event.preventDefault();
        this.bound_hide_all( event );
        this.bound_show_object_adding_without_hide();
    },
    bound_show_object_adding_without_hide : function( is_save_reopen ) {
        var container = $( '#object-adding-container' );
        container.show();
        $( '.show-object-adding' ).hide();
        $( '.hide-object-adding' ).show();
        if ( $( '.open-focus-target', container ).length != 0 ) {
            $( '.open-focus-target', container ).first().get()[0].focus();
        }
        this.bound_display_container_save_reopen_indicator( container, is_save_reopen );
    },
    bound_hide_object_adding : function( event ) {
        event.preventDefault();
        this.bound_hide_all( event );
    },
    bound_show_object_edit : function( event ) {
        event.preventDefault();
        this.bound_hide_all( event );
        this.bound_show_object_edit_by_id( $( event.srcElement ).attr('x-data-object-id') );
    },
    bound_show_object_edit_by_id : function( object_id, is_save_reopen ) {
        var container = $( '#object-'+object_id );
        $( '.object-editor', container ).show();
        $( '.object-edit-button.plus', container ).hide();
        $( '.object-edit-button.minus', container ).show();
        this.bound_display_container_save_reopen_indicator( container, is_save_reopen );
    },
    bound_display_container_save_reopen_indicator : function( container, is_save_reopen ) {
        if ( ! is_save_reopen ) {
            return;
        }
        $( '.save-reopen-indicator', container ).fadeIn();
        setTimeout( function() {
            $( '.save-reopen-indicator', container ).fadeOut();
        }, 3000 );
    },
    bound_hide_object_edit : function( event ) {
        event.preventDefault();
        this.bound_hide_all( event );
    },
    fill_object_payload : function( container, payload ) {
        $.each( $('.object-field', container), function( index, input_element ) {
            var $el = $( input_element )
            var field = $el.attr( 'x-data-object-field' );
            var val = $el.val();

            if ( $el.attr( 'x-data-object-field-type' ) == 'array' ) {
                if ( ! payload[ field ] ) {
                    payload[ field ] = [];
                }
                if ( $el.is(':checked') ) {
                    payload[ field ].push( val );
                }
            }
            else {
                payload[ field ] = val;
            }
        } );
    },
    bound_add_user : function ( event ) {
        event.preventDefault();

        this.bound_add_current_object( event, 'user', this.bound_model_user_post_fill_hook );
    },
    bound_edit_user : function ( event ) {
        event.preventDefault();

        this.bound_edit_current_object( event, 'user', this.bound_model_user_post_fill_hook );
    },
    bound_remove_user : function ( event ) {
        event.preventDefault();

        var r = confirm("Oletko varma että haluat poistaa käyttäjän?");
        if ( ! r ) { return; }

        this.bound_remove_current_object( event, 'user', this.bound_model_user_post_fill_hook );
    },
    bound_model_user_post_fill_hook : function( payload ) {
        if ( ! payload.name || ! payload.email ) {
            throw("Käyttäjällä täytyy olla sekä nimi että email");
        }

        if ( ! this.bound_validate_email( payload.email ) ) {
            throw("Käyttäjän sähköpostin täytyy olla oikea sähköpostiosoite");
        }

        if ( /[äöåÄÖÅ]/.test( payload.email ) ) {
            throw("Käyttäjän sähköpostissa ei saa olla Ä, Ö tai Å -merkkejä");
        }

        if ( payload.changed_email && ! this.bound_validate_email( payload.changed_email ) ) {
            throw("Käyttäjän uuden sähköpostin täytyy olla oikea sähköpostiosoite");
        }
        payload.uid = payload.email;
    },
    bound_add_office : function ( event ) {
        event.preventDefault();

        this.bound_add_current_object( event, 'office', this.bound_model_office_post_fill_hook );
    },
    bound_edit_office : function ( event ) {
        event.preventDefault();

        this.bound_edit_current_object( event, 'office', this.bound_model_office_post_fill_hook );
    },
    bound_remove_office : function ( event ) {
        event.preventDefault();

        var r = confirm("Oletko varma että haluat poistaa toimiston?");
        if ( ! r ) { return; }

        this.bound_remove_current_object( event, 'office', this.bound_model_office_post_fill_hook );
    },
    bound_model_office_post_fill_hook : function( payload ) {
        if ( ! payload.name ) {
            throw("Toimistolla täytyy olla nimi");
        }
        if ( payload.name.indexOf("(") > -1 ) {
            throw("Toimiston nimessä ei voi olla sulkumerkkejä. Voit käyttää Alaryhmä -kenttää luodaksesi erilaisia ryhmiä saman toimiston alle.");
        }
        ['open_mon','open_tue','open_wed','open_thu','open_fri'].forEach( function( wd ) {
            if ( ! payload[ wd ] ) { return; }
            if ( payload[ wd ].match(/^\d\d?\:\d\d\-\d\d?\:\d\d(\;\s*\d\d?\:\d\d\-\d\d?\:\d\d)*$/) ) { return; }
            throw("Aukioloaikojen tulee olla ohjeistetussa muodossa");
        }.bind( this ) );

        if ( payload.group_email && ! this.bound_validate_email( payload.group_email ) ) {
            throw("Yhteisen sähköpostilaatikon täytyy olla oikea sähköpostiosoite");
        }

        payload.full_name = payload.subgroup ? payload.name + ' ('+ payload.subgroup +')' : payload.name;
        payload.uid = payload.full_name;
    },
    bound_add_calendar : function ( event ) {
        event.preventDefault();

        this.bound_add_current_object( event, 'calendar', this.bound_model_calendar_post_fill_hook );
    },
    bound_edit_calendar : function ( event ) {
        event.preventDefault();

        this.bound_edit_current_object( event, 'calendar', this.bound_model_calendar_post_fill_hook );
    },
    bound_remove_calendar : function ( event ) {
        event.preventDefault();

        var r = confirm("Oletko varma että haluat poistaa kalenterin?");
        if ( ! r ) { return; }

        this.bound_remove_current_object( event, 'calendar', this.bound_model_calendar_post_fill_hook );
    },
    bound_model_calendar_post_fill_hook : function( payload ) {
        if ( ! payload.office_full_name || ! payload.user_email ) {
            throw("Sinun tulee valita sekä toimisto että käyttäjä");
        }

        if ( payload.extra_meeting_email && ! this.bound_validate_email( payload.extra_meeting_email ) ) {
            throw("Verkkotapaamisen osoitteen täytyy olla oikea sähköpostiosoite");
        }

        payload.uid = payload.office_full_name + ' ' + payload.user_email;
    },
    bound_edit_setting : function ( event ) {
        event.preventDefault();

        this.bound_edit_current_object( event, 'setting', this.bound_model_setting_post_fill_hook );
    },
    bound_model_setting_post_fill_hook : function( payload ) {
        payload.uid = 'general';
    },
    bound_add_current_object : function( event, model, post_fill_hook ) {
        var payload = {
            model : model,
            area : this.adminData.selected_area,
        };

        var container = $( '#object-adding-container' );
        this.bound_store_current_object( payload, container, post_fill_hook );
    },
    bound_edit_current_object : function( event, model, post_fill_hook ) {
        var payload = {
            model : model,
            area : this.adminData.selected_area,
        };

        var container = $( '#' + $( event.srcElement ).attr('x-data-object-container-id') );
        this.bound_store_current_object( payload, container, post_fill_hook );
    },
    bound_remove_current_object : function( event, model, post_fill_hook ) {
        var payload = {
            model : model,
            area : this.adminData.selected_area,
            removed_epoch : 1,
        };

        var container = $( '#' + $( event.srcElement ).attr('x-data-object-container-id') );
        this.bound_store_current_object( payload, container, post_fill_hook );
    },
    bound_store_current_object : function( payload, container, post_fill_hook ) {
        this.fill_object_payload( container, payload );

        if ( post_fill_hook ) {
            try {
                post_fill_hook( payload );
            }
            catch ( e ) {
                alert(e);
                return;
            }
        }

        if ( app.agent_admin_clickguard && app.agent_admin_clickguard > new Date().getTime() ) {
            return;
        }
        app.agent_admin_clickguard = new Date().getTime() + 5000;

        var setPost = $.post( '/meetings_json/set_agent_object', {
            payload : JSON.stringify( payload )
        } );

        $.when(setPost).then( function( result ) {
            if ( result.error && result.error.message ) {
                alert(result.error.message);
            }
            else {
                if ( ! payload.removed_epoch ) {
                    this.just_saved_uid = container.attr('id') == 'object-adding-container' ? 'new' : payload.uid;
                }
                this.bound_refresh_and_render();
            }
        }.bind(this) );
    },
    bound_validate_email : function( email ) {
        var re = /^(([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/;
        return re.test( email );
    }
});
