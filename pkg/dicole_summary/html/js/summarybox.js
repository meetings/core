// [% # $Id: summarybox.js,v 1.22 2008-03-01 14:43:03 amv Exp $ # %]

//*********************************************************
//			Dynamic Summarybox Layout
//			with matrix and open/closed status
//			updates to the cookie
//
//			(c) Tony Riikonen
//*********************************************************

// global variable for checking wether or not the hashedArray of Summaryboxes has been generated
var boxesHash = '';

function getBoxFromControls( controls ) {
    var box = controls;
    while ( box ) {
        var classi = box.getAttribute('class');
        if ( ! classi ) { classi = box.className; }
        if ( /box_container/i.test(classi) ) return box;
        try {
            box = box.parentNode;
            box.getAttribute('class');
        } catch ( e ) {
            box = false;
        }
    }
}

function getContentFromBox( element ) {
    if ( element && element.childNodes ) {
        for (var i=0; i < element.childNodes.length; i++) {
            var child = element.childNodes[i];
            if ( ! /table|tbody|td|tr|div/i.test( child.nodeName ) ) continue;
            var classi = child.getAttribute('class');
            if ( ! classi ) { classi = child.className; }
            if( /desktopBoxContent/i.test(classi) ) return child;
            var ret = getContentFromBox( child );
            if ( ret ) return ret;
        }
    }
    return false;
}

function moveBox(direction, object) {
    
	var info = getBoxInfo(object);

	var cols = info.cols
	var rows = info.rows;
	var box = info.box
	var id = info.id
	var parent = info.parent;
	var x = info.x;
	var y = info.y;

	if(boxesHash != '1') { getAllBoxesInfo('summaries'); }

	if(direction == 'up') {
		// checking that the box to be moved is not first in the direction that it is trying to move and thus can't go any further
		if (y == 0) {
			return false;
		} else {
			//for (i=1; i<rows.length; i++) {
				if(box == rows.rows[y]) {
					// the original box that was called to move
					var original = rows.rows[y];
					// the box that has to be moved out of the way of the original box and into its place
					var replacer = rows.rows[y-1]; /* direction is up, so the replacer box must be on top of the original box, thus -1 in the row list */
					// checking to see if there is a box under the original box (+1) to determine if we have to place the replacer box before another element
					if( rows.rows[y+1] ) {
						// the box under the orignal box, before which we place the replacer
						var before = rows.rows[y+1];
						// replacing the replacer with the original
			    		var replaced = parent.replaceChild(original, replacer);
						// inserting the replacer before the box under the original box
						var insertBefore = parent.insertBefore(replacer, before);
					// there is no box under the original so we need only to append the replacer to the parent
					} else {
						// replacing the replacer with the original
						var replaced = parent.replaceChild(original, replacer);
						// appending the replacer to the parent
						var append = parent.appendChild(replacer);
					}
					// updating the boxmatrix with the new coordinates
					if(/.closed/.test(hashedArray[id])) {
						hashedArray[id] = x + '.' + (y - 1) + '.closed';
					} else {
						hashedArray[id] = x + '.' + (y - 1);
					}
					if(/.closed/.test(hashedArray[replacer.id])) {
						hashedArray[replacer.id] = x + '.' + y + '.closed';
					} else {
						hashedArray[replacer.id] = x + '.' + y;
					}
				}
			//}
		}
		updateCookie();
		return false;
	} else if(direction == 'down') {
		// checking that the box to be moved is not first in the direction that it is trying to move and thus can't go any further
		if (y == rows.length - 1) {
			return false;
		} else {
			//for (i=0; i<rows.length; i++) {
				if(box == rows.rows[y]) {
					// the original box that was called to move
					var original = rows.rows[y];
					// the box that has to be moved out of the way of the original box and into its place
					var replacer = rows.rows[y+1]; /* direction is down, so the replacer box must be below of the original box, thus +1 in the row list */
					// replacing the replacer with the original
					var replaced = parent.replaceChild(original, replacer);
					// inserting the replacer before the box under the original box
					var insertBefore = parent.insertBefore(replacer, original);
					// updating the boxmatrix with the new coordinates
					if(/.closed/.test(hashedArray[id])) {
						hashedArray[id] = x + '.' + (y + 1) + '.closed';
					} else {
						hashedArray[id] = x + '.' + (y + 1);
					}
					if(/.closed/.test(hashedArray[replacer.id])) {
						hashedArray[replacer.id] = x + '.' + y + '.closed';
					} else {
						hashedArray[replacer.id] = x + '.' + y;
					}

				}
			//}
		}
		updateCookie();
		return false;
	} else if(direction == 'left') {
		// checking that the box to be moved is not first in the direction that it is trying to move and thus can't go any further
		if (x == 0) {
			return false;
		} else {
			cols.cols[x - 1].appendChild(box);
			if(/.closed/.test(hashedArray[id])) {
				hashedArray[id] = (x - 1) + '.' + (cols.cols[x - 1].childNodes.length - 1) + '.closed';
			} else {
				hashedArray[id] = (x - 1) + '.' + (cols.cols[x - 1].childNodes.length - 1);
			}
		}
		updateCookie();
		return false;
	} else if(direction == 'right') {
		// checking that the box to be moved is not first in the direction that it is trying to move and thus can't go any further
		if (x == cols.length - 1) {
			return false;
		} else {
			cols.cols[x + 1].appendChild(box);
			if(/.closed/.test(hashedArray[id])) {
				hashedArray[id] = (x + 1) + '.' + (cols.cols[x + 1].childNodes.length - 1) + '.closed';
			} else {
				hashedArray[id] = (x + 1) + '.' + (cols.cols[x + 1].childNodes.length - 1);
			}
		}
		updateCookie();
		return false;
	} else if(direction == 'close') {
		getContentFromBox( box ).style.display = 'none';
		object.onclick=function(){ moveBox('open', this); }
		object.firstChild.setAttribute("src","/images/theme/default/content/summary/box-open.png");
		hashedArray[id] = hashedArray[id] + '.closed';
		updateCookie();
		return false;
	} else if(direction == 'open') {
		//currentBox.childNodes[0].childNodes[1].style.display = '';
		//object.onclick=function(){ moveBox('close', this); }
		//object.firstChild.data='X';
		hashedArray[id].replace(/.closed/,'');
		updateCookie();
		return true;
	} else if(direction == 'info') {
		alert('rows: ' + rows.length + ' cols: ' + cols.length + ' ' + '\n' + 'Box ID: ' + currentBox_id + ': ' + hashedArray[currentBox_id]);
	}
}

// aquiring the columns in which the Summaryboxes are
function getColumns(parentObj) {
	var parent = getObject(parentObj);
 	if (parent.childNodes.length) {
        var i;
        var columns = new Array();
        for ( i = 0; i <  parent.childNodes.length; i++ ) {
            var child = parent.childNodes[i];
            // push the div inside child as column
            if ( /td/i.test( child.nodeName ) ) {
                for ( j = 0; j < child.childNodes.length; j++ ) {
                    var div = child.childNodes[j];
                    if ( /div/i.test( div.nodeName ) ) {
                        columns.push( div );
                        break;
                    }
                }
            }
        }
		return { cols:columns,length:columns.length }
	} else {
		return false;
	}
}

// aquiring the Summaryboxes as rows within a specific column
function getRows(parentObj) {
	var parent = parentObj;
	if (parent.childNodes.length) {
        var i;
        var rows = new Array();
        for ( i = 0; i <  parent.childNodes.length; i++ ) {
            var child = parent.childNodes[i];
            if ( ! /div/i.test( child.nodeName ) ) continue;
            var classi = child.getAttribute('class');
            if ( ! classi ) { classi = child.className; }
            if ( /box_container/i.test( classi ) ) rows.push( child );
        }
		return { rows:rows,length:rows.length }
	} else {
		return false;
	}
}

function getAllBoxesInfo(parentObj) {
// hashedArray contains the position and open/closed status information of each summarybox
// each Summaryboxes information can be retrieved and updated by accessing hashedArray["Summarybox ID"]

	hashedArray=new Array();

	var cols = getColumns(parentObj);
	var i = 0;
	var j = 0;
	var x = 0;
	var y = 0;
	var coords = '0.0';

	var boxes = new Array();

// Looping through all the Summarybox columns
	while(i < cols.length)
	{
		// Assigning the row values of each column into a temporary variable
		temp = getRows(cols.cols[i]);
		// Testing wether or not any rows were retrieved, if so, assign the rows to the boxes array
		if(temp.rows) { boxes[i] = temp.rows; } else { boxes[i] = '' }

		// Looping through each columns rows
		for(j=0; j<boxes[i].length; j++) {
			// Assigning respective values of both column and row to coordinate variables
			x = i;
			y = j;
			coords = x + '.' + y;
			// Checking wether or not a Summarybox has been generated without content by the template and should be assigned closed definition
			if(!getContentFromBox(boxes[i][j])) {
				hashedArray[boxes[i][j].id]= coords + '.closed';
			} else {
				hashedArray[boxes[i][j].id]= coords;
			}
		}
		i++;
	}
	// updating info into the cookie
	updateCookie();
	boxesHash = '1';
}

function updateCookie() {
// Assigning all the boxes id's, coordinates and open-state to the box-variable for the cookie
    var box = '';
	for(var i in hashedArray){
        if (!i || i == 'undefined' || ! hashedArray[i]) continue;
        box = box + i + '%20' + hashedArray[i] + escape('#');
	}

// Assigning the box-variable to the cookie's boxes-variable
	document.cookie = 'summary' + '_' + OIPath_action_id + '=' + box +';' + 'path=' + OIPath_dep + ';';
}

function updateFromCookie() {

hashedArray = new Array();
// Retrieving information from the cookie
	var cookieInfo = document.cookie;
// creating a temp array for processing the cookie information
	var tempArray = cookieInfo.split(';');

// create an array of arrays for better looping
	var finalArray = new Array();
	var xyz = 0;
	for (var i in tempArray) {
		finalArray[xyz] = tempArray[i].split('=');
		xyz++;
	}

// looping through to find the boxes-variable
	for (i in finalArray) {
		if (finalArray[i][0] == 'summary' + '_' + OIPath_action_id) {
			boxesValues = finalArray[i][1]; /* assign the value for boxes to new variable */
		}
	}

	boxesValuesSplit = boxesValues.split('%23');

	var tempArray2 = new Array();
	var zyx = 0;
	for (var i in boxesValuesSplit) {
		tempArray2[zyx] = boxesValuesSplit[i].split('%20');
		hashedArray[tempArray2[zyx][0]] = tempArray2[zyx][1];
		zyx++;
	}
}

function getBoxInfo(object) {
	var cols = getColumns("summaries");
	var box = getBoxFromControls(object);
	var id = box.getAttribute("id");
	var parent = box.parentNode;
	var rows = getRows(parent);

	for (i=0; i<cols.cols.length; i++) {
		if(parent == cols.cols[i]) { var x = i; break; }
	}
	for (i=0; i<rows.rows.length; i++) {
		if(box == rows.rows[i]) { var y = i; break;}
	}
	var ret = { cols:cols,rows:rows,box:box,id:id,parent:parent,x:x,y:y }
    return ret;
}
