/*
 * TagBrowser.js: Creates a controller for handling interaction
 * between a tag cloud and search content, tag based search
 *
 * TODO: generalize every configuration option so
 * this can be used in different places easily
 *
 */

dojo.provide("dicole.tags.TagBrowser");
dojo.provide("dicole.tags.TagCloudControl");
dojo.provide("dicole.tags.Tag");

dojo.require("dicole.base");
dojo.require("dijit.dijit");
dojo.require("dojo.fx");

// TODO, disconnect all connections made on unload
// TODO: optimize the updateDisplay(), instead
// prevents memory leaks
//dojo.addOnUnload();
//
/*
 OK, this is how this works:

 - dicole.tags.Tag represents one tag
 - dicole.tags.ObjectCloud represents a cloud of any objects, where each one of the objects has a unique ID which generated when the cloud is formed. The cloud can be formed from a collection of nodes from a page, or created programmatically
 - dicole.tags.TagCloud uses ObjectCloud as a superclass, creating a layer of tags on top of the ObjectCloud, rendering Tags visually, adding and removing, notifying subscribers when the TagCloud is updated etc
 - dicole.tags.TagBrowser is a handler class for two TagClouds. It handles
 the interaction between two designated TagCloud objects, handling the transfer of tags between those two. It also handles the communication between the server via XHR calls, let's the server know when selected tags have been updated and updates the content list based on the response received from the server.

 -- Sakari <sakari@dicole.com>
 */

// Class representing one tag, either already on the page
// or created new
dojo.declare("dicole.tags.Tag", null,
{
	"debug" : 0,
	"connectionHandle" : 0,
	// Actual weight of the tag, number of times used in system
	"weight" : 0,
	// Add className, this could be used
	// to overwrite the default className
	"className" : "tagPrimary",
	"href" : "#",
	"removeAdded" : false,
	"removeChar" : null,

	"constructor" : function( node, args )
	{
		if (this.debug > 1)
		{
			console.log("Tag.constructor, node=" + node + " args=" + args);
		}

		dojo.mixin(this, args);

		// Create new ?
		if (!node)
		{
			this.elem = this._createElem();
		}
		// Use the one already on the page
		else
		{
			this.elem = node;
		}
	},

	"_createElem" : function()
	{
		var inner_html;

		inner_html = this.name;

		var elem = dojo.create("a",
		{	
			"class": "tag",
			"href": this.href,
			// TODO: don't use innerHTML
			"innerHTML": inner_html,
			"className" : this.className
		});

		return elem;
	},

	"hide" : function()
	{
		dojo.style(this.elem, "display", "none");
	},

	"show": function()
	{
		dojo.style(this.elem, "display", "block");
	},

	"getElem" : function()
	{
		return this.elem;
	},

	"connect" : function( ext_this, onclick_func )
	{
		var conn = dojo.connect(this.elem, "onclick", ext_this, onclick_func);
		this.connectionHandle = conn;
	},

	"disconnect" : function()
	{
		if (this.connectionHandle)
		{
			dojo.disconnect(this.connectionHandle);
		}
	}

});

// ObjectCloud is an abstract handler for 
// one "Cloud" of objects. It can scan existing elements
// from the HTML page to create a "cloud" that can be controlled
// using this class, or the object clouds can be created
// programmatically too (TODO).
dojo.declare("dicole.tags.ObjectCloud", null,
{
	// Default values
	"objectQuery" : ".tag",
	"debug" : 0,
	"cloudId" : 0,
	"containerNode" : null,
	"objectCount" : 0,

	// static stuff that is shared between instances of this class
	"statics" :
	{
		"globalId" : "",
		"idCount" : 0,
		"idBase" : "dicole_oc_"
	},

	// Object query is the string given
	// to dojo.query when scanning the page for
	// objects that this ObjectCloud contains and
	// manages
	"constructor" : function( node, args )
	{
		dojo.mixin(this, args);

		if (this.debug)
		{
			console.log("ObjectCloud constructor, args=");
			console.dir(args);
		}

		if (node)
		{
			this.containerNode = node;
		}
		// This contains all the objects that this
		// ObjectCloud handles
		this.objects = {};
		//

		if (this.debug)
		{
			console.log("ObjectCloud created, id=" + this.cloudId);
		}
	},

	// Scan the page if we have the container node
	// specified, get references to all the elements 
	//
	"init" : function()
	{
		// Generate unique ID for this ObjectCloud
		this.cloudId = this.generateId();
		//
		// Find all the objects that we 
		// will be controlling
		// But now, only objects can be inside this containerNode
		this.queryObjects();

		if (this.debug > 1)
		{
			console.log("ObjectCloud initialized, objects=");
			console.dir(this.objects);
		}
	},

	"queryObjects" : function()
	{
		dojo.query(this.objectQuery, this.containerNode).forEach(
			dojo.hitch(this, 
				function( obj_elem )
				{
					// Generate unique ID for this object
					// and add to our dictionary of objects
					var unique_id = this.generateId();
					this.objects[unique_id] = obj_elem;
					this.objectCount++;
				}
			)
		);
	},

	// Generate unique id, altBase can be
	// specified to use alternative base for the generated IDs
	"generateId" : function( altBase )
	{
		do
		{ 
			this.statics.idCount++;
			this.statics.globalId = (altBase || this.statics.idBase) + this.statics.idCount; 
		}
		while(dojo.byId(this.statics.globalId));

		return this.statics.globalId;
	},

	"getCloudId" : function()
	{
		return this.cloudId;
	},

	"addObjectWithId" : function ( obj, id )
	{
		if (this.debug)
		{
			console.log("ObjectCloud.addObjectWithId, obj=" + obj + " id=" + id);
		}

		if (obj && id)
		{
			this.objects[id] = obj;
			this.objectCount++;
		}
	},

	"removeObjectWithId" : function ( id )
	{
		if (this.debug)
		{
			console.log("ObjectCloud.removeObjectWithId, id=" + id);
		}

		this.objectCount--;
		return delete this.objects[id];
	},

	"resetObjects" : function ()
	{
		for (var obj_id in objects)
		{
			delete this.objects[obj_id];
		}
	},

	"getObjects" : function ()
	{
		return this.objects;
	},

	"getObjectCount" : function ()
	{
		return this.objectCount;
	},

	"getObjectWithId" : function ( id )
	{
		return this.objects[id];
	}
});

// TagCloud controls interactions between two 
// ObjectClouds that hold text tags within them
//
// We must rely on our data structure to re-create this 
// visualization .. so we must empty the container node before
// updating it. We have all the data for the tags needed, and
// we have the container node.
dojo.declare("dicole.tags.TagCloud", [dicole.tags.ObjectCloud],
{
	"displayNode" : 0,
	"objectQuery" : "",
	"connectTags" : true,
	"addSeparators" : false,
	"separatorChar" : "+",
	"addRemove": false,
	"tagRemoveChar" : "✖",

	// Container node is the node containing the
	"constructor" : function( node, args )
	{
		dojo.mixin(this, args);

		if (this.debug > 1)
		{
			console.log("TagCloud.constructor, node=" + node);
			console.dir(args);
		}

		this.displayNode = node;
		this.tags = {};
		this.destClouds = [];
	},

	"init" : function ()
	{
		// Call super.init()
		this.inherited(arguments);

		if (this.debug > 1)
		{
			console.log("TagCloud.init, this.objects=");
			console.dir(this.objects);
		}

		this._createTagObjects();
		this.updateDisplay();
	},

	"_createNewTag" : function ( node, tag_args )
	{
		var removeChar;

		if (this.addRemove)
		{
			removeChar = this.tagRemoveChar;
		}
		else
		{
			removeChar = null;
		}
		// Create new Tag
		tag_args.removeChar = removeChar;
		var tag = new dicole.tags.Tag(node, tag_args);

		return tag;
	},

	"_createTagObjects" : function ()
	{
		// Create Tag objects to represent the objects
		// in this cloud
		for (var obj_id in this.objects)
		{
			var tag_node = this.getObjectWithId(obj_id);
			if (tag_node)
			{
				var tag = this._createNewTag(tag_node,
					{
						// TODO: don't use innerHTML
						"name" : tag_node.innerHTML,
						"weight" : 0,
						"removeChar": this.tagRemoveChar
					}
				);

				if (tag)
				{
					// Add to our tags
					this.tags[obj_id] = tag;
				}
			}
		}

		if (this.debug > 1)
		{
			console.log("TagCloud.init, this.tags =");
			console.dir(this.tags);
		}
	},

	"_createRemover" : function()
	{
		return dojo.create("a",
		{	
			"class": "tag_remover",
			// TODO: don't use innerHTML
			"href": "#",
			"innerHTML": this.tagRemoveChar
		});
	},

	"_createSeparator" : function()
	{
		return dojo.create("span",
		{	
			"class": "tag_separator",
			// TODO: don't use innerHTML
			"innerHTML": this.separatorChar
		});
	},

	"removeTagWithId" : function( id )
	{
		if (this.debug)
		{
			console.log("TagCloud.removeTagWithId, id=" + id);
		}

		// Remove object from our parent class
		this.removeObjectWithId(id);

		// Delete from our tags
		delete this.tags[id];

		this.updateDisplay();

		if (this.debug > 1)
		{
			console.dir(this.objects);
			console.dir(this.tags);
		}
	},

	"addTagWithId" : function ( /* Object */ tag, /* String */ id )
	{
		if (this.debug)
		{
			console.log("TagCloud.addTagWithId, id=" + id);
		}

		if (tag && id)
		{
			// Need to add the underlying object too
			var elem = tag.getElem();
			this.addObjectWithId(elem, id);

			// Add tag, check 
			if (this.addRemove)
			{
				tag.removeChar = this.tagRemoveChar;
			}
			else
			{
				tag.removeChar = null;
			}

			this.tags[id] = tag;

			this.updateDisplay();
		}
	},

	// Clear our tags
	"resetTags" : function ()
	{
		for (var tag_id in this.tags)
		{
			this.removeObjectWithId(tag_id);
			this.tags[tag_id].disconnect();
			delete this.tags[tag_id];
		}
	},

	"getTags" : function ()
	{
		return this.tags;
	},

	"getTagCount" : function()
	{
		var count = 0;
		for (var tag_id in this.tags)
		{
			count++;
		}

		return count;
	},

	// So .. currently we set the tags like follows:
	//
	// - New data comes from the server
	// - We create new tags based on that data
	// - Those tags are added to the tag cloud
	// - UpdateDisplay is called, the tag cloud is formed based
	//   on the tag data
	//
	// Now that the data comes as HTML from the server, we would have
	// to do the following :
	//
	// - New suggestion data comes from the server, the whole tagCloud as HTML
	// - Add that HTML to the page
	// - Scan the HTML, form the data model
	// - Don't update the display .. this means that everything should
	//   be formed on the serverside, including the remove characters 
	//   and tag separators too
	// - This means that we can't really be flexible on the javascript side
	//   .. as we can't actually touch the visual representation of the
	//   tag cloud, which is stupid
	// - When clicking on the suggestion tag, it removes one tag and moves
	//   it to the selected keywords .. then updateDisplay for that
	//   tagcloud is called
	//
	//   If all this data would come from the server, the selected
	//   tag would have to be removed, both tagclouds updated with the
	//   data from the server. Basically what this does is make the client
	//   a stupid terminal that just fetches pre-rendered data from the
	//   server
	//
	"setTags" : function ( /* Array */ tags_html )
	{
		var tags_dom = dojo._toDom(tags_html);

		if (this.debug > 1)
		{
			console.log("TagCloud setTags, tags_dom=");
			console.dir(tags_dom);
		}

		dojo.query(this.objectQuery, tags_dom).forEach(
			dojo.hitch(this, 
				function (tag_html)
				{
					var tag = this._createTagFromHtml(tag_html);
					var id = this.generateId();
					this.addTagWithId(tag, id);
				}
			)
		);
	},

	// Parse on create one Tag object from HTML portion
	"_createTagFromHtml" : function ( tag_html )
	{
		var weight = 0;
		var name = tag_html.innerHTML;
		var classes = tag_html.className.split(' ');
		var prefix = "real_weight_";

		for (var i=0; i<classes.length; i++)
		{
			// Check if this is the weight class
			if ( classes[i].substring(0, prefix.length) == prefix)
			{
				// Parse weight from string
				// string is in "real_weight_x" format
				weight = classes[i].split('_')[2];	
			}
		}

		var tag;
		if (name && weight)
		{
			tag = this._createNewTag(null,
				{
					"name" : name,
					"weight" : weight,
					"className" : tag_html.className
				}
			);
		}

		return tag;
	},

	// Get all tag names that we have
	"getTagNames" : function ()
	{
		var ret_array = [];

		for (var tag_id in this.tags)
		{
			ret_array.push(this.tags[tag_id].name);
		}

		return ret_array;
	},

	"getTagWithId" : function ( /* String */ id )
	{
		return this.tags[id];
	},

	"updateDisplay" : function()
	{
		// Reset
		dojo.empty(this.displayNode);

		// Append our representations of the objects
		// to the display element
		var objects = this.getObjects();
		var obj_count = this.getObjectCount();
		var index = 0;
//		var html = "";
		// TODO: optimize multiple dojo.place() with single
		// dojo.place, combine
		for (var obj_id in objects)
		{
			var tag = this.tags[obj_id];
			dojo.place(tag.elem, this.displayNode, "last");
			if (this.addRemove && tag.removeAdded == false)
			{
				// So .. we need to add the remove character
				var remover = this._createRemover();
				dojo.place(document.createTextNode("  " + this.tagRemoveChar), tag.elem);
				tag.removeAdded = true;
			}
			// Add tag separator ?
			if (this.addSeparators && (index + 1) < obj_count )
			{
				var separator = this._createSeparator();
				dojo.place(separator, this.displayNode, "last");
			}
			// Append a line break, otherwise layout will break
			dojo.place(document.createTextNode("\n"), this.displayNode, "last");
			index++;
		}

		//this.displayNode.innerHTML = html;

		// Let our subscribers know that we updated
		// TODO: replace with ID passed in the parameters
		// and the subscriber checking for that ID
		var publish_str = "/dicole/TagCloud/" + this.getCloudId() + "/updated";
		var publish_args = [
			{
				"item": "one"
			}
		];
		if (this.debug)
		{
			console.log(publish_str);
		}
		dojo.publish(publish_str, publish_args);
	}
});

// TagBrowser:
// Sends selected tags to the server and receives content
// based on those. Has a CloudControl that handles two
// ObjectClouds.
dojo.declare("dicole.tags.TagBrowser", null,
{
	"debug" : 0,
	/* Usually the same */
	"resultId" : "browse_results",
	"loadingNodeId" : "browse_loading",
	"showMoreId" : "browse_show_more",
	"filterWithKeywordsId": "browse_filter_with_keywords",
	"filterMoreId": "filter_more",
	"filterMoreContainerId": "filter_more_container",
	"filterShowId": "filter_show",
	"filterHideId": "filter_hide",
	"filterMoreShowId": "filter_more_show",
	"filterMoreHideId": "filter_more_hide",
	"selectedTagsId": "browse_selected_tags",
	"selectedContainerId": "browse_selected_container",
	"suggestionCloudId": "browse_suggestions",
	"filterContainerId" : "browse_filter_container",
	"profileCountId" : "browse_result_count",
	"noResultsId" : "browse_no_results",
	/* Implementation specific */
	"updateSuggestionTagsUrl" : "",
	"moreContentUrl" : "",
	"stateVarName" : "",

	"constructor" : function( container_node, args )
	{
		dojo.mixin(this, args)
		this.containerNode = container_node;
		this.resultData = [];
	},

	"init" : function()
	{
		var cloud_id;
		var subscribe_str;

		// Get all the nodes
		this.resultsNode = dojo.byId(this.resultId);
		this.showMoreNode = dojo.byId(this.showMoreId);
		this.loadingNode = dojo.byId(this.loadingNodeId);
		this.filterWithKeywordsNode = dojo.byId(this.filterWithKeywordsId);
		this.filterMoreNode = dojo.byId(this.filterMoreId);
		this.filterMoreContainerNode = dojo.byId(this.filterMoreContainerId);
		this.filterShowNode = dojo.byId(this.filterShowId);
		this.filterHideNode = dojo.byId(this.filterHideId);
		this.filterMoreShowNode = dojo.byId(this.filterMoreShowId);
		this.filterMoreHideNode = dojo.byId(this.filterMoreHideId);
		this.selectedTagsNode = dojo.byId(this.selectedTagsId);
		this.selectedContainerNode = dojo.byId(this.selectedContainerId);
		this.suggestionCloudNode = dojo.byId(this.suggestionCloudId);
		this.filterContainerNode = dojo.byId(this.filterContainerId);
		this.profileCountNode = dojo.byId(this.profileCountId);
		this.noResultsNode = dojo.byId(this.noResultsId);

		// Get the urls
		/*
		this.updateSuggestionTagsUrl = dicole.get_global_variable("keyword_change_url");
		this.moreContentUrl = dicole.get_global_variable("more_profiles_url");
		*/

		// Source tag cloud creation
		// This is the suggestion tag cloud
		this.tags_src = this.createTagCloud(
			{
				"displayQuery": "#browse_suggestions > .miniTagCloud",
				"objectQuery": ".tag",
				"connectTags": true
			}
		);
		this.tags_src.init();
		cloud_id = this.tags_src.getCloudId();

		// Destination tag cloud creation
		// These are the selected tags that
		// are used for filtering the content
		this.tags_dst = this.createTagCloud(
			{
				"displayQuery": "#browse_selected_tags > .miniTagCloud",
				"objectQuery":	".tag",
				"connectTags":	true,
				"addSeparators":	true,
				"addRemove":		true,
				"tagRemoveChar":	"✖",
				"separatorChar":	"+"
			}
		);
		this.tags_dst.init();
		cloud_id = this.tags_dst.getCloudId();
		// Subscribe to updates from the tag clouds
		subscribe_str = "/dicole/TagCloud/" + cloud_id + "/updated";
		dojo.subscribe(subscribe_str, this, 
				dojo.hitch(this, this.selectedTagsUpdated)
		);

		// Connect to each other :)
		this._connectTagsForClouds(this.tags_src, this.tags_dst);
		this._connectTagsForClouds(this.tags_dst, this.tags_src);

		// Connect show more and filter buttons
		dojo.connect(this.showMoreNode, "onclick", this, this._showMore);
		dojo.connect(this.filterWithKeywordsNode, "onclick", this, this._filterWithKeywords);
		dojo.connect(this.filterMoreNode, "onclick", this, this._filterMore);
	},

	"createTagCloud" : function ( args )
	{
		var display_node;
		// Find the display node
		dojo.query(args.displayQuery).forEach(
			function (node)
			{
				display_node = node;
			}
		);

		var tagCloud = new dicole.tags.TagCloud(display_node, args);
		
		return tagCloud;
	},

	"_connectTagsForClouds" : function ( src, dst )
	{
		var tags = src.getTags();
		for (var tag_id in tags)
		{
			var tag = src.getTagWithId(tag_id);
			if (tag)
			{
				tag.disconnect();
				tag.connect(this, this._createOnClick(src, dst, tag_id));
			}
		}
	},

	"_showSelectedKeywords" : function()
	{
		dojo.style(this.selectedContainerNode, "display", "block");
		dojo.style(this.selectedTagsNode, "display", "inline");
		dojo.style(this.filterMoreContainerNode, "display", "inline");
		dojo.style(this.suggestionCloudNode, "display", "none");
	},

	"_hideSelectedKeywords" : function()
	{
		dojo.style(this.selectedTagsNode, "display", "none");
		dojo.style(this.filterMoreContainerNode, "display", "none");
		dojo.style(this.suggestionCloudNode, "display", "block");
	},

	// Checks and sets keywords and filter more
	// button visibility based on tag counts
	"_actOnTagCloudChange" : function()
	{
		if (this.tags_dst.getTagCount() > 0)
		{
			this._showSelectedKeywords();
			this._setFilterMoreShow();
		}
		else
		{
			this._hideSelectedKeywords();
		}

		// Check if no more tag suggestions, hide "filter more" button
		if (this.tags_src.getTagCount() == 0)
		{
			dojo.style(this.filterMoreContainerNode, "display", "none");
		}

		if (this.noResultsNode)
		{
			dojo.style(this.noResultsNode, "display", "none");
		}
	},

	// Remove tag from source cloud and add copy to dest cloud
	"_createOnClick" : function ( src, dst, tag_id )
	{
		return function()
		{
			var tag = src.getTagWithId(tag_id);
			if (tag)
			{
				// This will swap the dst and src everytime
				// this is called, so the tag will be 
				// toggled between the src and dst clouds
				tag.disconnect();
				tag.connect(this, this._createOnClick(dst, src, tag_id));

				// Remove from source, add to dst
				src.removeTagWithId(tag_id);
				dst.addTagWithId(tag, tag_id);
				
				this._actOnTagCloudChange();
			}
		};
	},

	// The selected tag cloud was updated, do:
	//
	// - Set current state (displayed profiles) to empty
	// - Update the tag suggestion cloud from the server
	// - Fetch new set of profiles from the server and add to
	//   our content display
	"selectedTagsUpdated" : function ()
	{
		if (this.debug)
		{
			console.log("selectedTagsUpdated");
		}

		// Reset content
		this.resetContentDisplay();

		// Update suggestion cloud
		this.postSelectedKeywords();

		if (this.debug)
		{
			console.log("TagBrowser.selectedTagsUpdated, state = ");
			console.log(dicole.get_global_variable(this.stateVarName));
		}
	},

	// Show more content
	"_showMore" : function ( evt )
	{
		evt.preventDefault();
		this.showMoreContent();
	},

	"_setFilterMoreHide" : function ()
	{
		dojo.style(this.filterMoreHideNode, "display", "inline");
		dojo.style(this.filterMoreShowNode, "display", "none");
	},

	"_setFilterMoreShow" : function ()
	{
		dojo.style(this.filterMoreShowNode, "display", "inline");
		dojo.style(this.filterMoreHideNode, "display", "none");
	},

	// When filter more is pressed
	"_filterMore" : function ( evt )
	{
		evt.preventDefault();
		var node = this.suggestionCloudNode;
		var display = dojo.style(node, "display");
		if (display == "none")
		{
			dojo.style(node, "display", "block");
			this._setFilterMoreHide();
		}
		else
		{
			dojo.style(node, "display", "none");
			this._setFilterMoreShow();
		}
	},

	// Show or hide the "filter more" x and arrow
	"_setFilterShow" : function()
	 {
			dojo.style(this.filterHideNode, "display", "inline");
			dojo.style(this.filterShowNode, "display", "none");
	 },

	"_setFilterHide" : function()
	 {
			dojo.style(this.filterHideNode, "display", "none");
			dojo.style(this.filterShowNode, "display", "inline");
	 },

	"_keywordsShown" : function()
	{
		var display = dojo.style(this.selectedTagsNode, "display");
		var shown = true;
		if (display == "none")
		{
			shown = false;
		}

		return shown;
	},

	"_showFilter" : function()
	{
		this._setFilterShow();

		dojo.style(this.filterContainerNode, "display", "block");
		// This is to check if the page was loaded with any
		// keywords already selected
		if (this.tags_dst.getTagCount() > 0)
		{
			dojo.style(this.selectedTagsNode, "display", "inline");
		}

		if ( this._keywordsShown() == false )
		{
			dojo.style(this.suggestionCloudNode, "display", "inline");
		}
	},

	"_hideFilter" : function()
	{
		this._setFilterHide();

		dojo.style(this.filterContainerNode, "display", "none");
		dojo.style(this.selectedTagsNode, "display", "none");
		dojo.style(this.selectedContainerNode, "display", "none");
	},

	"_resetFilter" : function()
	{
		this.tags_dst.resetTags();
		this.selectedTagsUpdated();
	},

	// Show the suggestion cloud, toggle arrow
	"_filterWithKeywords" : function ( evt )
	{
		evt.preventDefault();
		// Toggle visibility of suggestion cloud
		var display = dojo.style(this.filterContainerNode, "display");
		if (display == "none")
		{
			this._showFilter();
		}
		else
		{
			//	TODO: fix
			this._hideFilter();
			this._resetFilter();
		}
	},

	"scrollMore" : function( evt )
	{
		evt.preventDefault();
		var vp = dijit.getViewport();

		var coords = dojo.coords(this.showMoreNode, true);
		var curr_pos = vp.h + vp.t;
		var line_pos = coords.y;

		// Hack
		if ( curr_pos > line_pos+32 )
		{
			this.showMoreContent();
		}
	},

	// Post selected keywords
	// Receive new suggestion keywords and profiles
	// update count 
	"postSelectedKeywords" : function()
	{
	/*
		if (this.debug)
		{
			console.log("TagBrowser.postSelectedKeywords");
		}
*/

		var selected_keywords = this.tags_dst.getTagNames();
		var args_json = dojo.toJson(selected_keywords);

		// Show loading
		dojo.style(this.loadingNode, "display", "block");
		dojo.style(this.showMoreNode, "display", "none");

		var tag_browser = this;
		var suggestion_cloud = this.tags_src;
		var selected_cloud = this.tags_dst;
		var xhrArgs =
		{
			"url" : tag_browser.updateSuggestionTagsUrl,
			"handleAs" : "json",
			"preventCache": true,
			// Arguments to server
			"content" : 
			{
				"selected_keywords": args_json
			},

			"load" : function( obj_response )
			{
				if (tag_browser.debug > 1)
				{
					console.log("TagBrowser.postSelectedKeywords, response=");
					console.log(obj_response);
				}

				if (obj_response)
				{
					// Update content
					tag_browser.resultData = obj_response;
					tag_browser.updateContentDisplay();
					// Set state
					var new_state = obj_response.state;
					dicole.set_global_variable(tag_browser.stateVarName, new_state);
					// Clear the cloud
					suggestion_cloud.resetTags();
					// Set cloud suggestion tags
					suggestion_cloud.setTags(obj_response.tags_html);
					// Need to connect these new tags also ..
					tag_browser._connectTagsForClouds(suggestion_cloud, selected_cloud);
					// Update display
					suggestion_cloud.updateDisplay();
				}
			},

			"error" : function( error )
			{
				console.log("TagBrowser.postSelectedKeywords error = " + error);
			}
		};

		// Make the call
		var deferred = dojo.xhrPost(xhrArgs);
	},

	// Get more profiles from the server
	"showMoreContent" : function()
	{
		if (this.debug)
		{
			console.log("TagBrowser.showMoreContent");
		}

		var tag_browser = this;
		var state = dicole.get_global_variable(this.stateVarName);

		// Show loading
		dojo.style(this.loadingNode, "display", "block");
		dojo.style(this.showMoreNode, "display", "none");

		var xhrArgs =
		{
			"url" : this.moreContentUrl,
			"handleAs" : "json",
			"preventCache": true,
			// Arguments to server
			"content" : 
			{
				"state" : state
			},

			"load" : function( obj_response )
			{
				if (obj_response)
				{
					// Update content
					tag_browser.resultData = obj_response;
					tag_browser.updateContentDisplay();
					// Set state
					var new_state = obj_response.state;
					dicole.set_global_variable(tag_browser.stateVarName, new_state);
				}
			},

			"error" : function( error )
			{
				console.log("TagBrowser.showMoreContent error = " + error);
			}
		};

		// Make the call
		var deferred = dojo.xhrPost(xhrArgs);
	},

	"resetContentDisplay" : function()
	{
		dojo.empty(this.resultsNode);
	},

	// TODO: fix
	"_setCountPlural" : function()
	{
		dojo.style(dojo.byId("browse_result_singular"), "display", "none");
		dojo.style(dojo.byId("browse_result_plural"), "display", "inline");
	},

	"_setCountSingular" : function()
	{
		dojo.style(dojo.byId("browse_result_plural"), "display", "none");
		dojo.style(dojo.byId("browse_result_singular"), "display", "inline");
	},

	"updateContentDisplay" : function()
	{
		if (this.debug)
		{
			console.log("TagBrowser.updateContentDisplay");
			if (this.debug > 2)
			{
				console.log("this.resultData = ");
				console.dir(this.resultData);
			}
		}

		// Update count
		var result_count = this.resultData.result_count;
		if (result_count)
		{
			this.profileCountNode.innerHTML = result_count;

			if (result_count > 1)
			{
				this._setCountPlural();
			}
			else
			{
				this._setCountSingular();
			}
		}

		// Make sure selected tags are displayed
//		dojo.style(this.selectedTagsNode, "display", "inline");

		var display = "none";
		dojo.style(this.loadingNode, "display", display);
		if ( this.resultData.end_of_pages == 0 )
		{
			display = "block";
		}
		else
		{
			display = "none";
		}

		dojo.style(this.showMoreNode, "display", display);
		this.resultsNode.innerHTML += this.resultData.results_html;
	}
});
