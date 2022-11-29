(function() {
	// Load plugin specific language pack
	tinymce.PluginManager.requireLangPack('dicole');

	tinymce.create('tinymce.plugins.DicolePlugin', {
		/**
		 * Initializes the plugin, this will be executed after the plugin has been created.
		 * This call is done before the editor instance has finished it's initialization so use the onInit event
		 * of the editor instance to intercept that event.
		 *
		 * @param {tinymce.Editor} ed Editor instance that the plugin is initialized in.
		 * @param {string} url Absolute URL to where the plugin is located.
		 */
		init : function(ed, url) {
			// Register the command so that it can be invoked by using tinyMCE.activeEditor.execCommand('mceExample');
/*			ed.addCommand('mceExample', function() {
				ed.windowManager.open({
					file : url + '/dialog.htm',
					width : 320 + parseInt(ed.getLang('example.delta_width', 0)),
					height : 120 + parseInt(ed.getLang('example.delta_height', 0)),
					inline : 1
				}, {
					plugin_url : url, // Plugin absolute URL
					some_custom_arg : 'custom arg' // Custom argument
				});
			});*/

// 			ed.addCommand('mceDicoleWiki', function() {
//                             ed.plugins.dicole.myOpen( ed, tinymce3_data.wiki_url, {} );
// 			});
// 			ed.addCommand('mceDicoleAttachment', function() {
//                             ed.plugins.dicole.myOpen( ed, tinymce3_data.attachment_url, {} );
// 			});
// 			ed.addCommand('mceDicoleLink', function() {
//                             ed.plugins.dicole.myOpen( ed, tinymce3_data.link_url, {} );
// 			});
// 			ed.addCommand('mceDicoleImage', function() {
//                             ed.plugins.dicole.myOpen( ed, tinymce3_data.image_url, {} );
// 			});
// 			ed.addCommand('mceDicoleHtml', function() {
//                             ed.plugins.dicole.myOpen( ed, tinymce3_data.html_url, {} );
// 			});

			ed.addCommand('mceDicoleSaveOpen', function() {
                            dicole_tinymce_toolbar_switch( this, 'save' );
                        });
                        ed.addShortcut('ctrl+shift+s', 'Save', 'mceDicoleSaveOpen');
                        ed.addShortcut('cmd+shift+s', 'Save', 'mceDicoleSaveOpen');
                        
			ed.addCommand('mceDicoleCancelOpen', function() {
                            dicole_tinymce_toolbar_switch( this, 'cancel' );
			});
			ed.addShortcut('ctrl+w', 'Cancel', 'mceDicoleCancelOpen');
                        ed.addShortcut('cmd+w', 'Cancel', 'mceDicoleCancelOpen');
                        
			ed.addCommand('mceDicoleAttachmentOpen', function() {
                            dicole_tinymce_toolbar_switch( this, 'attachment' );
			});
			ed.addShortcut('ctrl+f', 'Attachment', 'mceDicoleAttachmentOpen');
                        ed.addShortcut('cmd+f', 'Attachment', 'mceDicoleAttachmentOpen');
			
			ed.addCommand('mceDicoleLinkOpen', function() {
                            dicole_tinymce_execute_link_open( this );
			});
			ed.addShortcut('ctrl+l', 'Link', 'mceDicoleLinkOpen');
                        ed.addShortcut('cmd+l', 'Link', 'mceDicoleLinkOpen');
			
			ed.addCommand('mceDicoleAdvancedOpen', function() {
                            dicole_tinymce_toolbar_switch( this, 'advanced' );
			});
			ed.addCommand('mceDicoleTableOpen', function() {
                            dicole_tinymce_toolbar_switch( this, 'table' );
			});
			ed.addCommand('mceDicoleEmbedOpen', function() {
                            dicole_tinymce_toolbar_switch( this, 'embed' );
			});
			ed.addCommand('mceDicoleHtmlOpen', function() {
                            dicole_tinymce_execute_html_open( this );
			});
			ed.addCommand('mceDicoleShowroomOpen', function() {
                            dicole_tinymce_execute_showroom_open( this );
			});
			ed.addCommand('mceDicoleImageOpen', function() {
                            dicole_tinymce_execute_image_open( this );
			});
			ed.addCommand('mceDicoleImageLeft', function() {
                            dicole_tinymce_execute_image_align( this, 'left' );
			});
			ed.addCommand('mceDicoleImageCenter', function() {
                            dicole_tinymce_execute_image_align( this, '' );
			});
			ed.addCommand('mceDicoleImageRight', function() {
                            dicole_tinymce_execute_image_align( this, 'right' );
			});
                        ed.addCommand('mceDicoleJustifyLeft', function() {
                            dicole_tinymce_execute_justify(this, 'left');
                        });
                        ed.addCommand('mceDicoleJustifyCenter', function() {
                            dicole_tinymce_execute_justify(this, 'center');
                        });
                        ed.addCommand('mceDicoleAnnotationRemove', function() {
                        	dicole_tinymce_annotation_remove(this);
                        });
                        
                        ed.addShortcut('ctrl+b', 'Bold', 'Bold');
                        ed.addShortcut('cmd+b', 'Bold', 'Bold');
                        ed.addShortcut('ctrl+i', 'Italic', 'Italic');
                        ed.addShortcut('cmd+i', 'Italic', 'Italic');
                        ed.addShortcut('ctrl+s', 'Strikethrough', 'Strikethrough');
                        ed.addShortcut('cmd+s', 'Strikethrough', 'Strikethrough');
                        ed.addShortcut('ctrl+0', 'Paragraph', function() { ed.execCommand('Formatblock', false, 'P'); });
                        ed.addShortcut('cmd+0', 'Paragraph', function() { ed.execCommand('Formatblock', false, 'P'); });
                        ed.addShortcut('ctrl+p', 'Paragraph', function() { ed.execCommand('Formatblock', false, 'P'); });
                        ed.addShortcut('cmd+p', 'Paragraph', function() { ed.execCommand('Formatblock', false, 'P'); });
                        ed.addShortcut('ctrl+1', 'Header 1', function() { ed.execCommand('Formatblock', false, 'H1'); });
                        ed.addShortcut('cmd+1', 'Header 1', function() { ed.execCommand('Formatblock', false, 'H1'); });
                        ed.addShortcut('ctrl+2', 'Header 2', function() { ed.execCommand('Formatblock', false, 'H2'); });
                        ed.addShortcut('cmd+2', 'Header 2', function() { ed.execCommand('Formatblock', false, 'H2'); });
                        ed.addShortcut('ctrl+3', 'Header 3', function() { ed.execCommand('Formatblock', false, 'H3'); });
                        ed.addShortcut('cmd+3', 'Header 3', function() { ed.execCommand('Formatblock', false, 'H3'); });
                        ed.addShortcut('ctrl+4', 'Header 4', function() { ed.execCommand('Formatblock', false, 'H4'); });
                        ed.addShortcut('cmd+4', 'Header 4', function() { ed.execCommand('Formatblock', false, 'H4'); });
                        ed.addShortcut('ctrl+5', 'Header 5', function() { ed.execCommand('Formatblock', false, 'H5'); });
                        ed.addShortcut('cmd+5', 'Header 5', function() { ed.execCommand('Formatblock', false, 'H5'); });
                        ed.addShortcut('ctrl+6', 'Header 6', function() { ed.execCommand('Formatblock', false, 'H6'); });
                        ed.addShortcut('cmd+6', 'Header 6', function() { ed.execCommand('Formatblock', false, 'H6'); });

/*			ed.addButton('dicole_wiki', {
				title : 'dicole.button_wiki', cmd : 'mceDicoleWiki', image : url + '/img/wiki.gif'
			});
			ed.addButton('dicole_attachment', {
				title : 'dicole.button_attachment', cmd : 'mceDicoleAttachment', image : url + '/img/attachment.gif'
			});
			ed.addButton('dicole_link', {
				title : 'dicole.button_link', cmd : 'mceDicoleLink', image : url + '/img/file.gif'
			});*/
// 			ed.addButton('dicole_image', {
// 				title : 'dicole.button_image', cmd : 'mceDicoleImage', image : url + '/img/image.gif'
// 			});
// 			ed.addButton('dicole_html', {
// 				title : 'dicole.button_html', cmd : 'mceDicoleHtml', image : url + '/img/html.gif'
// 			});

			ed.addButton('dicole_save_open', {
				title : 'dicole.button_save_open', cmd : 'mceDicoleSaveOpen', 'class' : 'dicole_save'
			});
			ed.addButton('dicole_cancel_open', {
				title : 'dicole.button_cancel_open', cmd : 'mceDicoleCancelOpen', 'class' : 'dicole_cancel'
			});
			ed.addButton('dicole_attachment_open', {
				title : 'dicole.button_attachment_open', cmd : 'mceDicoleAttachmentOpen', 'class' : 'dicole_attachment'
			});
			ed.addButton('dicole_link_open', {
				title : 'dicole.button_link_open', cmd : 'mceDicoleLinkOpen', 'class' : 'dicole_link'
			});
			ed.addButton('dicole_advanced_open', {
				title : 'dicole.button_advanced_open', cmd : 'mceDicoleAdvancedOpen', 'class' : 'dicole_advanced'
			});
			ed.addButton('dicole_table_open', {
				title : 'dicole.button_table_open', cmd : 'mceDicoleTableOpen', 'class' : 'dicole_table'
			});
			ed.addButton('dicole_embed_open', {
				title : 'dicole.button_embed_open', cmd : 'mceDicoleEmbedOpen', 'class' : 'dicole_embed'
			});
			ed.addButton('dicole_html_open', {
				title : 'dicole.button_html_open', cmd : 'mceDicoleHtmlOpen', 'class' : 'dicole_html'
			});
			ed.addButton('dicole_showroom_open', {
				title : 'dicole.button_showroom_open', cmd : 'mceDicoleShowroomOpen', 'class' : 'dicole_showroom'
			});
			ed.addButton('dicole_image_open', {
				title : 'dicole.button_image_open', cmd : 'mceDicoleImageOpen', 'class' : 'dicole_image'
			});
			ed.addButton('dicole_image_left', {
				title : 'dicole.button_image_left', cmd : 'mceDicoleImageLeft', 'class' : 'dicole_image_left'
			});
			ed.addButton('dicole_image_center', {
				title : 'dicole.button_image_center', cmd : 'mceDicoleImageCenter', 'class' : 'dicole_image_center'
			});
			ed.addButton('dicole_image_right', {
				title : 'dicole.button_image_right', cmd : 'mceDicoleImageRight', 'class' : 'dicole_image_right'
			});
			ed.addButton('dicole_justify_left', {
				title : 'dicole.button_justify_left', cmd : 'mceDicoleJustifyLeft', 'class' : 'dicole_justify_left'
			});
			ed.addButton('dicole_justify_center', {
				title : 'dicole.button_justify_center', cmd : 'mceDicoleJustifyCenter', 'class' : 'dicole_justify_center'
			});
			ed.addButton('dicole_annotation_remove', {
				title : 'dicole.button_annotation_remove', cmd : 'mceDicoleAnnotationRemove', 'class' : 'dicole_image'
			});
			
			ed.onKeyUp.add(function(ed, event) {
				if(event.keyCode == dojo.keys.ENTER) {
					var annotation = ed.dom.getParent(ed.selection.getNode(), 'span.wiki_anno.wiki_anno_begin.wiki_anno_end');
					if(annotation) {
						ed.selection.select(annotation);
						ed.selection.setContent(annotation.innerHTML);
					}
				}
			});
			
			ed.onPostProcess.add(function(ed, o) {
				var annotation = ed.dom.getParent(ed.selection.getNode(), 'span.wiki_anno.wiki_anno_begin.wiki_anno_end');
				if(annotation) {
					var inline_elements = ["a","abbr","acronym","b","basefont","bdo","big","br","cite","code","dfn","em","font","i","img","input","kbd","label","q","s","samp","select","small","span","strike","strong","sub","sup","textarea","tt","u","var"];
					var regexp = new RegExp("<(?!/)(?!" + inline_elements.join("|") + ")[^>]*>", "im");
					var position = o.content.search(regexp);
					if(position != -1) {
						var insertable_content = o.content.substr(0, position);
						var excess_content = o.content.substr(position);
						ed.selection.setContent(insertable_content);
					}
					else ed.selection.setContent(o.content);
					o.content = "";
				}
			});

			// Add a node change handler, selects the button in the UI when a image is selected
			ed.onNodeChange.add(function(ed, cm, n, co) {
                            // co is wether selection is collapsed (empty)
                            // Set defaults
//                             cm.setDisabled('dicole_wiki', true);
//                             cm.setActive('dicole_wiki', false);
// 
//                             cm.setDisabled('dicole_link', true );
//                             cm.setActive('dicole_link', false );
//                     
//                             cm.setDisabled('dicole_html', false );
//                             cm.setActive('dicole_html', false);
// 
//                             cm.setDisabled('dicole_image', false);
//                             cm.setActive('dicole_image', false );

                            cm.setDisabled('dicole_link_open', true );
                            cm.setDisabled('dicole_showroom_open', true );
                            cm.setDisabled('dicole_html_open', false );
                            cm.setDisabled('dicole_image_open', false );
                            cm.setDisabled('dicole_justify_left', true);
                            cm.setDisabled('dicole_justify_center', true);
                            cm.setActive('dicole_justify_left', false);
                            cm.setActive('dicole_justify_center', false);
                            cm.setActive('dicole_image_left', false );
                            cm.setActive('dicole_image_center', false );
                            cm.setActive('dicole_image_right', false );
                            dicole_tinymce_toolbar_set_imagecontrols_visibility( ed, false );

//                            cm.setActive('dicole_link_open', false );
                    
                            // Select wiki or link button if parent node is a link
                            var alink = ed.dom.getParent(n, 'A');
                    
                            if ( alink ) {
/*                                if ( ed.dom.hasClass( alink, 'wikiLink' ) ) {
                                    cm.setDisabled('dicole_wiki', false);
                                    cm.setActive('dicole_wiki', true);
                                    cm.setDisabled('dicole_link', false);
                                }
                                else {
                                    cm.setDisabled('dicole_link', false);
                                    cm.setActive('dicole_link', true);
                                    cm.setDisabled('dicole_wiki', false);
                                }*/
                                if ( ed.dom.hasClass( alink, 'dicole_showroom_link') ) {
                                   cm.setDisabled('dicole_showroom_open', false);
                                }
                                else {
                                    cm.setDisabled('dicole_link_open', false);
                                }
                                cm.setDisabled('dicole_html_open', true);
                           }
                            else if ( ! co ) {
/*                                cm.setDisabled('dicole_wiki', false);
                                cm.setDisabled('dicole_link', false);*/
                                cm.setDisabled('dicole_link_open', false);
                                cm.setDisabled('dicole_showroom_open', false);
                                cm.setDisabled('dicole_html_open', true);
//                                cm.setDisabled('dicole_image_open', true);
                            }
                    
                            var imgnode = ed.dom.getParent(n, 'IMG');
                            if ( imgnode ) {
                                if ( n.className.indexOf('mceItem') != -1 ) {
//                                    cm.setDisabled('dicole_image_open', true);
                                    cm.setDisabled('dicole_html_open', true);
                                }
                                else if ( ed.dom.hasClass( imgnode, 'dicole_embedded_html') ) {
                                    cm.setDisabled('dicole_html_open', false);
//                                    cm.setActive('dicole_html', true);
//                                    cm.setDisabled('dicole_image_open', true);
                                }
                                else {
                                    dicole_tinymce_toolbar_set_imagecontrols_visibility( ed, true );
                                    var algn = ed.dom.getAttrib(n, 'align');
                                    cm.setActive('dicole_image_left', algn == 'left' );
                                    cm.setActive('dicole_image_center', algn == '' );
                                    cm.setActive('dicole_image_right', algn == 'right' );
//                                    cm.setDisabled('dicole_image_open', false);
//                                    cm.setActive('dicole_image', true);
                                    cm.setDisabled('dicole_html_open', true);
                                }
                            }

                            var pnode = ed.dom.getParent(n, 'P');
                            if ( pnode ) {
                                cm.setDisabled('dicole_justify_left', false);
                                cm.setDisabled('dicole_justify_center', false);
                                if(dojo.style( pnode, 'textAlign' ) != 'center' && dojo.style( pnode, 'textAlign' ) != 'left' ) {
                                    dojo.style( pnode, 'textAlign', 'left' );
                                }
                                if(dojo.style(pnode, 'textAlign') == 'center') cm.setActive('dicole_justify_center', true);
                                else if(dojo.style(pnode, 'textAlign') == 'left') cm.setActive('dicole_justify_left', true);
                            }

                            var pnodes = ed.dom.getParents('p.dicole_embedded_html_container', n);
                            if ( ed.dom.is( n, 'p.dicole_embedded_html_container') ) pnodes.push( n );
                            dojo.forEach( pnodes, function( pnode ) {
                                if ( ! ed.dom.select('img.dicole_embedded_html', pnode ).length )
                                    ed.dom.removeClass( pnode, 'dicole_embedded_html_container');
                            } );
                            
                            if(ed.dom.getParent(n, 'span.wiki_anno.wiki_anno_begin.wiki_anno_end')) cm.setDisabled('dicole_annotation_remove', false);
                            else cm.setDisabled('dicole_annotation_remove', true);

                            // This happens faster than any timeout but timeout
                            // is still nice at least for the initialization
                            // where content is not necessarily reported correctly
                            // TODO: This should be prefixed some day..
                    
                            if ( ! tinyMCE.activeEditor.getParam("dicole_disable_resize") ) {
                                _resize_editor();
                            }
			});
		},

		/**
		 * Creates control instances based in the incomming name. This method is normally not
		 * needed since the addButton method of the tinymce.Editor class is a more easy way of adding buttons
		 * but you sometimes need to create more complex controls like listboxes, split buttons etc then this
		 * method can be used to create those.
		 *
		 * @param {String} n Name of the control to create.
		 * @param {tinymce.ControlManager} cm Control manager to use inorder to create new control.
		 * @return {tinymce.ui.Control} New control instance or null if no control was created.
		 */
		createControl : function(n, cm) {
                        switch (n) {
                            case 'dicole_attachment_container' :
                            case 'dicole_link_container' :
                            case 'dicole_embed_container' :
                            case 'dicole_html_container' :
                            case 'dicole_showroom_container' :
                            case 'dicole_image_container' :
                            case 'dicole_save_container' :
                            case 'dicole_cancel_container' :
                                return tinyMCE.activeEditor.plugins.dicole.myTemplateControl( n, cm );

                            case 'dicole_save_open' :
                                return tinyMCE.activeEditor.plugins.dicole.myTextButtonControl( n, cm, {
                                    title : 'dicole.button_save_open', cmd : 'mceDicoleSaveOpen',
                                    text : tinyMCE.activeEditor.translate('dicole.button_save_text'), 'class' : 'dicole_save'
                                } );

                            case 'dicole_cancel_open' :
                                return tinyMCE.activeEditor.plugins.dicole.myTextButtonControl( n, cm, {
                                    title : 'dicole.button_cancel_open', cmd : 'mceDicoleCancelOpen',
                                    text : tinyMCE.activeEditor.translate('dicole.button_cancel_text'), 'class' : 'dicole_cancel'
                                } );

                        }

                        return null;
		},

                myOpen : function( ed, url, params ) {
                    ed.windowManager.open({
                        file : url,
                        width : 650,
                        height : 520,
                        inline : 1
                    }, params );
                },

                myTemplateControl : function( n, cm ) {
                    var aeid = tinyMCE.activeEditor.id + "";
                    var c = new tinymce.ui.Control( n );
                    c.renderHTML = function () {
                        var template = tinymce3_data[ n + '_template' ] || '';
                        template = template.replace(/REPLACE:EDITOR:ID:HERE/g, aeid );
                        return template;
                    };
                    c.postRender = function() {
                        dicole_tinymce_container_postrender( n, cm, aeid );
                    };
                    return c;
                },

                myTextButtonControl : function( n, cm, s ) {
                    var ed = tinyMCE.activeEditor;
                    s.title = ed.translate(s.title);
                    s.label = ed.translate(s.label);
                    s.scope = s.scope || ed;
                    s = tinymce.extend({
                        title : s.title,
                        unavailable_prefix : ed.getLang('unavailable', ''),
                        scope : s.scope,
                        control_manager : cm,
                        onclick : function() {
                            ed.execCommand(s.cmd, s.ui || false, s.value);
                        }
                    }, s);
                    var c = new tinymce.ui.Button( n, s );
                    c.renderHTML = function () {
                        var cp = this.classPrefix, s = this.settings, h, l, t;

                        l = tinymce.DOM.encode(s.label || '');
                        t = tinymce.DOM.encode(s.text || '' );
                        h = '<a id="' + this.id + '" href="javascript:;" class="dicole_tinymce3_submit_small_outer ' + cp + ' ' + cp + 'Enabled ' + s['class'] + (l ? ' ' + cp + 'Labeled' : '') +'" onmousedown="return false;" onclick="return false;" title="' + tinymce.DOM.encode(s.title) + '">';

                        h += '<span class="dicole_tinymce3_submit_small_inner ' + s['class'] + '">' + t + '</span>' + (l ? '<span class="' + cp + 'Label">' + l + '</span>' : '') + '</a>';

                        return h;
                    };
                    return c;
                },

		/**
		 * Returns information about the plugin as a name/value array.
		 * The current keys are longname, author, authorurl, infourl and version.
		 *
		 * @return {Object} Name/value array containing information about the plugin.
		 */
		getInfo : function() {
			return {
				longname : 'Dicole plugin',
				author : 'Antti Vähäkotamäki',
				authorurl : 'http://dicole.com/',
				infourl : '',
				version : "1.0"
			};
		}
	});

	// Register plugin
	tinymce.PluginManager.add('dicole', tinymce.plugins.DicolePlugin);
})();