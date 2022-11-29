var openMenus = new Array;

function onMO(object, child, number) {
	if(move = FindXYWH(object.firstChild)) {
		//alert(move.x + ' ' + move.y + ' ' + move.h);
		if(child.id){
			child.style.left = move.x  + 'px';
			child.style.top = move.y + move.h + 'px';
		} else {
			child.style.left = move.x  + move.w + 'px';
			child.style.top = move.y - 1 + 'px';
		}
	}
	var childDims = FindXYWH(child);
	object.firstChild.onmouseover=function(){
		if(!child.id){
		this.timer = setTimeout(function(){child.style.visibility = 'visible';}, 200);
			for(i=0;i<openMenus.length;i++){
				if(openMenus[i] == child) {
					break;
				} else if(i == (openMenus.length-1)){
					openMenus[openMenus.length] = child;
				}
			}
		}
	}
	object.firstChild.onclick=function(e){
		if (!e) var e = window.event;
			e.cancelBubble = true;
		if (e.stopPropagation) e.stopPropagation();
		if (child.id){
			var id = child.id
			closeMenus();
			// This is a quick hack to make the menus work on IE5.5+ due to the fact that layer elements aren't in the same z-index plane as windowed elements
			if(child.insertAdjacentHTML && is_ie){
				var layer = "<iframe id=\"ieFix\" style=\"display: block; padding: 0; margin: 0; border: 0; position: absolute; z-index: 101; left:" + childDims.x + "; top:" +childDims.y + "; width:" +childDims.w+"; height:" +childDims.h +";\"src=\"javascript:false;\" frameBorder=\"0\" scrolling=\"no\"></IFRAME>"
				child.insertAdjacentHTML("afterEnd", layer);
			}
			if(changeObjectVisibility(id, 'visible')){
				openMenus = new Array();
				openMenus[0] = child;
			}
		}
	}
	object.firstChild.onmouseout=function(){
		clearTimeout(this.timer);
	}
}

function onMOS(object, child){
	var parent = object.parentNode;
	object.firstChild.onmouseover = function(){
	if(openMenus[openMenus.length-1]){
			for(i=openMenus.length-1;i>0;i--){
				if(openMenus[i] == parent) {
					break;
				} else {
					closeMenu(openMenus[i]);
				}
			}
		}
	}
}

function getInfos() {
	var navi = getObject("navContainer");
	var lis = navi.getElementsByTagName("li");
	var number = 0;
		for (i=0; i<lis.length; i++) {
			var joo = new Array();
			joo = lis[i].getElementsByTagName("ul");
			if(joo[0] && joo[0].nodeType == '1') {
				onMO(lis[i], joo[0], number);
				number++;
			} else if (lis[i]) {
				onMOS(lis[i], joo[0]);
			}
		}
}

function closeMenu(object) {
	if(object.style.visibility = 'hidden') {
		return true;
	} else {
		return false;
	}
}

normalize();
getInfos();
