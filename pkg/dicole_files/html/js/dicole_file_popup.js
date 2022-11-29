var target_id;

function execute_browse() {
    filefield = document.forms[0].link_url;
    completeurl = true;
    var window_url = '/select_file/detect';
    if ( target_group_id ) window_url += '?group_id=' + target_group_id;
    else if ( target_user_id ) window_url += '?user_id=' + target_user_id;
    var dialog = window.open(
        window_url, 'profile',
        'toolbar=no,menubar=no,statusbar=no,' +
        'scrollbars=yes,width=640,height=480'
    );
}


function execute_popup() {
    var href = document.forms[0].link_url.value;
    var title = href;
    var dummy;

    tinyMCEPopup.restoreSelection();
    tinyMCE.themes['advanced']._insertLink(
        href, '', title, dummy, ''
    );
    tinyMCEPopup.close();
}

function cancel_popup() {
    tinyMCEPopup.close();
}


tinyMCE.addEvent(window, "load", function() {
//    tinyMCEPopup.resizeToContent();
    var href = tinyMCE.getWindowArg('href');
    target_group_id = tinyMCE.getWindowArg('target_group_id');
    target_user_id = tinyMCE.getWindowArg('target_user_id');
    document.forms[0].link_url.value = href;
} );


