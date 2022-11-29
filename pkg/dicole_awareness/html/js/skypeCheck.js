var activex=((navigator.userAgent.indexOf("Win")!=-1)&&(navigator.userAgent.indexOf("MSIE")!=-1)&&(parseInt(navigator.appVersion)>=4));
var CantDetect=((navigator.userAgent.indexOf("Safari")!=-1)||(navigator.userAgent.indexOf("Opera")!=-1));
function oopsPopup(){
var _1="oops";
var _2="http://download.skype.com/share/skypebuttons/oops/oops.html";
var _3=540,popH=305;
var _4="no";
w=screen.availWidth;
h=screen.availHeight;
var _5=(w-_3)/2,topPos=(h-popH)/2;
oopswindow=window.open(_2,_1,"width="+_3+",height="+popH+",scrollbars="+_4+",screenx="+_5+",screeny="+topPos+",top="+topPos+",left="+_5);
return false;
}
if(typeof (detected)=="undefined"&&activex){
document.write(["<script language=\"VBscript\">","Function isSkypeInstalled()","on error resume next","Set oSkype = CreateObject(\"Skype.Detection\")","isSkypeInstalled = IsObject(oSkype)","Set oSkype = nothing","End Function","</script>"].join("\n"));
}
function skypeCheck(){
if(CantDetect){
return true;
}else{
if(!activex){
var _6=navigator.mimeTypes["application/x-skype"];
detected=true;
if(typeof (_6)=="object"){
return true;
}else{
return oopsPopup();
}
}else{
if(isSkypeInstalled()){
detected=true;
return true;
}
}
}
detected=true;
return oopsPopup();
}

