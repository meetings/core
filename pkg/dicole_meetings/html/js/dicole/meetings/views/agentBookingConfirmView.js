dojo.provide("dicole.meetings.views.agentBookingConfirmView");

app.agentBookingConfirmView = Backbone.View.extend({

    initialize : function(options) {
        this.lock = options.lock;
        this.booking_data = options.booking_data;
        this.custom_location_saved = false;
        this.custom_location_open = false;

        this.type_data = this.booking_data.meeting_type_data || {};

        _(this).bindAll('render','cancel','close','openLocationChange','saveLocationChange','closeLocationChange', 'confirmReservation', 'backToBooking', 'closeLocationChange', 'updateLocation' );
    },

    events : {
        'click .close' : 'closeIt',
        'click .cancel' : 'cancel',
        'click .change-location' : 'openLocationChange',
        'click .js-save-location' : 'saveLocationChange',
        'click .js-cancel-location' : 'closeLocationChange',
        'click .confirm' : 'confirmReservation',
        'click .back-to-booking' : 'backToBooking',
        'keyup #booking-form-address' : 'updateLocation'
    },

    fields : [
        'booking-form-name',
        'booking-form-email',
        'booking-form-phone',
        'booking-form-birthdate',
        'booking-form-address',
        'booking-form-area',
        'booking-form-agenda'
    ],

    render : function() {
        window.scrollTo(0,0);
        this.$el.html( templatizer.agentBookingConfirm( { user : this.model.toJSON(), lock : this.lock.toJSON(), booking_data : this.booking_data } ) );

        if ( ! this.type_data.custom_address_from_user ) {
            $('.location-field').val( this.booking_data.agent.toimisto );
            $('p.location-area-display').text( this.booking_data.agent.toimisto );
        }
        else {
            $('p.location-area-display').text( '?' );
            $('.home-page, span.divider',this.el).hide();
        }
        this.closeLocationChange();

        // Set language value
        $('#booking-form-language').val( 'en' );
        if ( this.booking_data.language == 'suomi' ) {
            $('#booking-form-language').val( 'fi' );
        }
        if ( this.booking_data.language == 'svenska' ) {
            $('#booking-form-language').val( 'sv' );
        }
        $('#booking-form-language').attr('disabled', 'disabled');

        $('#booking-form-level').val( this.booking_data.level );
        $('#booking-form-level').attr('disabled', 'disabled');

        if ( app.agent_booking_remember_confirm_data ) {
            // ignore confirm data that is more than 60 minutes old
            if ( new Date().getTime() < app.agent_booking_remember_confirm_data.created_date.getTime() + 1 * 60 * 1000 ) {
                _.each(this.fields, function(selector) {
                    if ( app.agent_booking_remember_confirm_data[selector] ) {
                        $('#'+selector).val( app.agent_booking_remember_confirm_data[selector] );
                    }
                } );
            }
            app.agent_booking_remember_confirm_data = false;
        }

        // Setup suggestible
        $.get( app.defaults.direct_api_host + '/v1/users/' + app.auth.user + '/meeting_contacts', function(data) {

            // Parse data
            var name_to_info = [];
            var name_search = [];
            _.each( data, function(o) {
                name_to_info[o.name] = o;
                name_search.push( o.name );
            });
            $('#booking-form-name').suggestible({ source : name_search, onSelect : function(value, suggestible) {
                $(suggestible).val(value);
                $('#booking-form-email').val(name_to_info[value].email);
                $('#booking-form-phone').val(name_to_info[value].phone);
            }, formatSuggestion : function(suggestion) {
                return suggestion + ' (' + name_to_info[suggestion].email + ')';

            }});
        });

        // 60 min timeout to close the dialog
        this.lock_timeout = setTimeout( function(){
            alert( MTN.t('Sorry, the 60 min reservation on the slot expired and we freed it. Please try again.') );
            //app.router.navigate('/meetings/agent_booking', { trigger : true });
            window.location = '/meetings/agent_booking';
        }, 1000 * 60 * 60 /* 60 min because of extended lock */ );

    },

    cancel : function(e) {
        e.preventDefault();
        clearTimeout( this.lock_timeout );

        app.agent_booking_chosen_data_trigger = 1;
        app.agent_booking_last_rendered_week_trigger = 1;

        app.agent_booking_remember_confirm_data = { created_date : new Date() };
        _.each(this.fields, function(selector) {
            var val = $('#'+selector).val();
            app.agent_booking_remember_confirm_data[ selector ] = val;
        } );

        app.models.lock.destroy({ success : function() {
            app.router.navigate('/meetings/agent_booking', { trigger : true });
        }} );
    },

    closeIt : function(e) {
        e.preventDefault();
        app.router.navigate('/meetings/agent_booking', { trigger : true });
    },

    openLocationChange : function(e) {
        e.preventDefault();
        this.custom_location_open = true;
        if ( ! this.custom_location_saved ) {
            $('.location-field').val( this.custom_location );
        }
        $('p.location-area-display').hide();
        $('p.location-area').show();
        $('.location-field').focus();
    },

    closeLocationChange : function(e) {
        if(e) e.preventDefault();
        this.custom_location_open = false;
        $('p.location-area-display').show();
        $('p.location-area').hide();
    },

    saveLocationChange : function(e) {
        if (e) e.preventDefault();
        this.custom_location_saved = true;
        this.custom_location = $('.location-field').val();
        $('p.location-area-display').text( this.custom_location );
        $('.home-page, span.divider',this.el).hide();
        this.closeLocationChange();
    },

    updateLocation : function(e) {
        e.preventDefault();
        if ( this.custom_location_saved || this.custom_location_open ) return;
        if ( ! this.type_data.custom_address_from_user ) return;

        this.custom_location = $('#booking-form-address').val();
        $('p.location-area-display').text( this.custom_location || '?' );
    },

    confirmReservation : function(e) {
        e.preventDefault();

        var _this = this;


        // Validation stuff ----

        var errors = [];

        // Check all fields
        _.each(this.fields, function(selector) {
            if ( selector == 'booking-form-agenda' ) {
                return;
            }
            var val = $('#'+selector).val();
            if ( selector == 'booking-form-email' ) {
                if ( val && ! app.helpers.validEmail(val) ) {
                    errors.push(selector);
                }
            }
            else if ( ! val ) {
                errors.push(selector);
            }
        });

        // Add errors
        $('input').removeClass('required');
        if( errors.length ) {
            var first = true;
            _.each( errors, function(selector) {
                if( first ) {
                    $('#'+selector).focus();
                    first = false;
                }
                $('#'+selector).addClass('required');
            });
            return;
        }

        // End validation ----


        var new_user = new app.userModel();
        new_user.url = app.defaults.direct_api_host + '/v1/users';

        var name_full = $('#booking-form-name').val();
        var first_name = name_full;
        var last_name = '';
        if( name_full.indexOf(' ') !== -1 ) {
            first_name = name_full.substr(0,name_full.indexOf(' '));
            last_name = name_full.substr(name_full.indexOf(' ')+1);
        }

        var user_data = {
            matchmaker_lock_id : this.lock.get('id'),
            primary_email : $('#booking-form-email').val(),
            first_name : first_name,
            last_name : last_name,
            phone : $('#booking-form-phone').val(),
            timezone : 'Europe/Helsinki',
            tos_accepted : '0',
            language : $('#booking-form-language').val()
        };

        if ( ! user_data.primary_email ) {
            var email = name_full.toLowerCase();
            email = email.replace( / /g, '.' );
            email = email.replace( /[^a-zA-Z\-\.]/g, '' );
            email = email.replace( /\.+/g, '.' );
            email = 'ltsahkopostiton+' + email + '+' + Math.floor( Math.random() * 10000 ) + '@meetin.gs';
            user_data.primary_email = email;
        }

        var extra_data = {
            birthdate : $('#booking-form-birthdate').val(),
            address : $('#booking-form-address').val(),
            area : $('#booking-form-area').val(),
            notes : $('#booking-form-agenda').val()
        };

        // Show loader
        var $content = this.$el.find('.modal-content .content-area').html('<p>'+('Varataan...'||MTN.t('Booking...'))+'</p><div class="loader"></div>');
        var spinner = new Spinner(app.defaults.spinner_opts).spin( $('.loader' , this.el )[0] );

        // Hide location changing & stuff
        $('.change-location, span.divider, .modal-footer',_this.el).hide();

        if ( this.custom_location_open ) {
            this.saveLocationChange();
        }

        new_user.save(user_data, {
            success : function() {
                _this.lock.save({
                    expected_confirmer_id : new_user.id,
                    extra_data : extra_data,
                    location : _this.custom_location ? _this.custom_location : '',
                    ignore_auth_user : 1
                }, { success : function(res) {
                    if( res.error && res.error.message ) return alert(res.error.message);
                    $content.html(templatizer.agentBookingThanks);
                    clearTimeout( _this.lock_timeout );
                    $('.modal-footer',_this.el).show();
                    _this.$el.find('.modal-footer .buttons').html('<a href="#" class="button blue close">'+('Takaisin varausnäkymään'||MTN.t('Back to booking'))+'</a>');
                }});
            },
            error: function() {
                $('.change-location, span.divider, .modal-footer',_this.el).show();
                alert(MTN.t('Saving profile failed. Please try again!'));
            }
        });


    },

    backToBooking : function(e) {
        e.preventDefault();
        app.router.navigate('/meetings/agent_booking', { trigger : true });
    }


});
