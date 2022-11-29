dojo.provide("dicole.meetings.vendor.autocomplete");

dojo.require('dicole.meetings.vendor.jquery');

/* Autocomplete */
(function($) {
    $.fn.suggestible = function (options) {
        var defaults = {
            source: [],
            delay: 200,
            minLength: 1,
            selectOnBlur: false,
            alwaysShow: false,
            limit: 3,
            formatSuggestion: function (suggestion, search_term) {
                return suggestion;
            },
            rejectSelected: function (suggestions) {
                return suggestions;
            },
            extractSearchTerms: function (value) {
                return [value];
            },
            onSelect: function (value, suggestible) {
                $(suggestible).val(value);
            },
            addElementToDom: function (suggestible, resultsHolder) {
                suggestible.after(resultsHolder);
            },
            buildRegex: function (term) {
                return '^' + term;
            }
        };
        var options = $.extend(defaults, options);
        var source;

        function escapeRegex(value) {
            return value.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&");
        }

        function filter(array, term) {
            var matcher = new RegExp(options.buildRegex(escapeRegex(term)), "i")
            return $.grep(array, function(value) {
                var match = false;
                $.each(options.extractSearchTerms(value), function (index, term) {
                    if (matcher.test($.trim(term))) {
                        match = true;
                        return;
                    }
                });
                return match;
            });
        }

        (function initSource() {
            if ($.isArray(options.source)) {
                source = function(terms, callback) {
                    callback(options.source);
                };
            } else {
                source = options.source;
            }
        })();

        return this.each(function() {
            var $this = $(this);
            var id = $(this).attr('id');
            var lastSearch = false;
            var search_timeout;
            var closing_timeout;
            var pollTimeout;
            var noResults;
            var suggestionsActive = false;

            // Setup HTML
            $this.attr("autocomplete","off").addClass("suggestible-input");
            var $results_holder = $('<div class="suggestible-results" id="suggestible-results-' + id + '"></div>').hide();
            var $results_ul = $('<ul class="suggestible-list"></ul>');
            $results_holder.html($results_ul);
            options.addElementToDom($this, $results_holder);

            if (options.alwaysShow) {
                options.minLength = -1;
                search("", loadSuggestions);
            }

            function search(term, callback) {
                lastSearch = $this.val();
                if (callback == undefined) {
                    callback = loadSuggestions;
                }

                if ( term.length < options.minLength ) {
                    clearSearch();
                    return hideSuggestions(true);
                }

                $this.addClass('loading');
                source(term, function (results) {
                    var suggestions = options.rejectSelected(filter(results, term));
                    $this.removeClass('loading');
                    callback(suggestions, term);
                });
            }

            function loadSuggestions (suggestions, term) {
                $results_ul.html("");
                $.each(suggestions, function (index, item) {
                    if( index > options.limit - 1 ) return false;
                    var suggestionHolder = $('<li class="suggestible-item" id="suggestible-item-' + index + '"></li>').data('item', item);
                    suggestionHolder.html(options.formatSuggestion(item, term));
                    $results_ul.append(suggestionHolder);
                });
                if( $results_ul.html() !== '' ){
                    noResults = false;
                    showSuggestions();
                    moveSelection('down');
                } else {
                    noResults = true;
                }
            }

            function showSuggestions () {
                $results_ul.css("width", $this.outerWidth() - 2);
                $results_holder.show();
                suggestionsActive = true;
            }

            function hideSuggestions () {
                clearTimeout(closing_timeout);
                if (options.alwaysShow) {
                    return true;
                }
                $results_holder.hide();
                return suggestionsActive = false;
            }

            function selectActive () {
                var raw_data = $("li.active", $results_ul).data("item");
                if (raw_data) {
                    options.onSelect(raw_data, $this);
                }
                if (!options.alwaysShow) {
                    hideSuggestions();
                    clearSearch(raw_data);
                }
            }

            function clearSearch (val) {
                lastSearch = val || null;
                $this.val(val || null);
                $results_ul.html("");
            }

            function moveSelection (direction) {
                if ($(":visible",$results_holder).length > 0) {
                    var lis = $("li", $results_holder);
                    var start = (direction == "down") ? lis.eq(0) : lis.filter(":last");
                    var active = $("li.active:first", $results_holder);
                    if (active.length > 0) {
                        start = (direction == "down") ? active.next() : active.prev();
                    }
                    lis.removeClass("active");
                    start.addClass("active");
                }
            }

            function checkForChanges() {
                // only search if the value changed
                if (lastSearch != $this.val() ) {
                    search($.trim($this.val()), loadSuggestions);
                }
            }

            $this
            .focus(function () {
                if ($results_ul.html() !== "") {
                    showSuggestions();
                } else if (options.showListOnFocus) {
                    search("", loadSuggestions);
                }
                clearInterval(pollTimeout);
                pollTimeout = setInterval(checkForChanges, 100);
            })
            .blur(function () {
              clearTimeout(search_timeout);
                clearInterval(pollTimeout);
                if (options.selectOnBlur) {
                    selectActive();
                }
                // JFK: changed timeout to larger and added closing to click
                closing_timeout = setTimeout(hideSuggestions, 1500);
            })
            .keydown(function (e) {
                e.stopPropagation();
                switch(e.keyCode) {
                    case 38:
                        moveSelection('up');
                    e.preventDefault();
                    break;
                    case 40:
                        moveSelection('down');
                    e.preventDefault();
                    break;
                    case 13:
                        if (suggestionsActive) {
                        e.preventDefault();
                        selectActive();
                        break;
                    }
                    case 9:
                        console.log('norses: ',noResults)
                        if (suggestionsActive && ! noResults ) {
                        e.preventDefault();
                        selectActive();
                    }
                    break;
                    case 27:
                        hideSuggestions();
                    e.preventDefault();
                    break;
                    default:
                        clearTimeout(search_timeout);
                    search_timeout = setTimeout(checkForChanges, options.delay);
                    break;
                }
            });

           $(document).on('click', '#suggestible-results-' + id + ' .suggestible-item', null, function(){
               clearTimeout(closing_timeout);
               selectActive();
               hideSuggestions();
           });
           $(document).on('mouseover', '#suggestible-results-' + id + ' .suggestible-item', null, function () {
                $("li", $results_ul).removeClass("active");
                $(this).addClass("active");
            });
        });
    };
})(jQuery);
