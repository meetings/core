var currentXmlHttpPopupObject=null;
var xmlHttpPopupDiv=null;
var XmlHttpPopupObject=function(_1,_2){
var id=_1.id;
id=id.replace(/.*_popup_/,"");
var _4=_2.replace(/%%ID%%/,id);
return {enqueueId:0,fetchId:0,showId:0,enqueue:function(_5){
this.enqueueId++;
currentXmlHttpPopupObject=this;
},fetch:function(_6){
this.fetchId++;
if(this==currentXmlHttpPopupObject&&this.enqueueId==this.fetchId){
xmlHttpPopupDiv.innerHTML="...";
var _7=FindXYWH(_1);
moveObject("xmlHttpPopupDiv",_7.x,_7.y+_7.h);
xmlHttpPopupDiv.style.display="";
var _8=this;
dojo.xhr({url:_4,handle:function(_9,_a,_b){
_8.showId++;
if(_8==currentXmlHttpPopupObject&&_8.enqueueId==_8.showId){
if(_9=="load"){
xmlHttpPopupDiv.innerHTML=_a;
}else{
xmlHttpPopupDiv.style.display="none";
}
}
},mimetype:"text/plain"});
}else{
this.showId++;
}
},cancel:function(_c){
currentXmlHttpPopupObject=null;
xmlHttpPopupDiv.style.display="none";
}};
};
function connectXmlHttpPopupsByClass(_d,_e){
createXmlHttpPopupDiv();
var _f=document.getElementsByTagName("a");
for(var i=0;i<_f.length;i++){
var _11=_f[i];
if(_11.className.indexOf(_d)<0){
continue;
}
var _12=new XmlHttpPopupObject(_11,_e);
dojo.connect(_11,"onmouseover",_12,"enqueue");
dojo.event.kwConnect({srcObj:_11,srcFunc:"onmouseover",targetObj:_12,targetFunc:"fetch",delay:250});
dojo.connect(_11,"onmouseout",_12,"cancel");
dojo.connect(_11,"onmousedown",_12,"cancel");
}
}
function createXmlHttpPopupDiv(){
if(xmlHttpPopupDiv){
return;
}
xmlHttpPopupDiv=document.getElementById("xmlHttpPopupDiv");
if(!xmlHttpPopupDiv){
xmlHttpPopupDiv=document.createElement("div");
xmlHttpPopupDiv.id="xmlHttpPopupDiv";
xmlHttpPopupDiv.style.position="absolute";
xmlHttpPopupDiv.style.display="none";
xmlHttpPopupDiv.style["z-index"]="9999999";
document.body.appendChild(xmlHttpPopupDiv);
}
}

