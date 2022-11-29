dojo.require("dojo.event.*");
var StatusNum={UNKNOWN:0,OFFLINE:1,ONLINE:2,AWAY:3,NOTAVAILABLE:4,DONOTDISTURB:5,INVISIBLE:6,SKYPEME:7};
var Defs={INTERVAL:20000,TYPE_ELEMENT:1,USER_PREFIX:"user_",ICON_FORMAT:".gif",TAG_PREFIX:"skype_icon_",ICON_PREFIX:"skype_status_",STATUS_URL:"/skype/status/"+DicoleTargetId,STATUS_TEXT:"Skype"};
function getObject(_1){
if(document.getElementById&&document.getElementById(_1)){
return document.getElementById(_1);
}else{
if(document.all&&document.all(_1)){
return document.all(_1);
}else{
if(document.layers&&document.layers[_1]){
return document.layers[_1];
}else{
return false;
}
}
}
}
function updateIcon(_2,_3,_4){
if(_3<StatusNum.UNKNOWN||_3>StatusNum.SKYPEME){
_3=StatusNum.UNKNOWN;
}
if(_4==""){
_4=Defs.STATUS_TEXT;
}
var _5=Defs.TAG_PREFIX+_2;
icon=getObject(_5);
if(icon!=false){
var _6=Defs.ICON_PREFIX+_3+Defs.ICON_FORMAT;
var _7=new RegExp(Defs.ICON_PREFIX+"[0-9]"+Defs.ICON_FORMAT);
icon.src=icon.src.replace(_7,_6);
icon.alt=_4;
icon.title=icon.alt;
}
}
function updateStatusIcons(_8){
var _9=_8.documentElement.childNodes;
var _a=_9.length;
var _b;
if(_8.documentElement.nodeName!="skype_status"){
return;
}
for(i=0;i<_a;i++){
_b=_9.item(i);
if(_b.nodeType==Defs.TYPE_ELEMENT){
updateIcon(_b.nodeName,parseInt(_b.getAttribute("status_code")),_b.getAttribute("status_text"));
}
}
}
function pollStatus(){
dojo.xhr({url:Defs.STATUS_URL,preventCache:true,handleAs:"xml",load:function(_d,_e){
updateStatusIcons(_d);
}});
setTimeout(pollStatus,Defs.INTERVAL);
}
function initSkypeUpdate(){
/* pollStatus(); */
}
dojo.connect(window,"onload",initSkypeUpdate);

