/* Import plugin specific language pack */
tinyMCE.importPluginLanguagePack('dicole', 'en,fi'); // <- Add a comma separated list of all supported languages

// Singleton class
var TinyMCE_DicolePlugin = {
	getInfo : function() {
		return {
			longname : 'Dicole plugin',
			author : 'Antti Vähäkotamäki',
			authorurl : 'http://www.dicole.com',
			version : "1.0"
		};
	},

	initInstance : function(inst) {
		// You can take out plugin specific parameters
        var dialogs = tinyMCE.getParam("dicole_dialogs", false);

        if ( dialogs.indexOf('wiki') != -1 ) {
//		  inst.addShortcut('ctrl', 'p', 'lang_add_wiki_desc',
//                 'mceAddWikiPAge');
        }
	},

	getControlHTML : function(cn) {
		switch (cn) {
			case "dicole_wiki":
				return tinyMCE.getButtonHTML(cn, 'lang_dicole_wiki_desc', '{$pluginurl}/images/wiki.gif', 'mceDicoleWiki', true);
            case "dicole_file":
                return tinyMCE.getButtonHTML(cn, 'lang_dicole_file_desc', '{$pluginurl}/images/file.gif', 'mceDicoleFile', true);
            case "dicole_image":
                return tinyMCE.getButtonHTML(cn, 'lang_dicole_image_desc', '{$pluginurl}/images/image.gif', 'mceDicoleImage', true);
            case "dicole_cancel":
                return tinyMCE.getButtonHTML(cn, 'lang_dicole_cancel_desc', '{$pluginurl}/images/cancel.gif', 'mceDicoleCancel', true);
            case "dicole_save":
                return tinyMCE.getButtonHTML(cn, 'lang_dicole_save_desc', '{$pluginurl}/images/save.gif', 'mceDicoleSave', true);
		}

		return "";
	},

	execCommand : function(editor_id, element, command, user_interface, value) {
		// Handle commands
		switch (command) {
			// Remember to have the "mce" prefix for commands so they don't intersect with built in ones in the browser.
            case "mceDicoleSave":
                _save_wiki_edit();
                return true;
            case "mceDicoleCancel":
                _cancel_wiki_edit();
                return true;
			case "mceDicoleWiki":
				// Show UI/Popup
                // Largely copied from tinymce mceLink

                var inst = tinyMCE.getInstanceById(editor_id);
                var doc = inst.getDoc();
                var selectedText = "";

                if (tinyMCE.isMSIE) {
                    var rng = doc.selection.createRange();
                    selectedText = rng.text;
                } else
                    selectedText = inst.getSel().toString();

                if (!tinyMCE.linkElement) {
                    if ((tinyMCE.selectedElement.nodeName.toLowerCase() != "img") && (selectedText.length <= 0))
                        return true;
                }

                var title = "";

                if (tinyMCE.selectedElement.nodeName.toLowerCase() == "a")
                    tinyMCE.linkElement = tinyMCE.selectedElement;

                // Is anchor not a link
                if (tinyMCE.linkElement != null && tinyMCE.getAttrib(tinyMCE.linkElement, 'href') == "")
                    tinyMCE.linkElement = null;

                if (tinyMCE.linkElement) {
                    var button_id = editor_id + '_dicole_wiki';
                    var aclass = tinyMCE.getAttrib( 
                        document.getElementById(button_id), "class"
                    );
                    if ( aclass && aclass.indexOf('mceButtonDisabled') != -1 )
                        return false;

                    title = tinyMCE.getAttrib(tinyMCE.linkElement, 'title');
                }
                else {
                    title = selectedText;
                }

                TinyMCE_DicolePlugin._open_window(
                    'wiki_popup/tinymce_select_page/',
                    {'title' : title}
                );

                return true;

            case "mceDicoleFile":
                // Show UI/Popup
                // Largely copied from tinymce mceLink

                var inst = tinyMCE.getInstanceById(editor_id);
                var doc = inst.getDoc();
                var selectedText = "";

                if (tinyMCE.isMSIE) {
                    var rng = doc.selection.createRange();
                    selectedText = rng.text;
                } else
                    selectedText = inst.getSel().toString();

                if (!tinyMCE.linkElement) {
                    if ((tinyMCE.selectedElement.nodeName.toLowerCase() != "img") && (selectedText.length <= 0))
                        return true;
                }

                var href = "";

                if (tinyMCE.selectedElement.nodeName.toLowerCase() == "a")
                    tinyMCE.linkElement = tinyMCE.selectedElement;

                // Is anchor not a link
                if (tinyMCE.linkElement != null && tinyMCE.getAttrib(tinyMCE.linkElement, 'href') == "")
                    tinyMCE.linkElement = null;

                if (tinyMCE.linkElement) {
                    var button_id = editor_id + '_dicole_file';
                    var aclass = tinyMCE.getAttrib( 
                        document.getElementById(button_id), "class"
                    );
                    if ( aclass && aclass.indexOf('mceButtonDisabled') != -1 )
                        return false;

                    href = tinyMCE.getAttrib(tinyMCE.linkElement, 'href');
                }

                var urltarget = 'personal';
                if ( content_data.group_id ) {
                    urltarget = 'group';
                }

                TinyMCE_DicolePlugin._open_window(
                    urltarget + '_files_popup/tinymce_select_file/',
                    {
                        target_id : content_data.group_id,
                        href : href
                    }
                );

                return true;

            case "mceDicoleImage":
                // Show UI/Popup
                // Largely copied from tinymce mceImage

                var src = "", alt = "", align = "";

                var img = tinyMCE.imgElement;
                var inst = tinyMCE.getInstanceById(editor_id);

                if (tinyMCE.selectedElement != null && tinyMCE.selectedElement.nodeName.toLowerCase() == "img") {
                    img = tinyMCE.selectedElement;
                    tinyMCE.imgElement = img;
                }

                if (img) {
                    // Is it a internal MCE visual aid image, then skip this one.
                    if (tinyMCE.getAttrib(img, 'name').indexOf('mce_') == 0)
                        return true;

                    src = tinyMCE.getAttrib(img, 'src');
                    alt = tinyMCE.getAttrib(img, 'alt');

                    // Try polling out the title
                    if (alt == "")
                        alt = tinyMCE.getAttrib(img, 'title');

                    align = tinyMCE.getAttrib(img, 'align');
                }

                var urltarget = 'personal';
                if ( content_data.group_id ) {
                    urltarget = 'group';
                }

                TinyMCE_DicolePlugin._open_window(
                    urltarget + '_files_popup/tinymce_select_image/',
                    {
                        target_id : content_data.group_id,
                        src : src,
                        alt : alt,
                        align : align
                    }
                );

                return true;

        }
		// Pass to next handler in chain
		return false;
	},

	handleNodeChange : function(editor_id, node, undo_index, undo_levels, visual_aid, any_selection) {
        // Set defaults
        tinyMCE.switchClass(editor_id + '_dicole_wiki', 'mceButtonDisabled');
        tinyMCE.switchClass(editor_id + '_dicole_file', 'mceButtonDisabled');
        tinyMCE.switchClass(editor_id + '_dicole_image', 'mceButtonNormal');

        // Select wiki or link button if parent node is a link
        var alink = tinyMCE.getParentElement(node, "a");

        if ( alink ) {
            if ( alink.className &&
                 alink.className.indexOf('wikiLink') != -1 ) {
                tinyMCE.switchClass(editor_id + '_dicole_wiki',
                    'mceButtonSelected');
            }
            else {
                tinyMCE.switchClass(editor_id + '_dicole_file',
                    'mceButtonSelected');
            }
        }
        else if ( any_selection ) {
            tinyMCE.switchClass(editor_id + '_dicole_wiki',
                'mceButtonNormal' );
            tinyMCE.switchClass(editor_id + '_dicole_file',
                'mceButtonNormal' );
        }

        var imgnode = tinyMCE.getParentElement(node, "img");
        if ( imgnode ) {
            tinyMCE.switchClass(editor_id + '_dicole_image',
                'mceButtonSelected' );
        }

        // This happens faster than any timeout but timeout
        // is still nice at least for the initialization
        // where content is not necessarily reported correctly
        // TODO: This should be prefixed some day..

        if ( ! tinyMCE.getParam("dicole_disable_resize", false) ) {
            _resize_editor();
        }
	},

	/*	setupContent : function(editor_id, body, doc) {
	},
*/
	/*	onChange : function(inst) {
	},
*/
	/*	handleEvent : function(e) {
		// Display event type in statusbar
		top.status = "template plugin event: " + e.type;

		return true; // Pass to next handler
	},
*/
	/*	cleanup : function(type, content, inst) {
		switch (type) {
			case "get_from_editor":
				alert("[FROM] Value HTML string: " + content);

				// Do custom cleanup code here

				break;

			case "insert_to_editor":
				alert("[TO] Value HTML string: " + content);

				// Do custom cleanup code here

				break;

			case "get_from_editor_dom":
				alert("[FROM] Value DOM Element " + content.innerHTML);

				// Do custom cleanup code here

				break;

			case "insert_to_editor_dom":
				alert("[TO] Value DOM Element: " + content.innerHTML);

				// Do custom cleanup code here

				break;
		}

		return content;
	},
*/
	// Private plugin internal methods

    _open_window : function( url, params ) {
        var template = new Array();

        template['file'] = OIPath_dep +
            url + DicoleTargetId + '/';
        template['width'] = 640;
        template['height'] = 480;
        params['resizable'] = 'yes';
        params['scrollbars'] = 'yes';

        tinyMCE.openWindow(template, params);

        tinyMCE.triggerNodeChange(false);
    }
};

// Adds the plugin class to the list of available TinyMCE plugins
tinyMCE.addPlugin("dicole", TinyMCE_DicolePlugin);
