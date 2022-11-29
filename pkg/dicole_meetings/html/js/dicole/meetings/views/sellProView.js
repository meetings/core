dojo.provide("dicole.meetings.views.sellProView");

app.sellProView = Backbone.View.extend({

    initialize : function(options) {
        _(this).bindAll('render','startTrial','startSubscription','paymentReceived','pollForPayment','continueProcess','cancelPayment');
        this.mode = options.mode || 'default';
        this.callback = options.callback;
        this.upgrade_url = '/meetings/upgrade';
        this.model.url = app.defaults.api_host + '/v1/users/' + this.model.get('id');
        this.payment_canceled = false;
        this.render();
    },

    events : {
        'click .start-trial' : 'startTrial',
        'click .start-subscription' : 'startSubscription',
        'click .close' : 'close',
        'click .continue' : 'continueProcess',
        'click .cancel-payment' : 'cancelPayment'
    },

    render : function() {

        var showcase = dicole.create_showcase({
            "disable_close" : true,
            "content" : '<div class="sell-pro-temp"></div>'
        });


        if( this.mode === 'trial_ending' || this.mode === 'upgrade_now' ) {
            this.$el.html( templatizer.sellSubscription( { mode : this.mode }) );
        }
        else if( this.model.get('free_trial_has_expired') ) {
            this.$el.html( templatizer.sellSubscription( { mode : this.mode }) );
        }
        else {
            this.$el.html( templatizer.startTrial( { mode : this.mode }) );
        }
        $('.sell-pro-temp').html(this.el);
    },

    startTrial : function(e) {
        e.preventDefault();
        var _this = this;
        $(e.currentTarget).text( MTN.t('Starting...') );
        this.model.startTrial(function() {
            dojo.publish('showcase.close');
            if(_this.callback) _this.callback();
        });
    },

    paymentReceived : function() {
        this.$el.html( templatizer.thanksForPaying() );
    },

    continueProcess : function(e) {
        if(this.callback) this.callback();
        dojo.publish('showcase.close');
    },

    startSubscription : function(e) {
        e.preventDefault();
        var _this = this;
        this.$el.html( templatizer.waitingForPayment({ upgrade_url : this.upgrade_url }) );
        this.pollForPayment();
        setTimeout( function() {
            var win=window.open(_this.upgrade_url, '_blank');
            win.focus();
        }, 50);
    },

    pollForPayment : function() {
        _this = this;
        this.model.fetch({ success : function(m,r) {
            if( _this.payment_canceled ) {
                return;
            }
            if( m.get('is_pro') ) {
                _this.paymentReceived();
            }
            else {
                setTimeout( _this.pollForPayment, 5000 );
            }
        }});
    },

    cancelPayment : function(e) {
        e.preventDefault();
        this.payment_canceled = true;
        dojo.publish('showcase.close');
    },

    close : function(e) {
        e.preventDefault();
        dojo.publish('showcase.close');
    }
});

