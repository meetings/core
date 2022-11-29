dojo.provide("dicole.meetings.views.wizardProfileView");

app.wizardProfileView = Backbone.View.extend({
    openProfile : false,
    initialize : function(options) {
        _(this).bindAll('render');

        this.openProfile = options.open_profile;
        this.tz_data = dicole.get_global_variable('meetings_time_zone_data');
        this.now = new Date();
        app.options.ua_time_zone = jstz.determine_timezone();
    },

    events : {
        'click #login-google' : 'loginGoogle',
        'click .save-profile-data' : 'saveProfileData',
        'click .open-profile-form' : 'openProfileForm'
    },

    render : function() {

        var _this = this;

        // Check for error
        var err_params = dicole.get_global_variable('meetings_email_not_found_params');
        if( err_params ) {
            this.$el.html( templatizer.wizardProfileError( err_params ) );
            if( err_params.user_email && err_params.user_email != '0' ) {
               var spinner = new Spinner(app.defaults.spinner_opts).spin( $('.loader-container',this.el)[0] );
            }
            return;
        }

        this.model.set( dicole.get_global_variable('meetings_suggest_profile_values') );

        // Read timezone in try/catch as it can fail
        var tz_offset = 0;
        try {
            tz_offset = this.tz_data.data[app.options.ua_time_zone.name()].offset_value;
        } catch(e) {
            if( window.qbaka ) {
                qbaka.report('failed timezone set with tz:' + app.options.ua_time_zone.name() );
            }
        }

        // Setup template
        this.$el.html( templatizer.wizardProfile( {
            model : this.model.toJSON(),
            openProfile : this.openProfile,
            lockEmail : dicole.get_global_variable('meetings_force_email'),
            ua_tz : app.options.ua_time_zone.name(),
            ua_tz_offset_value : tz_offset,
            tz_data : this.tz_data,
            d : this.now
        } ) );

        // Setup file upload
        var params = {
            paramname : 'file',
            maxNumberOfFiles : 1,
            formData : {
                user_id : app.auth.user,
                dic : app.auth.token,
                create_thumbnail : 1,
                width : 160,
                height : 160
            },
            maxfilesize:5000000 , // in mb
            url : app.defaults.api_host + '/v1/uploads',
            acceptFileTypes : /(\.|\/)(gif|jpe?g|png)$/i,

            done : function(e,data){
                $('#draft_id').val(data.response().result.result.upload_id);

                $('img#profile-image').attr('src', data.response().result.result.upload_thumbnail_url);
                $('img#profile-image').fadeIn();

                $('a#upload-button').removeClass('disabled');
                $('a#upload-button span.text').text(MTN.t('Upload photo'));
            },

            start:function(e){
                $('a#upload-button').addClass('disabled');
                $('img#profile-image').fadeOut();
            },
            progressall: function(e, data) {
                var progress = parseInt(data.loaded / data.total * 100, 10);
                $('a#upload-button span.text').text(progress + '%');
            }
        };
        $('#fileupload').fileupload( params );

        var $select = $('#timezone-select');
        $select.chosen().change(function(e) {
            var tz = $select.val();
            var new_time_string = moment.utc(_this.now.getTime() + _this.tz_data.data[tz].offset_value * 1000).format('hh:mm A');
            $('#current-time', _this.el).html(new_time_string);
        });

        app.helpers.keepBackgroundCover(true);
    },

    openProfileForm: function(e) {
        e.preventDefault();

        $('#facebook-form-fill-section').slideToggle();
        $('#profile-edit-section').slideToggle();
        $('a.save-profile-data').fadeIn();
    },

    loginGoogle : function() {
        window.location = dicole.get_global_variable('meetings_google_connect_url');
    },

    saveProfileData : function(e) {
        e.preventDefault();

        var email = $('input#profile-email').val();
        var fname = $('input#profile-first-name').val();
        var lname = $('input#profile-last-name').val();
        var org = $('input#profile-organization').val();

        var errors = [];

        if(!app.helpers.validEmail(email)) {
            errors.push('profile-email');
        }
        if( ! fname ) {
            errors.push('profile-first-name');
        }
        if( ! lname ) {
            errors.push('profile-last-name');
        }
        if( ! org ) {
            errors.push('profile-organization');
        }

        $('label,input').removeClass('required');
        if( errors.length ) {
            var first = true;
            $.each( errors, function() {
                if( first ) {
                    $('#'+this).focus();
                    first = false;
                }
                $('#'+this).addClass('required').prev('label').addClass('required');
            });
            return;
        }

        new app.helpers.activeButton(e.currentTarget);

        $('#event_id').val( dicole.get_global_variable('meetings_event_id') || '0' );
        var data = $("#edit-profile-container .meetings-form").serialize();

        $.post( dicole.get_global_variable('meetings_save_profile_url'), data, function( response) {
            if ( response.result && response.result.url_after_post ) {
                if(Modernizr.localstorage) localStorage.setItem('new_user_flow', 1);
                window.location = response.result.url_after_post;
            }
            else {
                alert( response.error.message );
            }
        },'json' );
    }
});
