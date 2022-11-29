var target_id;

function execute_browse() {
    filefield = document.forms[0].image_url;
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
    var src = document.forms[0].image_url.value;
    var alt = document.forms[0].image_alt.value;
    var align = document.forms[0].image_align.options[document.forms[0].image_align.selectedIndex].value;
    var title = alt;
    var dummy;

    tinyMCEPopup.restoreSelection();
    tinyMCE.themes['advanced']._insertImage(src, alt, 0, dummy, dummy, dummy, dummy, align);
    tinyMCEPopup.close();
}

function cancel_popup() {
    tinyMCEPopup.close();
}


tinyMCE.addEvent(window, "load", function() {
//    tinyMCEPopup.resizeToContent();
    target_group_id = tinyMCE.getWindowArg('target_group_id');
    target_user_id = tinyMCE.getWindowArg('target_user_id');

    document.forms[0].image_url.value = tinyMCE.getWindowArg('src');
    document.forms[0].image_alt.value = tinyMCE.getWindowArg('alt');
    document.forms[0].image_align.value = tinyMCE.getWindowArg('align');
} );


