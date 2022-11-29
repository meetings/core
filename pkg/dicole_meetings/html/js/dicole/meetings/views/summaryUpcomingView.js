dojo.provide("dicole.meetings.views.summaryUpcomingView");

app.summaryUpcomingView = Backbone.View.extend({

    initialize : function(options) {
    },

    hide_loader : function(){
        $('.loader' , this.el ).remove();
        $('.tab-items', this.el).fadeIn();
    },

    try_to_hide_loader : _.after(3, function(){
        app.views.current.hide_loader();
    }),

    render : function() {

        // Setup template
        this.$el.html( templatizer.summaryUpcoming( { google_connected : dicole.get_global_variable('meetings_google_connected') , google_connect_url : dicole.get_global_variable('meetings_google_connect_url') }) );

        // Keep content el height
        app.helpers.keepBackgroundCover();

        // Show loader
        var spinner = new Spinner(app.defaults.spinner_opts).spin( $('.loader' , this.el )[0] );

        // Setup sub views
        app.views.unscheduled = new app.baseCollectionView({
            collection : app.collections.unscheduled,
            childViewConstructor : app.summaryMeetingView,
            childViewTagName : 'a',
            el : $('#upcoming-scheduling'),
            infiniScroll : false,
            showTimestamps : false,
            badgeHtml : '<div class="badge bl" title="'+MTN.t('Scheduling')+'"><i class="ico-schedule"></i></div>'
        });

        app.views.highlights = new app.baseCollectionView({
            collection : app.collections.highlights,
            childViewConstructor : app.summaryHighlightView,
            childViewTagName : 'a',
            showTimestamps : false,
            el : $('#upcoming-highlights'),
            infiniScroll : false,
            badgeHtml : '<div class="badge red" title="'+MTN.t('Tasks')+'"><i class="ico-note"></i></div>'
        });

        app.views.today = new app.baseCollectionView({
            collection : app.collections.today,
            childViewConstructor : app.summaryMeetingView,
            childViewTagName : 'a',
            el : $('#upcoming-today'),
            badgeHtml : '<div class="badge green" title="'+MTN.t('Today')+'"><i class="ico-star"></i></div><h3 class="section-head">'+MTN.t('Today')+'</h3>'
        });

        app.views.this_week = new app.baseCollectionView({
            collection : app.collections.this_week_meetings,
            childViewConstructor : app.summaryMeetingView,
            childViewTagName : 'a',
            el : $('#upcoming-this-week'),
            badgeHtml : '<div class="badge yellow" title="'+MTN.t('This week')+'"><i class="ico-up"></i></div><h3 class="section-head">'+MTN.t('This week')+'</h3>'
        });

        app.views.next_week = new app.baseCollectionView({
            collection : app.collections.next_week_meetings,
            childViewConstructor : app.summaryMeetingView,
            childViewTagName : 'a',
            el : $('#upcoming-next-week'),
            badgeHtml : '<div class="badge orange" title="'+MTN.t('Next week')+'"><i class="ico-up"></i></div><h3 class="section-head">'+MTN.t('Next week')+'</h3>'
        });

        app.views.all_future = new app.baseCollectionView({
            collection : app.collections.all_future,
            name : 'future',
            childViewConstructor : app.summaryMeetingView,
            childViewTagName : 'a',
            el : $('#upcoming-future'),
            badgeHtml : '<div class="badge oranger" title="'+MTN.t('Future')+'"><i class="ico-up"></i></div><h3 class="section-head">'+MTN.t('Future')+'</h3>'
        });
    }
});

