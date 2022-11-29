var mouseDwn="0";
var dontTouch="0";
function initDragAndSelect(){
if(getObject("list")){
puu=getObject("list");
var _1=puu.getElementsByTagName("input");
if(typeof (_1[0])!="undefined"&&_1[0].type=="checkbox"){
var _2="tr";
dragAndSelect(puu,_2,"firstChild");
puu.onmousedown=function(){
mouseDwn="1";
};
puu.onmouseup=function(){
mouseDwn="0";
};
document.onmouseup=function(){
mouseDwn="0";
};
}
}else{
if(getObject("tree")){
puu=getObject("tree");
var _1=puu.getElementsByTagName("input");
if(typeof (_1[0])!="undefined"&&_1[0].type=="checkbox"){
var _2="div";
dragAndSelect(puu,_2,"firstChild");
puu.onmousedown=function(){
mouseDwn="1";
};
puu.onmouseup=function(){
mouseDwn="0";
};
document.onmouseup=function(){
mouseDwn="0";
};
}
}
}
}
function dragAndSelect(_3,_4,_5){
var _6=_3.getElementsByTagName(_4);
var _7=_3.getElementsByTagName("input");
for(i=0;i<_6.length;i++){
_6[i].onmouseover=function(){
if(this.firstChild.firstChild){
if(this.firstChild.firstChild.checked&&mouseDwn=="1"){
this.firstChild.firstChild.checked="";
this.style.backgroundColor="";
}else{
if(this.firstChild.firstChild.checked==""&&mouseDwn=="1"){
this.firstChild.firstChild.checked="checked";
this.style.backgroundColor="rgb(206,224,236)";
}
}
}
};
if(_5){
dontO="_6[i]."+_5;
dontObj=eval(dontO);
dontObj.onmouseover=function(){
dontTouch="1";
};
dontObj.onmouseout=function(){
dontTouch="0";
};
}
_6[i].onclick=function(){
if(this.firstChild.firstChild){
if(this.firstChild.firstChild.checked&&dontTouch=="0"){
this.firstChild.firstChild.checked="";
this.style.backgroundColor="";
}else{
if(this.firstChild.firstChild.checked==""&&dontTouch=="0"){
this.firstChild.firstChild.checked="checked";
this.style.backgroundColor="rgb(206,224,236)";
}
}
}
};
}
for(j=0;j<_7.length;j++){
_7[j].onclick=function(){
if(!this.parentNode.parentNode.style.backgroundColor){
this.parentNode.parentNode.style.backgroundColor="rgb(206,224,236)";
}else{
this.parentNode.parentNode.style.backgroundColor="";
}
};
_7[j].onmouseup=function(){
mouseDwn="0";
};
}
}
normalize();
initDragAndSelect();

