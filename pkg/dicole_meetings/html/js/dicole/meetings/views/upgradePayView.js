dojo.provide("dicole.meetings.views.upgradePayView");

app.upgradePayView = Backbone.View.extend({

    initialize : function(options) {
        _(this).bindAll('render','payNow','checkForm','updatePrice');
        this.model.bind('change', _.bind(this.render, this));
        this.type = options.type;
        this.preset_coupon = options.preset_coupon;
    },

    events : {
        'click .pay-now' : 'payNow',
        'click #cc-vat-check' : 'toggleVat',
        'change input' : 'checkForm',
        'paste input' : 'checkForm',
        'keyup input' : 'checkForm',
        'blur input' : 'removePristinity',
        'blur #cc-vat' : 'updatePrice',
        'blur #cc-coupon' : 'updatePrice',
        'keyup #cc-coupon' : 'updatePrice'
    },

    prices : {
        yearly : {
            norm : {
                price : '$129',
                price_reverse : '$104,03',
                tax : '$24,97'
            },
            '7dcc613e0d6a30b146ab079450c66f00' : {
                price : '$96,75',
                price_reverse : '$78,02',
                tax : '$18,73'
            }
        },

        monthly : {
            norm : {
                price : '$12',
                price_reverse : '$9,68',
                tax : '$2,32'
            }
        }
    },

    eu_countries : ['AT', 'BE', 'BG', 'CY', 'CZ', 'DE', 'DK', 'EE', 'ES', 'FI', 'FR', 'GB', 'GR', 'HU', 'IE', 'IT', 'LT', 'LU', 'LV', 'MT', 'NL', 'PL', 'PT', 'RO', 'SE', 'SI', 'SK'],
    eu_countries_without_personal : ['AT', 'BE', 'BG', 'CY', 'CZ', 'DE', 'DK', 'EE', 'ES', 'FR', 'GB', 'GR', 'HU', 'IE', 'IT', 'LT', 'LU', 'LV', 'MT', 'NL', 'PL', 'PT', 'RO', 'SE', 'SI', 'SK'],

    render : function() {
        var _this = this;

        this.$el.html( templatizer.upgradeForm( { user : this.model.toJSON(), type : this.type, preset_coupon : this.preset_coupon }) );

        // Load stripe
        $.getScript("https://js.stripe.com/v2/", function(){
            Stripe.setPublishableKey( dicole.get_global_variable('meetings_stripe_key') );
        });

        // Setup card formattings
        $('input#cc-num').payment('formatCardNumber');
        $('input#cc-exp').payment('formatCardExpiry');
        $('input#cc-cvc').payment('formatCardCVC');

        // Setup country dropdown
        $('#cc-country').chosen().change(function(){
            _this.checkForm();
        });

        app.helpers.keepBackgroundCover();

        if( this.preset_coupon ) {
            var that = this;
            this.updateTokens( function() {
                that.checkForm();
                that.updatePrice();
            } );
        }
        else {
            this.updateTokens( function() {} );
        }
    },

    updateTokens : function( done ) {
        var that = this;
        $.get('/apigw/v1/coupons', function(res) {
            if ( res && res.monthly ) {
                _.each( res.monthly, function( value, key ) {
                    that.prices.monthly[ key ] = value;
                } )
            }
            if ( res && res.yearly ) {
                _.each( res.yearly, function( value, key ) {
                    that.prices.yearly[ key ] = value;
                } )
            }
            done();
        });
    },

    toggleVat : function(e) {
        $('.js-vat-wrap').slideToggle();
    },

    removePristinity : function(e) {
        $(e.currentTarget).addClass('modified');
    },

    updatePrice : function(e) {
        var _this = this;
        var $vat = $('#cc-vat');
        var vat = $vat.val();
        var vat_country = vat.substring(0,2).toUpperCase();
        var $coupon = $('#cc-coupon');
        var $price = $('#cc-price');
        var $reverse_tax = $('#cc-reverse-tax');
        var price_key = 'norm';

        // Check for valid coupon
        if( $coupon.val() && this.prices[this.type][$.md5($coupon.val())] ) {
            price_key = $.md5( $coupon.val() );
        }

        var def = $.Deferred().done(function( res ) {
            if( res  === true) {
                _this.payment_price = _this.prices[_this.type][price_key].price_reverse;
                _this.payment_tax = 0;
                $reverse_tax.show();
                $price.text( _this.payment_price );
            } else {
                $reverse_tax.hide();
                _this.payment_price = _this.prices[_this.type][price_key].price;
                _this.payment_tax = _this.prices[_this.type][price_key].tax;
                $price.text( _this.payment_price );
            }

            if( vat_country.match(/^[A-Za-z]+$/) && vat.length >= 4 ) {
                $vat.addClass('valid').parent('.field-wrap').addClass('valid').prev('label').addClass('valid');
                _this.checkForm();
            }
            else {
                $vat.removeClass('valid').parent('.field-wrap').removeClass('valid').prev('label').removeClass('valid');
                _this.checkForm();
            }
        });

        if( vat ) {
            $.get('/apigw/v1/reverse_tax_applicability/'+vat, function(res) {
                def.resolve(res);
            });
        } else {
            def.resolve(false);
        }
    },

    checkForm : function(e) {

        var requiredFields = 8;

        // Allow selecting checkbox with space
        if( typeof e !== 'undefined' && (e.currentTarget.id === 'cc-vat-check' || e.type === 'paste' ) ) {
            return true;
        }

        var $vat = $('#cc-vat');
        var vat_valid = false;

        if ( $vat.hasClass('valid') ) {
            vat_valid = true;
        }

        $('.error').removeClass('error');
        $('.valid').removeClass('valid');

        if ( vat_valid ) {
            $vat.addClass('valid').parent('.field-wrap').addClass('valid').prev('label').addClass('valid');
        }

        var errors = [];
        var valid = [];

        // Use cached jQ selectors
        var f = this.form || {};
        f.email = f.email || $('#cc-email');
        f.name = f.name || $('#cc-name');
        f.number = f.number || $('#cc-num');
        f.expiry = f.expiry || $('#cc-exp');
        f.cvc = f.cvc || $('#cc-cvc');
        f.company = f.company || $('#cc-company');
        f.vat = f.vat || $('#cc-vat');
        f.address = f.address || $('#cc-address1');
        f.city = f.city || $('#cc-city');
        f.zip = f.zip || $('#cc-zip');
        f.country = f.country || $('#cc-country');
        f.submit = f.submit || $('#cc-submit');
        f.coupon = f.coupon || $('#cc-coupon');

        // If no user, check email
        if( ! this.model || ! this.model.get('id') ) {
            requiredFields = 9;
            if( app.helpers.validEmail(f.email.val() || '') ) {
                valid.push('#cc-email');
            } else if( f.email.hasClass('modified') )  {
                errors.push('#cc-email');
            }
        }

        if( f.name.val() ) {
            valid.push('#cc-name');
        } else if( f.name.hasClass('modified') ) {
            errors.push('#cc-name');
        }

        var card_type = $.payment.cardType( f.number.val() );
        if( card_type ) {
            f.number.parent().addClass(card_type);
        }

        if( $.payment.validateCardNumber( f.number.val() ) ) {
            valid.push('#cc-num');
        } else if( f.number.hasClass('modified') ) {
            errors.push('#cc-num');
        }

        if( $.payment.validateCardExpiry(f.expiry.payment('cardExpiryVal').month, f.expiry.payment('cardExpiryVal').year) ) {
            valid.push('#cc-exp');
        } else if( f.expiry.hasClass('modified') ) {
            errors.push('#cc-exp');
        }

        if ( $.payment.validateCardCVC( f.cvc.val() )) {
            valid.push('#cc-cvc');
        } else if( f.cvc.hasClass('modified') ) {
            errors.push('#cc-cvc');
        }

        // Company is not required, so no need to show error
        // VAT id validation is done in it's own funciton
        if ( f.company.val() ) {
            valid.push('#cc-company');
        }

        if( f.address.val() ) {
            valid.push('#cc-address1');
        } else if( f.address.hasClass('modified') ){
            errors.push('#cc-address1');
        }

        if( f.city.val() ) {
            valid.push('#cc-city');
        } else if( f.city.hasClass('modified') ) {
            errors.push('#cc-city');
        }

        if( f.zip.val() && f.zip.val().length > 1 ) {
            valid.push('#cc-zip');
        } else if( f.zip.hasClass('modified') ) {
            errors.push('#cc-zip');
        }

        if( f.country.val() ) {
            valid.push('#cc-country');
        } else if( f.country.hasClass('modified') ) {
            errors.push('#cc-country');
        }

        if( f.coupon.val() && this.prices[this.type][$.md5( f.coupon.val() )] ) {
            valid.push('#cc-coupon');
        }

        // Extra error for EU countries if no valid VAT is input
        if( $.inArray(f.country.val(), this.eu_countries_without_personal) !== -1 && ! f.vat.hasClass('valid') ) {
            errors.push('#cc-vat-id-error');
        }
        else {
            valid.push('#cc-vat-id-error');
        }

        _.each( valid, function(e) {
            if(e === '#cc-vat-id-error') {
                $(e).hide();
            } else {
                $(e).parent('.field-wrap').addClass('valid').prev('label').addClass('valid');
            }
        });

        if( errors.length || valid.length < requiredFields ) {
            var first = true;
            _.each( errors, function(e) {
                if(e === '#cc-vat-id-error') {
                    $(e).show();
                } else {
                    $(e).parent('.field-wrap').addClass('error').prev('label').addClass('error');
                }
            });

            f.submit.addClass('disabled');
            return false;
        }

        f.submit.removeClass('disabled');

        return true;
    },

    payNow : function(e) {
        e.preventDefault();
        var _this = this;

        // Make all fields modified to trigger proper check
        $('input').addClass('modified');
        if( ! this.checkForm() || this.pay_lock ) return;
        this.updatePrice();
        this.pay_lock = true;

        var $button = new app.helpers.activeButton(e.currentTarget);

        // Save  card & get token
        Stripe.card.createToken({
            number : $('#cc-num').val(),
            cvc : $('#cc-cvc').val(),
            exp_month : $('#cc-exp').payment('cardExpiryVal').month,
            exp_year : $('#cc-exp').payment('cardExpiryVal').year,

            name : $('#cc-name').val(),
            address_line1 : $('#cc-address1').val(),
            address_line2 : $('#cc-address2').val(),
            address_city : $('#cc-city').val(),
            address_state : $('#cc-state').val(),
            address_zip : $('#cc-zip').val(),
            address_country: $('#cc-country').val()

        }, function(status, response) {
            var $form = $('#payment-form');
            var lang = _this.model.get('lang') || '';

            if (response.error) {
                _this.pay_lock = false;
                $button.reset();
                $('#cc-errors').html('<p class="error-message">'+MTN.t('There was an error processing the card. Please check the card details! If this problem persists, you should contact our %(L$support%).', { L : { 'class' : 'underline', href : 'https://support.meetin.gs/'+lang, target : '_blank' }})+'</p>');
            } else {
                var url = app.auth.user ? '/apigw/v1/users/'+app.auth.user+'/start_subscription' : '/apigw/v1/start_subscription';
                $.post(url, {
                    lang : dicole.get_global_variable('meetings_lang'),
                    token : response.id,
                    type : _this.type,
                    coupon : $('#cc-coupon').val(),
                    email : $('#cc-email').val(),
                    company : $('#cc-company').val(),
                    country: $('#cc-country').val(),
                    vat_id : $('#cc-vat').val()
                }, function(res) {
                    if( res && res.error ) {
                        _this.pay_lock = false;
                        $button.reset();
                        if( res.error.code === 2 ) {
                            if( app.auth.user ) {
                                $('#cc-errors').html('<p class="error-message">'+MTN.t('You seem to already have an active PRO subscription!')+'</p>');
                            } else {
                                $('#cc-errors').html('<p class="error-message">'+MTN.t('We seem to have an active PRO subscription associated with the provided email already! Please, %(L$log in%) and enjoy your PRO account.', { L : { 'class' : 'underline', href : '/meetings/login' }})+'</p>');
                            }
                        } else {
                            $('#cc-errors').html('<p class="error-message">'+MTN.t('There was an error processing the form. Please check your details! If this problem persists, you should contact our %(L$support%).', { L : { 'class' : 'underline', href : 'https://support.meetin.gs/'+lang, target : '_blank' }})+'</p>');
                        }
                    } else {
                        $button.setDone();

                        // Set globals for google tag manager
                        window.meetings_executed_payment_transaction_id = res.transaction_id;
                        window.meetings_executed_payment_price = _this.payment_price;
                        window.meetings_executed_payment_tax = _this.payment_tax;


                        app.router.navigate('/meetings/upgrade/success/' + _this.type, { trigger : true });
                    }
                });
            }
        });
    }
});
