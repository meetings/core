dojo.provide("dicole.meetings.views.meetingMaterialUploadsView");

app.meetingMaterialUploadsView = Backbone.View.extend({

    initialize : function(options) {
    },

    render : function() {
        if ( ! dicole.get_global_variable('meetings_user_can_add_material') ) {
            this.$el.remove();
            return;
        }

        // Setup template
        this.$el.html( templatizer.meetingMaterialUploads() );

        if(dicole.meetings.IEVersion() <= 9) this.$el.addClass('no-dnd-support');

        // dicole.meetings.using_mobile
        var upload_url = dicole.get_global_variable( "draft_attachment_fileapi_url" );

        // Prevend default dnd
        $(document).bind('drop dragover', function (e) {
            e.preventDefault();
        });

        // Bind drag indicators
        this.$el.bind('dragover', function(e) {
            e.preventDefault();
            $(this).addClass('active');
        });
        this.$el.bind('dragenter', function(e) {
            $(this).addClass('active');
        });
        this.$el.bind('dragleave', function(e) {
            $(this).removeClass('active');
        });


        // Setup uploader
        var params = {
            paramname : 'file',
            maxNumberOfFiles : 10,
            dropZone : this.$el,
            formData : {
                user_id : app.auth.user,
                dic : app.auth.token
            },
            maxfilesize:5000000 , // 50 in mb
            url : app.defaults.api_host + '/v1/uploads',
            done : function(e,data){
                $('#progress-text').text('Upload done, processing...');
                $.post( app.defaults.file_save_url, { draft_id : data.response().result.result.upload_id }, function( response ) {
                        dicole.meetings.refresh_material_list( false, false, function() {
                            $('#progress-text').text('Drag & drop materials here');
                            $('#progress-bar').css('display','none');
                        } );
                });
            },
            add: function (e, data) {
                data.submit();
            },
            start:function(e){
                $('#material-uploads').removeClass('active');
                $('#progress-bar').css('display','block');
            },
            progressall: function(e, data) {
                var progress = parseInt(data.loaded / data.total * 100, 10);
                progress += '%';
                $('#progress-text').text('Uploading ' + progress);
                $('#progress-bar').css('width', progress);
            }
        };
        $('#material-upload-button').fileupload( params );
    },
    events : {
    }
});

