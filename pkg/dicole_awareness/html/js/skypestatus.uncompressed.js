/* [% # $Id: skypestatus.uncompressed.js,v 1.5 2009-04-21 11:55:53 amv Exp $ # %]

Updates all the Skype user icons for users that are logged in. Gets the XML
file via XmlHttpRequest (dojo.io.bind takes care of this) and then updates the
status icons.

TODO: compress or something ?

*/

dojo.require("dojo.event.*");

var StatusNum =
{
	UNKNOWN		: 0,
	OFFLINE		: 1,
	ONLINE		: 2,
	AWAY		: 3,
	NOTAVAILABLE	: 4,
	DONOTDISTURB	: 5,
	INVISIBLE	: 6,
	SKYPEME		: 7
};

var Defs =
{
	/* The update interval, */
	INTERVAL	: 20000,
	TYPE_ELEMENT	: 1,
	USER_PREFIX	: "user_",
	ICON_FORMAT	: ".gif",
	TAG_PREFIX	: "skype_icon_",
	ICON_PREFIX	: "skype_status_",
	STATUS_URL	: "/skype/status/" + DicoleTargetId,
	STATUS_TEXT	: "Skype"
};

/* TODO: get this from somewhere else ? */
function getObject(objectId) {
	if(document.getElementById && document.getElementById(objectId)) {
	return document.getElementById(objectId);
	} else if (document.all && document.all(objectId)) {
	return document.all(objectId);
	} else if (document.layers && document.layers[objectId]) {
	return document.layers[objectId];
	} else {
	return false;
	}
}

/* Changes one Skype user icon to the right image
   user_id_str is in the format user_USERID, eg. user_10 */
function updateIcon(user_id_str, status_code, status_text)
{
	if (status_code < StatusNum.UNKNOWN || status_code > StatusNum.SKYPEME)
	{
		status_code = StatusNum.UNKNOWN;
	}
	if (status_text == "")
	{
		status_text = Defs.STATUS_TEXT;
	}

	var img_id = Defs.TAG_PREFIX + user_id_str;
	icon = getObject(img_id);
	if (icon != false)
	{
		/* Replace the image src, alt and title */
		var newsrc = Defs.ICON_PREFIX + status_code + Defs.ICON_FORMAT;
		var regexp = new RegExp(Defs.ICON_PREFIX + "[0-9]" +
		Defs.ICON_FORMAT);
		icon.src = icon.src.replace(regexp, newsrc);
		icon.alt = status_text;
		icon.title = icon.alt;
		//alert(newsrc + ' ' + regexp + ' ' + icon.src);
	}
}

/* Updates skype icons for all users */
function updateStatusIcons(xmldoc)
{
	var nodes = xmldoc.documentElement.childNodes;
	var len = nodes.length;
	var node;

	//alert("updateStatusIcons called, num nodes: " + len);

	/* Do nothing if for some reason we have the wrong xml file */
	if (xmldoc.documentElement.nodeName != "skype_status")
	{
		return;
	}

	for (i=0; i<len; i++)
	{
		node = nodes.item(i);
		if (node.nodeType == Defs.TYPE_ELEMENT)
		{
			/* Update the icon for one user specified in the
			 * nodeName */
			updateIcon(node.nodeName, 
			parseInt(node.getAttribute("status_code")),
			node.getAttribute("status_text"));
		}
	}
}

/* This is called between regular intervals to update the skype statuses */
function pollStatus()
{
	/* This sets up the XmlHttpRequest and returns the data as
	 * XmlDocument object that contains the Skype statuses of all users
	 * logged in */
	dojo.xhr(
	{ 
		url: Defs.STATUS_URL,
	        preventCache: true,
		handleAs: "xml",
		load: function(data, evt) {
			updateStatusIcons(data);
		}
	}
	);

	setTimeout(pollStatus, Defs.INTERVAL);
}

function initSkypeUpdate()
{
	pollStatus();
}

/* Start the update when page has loaded */
dojo.connect(window, "onload", initSkypeUpdate);
//alert('Skype status script loaded');
