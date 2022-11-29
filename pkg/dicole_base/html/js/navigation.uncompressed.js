// [% # $Id: navigation.uncompressed.js,v 1.5 2009-01-07 14:42:32 amv Exp $ # %]

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
var contentDropdownXOffset = -30;
var contentDropdownYOffset = -10;

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

function normalize() {
// removing all obsolete text type nodes for compatible cross browser references to the DOM-tree and its elements
  all=document.getElementsByTagName('*');
  for(i=0;i<all.length;++i) {
    for(j=all[i].firstChild;j;j=nx) {
      nx = j.nextSibling;
      // nodeType == 3 is returned only by text type nodes
      if(j.nodeType == 3 && j.parentNode.nodeName != "SPAN" && j.parentNode.nodeName != 'PRE' && j.parentNode.nodeName != "P" && j.parentNode.nodeName != 'CODE' && j.parentNode.nodeName != 'TEXTAREA' )  {
        j.data = j.data.replace(/\s+/g,' ').replace(/^ +$/g,'') /*normalize-space*/
        // if the node has no data after the normalization replacements, the node will be removed
        if(j.data == '') {
          j.parentNode.removeChild(j)
        }
      }
    }
  }
}

function getObject(objectId) {
  // cross-browser function to get an object's style object given its id
  if(document.getElementById && document.getElementById(objectId)) {
  // W3C DOM
  return document.getElementById(objectId);
  } else if (document.all && document.all(objectId)) {
  // MSIE 4 DOM
  return document.all(objectId);
  } else if (document.layers && document.layers[objectId]) {
  // NN 4 DOM.. note: this won't find nested layers
  return document.layers[objectId];
  } else {
  return false;
  }
} // getObject

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
  styleObject.left = newXCoordinate + 'px';
  styleObject.top = newYCoordinate + 'px';
  return true;
    } else {
  // we couldn't find the object, so we can't very well move it
  return false;
    }
} // moveObject

function focusElement(objectId) {
  // get a reference to the cross-browser object and make sure the object exists
  var object = getObject(objectId);
  if(object) {
    // getting a nice lock on the objects location so that the focused element isn't at the bottom of the screen
    var scroll = object.offsetTop + ((document.body.scrollTop)?document.body.scrollTop:0) - (screen.availHeight / 3);
    object.focus();
    // applying the correct scroll
    window.scrollTo(0, scroll);
    return true;
  } else {
    // we couldn't find the object, so we can't focus on it
    return false;
  }
} // focusElement
// Find the x,y location in pixels for a relatively positioned object
// returns an object with .x and .y properties.
function FindXY(obj){
  var x=0,y=0;
  while (obj!=null){
    x+=obj.offsetLeft;//-obj.scrollLeft;
    y+=obj.offsetTop;//-obj.scrollTop;
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
function collisionDetect(targetObjectId, eventObj) {
  var winH = window.innerHeight;
  var winW = window.innerWidth;
  var x = '0';
  var y = '0';
  var target = getObject(targetObjectId);

  var evLoc = FindXYWH(eventObj);
  var tarLoc = FindXYWH(target);

  // HORIZONTAL position
  if ((evLoc.x + evLoc.w + tarLoc.w) < winW) {
    // RIGHT SIDE OF Event Object
    x = evLoc.x + evLoc.w;
  } else if ((evLoc.x + evLoc.w + tarLoc.w) > winW && (evLoc.x - tarLoc.w) > 0) {
    // LEFT SIDE OF Event Object
    x = evLoc.x - tarLoc.w;
  } else {
    // ON TOP OF Event Object
    x = evLoc.x + evLoc.w - (tarLoc.w / 2);
  }
  // VERTICAL position
  if ((evLoc.y + evLoc.h + tarLoc.h) < winH && (evLoc.y - (tarLoc.h / 2)) < 0) {
    // UNDER Event Object
    y = evLoc.y + evLoc.h;
  } else if ((evLoc.y - tarLoc.h) > 0 && (evLoc.y + evLoc.h + (tarLoc.h / 2)) > winH) {
    // OVER Event Object
    y = evLoc.y + evLoc.h - tarLoc.h;
  } else {
    // ON TOP OF Event Object
    y = evLoc.y + evLoc.h - (tarLoc.h / 2);
  }
  return {x:x,y:y};
}
var confirmOpen = 0;
function showConfirm (targetObjectId, eventObj, relative) {
    if(confirmOpen == '0' && eventObj) {
  // hide any currently-visible popups
  hideCurrentPopup();
  confirmOpen = 1;
  // stop event from bubbling up any farther
  eventObj.cancelBubble = true;
  // move popup div to current cursor position
  // (add scrollTop to account for scrolling for IE)
    if(!relative){
      var coords = collisionDetect(targetObjectId, eventObj);
      moveObject(targetObjectId, coords.x, coords.y);
    }
  // and make it visible
    if( changeObjectVisibility(targetObjectId, 'visible') ) {
        // if we successfully showed the popup
        // store its Id on a globally-accessible object
        window.currentlyVisibleConfirm = targetObjectId;
    } else {
        // we couldn't show the popup, boo hoo!
    }
  }
  return false;
} // showConfirm

function focusThis() {
  x = new Date();
  var inputs = document.getElementsByTagName("input");
  //var textareas = document.getElementsByTagName("textarea");
  if (typeof(inputs[0]) != 'undefined') {
    for (i=0; i<inputs.length; i++) {
      if(inputs[i].type == 'text' ||inputs[i].type == 'password' ||inputs[i].type == 'file') {
        inputs[i].onfocus=function() {
          if(this.value){
            return false;
          } else {
                                                if ( this.className.match(/err/) ){
                                                        this.className="err fieldFilledFocus";
                                                } else if ( this.className.match(/req/) ){
                                                        this.className="req fieldFilledFocus";
                                                } else {
                                                        this.className="fieldFilledFocus";
                                                }
                                        }
                                };
                                inputs[i].onblur=function() {
                                        if(this.value){
                                                if ( this.className.match(/err/) ){
                                                        this.className="err fieldFilledOk";
                                                } else if ( this.className.match(/req/) ){
                                                        this.className="req fieldFilledOk";
                                                } else {
                                                        this.className="fieldFilledOk";
                                                }
                                        } else if ( this.className.match(/err/) ){
                                                this.className="err fieldFilledNotOk";
                                        } else if ( this.className.match(/req/) ){
                                                this.className="req fieldFilledNotOk";
                                        } else {
                                                this.className="fieldFilledUnknown";
                                        }
                                };
      }
    }
    if(!focusElement('focusElement') && inputs[0].type == 'text' || inputs[0].type == 'password' || inputs[0].type == 'file'){
      inputs[0].focus();
    }
  }
/*
  if (typeof(textareas[0]) != 'undefined') {
    for (i=0; i<textareas.length; i++) {
      textareas[i].onfocus=function() {
        this.style.background="rgb(206,224,236)";
      };
      textareas[i].onblur=function() {
        this.style.background="";
      };
    }
    if (typeof inputs[0] == 'undefined' && !focusElement('focusElement')) { textareas[0].focus(); }
  }
*/
}

function closeMenus() {
  if(typeof(openMenus) != 'undefined' && openMenus[0]) {
    if(getObject("ieFix")){
      var ieFix =getObject("ieFix");
      ieFix.parentNode.removeChild(ieFix);
    }
    var i = 0;
    while(i<openMenus.length) {
        if (openMenus[i].id) {
          var niin = getObject(openMenus[i].id);
          niin.style.visibility= 'hidden';
        } else {
          var geijjo = openMenus[i];
          geijjo.style.visibility = 'hidden';
        }
      i++;
    }
  }
}

var agt = navigator.userAgent.toLowerCase();
var is_major = parseInt(navigator.appVersion);
var is_gecko = (agt.indexOf('gecko') != -1);
var is_nav = (agt.indexOf('mozilla')!=-1) && (agt.indexOf('spoofer')==-1);
var is_nav6up = (is_nav && (is_major >= 5));
var is_opera = (agt.indexOf("opera") != -1);
var is_ie = ((agt.indexOf("msie") != -1) && (agt.indexOf("opera") == -1));
var is_konqueror = (navigator.userAgent.indexOf('Konqueror') != -1);

if(is_nav){
  var parentLeft = (screen.availWidth - 320);
  var childLeft = (screen.availWidth - 310);
  var parentHeight = (screen.availHeight - 30);
  var childHeight = (screen.availHeight - 45);
  var parentResizeWidth = (screen.availWidth - 15);
  var parentResizeHeight = (screen.availHeight - 30);
}
if(is_ie) {
  var parentLeft = (screen.availWidth - 305);
  var childLeft = (screen.availWidth - 309);
  var parentHeight = (screen.availHeight);
  var childHeight = (screen.availHeight - 25);
  var parentResizeWidth = (screen.availWidth);
  var parentResizeHeight = (screen.availHeight);
}

function popUp(URL) {
  window.resizeTo(parentLeft, parentHeight);
  jaakko=window.open(URL, 'helpWindow','toolbar=0,scrollbars=1,location=0,statusbar=0,menubar=0,resizable=0,width=300,height=' + childHeight + ',left=' + childLeft + ',top=0');
}

function resizeParent() {
  if(opener.window) {
    opener.window.resizeTo(parentResizeWidth, parentResizeHeight);
  }
  window.close();
}

function hideConfirm() {
  changeObjectVisibility(window.currentlyVisibleConfirm, 'hidden');
  confirmOpen = 0;
}

function filefieldToParent(This) {
  var formValue = This.form.selection.value;
  if (top.opener.completeurl) { formValue = '/select_file/view' + formValue };
  top.opener.filefield.value = formValue;
  top.close();
}


// *************************
// content object routines *
// *************************

function showContentDropdown (targetObjectId, eventObj) {

    var ddId = 'content_dropdown_' + targetObjectId;
    var selId = 'content_dropdown_selected_' + targetObjectId;

    var ddLoc = FindXYWH( getObject(ddId) );
    var selLoc = FindXYWH( getObject(selId) );

    var pageXOffset = (document.all) ? document.body.scrollLeft : window.pageXOffset;
    var pageYOffset = (document.all) ? document.body.scrollTop : window.pageYOffset;

    var newX = eventObj.clientX + selLoc.x - ddLoc.x + contentDropdownXOffset + pageXOffset;
    var newY = eventObj.clientY - selLoc.y + ddLoc.y + contentDropdownYOffset + pageYOffset;

    var screenSize = getScreenSize();
    if ( screenSize.x < newX + ddLoc.w ) {
        newX = screenSize.x - ddLoc.w - 24;
        if ( eventObj.clientX > newX + ddLoc.w ) {
            newX = eventObj.clientX - ddLoc.w + 1;
        }
    }

    moveObject(ddId, newX, newY);

    showPopup( ddId, eventObj );

    return false;
}

document.onclick=function(){hideCurrentPopup();closeMenus();helpClose();};

// *************************
// context help routines
// *************************

var help_open = 0;

function helpClose() {
    if ( help_open == 1 ) {
        help_open = 0;
        getObject('helpIframe').style.display = 'none';
        getObject('helpBox').style.visibility = 'hidden';
    }
    return false;
}

var pos = 0;
var speed = 0;
var element = null;
var Id = null;

function helpOpen(url) {
    initIframe("helpIframe", "helpContainer", url);
    // No opacity during scrolling
    getObject('helpBox').style.opacity = "1.0";

    var screenSize = getScreenSize();
    var boxHeight = screenSize.y - Math.floor(screenSize.y / 2);

    getObject('helpIframe').style.height = boxHeight + "px";
    getObject('helpIframe').style.width = Math.floor(screenSize.x / 3) + "px";
    getObject('helpContainer').style.height = boxHeight + "px";
    getObject('helpContainer').style.width = Math.floor(screenSize.x / 3) + "px";
//    getObject('helpBoxInner').style.visibility = 'visible';
    getObject('helpBox').style.visibility = 'visible';
    pos = -boxHeight - 100;
    speed = 20;
    element = getObject('helpBox');
    moveHelp();
    return false;
}

function moveHelp() {
    var endpoint = 10;
    if ( speed > 1 && (endpoint - pos) <= 200 ) {
        speed = speed - 1;
    }
    pos = pos + speed;
    element.style.top = pos + "px";
    if ( pos >= endpoint ) {
        clearTimeout(Id); Id = 0;
        help_open = 1;

        getObject('helpBox').style.opacity = "0.92";
        setTimeout( "delayedIframeDisplay()", 10 );
    }
    else {
       Id = setTimeout( "moveHelp()", 10 );
    }
}

function delayedIframeDisplay() {
        getObject('helpIframe').style.display = 'block';
}

function initIframe( parentID, frameID, url ) {
    if ( !getObject(parentID) ) {
        var helpIframe = document.createElement('iframe');
        helpIframe.id = parentID;
        helpIframe.src = url;
        helpIframe.style.display = 'none';
        getObject(frameID).appendChild(helpIframe);
    }
}

function getScreenSize() {
    var x,y;
    if ( self.innerHeight ) { // all except Explorer
        x = self.innerWidth;
        y = self.innerHeight;
    }
    // Explorer 6 Strict mode
    else if ( document.documentElement && document.documentElement.clientHeight ) {
        x = document.documentElement.clientWidth;
        y = document.documentElement.clientHeight;
    }
    else if ( document.body ) { // other Explorers
        x = document.body.clientWidth;
        y = document.body.clientHeight;
    }
    return { x:x, y:y };
}

// *************************
// Generate random password
// *************************

function getRandomNum(lbound, ubound) {
        return (Math.floor(Math.random() * (ubound - lbound)) + lbound);
}

function getRandomChar() {
    var numberChars = "23456789";
    var lowerChars = "abcdefghijkmnpqrstuvwxyz";
    var upperChars = "ABCDEFGHJKLMNPQRSTUVWXYZ";
    var charSet = "";
    charSet += numberChars;
    charSet += lowerChars;
    charSet += upperChars;
    return charSet.charAt(getRandomNum(0, charSet.length));
}

function generatePassword(passLength) {
  if ( !passLength ) {
        passLength = 6;
    }
    var rc = "";
    if (length > 0) rc = rc + getRandomChar();
    for (var idx = 1; idx < passLength; ++idx) {
        rc = rc + getRandomChar();
    }
    return rc;
}
