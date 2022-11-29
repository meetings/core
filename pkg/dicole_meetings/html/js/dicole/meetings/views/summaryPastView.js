dojo.provide("dicole.meetings.views.summaryPastView");

app.summaryPastView = Backbone.View.extend({

    hide_loader : function(){
        $('.loader' , this.el ).remove();
        $('.tab-items', this.el ).fadeIn();
    },

    initialize: function(options) {
    },

    render: function() {

        this.$el.html( templatizer.summaryPast() );

        // Keep content height
        app.helpers.keepBackgroundCover();

        // Show loader
        var spinner = new Spinner(app.defaults.spinner_opts).spin( $('.loader' , this.el )[0] );

        app.views.yesterday = new app.baseCollectionView({
            collection : app.collections.yesterday,
            childViewConstructor : app.summaryMeetingView,
            childViewTagName : 'a',
            el : $('#past-yesterday'),
            badgeHtml : '<div class="badge gr" title="'+MTN.t('Yesterday')+'"><i class="ico-down1"></i></div><h3 class="section-head">'+MTN.t('Yesterday')+'</h3>'
        });

        app.views.past_this_week = new app.baseCollectionView({
            collection : app.collections.this_week_past,
            childViewConstructor : app.summaryMeetingView,
            childViewTagName : 'a',
            el : $('#past-this-week'),
            badgeHtml : '<div class="badge gr" title="'+MTN.t('This week')+'"><i class="ico-down1"></i></div><h3 class="section-head">'+MTN.t('This week')+'</h3>'
        });

        app.views.past_last_week = new app.baseCollectionView({
            collection : app.collections.last_week_past,
            childViewConstructor : app.summaryMeetingView,
            childViewTagName : 'a',
            el : $('#past-last-week'),
            badgeHtml : '<div class="badge gr" title="'+MTN.t('Last week')+'"><i class="ico-down1"></i></div><h3 class="section-head">'+MTN.t('Last week')+'</h3>'
        });

        var today = Math.floor( moment().startOf('day') / 1000 );
        app.views.past_all = new app.baseCollectionView({
            collection : app.collections.all_past,
            childViewConstructor : app.summaryMeetingView,
            childViewTagName : 'a',
            el : $('#past-all'),
            emptyString : '<div class="end">No more past meetings.</div>',
            badgeHtml : '<div class="badge gr" title="'+MTN.t('Past')+'"><i class="ico-down1"></i></div><h3 class="section-head">'+MTN.t('Past')+'</h3>',
            infiniScroll : true,
            infiniScrollExtraParams : { start_max : today, sort : "desc" }
        });

        return this;
    }
});
