var xOffset = 50;
var yOffset = 0;


function fileActionPopup() {
		var div = getObject("tree");
		var anchors = div.getElementsByTagName("a");
		for (i=0; i<anchors.length; i++) {
				anchors[i].onmouseover=function() { hideCurrentPopup; window.currentFilePopupRef = this.href;var thisObj = this; var boxID = this.id; this.showTimer = setTimeout(function(){ showActionPopup(boxID, thisObj)}, 500); }
				anchors[i].onmouseout=function() { clearTimeout(this.showTimer); }
			}
		}

function submitLocation(hrefReplace) {
	var replacedHref = window.currentFilePopupRef.replace(/\/tree\//, hrefReplace);
	location.href=replacedHref;
}
function showActionPopup (targetObjectId, eventObj) {
    if(eventObj) {
	// hide any currently-visible popups
	hideCurrentPopup();
	// stop event from bubbling up any farther
	eventObj.cancelBubble = true;
	// move popup div to current cursor position
	// (add scrollTop to account for scrolling for IE)
	var whereIsIt = FindXYWH(eventObj);
	var eccess = whereIsIt.x + whereIsIt.w + 10;
	var yccess = whereIsIt.y + yOffset;
	var targetObj = targetObjectId.replace(/_.+/, '');
	moveObject(targetObj, eccess, yccess);
	// and make it visible
	if(changeObjectVisibility(targetObj, 'visible') ) {
	    // if we successfully showed the popup
	    // store its Id on a globally-accessible object
	    window.currentlyVisiblePopup = targetObj;
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