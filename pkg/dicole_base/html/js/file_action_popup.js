function fileActionPopup(_1,_2){
hideCurrentPopup();
window.currentFilePopupRef=_1.href;
var _3=_1;
document.open_files_action_box=_1;
var _4="files_action_box_"+_2;
document.open_files_action_box=setTimeout(function(){
showActionPopup(_4,_3);
},300);
}
function fileActionPopupHide(){
clearTimeout(document.open_files_action_box);
}
function submitLocation(_5){
var _6=window.currentFilePopupRef.replace(/\/tree\//,_5);
location.href=_6;
}
function showActionPopup(_7,_8){
if(confirmOpen=="0"&&_8){
hideCurrentPopup();
_8.cancelBubble=true;
var _9=FindXYWH(_8);
var _a=_9.x+_9.w+7;
var _b=_9.y+yOffset+8;
var _c=_7;
moveObject(_c,_a,_b);
if(changeObjectVisibility(_c,"visible")){
window.currentlyVisiblePopup=_c;
return true;
}else{
return false;
}
}else{
return false;
}
}
function FindXY(_d){
var x=0,y=0;
while(_d!=null){
x+=_d.offsetLeft;
y+=_d.offsetTop;
_d=_d.offsetParent;
}
return {x:x,y:y};
}
function FindXYWH(_f){
var _10=FindXY(_f);
return _10?{x:_10.x,y:_10.y,w:_f.offsetWidth,h:_f.offsetHeight}:{x:0,y:0,w:0,h:0};
}

