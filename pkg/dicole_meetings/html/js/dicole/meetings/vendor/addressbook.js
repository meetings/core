dojo.provide("dicole.meetings.vendor.addressbook");

dojo.require('dicole.meetings.vendor.jquery');

/*
 * jQuery Plugin: Meetin.gs address book
 * Version 0.1
 *
 * Copyright (c) 2012 Meetin.gs Ltd
 * Licensed jointly under the GPL and MIT licenses,
 * choose which one suits your project best!
 *
 */

(function($) {
    // Default settings
    var DEFAULT_SETTINGS = {

        // State
        abInitialized: false,

        // Search settings
        searchDelay: 300,
        minChars: 1,
        propertyToSearch: ['name', 'email'],
        tokenLimit: 100,

        // Data
        users: null,
        meetings: null,
        users_arr: [],
        meetings_arr: [],
        users_arr_len: 0,
        meetings_arr_len: 0,

        // Callbacks
        onAdd: null,
        onDelete: null
    };

    // Keys "enum"
    var KEY = {
        BACKSPACE: 8,
        TAB: 9,
        ENTER: 13,
        ESCAPE: 27,
        SPACE: 32,
        PAGE_UP: 33,
        PAGE_DOWN: 34,
        END: 35,
        HOME: 36,
        LEFT: 37,
        UP: 38,
        RIGHT: 39,
        DOWN: 40,
        NUMPAD_ENTER: 108,
        COMMA: 188
    };

    // Additional public (exposed) methods
    var methods = {
        init: function(url_or_data_or_function, options) {
            var settings = $.extend({}, DEFAULT_SETTINGS, options || {});

            return this.each(function () {
                $(this).data("addressBookObject", new $.ab(this, url_or_data_or_function, settings));
            });
        },
        getUsers : function() {
            return this.data('addressBookObject').get_users();
        },
        updateData: function(data) {
            this.data("addressBookObject").update_data(data);
            return this;
        },
        updateDataOnce: function(data) {
            this.data("addressBookObject").update_data_once(data);
            return this;
        },
        showAddressArea: function() {
            this.data("addressBookObject").show_address_area();
        }
    };

    // Expose the .addressBook function to jQuery as a plugin
    $.fn.addressBook = function (method) {
        // Method calling and initialization logic
        if(methods[method]) {
            return methods[method].apply(this, Array.prototype.slice.call(arguments, 1));
        } else {
            return methods.init.apply(this, arguments);
        }
    };

    // ab class for each input
    $.ab = function (input, data, settings) {

        var strings = {
            hintText: MTN.t("Type an email, a name or a meeting name"),
            tipText: MTN.t("HINT: You can also copy & paste a list of email addresses above (separated by a comma)."),
            noResultsText: function(inited){
                return inited ? ' ' + MTN.t('not found.') : ' ' +MTN.t('not found yet, we are still working to fetch your contacts...') + '<img style="display:block; margin:20px 5px;" alt="Loading..." src="/images/meetings/ajax_loader.gif">';
            },
            emptyAddressBookText: function(inited){
                return inited ? MTN.t('Address book is empty.') : MTN.t('We are working hard to fetch your contacts...') + '<img style="display:block; margin:20px 5px;" alt="Loading..." src="/images/meetings/ajax_loader.gif">';
            },
            deleteText: "&times;"
        };
        settings = $.extend({}, strings, settings );

        var ab_id_lookup = [];
        // Initialization
        if(typeof(data) === "object" && data !== null) {
            // Set the local data to search through
            init_ab_data( data );
        }
        // No data yet
        else {
            settings.users = {};
            settings.meetings = {};
            settings.users_arr = [];
            settings.meetings_arr = [];
        }

        // HTML escaper
        var esc = dicole.encode_html;

        // Selected users & selected user count
        var selected_users = [];
        var selected_users_count = 0;

        // Keep count of currently shown search results
        var search_list_count = 0;

        // Keep track of the meeting open div
        var div_meeting_open = $('<div class="meeting-open-banner" />');

        // Search list active item
        var search_list_active_item;

        // Keep track of the timeout
        var search_timeout;

        // Keep track if the address book was opened by hand
        var ab_opened_by_hand = false;

        // Keep track of proposed emails
        var email_proposals = [];

        // Keep track of contact suggestion text & element
        var contact_suggestion_element = $('<span/>');

        // Keep track, if we are allowed to clear the search field
        var protect_search_field = false;
        var subview_open = false;

        // Keep a reference to the original input box
        var hidden_input = $(input).hide().val("");

        var submit_button = $('#invite-participants-submit span.button').removeClass('blue').addClass('gray').fadeTo('fast',0.5);
        var submit_button_enabled = false;
        // Create a new text input an attach keyup events
        var input_box = $('<input type="text" class="filter-people">')
        .css({outline: "none"})
        .val(settings.hintText)
        .focus(function () {
            if (settings.disabled) {
                return false;
            }
            else if(input_box.val() == settings.hintText){
                input_box.val('');
            }
        })
        .blur(function () {
            // TODO: Don't clear if:
            // * lost focus by tab or arrow
            // * lost focus when inside a meeting / company
            //console.log('lost focus');
            /*var elem = $(this);
              setTimeout(function(){
              if( subview_open ){
            //console.log('subview protect');
            }
            else if(protect_search_field){
            //console.log('protect on');
            protect_search_field = false;
            }
            else{
            elem.val("");
            clear_email_proposals();
            if(! ab_opened_by_hand ) hide_results();
            }
            },500);*/
            if( input_box.val() === '' ){
                input_box.val(settings.hintText);
            }
        })
        .keydown(function (event) {
            switch(event.keyCode) {
                // TODO: move along contacts
                case KEY.LEFT:
                    break;
                case KEY.RIGHT:
                    break;
                case KEY.UP:
                    break;
                case KEY.DOWN:
                    break;
                case KEY.TAB:
                    // TODO: to first item
                    break;
                case KEY.NUMPAD_ENTER:
                    case KEY.ENTER:
                    if(email_proposals.length > 0){
                    add_email_proposals();
                    show_all_users();
                    clear_email_proposals();
                    input_box.val("");
                    break;
                }
                else if(search_list_count == 1){
                    $('.visible', result_box_container).click();
                }
                else{
                    open_contact_suggestion_popup();
                }
                break;
                case KEY.COMMA:
                    case KEY.ESCAPE:
                    case KEY.BACKSPACE:
                    // Clear timeout so when the field gets emptied, the empty search
                    // will be made and not the search that had something in it
                    // eg. cmd + a and backspace
                    clearTimeout(search_timeout);
                default:
                    if(String.fromCharCode(event.which)) {
                    // set a timeout just long enough to let this function finish.
                    setTimeout(function(){do_search();}, 5);
                }
                break;
            }
        });

        // Create open button
        var ab_open_button = $('<a id="ab-open-button" />');
        ab_open_button.html('<span class="button blue"><i class="ico-addressbook"></i> '+MTN.t('Address book')+'</span>');
        ab_open_button.click(function(e){
            e.preventDefault();
            show_results();
            if( ab_opened_by_hand === false && search_list_count === 0 ){
                empty_address_book_element.html(settings.emptyAddressBookText(settings.abInitialized)).show();
            }
            ab_opened_by_hand = true;
        });

        // Wrapper for the field and the button
        var ab_field_and_button_wrapper = $('<div id="field-and-button-wrapper" />');
        ab_field_and_button_wrapper.append(input_box).append(ab_open_button);
        ab_field_and_button_wrapper.insertBefore(hidden_input);

        // Create tip
        var tip_container = $('<div id="tip-container" />').insertBefore(hidden_input);
        tip_container.html('<p>'+settings.tipText+'</p>');

        // Create search result container
        var result_box_container = $('<div id="contacts-wrapper" />').insertBefore(hidden_input);
        result_box_container.hide();
        var result_box = $('<div id="contacts-list" />');
        result_box_container.append(result_box);

        // Generate user & meeting html
        var user_html = generate_user_html();
        var meeting_html = generate_meeting_html();

        // Create empty address book badge
        var empty_address_book_element = $('<p style="text-align:Center"></p>').hide();
        result_box.append(empty_address_book_element);

        // Create add all email proposals button
        var add_email_proposals_button = $('<span class="button pink" style="display:block;">'+MTN.t('Add all')+'</span>');
        add_email_proposals_button.click(function(e){
            e.preventDefault();
            add_email_proposals();
            clear_email_proposals();
            input_box.val('');
            show_all_results();
        }).hide();

        // Add to DOM
        result_box.append(user_html);
        result_box.append(meeting_html);
        result_box.append(add_email_proposals_button);

        add_user_click_handlers();
        add_meeting_click_handlers();

        // Container for the list
        var token_list_container = $('<div id="token-list-wrapper" />').insertAfter(hidden_input);

        // The list to store the token items in
        var token_list = $('<ul id="selected-user-tokens" />')
        .click(function (event) {
            var li = $(event.target).closest("li");
            // TODO: Select user in list
        })
        .mouseover(function (event) {
            var li = $(event.target).closest("li");
            if(li) {
                li.addClass('highlight');
            }
        })
        .mouseout(function (event) {
            var li = $(event.target).closest("li");
            if(li) {
                li.removeClass('highlight');
            }
        });
        token_list_container.append(token_list);

        // Dont show initially
        token_list.hide();
        token_list.html('<li class="to">'+MTN.t('Selected:')+'</li>');

        //
        // Public functions
        //

        this.get_users = function() {
            return selected_users;
        };

        this.update_data = function(data) {
            init_ab_data(data);
            var user_html = generate_user_html();
            var meeting_html = generate_meeting_html();
            result_box.append(user_html);
            result_box.append(meeting_html);
            add_user_click_handlers();
            add_meeting_click_handlers();
            if( input_box.val() !== settings.hintText && input_box.val() !== ''){
                do_search();
            }
        };

        this.update_data_once = function(data) {
            if( ! settings.abInitialized ){
                init_ab_data(data);
                var user_html = generate_user_html();
                var meeting_html = generate_meeting_html();
                result_box.append(user_html);
                result_box.append(meeting_html);
                add_user_click_handlers();
                add_meeting_click_handlers();
                if( input_box.val() !== settings.hintText && input_box.val() !== ''){
                    do_search();
                }
            }
        };

        this.clear = function() {
            token_list.children("li").each(function() {
                if ($(this).children("input").length === 0) {
                    var id = $(this).attr('id').substr(3);
                    delete_token(id);
                }
            });
        };

        this.add = function(item) {
            add_token(item);
        };

        this.show_address_area = function() {
            show_results();
        };

        this.remove = function(item) {
            token_list.children("li").each(function() {
                if ($(this).children("input").length === 0) {
                    var currToken = $(this).data("tokeninput");
                    var match = true;
                    for (var prop in item) {
                        if (item[prop] !== currToken[prop]) {
                            match = false;
                            break;
                        }
                    }
                    if (match) {
                        var id = $(this).attr('id').substr(3);
                        delete_token(id);
                    }
                }
            });
        };

        //
        // Private functions
        //
        function remove_ab_open_button(){
            if( ab_open_button.html() !== "" ) {
                ab_open_button.fadeOut('200', function(){
                    ab_open_button.html('').remove();
                    input_box.animate({width:'701px'});
                    do_search(); // JFK: fixes problem on chrome not noticing fast copypaste of email
                });
            }
        }

        function init_ab_data(data) {

            // Filter deleted accounts from data
            data.users = _.filter(data.users, function(u) { return u.name !== 'Deleted Account'; });

            var i;
            var c = 0;
            if(data.users){
                var user;
                for(i in data.users){
                    user = data.users[i];
                    if( user.name !== '' ){
                        if( user.user_id ) ab_id_lookup[""+user.user_id] = c;
                        settings.users_arr[c] = user;
                        c = c + 1;
                    }
                }
            }
            settings.users_arr_len = c;
            if(data.meetings){
                c = 0;
                var meeting;
                for(i in data.meetings){
                    meeting = data.meetings[i];
                    if( meeting && meeting.participant_id_list.length > 1 ){
                        meeting.id = c;
                        settings.meetings_arr[""+c] = meeting;
                        c = c + 1;
                    }
                }
            }
            settings.meetings_arr_len = c;
            settings.abInitialized = true;
            //console.timeEnd('init');
        }

        function add_user_click_handlers(){
            // User click behaviour
            $('a.user', result_box).each(function(i){
                var item = $(this);
                var ab_id = item.attr('id').substr(2);
                settings.users_arr[ab_id].element = item;
                item.click(function(e){
                    e.preventDefault();
                    protect_search_field = true;
                    if(item.hasClass('user_selected')){
                        item.removeClass('user_selected');
                        delete_token(ab_id);

                    }
                    else{
                        if(check_token_limit()){
                            item.addClass('user_selected');
                            add_token(settings.users_arr[ab_id]);
                        }
                    }
                });
            });
        }

        function add_meeting_click_handlers(){
            // Meeting click behaviour
            $('a.meeting', result_box).each(function(i){
                var item = $(this);
                var mid = item.attr('id').substr(2);
                settings.meetings_arr[mid].element = item;
                item.click(function(e){
                    protect_search_field = true;
                    e.preventDefault();
                    hide_all_results();
                    // Show users from meeting
                    // Show meeting header and add all button
                    div_meeting_open = $('<div class="meeting-open-banner" />');
                    var back_button = $('<span class="button blue" />');
                    back_button.html('<span class="white-arrow-back"></span>Back');
                    back_button.click(function(){
                        hide_all_results();
                        // div_meeting_open.remove();
                        // show_all_results(); not needed?
                        do_search();
                    });
                    var info_div = $('<div class="meeting-info"></div>');
                    info_div.click(function(){
                        // Toggle between select all and deselect
                        // TODO: add visual cue for deselect
                        $.each(settings.meetings_arr[mid].participant_id_list, function(index, meetings_id){
                            // convert meetings user id to address book user id
                            var id = ab_id_lookup[meetings_id];
                            var user = settings.users_arr[id].element;
                            if(settings.meetings_arr[mid].all_selected === true){
                                user.removeClass('user_selected');
                                delete_token(id);
                            }
                            else{
                                if(check_token_limit()){
                                    user.addClass('user_selected');
                                    add_token(settings.users_arr[id]);
                                }
                            }
                        });
                        if(settings.meetings_arr[mid].all_selected === true){
                            settings.meetings_arr[mid].all_selected = false;
                        }
                        else{
                            settings.meetings_arr[mid].all_selected = true;
                        }
                    });
                    info_div.html(get_calendar_html(settings.meetings_arr[mid].calendar)+'<span class="title">'+esc(settings.meetings_arr[mid].title)+'</span><span class="select-all">' + MTN.t('Click here to select all') + '</span>');
                    result_box.prepend(div_meeting_open);
                    div_meeting_open.append(back_button).append(info_div);
                    $.each(settings.meetings_arr[mid].participant_id_list, function(index, meetings_id){
                        var id = ab_id_lookup[meetings_id];
                        if( id ) settings.users_arr[id].element.addClass('visible');
                    });

                });
            });
        }

        function check_token_limit() {
            if(settings.tokenLimit === null || selected_users_count < settings.tokenLimit) {
                return true;
            }
            else{
                alert('Meetin.gs is not really meant for this big meetings. Sorry.');
                return false;
            }
        }

        // Create html for users
        function generate_user_html(){
            var user_html = '';
            var l = settings.users_arr.length;
            var user;
            for(var i = 0; i < l; i++){
                user = settings.users_arr[i];
                user.ab_id = i;
                var image = user.image || '/images/theme/default/default-user-avatar-50px.png';
                var tooltip = user.email || user.name;
                user_html += '<a class="user visible" href="#" id="u_'+esc(user.ab_id)+'" title="'+esc(tooltip)+'">';
                user_html += '<div class="wrap"><img src="'+esc(image)+ '" alt="'+esc(user.name)+'"/>';
                user_html += '<span class="info">'+esc(user.name)+'</span>';
                var title = user.organization_title || '';
                if(title !== '') title = title + ', ';
                if( user.organization ) user_html += '<span class="info2">'+esc(title+user.organization)+'</span>';
                user_html += '<span class="down-arrow"> </span></div></a>';
                search_list_count += 1;
            }
            return user_html;
        }

        // Create html for meetings
        function generate_meeting_html(){
            var meeting_html = '';
            var l = settings.meetings_arr.length;
            var meeting;
            for(var i = 0; i < l; i++){
                meeting = settings.meetings_arr[i];
                meeting_html += '<a class="meeting" href="#" id="m_'+esc(meeting.id)+'" title="'+esc(meeting.title)+'"><div class="wrap">';
                meeting_html += get_calendar_html(meeting.calendar);
                meeting_html += '<span class="info">'+esc(concatenate(meeting.title))+'</span>';
                if( meeting.location ) meeting_html += '<span class="info2">'+esc(meeting.location)+'</span>';
                meeting_html += '</div></a>';
                search_list_count += 1;
            }
            return meeting_html;
        }

        // Add a token to the token list based on user input
        function add_token (item) {
            var callback = settings.onAdd;

            // Insert the new tokens
            if(!is_duplicate_token(item)) {
                insert_token(item);
                selected_users.push(item);
                update_token_list();

                // Execute the onAdd callback if defined
                if($.isFunction(callback)) {
                    callback.call(hidden_input,item);
                }
            }
        }

        // Insert token to the list
        function insert_token(item) {
            var ab_id = item.ab_id;
            var item_text = item.real_name || item.name;
            var this_token = $('<li id="li_'+esc(ab_id)+'" class="token">' + esc(item_text) + '</li>');
            token_list.append(this_token);

            // Add the delete token button
            $("<span>" + settings.deleteText + "</span>")
            .appendTo(this_token)
            .click(function () {
                if (!settings.disabled) {
                    var ab_id = $(this).parent().attr('id').substr(3);
                    delete_token(ab_id);
                    hidden_input.change();
                    return false;
                }
            });
            selected_users_count += 1;
            return this_token;
        }

        // Delete a token from the token list
        function delete_token(ab_id) {
            //console.log('delete_token: ' +id);
            var callback = settings.onDelete;

            // Unselect on result list
            $('#u_'+ab_id).removeClass('user_selected');

            // Delete the token
            $('#li_'+ab_id).remove();

            var index = false;
            $.each(selected_users, function(i,user){
                if(user.ab_id == ab_id){
                    index = i;
                    return false;
                }
            });
            if(index !== false) selected_users.splice(index,1);

            selected_users_count -= 1;

            update_token_list();

            // Execute the onDelete callback if defined
            if($.isFunction(callback)) {
                callback.call(hidden_input,settings.users_arr[ab_id]);
            }
        }

        // Update the hidden input box value
        function update_token_list() {
            // Check if we have tokens and show the container
            if( selected_users_count > 0 ) {
                token_list.show();
                if( submit_button_enabled === false ) {
                    submit_button.addClass('pink').removeClass('gray').fadeTo('fast',1).hintLight({duration:1500,zindex_override:'1020'});
                    submit_button_enabled = true;
                }
            }
            else{
                token_list.hide();
                if( submit_button_enabled === true ) {
                    submit_button.addClass('gray').removeClass('pink').fadeTo('fast',0.5);
                    submit_button_enabled = false;
                }
            }

            // Update hidden field
            var items = [];
            $.each(selected_users, function(index,user) {
                var user_string = '';
                // User is from add popup
                if ( user.real_name ) {
                    user_string = '"' + user.real_name + '" <' + user.name + '>';
                }
                // From server
                else if(user.user_id) {
                    user_string = user.user_id;
                }
                else {
                    user_string = user.email || user.name;
                }
                items.push(user_string);
            });

            hidden_input.attr('value', dojo.toJson(items) );
        }

        // Adds mails suggestion
        function add_email_proposal(index){
            var i = index.substr(2);
            var email = email_proposals[i];
            var item = { 'ab_id' : 'e_'+i, 'name': email, 'type' : 'email', email : email };
            if(check_token_limit()) {
                add_token(item);
            }
        }
        // Add all mail suggestions and removes button
        function add_email_proposals(){
            $.each(email_proposals, function(index,email){
                var item = { 'ab_id' : 'e_'+index, 'name' : email, 'type' : 'email', email : email };
                if(check_token_limit()) {
                    add_token(item);
                }
                else {
                    return false;
                }
            });
            add_email_proposals_button.hide();
        }

        function do_search() {
            div_meeting_open.remove();
            empty_address_book_element.hide();
            add_email_proposals_button.hide();
            contact_suggestion_element.remove();
            var query = input_box.val();
            if( query === settings.hintText ) query = '';
            if(query && query.length && query.length >= settings.minChars) {
                clearTimeout(search_timeout);
                search_timeout = setTimeout(function(){
                    // Run search
                    run_search(query);

                    // TODO: Handle case where, search string is an email and also a part of a search result
                    if(search_list_count === 0) {
                        if(! find_emails(query.replace(/\s|\;/g, ",")) ){
                            // Suggest adding new dude
                            suggest_new_contact(query);
                            show_results();
                        }
                        else{
                            contact_suggestion_element.remove();
                        }
                    }
                }, settings.searchDelay);
            }
            else{
                show_results();
                show_all_results();
                if( search_list_count <= 0 && settings.users_arr_len === 0 && settings.meetings_arr_len === 0 ){
                    // TODO: dont show if only the search was empty
                    empty_address_book_element.html(settings.emptyAddressBookText(settings.abInitialized)).show();
                    remove_ab_open_button();
                }
            }
        }

        // Do the actual search
        function run_search(query) {
            if( query === settings.hintText ) return;
            query = query.toLowerCase();
            //console.time('search');
            var u_count = settings.users_arr_len;
            var m_count = settings.meetings_arr_len;
            var i,user,meeting;
            search_list_count = u_count + m_count;
            clear_email_proposals();
            for(i = 0; i < u_count; i++){
                user = settings.users_arr[i];
                if(user.name.toLowerCase().indexOf(query) !== -1 ||
                   user.email.toLowerCase().indexOf(query) !== -1 ||
                       ( user.organization && user.organization.toLowerCase().indexOf(query) !== -1 )
                  ) {
                      user.element.addClass('visible');
                  }
                  else{
                      user.element.removeClass('visible');
                      search_list_count -= 1;
                  }
            }
            // Search meetings by name
            for(i = 0; i < m_count; i++){
                meeting = settings.meetings_arr[i];
                if(meeting.title.toLowerCase().indexOf(query.toLowerCase()) !== -1){
                    meeting.element.addClass('visible');
                }
                else{
                    meeting.element.removeClass('visible');
                    search_list_count -= 1;
                }
            }
            if(search_list_count > 0){
                show_results();
            }
            //console.timeEnd('search');
        }


        function find_emails(query){
            // Check if string is email
            var possible_email = get_email(query);
            var found_email = false;
            // TODO: Find if email contains name, and save it along
            if(query.indexOf(',') !== -1){
                hide_all_results();
                var email_arr = query.split(',');
                found_email = false;
                $.each(email_arr, function(index, email){
                    var probable_email = get_email(email);
                    if(probable_email !== false && on_the_list(probable_email) === false ){
                        show_email_proposal(probable_email);
                        found_email = true;
                    }
                });
            }
            else if( possible_email !== false && on_the_list(possible_email) === false ){
                hide_all_results();
                show_email_proposal(possible_email);
                found_email = true;
            }
            return found_email;
        }

        function is_duplicate_token(item){
            var found = false;
            var compare_string = item;
            if(typeof item === 'object') compare_string = item.user_id || item.name;

            $.each(selected_users, function(index, thing){
                // TODO: problem with id, maybe fixed
                var id = thing.user_id || thing.name;
                // TODO: COmpare mail with mail and not id
                if(compare_string == id) found = true;
            });
            //console.log(found);
            return found;
        }

        function on_the_list(email){
            // Already added?
            if(is_duplicate_token(email)) return true;
            // TODO: should not go beyond this

            // Already proposed?
            var found = false;
            $.each(email_proposals, function(index,item){
                // Update either is a substring but not the same
                if( email.indexOf(item) !== -1 || item.indexOf(email) !== -1 ){
                    if( email != item ){
                        email_proposals[index] = email;
                        $('#email_'+index+' span.text').html(esc(email)+settings.noResultsText(settings.abInitialized));
                        $('#email_'+index+' span.button').html(MTN.t('Add')+' '+esc(email));
                    }
                    found = index;
                }
            });
            return found;
        }

        function show_email_proposal(email){
            var email_add = '';
            var email_text = '';
            var add_button = '';
            var email_name = '';
            if(is_duplicate_token(email)) {
                email_add = $('<div class="email_proposal">' + MTN.t('%1$s is already added.', [esc(email)]) + '</div>');
            }
            else{
                email_add = $('<div class="email_proposal" id="'+esc(id_from_email(email))+'"></div>');
                email_text = $('<span class="text">'+esc(email)+settings.noResultsText(settings.abInitialized)+'</span>');
                add_button = $('<span class="button blue">Add '+esc(email)+'</span>');
                email_add.append(email_text);
                email_add.append(add_button);
                add_button.click(function(e){
                    e.preventDefault();
                    protect_search_field = true;
                    add_email_proposal(id_from_email(email));
                    $(this).remove();
                    email_add.remove();
                    if(email_proposals.length == 1){
                        input_box.val("");
                    }
                    show_all_users();
                });
            }

            email_proposals.push(email);
            result_box.append(email_add);
            show_results();

            if(email_proposals.length > 1){
                // Show add all button
                add_email_proposals_button.show();
            }
            else{
                // Hide add all button
                add_email_proposals_button.hide();
            }
        }

        // Suggest adding query as a new person
        function suggest_new_contact(query){
            contact_suggestion_element.remove();
            contact_suggestion_element = $('<div id="new_cotact_suggestion"></div>');
            contact_text = $('<span class="text">'+esc(query)+settings.noResultsText(settings.abInitialized)+'</span>');
            add_button = $('<span class="button blue">' + MTN.t('Add %1$s',[esc(query)]) + '</span>');
            contact_suggestion_element.append(contact_text);
            contact_suggestion_element.append(add_button);
            add_button.click(function(e){
                e.preventDefault();
                protect_search_field = true;
                open_contact_suggestion_popup();
            });
            result_box.append(contact_suggestion_element);
        }

        function open_contact_suggestion_popup(){
            var text = input_box.val();
            if( ! check_token_limit() ) return;

            dicole.uc_common_open_and_prepare_form('meetings', 'invite_participants_new', {
                template_params : {
                    name : text,
                    email : ''
                },
                submit_handler : function( data, response_handler ) {
                    if( get_email(data.email) === false ){
                        return response_handler( { error : { message : MTN.t('Email is required.') } } );
                    }
                    else{
                        return response_handler( { result : data } );
                    }
                },
                success_handler : function( data ) {
                    var item = { 'ab_id' : id_from_email(data.result.email), 'name': data.result.email, 'type' : 'email', 'real_name' : data.result.name };
                    add_token(item);
                    dojo.publish('showcase.close');
                    contact_suggestion_element.remove();
                    input_box.val('');
                    do_search();
                }
            });
        }

        // Helper functions -----------------------

        function clear_email_proposals(){
            $('.email_proposal',result_box).remove();
            email_proposals.length = 0;
        }

        function get_calendar_html(calendar){
            if(calendar.weekday === undefined) calendar.weekday = '?';
            return '<div class="calendar cal-small after"><div class="cal-wrap"><div class="cal-day-text">'+esc(calendar.weekday)+'</div><div class="cal-day">'+esc(calendar.day)+'</div><div class="cal-mon">'+esc(calendar.month)+'</div></div></div>';
        }

        function hide_results(){
            tip_container.show();
            result_box_container.hide();
        }

        function show_results(){
            tip_container.hide();
            result_box_container.show();
            remove_ab_open_button();
        }

        function show_all_users(){
            for(var i = 0; i < settings.users_arr_len; i++){
                settings.users_arr[i].element.addClass('visible');
            }
        }

        function hide_all_users(){
            for(var i = 0; i < settings.users_arr_len; i++){
                settings.users_arr[i].element.removeClass('visible');
            }
        }

        function hide_all_results(){
            for(var i = 0; i < settings.users_arr_len; i++){
                settings.users_arr[i].element.removeClass('visible');
            }
            for(var i = 0; i < settings.meetings_arr_len; i++){
                settings.meetings_arr[i].element.removeClass('visible');
            }
        }
        function show_all_results(){
            for(var i = 0; i < settings.users_arr_len; i++){
                settings.users_arr[i].element.addClass('visible');
            }
            for(var i = 0; i < settings.meetings_arr_len; i++){
                settings.meetings_arr[i].element.addClass('visible');
            }
        }

        function id_from_email(email){
            // JFK - 1 removed
            return 'e_'+ ( email_proposals.length - 1 );
        }

        function concatenate(string){
            if(string.length > 40) string = string.substr(37)+'...';
            return string;
        }

        function get_email(email){
            var pattern = new RegExp("(?:[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*|\"(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21\\x23-\\x5b\\x5d-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])*\")@(?:(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?|\\[(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?|[a-z0-9-]*[a-z0-9]:(?:[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f\\x21-\\x5a\\x53-\\x7f]|\\\\[\\x01-\\x09\\x0b\\x0c\\x0e-\\x7f])+)\\])");
            var result = pattern.exec(email.toLowerCase());
            if( result !== null ) result = result[0];
            else result = false;
            return result;
            // TODO: Handle the name part to the server too
        }

        // Return name string if email contains one
        function get_name_from_mail(email){
            var pattern = /\"(.*?)\"/; // Fix syntax hl "
            var result = pattern.exec(email.toLowerCase());
            if( result !== null && result[1] !== null ) result = result[0];
                else result = false;
            return result;
        }
    };

}(jQuery));

