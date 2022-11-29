/**
 * $RCSfile: editor_plugin_src.js,v $
 * $Revision: 1.17 $
 * $Date: 2008-01-21 11:38:04 $
 *
 * @author Moxiecode
 * @copyright Copyright  2004-2006, Moxiecode Systems AB, All rights reserved.
 */

/* Import plugin specific language pack */
tinyMCE.importPluginLanguagePack('dicole', 'en,fi'); // <- Add a comma separated list of all supported languages

/****
 * Steps for creating a plugin from this template:
 *
 * 1. Change all "template" to the name of your plugin.
 * 2. Remove all the callbacks in this file that you don't need.
 * 3. Remove the popup.htm file if you don't need any popups.
 * 4. Add your custom logic to the callbacks you needed.
 * 5. Write documentation in a readme.txt file on how to use the plugin.
 * 6. Upload it under the "Plugins" section at sourceforge.
 *
 ****/

// Singleton class
var TinyMCE_DicolePlugin = {
	/**
	 * Returns information about the plugin as a name/value array.
	 * The current keys are longname, author, authorurl, infourl and version.
	 *
	 * @returns Name/value array containing information about the plugin.
	 * @type Array 
	 */
	getInfo : function() {
		return {
			longname : 'Dicole plugin',
			author : 'Antti Vähäkotamäki',
			authorurl : 'http://www.dicole.com',
			version : "1.0"
		};
	},

	/**
	 * Gets executed when a TinyMCE editor instance is initialized.
	 *
	 * @param {TinyMCE_Control} Initialized TinyMCE editor control instance. 
	 */
	initInstance : function(inst) {
		// You can take out plugin specific parameters
        var dialogs = tinyMCE.getParam("dicole_dialogs", false);

        if ( dialogs.indexOf('wiki') != -1 ) {
//		  inst.addShortcut('ctrl', 'p', 'lang_add_wiki_desc',
//                 'mceAddWikiPAge');
        }
	},

	/**
	 * Returns the HTML code for a specific control or empty string if this plugin doesn't have that control.
	 * A control can be a button, select list or any other HTML item to present in the TinyMCE user interface.
	 * The variable {$editor_id} will be replaced with the current editor instance id and {$pluginurl} will be replaced
	 * with the URL of the plugin. Language variables such as {$lang_somekey} will also be replaced with contents from
	 * the language packs.
	 *
	 * @param {string} cn Editor control/button name to get HTML for.
	 * @return HTML code for a specific control or empty string.
	 * @type string
	 */
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
            case "dicole_html":
                return tinyMCE.getButtonHTML(cn, 'lang_dicole_html_desc', '{$pluginurl}/images/html.gif', 'mceDicoleHtml', true);
		}

		return "";
	},

	/**
	 * Executes a specific command, this function handles plugin commands.
	 *
	 * @param {string} editor_id TinyMCE editor instance id that issued the command.
	 * @param {HTMLElement} element Body or root element for the editor instance.
	 * @param {string} command Command name to be executed.
	 * @param {string} user_interface True/false if a user interface should be presented.
	 * @param {mixed} value Custom value argument, can be anything.
	 * @return true/false if the command was executed by this plugin or not.
	 * @type
	 */
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
                if ( content_data.target_group_id ) {
                    urltarget = 'group';
                }

                TinyMCE_DicolePlugin._open_window(
                    urltarget + '_files_popup/tinymce_select_file/',
                    {
                        target_user_id : content_data.target_user_id,
                        target_group_id : content_data.target_group_id,
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
                    if (tinyMCE.getAttrib(img, 'class').
                            indexOf('dicole_embedded_html') != -1 )
                        return true;

                    src = tinyMCE.getAttrib(img, 'src');
                    alt = tinyMCE.getAttrib(img, 'alt');

                    // Try polling out the title
                    if (alt == "")
                        alt = tinyMCE.getAttrib(img, 'title');

                    align = tinyMCE.getAttrib(img, 'align');
                }

                var urltarget = 'personal';
                if ( content_data.target_group_id ) {
                    urltarget = 'group';
                }

                TinyMCE_DicolePlugin._open_window(
                    urltarget + '_files_popup/tinymce_select_image/',
                    {
                        target_user_id : content_data.target_user_id,
                        target_group_id : content_data.target_group_id,
                        src : src,
                        alt : alt,
                        align : align
                    }
                );

                return true;


            case "mceDicoleHtml":
                // Show UI/Popup
                // Largely copied from tinymce mceImage

                var code = "";

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

                    code = tinyMCE.getAttrib(img, 'alt');
                }


                TinyMCE_DicolePlugin._open_window(
                    'tinymce_popup/embedded_html/',
                    {
                        code : code
                    }
                );

                return true;

        }
		// Pass to next handler in chain
		return false;
	},

	/**
	 * Gets called ones the cursor/selection in a TinyMCE instance changes. This is useful to enable/disable
	 * button controls depending on where the user are and what they have selected. This method gets executed
	 * alot and should be as performance tuned as possible.
	 *
	 * @param {string} editor_id TinyMCE editor instance id that was changed.
	 * @param {HTMLNode} node Current node location, where the cursor is in the DOM tree.
	 * @param {int} undo_index The current undo index, if this is -1 custom undo/redo is disabled.
	 * @param {int} undo_levels The current undo levels, if this is -1 custom undo/redo is disabled.
	 * @param {boolean} visual_aid Is visual aids enabled/disabled ex: dotted lines on tables.
	 * @param {boolean} any_selection Is there any selection at all or is there only a cursor.
	 */
	handleNodeChange : function(editor_id, node, undo_index, undo_levels, visual_aid, any_selection) {
        // Set defaults
        tinyMCE.switchClass(editor_id + '_dicole_wiki', 'mceButtonDisabled');
        tinyMCE.switchClass(editor_id + '_dicole_file', 'mceButtonDisabled');
        tinyMCE.switchClass(editor_id + '_dicole_image', 'mceButtonNormal');
        tinyMCE.switchClass(editor_id + '_dicole_html', 'mceButtonNormal');

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
             tinyMCE.switchClass(editor_id + '_dicole_html', 'mceButtonDisabled');
       }
        else if ( any_selection ) {
            tinyMCE.switchClass(editor_id + '_dicole_wiki',
                'mceButtonNormal' );
            tinyMCE.switchClass(editor_id + '_dicole_file',
                'mceButtonNormal' );
        }

        var imgnode = tinyMCE.getParentElement(node, "img");
        if ( imgnode ) {
            name = tinyMCE.getAttrib(imgnode, 'class');
            if (name.indexOf('dicole_embedded_html') == -1 ) {
                tinyMCE.switchClass(editor_id + '_dicole_image', 'mceButtonSelected');
                tinyMCE.switchClass(editor_id + '_dicole_html', 'mceButtonDisabled');
            }
            else {
                tinyMCE.switchClass(editor_id + '_dicole_html', 'mceButtonSelected');
                tinyMCE.switchClass(editor_id + '_dicole_image', 'mceButtonDisabled');
                tinyMCE.switchClass(editor_id + '_dicole_wiki', 'mceButtonDisabled');
                tinyMCE.switchClass(editor_id + '_dicole_file', 'mceButtonDisabled');
            }
        }

        // This happens faster than any timeout but timeout
        // is still nice at least for the initialization
        // where content is not necessarily reported correctly
        // TODO: This should be prefixed some day..

        if ( ! tinyMCE.getParam("dicole_disable_resize", false) ) {
            _resize_editor();
        }
	},

	/**
	 * Gets called when a TinyMCE editor instance gets filled with content on startup.
	 *
	 * @param {string} editor_id TinyMCE editor instance id that was filled with content.
	 * @param {HTMLElement} body HTML body element of editor instance.
	 * @param {HTMLDocument} doc HTML document instance.
	 */
/*	setupContent : function(editor_id, body, doc) {
	},
*/
	/**
	 * Gets called when the contents of a TinyMCE area is modified, in other words when a undo level is
	 * added.
	 *
	 * @param {TinyMCE_Control} inst TinyMCE editor area control instance that got modified.
	 */
/*	onChange : function(inst) {
	},
*/
	/**
	 * Gets called when TinyMCE handles events such as keydown, mousedown etc. TinyMCE
	 * doesn't listen on all types of events so custom event handling may be required for
	 * some purposes.
	 *
	 * @param {Event} e HTML editor event reference.
	 * @return true - pass to next handler in chain, false - stop chain execution
	 * @type boolean
	 */
/*	handleEvent : function(e) {
		// Display event type in statusbar
		top.status = "template plugin event: " + e.type;

		return true; // Pass to next handler
	},
*/
	/**
	 * Gets called when HTML contents is inserted or retrived from a TinyMCE editor instance.
	 * The type parameter contains what type of event that was performed and what format the content is in.
	 * Possible valuses for type is get_from_editor, insert_to_editor, get_from_editor_dom, insert_to_editor_dom.
	 *
	 * @param {string} type Cleanup event type.
	 * @param {mixed} content Editor contents that gets inserted/extracted can be a string or DOM element.
	 * @param {TinyMCE_Control} inst TinyMCE editor instance control that performes the cleanup.
	 * @return New content or the input content depending on action.
	 * @type string
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
        template['height'] = 520;
        params['resizable'] = 'yes';
        params['scrollbars'] = 'yes';

        tinyMCE.openWindow(template, params);

        tinyMCE.triggerNodeChange(false);
    }
};

// Adds the plugin class to the list of available TinyMCE plugins
tinyMCE.addPlugin("dicole", TinyMCE_DicolePlugin);
