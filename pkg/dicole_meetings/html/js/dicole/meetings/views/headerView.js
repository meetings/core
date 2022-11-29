dojo.provide("dicole.meetings.views.headerView");

app.headerView = Backbone.View.extend({
    subviews : {},
    initialize : function(options) {
        _(this).bindAll('render','setupDropdowns','refreshMeetingList','showSearch','setupSearch','setupNotifications');

        this.meeting_list_cache_hash = '';
        this.rendered = false;
        this.view_type = options.type || options.view_type || 'normal';

        if( this.model && this.model.get('id') && ! this.model.get('new_user_flow') ) {
            this.model.bind('change', this.render);
            dicole.event_source.subscribe( 'user_meeting_changes', { "limit_topics": [ [ "class:meetings_participant" ] ] }, this.refreshMeetingList );
            dojo.subscribe("meeting_removed_from_quickbar", this.refreshMeetingList );
            dojo.subscribe("meeting_added_to_quickbar", this.refreshMeetingList );
        } else {
            this.render();
        }
    },

    events : {
        'click #header-search' : 'showSearch',
        'click #header-cancel' : 'logout',
        'click #header-login' : 'login',
        'click #header-event-configure' : 'eventConfigure',
        'click .js-open-url' : 'openUrl'
    },

    logout : function(e) {
        e.preventDefault();
        window.location = '/meetings_global/logout';
    },

    login : function(e) {
        e.preventDefault();
        window.location = '/meetings/login?url_after_login=' + window.location.pathname;
    },

    eventConfigure : function(e) {
        e.preventDefault();
        window.location = dicole.get_global_variable('meetings_event_listing_registration_url');
    },

    render : function() {

        this.rendered = true;

        // User object
        var user = this.model ? this.model.toJSON() : {};

        var extra_meeting_links = dicole.get_global_variable('meetings_extra_meeting_links');
        if ( ! extra_meeting_links ) {
            extra_meeting_links = [];
        }

        // Draw base template
        this.$el.html( templatizer.headerBase( { user : user, meetings : {}, view_type : this.view_type, extra_meeting_links : extra_meeting_links, admin_return_link : dicole.get_global_variable('meetings_admin_return_link') } ) );

        // Setup dropdowns & search
        if( this.model && this.model.get('id') && ! this.model.get('new_user_flow') && ! (this.model.get('email_confirmed') === 0 || this.model.get('email_confirmed') === '0' )) {
            this.setupDropdowns();
            this.setupSearch();
            this.setupNotifications();
            dojo.publish("new_node_created", [ this.el ]);
        }
    },

    showSearch : function(e) {
        // TODO: HAndle case where no meetings to search from
        var $el = $(e.currentTarget);
        $el.find('.ico-search').hide();
        $('#header-quickbar').fadeIn('fast', function() {
            var $chosen_el = $('div#meetings_quickbar_chzn').trigger('mousedown');
            setTimeout( function() {
                $chosen_el.find('input').focus();
            },100);
        });
    },

    setupSearch : function() {
        var hide_lock = false;

        $.get('/apigw/v1/users/'+ this.model.get('id')+'/quickbar_meetings', function( data ) {
            // Draw meetings options && Setup chosen
            var $select = $('#meetings-quickbar').html( templatizer.headerSearchOptions( { meetings : data }) ).chosen().change(function( data ) {
                hide_lock = true;
                var option = $select[0].options[$select[0].selectedIndex];
                if ( option && option.value ) {
                    window.location = option.value;
                }
            });

            // Setup focus lost hiding for chosen
            $('#meetings_quickbar_chzn .chzn-search input').on('blur', function() {
                setTimeout( function() {
                    if( ! hide_lock ) {
                        $('#header-quickbar').fadeOut('fast', function() {
                            $('#header-search .ico-search').show();
                        });
                    }
                }, 200 );
            });
        });
    },

    setupNotifications : function() {
        app.collections.notifications = app.collections.notifications || new app.notificationCollection();
        app.collections.notifications.url = '/apigw/v1/users/' + app.auth.user + '/notifications';
        this.subviews.notifications = new app.notificationsView({ el : '#header-notifications-menu', collection : app.collections.notifications });
        app.collections.notifications.fetch({ reset : true });
    },

    refreshMeetingList : function() {
        if( ! this.rendered ) return;
        var _this = this;
        $.get('/apigw/v1/users/'+ this.model.get('id')+'/quickbar_meetings', function(data) {
            if (data.result && data.result_hash !== _this.meeting_list_cache_hash ) {
                // Update select options
                $('#meetings-quickbar').html( templatizer.headerSearchOptions({ meetings : data.result }) );

                // Tell chosen things changed
                $("#meetings-quickbar").trigger("chosen:updated");

                // Update cache hash
                _this.meeting_list_cache_hash = data.result_hash;
            }
        });
    },

    setupDropdowns : function() {
        $('#header-meeting-menu, #header-profile-menu, #header-notifications-menu').each(function() {
            var el = this;
            var $menu_el = $(el);
            var $other_menu_el = $('#header-meeting-menu, #header-profile-menu').not(el);

            var timer = 0;
            var opened_by_click = false;
            var id = $menu_el.attr('id');
            var x_adjust = $menu_el.attr('data-x-adjust');
            var $opener_el = $($menu_el.attr('data-open-selector'));

            $opener_el.click(function(e) {
                e.preventDefault();
                meetings_tracker.track(el);
                toggleMenu(e);
            }).mouseenter(function(e) {
                if( id === 'header-notifications-menu' ) return;
                toggleMenu(e);
            }).mouseleave(function(e) {
                if( id === 'header-notifications-menu' ) return;
                clearTimeout(timer);
                timer = setTimeout( function() {
                    $menu_el.fadeOut('fast').removeClass('open');
                }, 300 );
            });

            $menu_el.mouseenter(function(e) {
                clearTimeout(timer);
            }).mouseleave(function(e) {
                if( id === 'header-notifications-menu' ) return;
                clearTimeout(timer);
                timer = setTimeout( function(){
                    $menu_el.fadeOut('fast').removeClass('open');
                    opened_by_click = false;
                }, 300 );
            });

            var closeMenu = function() {
                if(! ( navigator.userAgent.match(/iPhone|iPad|iPod/i) ) ){
                    $menu_el.fadeOut('fast').removeClass('open');
                }
                else{
                    $menu_el.hide().removeClass('open');
                }
            };
            var openMenu = function() {
                // Close on outside click
                setTimeout(function() {
                    $("html").on('click', function(e) {
                        var t = $( e.target );
                        if ( !( t.is("#"+id ) || t.parents( "#"+id ).length > 0) ) {
                            $menu_el.hide().removeClass('open');
                            $("html").off('click');
                        }
                    });
                }, 100);

                if(! ( navigator.userAgent.match(/iPhone|iPad|iPod/i) ) ){
                    $menu_el.fadeIn('fast').addClass('open');
                }
                else{
                    $menu_el.show().addClass('open');
                }
            };

            var toggleMenu = function(e) {
                if( timer !== 0 ) {
                    clearTimeout(timer);
                    timer = 0;
                }
                $other_menu_el.hide();
                var posx = $opener_el.offset().left;
                var posy = $opener_el.position().top;
                $menu_el.css({ left : Math.ceil(posx - parseInt(x_adjust)) +'px', top : Math.ceil(posy + 45 ) +'px' });

                // Hack to mark as read and todo: refactor
                if( id === 'header-notifications-menu' ) {
                    app.collections.notifications.trigger('all_seen');
                }

                if( $menu_el.hasClass('open') ) {
                    if( ! opened_by_click && e.type === 'click' ) {
                        opened_by_click = true;
                        e.stopPropagation();
                        return;
                    }
                    opened_by_click = false;
                    closeMenu(e);
                }
                else{
                    if( e && e.type === 'click' ) opened_by_click = true;
                    openMenu(e);
                }
            };
        });
    },

    openUrl : function(e) {
        e.preventDefault();
        var url = $(e.currentTarget).attr('href');
        if( app.router && app.router.navigate ) {
            app.router.navigate(url, { trigger : true });
        } else {
            window.location.href = url;
        }
    }
});
