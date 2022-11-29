
tinyMCE.init( {
    mode: "specific_textareas",
    editor_selector : "mceEditor",
    language : tinymce3_data.language,

    theme : "advanced",
    theme_advanced_layout_manager : "RowLayout",
    theme_advanced_row_height: 0,
    theme_advanced_containers : 'main,attachment,link,advanced,table,html,showroom,image,mceeditor,mceelementpath',

    theme_advanced_container_main_class : 'tinymce_toolbar_container tinymce_toolbar_container_main',
    theme_advanced_container_main :  'formatselect,bold,italic,strikethrough,bullist,numlist,dicole_attachment_open,dicole_link_open,unlink,dicole_advanced_open',

    theme_advanced_container_attachment_class : 'tinymce_toolbar_container tinymce_toolbar_container_attachment tinymce_toolbar_modal hiddenBlock',
    theme_advanced_container_attachment :  'dicole_attachment_container',

    theme_advanced_container_link_class : 'tinymce_toolbar_container tinymce_toolbar_container_link tinymce_toolbar_modal hiddenBlock',
    theme_advanced_container_link :  'dicole_link_container',

    theme_advanced_container_advanced_class : 'tinymce_toolbar_container tinymce_toolbar_container_advanced hiddenBlock',
    theme_advanced_container_advanced :  'forecolor,backcolor,outdent,indent,dicole_justify_left,dicole_justify_center,dicole_table_open,dicole_html_open,dicole_showroom_open,dicole_image_open,removeformat,unlink',

    theme_advanced_container_table_class : 'tinymce_toolbar_container tinymce_toolbar_container_table hiddenBlock',
    theme_advanced_container_table :  'tablecontrols',

    theme_advanced_container_html_class : 'tinymce_toolbar_container tinymce_toolbar_container_html tinymce_toolbar_modal hiddenBlock',
    theme_advanced_container_html :  'dicole_html_container',

    theme_advanced_container_showroom_class : 'tinymce_toolbar_container tinymce_toolbar_container_showroom tinymce_toolbar_modal hiddenBlock',
    theme_advanced_container_showroom :  'dicole_showroom_container',

    theme_advanced_container_image_class : 'tinymce_toolbar_container tinymce_toolbar_container_image tinymce_toolbar_modal hiddenBlock',
    theme_advanced_container_image :  'dicole_image_container',

    theme_advanced_container_mceeditor :  'mceEditor',
    theme_advanced_container_mceelementpath :  'mceElementPath',
    
    theme_advanced_resizing : true,
    theme_advanced_resize_horizontal : false,

    relative_urls : false,
    remove_script_host : true,
    document_base_url : tinymce3_data.document_base_url,

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
