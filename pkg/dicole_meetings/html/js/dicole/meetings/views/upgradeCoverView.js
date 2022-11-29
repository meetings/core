dojo.provide("dicole.meetings.views.upgradeCoverView");

app.upgradeCoverView = Backbone.View.extend({

    initialize : function(options) {
        _(this).bindAll('render');
        this.paypal_url = dicole.get_global_variable('meetings_start_basic_purchase_url');
        this.model.url = app.defaults.api_host + '/v1/users/' + this.model.get('id');
        this.prefered_vendor = options.prefered_vendor || false;
    },

    events : {
        'click .vendor-link' : 'switchVendor',
        'click .open-pay' : 'payNow'
    },

    render : function() {
        this.$el.html( templatizer.upgradeCover({ prefered_vendor : this.prefered_vendor }) );
    },

    payNow : function(e) {
        e.preventDefault();
        var type = $(e.currentTarget).attr('data-payment-type');
        app.router.navigate('/meetings/upgrade/pay/' + type,{ trigger : true });
    },

    switchVendor : function(e) {
        e.preventDefault();
        app.router.navigate($(e.currentTarget).attr('href'), { trigger : true });
    }
});

