dojo.provide("dicole.meetings.vendor.guiders");

dojo.require('dicole.meetings.vendor.jquery');


/**
 * guiders.js
 *
 * version 1.2.6
 *
 * Developed at Optimizely. (www.optimizely.com)
 * We make A/B testing you'll actually use.
 *
 * Released under the Apache License 2.0.
 * www.apache.org/licenses/LICENSE-2.0.html
 *
 * Questions about Guiders?
 * You may email me (Jeff Pickhardt) at jeff+pickhardt@optimizely.com
 *
 * Questions about Optimizely should be sent to:
 * sales@optimizely.com or support@optimizely.com
 *
 * Enjoy!
 *
 * A PROMINENT NOTICE:
 * Meetin.gs had changed the following jQuery plugin.
 */

var guiders = (function($) {
    var guiders = {};

    guiders.version = "1.2.6";

    guiders._defaultSettings = {
        attachTo: null, // Selector of the element to attach to.
        autoFocus: false, // Determines whether or not the browser scrolls to the element.
        buttons: [{name: "Close"}],
        buttonCustomHTML: "",
        classString: null,
        description: "Lorem ipsum dolor sit amet.",
        highlight: null,
        isHashable: true,
        offset: {
            top: null,
            left: null
        },
        onShow: null,
        onHide: null,
        overlay: false,
        position: 0, // 1-12 follows an analog clock, 0 means centered.
        title: "Sample title goes here",
        width: 400,
        xButton: false // This places a closer "x" button in the top right of the guider.
    };

    guiders._htmlSkeleton = [
        "<div class='guider'>",
        "  <div class='guider_content'>",
        "    <h1 class='guider_title'></h1>",
        "    <div class='guider_close'></div>",
        "    <p class='guider_description'></p>",
        "    <div class='guider_buttons'>",
        "    </div>",
        "  </div>",
        "  <div class='guider_arrow'>",
        "  </div>",
        "</div>"
    ].join("");

    guiders._arrowSize = 42; // This is the arrow's width and height.
    guiders._buttonElement = "<a></a>";
    guiders._buttonAttributes = {"href": "javascript:void(0);"};
    guiders._closeButtonTitle = "Close";
    guiders._currentGuiderID = null;
    guiders._guiders = {};
    guiders._lastCreatedGuiderID = null;
    guiders._nextButtonTitle = "Next";
    guiders._offsetNameMapping = {
        "topLeft": 11,
        "top": 12,
        "topRight": 1,
        "rightTop": 2,
        "right": 3,
        "rightBottom": 4,
        "bottomRight": 5,
        "bottom": 6,
        "bottomLeft": 7,
        "leftBottom": 8,
        "left": 9,
        "leftTop": 10
    };
    guiders._windowHeight = 0;

    guiders._addButtons = function(myGuider) {
        var guiderButtonsContainer = myGuider.elem.find(".guider_buttons");

        if (myGuider.buttons === null || myGuider.buttons.length === 0) {
            guiderButtonsContainer.remove();
            return;
        }

        for (var i = myGuider.buttons.length - 1; i >= 0; i--) {
            var thisButton = myGuider.buttons[i];
            var thisButtonElem;

            // Checkbox
            if (typeof thisButton.type !== "undefined" && thisButton.type !== null && thisButton.type === 'checkbox') {
                thisButtonText = $('<label class="guider_label">'+thisButton.name+'</label>');
                thisButtonElem = $('<input class="guider_checkbox" type="checkbox"/>');
                guiderButtonsContainer.append(thisButtonText);
                guiderButtonsContainer.append(thisButtonElem);
                if (thisButton.change) {
                    thisButtonElem.change(thisButton.change);
                }
            }
            // Normal
            else{
                thisButtonElem = $(guiders._buttonElement, $.extend({
                    "class" : "guider_button",
                    "html" : thisButton.name },
                    guiders._buttonAttributes, thisButton.html || {}));
            }
            if (typeof thisButton.classString !== "undefined" && thisButton.classString !== null) {
                thisButtonElem.addClass(thisButton.classString);
            }

            guiderButtonsContainer.append(thisButtonElem);

            if (thisButton.onclick) {
                thisButtonElem.bind("click", thisButton.onclick);
            } else if (!thisButton.onclick &&
                       thisButton.name.toLowerCase() === guiders._closeButtonTitle.toLowerCase()) {
                thisButtonElem.bind("click", function() { guiders.hideAll(); });
            } else if (!thisButton.onclick &&
                       thisButton.name.toLowerCase() === guiders._nextButtonTitle.toLowerCase()) {
                thisButtonElem.bind("click", function() { !myGuider.elem.data('locked') && guiders.next(); });
            }
        }

        if (myGuider.buttonCustomHTML !== "") {
            var myCustomHTML = $(myGuider.buttonCustomHTML);
            myGuider.elem.find(".guider_buttons").append(myCustomHTML);
        }

        if (myGuider.buttons.length === 0) {
            guiderButtonsContainer.remove();
        }
    };

    guiders.addCountDown = function(){
        // Add counts JFK
        var len = 0;
        $.each(guiders._guiders, function(i,o){
            len += 1;
        });
        var index = 1;
        $.each(guiders._guiders, function(i,o){
            var el = $('#'+o.id+' .guider_content');
            el.prepend('<div class="guiders_count">'+index+'/'+len+'</span>');
            index++;
        });
    };

    guiders._addXButton = function(myGuider) {
        var xButtonContainer = myGuider.elem.find(".guider_close");
        var xButton = $("<div></div>", {
            "class" : "x_button",
            "role" : "button" });
            xButtonContainer.append(xButton);
            xButton.click(function() {
                    // JFK: Call the callback instead
                myGuider.xButton();
            });
    };

    guiders._attach = function(myGuider) {
        if (myGuider === null) {
            return;
        }

        var attachTo = $(myGuider.attachTo);

        var myHeight = myGuider.elem.innerHeight();
        var myWidth = myGuider.elem.innerWidth();

        if (myGuider.position === 0 || attachTo.length === 0) {
            // The guider is positioned in the center of the screen.
            myGuider.elem.css("position", "fixed");
            myGuider.elem.css("top", ($(window).height() - myHeight) / 3 + "px");
            myGuider.elem.css("left", ($(window).width() - myWidth) / 2 + "px");
            return;
        }

        // Otherwise, the guider is positioned relative to the attachTo element.
        var base = attachTo.offset();
        var top = base.top;
        var left = base.left;

        // topMarginOfBody corrects positioning if body has a top margin set on it.
        var topMarginOfBody = $("body").outerHeight(true) - $("body").outerHeight(false);
        base -= topMarginOfBody;

        // Now, take into account how the guider should be positioned relative to the attachTo element.
        // e.g. top left, bottom center, etc.
        if (guiders._offsetNameMapping[myGuider.position]) {
            // As an alternative to the clock model, you can also use keywords to position the guider.
            myGuider.position = guiders._offsetNameMapping[myGuider.position];
        }

        var attachToHeight = attachTo.innerHeight();
        var attachToWidth = attachTo.innerWidth();
        var bufferOffset = 0.9 * guiders._arrowSize;

        // offsetMap follows the form: [height, width]
        var offsetMap = {
            1: [-bufferOffset - myHeight, attachToWidth - myWidth],
            2: [0, bufferOffset + attachToWidth],
            3: [attachToHeight/2 - myHeight/2, bufferOffset + attachToWidth],
            4: [attachToHeight - myHeight, bufferOffset + attachToWidth],
            5: [bufferOffset + attachToHeight, attachToWidth - myWidth],
            6: [bufferOffset + attachToHeight, attachToWidth/2 - myWidth/2],
            7: [bufferOffset + attachToHeight, 0],
            8: [attachToHeight - myHeight, -myWidth - bufferOffset],
            9: [attachToHeight/2 - myHeight/2, -myWidth - bufferOffset],
            10: [0, -myWidth - bufferOffset],
            11: [-bufferOffset - myHeight, 0],
            12: [-bufferOffset - myHeight, attachToWidth/2 - myWidth/2]
        };
        var offset = offsetMap[myGuider.position];
        top   += offset[0];
        left  += offset[1];

        var positionType = "absolute";
        // If the element you are attaching to is position: fixed, then we will make the guider
        // position: fixed as well.
        if (attachTo.css("position") == "fixed") {
            positionType = "fixed";
            top -= $(window).scrollTop();
            left -= $(window).scrollLeft();
        }

        // If you specify an additional offset parameter when you create the guider, it gets added here.
        if (myGuider.offset.top !== null) {
            top += myGuider.offset.top;
        }
        if (myGuider.offset.left !== null) {
            left += myGuider.offset.left;
        }

        // Finally, set the style of the guider and return it!
        return myGuider.elem.css({
            "position": positionType,
            "top": top,
            "left": left
        });
    };

    guiders._guiderById = function(id) {
        if (typeof guiders._guiders[id] === "undefined") {
            throw "Cannot find guider with id " + id;
        }
        return guiders._guiders[id];
    };

    guiders._showOverlay = function() {
        $("#guider_overlay").fadeIn("fast", function(){
            if (this.style.removeAttribute) {
                this.style.removeAttribute("filter");
            }
        });
        // This callback is needed to fix an IE opacity bug.
        // See also:
        // http://www.kevinleary.net/jquery-fadein-fadeout-problems-in-internet-explorer/
    };

    guiders._highlightElement = function(selector) {
        $(selector).addClass('guider_highlight');
    };

    guiders._dehighlightElement = function(selector) {
        $(selector).removeClass('guider_highlight');
    };

    guiders._hideOverlay = function() {
        $("#guider_overlay").fadeOut("fast");
    };

    guiders._initializeOverlay = function() {
        if ($("#guider_overlay").length === 0) {
            $("<div id=\"guider_overlay\"></div>").hide().appendTo("body");
        }
    };

    guiders._styleArrow = function(myGuider) {
        var position = myGuider.position || 0;
        if (!position) {
            return;
        }
        var myGuiderArrow = $(myGuider.elem.find(".guider_arrow"));
        var newClass = {
            1: "guider_arrow_down",
            2: "guider_arrow_left",
            3: "guider_arrow_left",
            4: "guider_arrow_left",
            5: "guider_arrow_up",
            6: "guider_arrow_up",
            7: "guider_arrow_up",
            8: "guider_arrow_right",
            9: "guider_arrow_right",
            10: "guider_arrow_right",
            11: "guider_arrow_down",
            12: "guider_arrow_down"
        };
        myGuiderArrow.addClass(newClass[position]);

        var myHeight = myGuider.elem.innerHeight();
        var myWidth = myGuider.elem.innerWidth();
        var arrowOffset = guiders._arrowSize / 2;
        var positionMap = {
            1: ["right", arrowOffset],
            2: ["top", arrowOffset],
            3: ["top", myHeight/2 - arrowOffset],
            4: ["bottom", arrowOffset],
            5: ["right", arrowOffset],
            6: ["left", myWidth/2 - arrowOffset],
            7: ["left", arrowOffset],
            8: ["bottom", arrowOffset],
            9: ["top", myHeight/2 - arrowOffset],
            10: ["top", arrowOffset],
            11: ["left", arrowOffset],
            12: ["left", myWidth/2 - arrowOffset]
        };
        var position = positionMap[myGuider.position];
        myGuiderArrow.css(position[0], position[1] + "px");
    };

    /**
     * One way to show a guider to new users is to direct new users to a URL such as
     * http://www.mysite.com/myapp#guider=welcome
     *
     * This can also be used to run guiders on multiple pages, by redirecting from
     * one page to another, with the guider id in the hash tag.
     *
     * Alternatively, if you use a session variable or flash messages after sign up,
     * you can add selectively add JavaScript to the page: "guiders.show('first');"
     */
    guiders._showIfHashed = function(myGuider) {
        var GUIDER_HASH_TAG = "guider=";
        var hashIndex = window.location.hash.indexOf(GUIDER_HASH_TAG);
        if (hashIndex !== -1) {
            var hashGuiderId = window.location.hash.substr(hashIndex + GUIDER_HASH_TAG.length);
            if (myGuider.id.toLowerCase() === hashGuiderId.toLowerCase()) {
                // Success!
                guiders.show(myGuider.id);
            }
        }
    };

    guiders.reposition = function() {
        var currentGuider = guiders._guiders[guiders._currentGuiderID];
        if( ! currentGuider ) return;
        guiders._attach(currentGuider);
    };

    guiders.next = function() {
        var currentGuider = guiders._guiders[guiders._currentGuiderID];
        if (typeof currentGuider === "undefined") {
            return;
        }
        currentGuider.elem.data('locked', true);

        var nextGuiderId = currentGuider.next || null;
        if (nextGuiderId !== null && nextGuiderId !== "") {
            var myGuider = guiders._guiderById(nextGuiderId);
            var omitHidingOverlay = myGuider.overlay ? true : false;
            guiders.hideAll(omitHidingOverlay, true);
            if (currentGuider && currentGuider.highlight) {
                guiders._dehighlightElement(currentGuider.highlight);
            }
            guiders.show(nextGuiderId);
        }
    };

    guiders.createGuider = function(passedSettings) {
        if (passedSettings === null || passedSettings === undefined) {
            passedSettings = {};
        }

        // Extend those settings with passedSettings
        myGuider = $.extend({}, guiders._defaultSettings, passedSettings);
        myGuider.id = myGuider.id || String(Math.floor(Math.random() * 1000));

        var guiderElement = $(guiders._htmlSkeleton);
        myGuider.elem = guiderElement;
        if (typeof myGuider.classString !== "undefined" && myGuider.classString !== null) {
            myGuider.elem.addClass(myGuider.classString);
        }
        myGuider.elem.css("width", myGuider.width + "px");

        var guiderTitleContainer = guiderElement.find(".guider_title");
        guiderTitleContainer.html(myGuider.title);

        guiderElement.find(".guider_description").html(myGuider.description);

        guiders._addButtons(myGuider);

        if (myGuider.xButton) {
            guiders._addXButton(myGuider);
        }

        guiderElement.hide();
        guiderElement.appendTo("body");
        guiderElement.attr("id", myGuider.id);

        // Ensure myGuider.attachTo is a jQuery element.
        if (typeof myGuider.attachTo !== "undefined" && myGuider !== null) {
            guiders._attach(myGuider) && guiders._styleArrow(myGuider);
        }

        guiders._initializeOverlay();

        guiders._guiders[myGuider.id] = myGuider;
        guiders._lastCreatedGuiderID = myGuider.id;

        /**
         * If the URL of the current window is of the form
         * http://www.myurl.com/mypage.html#guider=id
         * then show this guider.
         */
        if (myGuider.isHashable) {
            guiders._showIfHashed(myGuider);
        }

        return guiders;
    };

    guiders.hideAll = function(omitHidingOverlay, next) {
        next = next || false;

        $(".guider:visible").each(function(index, elem){
            var myGuider = guiders._guiderById($(elem).attr('id'));
            if (myGuider.onHide) {
                myGuider.onHide(myGuider, next);
            }
        });
        $(".guider").fadeOut("fast");
        var currentGuider = guiders._guiders[guiders._currentGuiderID];
        if (currentGuider && currentGuider.highlight) {
            guiders._dehighlightElement(currentGuider.highlight);
        }
        if (typeof omitHidingOverlay !== "undefined" && omitHidingOverlay === true) {
            // do nothing for now
        } else {
            guiders._hideOverlay();
        }
        return guiders;
    };

    guiders.show = function(id) {
        if (!id && guiders._currentGuiderID) {
            id = guiders._currentGuiderID;
        }

        var myGuider = guiders._guiderById(id);
        if (myGuider.overlay) {
            guiders._showOverlay();
            // if guider is attached to an element, make sure it's visible
            if (myGuider.highlight) {
                guiders._highlightElement(myGuider.highlight);
            }
        }

        // You can use an onShow function to take some action before the guider is shown.
        if (myGuider.onShow) {
            myGuider.onShow(myGuider);
        }
        guiders._attach(myGuider);
        myGuider.elem.fadeIn("fast").data("locked", false);

        guiders._currentGuiderID = id;

        var windowHeight = guiders._windowHeight = $(window).height();
        var scrollHeight = $(window).scrollTop();
        var guiderOffset = myGuider.elem.offset();
        var guiderElemHeight = myGuider.elem.height();

        var isGuiderBelow = (scrollHeight + windowHeight < guiderOffset.top + guiderElemHeight); /* we will need to scroll down */
        var isGuiderAbove = (guiderOffset.top < scrollHeight); /* we will need to scroll up */

        if (myGuider.autoFocus && (isGuiderBelow || isGuiderAbove)) {
            // Sometimes the browser won't scroll if the person just clicked,
            // so let's do this in a setTimeout.
            setTimeout(guiders.scrollToCurrent, 10);
        }

        $(myGuider.elem).trigger("guiders.show");

        return guiders;
    };

    guiders.scrollToCurrent = function() {
        var currentGuider = guiders._guiders[guiders._currentGuiderID];
        if (typeof currentGuider === "undefined") {
            return;
        }

        var windowHeight = guiders._windowHeight;
        var scrollHeight = $(window).scrollTop();
        var guiderOffset = currentGuider.elem.offset();
        var guiderElemHeight = currentGuider.elem.height();

        // Scroll to the guider's position.
        var scrollToHeight = Math.round(Math.max(guiderOffset.top + (guiderElemHeight / 2) - (windowHeight / 2), 0));
        window.scrollTo(0, scrollToHeight);
    };

    // Change the bubble position after browser gets resized
    var _resizing = undefined;
    $(window).resize(function() {
        if (typeof(_resizing) !== "undefined") {
            clearTimeout(_resizing); // Prevents seizures
        }
        _resizing = setTimeout(function() {
            _resizing = undefined;
            guiders.reposition();
        }, 20);
    });

    return guiders;
}).call(this, jQuery);




// Quicksearch
(function($, window, document, undefined) {
 $.fn.quicksearch = function (target, opt) {

var timeout, cache, rowcache, jq_results, val = '', e = this, options = $.extend({
    delay: 100,
    selector: null,
    stripeRows: null,
    loader: null,
    noResults: '',
    matchedResultsCount: 0,
    bind: 'keyup',
    onBefore: function () {
        return;
    },
    onAfter: function () {
        return;
    },
    show: function () {
        this.style.display = "";
    },
    hide: function () {
        this.style.display = "none";
    },
    prepareQuery: function (val) {
        return val.toLowerCase().split(' ');
    },
    testQuery: function (query, txt, _row) {
        for (var i = 0; i < query.length; i += 1) {
            if (txt.indexOf(query[i]) === -1) {
                return false;
            }
        }
        return true;
    }
}, opt);

this.go = function () {

    var i = 0,
    numMatchedRows = 0,
    noresults = true,
    query = options.prepareQuery(val),
    val_empty = (val.replace(' ', '').length === 0);

    for (var i = 0, len = rowcache.length; i < len; i++) {
        if (val_empty || options.testQuery(query, cache[i], rowcache[i])) {
            options.show.apply(rowcache[i]);
            noresults = false;
            numMatchedRows++;
        } else {
            options.hide.apply(rowcache[i]);
        }
    }

    if (noresults) {
        this.results(false);
    } else {
        this.results(true);
        this.stripe();
    }

    this.matchedResultsCount = numMatchedRows;
    this.loader(false);
    options.onAfter();

    return this;
};

/*
 * External API so that users can perform search programatically.
 * */
this.search = function (submittedVal) {
    val = submittedVal;
    e.trigger();
};

/*
 * External API to get the number of matched results as seen in
 * https://github.com/ruiz107/quicksearch/commit/f78dc440b42d95ce9caed1d087174dd4359982d6
 * */
this.currentMatchedResults = function() {
    return this.matchedResultsCount;
};

this.stripe = function () {

    if (typeof options.stripeRows === "object" && options.stripeRows !== null)
        {
            var joined = options.stripeRows.join(' ');
            var stripeRows_length = options.stripeRows.length;

            jq_results.not(':hidden').each(function (i) {
                $(this).removeClass(joined).addClass(options.stripeRows[i % stripeRows_length]);
            });
        }

        return this;
};

this.strip_html = function (input) {
    var output = input.replace(new RegExp('<[^<]+\>', 'g'), "");
    output = $.trim(output.toLowerCase());
    return output;
};

this.results = function (bool) {
    if (typeof options.noResults === "string" && options.noResults !== "") {
        if (bool) {
            $(options.noResults).hide();
        } else {
            $(options.noResults).show();
        }
    }
    return this;
};

this.loader = function (bool) {
    if (typeof options.loader === "string" && options.loader !== "") {
        (bool) ? $(options.loader).show() : $(options.loader).hide();
    }
    return this;
};

this.cache = function () {

    jq_results = $(target);

    if (typeof options.noResults === "string" && options.noResults !== "") {
        jq_results = jq_results.not(options.noResults);
    }

    var t = (typeof options.selector === "string") ? jq_results.find(options.selector) : $(target).not(options.noResults);
    cache = t.map(function () {
        return e.strip_html(this.innerHTML);
    });

    rowcache = jq_results.map(function () {
        return this;
    });

    /*
     * Modified fix for sync-ing "val".
     * Original fix https://github.com/michaellwest/quicksearch/commit/4ace4008d079298a01f97f885ba8fa956a9703d1
     * */
    val = val || this.val() || "";

    return this.go();
};

this.trigger = function () {
    this.loader(true);
    options.onBefore();

    window.clearTimeout(timeout);
    timeout = window.setTimeout(function () {
        e.go();
    }, options.delay);

    return this;
};

this.cache();
this.results(true);
this.stripe();
this.loader(false);

return this.each(function () {

        /*
         * Changed from .bind to .on.
         * */
    $(this).on(options.bind, function () {

        val = $(this).val();
        e.trigger();
    });
});

 };

}(jQuery, this, document));
