function fileActionPopup(object, type) {
				hideCurrentPopup();
				window.currentFilePopupRef = object.href;
				var thisObj = object;
				document.open_files_action_box = object;
				var boxID = 'files_action_box_' + type;
				document.open_files_action_box = setTimeout(function(){ showActionPopup(boxID, thisObj)}, 300);
			}
function fileActionPopupHide() {
				clearTimeout(document.open_files_action_box);
}

function submitLocation(hrefReplace){
	var replacedHref = window.currentFilePopupRef.replace(/\/tree\//, hrefReplace);
	location.href=replacedHref;
}
function showActionPopup (targetObjectId, eventObj) {
    if(confirmOpen == '0' && eventObj) {
	// hide any currently-visible popups
	hideCurrentPopup();
	// stop event from bubbling up any farther
	eventObj.cancelBubble = true;
	// move popup div to current cursor position
	// (add scrollTop to account for scrolling for IE)
	var whereIsIt = FindXYWH(eventObj);
	var eccess = whereIsIt.x + whereIsIt.w + 7;
	var yccess = whereIsIt.y + yOffset + 8;
	var targetObj = targetObjectId;
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

// Find the x,y location in pixels for a relatively positioned object
// returns an object with .x and .y properties.
function FindXY(obj){
	var x=0,y=0;
	while (obj!=null){
		x+=obj.offsetLeft;
		y+=obj.offsetTop;
		obj=obj.offsetParent;
	}
	return {x:x,y:y};
}

// Find the x,y location in pixels for a relatively positioned object
// returns an object with .x, .y, .w (width) and .h (height) properties.
function FindXYWH(obj){
	var objXY = FindXY(obj);
	return objXY?{ x:objXY.x, y:objXY.y, w:obj.offsetWidth, h:obj.offsetHeight }:{ x:0, y:0, w:0, h:0 };
}


