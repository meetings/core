var templatizer = require('/usr/lib/node_modules/templatizer');

var src = '/usr/local/src/dicole-crmjournal/pkg/dicole_meetings/src/jade'
var dest = '/usr/local/src/dicole-crmjournal/pkg/dicole_meetings/html/js'
templatizer( src, dest + '/templates.js');
