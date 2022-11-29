<!-- load the plugins -->
HTMLArea.loadPlugin("TableOperations");
HTMLArea.loadPlugin("FullPage");
HTMLArea.loadPlugin("ContextMenu");

var editor = null;
function initEditor(areaName,useFullPage) {

  // create an editor for the areaName textbox
  editor = new HTMLArea(areaName);

  // register the FullPage plugin
  if (useFullPage) { editor.registerPlugin(FullPage) };

  // register the TableOperations
  editor.registerPlugin(TableOperations);

  // add a contextual menu
  editor.registerPlugin("ContextMenu");

  // load the page stylesheet
  // editor.config.pageStyle = "";

  editor.generate();
//  setTimeout(function() {
//    editor.generate();
//  }, 5000);
  return false;
}
