dojo.provide("dicole.meetings.views.meetmePresetFilesView");

app.meetmePresetFilesView = Backbone.View.extend({

    initialize : function(options) {
        _(this).bindAll('render','removeFile');
        this.render();
    },

    events : {
        'click .remove-file' : 'removeFile'
    },

    render : function() {

        var _this = this;

        // Init values
        if( ! this.model.get('preset_materials') ) {
            this.model.set('preset_materials', []);
        }

        this.$el.html( templatizer.meetmePresetFiles( this.model.toJSON() ) );

        // Setup file upload
        var params = {
            paramname : 'file',
            maxNumberOfFiles : 10,
            formData : {
                user_id : app.auth.user,
                dic : app.auth.token
            },
            maxfilesize:5000000 , // in mb
            url : app.defaults.api_host + '/v1/uploads',
            done : function(e,data){
                var $files = $('#material-list');
                var file = {
                    name : data.files[0].name,
                    upload_id : data.response().result.result.upload_id
                };
                _this.model.set('preset_materials', _this.model.get('preset_materials') || []);
                _this.model.get('preset_materials').push(file);
                $files.append('<li class="material" data-id="'+file.upload_id +'">'+file.name+' <i class="ico-cross remove-file"></i></li>');
                $('a#upload-button').removeClass('disabled');
                $('a#upload-button span.text').text('Upload another file');
            },
            start : function(e) {
                $('a#upload-button').addClass('disabled');
            },
            progressall : function(e, data) {
                var progress = parseInt(data.loaded / data.total * 100, 10);
                $('a#upload-button span.text').text('Uploading ' + progress + '%');
            }
        };
        $('#fileupload').fileupload( params );

    },

    updateModel : function(e) {
    },

    removeFile : function(e) {
        e.preventDefault();
        var $el = $(e.currentTarget).parent();
        var id = $el.attr('data-id');
        var materials = this.model.get('preset_materials');

        var found_index = false;
        _.each( materials, function(m,i) {
            if( ( m.upload_id && m.upload_id === id )|| ( m.attachment_id && m.attachment_id === id) ) {
                found_index = i;
            }
        });

        if( found_index !== false ) {
            this.model.get('preset_materials').splice(found_index, 1);
            $el.remove();
        }
    }

});

