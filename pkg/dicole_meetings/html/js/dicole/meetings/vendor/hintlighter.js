dojo.provide("dicole.meetings.vendor.hintlighter");

dojo.require('dicole.meetings.vendor.jquery');

/*
 * jQuery Plugin: Meetin.gs element hintlighter
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
        duration : 20000,
        end_on_mouseover : true,
        zindex_override : false,
        hintlight_color : '#ffffff',
        position : 'centered'
    };

    var methods = {
        init: function(options) {
            var settings = $.extend({}, DEFAULT_SETTINGS, options || {});

            return this.each(function () {
                $(this).data("hlObject", new $.hl(this, settings));
            });
        }
    };

    // Expose the hintLight function to jQuery as a plugin
    $.fn.hintLight = function (method) {
        // Method calling and initialization logic
        if(methods[method]) {
            return methods[method].apply(this, Array.prototype.slice.call(arguments, 1));
        } else {
            return methods.init.apply(this, arguments);
        }
    };

    // hl class for each element
    $.hl = function (el, settings) {
        el = $(el);
        // Create higlight element
        var hl_el = $('<span class="hl-pulse"/>');
        $('body').append(hl_el);

        // Center the element
        if( settings.position === 'centered' ){
            position_hl_element();
        }

        // Remove element, when time is up
        if( typeof settings.duration === "number" ){
            setTimeout(function(){
                remove_hl_element();
            }, settings.duration);
        }

        // Remove element on mouseover & click
        if( settings.end_on_mouseover ){
            hl_el.on('mouseover click', function(){
                remove_hl_element();
            });
        }

        // Reposition on resize & orientation change
        $(window).on('orientationchange resize', function(){
            position_hl_element();
        });

        // Helper functions ---------
        function remove_hl_element(){
            if( hl_el ){
                hl_el.fadeOut('fast',function(){
                    hl_el.remove();
                });
            }
        }
        function position_hl_element(){
            var w = el.innerWidth();
            var h = el.innerHeight();
            var p = el.offset();

            hl_el.css({
                "top" : p.top - 4, // compensate for 4px border
                "left" : p.left,
                "width" : w,
                "height" : h,
                "border-color" : settings.hintlight_color
            });

            if( settings.zindex_override ){
                hl_el.css("z-index",settings.zindex_override);
            }
        }
    };
}(jQuery));
