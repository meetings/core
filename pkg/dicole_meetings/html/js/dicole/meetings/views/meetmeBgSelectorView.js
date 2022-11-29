dojo.provide("dicole.meetings.views.meetmeBgSelectorView");

app.meetmeBgSelectorView = Backbone.View.extend({

    initialize : function(options) {
        _(this).bindAll('render','setupFileUpload','closeModal','selectBg');
        this.uploadSaveCb = options.uploadSaveCb;
        this.themeSaveCb = options.themeSaveCb;
        this.render();
    },

    events : {
        'click .background' : 'selectBg',
        'click .close-modal' : 'closeModal'
    },

    render : function() {

        var showcase = dicole.create_showcase({
            "disable_close" : true,
            "content" : '<div class="tempcontainer"></div>'
        });

        var temp_model = {
            background_theme : this.model.get('background_theme') || this.model.get('meetme_background_theme'),
            background_preview_url : this.model.get('background_preview_url') || this.model.get('meetme_background_preview_url'),
            background_upload_id : this.model.get('background_upload_id') || this.model.get('meetme_background_upload_id'),
            background_image_url : this.model.get('background_image_url') || this.model.get('meetme_background_image_url')
        };

        // Render main template
        this.$el.html( templatizer.meetmeBgSelector( { model : temp_model }) );
        $('.tempcontainer').html(this.el);

        this.setupFileUpload();
    },

    selectBg : function(e) {
        e.preventDefault();

        // Clear all actives
        $('.background', this.el).removeClass('active');

        // Set selected as active
        var $el = $(e.currentTarget);
        $el.addClass('active');

        var id = $el.attr('data-theme-id');

        // Return if reselecting own custom uploaded image
        if( id === 'c' ) {
            dojo.publish('showcase.close');
            return;
        }

        // Show background
        this.themeSaveCb(this, id);
    },

    closeModal : function(e) {
        if(e) e.preventDefault();
        this.remove();
        dojo.publish('showcase.close');
    },

    setupFileUpload : function() {
        var _this = this;
        var $progress_bar = $('.progress-bar', this.el);
        var $progress_text = $('.progress-text', this.el);
        var $own_bg = $('#own-bg', this.el);
        var params = {
            paramname : 'file',
            maxNumberOfFiles : 1,
            dataType: 'json',
            formData : {
                user_id : app.auth.user,
                dic : app.auth.token,
                preview_image : 1,
                broken_ie : dicole.meetings.IEVersion() <= 9 ? 1 : 0 // Sets returned content type to text/html
            },
            maxfilesize:5000000 , // in mb
            url : app.defaults.api_host + '/v1/uploads',
            acceptFileTypes : /(\.|\/)(gif|jpe?g|png)$/i,

            done : function(e,data){
                $progress_text.text('Done.');
                $('.background').removeClass('active');
                $own_bg.attr('data-upload-id', data.result.result.upload_id )
                .addClass('active')
                .attr('data-upload-image', data.result.result.upload_preview_url )
                .css('background-image', 'url(' + data.result.result.upload_preview_url + ')' );
                $progress_bar.hide();
                setTimeout(function() {
                    $progress_text.text('Change background');
                }, 1000);

                _this.uploadSaveCb( _this, data );
            },

            add: function (e, data) {
                var regex = /(\.|\/)(jpg|jpeg|png|gif)$/i;
                if (!(regex.test(data.files[0].type) ||
                      regex.test(data.files[0].name))) {
                    alert('Oops, invalid filetype. Please use JPG or PNG format.');
                }
                else{
                    data.submit();
                    $own_bg.show();
                    $progress_bar.show();
                }
            },
            progressall: function(e, data) {
                var progress = parseInt(data.loaded / data.total * 100, 10);
                $progress_bar.css('width', progress + '%');
                $progress_text.text(progress + ' %');
            }
        };
        $('#fileupload-bg').fileupload( params );
    },


    beforeClose : function(){
        this.model.unbind();
    }
});

