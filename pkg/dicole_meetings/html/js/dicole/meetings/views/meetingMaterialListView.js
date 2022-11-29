dojo.provide("dicole.meetings.views.meetingMaterialListView");

app.meetingMaterialListView = Backbone.View.extend({

    initialize : function(options) {
    },

    render : function() {
        // Setup template
        this.$el.html( templatizer.meetingMaterials() );

        // Setup dragging
        /*

          $('.material-item').each(function(){
          this.setAttribute('draggable', 'true');

          $(this).bind( 'dragstart', function (e) {
          console.log('dragstart');
          e.originalEvent.dataTransfer.effectAllowed = 'move'; // only dropEffect='copy' will be dropable
          e.originalEvent.dataTransfer.setData('Text', this.id); // required otherwise doesn't work

        // Hide DnD upload, show trash
        $('#meeting-dropzone-container').slideToggle();
        $('#meeting-trash-container').slideToggle();

        });
        $(this).bind('dragend', function (e) {
        console.log('dragend');
        $('#meeting-dropzone-container').slideToggle();
        $('#meeting-trash-container').slideToggle();
        });

        $(this).bind('dragenter', function (e) {
        });
        $(this).bind('dragleave', function (e) {
        });

        // Drop event for dropping on materials
        $(this).bind('drop', function (e) {
        console.log('drop on material');
        e.preventDefault();
        var drop_target = $(this);
        // Get the dragged element
        var dropped_item = $('#'+e.originalEvent.dataTransfer.getData('Text'));

        // do nothing if dropped on self
        if(dropped_item.attr('id') == drop_target.attr('id')) return;

        // Detatch
        var saved = dropped_item.detach();

        // Append/prepend dragged
        if(drop_target.attr('data-order-num') > dropped_item.attr('data-order-num')){
        drop_target.after(saved);
        }
        else{
        drop_target.before(saved);
        }
        dicole.meetings.fixMaterialList();
        });
        });*/

             },
events : {
         }
});
