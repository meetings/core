dojo.provide("dicole.meetings.app");

Backbone.history.on("route", function() {
    if( typeof ga !== 'undefined' ) ga('send', 'pageview', window.location.pathname);
});

// Backbone close
Backbone.View.prototype.close = function () {

    // Call before close
    if(this.beforeClose) {
        this.beforeClose();
    }

    // Call close for possible subviews
    if(this.subviews) {
        var i, l = this.subviews.length;
        for( i = 0; i < l; i++ ) {
            this.subviews[i].close();
        }
    }
    this.remove();
    this.unbind();
};
// Hack backbone sync to our needs
Backbone.sync = _.wrap(Backbone.sync, function(originalSync, method, model, options) {

    // Override patch to post
    if(method === 'patch') {
        options.type = 'POST';
    }

    var new_options =  _.extend({
        beforeSend : function(xhr) {

            // Setup auth tokens & language
            var token = app.auth.token;
            var user = app.auth.user;
            var lang = dicole.get_global_variable('meetings_lang');
            if(token) xhr.setRequestHeader('dic', token);
            if(user) xhr.setRequestHeader('user_id', user);
            if(lang) xhr.setRequestHeader('lang', lang);
            xhr.setRequestHeader('x-meetings-app-version', 'desktop');

            // Add patch header
            if(method === 'patch') xhr.setRequestHeader('X-HTTP-Method-Override','PATCH');
        }
    }, options);

    return originalSync(method, model, new_options);
});
// Backbone click tracking
Backbone.View.prototype.delegateEvents = function(events) {
    var delegateEventSplitter = /^(\S+)\s*(.*)$/;
    if (!(events || (events = _.result(this, 'events')))) return;
    this.undelegateEvents();
    var add_tracking = function(m,e) {
        meetings_tracker.track(e.currentTarget);
        m(e);
    };
    for (var key in events) {
        var method = events[key];
        if (!_.isFunction(method)) method = this[events[key]];
        if (!method) throw new Error('Method "' + events[key] + '" does not exist');
        var match = key.match(delegateEventSplitter);
        var eventName = match[1], selector = match[2];

        // Wrap method to add tracking
        if ( $.inArray(eventName, ['mouseenter','mouseleave','dragstart','dragenter','dragleave','dragover','blur','focus','keyup','paste'] ) === -1 ) {
            method = _.wrap( method, add_tracking );
        }

        eventName += '.delegateEvents' + this.cid;
        if(selector === '') {
            this.$el.on(eventName, method);
        } else {
            this.$el.on(eventName, selector, method );
        }
    }
};

// Add dic, user and lang to jquery requests
$.ajaxPrefilter(function( options ) {
    if ( !options.beforeSend) {
        options.beforeSend = function (xhr) {
            xhr.setRequestHeader('dic', app.auth.token);
            xhr.setRequestHeader('user_id', app.auth.user);
            xhr.setRequestHeader('lang', dicole.get_global_variable('meetings_lang'));
            xhr.setRequestHeader('x-meetings-app-version', 'desktop');
        };
    }
});

window.app = {
    auth : {
        user : '',
        token : '',
        cookiename : 'oi2_ssn', // not in use now
        cookievalid : 14 // in days
    },
    defaults : {
        // This detects IE below version 11, which is what we want.
        direct_api_host : ( window.navigator.userAgent.toLowerCase().indexOf('msie') != -1 ) ? '/apigw' : location.host.toString().match(/.*dev\.meetin\.gs/) ? 'https://api-dev.meetin.gs' : 'https://api.meetin.gs',
        api_host : '/apigw',
        return_host : 'http://' + location.host,
        spinner_opts : {
            lines: 11, // The number of lines to draw
            length: 5, // The length of each line
            width: 4, // The line thickness
            radius: 8, // The radius of the inner circle
            corners: 1, // Corner roundness (0..1)
            rotate: 0, // The rotation offset
            color: '#000', // #rgb or #rrggbb
            speed: 1, // Rounds per second
            trail: 60, // Afterglow percentage
            shadow: false, // Whether to render a shadow
            hwaccel: false, // Whether to use hardware acceleration
            className: 'spinner', // The CSS class to assign to the spinner
            zIndex: 2e9, // The z-index (defaults to 2000000000)
            top: 'auto', // Top position relative to parent in px
            left: 'auto' // Left position relative to parent in px
        },
        h_to_a : {
            add_participants : 'ico-add',
            send_invitations : 'ico-mail',
            fill_action_points : 'ico-edit',
            set_title : 'ico-edit',
            suggest_dates : 'ico-calendar',
            set_location : 'ico-location',
            add_agenda : 'ico-edit'

        }
    },

    vendors : { /* Gets populated when app is loaded, as translation functions might not be ready otherwise */ },

    meetme_themes : [
        {
            image : '/images/meetings/meetme_themes/theme1.jpg',
            thumb : '/images/meetings/meetme_themes/theme1_thumb.jpg'
        },
        {
            image : '/images/meetings/meetme_themes/theme2.jpg',
            thumb : '/images/meetings/meetme_themes/theme2_thumb.jpg'
        },
        {
            image : '/images/meetings/meetme_themes/theme3.jpg',
            thumb : '/images/meetings/meetme_themes/theme3_thumb.jpg'
        },
        {
            image : '/images/meetings/meetme_themes/theme4.jpg',
            thumb : '/images/meetings/meetme_themes/theme4_thumb.jpg'
        },
        {
            image : '/images/meetings/meetme_themes/theme5.jpg',
            thumb : '/images/meetings/meetme_themes/theme5_thumb.jpg'
        },
        {
            image : '/images/meetings/meetme_themes/theme6.jpg',
            thumb : '/images/meetings/meetme_themes/theme6_thumb.jpg'
        },
        {
            image : '/images/meetings/meetme_themes/theme7.jpg',
            thumb : '/images/meetings/meetme_themes/theme7_thumb.jpg'
        },
        {
            image : '/images/meetings/meetme_themes/theme8.jpg',
            thumb : '/images/meetings/meetme_themes/theme8_thumb.jpg'
        },
        {
            image : '/images/meetings/meetme_themes/theme9.jpg',
            thumb : '/images/meetings/meetme_themes/theme9_thumb.jpg'
        },
        {
            image : '/images/meetings/meetme_themes/theme10.jpg',
            thumb : '/images/meetings/meetme_themes/theme10_thumb.jpg'
        },
        {
            image : '/images/meetings/meetme_themes/theme11.jpg',
            thumb : '/images/meetings/meetme_themes/theme11_thumb.jpg'
        },
        {
            image : '/images/meetings/meetme_themes/theme12.jpg',
            thumb : '/images/meetings/meetme_themes/theme12_thumb.jpg'
        }
    ],

    meetme_types : [
        {
            icon_class : 'ico-meetings',
            name : 'Generic'
        },
        {
            icon_class : 'ico-coffee',
            name : 'Coffee'
        },
        {
            icon_class : 'ico-dinner',
            name : 'Dinner'
        },
        {
            icon_class : 'ico-drinks',
            name : 'Drinks'
        },
        {
            icon_class : 'ico-workshop',
            name : 'Workshop'
        },
        {
            icon_class : 'ico-sports',
            name : 'Sports'
        },
        {
            icon_class : 'ico-team',
            name : 'Team'
        },
        {
            icon_class : 'ico-idea',
            name : 'Idea'
        },
        {
            icon_class : 'ico-material_presentation',
            name : 'Board'
        },
        {
            icon_class : 'ico-calendars',
            name : 'Event'
        },
        {
            icon_class : 'ico-handshake',
            name : 'Business'
        },
        {
            icon_class : 'ico-call',
            name : 'Call'
        },
        {
            icon_class : 'ico-tablet',
            name : 'Tablet'
        },
        {
            icon_class : 'ico-teleconf',
            name : 'Telco'
        },
        {
            icon_class : 'ico-onlineconf',
            name : 'Skype'
        }
    ],
    options: {},
    models : {},
    collections : {},
    views : {},
    router : null,
    mixins : {},
    helpers : {

        checkGlobals : function( list ) {
            return $.grep( list, function( x ) { return dicole.get_global_variable( x ); } ).length > 0;
        },

        getPricingLink : function() {
            var pricing_link = '';
            var lang = app.models.user.get('language');

            if( lang === 'en') pricing_link = 'http://www.meetin.gs/pricing/';
            if( lang === 'fi') pricing_link = 'http://www.meetin.gs/fi/hinnasto/';
            if( lang === 'sv') pricing_link = 'http://www.meetin.gs/sv/priser/';
            if( lang === 'nl') pricing_link = 'http://www.meetin.gs/nl/prijzen/';
            if( lang === 'fr') pricing_link = 'http://www.meetin.gs/nl/prix/';

            return pricing_link;
        },

        getServiceDisconnectUrl : function( service ) {
            return '/apigw/v1/users/' + app.auth.user + '/service_accounts/' + service + '/disconnect';
        },

        getServiceUrl : function( params ) {

            var url = '';
            params.return_url = params.return_url || window.location.href;

            // Check for necessary params
            if( ! params || ! params.service || ! params.action ) {
                console.log('getServiceUrl called with invalid params');
            }

            if( $.inArray(params.action, ['login','connect','buy_monthly', 'buy_yearly']) ) {
                url = '/apigw/v1/service_redirect/' + params.service + '_' + params.action;
            } else if( params.action === 'disconnect' ) {
                url = '/apigw/v1/user/' + app.auth.user + '/service_accounts/' + params.service + '/disconnect';
            }

            url += '?return_url=' + app.defaults.return_host + params.return_url;

            url += '&cancel_url=' + params.return_url;

            url += '&dic=' + app.auth.token;

            return url;
        },

        populateVendors : function() {
            app.vendors = {
                'elisa' : { image : '/images/meetings/vendors/elisa_logo.png', image_small : '/images/meetings/vendors/elisa_logo_small.png', name : MTN.t('Elisa (Finland)'), url : 'https://pilvi.elisa.fi/fi/productdetails/125', price : MTN.t('9 EUR / month'), country_code : 'FI' },
                'telia' : { image : '/images/meetings/vendors/telia_logo.png', image_small : '/images/meetings/vendors/telia_logo_small.png', name : MTN.t('Telia (Sweden)'), url : 'https://appmarket.telia.se/apps/7465', price : MTN.t('79 SEK / month'), country_code : 'SWE' }
                //'base' : { image : '/images/meetings/vendors/base_logo.png', image_small : '/images/meetings/vendors/base_logo_small.png', name : 'Base', url : 'TODO' },
                //'kpn' : { image : '/images/meetings/vendors/kpn_logo.png', image_small : '/images/meetings/vendors/kpn_logo_small.png', name : 'KPN', url : 'TODO' },
            };
        },

        activeButton : function( el ) {
            var $el = $(el);
            var $label = $('span.label',el);
            var advancedMode = $label && $label.length;
            var savedText = $el.text();

            if( advancedMode ) {
                $el.addClass('active');
            } else {
                $el.text( MTN.t('Saving...') );
            }
            // TODO: min timing

            this.setDone = function(text) {
                var newText = text || savedText;
                if( advancedMode ) {
                    $el.removeClass('active').addClass('done');
                    $label.text('Done');
                } else {
                    $el.text( MTN.t('Done') );
                }
                setTimeout(function() {
                    $el.removeClass('done');
                    if( $label.length ) {
                        $label.text(newText);
                    } else {
                        $el.text(newText);
                    }
                },2000);
            };

            this.reset = function() {
                $el.removeClass('active');
                $label.text(savedText);
                // TODO: release memory?
            };

            this.remove = function() {
                $el.remove();
            };

            return this;
        },

        unescapeHTML : function( str ) {
            var d = document.createElement("div");
            d.innerHTML = str;
            return d.innerText || d.text || d.textContent;
        },

        setLangParams : function() {
            if( dicole.get_global_variable('meetings_lang') ) {
                $.ajaxSetup({
                    headers: {'lang' : dicole.get_global_variable('meetings_lang') }
                });
                moment.lang( dicole.get_global_variable('meetings_lang') );
                app.language = dicole.get_global_variable('meetings_lang');
            }
        },

        ensureToolUrl : function(url) {
            // Remove whitespace
            url.replace(/\s+/g, '');

            // Ensure begin with http(s)
            if( url.indexOf('http://') !== 0 && url.indexOf('https://') !== 0 ) {
                if(window.qbaka) qbaka.report('Broken lct url: ' + url);
                url = 'http://' + url;
            }

            // Ensure not pointing inside meetings
            if( url.indexOf('http://meetin.gs') === 0 || url.indexOf('https://meetin.gs') === 0) {
                alert('Meeting tool url is invalid. Please contact the meeting organizer.');
                url = '';
            }

            return url;
        },

        normalizeUrl : function(url) {
            var preserveNormalForm = /[,_`;\':-]+/gi;

                url = url.replace(preserveNormalForm, ' ');

                // strip accents
                url = app.helpers.stripVowelAccent(url);

                //remove all special chars
                url = url.replace(/[^a-z|^0-9|^-|\s]/gi, '');

                // Trim the url
                url = url.replace(/^\s+|\s+$/g, "");

                //replace spaces with a -
                url = url.replace(/\s+/gi, '-');

                // make lover case
                url = url.toLowerCase();
                return url;
        },

        stripVowelAccent : function(str) {
            var rExps = [{ re: /[\xC0-\xC6]/g, ch: 'A' },
                { re: /[\xE0-\xE6]/g, ch: 'a' },
                { re: /[\xC8-\xCB]/g, ch: 'E' },
                { re: /[\xE8-\xEB]/g, ch: 'e' },
                { re: /[\xCC-\xCF]/g, ch: 'I' },
                { re: /[\xEC-\xEF]/g, ch: 'i' },
                { re: /[\xD2-\xD6]/g, ch: 'O' },
                { re: /[\xF2-\xF6]/g, ch: 'o' },
                { re: /[\xD9-\xDC]/g, ch: 'U' },
                { re: /[\xF9-\xFC]/g, ch: 'u' },
                { re: /[\xD1]/g, ch: 'N' },
                { re: /[\xF1]/g, ch: 'n'}];
                for (var i = 0, len = rExps.length; i < len; i++)
                str = str.replace(rExps[i].re, rExps[i].ch);
                return str;
        },

        truncate : function (string, len) {
            if (string.length >= len )
                return string.substring(0,len)+'...';
            else
                return string;
        },

        // TODO: Rework to load only the needed themes
        preloadMeetmeBackgrounds : function(timeout) {
            if( app.preloads ) return;
            setTimeout(function() {
                app.preloads = [];
                var temp_arr = [];
                var i, l = app.meetme_themes.length;
                for( i = 0; i < l; i++ ) {
                    temp_arr.push(app.meetme_themes[i].image);
                }

                if( app.collections.matchmakers ) {
                    var x, y = app.collections.matchmakers.length;
                    for( x = 0; x < y; x++ ) {
                        if(  app.collections.matchmakers.at(x).get('background_image_url') ) {
                            temp_arr.push(app.collections.matchmakers.at(x).get('background_image_url'));
                        }
                    }
                }

                if( app.models.user && app.models.user.get('meetme_background_image_url') ){
                    temp_arr.push(app.models.user.get('meetme_background_image_url'));
                }

                for (i = 0; i < temp_arr.length; i++) {
                    app.preloads[i] = new Image();
                    app.preloads[i].src = temp_arr[i];
                }
            }, (timeout || 100) );
        },

        preloadMeetmeBackgroundsOld : function(timeout) {
            setTimeout(function() {

                if($('#preloads').length) return;

                var $c = $('<div id="preloads"></div>');

                var i, l = app.meetme_themes.length;
                for( i = 0; i < l; i++ ) {
                    $c.append( $('<div style="background:url('+app.meetme_themes[i].image+') no-repeat -9999px -9999px"></div>'));
                }

                if( app.collections.matchmakers ) {
                    var x, y = app.collections.matchmakers.length;
                    for( x = 0; x < y; x++ ) {
                        if(  app.collections.matchmakers.at(x).get('background_image_url') ) {
                            $c.append( $('<div style="background:url('+app.collections.matchmakers.at(x).get('background_image_url')+') no-repeat -9999px -9999px"></div>'));
                        }
                    }

                }
                $('body').append($c);

            }, (timeout || 100) );
        },

        // Looks for .content and keeps it fully sized
        keepBackgroundCover : function(onlyFooter) {
            var rateControlState = { rateLimitMilliseconds : 500 };
            var executeHandler = function() {
                var extra_height = 0;
                var $footer = $('#bb-footer');
                var footer_height = $footer.is(':visible') ? $footer.height() : 0;
                if( onlyFooter ) extra_height = footer_height;
                else extra_height = footer_height + $('div.top-wrapper').height() + $('div.info-bar').height();
                $('.content').css('min-height', '');
                var h = $(document).height();
                $('.content').css('min-height', h - extra_height);
                $('#bb-background').css('min-height', h - extra_height);
            };

            $(window).on('scroll', function(){
                window.app.helpers.rateLimitedAndSchedulingExecute( executeHandler, rateControlState );
            });
            $(window).on('resize', function(){
                window.app.helpers.rateLimitedAndSchedulingExecute( executeHandler, rateControlState );
            });
        },

        matchElHeight : function($el) {
            var rateControlState = { rateLimitMilliseconds : 500 };
            var executeHandler = function() {
                var extra_height = $('#bb-footer').height() + $('div.top-wrapper').height() + $('div.info-bar').height();
                var h = $(document).height();
                $el.css('min-height', h - extra_height);
            };

            $(window).on('resize', function(){
                window.app.helpers.rateLimitedAndSchedulingExecute( executeHandler, rateControlState );
            });
        },

        rateLimitedAndSchedulingExecute : function( codeHandler, rateControlState ) {
            if ( rateControlState.lastExecute && ( new Date().getTime() < rateControlState.lastExecute + rateControlState.rateLimitMilliseconds ) ) {
                if ( ! rateControlState.executeScheduled ) {
                    rateControlState.executeScheduled = setTimeout( function() {
                        rateControlState.executeScheduled = false;
                        window.app.helpers.rateLimitedAndSchedulingExecute( codeHandler, rateControlState );
                    }, 50 );
                }
            }
            else {
                rateControlState.lastExecute = new Date().getTime();
                codeHandler();
            }
        },

        validEmail : function(emailAddress) {
            var pattern = new RegExp(/^((([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+(\.([a-z]|\d|[!#\$%&'\*\+\-\/=\?\^_`{\|}~]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])+)*)|((\x22)((((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(([\x01-\x08\x0b\x0c\x0e-\x1f\x7f]|\x21|[\x23-\x5b]|[\x5d-\x7e]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(\\([\x01-\x09\x0b\x0c\x0d-\x7f]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF]))))*(((\x20|\x09)*(\x0d\x0a))?(\x20|\x09)+)?(\x22)))@((([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|\d|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.)+(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])|(([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])([a-z]|\d|-|\.|_|~|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])*([a-z]|[\u00A0-\uD7FF\uF900-\uFDCF\uFDF0-\uFFEF])))\.?$/i);
            var replace_regex = '\\".*\\"\\s*\\<(.*)\\>|(.*)';
            emailAddress = emailAddress.replace(new RegExp(replace_regex), '$1$2');
            return pattern.test(emailAddress);
        },

        getQueryParamByName : function( name ) {
            var match = RegExp('[?&]' + name + '=([^&]*)').exec(window.location.search);
            return match && decodeURIComponent(match[1].replace(/\+/g, ' '));
        },

        paymentDateString : function( time ) {
            return moment.utc(time * 1000).format('MMMM DD, YYYY');
        },

        dateString : function(time, offset) {
            var o = offset || 0;
            return moment.utc(time + o * 1000).format('dddd, MMM DD');
        },

        dayString : function(time, offset) {
            var o = offset || 0;
            return moment.utc(time + o * 1000).format('dddd');
        },

        hourString : function( time, offset ) {
            var o = offset || 0;
            return moment.utc(time + o * 1000).format('h:mm A');
        },

        hourSpanString : function( start, end, offset ) {
            var o = offset || 0;
            return moment.utc(start + o * 1000).format('h:mm A') + ' - ' + moment.utc(end + o * 1000).format('h:mm A');
        },

        daySpanStringFromTimespans : function(spans, offset) {
            var o = offset || 0;
            var i, l = spans.length, start = Infinity, end = 0;
            for(i = 0; i < l; i++ ) {
                if( spans[i].start < start ) start = spans[i].start;
                if( spans[i].end > end ) end = spans[i].end;
            }

            // Check if start & end inside the same day
            var start_string = app.helpers.dateString(start * 1000, o);
            var end_string = app.helpers.dateString(end * 1000, o);

            if( start_string === end_string ) string = start_string;
            else string = start_string + ' - ' + end_string;

            return string;
        },

        fullTimeString : function(time, offset) {
            return app.helpers.dateString( time, offset ) + ' ' + app.helpers.hourString( time, offset );
        },

        fullTimeSpanString : function( start, end, timezone ) {
            var o = timezone.offset_value;
            var tzn = timezone.readable_name;

            // Check DST change
            if( timezone.dst_change_epoch && timezone.dst_change_epoch < start ) {
                o = timezone.changed_offset_value;
                tzn = timezone.changed_readable_name;
            }

            // Check if start & end inside the same day
            var string = '';
            var s = new Date( (start + o ) * 1000 );
            var e = new Date( (end + o ) * 1000 );

            if( s.getUTCDate() === e.getUTCDate() ) {
                string =  app.helpers.hourString( start * 1000, o ) + ' - ' +
                          app.helpers.hourString( end * 1000, o ) + ' ' +
                          app.helpers.dateString(end * 1000, o) + ' ' + tzn;
            }
            else {
                string =  app.helpers.hourString( start * 1000, o ) + ' ' +
                    app.helpers.dateString(start * 1000, o) + ' - ' +
                    app.helpers.hourString( end * 1000, o ) + ' ' +
                    app.helpers.dateString(end * 1000, o) + ' ' + tzn;
            }

            return string;
        },

        selectText : function(text) {
            var doc = document, range, selection;
            if(doc.body.createTextRange) { //ms
                range = doc.body.createTextRange();
                range.moveToElementText(text);
                range.select();
            } else if(window.getSelection) { //all others
                selection = window.getSelection();
                range = doc.createRange();
                range.selectNodeContents(text);
                selection.removeAllRanges();
                selection.addRange(range);
            }
        },

        setupUserAuth : function() {
            app.auth.user = dicole.get_global_variable('meetings_user_id');
            app.auth.token = dicole.get_global_variable('meetings_auth_token');
            app.auth.is_pro = dicole.get_global_variable('meetings_user_is_pro');
        }

    },


    // Init for the summary
    init_summary : function() {

        app.helpers.setLangParams();

        app.helpers.setupUserAuth();

        app.models.user = new app.userModel({ id : app.auth.user });

        app.collections.news = new app.newsCollection();
        app.collections.news.url = '/apigw/v1/users/' + app.auth.user + '/news';
        app.views.news_view = new app.newsView({ el : '#new-features', 'collection' : app.collections.news });
        app.collections.news.fetch({ reset : true });

        app.collections.past = new app.meetingCollection();
        app.collections.upcoming = new app.meetingCollection(null,{ override_endpoint : 'meetings_and_suggestions' });
        app.collections.highlights = new app.meetingCollection(null,{ override_endpoint : 'highlights' });
        app.collections.unscheduled = new app.meetingCollection(null,{ override_endpoint : 'unscheduled_meetings' });

        // Collections generated from upcoming meetings
        app.collections.today = new app.meetingCollection();
        app.collections.this_week_meetings = new app.meetingCollection();
        app.collections.next_week_meetings = new app.meetingCollection();
        app.collections.all_future = new app.meetingCollection();

        // Collections generated from past meetings
        app.collections.yesterday = new app.meetingCollection();
        app.collections.this_week_past = new app.meetingCollection();
        app.collections.last_week_past = new app.meetingCollection();
        app.collections.all_past = new app.meetingCollection();

        // Header
        app.views.header = new app.headerView({ el : '#header-wrapper', model : app.models.user });
        app.models.user.fetch({ reset : true });

        // Footer
        app.views.footer = new app.footerView({ el : '#bb-footer', type : 'normal' });

        if( dicole.get_global_variable('meetings_show_calendar_connect') ) {
            app.router.googleConnecting();
        } else {
            app.router.upcoming();
        }
    },

    init_backbone : function() {

        app.helpers.populateVendors();

        app.helpers.setLangParams();

        app.helpers.setupUserAuth();

        app.router = new app.backboneRouter();

        // Hack to get fragments working on non history supporting devices
        Backbone.history.start({pushState: Modernizr.history, silent: true});
        if(!Modernizr.history) {
            Backbone.history.navigate( window.location.pathname.substr(Backbone.history.options.root.length), { trigger: true } );
            window.location.hash = "";
        } else {
            Backbone.history.loadUrl(Backbone.history.getFragment());
        }
    },

    init_meeting : function() {

        app.helpers.setLangParams();

        // Get globals
        app.helpers.setupUserAuth();
        app.defaults.file_save_url = dicole.get_global_variable('meetings_add_material_from_draft_url');

        // Init views & models
        app.views.material_uploader = new app.meetingMaterialUploadsView({  el : '#material-uploads' });
        app.models.meeting = new app.meetingModel({ id : dicole.get_global_variable('meetings_meeting_id') });
        app.models.user = new app.userModel({ id : app.auth.user });
        app.views.meeting_top = new app.meetingTopView({ el : '#meeting-top', model : app.models.meeting });

        app.collections.news = new app.newsCollection();
        app.collections.news.url = '/apigw/v1/users/' + app.auth.user + '/news';
        app.views.news_view = new app.newsView({ el : '#new-features', 'collection' : app.collections.news });
        app.collections.news.fetch({ reset : true });

        // Header
        app.views.header = new app.headerView({ el : '#header-wrapper', model : app.models.user });
        app.models.user.fetch({ reset : true });

        // Footer
        app.views.footer = new app.footerView({ el : '#bb-footer', type : 'normal' });

        this.helpers.keepBackgroundCover();
    },

    init_ext : function(view_type) {
        view_type = view_type || 'ext';

        app.helpers.setLangParams();
        app.helpers.setupUserAuth();

        // Show header if we got logged in user and are in matchmaking success
        if( app.auth.user && $('body').hasClass('action_meetings_task_matchmaking_success') ) {
            app.models.user = new app.userModel({ id : app.auth.user });
            app.views.header = new app.headerView({ el : '#header-wrapper', model : app.models.user, type : 'normal' });
            app.models.user.fetch({ reset : true });
        } else {
            app.views.header = new app.headerView({ el : '#header-wrapper', type : view_type });
        }

        app.views.footer = new app.footerView({ el : '#bb-footer', type : view_type });
    }
};
