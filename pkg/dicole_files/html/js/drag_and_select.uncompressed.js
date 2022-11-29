var mouseDwn = '0';
var dontTouch = '0';
function initDragAndSelect(){
if(getObject('list')){
	puu = getObject("list");
	var inputs = puu.getElementsByTagName("input");
	if(typeof(inputs[0]) != 'undefined' && inputs[0].type == 'checkbox'){
		var child = 'tr'
		dragAndSelect(puu, child, 'firstChild');
		puu.onmousedown=function(){ mouseDwn = '1';}
		puu.onmouseup=function(){ mouseDwn = '0';}
		document.onmouseup=function(){ mouseDwn = '0';}
	}
} else if(getObject('tree')){
	puu = getObject("tree");
	var inputs = puu.getElementsByTagName("input");
	if(typeof(inputs[0]) != 'undefined' && inputs[0].type == 'checkbox'){
		var child = 'div'
		dragAndSelect(puu, child, 'firstChild');
		puu.onmousedown=function(){ mouseDwn = '1';}
		puu.onmouseup=function(){ mouseDwn = '0';}
		document.onmouseup=function(){ mouseDwn = '0';}
	}
}
}

function dragAndSelect(parent, child, dontT) {
	var children = parent.getElementsByTagName(child);
	var inps = parent.getElementsByTagName("input");
	//var specials = parent.getElementsByTagName(special);
	for (i=0; i<children.length; i++) {
		children[i].onmouseover=function() {
			if(this.firstChild.firstChild){
				if(this.firstChild.firstChild.checked && mouseDwn == '1') {
					this.firstChild.firstChild.checked="";
					this.style.backgroundColor="";
				} else if (this.firstChild.firstChild.checked == '' && mouseDwn == '1') {
					this.firstChild.firstChild.checked="checked";
					this.style.backgroundColor="rgb(206,224,236)";
				}
			}
		}
		if(dontT){
			dontO = 'children[i].' + dontT;
			dontObj = eval(dontO);
			dontObj.onmouseover=function(){
				dontTouch= '1';
			}
			dontObj.onmouseout=function() {
				dontTouch= '0';
			}
		}
		children[i].onclick=function() {
			if(this.firstChild.firstChild){
				if(this.firstChild.firstChild.checked && dontTouch == '0') {
					this.firstChild.firstChild.checked="";
					this.style.backgroundColor="";
				} else if (this.firstChild.firstChild.checked == '' && dontTouch == '0') {
					this.firstChild.firstChild.checked="checked";
					this.style.backgroundColor="rgb(206,224,236)";
				}
			}
		}
	}
	for(j=0; j<inps.length; j++){
		inps[j].onclick=function(){
			if(!this.parentNode.parentNode.style.backgroundColor) {
				this.parentNode.parentNode.style.backgroundColor="rgb(206,224,236)";
			} else {
				this.parentNode.parentNode.style.backgroundColor="";
			}
		}
		inps[j].onmouseup=function(){
			mouseDwn = '0';
		}
	}
}
normalize();
initDragAndSelect();