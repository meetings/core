var xOffset=50;
var yOffset=0;
function fileActionPopup(){
var _1=getObject("tree");
var _2=_1.getElementsByTagName("a");
for(i=0;i<_2.length;i++){
_2[i].onmouseover=function(){
hideCurrentPopup;
window.currentFilePopupRef=this.href;
var _3=this;
var _4=this.id;
this.showTimer=setTimeout(function(){
showActionPopup(_4,_3);
},500);
};
_2[i].onmouseout=function(){
clearTimeout(this.showTimer);
};
}
}
function submitLocation(_5){
var _6=window.currentFilePopupRef.replace(/\/tree\//,_5);
location.href=_6;
}
function showActionPopup(_7,_8){
if(_8){
hideCurrentPopup();
_8.cancelBubble=true;
var _9=FindXYWH(_8);
var _a=_9.x+_9.w+10;
var _b=_9.y+yOffset;
var _c=_7.replace(/_.+/,"");
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

