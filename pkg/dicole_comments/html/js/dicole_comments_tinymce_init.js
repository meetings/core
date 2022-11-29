
function comments_tinymce_init() {

tinyMCE.init( {
    mode: "specific_textareas",
    editor_selector : "mceEditor",
    language : tinymce3_data.language,

    theme : "advanced",
    theme_advanced_layout_manager : "RowLayout",
    theme_advanced_row_height: 0,
    theme_advanced_containers : 'main,link,mceeditor,mceelementpath',

    theme_advanced_container_main_class : 'tinymce_toolbar_container tinymce_toolbar_container_main',
    theme_advanced_container_main :  'bold,italic,strikethrough,bullist,numlist,dicole_link_open,unlink,removeformat',

    theme_advanced_container_link_class : 'tinymce_toolbar_container tinymce_toolbar_container_link tinymce_toolbar_modal hiddenBlock',
    theme_advanced_container_link :  'dicole_link_container',

    theme_advanced_container_mceeditor :  'mceEditor',
    theme_advanced_container_mceelementpath :  'mceElementPath',
    
    theme_advanced_resizing : true,
    theme_advanced_resize_horizontal : false,

    relative_urls : false,
    remove_script_host : true,

    popups_css_add : "/css/default/main_markup.css,/css/default/main_layout.css",
    content_css : "/css/default/main_markup.css,/css/default/main_layout.css,/css/default/tinymce_content.css",

    plugins : "dicole,paste,table,inlinepopups",

    dicole_dialogs : "file,image",
    dicole_disable_resize : 1,

    paste_create_paragraphs : true,
    paste_create_linebreaks : true,
    paste_strip_class_attributes: 'all',
    paste_auto_cleanup_on_paste: true,

    handle_event_callback: function(event) {
        if(event.type == 'keydown') 
        {
            var code;
            if(event.keyCode) code = event.keyCode;
            else if(event.which) code = event.which;
            if(code == 9)
            {
                event.cancelBubble = true;
                event.returnValue = false;
                if(event.stopPropagation)
                {
                    event.preventDefault();
                    event.stopPropagation();
                }
                if(event.shiftKey) tinyMCE.activeEditor.execCommand('Outdent', false);
                else tinyMCE.activeEditor.execCommand('Indent', false);
                return false;
            }
            else if(code == 8 && (event.ctrlKey || event.metaKey))
            {
                event.cancelBubble = true;
                event.returnValue = false;
                if(event.stopPropagation)
                {
                    event.preventDefault();
                    event.stopPropagation();
                }
                tinyMCE.activeEditor.execCommand('Removeformat', false);
                return false;
            }
        }
        return true;
    },

    table_default_border: 2

} );
}

comments_tinymce_init();
