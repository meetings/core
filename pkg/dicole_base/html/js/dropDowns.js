var openMenus=new Array;
function onMO(_1,_2,_3){
if(move=FindXYWH(_1.firstChild)){
if(_2.id){
_2.style.left=move.x+"px";
_2.style.top=move.y+move.h+"px";
}else{
_2.style.left=move.x+move.w+"px";
_2.style.top=move.y-1+"px";
}
}
var _4=FindXYWH(_2);
_1.firstChild.onmouseover=function(){
if(!_2.id){
this.timer=setTimeout(function(){
_2.style.visibility="visible";
},200);
for(i=0;i<openMenus.length;i++){
if(openMenus[i]==_2){
break;
}else{
if(i==(openMenus.length-1)){
openMenus[openMenus.length]=_2;
}
}
}
}
};
_1.firstChild.onclick=function(e){
if(!e){
var e=window.event;
}
e.cancelBubble=true;
if(e.stopPropagation){
e.stopPropagation();
}
if(_2.id){
var id=_2.id;
closeMenus();
if(_2.insertAdjacentHTML&&is_ie){
var _7="<iframe id=\"ieFix\" style=\"display: block; padding: 0; margin: 0; border: 0; position: absolute; z-index: 101; left:"+_4.x+"; top:"+_4.y+"; width:"+_4.w+"; height:"+_4.h+";\"src=\"javascript:false;\" frameBorder=\"0\" scrolling=\"no\"></IFRAME>";
_2.insertAdjacentHTML("afterEnd",_7);
}
if(changeObjectVisibility(id,"visible")){
openMenus=new Array();
openMenus[0]=_2;
}
}
};
_1.firstChild.onmouseout=function(){
clearTimeout(this.timer);
};
}
function onMOS(_8,_9){
var _a=_8.parentNode;
_8.firstChild.onmouseover=function(){
if(openMenus[openMenus.length-1]){
for(i=openMenus.length-1;i>0;i--){
if(openMenus[i]==_a){
break;
}else{
closeMenu(openMenus[i]);
}
}
}
};
}
function getInfos(){
var _b=getObject("navContainer");
var _c=_b.getElementsByTagName("li");
var _d=0;
for(i=0;i<_c.length;i++){
var _e=new Array();
_e=_c[i].getElementsByTagName("ul");
if(_e[0]&&_e[0].nodeType=="1"){
onMO(_c[i],_e[0],_d);
_d++;
}else{
if(_c[i]){
onMOS(_c[i],_e[0]);
}
}
}
}
function closeMenu(_f){
if(_f.style.visibility="hidden"){
return true;
}else{
return false;
}
}
normalize();
getInfos();

