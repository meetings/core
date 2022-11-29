// [% # $Id: showhidelayer.uncompressed.js,v 1.2 2009-01-07 14:42:32 amv Exp $ # %]

// ********************************
// application-specific functions *
// ********************************

// Usage:
// Add in the top of the body:
//
// <div onclick="event.cancelBubble = true;" class="infobox" id="nameOfPopup">
// Example popup.
// </div>
// 
// To request the popup:
//
// <a href="#" onMouseOut="hideCurrentPopup();"
// onMouseOver="showPopup('nameOfPopup', event);">Popup</a>

// store variables to control where the popup will appear relative to the cursor position
// positive numbers are below and to the right of the cursor, negative numbers are above and to the left
var xOffset = 50;
var yOffset = -10;

function showPopupMove (targetObjectId, eventObj) {
    if(eventObj) {
	// hide any currently-visible popups
	hideCurrentPopup();
	// stop event from bubbling up any farther
	eventObj.cancelBubble = true;
	// move popup div to current cursor position 
	// (add scrollTop to account for scrolling for IE)
	var newXCoordinate = (eventObj.pageX)?eventObj.pageX + xOffset:eventObj.x + xOffset + ((document.body.scrollLeft)?document.body.scrollLeft:0);
	var newYCoordinate = (eventObj.pageY)?eventObj.pageY + yOffset:eventObj.y + yOffset + ((document.body.scrollTop)?document.body.scrollTop:0);
	moveObject(targetObjectId, newXCoordinate, newYCoordinate);
	// and make it visible
	if( changeObjectVisibility(targetObjectId, 'visible') ) {
	    // if we successfully showed the popup
	    // store its Id on a globally-accessible object
	    window.currentlyVisiblePopup = targetObjectId;
	    return true;
	} else {
	    // we couldn't show the popup, boo hoo!
	    return false;
	}
    } else {
	// there was no event object, so we won't be able to position anything, so give up
	return false;
    }
} // showPopup

function showPopup (targetObjectId, eventObj) {
    if(eventObj) {
	// hide any currently-visible popups
	hideCurrentPopup();
	// stop event from bubbling up any farther
	eventObj.cancelBubble = true;
	if( changeObjectVisibility(targetObjectId, 'visible') ) {
	    // if we successfully showed the popup
	    // store its Id on a globally-accessible object
	    window.currentlyVisiblePopup = targetObjectId;
	    return true;
	} else {
	    // we couldn't show the popup, boo hoo!
	    return false;
	}
    } else {
	// there was no event object, so we won't be able to position anything, so give up
	return false;
    }
} // showPopup

function hideCurrentPopup(targetObjectId) {
    // note: we've stored the currently-visible popup on the global object window.currentlyVisiblePopup
    if(window.currentlyVisiblePopup) {
	changeObjectVisibility(window.currentlyVisiblePopup, 'hidden');
	window.currentlyVisiblePopup = false;
    }
    if (targetObjectId && document.getElementById(targetObjectId) )
    {
    	document.getElementById(targetObjectId).style.visibility = 'hidden';
	}
} // hideCurrentPopup

// ************************
// layer utility routines *
// ************************

function getStyleObject(objectId) {
    // cross-browser function to get an object's style object given its id
    if(document.getElementById && document.getElementById(objectId)) {
        // W3C DOM
        return document.getElementById(objectId).style;
    } else if (document.all && document.all(objectId)) {
        // MSIE 4 DOM
        return document.all(objectId).style;
    } else if (document.layers && document.layers[objectId]) {
        // NN 4 DOM.. note: this won't find nested layers
        return document.layers[objectId];
    } else {
        return false;
    }
} // getStyleObject

function changeObjectVisibility(objectId, newVisibility) {
    // get a reference to the cross-browser style object and make sure the object exists
    var styleObject = getStyleObject(objectId);
    if(styleObject) {
        styleObject.visibility = newVisibility;
        return true;
    } else {
        // we couldn't find the object, so we can't change its visibility
        return false;
    }
} // changeObjectVisibility

function moveObject(objectId, newXCoordinate, newYCoordinate) {
    // get a reference to the cross-browser style object and make sure the object exists
    var styleObject = getStyleObject(objectId);
    if(styleObject) {
        styleObject.left = newXCoordinate;
        styleObject.top = newYCoordinate;
        return true;
    } else {
        // we couldn't find the object, so we can't very well move it
        return false;
    }
} // moveObject
