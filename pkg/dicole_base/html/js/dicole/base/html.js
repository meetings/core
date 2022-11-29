dojo.provide('dicole.base.html');

dicole.encode_html = function( str ) {
    return (str+"").replace(/&/gm, "&amp;").replace(/</gm, "&lt;").replace(/>/gm, "&gt;").replace(/"/gm, "&quot;");
};

