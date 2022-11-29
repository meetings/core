var xOffset=50;
var yOffset=-10;
function showPopupMove(_1,_2){
if(_2){
hideCurrentPopup();
_2.cancelBubble=true;
var _3=(_2.pageX)?_2.pageX+xOffset:_2.x+xOffset+((document.body.scrollLeft)?document.body.scrollLeft:0);
var _4=(_2.pageY)?_2.pageY+yOffset:_2.y+yOffset+((document.body.scrollTop)?document.body.scrollTop:0);
moveObject(_1,_3,_4);
if(changeObjectVisibility(_1,"visible")){
window.currentlyVisiblePopup=_1;
return true;
}else{
return false;
}
}else{
return false;
}
}
function showPopup(_5,_6){
if(_6){
hideCurrentPopup();
_6.cancelBubble=true;
if(changeObjectVisibility(_5,"visible")){
window.currentlyVisiblePopup=_5;
return true;
}else{
return false;
}
}else{
return false;
}
}
function hideCurrentPopup(_7){
if(window.currentlyVisiblePopup){
changeObjectVisibility(window.currentlyVisiblePopup,"hidden");
window.currentlyVisiblePopup=false;
}
if(_7&&document.getElementById(_7)){
document.getElementById(_7).style.visibility="hidden";
}
}
function getStyleObject(_8){
if(document.getElementById&&document.getElementById(_8)){
return document.getElementById(_8).style;
}else{
if(document.all&&document.all(_8)){
return document.all(_8).style;
}else{
if(document.layers&&document.layers[_8]){
return document.layers[_8];
}else{
return false;
}
}
}
}
function changeObjectVisibility(_9,_a){
var _b=getStyleObject(_9);
if(_b){
_b.visibility=_a;
return true;
}else{
return false;
}
}
function moveObject(_c,_d,_e){
var _f=getStyleObject(_c);
if(_f){
_f.left=_d;
_f.top=_e;
return true;
}else{
return false;
}
}

