var currentXmlHttpPopupObject = null;
var xmlHttpPopupDiv = null;

var XmlHttpPopupObject = function(popup_element, popup_url) {

    var id = popup_element.id;
    id = id.replace(/.*_popup_/, '');
    var closureUrl = popup_url.replace(/%%ID%%/, id);
     
    return {
      enqueueId: 0,
      fetchId: 0,
      showId: 0,

      enqueue: function(evt) {
	this.enqueueId++;
        currentXmlHttpPopupObject = this;
      },

      fetch: function(evt) {
      	this.fetchId++;
        if(this == currentXmlHttpPopupObject && this.enqueueId == this.fetchId) {
	  xmlHttpPopupDiv.innerHTML = "...";

	  var loc = FindXYWH(popup_element);
	  moveObject('xmlHttpPopupDiv', loc.x, loc.y+loc.h);
	  xmlHttpPopupDiv.style.display="";

	  var closureObject = this;
	  dojo.io.bind({
            url: closureUrl,
            handle: function(type, data, evt){
            closureObject.showId++;
		    if (closureObject == currentXmlHttpPopupObject &&
		        closureObject.enqueueId == closureObject.showId) {
		    	if (type == 'load') {
			    xmlHttpPopupDiv.innerHTML = data;
			}
			else {
			    xmlHttpPopupDiv.style.display="none";
			}
		    }
		},
    		mimetype: "text/plain"
           });
        }
	else {
	    this.showId++;
	}
      },

      cancel: function(evt) {
        currentXmlHttpPopupObject = null;
 	xmlHttpPopupDiv.style.display="none";
     }
    };
}

function connectXmlHttpPopupsByClass(clss, url) {
  createXmlHttpPopupDiv();
  var popup_links = document.getElementsByTagName("a");
//  var popup_links = dojo.html.getElementsByClass(clss);
  for (var i=0; i < popup_links.length; i++) {
    var link = popup_links[i];

    if (link.className.indexOf(clss) < 0 ) continue;
    
    var object = new XmlHttpPopupObject(link, url);

    dojo.event.connect(link, 'onmouseover', object, "enqueue");
    dojo.event.connect({
    	srcObj: link,
	srcFunc: 'onmouseover',
	targetObj: object,
	targetFunc: "fetch",
	delay: 250
    });
    dojo.connect(link, 'onmouseout', object, "cancel");
    dojo.connect(link, 'onmousedown', object, "cancel");
  }
}

function createXmlHttpPopupDiv() {
    if (xmlHttpPopupDiv) return;
    xmlHttpPopupDiv = document.getElementById('xmlHttpPopupDiv');
    if (! xmlHttpPopupDiv) {
        xmlHttpPopupDiv = document.createElement('div');
        xmlHttpPopupDiv.id = 'xmlHttpPopupDiv';
        xmlHttpPopupDiv.style.position = 'absolute';
        xmlHttpPopupDiv.style.display = 'none';
        xmlHttpPopupDiv.style['z-index'] = '9999999';
        document.body.appendChild(xmlHttpPopupDiv);
    }
}
