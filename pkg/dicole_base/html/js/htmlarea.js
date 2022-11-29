HTMLArea.loadPlugin("TableOperations");
HTMLArea.loadPlugin("FullPage");
HTMLArea.loadPlugin("ContextMenu");
var editor=null;
function initEditor(_1,_2){
editor=new HTMLArea(_1);
if(_2){
editor.registerPlugin(FullPage);
}
editor.registerPlugin(TableOperations);
editor.registerPlugin("ContextMenu");
editor.generate();
return false;
}

