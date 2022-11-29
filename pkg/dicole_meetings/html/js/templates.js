(function () {
var root = this, exports = {};

// The jade runtime:
var jade=function(exports){Array.isArray||(Array.isArray=function(arr){return"[object Array]"==Object.prototype.toString.call(arr)}),Object.keys||(Object.keys=function(obj){var arr=[];for(var key in obj)obj.hasOwnProperty(key)&&arr.push(key);return arr}),exports.merge=function merge(a,b){var ac=a["class"],bc=b["class"];if(ac||bc)ac=ac||[],bc=bc||[],Array.isArray(ac)||(ac=[ac]),Array.isArray(bc)||(bc=[bc]),ac=ac.filter(nulls),bc=bc.filter(nulls),a["class"]=ac.concat(bc).join(" ");for(var key in b)key!="class"&&(a[key]=b[key]);return a};function nulls(val){return val!=null}return exports.attrs=function attrs(obj,escaped){var buf=[],terse=obj.terse;delete obj.terse;var keys=Object.keys(obj),len=keys.length;if(len){buf.push("");for(var i=0;i<len;++i){var key=keys[i],val=obj[key];"boolean"==typeof val||null==val?val&&(terse?buf.push(key):buf.push(key+'="'+key+'"')):0==key.indexOf("data")&&"string"!=typeof val?buf.push(key+"='"+JSON.stringify(val)+"'"):"class"==key&&Array.isArray(val)?buf.push(key+'="'+exports.escape(val.join(" "))+'"'):escaped&&escaped[key]?buf.push(key+'="'+exports.escape(val)+'"'):buf.push(key+'="'+val+'"')}}return buf.join(" ")},exports.escape=function escape(html){return String(html).replace(/&(?!(\w+|\#\d+);)/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;")},exports.rethrow=function rethrow(err,filename,lineno){if(!filename)throw err;var context=3,str=require("fs").readFileSync(filename,"utf8"),lines=str.split("\n"),start=Math.max(lineno-context,0),end=Math.min(lines.length,lineno+context),context=lines.slice(start,end).map(function(line,i){var curr=i+start+1;return(curr==lineno?"  > ":"    ")+curr+"| "+line}).join("\n");throw err.path=filename,err.message=(filename||"Jade")+":"+lineno+"\n"+context+"\n\n"+err.message,err},exports}({});

// create our folder objects

// agentAdminCalendars.jade compiled template
exports.agentAdminCalendars = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div class="input-row"><span class="input-label">Käyttäjä</span>\n  <select');
        buf.push(attrs({
            "x-data-object-field": "user_email",
            disabled: typeof admin_calendar == "undefined" ? undefined : "disabled",
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            disabled: true
        }));
        buf.push('>\n    <option value="">[valitse käyttäjä]</option>');
        (function() {
            if ("number" == typeof users.length) {
                for (var $index = 0, $$l = users.length; $index < $$l; $index++) {
                    var u = users[$index];
                    buf.push("\n    <option");
                    buf.push(attrs({
                        value: u.email,
                        selected: u.email == (typeof admin_calendar == "undefined" ? undefined : admin_calendar.user_email) ? "selected" : undefined
                    }, {
                        value: true,
                        selected: true
                    }));
                    buf.push(">");
                    var __val__ = u.email;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</option>");
                }
            } else {
                var $$l = 0;
                for (var $index in users) {
                    $$l++;
                    var u = users[$index];
                    buf.push("\n    <option");
                    buf.push(attrs({
                        value: u.email,
                        selected: u.email == (typeof admin_calendar == "undefined" ? undefined : admin_calendar.user_email) ? "selected" : undefined
                    }, {
                        value: true,
                        selected: true
                    }));
                    buf.push(">");
                    var __val__ = u.email;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</option>");
                }
            }
        }).call(this);
        buf.push('\n  </select>\n</div>\n<div class="input-row"><span class="input-label">Toimisto</span>\n  <select');
        buf.push(attrs({
            "x-data-object-field": "office_full_name",
            disabled: typeof admin_calendar == "undefined" ? undefined : "disabled",
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            disabled: true
        }));
        buf.push('>\n    <option value="">[valitse toimisto]</option>');
        (function() {
            if ("number" == typeof offices.length) {
                for (var $index = 0, $$l = offices.length; $index < $$l; $index++) {
                    var o = offices[$index];
                    buf.push("\n    <option");
                    buf.push(attrs({
                        value: o.full_name,
                        selected: o.full_name == (typeof admin_calendar == "undefined" ? undefined : admin_calendar.office_full_name) ? "selected" : undefined
                    }, {
                        value: true,
                        selected: true
                    }));
                    buf.push(">");
                    var __val__ = o.full_name;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</option>");
                }
            } else {
                var $$l = 0;
                for (var $index in offices) {
                    $$l++;
                    var o = offices[$index];
                    buf.push("\n    <option");
                    buf.push(attrs({
                        value: o.full_name,
                        selected: o.full_name == (typeof admin_calendar == "undefined" ? undefined : admin_calendar.office_full_name) ? "selected" : undefined
                    }, {
                        value: true,
                        selected: true
                    }));
                    buf.push(">");
                    var __val__ = o.full_name;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</option>");
                }
            }
        }).call(this);
        buf.push('\n  </select>\n</div>\n<div class="input-row">\n  <div class="input-label-row"><span>Palvelukielet:</span></div>');
        (function() {
            if ("number" == typeof all_languages.length) {
                for (var $index = 0, $$l = all_languages.length; $index < $$l; $index++) {
                    var lang = all_languages[$index];
                    buf.push("\n  <div>\n    <input");
                    buf.push(attrs({
                        "x-data-object-field": "languages",
                        "x-data-object-field-type": "array",
                        type: "checkbox",
                        value: lang.id,
                        checked: typeof admin_calendar !== "undefined" && admin_calendar.languages_map[lang.id] ? "checked" : undefined,
                        "class": "object-field"
                    }, {
                        "x-data-object-field": true,
                        "x-data-object-field-type": true,
                        type: true,
                        value: true,
                        checked: true
                    }));
                    buf.push("/><span>");
                    var __val__ = lang.name;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</span>\n  </div>");
                }
            } else {
                var $$l = 0;
                for (var $index in all_languages) {
                    $$l++;
                    var lang = all_languages[$index];
                    buf.push("\n  <div>\n    <input");
                    buf.push(attrs({
                        "x-data-object-field": "languages",
                        "x-data-object-field-type": "array",
                        type: "checkbox",
                        value: lang.id,
                        checked: typeof admin_calendar !== "undefined" && admin_calendar.languages_map[lang.id] ? "checked" : undefined,
                        "class": "object-field"
                    }, {
                        "x-data-object-field": true,
                        "x-data-object-field-type": true,
                        type: true,
                        value: true,
                        checked: true
                    }));
                    buf.push("/><span>");
                    var __val__ = lang.name;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</span>\n  </div>");
                }
            }
        }).call(this);
        buf.push('\n</div>\n<div class="input-row">\n  <div class="input-label-row"><span>Palvelutasot:</span></div>');
        (function() {
            if ("number" == typeof all_service_levels.length) {
                for (var $index = 0, $$l = all_service_levels.length; $index < $$l; $index++) {
                    var sl = all_service_levels[$index];
                    buf.push("\n  <div>\n    <input");
                    buf.push(attrs({
                        "x-data-object-field": "service_levels",
                        "x-data-object-field-type": "array",
                        type: "checkbox",
                        value: sl.id,
                        checked: typeof admin_calendar !== "undefined" && admin_calendar.service_levels_map[sl.id] ? "checked" : undefined,
                        "class": "object-field"
                    }, {
                        "x-data-object-field": true,
                        "x-data-object-field-type": true,
                        type: true,
                        value: true,
                        checked: true
                    }));
                    buf.push("/><span>");
                    var __val__ = sl.name;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</span>\n  </div>");
                }
            } else {
                var $$l = 0;
                for (var $index in all_service_levels) {
                    $$l++;
                    var sl = all_service_levels[$index];
                    buf.push("\n  <div>\n    <input");
                    buf.push(attrs({
                        "x-data-object-field": "service_levels",
                        "x-data-object-field-type": "array",
                        type: "checkbox",
                        value: sl.id,
                        checked: typeof admin_calendar !== "undefined" && admin_calendar.service_levels_map[sl.id] ? "checked" : undefined,
                        "class": "object-field"
                    }, {
                        "x-data-object-field": true,
                        "x-data-object-field-type": true,
                        type: true,
                        value: true,
                        checked: true
                    }));
                    buf.push("/><span>");
                    var __val__ = sl.name;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</span>\n  </div>");
                }
            }
        }).call(this);
        buf.push('\n</div>\n<div class="input-row">\n  <div class="input-label-row"><span>Tapaamistyyypit:</span></div>');
        (function() {
            if ("number" == typeof all_meeting_types.length) {
                for (var $index = 0, $$l = all_meeting_types.length; $index < $$l; $index++) {
                    var mt = all_meeting_types[$index];
                    buf.push("\n  <div>\n    <input");
                    buf.push(attrs({
                        "x-data-object-field": "meeting_types",
                        "x-data-object-field-type": "array",
                        type: "checkbox",
                        value: mt.id,
                        checked: typeof admin_calendar !== "undefined" && admin_calendar.meeting_types_map[mt.id] ? "checked" : undefined,
                        "class": "object-field"
                    }, {
                        "x-data-object-field": true,
                        "x-data-object-field-type": true,
                        type: true,
                        value: true,
                        checked: true
                    }));
                    buf.push("/><span>");
                    var __val__ = mt.name;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</span>\n  </div>");
                }
            } else {
                var $$l = 0;
                for (var $index in all_meeting_types) {
                    $$l++;
                    var mt = all_meeting_types[$index];
                    buf.push("\n  <div>\n    <input");
                    buf.push(attrs({
                        "x-data-object-field": "meeting_types",
                        "x-data-object-field-type": "array",
                        type: "checkbox",
                        value: mt.id,
                        checked: typeof admin_calendar !== "undefined" && admin_calendar.meeting_types_map[mt.id] ? "checked" : undefined,
                        "class": "object-field"
                    }, {
                        "x-data-object-field": true,
                        "x-data-object-field-type": true,
                        type: true,
                        value: true,
                        checked: true
                    }));
                    buf.push("/><span>");
                    var __val__ = mt.name;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</span>\n  </div>");
                }
            }
        }).call(this);
        buf.push('\n</div>\n<div class="input-row">\n  <div class="input-label-row"><span>Verkkotapaamisen</span></div>\n</div>\n<div class="input-row"><span class="input-label">osoite</span>\n  <input');
        buf.push(attrs({
            "x-data-object-field": "extra_meeting_email",
            size: 40,
            value: typeof admin_calendar == "undefined" ? undefined : admin_calendar.extra_meeting_email,
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            size: true,
            value: true
        }));
        buf.push('/>\n</div>\n<div class="input-row">\n  <div class="input-label-row"><span>Kalenterin rajattu saatavuus:</span></div>\n</div>\n<div class="input-row"><span class="input-label">Ensimmäinen varattava päivä</span>\n  <input');
        buf.push(attrs({
            id: "first-day-" + (typeof admin_calendar == "undefined" ? "new" : admin_calendar.safe_uid),
            "x-data-object-field": "first_reservable_day",
            size: 10,
            value: typeof admin_calendar == "undefined" ? undefined : admin_calendar.first_reservable_day,
            "class": "object-field" + " " + "js_dmy_datepicker_input"
        }, {
            id: true,
            "x-data-object-field": true,
            size: true,
            value: true
        }));
        buf.push('/>\n</div>\n<div class="input-row"><span class="input-label">Viimeinen varattava päivä</span>\n  <input');
        buf.push(attrs({
            id: "last-day-" + (typeof admin_calendar == "undefined" ? "new" : admin_calendar.safe_uid),
            "x-data-object-field": "last_reservable_day",
            size: 10,
            value: typeof admin_calendar == "undefined" ? undefined : admin_calendar.last_reservable_day,
            "class": "object-field" + " " + "js_dmy_datepicker_input"
        }, {
            id: true,
            "x-data-object-field": true,
            size: true,
            value: true
        }));
        buf.push("/>\n</div>");
        if (selected_area == "esim") {
            {
                buf.push('\n<div class="input-row"><span class="input-label">Yhdistä sisäinen kalenteri</span>\n  <select x-data-object-field="disable_calendar_sync" class="object-field">\n    <option value="">Kyllä</option>\n    <option');
                buf.push(attrs({
                    value: "yes",
                    selected: "yes" == (typeof admin_calendar == "undefined" ? undefined : admin_calendar.disable_calendar_sync) ? "selected" : undefined
                }, {
                    value: true,
                    selected: true
                }));
                buf.push(">Ei</option>\n  </select>\n</div>");
            }
        }
    }
    return buf.join("");
};

// meetingMaterialUploads.jade compiled template
exports.meetingMaterialUploads = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="progress-bar"></div><a class="button blue"><i class="ico-add"></i>');
        var __val__ = MTN.t("Add new material");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a>\n<p id="progress-text">');
        var __val__ = MTN.t("Drag & drop materials here");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n<input id="material-upload-button" type="file" name="file"/>');
    }
    return buf.join("");
};

// thanksForPaying.jade compiled template
exports.thanksForPaying = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="start-trial" class="m-modal">\n  <div class="modal-header">\n    <h3>');
        var __val__ = MTN.t("Thank you!");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3>\n  </div>\n  <div class="modal-content">\n    <p>');
        var __val__ = MTN.t("Your Meetin.gs PRO subscription is now active. You can continue with the PRO features enabled by clicking continue below.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n  </div>\n  <div class="modal-footer"> \n    <div class="buttons right"><a href="#" class="button blue continue">');
        var __val__ = MTN.t("Continue");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// agentBooking.jade compiled template
exports.agentBooking = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="agent-booking" class="m-modal">\n  <div class="modal-header">\n    <h3> <i class="ico-profile"></i>');
        var __val__ = "Varaa aika" || MTN.t("Reserve a time");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n    </h3>\n  </div>\n  <div class="modal-content">\n    <div class="agent-selectors">\n      <div class="selector-container"><span>');
        var __val__ = "Alue" || MTN.t("Area");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push("</span>\n        <select id=\"agent-area\" data-key=\"alue\"><!-- option(value='')='Valitse alue'||MTN.t('Choose an area') -->");
        (function() {
            if ("number" == typeof selector_data.areas.length) {
                for (var $index = 0, $$l = selector_data.areas.length; $index < $$l; $index++) {
                    var area = selector_data.areas[$index];
                    buf.push("\n          <option");
                    buf.push(attrs({
                        value: area.value,
                        selected: area.value == selected_area ? "selected" : undefined
                    }, {
                        value: true,
                        selected: true
                    }));
                    buf.push(">");
                    var __val__ = area.text;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</option>");
                }
            } else {
                var $$l = 0;
                for (var $index in selector_data.areas) {
                    $$l++;
                    var area = selector_data.areas[$index];
                    buf.push("\n          <option");
                    buf.push(attrs({
                        value: area.value,
                        selected: area.value == selected_area ? "selected" : undefined
                    }, {
                        value: true,
                        selected: true
                    }));
                    buf.push(">");
                    var __val__ = area.text;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</option>");
                }
            }
        }).call(this);
        buf.push('\n        </select>\n      </div>\n      <div class="selector-container"><span>');
        var __val__ = "Tyyppi" || MTN.t("Type");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</span>\n        <select id="agent-type" data-key="tyyppi">\n          <option value="">');
        var __val__ = "Valitse tyyppi" || MTN.t("Choose meeting type");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push("</option>");
        (function() {
            if ("number" == typeof selector_data.types.length) {
                for (var $index = 0, $$l = selector_data.types.length; $index < $$l; $index++) {
                    var type = selector_data.types[$index];
                    buf.push("\n          <option");
                    buf.push(attrs({
                        value: type.value
                    }, {
                        value: true
                    }));
                    buf.push(">");
                    var __val__ = type.text;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</option>");
                }
            } else {
                var $$l = 0;
                for (var $index in selector_data.types) {
                    $$l++;
                    var type = selector_data.types[$index];
                    buf.push("\n          <option");
                    buf.push(attrs({
                        value: type.value
                    }, {
                        value: true
                    }));
                    buf.push(">");
                    var __val__ = type.text;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</option>");
                }
            }
        }).call(this);
        buf.push('\n        </select>\n      </div>\n      <div class="selector-container"><span>');
        var __val__ = "Kieli" || MTN.t("Language");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</span>\n        <select id="agent-language" data-key="language">');
        (function() {
            if ("number" == typeof selector_data.languages.length) {
                for (var $index = 0, $$l = selector_data.languages.length; $index < $$l; $index++) {
                    var agent = selector_data.languages[$index];
                    buf.push("\n          <option");
                    buf.push(attrs({
                        value: agent.value
                    }, {
                        value: true
                    }));
                    buf.push(">");
                    var __val__ = agent.text;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</option>");
                }
            } else {
                var $$l = 0;
                for (var $index in selector_data.languages) {
                    $$l++;
                    var agent = selector_data.languages[$index];
                    buf.push("\n          <option");
                    buf.push(attrs({
                        value: agent.value
                    }, {
                        value: true
                    }));
                    buf.push(">");
                    var __val__ = agent.text;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</option>");
                }
            }
        }).call(this);
        buf.push('\n        </select>\n      </div>\n      <div class="selector-container"><span>');
        var __val__ = "Toimisto" || MTN.t("Office");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</span>\n        <select id="agent-office" data-key="toimisto">\n          <option value="">');
        var __val__ = "Valitse toimisto" || MTN.t("Choose an office");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push("</option>");
        (function() {
            if ("number" == typeof selector_data.offices.length) {
                for (var $index = 0, $$l = selector_data.offices.length; $index < $$l; $index++) {
                    var office = selector_data.offices[$index];
                    buf.push("\n          <option");
                    buf.push(attrs({
                        value: office.value
                    }, {
                        value: true
                    }));
                    buf.push(">");
                    var __val__ = office.text;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</option>");
                }
            } else {
                var $$l = 0;
                for (var $index in selector_data.offices) {
                    $$l++;
                    var office = selector_data.offices[$index];
                    buf.push("\n          <option");
                    buf.push(attrs({
                        value: office.value
                    }, {
                        value: true
                    }));
                    buf.push(">");
                    var __val__ = office.text;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</option>");
                }
            }
        }).call(this);
        buf.push('\n        </select>\n      </div>\n      <div class="selector-container"><span>');
        var __val__ = "Etutaso" || MTN.t("Level");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</span>\n        <select id="agent-level" data-key="level">');
        (function() {
            if ("number" == typeof selector_data.levels.length) {
                for (var $index = 0, $$l = selector_data.levels.length; $index < $$l; $index++) {
                    var agent = selector_data.levels[$index];
                    buf.push("\n          <option");
                    buf.push(attrs({
                        value: agent.value
                    }, {
                        value: true
                    }));
                    buf.push(">");
                    var __val__ = agent.text;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</option>");
                }
            } else {
                var $$l = 0;
                for (var $index in selector_data.levels) {
                    $$l++;
                    var agent = selector_data.levels[$index];
                    buf.push("\n          <option");
                    buf.push(attrs({
                        value: agent.value
                    }, {
                        value: true
                    }));
                    buf.push(">");
                    var __val__ = agent.text;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</option>");
                }
            }
        }).call(this);
        buf.push('\n        </select>\n      </div>\n      <div class="selector-container"><span>');
        var __val__ = "Henkilö" || MTN.t("Agent");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</span>\n        <select id="agent-agent" data-key="agentti">\n          <option value="">');
        var __val__ = "Valitse henkilö" || MTN.t("Choose an agent");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push("</option>");
        (function() {
            if ("number" == typeof selector_data.agents.length) {
                for (var $index = 0, $$l = selector_data.agents.length; $index < $$l; $index++) {
                    var agent = selector_data.agents[$index];
                    buf.push("\n          <option");
                    buf.push(attrs({
                        value: agent.value
                    }, {
                        value: true
                    }));
                    buf.push(">");
                    var __val__ = agent.text;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</option>");
                }
            } else {
                var $$l = 0;
                for (var $index in selector_data.agents) {
                    $$l++;
                    var agent = selector_data.agents[$index];
                    buf.push("\n          <option");
                    buf.push(attrs({
                        value: agent.value
                    }, {
                        value: true
                    }));
                    buf.push(">");
                    var __val__ = agent.text;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</option>");
                }
            }
        }).call(this);
        buf.push('\n        </select>\n      </div>\n    </div>\n    <div class="js-calendar-guide">\n      <p class="note">');
        var __val__ = "Valitse vähintään tyyppi ja sen jälkeen joko toimisto tai henkilö" || MTN.t("You need to select meeting type and either an office or an agent.");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</p>\n    </div>\n    <div class="calendar-container js-calendar-container"></div>\n  </div>\n</div>');
    }
    return buf.join("");
};

// startTrial.jade compiled template
exports.startTrial = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="sell-subscription" class="m-modal">');
        if (mode === "general_trial") {
            buf.push('\n  <div class="modal-header">\n    <h3>');
            var __val__ = MTN.t("Free gift! Access the full suite for 30 days.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</h3>\n  </div>\n  <div class="modal-content trial">\n    <p>');
            var __val__ = MTN.t("Have a good look at our service at your convenience without any commitments. Embrace the full potential offered for increased meeting productivity and let us know what you think.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</p>\n    <div class="pro-trial-upgrade">\n      <div class="star-box">\n        <h3>');
            var __val__ = MTN.t("Free");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</h3>\n        <p>");
            var __val__ = MTN.t("1 month trial");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</p>\n      </div>\n    </div>\n    <h3 class="pro-header">');
            var __val__ = MTN.t("Explore the full suite for free for 30 days with the following benefits:");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</h3>\n    <ul class="pro-list">\n      <li>');
            var __val__ = MTN.t("Save everyone from the pain of scheduling meetings.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</li>\n      <li>");
            var __val__ = MTN.t("Avoid the hassle by gathering all the meeting materials into one place.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</li>\n      <li>");
            var __val__ = MTN.t("No more access codes: Join in with phone, Skype, Lync and Hangouts with a single tap.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</li>\n      <li>");
            var __val__ = MTN.t("Be notified of meeting updates in an instant.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</li>\n    </ul>\n    <p style="margin-top:14px;">');
            var __val__ = MTN.t("Do you want to hear more or extend your trial? %(L$Schedule a meeting%) with our Head of Customer Happiness Antti and he will be happy to assist you.", {
                L: {
                    href: "http://meetin.gs/meet/amv"
                }
            });
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</p>\n    <div style="clear:both;"></div>\n  </div>\n  <div class="modal-footer"> \n    <div class="buttons right"><a href="#" class="start-trial button blue">');
            var __val__ = MTN.t("Ok, lets go!");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a></div>\n  </div>");
        } else {
            buf.push('\n  <div class="modal-header">\n    <h3>');
            var __val__ = MTN.t("Start a free 30 day Meetin.gs PRO trial");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</h3>\n  </div>\n  <div class="modal-content trial">');
            if (mode === "meetme") {
                buf.push("\n    <p>");
                var __val__ = MTN.t("Additional Meet Me pages is a Meetin.gs PRO feature. We offer you a free 30 day trial including multiple Meet Me pages and other great PRO features. Would you like to start your free trial now?");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</p>");
            } else if (mode === "lct") {
                buf.push("\n    <p>");
                var __val__ = MTN.t("Google Hangouts, Microsoft Lync and custom options are PRO features. We offer you a free 30 day trial including all live communication tools and other great PRO features. Would you like to start your free trial now?");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</p>");
            } else if (mode === "invite") {
                buf.push("\n    <p>");
                var __val__ = MTN.t("Meetings with more than 6 participants are a PRO feature. We offer you a free 30 day trial including including all the benefits of Meetin.gs PRO.");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</p>");
            } else if (mode === "settings") {
                buf.push("\n    <p>");
                var __val__ = MTN.t("Configuring user rights on a per meeting basis is a PRO feature. We offer you a free 30 day trial including the user rights configuration and other great PRO features. Would you like to start your free trial now?");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</p>\n    <p>");
                var __val__ = MTN.t("Have a good look at our service at your convenience without any commitments. Embrace the full potential offered for increased meeting productivity and let us know what you think.");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</p>");
            }
            buf.push('\n    <div class="pro-trial-upgrade">\n      <div class="star-box">\n        <h3>');
            var __val__ = MTN.t("Free");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</h3>\n        <p>");
            var __val__ = MTN.t("1 month trial");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</p>\n      </div>\n    </div>\n    <h3 class="pro-header">');
            var __val__ = MTN.t("Benefits for upgrading:");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</h3>\n    <ul class="pro-list">\n      <li>');
            var __val__ = MTN.t("Unlimited meeting schedulers");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</li>\n      <li>");
            var __val__ = MTN.t("Expanded live communication tools");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</li>\n      <li>");
            var __val__ = MTN.t("Visual customization and branding");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</li>\n      <li>");
            var __val__ = MTN.t("Unlimited meeting participants");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</li>\n      <li>");
            var __val__ = MTN.t("Unlimited meeting materials");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</li>\n    </ul>\n  </div>\n  <div class="modal-footer"> \n    <div class="buttons right"><a href="#" class="start-trial button blue">');
            var __val__ = MTN.t("Start trial");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</a><a href="#" class="button gray close js_hook_showcase_close">');
            var __val__ = MTN.t("Cancel");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a></div>\n  </div>");
        }
        buf.push("\n</div>");
    }
    return buf.join("");
};

// meetmeClaim.jade compiled template
exports.meetmeClaim = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="meetme-claim" class="m-modal">\n  <div class="modal-header">');
        if (locals.in_event_flow) {
            buf.push("\n    <h3>");
            var __val__ = "Claim your <b>Meet Me</b> page";
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</h3>");
        } else {
            buf.push("\n    <h3>");
            var __val__ = MTN.t("Do you want to claim a %(B$Meet Me%) page?");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</h3>");
        }
        buf.push('\n  </div>\n  <div class="modal-content">\n    <div class="url-container"></div>');
        if (locals.in_event_flow) {
            buf.push('\n    <p class="explanation">');
            var __val__ = MTN.t("You are about to register for matchmaking. First select and claim your personal URL above. Next we'll take you to create and customize your own %(B$Meet Me%) page for the event. It enables people to use a handy scheduler to easily propose meetings with you. Later you will also be able to create additional schedulers for your personal use.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>");
        } else {
            buf.push('\n    <p class="explanation">');
            var __val__ = MTN.t("%(B$Meet Me%) page is your private or public meeting scheduler page through which other people can propose meetings with you.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>");
        }
        buf.push('\n  </div>\n  <div class="modal-footer">');
        if (!locals.in_event_flow) {
            buf.push('\n    <div class="buttons left">\n      <p><a href="#" class="underline skip">');
            var __val__ = MTN.t("Skip");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a></p>\n    </div>");
        }
        buf.push('\n    <div class="buttons right"><a href="#" class="button blue save">');
        var __val__ = MTN.t("Save & continue");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// meetmeTypeSelector.jade compiled template
exports.meetmeTypeSelector = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="meetme-type-selector" class="m-modal">\n  <div class="modal-header">\n    <h3>');
        var __val__ = MTN.t("Select icon");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3>\n  </div>\n  <div class="modal-content">');
        for (var i = 0; i < app.meetme_types.length; ++i) {
            {
                if (matchmaker.meeting_type == i || !matchmaker.meeting_type && i === 0) {
                    buf.push("<i");
                    buf.push(attrs({
                        "data-tooltip-text": "e.g. " + app.meetme_types[i].name,
                        "data-type-id": i,
                        "class": "type-icon selected js_tooltip " + app.meetme_types[i].icon_class
                    }, {
                        "data-tooltip-text": true,
                        "class": true,
                        "data-type-id": true
                    }));
                    buf.push("></i>");
                } else {
                    buf.push("<i");
                    buf.push(attrs({
                        "data-tooltip-text": "e.g. " + app.meetme_types[i].name,
                        "data-type-id": i,
                        "class": "type-icon js_tooltip " + app.meetme_types[i].icon_class
                    }, {
                        "data-tooltip-text": true,
                        "class": true,
                        "data-type-id": true
                    }));
                    buf.push("></i>");
                }
            }
        }
        buf.push('\n  </div><a href="#" class="close-modal js_hook_showcase_close"><i class="ico-cross"></i></a>\n</div>');
    }
    return buf.join("");
};

// meetingLctPicker.jade compiled template
exports.meetingLctPicker = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="lct-picker" class="m-modal">\n  <div class="modal-header">\n    <h3>');
        var __val__ = MTN.t("Live communication");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3>\n  </div>\n  <div class="modal-content">\n    <p>');
        var __val__ = MTN.t("Choose the live communication tool for this meeting.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</p>\n    <p>");
        var __val__ = MTN.t("15 minutes before the meeting participants will receive a notification containing instructions and a link to join the meeting remotely.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n    <div class="lctools"><a href="#" data-tool-name="skype" class="tool skype"><i class="ico-skype"></i>');
        var __val__ = MTN.t("Skype call");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a><a href="#" data-tool-name="teleconf" class="tool teleconf"><i class="ico-teleconf"></i>');
        var __val__ = MTN.t("Teleconference");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a><a href="#" data-tool-name="hangout" class="tool hangout"><i class="ico-hangout"></i>Google Hangouts');
        if (!user.is_pro) {
            buf.push('<span class="pro"></span>');
        }
        buf.push('</a><a href="#" data-tool-name="lync" class="tool lync"><i class="ico-lync"></i>Microsoft Lync');
        if (!user.is_pro) {
            buf.push('<span class="pro"></span>');
        }
        buf.push('</a><a href="#" data-tool-name="custom" class="tool custom"><i class="ico-custom"></i>');
        var __val__ = MTN.t("Custom Tool");
        buf.push(null == __val__ ? "" : __val__);
        if (!user.is_pro) {
            buf.push('<span class="pro"></span>');
        }
        buf.push('</a><a href="#" class="tool disable"><i class="ico-cross"></i>');
        var __val__ = MTN.t("Disable");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a></div>\n  </div><a href="#" class="close-modal"><i class="ico-cross"></i></a>\n</div>');
    }
    return buf.join("");
};

// youtubeEmbed.jade compiled template
exports.youtubeEmbed = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div class="m-modal youtube-embed">\n  <iframe');
        buf.push(attrs({
            id: "ytplayer",
            type: "text/html",
            width: width,
            height: height,
            src: "https://www.youtube.com/embed/" + video_id + "?autoplay=1",
            frameborder: 0
        }, {
            type: true,
            width: true,
            height: true,
            src: true,
            frameborder: true
        }));
        buf.push('></iframe><a href="#" class="js_hook_showcase_close close-modal"><i class="ico-cross"></i></a>\n</div>');
    }
    return buf.join("");
};

// userSettingsTimezone.jade compiled template
exports.userSettingsTimezone = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="meeting-settings">\n  <!-- Required params:-->\n  <div class="setting-head">\n    <h3 class="setting-title"><i class="icon ico-time"></i>');
        var __val__ = MTN.t("Choose your timezone");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n    </h3>\n    <p class="setting-desc">');
        var __val__ = MTN.t("Setup the timezone you want to use.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n  </div>\n  <div class="setting-content m-form">\n    <p>');
        var __val__ = MTN.t("When you select a new time zone, our service converts all your meeting starting times to match your new time zone setting.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n    <label for="timezone">');
        var __val__ = MTN.t("Time Zone:");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n      <select id="timezone" name="timezone" class="chosen timezone-select">');
        (function() {
            if ("number" == typeof dicole.get_global_variable("meetings_time_zone_data")["choices"].length) {
                for (var $index = 0, $$l = dicole.get_global_variable("meetings_time_zone_data")["choices"].length; $index < $$l; $index++) {
                    var tz = dicole.get_global_variable("meetings_time_zone_data")["choices"][$index];
                    if (user.time_zone == tz) {
                        buf.push("\n        <option");
                        buf.push(attrs({
                            value: tz,
                            selected: "selected"
                        }, {
                            value: true,
                            selected: true
                        }));
                        buf.push(">");
                        var __val__ = dicole.get_global_variable("meetings_time_zone_data")["data"][tz].readable_name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    } else {
                        buf.push("\n        <option");
                        buf.push(attrs({
                            value: tz
                        }, {
                            value: true
                        }));
                        buf.push(">");
                        var __val__ = dicole.get_global_variable("meetings_time_zone_data")["data"][tz].readable_name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    }
                }
            } else {
                var $$l = 0;
                for (var $index in dicole.get_global_variable("meetings_time_zone_data")["choices"]) {
                    $$l++;
                    var tz = dicole.get_global_variable("meetings_time_zone_data")["choices"][$index];
                    if (user.time_zone == tz) {
                        buf.push("\n        <option");
                        buf.push(attrs({
                            value: tz,
                            selected: "selected"
                        }, {
                            value: true,
                            selected: true
                        }));
                        buf.push(">");
                        var __val__ = dicole.get_global_variable("meetings_time_zone_data")["data"][tz].readable_name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    } else {
                        buf.push("\n        <option");
                        buf.push(attrs({
                            value: tz
                        }, {
                            value: true
                        }));
                        buf.push(">");
                        var __val__ = dicole.get_global_variable("meetings_time_zone_data")["data"][tz].readable_name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    }
                }
            }
        }).call(this);
        buf.push('\n      </select></label>\n    <p id="js_timezone_preview">');
        var __val__ = moment().utc().add("seconds", user.time_zone_offset).format("HH:mm dddd");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</p>\n  </div>\n  <div class="setting-footer"><a class="button blue save-timezone"><span class="label">');
        var __val__ = MTN.t("Save");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</span></a></div>\n</div>");
    }
    return buf.join("");
};

// upgradeForm.jade compiled template
exports.upgradeForm = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="upgrade-page" class="m-modal">\n  <div class="modal-header">\n    <h3>');
        var __val__ = MTN.t("Upgrade to Meetin.gs PRO");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3>\n  </div>\n  <div class="modal-content m-form">\n    <div class="section">\n      <ul class="list inside">');
        if (type === "monthly") {
            buf.push("\n        <li>");
            var __val__ = MTN.t("You are subscribing to Meetin.gs PRO monthly plan.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</li>");
        } else {
            buf.push("\n        <li>");
            var __val__ = MTN.t("You are subscribing to Meetin.gs PRO yearly plan.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</li>");
        }
        buf.push("\n        <li>");
        var __val__ = MTN.t("Subscription will be renewed automatically at the end of each billing cycle.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</li>\n        <li>");
        var __val__ = MTN.t("You can unsubscribe any time during the billing cycle.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</li>\n        <li>");
        var __val__ = MTN.t("We support all major credit cards. All transactions are secure and encrypted.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</li>\n      </ul>\n    </div>");
        if (!user || !user.id) {
            buf.push('\n    <div class="section">\n      <h4 class="modal-sub-header">');
            var __val__ = MTN.t("New Account");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</h4>\n      <div class="form-row">\n        <label for="cc-email" class="inline required">');
            var __val__ = MTN.t("Email address");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</label>\n        <div class="field-wrap">\n          <input type="email" name="email" placeholder="" required="required" id="cc-email"/>\n        </div>\n      </div>\n    </div>');
        }
        buf.push('\n    <div class="section">\n      <h4 class="modal-sub-header">');
        var __val__ = MTN.t("Credit Card");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h4>\n      <div class="form-row">\n        <label for="cc-name" class="inline required">');
        var __val__ = MTN.t("Name on Card");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</label>\n        <div class="field-wrap">\n          <input');
        buf.push(attrs({
            type: "text",
            name: "name",
            placeholder: "",
            value: user && user.name ? user.name : "",
            required: true,
            id: "cc-name"
        }, {
            type: true,
            name: true,
            placeholder: true,
            value: true,
            required: true
        }));
        buf.push('/>\n        </div>\n      </div>\n      <div class="form-row">\n        <label for="cc-num" class="inline required cc-number-wrap">');
        var __val__ = MTN.t("Card number");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</label>\n        <div class="field-wrap card">\n          <input type="text" placeholder="•••• •••• •••• ••••" autocompletetype="cc-number" required="required" id="cc-num" class="mid payment-input"/>\n        </div>\n      </div>\n      <div class="form-row">\n        <label for="cc-exp" class="inline required">');
        var __val__ = MTN.t("Expiry Date");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</label>\n        <div class="field-wrap">\n          <input type="text" placeholder="MM / YY" autocompletetype="cc-exp" required="required" id="cc-exp" class="small payment-input"/>\n        </div>\n      </div>\n      <div class="form-row">\n        <label for="cc-cvc" class="inline required">');
        var __val__ = MTN.t("Security Code (CVC)");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</label>\n        <div class="field-wrap">\n          <input type="text" placeholder="CVC" autocompletetype="cc-cvc" required="required" id="cc-cvc" class="smaller payment-input"/>\n        </div>\n      </div>\n    </div>\n    <div class="section">\n      <h4 class="modal-sub-header">');
        var __val__ = MTN.t("Company (optional)");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h4>\n      <div class="form-row">\n        <label for="cc-company">');
        var __val__ = MTN.t("Company Name");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</label>\n        <div class="field-wrap">\n          <input type="text" name="company" placeholder="" id="cc-company"/>\n        </div>\n      </div>\n      <div class="form-row checkbox">\n        <input type="checkbox" name="cc-vat-check" id="cc-vat-check"/>\n        <label for="cc-vat-check">');
        var __val__ = MTN.t("I have VAT number (Value Added Tax)");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</label>\n      </div>\n      <div class="form-row hidden js-vat-wrap">\n        <label for="cc-vat">');
        var __val__ = MTN.t("VAT-ID");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</label>\n        <div class="field-wrap">\n          <input type="text" name="vat" placeholder="e.g. FI24332464" id="cc-vat"/>\n        </div>\n      </div>\n    </div>\n    <div class="section">\n      <h4 class="modal-sub-header">');
        var __val__ = MTN.t("Billing Address");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h4>\n      <div class="form-row">\n        <label for="cc-address1" class="required">');
        var __val__ = MTN.t("Street Address");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</label>\n        <div class="field-wrap">\n          <input type="text" name="address1" placeholder="" required="required" id="cc-address1"/>\n        </div>\n      </div>\n      <div class="form-row no-label">\n        <div class="field-wrap">\n          <input type="text" name="address2" placeholder="" required="required" id="cc-address2"/>\n        </div>\n      </div>\n      <div class="form-row">\n        <label for="cc-city" class="required">');
        var __val__ = MTN.t("City");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</label>\n        <div class="field-wrap">\n          <input type="text" name="city" placeholder="" required="required" id="cc-city"/>\n        </div>\n      </div>\n      <div class="form-row">\n        <label for="cc-zip" class="required">');
        var __val__ = MTN.t("Postal code");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</label>\n        <div class="field-wrap">\n          <input type="text" name="zip" placeholder="" required="required" id="cc-zip" class="small"/>\n        </div>\n      </div>\n      <div class="form-row">\n        <label for="cc-country" class="required">');
        var __val__ = MTN.t("Country");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</label>\n        <select");
        buf.push(attrs({
            name: "contry",
            "data-placeholder": MTN.t("Select country"),
            required: true,
            id: "cc-country",
            "class": "modified"
        }, {
            name: true,
            "data-placeholder": false,
            required: false
        }));
        buf.push('>\n          <option value=""></option>');
        (function() {
            if ("number" == typeof app.country_list.length) {
                for (var $index = 0, $$l = app.country_list.length; $index < $$l; $index++) {
                    var country = app.country_list[$index];
                    if (user && typeof user.presumed_country_code === "string" && country.code.toLowerCase() === user.presumed_country_code.toLowerCase()) {
                        buf.push("\n          <option");
                        buf.push(attrs({
                            value: country.code,
                            selected: "selected"
                        }, {
                            value: true,
                            selected: true
                        }));
                        buf.push(">");
                        var __val__ = country.name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    } else {
                        buf.push("\n          <option");
                        buf.push(attrs({
                            value: country.code
                        }, {
                            value: true
                        }));
                        buf.push(">");
                        var __val__ = country.name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    }
                }
            } else {
                var $$l = 0;
                for (var $index in app.country_list) {
                    $$l++;
                    var country = app.country_list[$index];
                    if (user && typeof user.presumed_country_code === "string" && country.code.toLowerCase() === user.presumed_country_code.toLowerCase()) {
                        buf.push("\n          <option");
                        buf.push(attrs({
                            value: country.code,
                            selected: "selected"
                        }, {
                            value: true,
                            selected: true
                        }));
                        buf.push(">");
                        var __val__ = country.name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    } else {
                        buf.push("\n          <option");
                        buf.push(attrs({
                            value: country.code
                        }, {
                            value: true
                        }));
                        buf.push(">");
                        var __val__ = country.name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    }
                }
            }
        }).call(this);
        buf.push('\n        </select>\n      </div>\n    </div>\n    <div class="section price-container">\n      <div class="form-row">\n        <label for="cc-coupon" class="ignored-field">');
        var __val__ = MTN.t("Promotional code");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</label>\n        <div class="field-wrap">\n          <input');
        buf.push(attrs({
            type: "text",
            name: "cc-coupon",
            placeholder: "",
            value: preset_coupon,
            id: "cc-coupon"
        }, {
            type: true,
            name: true,
            placeholder: true,
            value: true
        }));
        buf.push('/>\n        </div>\n      </div>\n      <div class="price-box">');
        if (type === "monthly") {
            buf.push('\n        <p id="cc-billing-period">');
            var __val__ = MTN.t("You will be billed monthly:");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</p>\n        <p id="cc-price">$12</p>');
        } else {
            buf.push('\n        <p id="billing-period">');
            var __val__ = MTN.t("You will be billed yearly:");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</p>\n        <p id="cc-price">$129</p>');
        }
        buf.push('\n        <p id="cc-reverse-tax" style="display:none;">');
        var __val__ = MTN.t("(reverse tax applies)");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n      </div>\n      <div id="cc-errors"></div>\n      <div id="cc-vat-id-error" style="display:none;">\n        <p class="error-message">');
        var __val__ = MTN.t("Unfortunately due to recent changes in EU VAT legislation, purchasing without a valid VAT ID is temporarily disabled for your country.");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</p>\n      </div>\n    </div><a id="cc-submit" class="button blue disabled pay-now"><span class="label">');
        var __val__ = MTN.t("Pay now");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</span></a>\n  </div>\n</div>");
    }
    return buf.join("");
};

// userSettingsTimeline.jade compiled template
exports.userSettingsTimeline = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div class="setting-head">\n  <h3 class="setting-title"><i class="icon ico-timeline"></i>');
        var __val__ = MTN.t("Timeline settings");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n  </h3>\n  <p class="setting-desc">');
        var __val__ = MTN.t("Manage which of your calendars are shown on the timeline.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n</div>\n<div class="setting-content">\n  <div class="sources m-form">');
        if (_.size(sources)) {
            (function() {
                if ("number" == typeof sources.length) {
                    for (var $index = 0, $$l = sources.length; $index < $$l; $index++) {
                        var source = sources[$index];
                        buf.push('\n    <div class="setting-section">');
                        (function() {
                            if ("number" == typeof source.length) {
                                for (var index = 0, $$l = source.length; index < $$l; index++) {
                                    var suggestion = source[index];
                                    if (index === 0) {
                                        buf.push('\n      <h3 class="setting-sub-title">');
                                        var __val__ = suggestion.container_name;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</h3>");
                                    }
                                    buf.push('\n      <label class="slider"><span class="slider-text">');
                                    var __val__ = suggestion.name;
                                    buf.push(escape(null == __val__ ? "" : __val__));
                                    buf.push("</span><span");
                                    buf.push(attrs({
                                        "data-setting": suggestion.uid,
                                        "class": "js_form_slider_button" + " " + "slider-button" + " " + (suggestion.enabled ? "on-position" : "off-position")
                                    }, {
                                        "class": true,
                                        "data-setting": true
                                    }));
                                    buf.push("></span></label>");
                                }
                            } else {
                                var $$l = 0;
                                for (var index in source) {
                                    $$l++;
                                    var suggestion = source[index];
                                    if (index === 0) {
                                        buf.push('\n      <h3 class="setting-sub-title">');
                                        var __val__ = suggestion.container_name;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</h3>");
                                    }
                                    buf.push('\n      <label class="slider"><span class="slider-text">');
                                    var __val__ = suggestion.name;
                                    buf.push(escape(null == __val__ ? "" : __val__));
                                    buf.push("</span><span");
                                    buf.push(attrs({
                                        "data-setting": suggestion.uid,
                                        "class": "js_form_slider_button" + " " + "slider-button" + " " + (suggestion.enabled ? "on-position" : "off-position")
                                    }, {
                                        "class": true,
                                        "data-setting": true
                                    }));
                                    buf.push("></span></label>");
                                }
                            }
                        }).call(this);
                        buf.push("\n    </div>");
                    }
                } else {
                    var $$l = 0;
                    for (var $index in sources) {
                        $$l++;
                        var source = sources[$index];
                        buf.push('\n    <div class="setting-section">');
                        (function() {
                            if ("number" == typeof source.length) {
                                for (var index = 0, $$l = source.length; index < $$l; index++) {
                                    var suggestion = source[index];
                                    if (index === 0) {
                                        buf.push('\n      <h3 class="setting-sub-title">');
                                        var __val__ = suggestion.container_name;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</h3>");
                                    }
                                    buf.push('\n      <label class="slider"><span class="slider-text">');
                                    var __val__ = suggestion.name;
                                    buf.push(escape(null == __val__ ? "" : __val__));
                                    buf.push("</span><span");
                                    buf.push(attrs({
                                        "data-setting": suggestion.uid,
                                        "class": "js_form_slider_button" + " " + "slider-button" + " " + (suggestion.enabled ? "on-position" : "off-position")
                                    }, {
                                        "class": true,
                                        "data-setting": true
                                    }));
                                    buf.push("></span></label>");
                                }
                            } else {
                                var $$l = 0;
                                for (var index in source) {
                                    $$l++;
                                    var suggestion = source[index];
                                    if (index === 0) {
                                        buf.push('\n      <h3 class="setting-sub-title">');
                                        var __val__ = suggestion.container_name;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</h3>");
                                    }
                                    buf.push('\n      <label class="slider"><span class="slider-text">');
                                    var __val__ = suggestion.name;
                                    buf.push(escape(null == __val__ ? "" : __val__));
                                    buf.push("</span><span");
                                    buf.push(attrs({
                                        "data-setting": suggestion.uid,
                                        "class": "js_form_slider_button" + " " + "slider-button" + " " + (suggestion.enabled ? "on-position" : "off-position")
                                    }, {
                                        "class": true,
                                        "data-setting": true
                                    }));
                                    buf.push("></span></label>");
                                }
                            }
                        }).call(this);
                        buf.push("\n    </div>");
                    }
                }
            }).call(this);
        } else {
            buf.push("\n    <p>");
            var __val__ = MTN.t("You have no calendars connected with your account. Connect your third-party accounts or devices to import your calendar events to your Meeting Timeline.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</p>\n    <p><a href="/meetings/user/settings/calendar" class="button blue">');
            var __val__ = MTN.t("Calendar integration");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a></p>");
        }
        buf.push("\n  </div>\n</div>");
        if (_.size(sources)) {
            buf.push('\n<div class="setting-footer"><a href="#" class="button blue save-timeline"><span class="label">');
            var __val__ = MTN.t("Save");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</span></a></div>");
        }
    }
    return buf.join("");
};

// upgradeSuccess.jade compiled template
exports.upgradeSuccess = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="upgrade-page" class="m-modal">\n  <div class="modal-header">\n    <h3>');
        var __val__ = MTN.t("Thank you, you're awesome!");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3>\n  </div>\n  <div class="modal-content">\n    <p>');
        var __val__ = MTN.t("Thank you for upgrading to Meetin.gs PRO. We really appreciate it!");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</p>\n    <p>");
        var __val__ = MTN.t("We have sent you an email with a login link and further instructions and tips on how to get the most out of your PRO subscription.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</p>\n    <p>");
        var __val__ = MTN.t("You will also get a receipt of your transaction in a separate email.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n  </div>\n  <div class="modal-footer">\n    <div class="buttons right">');
        if (app.auth.user) {
            buf.push('<a href="/meetings/summary" class="button blue"><span class="label">');
            var __val__ = MTN.t("Continue");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</span></a>");
        } else {
            buf.push('<a href="/meetings/login" class="button blue"><span class="label">');
            var __val__ = MTN.t("Log in");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</span></a>");
        }
        buf.push("\n    </div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// agentBookingPublicThanks.jade compiled template
exports.agentBookingPublicThanks = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push("\n<p>");
        var __val__ = "Varaus on suoritettu onnistuneesti." || MTN.t("The booking has been completed succesfully.");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push("</p>");
    }
    return buf.join("");
};

// userSettingsCover.jade compiled template
exports.userSettingsCover = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div style="border:none;" class="setting-head">\n  <h3 class="setting-title">');
        var __val__ = MTN.t("Manage your settings");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3>\n</div>\n<div class="two-column-settings">\n  <div class="modal-content">\n    <div class="horizontal-divider"></div>\n    <div class="vertical-divider"></div>\n    <div class="vertical-divider second"></div>');
        if (!dicole.get_global_variable("meetings_user_is_visitor")) {
            buf.push('\n    <div class="vertical-divider third"></div>');
        }
        buf.push('\n    <div class="settings">\n      <div data-href="/meetings/user/settings/login" class="setting left login midrow"><i class="ico-password"></i>\n        <div class="info">\n          <h3 class="title">');
        var __val__ = MTN.t("Login methods");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</h3>\n          <p>");
        var __val__ = MTN.t("Setup login with Google, Facebook or password.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</p>\n        </div>\n      </div>");
        if (!dicole.get_global_variable("meetings_user_is_visitor")) {
            buf.push('\n      <div data-href="/meetings/user/settings/calendar" class="setting right calendar midrow"><i class="ico-calendar"></i>\n        <div class="info">\n          <h3 class="title">');
            var __val__ = MTN.t("Calendar integration");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</h3>\n          <p>");
            var __val__ = MTN.t("Integrate your calendar with Meetin.gs.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>\n        </div>\n      </div>");
        }
        if (!dicole.get_global_variable("meetings_user_is_visitor")) {
            buf.push('\n      <div data-href="/meetings/user/settings/timeline" class="setting left timeline midrow"><i class="ico-timeline"></i>\n        <div class="info">\n          <h3 class="title">');
            var __val__ = MTN.t("Timeline");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</h3>\n          <p>");
            var __val__ = MTN.t("Manage which of your calendars are shown on the timeline.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>\n        </div>\n      </div>");
        }
        buf.push('\n      <div data-href="/meetings/user/settings/regional" class="setting right timezone midrow"><i class="ico-language"></i>\n        <div class="info">\n          <h3 class="title">');
        var __val__ = MTN.t("Regional settings");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</h3>\n          <p>");
        var __val__ = MTN.t("Change your time zone and language.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</p>\n        </div>\n      </div>");
        if (!dicole.get_global_variable("meetings_user_is_visitor")) {
            buf.push('\n      <div data-href="/meetings/user/settings/branding" class="setting left branding midrow"><i class="ico-brush"></i>\n        <div class="info">\n          <h3 class="title">');
            var __val__ = MTN.t("Branding");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</h3>\n          <p>");
            var __val__ = MTN.t("Customize the look and feel.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>\n        </div>\n      </div>");
        }
        buf.push('\n      <div data-href="/meetings/user/settings/account" class="setting right midrow account"><i class="ico-pro"></i>\n        <div class="info">\n          <h3 class="title">');
        var __val__ = MTN.t("Account");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</h3>\n          <p>");
        var __val__ = MTN.t("Manage your account & subscription.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</p>\n        </div>\n      </div>\n    </div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// wizardApps.jade compiled template
exports.wizardApps = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="profile-apps">\n  <h1>');
        var __val__ = MTN.t("Get the most out of your Meetin.gs");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h1>\n  <div style="padding:0 100px;" class="apps">\n    <div class="app ios mr"><span class="logo"></span>\n      <p>');
        var __val__ = MTN.t("Sync your mobile calendar and contacts.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p><a href="http://bit.ly/swipetomeet-ios" target="_blank" class="button gray">');
        var __val__ = MTN.t("Download for iPhone");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a>\n    </div>\n    <div class="app android mr"><span class="logo"></span>\n      <p>');
        var __val__ = MTN.t("Keep track of your meetings while on the move.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p><a href="http://bit.ly/swipetomeet-android" target="_blank" class="button gray">');
        var __val__ = MTN.t("Download for Android");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a>\n    </div>\n    <div class="app chrome"><span class="logo"></span>\n      <p>');
        var __val__ = MTN.t("Organize meetings from Gmail, LinkedIn, Highrise and more.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p><a href="http://chrome.meetin.gs/" target="_blank" class="button gray">');
        var __val__ = MTN.t("Install Chrome Extension");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a>\n    </div>\n  </div>\n  <div class="continue"><a href="#" class="next-step button blue">');
        var __val__ = MTN.t("Continue");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></div>\n</div>");
    }
    return buf.join("");
};

// meetingSettingsEmail.jade compiled template
exports.meetingSettingsEmail = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div class="m-modal">\n  <div class="modal-header back-button">\n    <h3>');
        var __val__ = MTN.t("Email settings");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3><i class="ico-leftarrow back"></i>\n  </div>\n  <div class="modal-content m-form">\n    <p>');
        var __val__ = MTN.t("Email notification settings for the current meeting:");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n    <p class="slider"><span');
        buf.push(attrs({
            "data-setting": "start_reminder",
            "class": "js_form_slider_button" + " " + "slider-button" + " " + (start_reminder ? "on-position" : "off-position")
        }, {
            "class": true,
            "data-setting": true
        }));
        buf.push("></span>");
        var __val__ = MTN.t("Meeting start reminder");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n    </p>\n    <p class="slider"><span');
        buf.push(attrs({
            "data-setting": "participant_digest",
            "class": "js_form_slider_button" + " " + "slider-button" + " " + (participant_digest ? "on-position" : "off-position")
        }, {
            "class": true,
            "data-setting": true
        }));
        buf.push("></span>");
        var __val__ = MTN.t("Participant digest");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("\n    </p>\n    <div");
        buf.push(attrs({
            style: participant_digest ? "" : "display:none",
            "class": "js_email_subchoices"
        }, {
            style: true
        }));
        buf.push('>\n      <p class="slider"><span');
        buf.push(attrs({
            "data-setting": "participant_digest_new_participant",
            "class": "js_form_slider_button" + " " + "slider-button" + " " + (participant_digest_new_participant ? "on-position" : "off-position")
        }, {
            "class": true,
            "data-setting": true
        }));
        buf.push("></span>");
        var __val__ = MTN.t("New participant notification");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n      </p>\n      <p class="slider"><span');
        buf.push(attrs({
            "data-setting": "participant_digest_material",
            "class": "js_form_slider_button" + " " + "slider-button" + " " + (participant_digest_material ? "on-position" : "off-position")
        }, {
            "class": true,
            "data-setting": true
        }));
        buf.push("></span>");
        var __val__ = MTN.t("New material notification");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n      </p>\n      <p class="slider"><span');
        buf.push(attrs({
            "data-setting": "participant_digest_comments",
            "class": "js_form_slider_button" + " " + "slider-button" + " " + (participant_digest_comments ? "on-position" : "off-position")
        }, {
            "class": true,
            "data-setting": true
        }));
        buf.push("></span>");
        var __val__ = MTN.t("New comment notification");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n      </p>\n    </div>\n  </div>\n  <div class="modal-footer">\n    <div class="buttons right"><a class="button blue save">');
        var __val__ = MTN.t("Save");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a></div>\n  </div><a href="#" class="close-modal"><i class="ico-cross"></i></a>\n</div>');
    }
    return buf.join("");
};

// agentBookingThanks.jade compiled template
exports.agentBookingThanks = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push("\n<p>");
        var __val__ = "Varaus on suoritettu onnistuneesti." || MTN.t("The booking has been completed succesfully.");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push("</p>");
    }
    return buf.join("");
};

// agentAdminUsers.jade compiled template
exports.agentAdminUsers = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div class="input-row"><span class="input-label">Email</span>\n  <input');
        buf.push(attrs({
            "x-data-object-field": "email",
            size: 40,
            value: typeof admin_user == "undefined" ? undefined : admin_user.email,
            disabled: typeof admin_user == "undefined" ? undefined : "disabled",
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            size: true,
            value: true,
            disabled: true
        }));
        buf.push('/>\n</div>\n<div class="input-row"><span class="input-label">AD tunnus</span>\n  <input');
        buf.push(attrs({
            "x-data-object-field": "ad_account",
            size: 40,
            value: typeof admin_user == "undefined" ? undefined : admin_user.ad_account,
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            size: true,
            value: true
        }));
        buf.push('/>\n</div>\n<div class="input-row"><span class="input-label">Nimi</span>\n  <input');
        buf.push(attrs({
            "x-data-object-field": "name",
            size: 40,
            value: typeof admin_user == "undefined" ? undefined : admin_user.name,
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            size: true,
            value: true
        }));
        buf.push('/>\n</div>\n<div class="input-row"><span class="input-label">Titteli</span>\n  <input');
        buf.push(attrs({
            "x-data-object-field": "title",
            size: 40,
            value: typeof admin_user == "undefined" ? undefined : admin_user.title,
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            size: true,
            value: true
        }));
        buf.push('/>\n</div>\n<div class="input-row"><span class="input-label">Tiimi</span>\n  <input');
        buf.push(attrs({
            "x-data-object-field": "team",
            size: 40,
            value: typeof admin_user == "undefined" ? undefined : admin_user.team,
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            size: true,
            value: true
        }));
        buf.push('/>\n</div>\n<div class="input-row"><span class="input-label">Esimies</span>\n  <select x-data-object-field="supervisor" class="object-field">\n    <option value="">Ei</option>');
        (function() {
            if ("number" == typeof users.length) {
                for (var $index = 0, $$l = users.length; $index < $$l; $index++) {
                    var u = users[$index];
                    buf.push("\n    <option");
                    buf.push(attrs({
                        value: u.email,
                        selected: u.email == (typeof admin_user == "undefined" ? undefined : admin_user.supervisor) ? "selected" : undefined
                    }, {
                        value: true,
                        selected: true
                    }));
                    buf.push(">");
                    var __val__ = u.email;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</option>");
                }
            } else {
                var $$l = 0;
                for (var $index in users) {
                    $$l++;
                    var u = users[$index];
                    buf.push("\n    <option");
                    buf.push(attrs({
                        value: u.email,
                        selected: u.email == (typeof admin_user == "undefined" ? undefined : admin_user.supervisor) ? "selected" : undefined
                    }, {
                        value: true,
                        selected: true
                    }));
                    buf.push(">");
                    var __val__ = u.email;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</option>");
                }
            }
        }).call(this);
        buf.push('\n  </select>\n</div>\n<div class="input-row"><span class="input-label">Puhelinnumero</span>\n  <input');
        buf.push(attrs({
            "x-data-object-field": "phone",
            size: 40,
            value: typeof admin_user == "undefined" ? undefined : admin_user.phone,
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            size: true,
            value: true
        }));
        buf.push('/>\n</div>\n<div class="input-row">\n  <div class="input-label-row"><span>Käyttöoikeudet:</span></div>\n</div>\n<div class="input-row"><span class="input-label">Varaaminen</span>\n  <select x-data-object-field="booking_rights" class="object-field">\n    <option value="">Ei</option>\n    <option');
        buf.push(attrs({
            value: selected_area,
            selected: selected_area == (typeof admin_user == "undefined" ? undefined : admin_user.booking_rights) ? "selected" : undefined
        }, {
            value: true,
            selected: true
        }));
        buf.push(">");
        var __val__ = selected_area_name;
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push("</option>\n    <option");
        buf.push(attrs({
            value: "_all",
            selected: "_all" == (typeof admin_user == "undefined" ? undefined : admin_user.booking_rights) ? "selected" : undefined
        }, {
            value: true,
            selected: true
        }));
        buf.push('>Kaikki yhtiöt</option>\n  </select>\n</div>\n<div class="input-row"><span class="input-label">Varausten muokkaaminen</span>\n  <select x-data-object-field="manage_rights" class="object-field">\n    <option value="">Ei</option>\n    <option');
        buf.push(attrs({
            value: selected_area,
            selected: selected_area == (typeof admin_user == "undefined" ? undefined : admin_user.manage_rights) ? "selected" : undefined
        }, {
            value: true,
            selected: true
        }));
        buf.push(">");
        var __val__ = selected_area_name;
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push("</option>\n    <option");
        buf.push(attrs({
            value: "_all",
            selected: "_all" == (typeof admin_user == "undefined" ? undefined : admin_user.manage_rights) ? "selected" : undefined
        }, {
            value: true,
            selected: true
        }));
        buf.push('>Kaikki yhtiöt</option>\n  </select>\n</div>\n<div class="input-row"><span class="input-label">Käyttäjähallinta</span>\n  <select');
        buf.push(attrs({
            "x-data-object-field": "admin_rights",
            disabled: typeof admin_user == "undefined" ? undefined : admin_user.admin_rights == "_all" && areas != "_all" ? "disabled" : undefined,
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            disabled: true
        }));
        buf.push('>\n    <option value="">Ei</option>\n    <option');
        buf.push(attrs({
            value: selected_area,
            selected: selected_area == (typeof admin_user == "undefined" ? undefined : admin_user.admin_rights) ? "selected" : undefined
        }, {
            value: true,
            selected: true
        }));
        buf.push(">");
        var __val__ = selected_area_name;
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push("</option>");
        if (areas == "_all" || typeof admin_user != "undefined" && admin_user.admin_rights == "_all") {
            {
                buf.push("\n    <option");
                buf.push(attrs({
                    value: "_all",
                    selected: "_all" == (typeof admin_user == "undefined" ? undefined : admin_user.admin_rights) ? "selected" : undefined
                }, {
                    value: true,
                    selected: true
                }));
                buf.push(">Kaikki yhtiöt</option>");
            }
        }
        buf.push('\n  </select>\n</div>\n<div class="input-row"><span class="input-label">Käyttö sisäverkon ulkopuolelta</span>\n  <select');
        buf.push(attrs({
            "x-data-object-field": "access_outside_intranet",
            disabled: areas != "_all" ? "disabled" : undefined,
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            disabled: true
        }));
        buf.push('>\n    <option value="">Ei</option>\n    <option');
        buf.push(attrs({
            value: "allow",
            selected: "allow" == (typeof admin_user == "undefined" ? undefined : admin_user.access_outside_intranet) ? "selected" : undefined
        }, {
            value: true,
            selected: true
        }));
        buf.push(">Kyllä</option>\n  </select>\n</div>");
        if (typeof admin_user !== "undefined") {
            {
                buf.push('\n<div class="input-row">\n  <div class="input-label-row"><span>Erityiset muutostyöt:</span></div>\n</div>\n<div class="input-row"><span class="input-label">Vaihtunut Email</span>\n  <input');
                buf.push(attrs({
                    "x-data-object-field": "changed_email",
                    size: 40,
                    value: typeof admin_user == "undefined" ? undefined : admin_user.changed_email,
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    size: true,
                    value: true
                }));
                buf.push("/>\n</div>");
            }
        }
    }
    return buf.join("");
};

// meetingLctBar.jade compiled template
exports.meetingLctBar = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="meeting-conferencing">');
        if (online_conferencing_option === "skype") {
            if (skype_is_organizer) {
                buf.push('<a id="join-skype-call-button" href="skype:" class="button blue">');
                var __val__ = MTN.t("Open Skype to receive calls");
                buf.push(null == __val__ ? "" : __val__);
                buf.push('<span class="double-arrow-right"></span></a>');
            } else {
                buf.push("<a");
                buf.push(attrs({
                    id: "join-skype-call-button",
                    href: skype_uri,
                    "class": "button" + " " + "blue"
                }, {
                    href: true
                }));
                buf.push(">");
                var __val__ = MTN.t("Join Skype conference call");
                buf.push(null == __val__ ? "" : __val__);
                buf.push('<span class="double-arrow-right"></span></a>');
            }
            buf.push('\n  <p class="explanation">');
            var __val__ = MTN.t("You need to have %(L$Skype 5.0%) or greater installed.", {
                L: {
                    href: "http://www.skype.com/"
                }
            });
            buf.push(null == __val__ ? "" : __val__);
            if (skype_is_organizer) {
                var __val__ = MTN.t('Make sure that under "Skype > Preferences > Privacy" you allow calls from anyone.');
                buf.push(null == __val__ ? "" : __val__);
            }
            buf.push("</p>");
        }
        if (online_conferencing_option === "teleconf") {
            buf.push("<a");
            buf.push(attrs({
                href: teleconf_uri,
                "class": "button" + " " + "blue"
            }, {
                href: true
            }));
            buf.push(">");
            var __val__ = MTN.t("Join the teleconference");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</a>\n  <p class="explanation">');
            var __val__ = MTN.t("Is the button not working? Call manually") + " " + online_conferencing_data.teleconf_number + " ";
            buf.push(null == __val__ ? "" : __val__);
            if (online_conferencing_data.teleconf_pin) {
                var __val__ = MTN.t("with pin %1$s", {
                    params: [ online_conferencing_data.teleconf_pin ]
                });
                buf.push(null == __val__ ? "" : __val__);
            }
            buf.push("</p>");
        }
        if (online_conferencing_option === "hangout") {
            if (locals.hangout_uri) {
                buf.push("<a");
                buf.push(attrs({
                    href: hangout_uri,
                    target: "_blank",
                    "class": "button" + " " + "blue"
                }, {
                    href: true,
                    target: true
                }));
                buf.push(">");
                var __val__ = MTN.t("Open the Hangout");
                buf.push(null == __val__ ? "" : __val__);
                buf.push('</a>\n  <p class="explanation">');
                var __val__ = MTN.t("This meeting has an active Google Hangout. Click the button above to join.");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</p>");
            } else if (is_manager && hangout_organizer_uri) {
                buf.push("<a");
                buf.push(attrs({
                    href: hangout_organizer_uri,
                    target: "_blank",
                    "class": "button" + " " + "blue"
                }, {
                    href: true,
                    target: true
                }));
                buf.push(">");
                var __val__ = MTN.t("Open the Hangout");
                buf.push(null == __val__ ? "" : __val__);
                buf.push('</a>\n  <p class="explanation">');
                var __val__ = MTN.t("Please open the Hangout to allow participants to join the online conference.");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</p>");
            } else {
                buf.push('\n  <p class="explanation">');
                var __val__ = MTN.t("Please wait while the organizer prepares the hangout.");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</p>");
            }
        }
        if (online_conferencing_option === "lync") {
            buf.push("<a");
            buf.push(attrs({
                href: lync_uri,
                target: "_blank",
                "class": "button" + " " + "blue"
            }, {
                href: true,
                target: true
            }));
            buf.push(">");
            var __val__ = MTN.t("Open Lync");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</a>\n  <p class="explanation">');
            var __val__ = MTN.t("This meeting is using Microsoft Lync. Click the button above to open Lync.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>");
        }
        if (online_conferencing_option === "custom") {
            buf.push("<a");
            buf.push(attrs({
                href: app.helpers.ensureToolUrl(custom_uri),
                target: "_blank",
                "class": "button" + " " + "blue"
            }, {
                href: true,
                target: true
            }));
            buf.push(">");
            var __val__ = "Join " + (online_conferencing_data.custom_name || "conference");
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push('</a>\n  <p class="explanation">');
            var __val__ = _.escape(online_conferencing_data.custom_description) || MTN.t("This meeting is using a custom tool. Click the button above to join.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>");
        }
        buf.push('\n</div>\n<div class="drop-shadow"></div>');
    }
    return buf.join("");
};

// meetmePresetFiles.jade compiled template
exports.meetmePresetFiles = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<h3 class="materials-title">');
        var __val__ = MTN.t("Preset materials");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</h3>");
        if (preset_materials) {
            buf.push('\n<ul id="material-list">');
            (function() {
                if ("number" == typeof preset_materials.length) {
                    for (var $index = 0, $$l = preset_materials.length; $index < $$l; $index++) {
                        var material = preset_materials[$index];
                        buf.push("\n  <!-- TODO: remove button-->\n  <li");
                        buf.push(attrs({
                            "data-id": material.attachment_id,
                            "class": "material"
                        }, {
                            "data-id": true
                        }));
                        buf.push(">");
                        var __val__ = material.name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push('<i class="ico-cross remove-file"></i></li>');
                    }
                } else {
                    var $$l = 0;
                    for (var $index in preset_materials) {
                        $$l++;
                        var material = preset_materials[$index];
                        buf.push("\n  <!-- TODO: remove button-->\n  <li");
                        buf.push(attrs({
                            "data-id": material.attachment_id,
                            "class": "material"
                        }, {
                            "data-id": true
                        }));
                        buf.push(">");
                        var __val__ = material.name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push('<i class="ico-cross remove-file"></i></li>');
                    }
                }
            }).call(this);
            buf.push("\n</ul>");
        }
        buf.push('\n<div id="upload-area"><a id="upload-button" href="#" class="button blue"><i class="ico-add"></i><span class="label text">');
        var __val__ = MTN.t("Add new material");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</span>\n    <input id="fileupload" type="file" name="file"/></a></div>');
    }
    return buf.join("");
};

// notification.jade compiled template
exports.notification = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        if (typeof data === "undefined") return;
        var title = data.meeting.title_value || MTN.t("Untitled meeting");
        var time_string = app.helpers.fullTimeString(created_at * 1e3, app.models.user.get("time_zone_offset"));
        buf.push("<a");
        buf.push(attrs({
            href: "#",
            "data-id": id,
            "class": "notification" + (is_read ? "" : " unread")
        }, {
            href: true,
            "class": true,
            "data-id": true
        }));
        buf.push(">");
        switch (type) {
          case "rsvp":
            buf.push('<i class="ico ico-error"></i>\n  <p class="text">');
            var __val__ = MTN.t("Please respond to the invitation: %1$s", [ title ]);
            buf.push(null == __val__ ? "" : __val__);
            buf.push('<span class="date">');
            var __val__ = time_string;
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("</span></p>");
            break;

          case "invited":
            buf.push('<i class="ico ico-meetings"></i>\n  <p class="text">');
            var __val__ = MTN.t("%1$s invited you to %2$s", [ data.author.name, title ]);
            buf.push(null == __val__ ? "" : __val__);
            buf.push('<span class="date">');
            var __val__ = time_string;
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("</span></p>");
            break;

          case "new_material":
            buf.push("<i");
            buf.push(attrs({
                "class": "ico ico-material_" + data.material.type_class
            }, {
                "class": true
            }));
            buf.push("></i>\n  <!-- It seems in some cases data.author is not defined, so check that-->");
            var author = data && data.author && data.author.name ? data.author.name : MTN.t("somebody");
            buf.push('\n  <p class="text">');
            var __val__ = MTN.t("%1$s added material %2$s in %3$s", [ author, data.material.title, title ]);
            buf.push(null == __val__ ? "" : __val__);
            buf.push('<span class="date">');
            var __val__ = time_string;
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("</span></p>");
            break;

          case "new_participant":
            buf.push('<i class="ico ico-profile"></i>\n  <p class="text">');
            var __val__ = MTN.t("New participant: %1$s in %2$s", [ data.user.name, title ]);
            buf.push(null == __val__ ? "" : __val__);
            buf.push('<span class="date">');
            var __val__ = time_string;
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("</span></p>");
            break;

          case "new_meeting_date":
            buf.push('<i class="ico ico-time"></i>');
            if (data.meeting.begin_epoch) {
                buf.push('\n  <!-- TODO: parse timestamp for user-->\n  <p class="text">');
                var __val__ = MTN.t("Meeting time was changed to %1$s for %2$s", [ app.helpers.fullTimeString(data.meeting.begin_epoch * 1e3, app.models.user.get("time_zone_offset")), title ]);
                buf.push(null == __val__ ? "" : __val__);
                buf.push('<span class="date">');
                var __val__ = time_string;
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</span></p>");
            } else if (data.meeting.begin_epoch == "0") {
                buf.push('\n  <p class="text">');
                var __val__ = MTN.t("Meeting time was removed from %1$s", [ title ]);
                buf.push(null == __val__ ? "" : __val__);
                buf.push('<span class="date">');
                var __val__ = time_string;
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</span></p>");
            }
            break;

          case "new_meeting_location":
            buf.push('<i class="ico ico-location"></i>\n  <p class="text">');
            var __val__ = MTN.t("Meeting location changed to %1$s for %2$s", [ data.meeting.location, title ]);
            buf.push(null == __val__ ? "" : __val__);
            buf.push('<span class="date">');
            var __val__ = time_string;
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("</span></p>");
            break;

          case "new_material_comment":
            buf.push('<i class="ico ico-comment"></i>\n  <p class="text">');
            var __val__ = MTN.t("%1$s commented %2$s in %3$s", [ data.author.name, data.material.title, title ]);
            buf.push(null == __val__ ? "" : __val__);
            buf.push('<span class="date">');
            var __val__ = time_string;
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("</span></p>");
            break;

          case "new_meeting_title":
            buf.push('<i class="ico ico-meetings"></i>\n  <p class="text">');
            var __val__ = MTN.t("%1$s changed the title of %2$s to %3$s", [ data.author.name, data.old_title, title ]);
            buf.push(null == __val__ ? "" : __val__);
            buf.push('<span class="date">');
            var __val__ = time_string;
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("</span></p>");
            break;

          case "decided_meeting_date":
            buf.push('<i class="ico ico-time"></i>');
            if (data.meeting.begin_epoch) {
                buf.push('\n  <!-- TODO: parse timestamp for user-->\n  <p class="text">');
                var __val__ = MTN.t("Meeting time was changed to %1$s", [ app.helpers.fullTimeString(data.meeting.begin_epoch * 1e3, app.models.user.get("time_zone_offset")) ]);
                buf.push(null == __val__ ? "" : __val__);
                buf.push('<span class="date">');
                var __val__ = time_string;
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</span></p>");
            } else if (data.meeting.begin_epoch == "0") {
                buf.push('\n  <p class="text">');
                var __val__ = MTN.t("Meetin time was removed from");
                buf.push(null == __val__ ? "" : __val__);
                buf.push('<span class="date">');
                var __val__ = time_string;
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</span></p>");
            }
            break;

          case "decided_meeting_location":
            buf.push('<i class="ico ico-location"></i>\n  <p class="text">');
            var __val__ = MTN.t("Meeting location was set to %1$s for %2$s", [ data.meeting.location, title ]);
            buf.push(null == __val__ ? "" : __val__);
            buf.push('<span class="date">');
            var __val__ = time_string;
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("</span></p>");
            break;

          case "meetme_request":
            buf.push('<i class="ico ico-meetings"></i>');
            if (data.author.organization.length) {
                buf.push('\n  <p class="text">');
                var __val__ = MTN.t("%1$s from %2$s would like to meet you. Please respond now.", [ data.author.name, data.author.organization ]);
                buf.push(null == __val__ ? "" : __val__);
                buf.push('<span class="date">');
                var __val__ = time_string;
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</span></p>");
            } else {
                buf.push('\n  <p class="text">');
                var __val__ = MTN.t("%1$s would like to meet you. Please respond now.", [ data.author.name ]);
                buf.push(null == __val__ ? "" : __val__);
                buf.push('<span class="date">');
                var __val__ = time_string;
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</span></p>");
            }
            break;

          case "meetme_invited":
            buf.push('<i class="ico ico-meetings"></i>\n  <p class="text">');
            var __val__ = MTN.t("%1$s accepted your request to meet.", [ data.author.name ]);
            buf.push(null == __val__ ? "" : __val__);
            buf.push('<span class="date">');
            var __val__ = time_string;
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("</span></p>");
            break;

          case "meetme_rsvp":
            buf.push('<i class="ico ico-meetings"></i>\n  <p class="text">');
            var __val__ = MTN.t("%1$s accepted your request and wants to double check your RSVP.", [ data.author.name ]);
            buf.push(null == __val__ ? "" : __val__);
            buf.push('<span class="date">');
            var __val__ = time_string;
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("</span></p>");
            break;

          case "new_scheduling_answers_needed":
            buf.push('<i class="ico ico-schedule"></i>\n  <!-- should be ico-swipe-->\n  <p class="text">');
            var __val__ = MTN.t("%1$s is looking for a suitable time for a meeting.", [ data.author.name ]);
            buf.push(null == __val__ ? "" : __val__);
            buf.push('<span class="date">');
            var __val__ = time_string;
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("</span></p>");
            break;

          case "more_scheduling_answers_needed":
            buf.push('<i class="ico ico-schedule"></i>\n  <!-- should be ico-swipe-->\n  <p class="text">');
            var __val__ = MTN.t("We need more input from you to schedule %1$s.", [ title ]);
            buf.push(null == __val__ ? "" : __val__);
            buf.push('<span class="date">');
            var __val__ = time_string;
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("</span></p>");
            break;

          case "scheduling_date_found":
            buf.push('<i class="ico ico-time"></i>\n  <p class="text">');
            var __val__ = MTN.t("Time found for %1$s on %2$s.", [ title, app.helpers.fullTimeString(data.meeting.begin_epoch * 1e3, app.models.user.get("time_zone_offset")) ]);
            buf.push(null == __val__ ? "" : __val__);
            buf.push('<span class="date">');
            var __val__ = time_string;
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("</span></p>");
            break;

          case "scheduling_date_not_found":
            buf.push('<i class="ico ico-time"></i>\n  <p class="text">');
            var __val__ = MTN.t("We were unable to find a suitable time for %1$s.", [ title ]);
            buf.push(null == __val__ ? "" : __val__);
            buf.push('<span class="date">');
            var __val__ = time_string;
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("</span></p>");
            break;

          case "scheduling_is_missing_answers":
            buf.push('<i class="ico ico-profile"></i>\n  <p class="text">');
            var __val__ = MTN.t("Scheduling is stagnant. We are missing responses for %1$s.", [ title ]);
            buf.push(null == __val__ ? "" : __val__);
            buf.push('<span class="date">');
            var __val__ = time_string;
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("</span></p>");
            break;

          default:
            if (window.qbaka) qbaka.report("Unrecognized notification type: " + type);
            break;
        }
        buf.push("</a>");
    }
    return buf.join("");
};

// footer.jade compiled template
exports.footer = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div class="footer">\n  <div class="footer-left">\n    <!-- TODO check if user is pro and add class normal or pro --><span class="logo normal"></span>');
        if (view_type !== "clean") {
            buf.push('\n    <div class="pages">\n      <ul>');
            if (view_type === "ext") {
                buf.push('\n        <li class="first"><a id="user-guide-menu-open" href="#" class="js_meetings_user_guide_menu_open">');
                var __val__ = MTN.t("Getting Started");
                buf.push(null == __val__ ? "" : __val__);
                buf.push('</a></li>\n        <li><a id="website-link" target="_blank" href="http:///www.meetin.gs/#frontpage">');
                var __val__ = MTN.t("Website");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</a></li>");
            } else if (view_type === "matchmaking") {
                buf.push('\n        <li class="first">');
                var __val__ = MTN.t("Powered by %(L$Meetin.gs%)", {
                    L: {
                        href: "http://meetin.gs"
                    }
                });
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</li>");
            } else if (view_type !== "clean") {
                buf.push('\n        <li class="first"><a id="website-link" target="_blank" href="http:///www.meetin.gs/#frontpage">');
                var __val__ = MTN.t("Website");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</a></li>");
            }
            buf.push("\n      </ul>\n    </div>");
        }
        buf.push('\n  </div>\n  <div class="footer-right">');
        if (view_type !== "clean" && view_type !== "matchmaking") {
            buf.push('\n    <div class="contact">\n      <ul>\n        <li class="first"><a id="blog-link" href="http://www.meetin.gs/blog" target="_blank">');
            var __val__ = MTN.t("Blog");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</a></li>\n        <li><a id="gsfn-open" href="http://support.meetin.gs/" target="_blank">');
            var __val__ = MTN.t("Support");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</a></li>\n        <li><a id="facebook-open" href="http://www.facebook.com/pages/Meetings/182909251746386" target="_blank">Facebook</a></li>\n        <li><a id="twiter-open" href="http://twitter.com/meetin_gs/" target="_blank">Twitter</a></li>\n        <li><a href="mailto:info@meetin.gs">');
            var __val__ = MTN.t("Contact");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a></li>\n      </ul>\n    </div>");
        }
        buf.push('\n    <div class="policies">\n      <ul>\n        <li class="first"><a target="_blank" href="http://www.meetin.gs/privacy/">');
        var __val__ = MTN.t("Privacy Policy");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a></li>\n        <li><a target="_blank" href="http://www.meetin.gs/takedown-policy/">');
        var __val__ = MTN.t("Takedown policy");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a></li>\n        <li><a target="_blank" href="http://www.meetin.gs/terms-of-service/">');
        var __val__ = MTN.t("Terms of Service");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></li>\n      </ul>\n    </div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// summaryUpcoming.jade compiled template
exports.summaryUpcoming = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="summary-upcoming" class="tab">\n  <div class="loader"></div>\n  <div class="tab-items">\n    <div id="upcoming-today" class="section"></div>\n    <div id="upcoming-highlights" class="section"></div>\n    <div id="upcoming-scheduling" class="section"></div>\n    <div id="upcoming-this-week" class="section"></div>\n    <div id="upcoming-next-week" class="section"></div>\n    <div id="upcoming-future" class="section"></div>');
        if (!dicole.get_global_variable("meetings_user_is_visitor")) {
            buf.push('\n    <div class="section share-organize">');
            if (google_connected == 0) {
                buf.push('\n      <div class="line vertical"></div>');
            }
            buf.push('\n      <div class="row">\n        <div class="line horizontal1"></div>\n        <div class="badge bl"><i class="ico-add"></i></div><a href="#" class="action create-meeting"><i class="ico-schedule"></i><br/>');
            var __val__ = MTN.t("Organize a new meeting");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</a><a href="#" class="action goto-meetme"><i class="ico-emblem"></i><br/>');
            var __val__ = MTN.t("Share your Meet Me page");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a>\n      </div>\n    </div>");
            if (google_connected == 0) {
                buf.push('\n    <div class="section google-connect">\n      <div class="line vertical"></div>\n      <div class="row">\n        <div class="line horizontal1"></div>\n        <div class="badge bl"><i class="ico-calendar"></i></div><a');
                buf.push(attrs({
                    href: google_connect_url,
                    "class": "action"
                }, {
                    href: true
                }));
                buf.push('><i class="ico-calendar"></i><br/>');
                var __val__ = MTN.t("Connect Google Calendar");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</a>\n      </div>\n    </div>");
            }
        }
        buf.push('\n  </div>\n  <p class="bottom-tip">');
        var __val__ = MTN.t("Looking for %(L$Past meetings%)?", {
            L: {
                href: "#",
                classes: "past"
            }
        });
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</p>\n</div>");
    }
    return buf.join("");
};

// meetingSettings.jade compiled template
exports.meetingSettings = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div class="two-column-settings">\n  <div class="m-modal">\n    <div class="modal-header">\n      <h3>');
        var __val__ = MTN.t("Meeting settings");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3>\n    </div>\n    <div class="modal-content">\n      <div class="horizontal-divider"></div>\n      <div class="settings">\n        <div class="setting email left"><i class="ico-mail"></i>\n          <div class="info">\n            <h3 class="title">');
        var __val__ = MTN.t("Email settings");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</h3>\n            <p>");
        var __val__ = MTN.t("Manage meeting email notifications.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n          </div>\n        </div>\n        <div class="setting right rights">');
        if (user && user.is_pro) {
            buf.push('<i class="ico-profile"></i>\n          <div class="info">\n            <h3 class="title">');
            var __val__ = MTN.t("Participant rights");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</h3>\n            <p>");
            var __val__ = MTN.t("Decide what participants are allowed to do.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>\n          </div>");
        } else {
            buf.push('<i class="ico-pro"></i>\n          <div class="info">\n            <h3 class="title pro">');
            var __val__ = MTN.t("Upgrade to PRO");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</h3>\n            <p>");
            var __val__ = MTN.t("Customize meetings and get all the benefits of the full suite!");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>\n          </div>");
        }
        buf.push('\n        </div>\n      </div>\n    </div>\n    <!-- TODO: Remove--><a href="#" class="close-modal"><i class="ico-cross"></i></a>\n  </div>\n  <div class="remove-area normal"><i class="ico-cross"></i>\n    <div class="info">\n      <h3 class="title">');
        var __val__ = MTN.t("Remove meeting");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</h3>\n      <p>");
        var __val__ = MTN.t("If you remove this meeting, you and the participants will no longer be able to access this meeting and its content.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n    </div><a class="button blue remove">');
        var __val__ = MTN.t("Remove");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a>\n  </div>\n  <div class="remove-area confirm">\n    <div class="info">\n      <p><a class="button blue remove">');
        var __val__ = MTN.t("Remove");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a><a class="button gray cancel-remove">');
        var __val__ = MTN.t("Cancel");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a></p>\n    </div>\n  </div>\n  <div class="remove-area removing">\n    <div class="info">\n      <p>');
        var __val__ = MTN.t("Removing meeting...");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n    </div>\n  </div>\n  <div class="remove-area removed">\n    <div class="info">\n      <p>');
        var __val__ = MTN.t("Removing meeting... done. Redirecting to timeline.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</p>\n    </div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// agentAdminSettings.jade compiled template
exports.agentAdminSettings = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div class="input-row">\n  <div class="input-label-row"><span>Tapaamisten pituus:</span></div>\n</div>\n<div class="input-row"><span class="input-label">Etutaso 0-1</span>\n  <select x-data-object-field="etutaso0-1_length_minutes" class="object-field">\n    <option');
        buf.push(attrs({
            value: "60",
            selected: "60" == (typeof admin_setting == "undefined" ? undefined : admin_setting["etutaso0-1_length_minutes"]) ? "selected" : undefined
        }, {
            value: true,
            selected: true
        }));
        buf.push(">1 tunti</option>\n    <option");
        buf.push(attrs({
            value: "90",
            selected: "90" == (typeof admin_setting == "undefined" ? undefined : admin_setting["etutaso0-1_length_minutes"]) ? "selected" : undefined
        }, {
            value: true,
            selected: true
        }));
        buf.push(">1,5 tuntia</option>\n    <option");
        buf.push(attrs({
            value: "120",
            selected: "120" == (typeof admin_setting == "undefined" ? undefined : admin_setting["etutaso0-1_length_minutes"]) ? "selected" : undefined
        }, {
            value: true,
            selected: true
        }));
        buf.push('>2 tuntia</option>\n  </select>\n</div>\n<div class="input-row"><span class="input-label">Etutaso 2-4</span>\n  <select x-data-object-field="etutaso2-4_length_minutes" class="object-field">\n    <option');
        buf.push(attrs({
            value: "60",
            selected: "60" == (typeof admin_setting == "undefined" ? undefined : admin_setting["etutaso2-4_length_minutes"]) ? "selected" : undefined
        }, {
            value: true,
            selected: true
        }));
        buf.push(">1 tunti</option>\n    <option");
        buf.push(attrs({
            value: "90",
            selected: "90" == (typeof admin_setting == "undefined" ? undefined : admin_setting["etutaso2-4_length_minutes"]) ? "selected" : undefined
        }, {
            value: true,
            selected: true
        }));
        buf.push(">1,5 tuntia</option>\n    <option");
        buf.push(attrs({
            value: "120",
            selected: "120" == (typeof admin_setting == "undefined" ? undefined : admin_setting["etutaso2-4_length_minutes"]) ? "selected" : undefined
        }, {
            value: true,
            selected: true
        }));
        buf.push(">2 tuntia</option>\n  </select>\n</div>");
    }
    return buf.join("");
};

// summaryGoogleLoaded.jade compiled template
exports.summaryGoogleLoaded = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="summary-connecting" class="tab">\n  <div id="google-connecting" class="m-modal">\n    <div class="modal-header">\n      <h3><i class="ico-calendar"></i>');
        var __val__ = MTN.t("Connecting your calendar");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n      </h3>\n    </div>\n    <div class="modal-content">\n      <p>');
        var __val__ = MTN.t("We have now imported your calendar items. You can change the calendar integration settings anytime at your personal settings.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</p>\n      <p>");
        var __val__ = MTN.t("Next you should add Meetin.gs to your Google calendar. Do you want to subscribe to the meeting calendar feed now?");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n    </div>\n    <div class="modal-footer">\n      <div class="buttons right"><a href="/meetings/user/settings/calendar" class="button blue subscribe">');
        var __val__ = MTN.t("Subscribe");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a><a class="button gray cancel">');
        var __val__ = MTN.t("Not now");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></div>\n    </div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// userSettingsEmailNotifications.jade compiled template
exports.userSettingsEmailNotifications = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="meeting-settings">\n  <div class="setting-head">\n    <h3 class="setting-title"><i class="icon ico-settings"></i>');
        var __val__ = MTN.t("Email notifications");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n    </h3>\n    <p class="setting-desc">');
        var __val__ = MTN.t("Here you can manage what your notification settings.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n  </div>\n  <div class="setting-content">');
        if (_.size(emailSettings)) {
            buf.push('\n    <div class="setting-section m-form">');
            (function() {
                if ("number" == typeof emailSettings.length) {
                    for (var $index = 0, $$l = emailSettings.length; $index < $$l; $index++) {
                        var setting = emailSettings[$index];
                        buf.push('\n      <label class="slider"><span class="slider-text">');
                        var __val__ = setting.title;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</span><span");
                        buf.push(attrs({
                            "data-setting": setting.id,
                            "class": "js_form_slider_button" + " " + "slider-button" + " " + (setting.value ? "on-position" : "off-position")
                        }, {
                            "class": true,
                            "data-setting": true
                        }));
                        buf.push("></span></label>");
                    }
                } else {
                    var $$l = 0;
                    for (var $index in emailSettings) {
                        $$l++;
                        var setting = emailSettings[$index];
                        buf.push('\n      <label class="slider"><span class="slider-text">');
                        var __val__ = setting.title;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</span><span");
                        buf.push(attrs({
                            "data-setting": setting.id,
                            "class": "js_form_slider_button" + " " + "slider-button" + " " + (setting.value ? "on-position" : "off-position")
                        }, {
                            "class": true,
                            "data-setting": true
                        }));
                        buf.push("></span></label>");
                    }
                }
            }).call(this);
            buf.push("\n    </div>");
        }
        buf.push("\n  </div>\n</div>");
        if (_.size(emailSettings)) {
            buf.push('\n<div class="setting-footer"><a href="#" class="button blue save-email-notifications"><span class="label">');
            var __val__ = MTN.t("Save");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</span></a></div>");
        }
    }
    return buf.join("");
};

// highlightCard.jade compiled template
exports.highlightCard = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push("<i");
        buf.push(attrs({
            "class": app.defaults.h_to_a[highlight.type]
        }, {
            "class": true
        }));
        buf.push("></i>\n<h3>");
        var __val__ = highlight.message;
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</h3>\n<p class="title">');
        var __val__ = title;
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</p>\n<p class="time">');
        var __val__ = time_string || MTN.t("Created on %1$s", {
            params: [ created_date_string ]
        });
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push("</p>");
    }
    return buf.join("");
};

// meetingSettingsRights.jade compiled template
exports.meetingSettingsRights = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div class="m-modal">\n  <div class="modal-header back-button">\n    <h3>');
        var __val__ = MTN.t("Edit participant rights");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3><i class="ico-leftarrow back"></i>\n  </div>\n  <div class="modal-content m-form">\n    <p>');
        var __val__ = MTN.t("Participants of this meeting are allowed to:");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n    <p class="slider"><span');
        buf.push(attrs({
            "data-setting": "invite",
            "class": "js_form_slider_button" + " " + "slider-button" + " " + (invite ? "on-position" : "off-position")
        }, {
            "class": true,
            "data-setting": true
        }));
        buf.push("></span>");
        var __val__ = MTN.t("Invite new participants");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n    </p>\n    <p class="slider"><span');
        buf.push(attrs({
            "data-setting": "add_material",
            "class": "js_form_slider_button" + " " + "slider-button" + " " + (add_material ? "on-position" : "off-position")
        }, {
            "class": true,
            "data-setting": true
        }));
        buf.push("></span>");
        var __val__ = MTN.t("Add material");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n    </p>\n    <p class="slider"><span');
        buf.push(attrs({
            "data-setting": "edit_material",
            "class": "js_form_slider_button" + " " + "slider-button" + " " + (edit_material ? "on-position" : "off-position")
        }, {
            "class": true,
            "data-setting": true
        }));
        buf.push("></span>");
        var __val__ = MTN.t("Edit material");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n    </p>\n  </div>\n  <div class="modal-footer">\n    <div class="buttons right"><a class="button blue save">');
        var __val__ = MTN.t("Save");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a></div>\n  </div><a href="#" class="close-modal"><i class="ico-cross"></i></a>\n</div>');
    }
    return buf.join("");
};

// meetmeMatchmakerUrl.jade compiled template
exports.meetmeMatchmakerUrl = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        if (locals.meetme_fragment) {
            buf.push('\n<p class="your-url m-form">URL: ');
            var __val__ = "https://" + window.location.hostname + "/meet/";
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("\n  <input");
            buf.push(attrs({
                type: "text",
                value: meetme_fragment,
                "class": "handle-value"
            }, {
                type: true,
                value: true
            }));
            buf.push('/><span class="warning"></span>\n</p>');
        } else {
            buf.push('\n<p class="finding-url">');
            var __val__ = MTN.t("Checking url...");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("\n</p>");
        }
    }
    return buf.join("");
};

// meetmeCalendar.jade compiled template
exports.meetmeCalendar = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="meetme-calendar">\n  <div class="top-wrapper">\n    <div class="top"><a href="#" class="back-to-cover"><img');
        buf.push(attrs({
            src: user.image || "/images/meetings/new_profile.png"
        }, {
            src: true
        }));
        buf.push("/></a>");
        if (!app.auth.user) {
            buf.push('<a href="#" class="login">');
            var __val__ = MTN.t("Already a user? Login here");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a>");
        }
        buf.push('\n      <h1 class="name">');
        var __val__ = user.name;
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push("</h1>");
        if (user.organization && user.organization_title) {
            buf.push('\n      <p class="title">');
            var __val__ = user.organization + ", " + user.organization_title;
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("</p>");
        }
        if (user.organization && !user.organization_title) {
            buf.push('\n      <p class="title">');
            var __val__ = user.organization;
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("</p>");
        }
        if (!user.organization && user.organization_title) {
            buf.push('\n      <p class="title">');
            var __val__ = user.organization_title;
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("</p>");
        }
        buf.push('\n      <div class="social-links">');
        if (user.linkedin) {
            buf.push("<a");
            buf.push(attrs({
                href: user.linkedin,
                target: "_blank"
            }, {
                href: true,
                target: true
            }));
            buf.push('><i class="ico-linkedin"></i>');
            var __val__ = MTN.t("Linkedin Profile");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a>");
        }
        buf.push('\n      </div>\n    </div>\n  </div>\n  <div class="info-bar">\n    <p>');
        var __val__ = MTN.t("Suggest below the best time to meet with %1$s.", {
            params: [ user.name ]
        });
        buf.push(null == __val__ ? "" : __val__);
        if (matchmaker.duration) {
            buf.push('<i class="ico-time"></i>');
            var __val__ = matchmaker.duration + " min";
            buf.push(escape(null == __val__ ? "" : __val__));
        }
        if (matchmaker.location) {
            buf.push('<i class="ico-location"></i>');
            var __val__ = rescheduled_meeting.location || matchmaker.location;
            buf.push(escape(null == __val__ ? "" : __val__));
        }
        buf.push('\n    </p>\n  </div>\n  <div class="middle">\n    <p class="timezone">');
        var __val__ = matchmaker.time_zone_string;
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</p>\n    <div id="calendar-container" class="btd-container">\n      <p>');
        var __val__ = MTN.t("Loading calendar...");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n      <div class="loader"></div>\n    </div>\n  </div>\n</div>');
    }
    return buf.join("");
};

// datePicker.jade compiled template
exports.datePicker = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="date" class="m-form">\n  <label for="begin_date"><i class="ico-calendar js_dmy_datepicker_meetings_manage_basic_begin_date_input_open_container"></i>');
        var __val__ = MTN.t("Date");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("\n    <input");
        buf.push(attrs({
            id: "meetings_manage_basic_begin_date_input",
            name: "begin_date",
            value: begin_date ? begin_date : initial_date_value,
            "class": "js_dmy_datepicker_input"
        }, {
            name: true,
            value: true
        }));
        buf.push('/>\n  </label>\n  <hr/>\n  <label for="begin_time_hours"><i class="ico-time"></i>\n    <select id="begin_time_hours" class="begin_time_hours">');
        if (begin_time_hours == 0) {
            buf.push('\n      <option value="0" selected="selected">12am </option>');
        } else {
            buf.push('\n      <option value="0">12am </option>');
        }
        for (var i = 1; i <= 11; i++) {
            if (i == begin_time_hours) {
                buf.push("\n      <option");
                buf.push(attrs({
                    value: i,
                    selected: "selected"
                }, {
                    value: true,
                    selected: true
                }));
                buf.push(">");
                var __val__ = i + (i > 9 ? "" : " ") + "am";
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</option>");
            } else {
                buf.push("\n      <option");
                buf.push(attrs({
                    value: i
                }, {
                    value: true
                }));
                buf.push(">");
                var __val__ = i + (i > 9 ? "" : " ") + "am";
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</option>");
            }
        }
        if (begin_time_hours == 12) {
            buf.push('\n      <option value="12" selected="selected">12pm</option>');
        } else {
            buf.push('\n      <option value="12">12pm</option>');
        }
        for (var i = 1; i <= 11; i++) {
            if (i + 12 == begin_time_hours) {
                buf.push("\n      <option");
                buf.push(attrs({
                    value: i + 12,
                    selected: "selected"
                }, {
                    value: true,
                    selected: true
                }));
                buf.push(">");
                var __val__ = i + (i > 9 ? "" : " ") + "pm";
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</option>");
            } else {
                buf.push("\n      <option");
                buf.push(attrs({
                    value: i + 12
                }, {
                    value: true
                }));
                buf.push(">");
                var __val__ = i + (i > 9 ? "" : " ") + "pm";
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</option>");
            }
        }
        buf.push('\n    </select>\n    <select id="begin_time_minutes" class="begin_time_minutes">');
        if (begin_time_minutes == 0 && begin_time_minutes == 0) {
            begin_time_minutes = 1;
        }
        for (var i = 0; i < 60; i = i + 5) {
            if (i == begin_time_minutes) {
                buf.push("\n      <option");
                buf.push(attrs({
                    value: i.toString().length < 2 ? "0" + i : i,
                    selected: "selected"
                }, {
                    value: true,
                    selected: true
                }));
                buf.push(">");
                var __val__ = i.toString().length < 2 ? "0" + i : i;
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</option>");
            } else {
                buf.push("\n      <option");
                buf.push(attrs({
                    value: i.toString().length < 2 ? "0" + i : i
                }, {
                    value: true
                }));
                buf.push(">");
                var __val__ = i.toString().length < 2 ? "0" + i : i;
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</option>");
            }
        }
        buf.push("\n    </select>\n  </label>\n</div>");
    }
    return buf.join("");
};

// meetmeTimezonePrefs.jade compiled template
exports.meetmeTimezonePrefs = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="meetme-timezone-popup" class="m-modal">\n  <div class="modal-header">\n    <h3>');
        var __val__ = MTN.t("Choose your time");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3>\n  </div>\n  <div class="modal-content">\n    <p>');
        var __val__ = MTN.t("Which time zone would you prefer for displaying the available times?");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n    <div class="m-form">\n      <label class="radio">\n        <input');
        buf.push(attrs({
            type: "radio",
            name: "offset",
            checked: "checked",
            value: matchmaker.time_zone
        }, {
            type: true,
            name: true,
            checked: true,
            value: true
        }));
        buf.push("/>");
        if (matchmaker.event_data && matchmaker.event_data.id && matchmaker.event_data.force_time_zone) {
            var __val__ = MTN.t("Timezone set for") + " ";
            buf.push(null == __val__ ? "" : __val__);
            var __val__ = matchmaker.event_data.name + ": ";
            buf.push(escape(null == __val__ ? "" : __val__));
            var __val__ = matchmaker.time_zone_string;
            buf.push(escape(null == __val__ ? "" : __val__));
        } else {
            var __val__ = MTN.t("Timezone set by") + " ";
            buf.push(null == __val__ ? "" : __val__);
            var __val__ = user.name + ": ";
            buf.push(escape(null == __val__ ? "" : __val__));
            var __val__ = matchmaker.time_zone_string;
            buf.push(escape(null == __val__ ? "" : __val__));
        }
        buf.push('\n      </label>\n      <p class="now">');
        var __val__ = MTN.t("Current time for this zone is:") + " ";
        buf.push(null == __val__ ? "" : __val__);
        buf.push("<span>");
        var __val__ = moment.utc(d.getTime() + matchmaker.time_zone_offset * 1e3).format("hh:mm A");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</span>\n      </p>\n      <p class="radio">\n        <input');
        buf.push(attrs({
            id: "user-tz",
            type: "radio",
            name: "offset",
            value: ua_tz
        }, {
            type: true,
            name: true,
            value: true
        }));
        buf.push("/>");
        var __val__ = MTN.t("Your time zone ");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n        <select id="timezone-select" class="chosen">');
        (function() {
            if ("number" == typeof tz_data.choices.length) {
                for (var i = 0, $$l = tz_data.choices.length; i < $$l; i++) {
                    var tz = tz_data.choices[i];
                    if (tz === ua_tz) {
                        buf.push("\n          <option");
                        buf.push(attrs({
                            value: tz,
                            selected: "selected"
                        }, {
                            value: true,
                            selected: true
                        }));
                        buf.push(">");
                        var __val__ = tz_data.data[tz].readable_name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    } else {
                        buf.push("\n          <option");
                        buf.push(attrs({
                            value: tz
                        }, {
                            value: true
                        }));
                        buf.push(">");
                        var __val__ = tz_data.data[tz].readable_name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    }
                }
            } else {
                var $$l = 0;
                for (var i in tz_data.choices) {
                    $$l++;
                    var tz = tz_data.choices[i];
                    if (tz === ua_tz) {
                        buf.push("\n          <option");
                        buf.push(attrs({
                            value: tz,
                            selected: "selected"
                        }, {
                            value: true,
                            selected: true
                        }));
                        buf.push(">");
                        var __val__ = tz_data.data[tz].readable_name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    } else {
                        buf.push("\n          <option");
                        buf.push(attrs({
                            value: tz
                        }, {
                            value: true
                        }));
                        buf.push(">");
                        var __val__ = tz_data.data[tz].readable_name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    }
                }
            }
        }).call(this);
        buf.push('\n        </select>\n      </p>\n      <p class="now">');
        var __val__ = MTN.t("Current time for this zone is:");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('<span id="user-time">');
        var __val__ = moment.utc(d.getTime() + tz_data.data[app.options.ua_time_zone].offset_value * 1e3).format("hh:mm A");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</span>\n      </p>\n    </div>\n  </div>\n  <div class="modal-footer">\n    <div class="buttons right"><a href="#" class="button blue set-time-zone">');
        var __val__ = MTN.t("Continue");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// upgradeCover.jade compiled template
exports.upgradeCover = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="upgrade-page" class="m-modal">\n  <div class="modal-header">\n    <h3>');
        var __val__ = MTN.t("Upgrade Meetin.gs PRO");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3>\n  </div>\n  <div class="modal-content">\n    <div class="section vendor paypal">\n      <div class="left">\n        <h3>');
        var __val__ = MTN.t("Buy using credit card");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3>\n      </div>\n      <div class="right">\n        <p><a data-payment-type="monthly" class="button pink open-pay">');
        var __val__ = MTN.t("$ 12 / month");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a><span class="or">');
        var __val__ = MTN.t("or");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</span><a data-payment-type="yearly" class="button pink open-pay">');
        var __val__ = MTN.t("$ 129 / year");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></p>\n      </div>\n    </div>");
        if (prefered_vendor) {
            buf.push('\n    <div class="section vendor prefered">\n      <div class="left">\n        <h3>');
            var __val__ = MTN.t("Buy from your local vendor");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</h3>\n      </div>\n      <div class="right">\n        <p><a');
            buf.push(attrs({
                href: app.vendors[prefered_vendor].url,
                "class": "prefered-image"
            }, {
                href: true
            }));
            buf.push("><img");
            buf.push(attrs({
                src: app.vendors[prefered_vendor].image,
                alt: app.vendors[prefered_vendor].name,
                "class": "logo"
            }, {
                src: true,
                alt: true
            }));
            buf.push('/><span class="price">');
            var __val__ = app.vendors[prefered_vendor].price;
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("</span></a></p>\n      </div>\n    </div>");
        }
        buf.push('\n    <div class="section vendor others">\n      <div class="left">\n        <h3>');
        var __val__ = MTN.t("Other vendors");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3>\n      </div>\n      <div class="right">\n        <p>');
        var i = 0;
        (function() {
            if ("number" == typeof app.vendors.length) {
                for (var key = 0, $$l = app.vendors.length; key < $$l; key++) {
                    var vendor = app.vendors[key];
                    if (key !== prefered_vendor) {
                        var __val__ = i > 0 ? ", " : "";
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("<a");
                        buf.push(attrs({
                            href: "/meetings/upgrade/" + key,
                            "class": "vendor-link" + " " + "underline"
                        }, {
                            href: true
                        }));
                        buf.push(">");
                        var __val__ = vendor.name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</a>");
                        i++;
                    }
                }
            } else {
                var $$l = 0;
                for (var key in app.vendors) {
                    $$l++;
                    var vendor = app.vendors[key];
                    if (key !== prefered_vendor) {
                        var __val__ = i > 0 ? ", " : "";
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("<a");
                        buf.push(attrs({
                            href: "/meetings/upgrade/" + key,
                            "class": "vendor-link" + " " + "underline"
                        }, {
                            href: true
                        }));
                        buf.push(">");
                        var __val__ = vendor.name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</a>");
                        i++;
                    }
                }
            }
        }).call(this);
        buf.push("\n        </p>\n      </div>\n    </div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// meetmeButtonTips.jade compiled template
exports.meetmeButtonTips = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="meetme-button-tips" class="m-modal">\n  <div class="modal-header">\n    <h3>');
        var __val__ = MTN.t("Please take note:");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3>\n  </div>\n  <div class="modal-content">\n    <p>');
        var __val__ = MTN.t("It is recommended to have at least one public meeting scheduler available to share your Meet Me cover page. Please add one now.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</p>\n    <p>");
        var __val__ = MTN.t('When you are done you can use the "sharing" link on top of this screen to easily embed your "schedule" button and share your Meet Me cover page as well as your private meeting schedulers.');
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n  </div>\n  <div class="modal-footer"> \n    <div class="buttons right"><a href="#" class="button blue js_hook_showcase_close">');
        var __val__ = MTN.t("Ok, got it");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// meetingTop.jade compiled template
exports.meetingTop = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
    }
    return buf.join("");
};

// agentBookingPublic.jade compiled template
exports.agentBookingPublic = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        if (stage == "area") {
            {
                buf.push('\n<div id="agent-booking-public" class="m-modal">\n  <div class="modal-header">\n    <h3> <i class="ico-search"></i>');
                var __val__ = "Tervetuloa Lähixcustxzn omatoimiseen verkkoajanvaraukseen!";
                buf.push(null == __val__ ? "" : __val__);
                buf.push('\n    </h3>\n  </div>\n  <div class="modal-content">\n    <p style="font-weight: bold" class="note">');
                var __val__ = "Valitse alta Lähixcustxzn alueyhtiösi";
                buf.push(null == __val__ ? "" : __val__);
                buf.push('\n    </p>\n    <p class="note">');
                var __val__ = "Valitettavasti ainoastaan Pääkaupunkiseudun alueyhtiö on toistaiseksi tavattavissa omatoimisesti. Mikäli asut jonkun muun alueyhtiön alla, palaa takaisin Lähixcustxzn sivuille ja pyydä verkkotapaamista yhteidenottolomakkeella.";
                buf.push(null == __val__ ? "" : __val__);
                buf.push('\n    </p>\n    <div class="selector-container"><a href="#" x-data-area="Pääkaupunkiseutu" class="button-select-area">');
                var __val__ = "Pääkaupunkiseutu";
                buf.push(null == __val__ ? "" : __val__);
                buf.push('<br/><br/><img src="/images/meetings/ltmap-pks.png" height="200px" alt="Pääkaupunkiseutu"/></a></div>\n    <div class="back-container"><br/><br/><br/><a id="button-navigate-back-to-site" href="#">');
                var __val__ = "Takaisin Lähixcustxzn sivuille";
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</a></div>\n  </div>\n</div>");
            }
        } else if (stage == "level") {
            {
                buf.push('\n<div id="agent-booking-public" class="m-modal">\n  <div class="modal-header">\n    <h3> <i class="ico-question"></i>');
                var __val__ = "Oletko jo Lähixcustxzn asiakas?";
                buf.push(null == __val__ ? "" : __val__);
                buf.push('\n    </h3>\n  </div>\n  <div class="modal-content">\n    <p class="note">');
                var __val__ = "Tämän tiedon pohjalta osaamme varata sinulle sopivan edustajan.";
                buf.push(null == __val__ ? "" : __val__);
                buf.push('\n    </p>\n    <div class="selector-container"><a href="#" x-data-level="etutaso2-4" class="button-select-level"><i class="ico-like"></i><br/><br/>');
                var __val__ = "Kyllä, olen jo asiakas";
                buf.push(null == __val__ ? "" : __val__);
                buf.push('</a><a href="#" x-data-level="etutaso0-1" class="button-select-level"><i class="ico-question"></i><br/><br/>');
                var __val__ = "Ei, olen uusi asiakas";
                buf.push(null == __val__ ? "" : __val__);
                buf.push('</a></div>\n    <div class="back-container"><br/><br/><br/><a id="button-navigate-back-to-area" href="#">');
                var __val__ = "Takaisin alueyhtiön valintaan";
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</a></div>\n  </div>\n</div>");
            }
        } else {
            {
                buf.push('\n<div id="agent-booking-public" class="m-modal">\n  <div class="modal-header">\n    <h3> <i class="ico-calendar"></i>');
                var __val__ = "Varaa itsellesi sopiva aika" || MTN.t("Reserve a time");
                buf.push(null == __val__ ? "" : __val__);
                buf.push('\n    </h3>\n  </div>\n  <div class="modal-content">\n    <p style="font-weight: bold" class="note">');
                var __val__ = "Valitse alta jokin sopivista vihreistä alueista tapaamisesi ajankohdaksi.";
                buf.push(null == __val__ ? "" : __val__);
                buf.push('\n    </p>\n    <p class="note">');
                var __val__ = "Valinnan jälkeen kysymme muutamia lisätietoja ja vahvistamme sen jälkeen ajan sinulle.";
                buf.push(null == __val__ ? "" : __val__);
                buf.push('\n    </p>\n    <div style="height:900px" class="calendar-container js-calendar-container"></div>\n    <div class="back-container"><br/><br/><br/><a id="button-navigate-back-to-level" href="#">');
                var __val__ = "Takaisin asiakkuustyypin valintaan";
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</a></div>\n  </div>\n</div>");
            }
        }
    }
    return buf.join("");
};

// userSettingsLogin.jade compiled template
exports.userSettingsLogin = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push("\n<!-- Required params: fbid, google_connected-->");
        user.facebook_user_id = user.facebook_user_id || 0;
        buf.push('\n<div class="setting-head">\n  <h3 class="setting-title"><i class="icon ico-password"></i>');
        var __val__ = MTN.t("Login methods");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n  </h3>\n  <p class="setting-desc">');
        var __val__ = MTN.t("Manage how you log in to the service.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n</div>\n<div class="setting-content">\n  <div class="setting-section">\n    <h3 class="setting-sub-title">');
        var __val__ = MTN.t("Third-party login options");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</h3>\n    <p>");
        var __val__ = MTN.t("Connect one of your third-party accounts to login easily:");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n      <!-- Facebook-->\n      <div id="facebook_connect_container">\n        <input');
        buf.push(attrs({
            type: "hidden",
            value: user.facebook_user_id,
            name: user.facebook_user_id,
            "class": "js_fb_fillable_Facebook_user_id"
        }, {
            type: true,
            value: true,
            name: true
        }));
        buf.push("/>\n        <p");
        buf.push(attrs({
            id: "profile-edit-facebook-disconnected",
            style: user.facebook_user_id ? "display:none;" : "",
            "class": "disconnected"
        }, {
            style: true
        }));
        buf.push("><a");
        buf.push(attrs({
            id: "connect-facebook",
            href: app.helpers.getServiceUrl({
                service: "facebook",
                action: "connect",
                return_url: "/meetings/user/settings/login"
            }),
            "class": "js_meetings_connect_profile_with_facebook" + " " + "button" + " " + "login" + " " + "fb-blue"
        }, {
            href: true
        }));
        buf.push('><i class="ico-facebook"></i>');
        var __val__ = MTN.t("Connect with Facebook");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></p>\n        <p");
        buf.push(attrs({
            id: "profile-edit-facebook-connected",
            style: user.facebook_user_id ? "" : "display:none;",
            "class": "connected"
        }, {
            style: true
        }));
        buf.push('><span class="ok"></span>');
        var __val__ = MTN.t("Your account is connected to Facebook");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('<a id="disconnect-facebook-submit" href="#" data-network-id="facebook" class="disconnect js_meetings_disconnect_profile_from_facebook">');
        var __val__ = MTN.t("Disconnect");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a>\n        </p>\n      </div>\n      <!-- Google-->\n      <div id="google_connect_container">\n        <p');
        buf.push(attrs({
            style: user.google_connected ? "display:none;" : "",
            "class": "disconnected"
        }, {
            style: true
        }));
        buf.push("><a");
        buf.push(attrs({
            id: "connect-google",
            href: app.helpers.getServiceUrl({
                service: "google",
                action: "connect",
                return_url: "/meetings/user/settings/login"
            }),
            "class": "button" + " " + "login" + " " + "google-blue"
        }, {
            href: true
        }));
        buf.push('><i class="ico-google"></i>');
        var __val__ = MTN.t("Connect with Google");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></p>\n        <p");
        buf.push(attrs({
            style: user.google_connected ? "" : "display:none;",
            "class": "connected"
        }, {
            style: true
        }));
        buf.push('><span class="ok"></span>');
        var __val__ = MTN.t("Your account is connected to Google");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('<a href="#" data-network-id="google" class="disconnect">');
        var __val__ = MTN.t("Disconnect");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a>\n        </p>\n      </div></p>\n  </div>\n  <div class="setting-section">\n    <h3 class="setting-sub-title">');
        var __val__ = MTN.t("Set up a password");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</h3>\n    <p>");
        var __val__ = MTN.t("Create a password to easily login without your personal login link.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n    <div class="m-form">\n      <label class="inline">');
        var __val__ = MTN.t("Password");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("\n        <input");
        buf.push(attrs({
            id: "password",
            type: "password",
            value: "",
            placeholder: MTN.t("New password")
        }, {
            type: true,
            value: true,
            placeholder: false
        }));
        buf.push('/></label>\n    </div>\n  </div>\n</div>\n<div class="setting-footer"><a href="#" class="button blue save-password"><span class="label">');
        var __val__ = MTN.t("Save");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</span></a></div>");
    }
    return buf.join("");
};

// userSettingsCancelSubscription.jade compiled template
exports.userSettingsCancelSubscription = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="confirm-subscription-cancel" class="m-modal">\n  <div class="modal-header">\n    <h3>');
        var __val__ = MTN.t("Cancel subscription");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3>\n  </div>\n  <div class="modal-content">\n    <p>');
        var __val__ = MTN.t("Are you sure you want to cancel your subscription? Doing this will end your subscription after the ongoing billing cycle. Your account will be downgraded to the limited version in %1$s.", [ moment(user.subscription_user_next_payment_epoch * 1e3).fromNow() ]);
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n  </div>\n  <div class="modal-footer"> \n    <div class="buttons right"><a href="#" class="confirm-cancel button blue">');
        var __val__ = MTN.t("Yes, cancel my subscription");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a><a href="#" class="button gray js_hook_showcase_close">');
        var __val__ = MTN.t("No, continue as a PRO user");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// meetingLctSkype.jade compiled template
exports.meetingLctSkype = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="lct-picker" class="m-modal">\n  <div class="modal-header back-button">\n    <h3>');
        var __val__ = MTN.t("Skype settings");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3><i class="ico-leftarrow back"></i>\n  </div>\n  <div class="modal-content m-form">\n    <p>');
        var __val__ = MTN.t("Type in the Skype account that will be used to receive the calls from the participants.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</p>\n    <label>");
        var __val__ = MTN.t("Skype account name");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("\n      <input");
        buf.push(attrs({
            id: "com-skype",
            type: "text",
            value: meeting.online_conferencing_data && meeting.online_conferencing_data.skype_account ? meeting.online_conferencing_data.skype_account : user && user.skype ? user.skype : "",
            placeholder: MTN.t("Skype account name")
        }, {
            type: true,
            value: true,
            placeholder: false
        }));
        buf.push('/></label><br/>\n    <p class="note">');
        var __val__ = MTN.t("NOTE: If you are not connected with the participants in Skype, remember to allow incoming calls from anyone using Skype privacy settings.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n  </div>\n  <div class="modal-footer">\n    <div class="buttons right"><a href="#" class="button blue save">');
        var __val__ = MTN.t("Save");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// meetmeCalendarOptions.jade compiled template
exports.meetmeCalendarOptions = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        if (user.suggestion_sources && user.suggestion_sources.length > 0) {
            if (mode === "closed") {
                var selected_cals = _.size(matchmaker.source_settings.enabled);
                var unselected_cals = _.size(matchmaker.source_settings.disabled);
                var new_cals = user.suggestion_sources.length - (selected_cals + unselected_cals);
                var xtra = unselected_cals === 0 && selected_cals === 0 ? _.where(user.suggestion_sources, {
                    selected_by_default: 1
                }).length : 0;
                buf.push('\n<!-- TODO: Checking that there actually is a default cal-->\n<p class="sources-info">');
                var __val__ = MTN.t("Connected calendars: %1$s active %2$s inactive and %3$s new calendars", {
                    params: [ selected_cals + xtra, unselected_cals, new_cals ]
                }) + " ";
                buf.push(null == __val__ ? "" : __val__);
                buf.push('<a href="#" class="open-cal-options">');
                var __val__ = MTN.t("change");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</a></p>");
                if (user.suggestion_sources.length > matchmaker.source_settings.disabled.length + matchmaker.source_settings.enabled.length) {
                    buf.push('<span class="new-cals-note">');
                    var __val__ = MTN.t("( NOTE: Calendars not configured )");
                    buf.push(null == __val__ ? "" : __val__);
                    buf.push("</span>");
                }
            } else {
                buf.push('\n<p class="sources-info">');
                var __val__ = MTN.t("Select which calendars you want to check for your availability");
                buf.push(null == __val__ ? "" : __val__);
                buf.push('</p>\n<div class="m-form">');
                user.suggestion_sources = _.sortBy(user.suggestion_sources, function(o) {
                    return o.name.toLowerCase();
                });
                var grouped_sources = _.groupBy(user.suggestion_sources, function(r) {
                    return r.container_id;
                });
                (function() {
                    if ("number" == typeof grouped_sources.length) {
                        for (var $index = 0, $$l = grouped_sources.length; $index < $$l; $index++) {
                            var source = grouped_sources[$index];
                            buf.push('\n  <div class="cal-section">');
                            (function() {
                                if ("number" == typeof source.length) {
                                    for (var i = 0, $$l = source.length; i < $$l; i++) {
                                        var suggestion = source[i];
                                        if (i === 0) {
                                            buf.push('\n    <h3 class="cal-title">');
                                            var __val__ = suggestion.container_name;
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                            buf.push("</h3>");
                                        }
                                        buf.push('\n    <label class="checkbox">');
                                        if (matchmaker.source_settings && suggestion.uid in matchmaker.source_settings.enabled) {
                                            buf.push("\n      <input");
                                            buf.push(attrs({
                                                type: "checkbox",
                                                name: "calendars",
                                                checked: "checked",
                                                "data-id": suggestion.uid,
                                                "class": "cal-box"
                                            }, {
                                                type: true,
                                                name: true,
                                                checked: true,
                                                "data-id": true
                                            }));
                                            buf.push("/>");
                                            var __val__ = suggestion.name;
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                        } else {
                                            buf.push("\n      <input");
                                            buf.push(attrs({
                                                type: "checkbox",
                                                name: "calendars",
                                                "data-id": suggestion.uid,
                                                "class": "cal-box"
                                            }, {
                                                type: true,
                                                name: true,
                                                "data-id": true
                                            }));
                                            buf.push("/>");
                                            var __val__ = suggestion.name;
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                        }
                                        buf.push("\n    </label>");
                                    }
                                } else {
                                    var $$l = 0;
                                    for (var i in source) {
                                        $$l++;
                                        var suggestion = source[i];
                                        if (i === 0) {
                                            buf.push('\n    <h3 class="cal-title">');
                                            var __val__ = suggestion.container_name;
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                            buf.push("</h3>");
                                        }
                                        buf.push('\n    <label class="checkbox">');
                                        if (matchmaker.source_settings && suggestion.uid in matchmaker.source_settings.enabled) {
                                            buf.push("\n      <input");
                                            buf.push(attrs({
                                                type: "checkbox",
                                                name: "calendars",
                                                checked: "checked",
                                                "data-id": suggestion.uid,
                                                "class": "cal-box"
                                            }, {
                                                type: true,
                                                name: true,
                                                checked: true,
                                                "data-id": true
                                            }));
                                            buf.push("/>");
                                            var __val__ = suggestion.name;
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                        } else {
                                            buf.push("\n      <input");
                                            buf.push(attrs({
                                                type: "checkbox",
                                                name: "calendars",
                                                "data-id": suggestion.uid,
                                                "class": "cal-box"
                                            }, {
                                                type: true,
                                                name: true,
                                                "data-id": true
                                            }));
                                            buf.push("/>");
                                            var __val__ = suggestion.name;
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                        }
                                        buf.push("\n    </label>");
                                    }
                                }
                            }).call(this);
                            buf.push("\n  </div>");
                        }
                    } else {
                        var $$l = 0;
                        for (var $index in grouped_sources) {
                            $$l++;
                            var source = grouped_sources[$index];
                            buf.push('\n  <div class="cal-section">');
                            (function() {
                                if ("number" == typeof source.length) {
                                    for (var i = 0, $$l = source.length; i < $$l; i++) {
                                        var suggestion = source[i];
                                        if (i === 0) {
                                            buf.push('\n    <h3 class="cal-title">');
                                            var __val__ = suggestion.container_name;
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                            buf.push("</h3>");
                                        }
                                        buf.push('\n    <label class="checkbox">');
                                        if (matchmaker.source_settings && suggestion.uid in matchmaker.source_settings.enabled) {
                                            buf.push("\n      <input");
                                            buf.push(attrs({
                                                type: "checkbox",
                                                name: "calendars",
                                                checked: "checked",
                                                "data-id": suggestion.uid,
                                                "class": "cal-box"
                                            }, {
                                                type: true,
                                                name: true,
                                                checked: true,
                                                "data-id": true
                                            }));
                                            buf.push("/>");
                                            var __val__ = suggestion.name;
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                        } else {
                                            buf.push("\n      <input");
                                            buf.push(attrs({
                                                type: "checkbox",
                                                name: "calendars",
                                                "data-id": suggestion.uid,
                                                "class": "cal-box"
                                            }, {
                                                type: true,
                                                name: true,
                                                "data-id": true
                                            }));
                                            buf.push("/>");
                                            var __val__ = suggestion.name;
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                        }
                                        buf.push("\n    </label>");
                                    }
                                } else {
                                    var $$l = 0;
                                    for (var i in source) {
                                        $$l++;
                                        var suggestion = source[i];
                                        if (i === 0) {
                                            buf.push('\n    <h3 class="cal-title">');
                                            var __val__ = suggestion.container_name;
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                            buf.push("</h3>");
                                        }
                                        buf.push('\n    <label class="checkbox">');
                                        if (matchmaker.source_settings && suggestion.uid in matchmaker.source_settings.enabled) {
                                            buf.push("\n      <input");
                                            buf.push(attrs({
                                                type: "checkbox",
                                                name: "calendars",
                                                checked: "checked",
                                                "data-id": suggestion.uid,
                                                "class": "cal-box"
                                            }, {
                                                type: true,
                                                name: true,
                                                checked: true,
                                                "data-id": true
                                            }));
                                            buf.push("/>");
                                            var __val__ = suggestion.name;
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                        } else {
                                            buf.push("\n      <input");
                                            buf.push(attrs({
                                                type: "checkbox",
                                                name: "calendars",
                                                "data-id": suggestion.uid,
                                                "class": "cal-box"
                                            }, {
                                                type: true,
                                                name: true,
                                                "data-id": true
                                            }));
                                            buf.push("/>");
                                            var __val__ = suggestion.name;
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                        }
                                        buf.push("\n    </label>");
                                    }
                                }
                            }).call(this);
                            buf.push("\n  </div>");
                        }
                    }
                }).call(this);
                buf.push("\n</div>");
            }
        }
    }
    return buf.join("");
};

// userSettingsAccountRemove.jade compiled template
exports.userSettingsAccountRemove = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="meetme-confirm-delete" class="m-modal">\n  <div class="modal-header">\n    <h3>');
        var __val__ = MTN.t("Remove account");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3>\n  </div>\n  <div class="modal-content">\n    <p>');
        var __val__ = MTN.t("Are you sure you want to remove account with email %1$s. There is no undo.", {
            params: [ user.email ]
        });
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n  </div>\n  <div class="modal-footer"> \n    <div class="buttons right"><a href="#" class="confirm-delete button blue">');
        var __val__ = MTN.t("Remove");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a><a href="#" class="button gray js_hook_showcase_close">');
        var __val__ = MTN.t("Cancel");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// meetmeCover.jade compiled template
exports.meetmeCover = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="meetme-cover">');
        if (mode === "edit") {
            buf.push('\n  <div class="config-bar">\n    <div class="config-bar-content">\n      <div class="url-config">\n        <p class="your-url m-form">URL: ');
            var __val__ = "https://" + window.location.hostname + "/meet/" + user.meetme_fragment;
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("\n        </p>");
            if (matchmaker_collection.length && user && user.new_user_flow) {
                buf.push('<a href="#" class="button pink go-to-share">Continue</a>');
            } else if (matchmaker_collection.length) {
                buf.push('\n        <p class="url-help-links"><a href="#" class="blue-link view-page">');
                var __val__ = MTN.t("view page");
                buf.push(null == __val__ ? "" : __val__);
                buf.push('</a><a href="#" class="blue-link go-to-share">');
                var __val__ = MTN.t("sharing");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</a></p>");
            } else if (user.new_user_flow) {
                buf.push('\n        <p class="url-help-links"><a href="#" class="blue-link skip-continue">');
                var __val__ = MTN.t("skip");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</a></p>");
            }
            buf.push('\n      </div>\n    </div>\n  </div>\n  <div class="config-bar grey">\n    <div class="config-bar-content">\n      <h2>');
            var __val__ = MTN.t("Configure your %(B$Meet Me%) page");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</h2>\n    </div>\n  </div>");
        }
        buf.push('\n  <div class="top">\n    <h1>');
        var __val__ = user.name;
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push("</h1>");
        var ts = user.organization_title && user.organization ? user.organization_title + ", " + user.organization : user.organization_title + user.organization;
        buf.push("\n    <p>");
        var __val__ = ts;
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push("</p>");
        if (mode !== "edit" && !app.auth.user && !user.is_pro) {
            buf.push('\n    <div class="claim-wrap"><a href="#" class="claim">');
            var __val__ = MTN.t("Claim your free %(B$Meet Me%) page now") + " &raquo;";
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a></div>");
        }
        buf.push('\n  </div>\n  <div class="middle">\n    <div class="border">\n      <div class="wrapper edit-profile"><img');
        buf.push(attrs({
            src: user.image || "/images/meetings/new_profile.png",
            "class": "profile"
        }, {
            src: true
        }));
        buf.push("/>");
        if (mode === "edit") {
            buf.push('<span class="edit-profile">');
            var __val__ = MTN.t("Edit profile");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</span>");
        }
        buf.push("\n      </div>\n    </div>");
        if (mode === "edit") {
            buf.push('\n    <div class="bubble bg-change"><span class="text"><i class="ico-material_image"></i>');
            var __val__ = MTN.t("Change background");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</span></div>");
        }
        buf.push('\n    <div class="bubble mid">\n      <div class="tip"></div>');
        var desc = mode === "single" ? matchmaker_collection[0].description : user.meetme_description;
        if (!desc && !matchmaker_collection.length) {
            buf.push('\n      <div class="meetme-description">');
            var __val__ = MTN.t("Welcome to my meet me page. Unfortunately I have not made any of my calendars public yet!");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</div>");
        } else if (!desc && matchmaker_collection.length) {
            buf.push('\n      <div class="meetme-description">');
            var __val__ = MTN.t("Welcome to my meet me page. Please choose what kind of a meeting you would like to schedule with me below:");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</div>");
        } else {
            buf.push('\n      <div class="meetme-description">' + ((interp = escape(desc).replace(/\n/g, "<br/>")) == null ? "" : interp) + "</div>");
        }
        if (mode === "edit") {
            buf.push("<a");
            buf.push(attrs({
                title: MTN.t("Edit greeting text"),
                href: "#",
                "class": "edit-desc"
            }, {
                title: false,
                href: true
            }));
            buf.push('><i class="ico-edit"></i></a><a href="#" style="display:none;" class="button blue save-desc">Save</a>');
        }
        var mms = locals.preview ? matchmaker_collection : _.filter(matchmaker_collection, function(o) {
            return o.last_active_epoch === 0 || o.last_active_epoch * 1e3 > new Date().getTime() - 1e3 * 3 * 31 * 24 * 60 * 60;
        });
        if (mms.length) {
            buf.push('\n      <div class="matchmakers">');
            (function() {
                if ("number" == typeof mms.length) {
                    for (var index = 0, $$l = mms.length; index < $$l; index++) {
                        var mm = mms[index];
                        if (mode === "edit" || mode === "single" || !mm.meetme_hidden) {
                            buf.push("\n        <div");
                            buf.push(attrs({
                                "data-id": mm.id || mm.cid,
                                title: mode === "edit" ? MTN.t("Drag to reorder") : "",
                                "class": "matchmaker" + " " + (matchmaker_collection.length === 1 ? "alone" : "")
                            }, {
                                "class": true,
                                "data-id": true,
                                title: false
                            }));
                            buf.push("><i");
                            buf.push(attrs({
                                "class": "type-icon " + app.meetme_types[mm.meeting_type || 0].icon_class
                            }, {
                                "class": true
                            }));
                            buf.push("></i>\n          <div");
                            buf.push(attrs({
                                "class": "text " + mode
                            }, {
                                "class": true
                            }));
                            buf.push('><span class="name">');
                            var __val__ = mm.name || MTN.t("Meeting with ") + user.name;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</span>");
                            var info = mm.meetme_hidden && mode === "edit" ? MTN.t("Private") : "";
                            if (mm.event_data && mm.event_data.force_available_timespans) {
                                {
                                    if (info) info += " / ";
                                    info += app.helpers.daySpanStringFromTimespans(mm.event_data.force_available_timespans, user.time_zone_offset);
                                }
                            }
                            if (info) {
                                buf.push('<span class="info">');
                                var __val__ = info;
                                buf.push(escape(null == __val__ ? "" : __val__));
                                buf.push("</span>");
                            }
                            buf.push("\n          </div>");
                            if (mode === "edit") {
                                buf.push("<span");
                                buf.push(attrs({
                                    title: MTN.t("Configure Meet Me page"),
                                    "data-name": mm.vanity_url_path || "default",
                                    "class": "button" + " " + "blue" + " " + "edit-scheduler"
                                }, {
                                    title: false,
                                    "data-name": true
                                }));
                                buf.push('><i class="ico-settings"></i></span><span');
                                buf.push(attrs({
                                    title: MTN.t("Remove Meet Me page"),
                                    "data-id": mm.id,
                                    "class": "button" + " " + "gray" + " " + "remove-scheduler"
                                }, {
                                    title: false,
                                    "data-id": true
                                }));
                                buf.push('><i class="ico-cross"></i></span>');
                            } else {
                                buf.push("<span");
                                buf.push(attrs({
                                    "data-id": mm.id || mm.cid,
                                    "class": "button" + " " + "blue" + " " + "open-scheduler"
                                }, {
                                    "data-id": true
                                }));
                                buf.push(">");
                                var __val__ = MTN.t("Schedule");
                                buf.push(null == __val__ ? "" : __val__);
                                buf.push("</span>");
                            }
                            buf.push("\n        </div>");
                        }
                    }
                } else {
                    var $$l = 0;
                    for (var index in mms) {
                        $$l++;
                        var mm = mms[index];
                        if (mode === "edit" || mode === "single" || !mm.meetme_hidden) {
                            buf.push("\n        <div");
                            buf.push(attrs({
                                "data-id": mm.id || mm.cid,
                                title: mode === "edit" ? MTN.t("Drag to reorder") : "",
                                "class": "matchmaker" + " " + (matchmaker_collection.length === 1 ? "alone" : "")
                            }, {
                                "class": true,
                                "data-id": true,
                                title: false
                            }));
                            buf.push("><i");
                            buf.push(attrs({
                                "class": "type-icon " + app.meetme_types[mm.meeting_type || 0].icon_class
                            }, {
                                "class": true
                            }));
                            buf.push("></i>\n          <div");
                            buf.push(attrs({
                                "class": "text " + mode
                            }, {
                                "class": true
                            }));
                            buf.push('><span class="name">');
                            var __val__ = mm.name || MTN.t("Meeting with ") + user.name;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</span>");
                            var info = mm.meetme_hidden && mode === "edit" ? MTN.t("Private") : "";
                            if (mm.event_data && mm.event_data.force_available_timespans) {
                                {
                                    if (info) info += " / ";
                                    info += app.helpers.daySpanStringFromTimespans(mm.event_data.force_available_timespans, user.time_zone_offset);
                                }
                            }
                            if (info) {
                                buf.push('<span class="info">');
                                var __val__ = info;
                                buf.push(escape(null == __val__ ? "" : __val__));
                                buf.push("</span>");
                            }
                            buf.push("\n          </div>");
                            if (mode === "edit") {
                                buf.push("<span");
                                buf.push(attrs({
                                    title: MTN.t("Configure Meet Me page"),
                                    "data-name": mm.vanity_url_path || "default",
                                    "class": "button" + " " + "blue" + " " + "edit-scheduler"
                                }, {
                                    title: false,
                                    "data-name": true
                                }));
                                buf.push('><i class="ico-settings"></i></span><span');
                                buf.push(attrs({
                                    title: MTN.t("Remove Meet Me page"),
                                    "data-id": mm.id,
                                    "class": "button" + " " + "gray" + " " + "remove-scheduler"
                                }, {
                                    title: false,
                                    "data-id": true
                                }));
                                buf.push('><i class="ico-cross"></i></span>');
                            } else {
                                buf.push("<span");
                                buf.push(attrs({
                                    "data-id": mm.id || mm.cid,
                                    "class": "button" + " " + "blue" + " " + "open-scheduler"
                                }, {
                                    "data-id": true
                                }));
                                buf.push(">");
                                var __val__ = MTN.t("Schedule");
                                buf.push(null == __val__ ? "" : __val__);
                                buf.push("</span>");
                            }
                            buf.push("\n        </div>");
                        }
                    }
                }
            }).call(this);
            buf.push("\n      </div>");
        }
        buf.push("\n    </div>");
        if (mode === "edit") {
            if (matchmaker_collection.length) {
                buf.push('<a class="button blue new-scheduler"><i class="ico-add"></i>');
                var __val__ = MTN.t("Add new meeting scheduler");
                buf.push(null == __val__ ? "" : __val__);
                if (!(user.is_pro || _.filter(matchmaker_collection, function(o) {
                    return o.matchmaking_event_id > 0 ? false : true;
                }).length < 1)) {
                    buf.push('<span class="pro"></span>');
                }
                buf.push("</a>");
            } else {
                buf.push('<a class="button pink new-scheduler"><i class="ico-add"></i>');
                var __val__ = MTN.t("Start by adding your first meeting scheduler");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</a>");
            }
        }
        buf.push('\n  </div>\n  <div class="extra"></div>\n  <div style="clear:both;"></div>\n</div>');
    }
    return buf.join("");
};

// agentAbsences.jade compiled template
exports.agentAbsences = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="agent-absences" class="m-modal">\n  <div class="modal-header">\n    <h3> <i class="ico-profile"></i>');
        var __val__ = "Hallitse poissaoloja" || MTN.t("Manage absences");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n    </h3>\n  </div>\n  <div class="modal-content">');
        if (categories.length > 0) {
            {
                buf.push('\n    <div class="category-listing">');
                (function() {
                    if ("number" == typeof categories.length) {
                        for (var index = 0, $$l = categories.length; index < $$l; index++) {
                            var cat = categories[index];
                            if (cat == selected_category) {
                                {
                                    buf.push("<a");
                                    buf.push(attrs({
                                        href: "#",
                                        "x-data-category": cat,
                                        "class": "category-button-selected" + " " + "select-category"
                                    }, {
                                        href: true,
                                        "x-data-category": true
                                    }));
                                    buf.push(">");
                                    var __val__ = cat;
                                    buf.push(escape(null == __val__ ? "" : __val__));
                                    buf.push("</a>");
                                }
                            } else {
                                {
                                    buf.push("<a");
                                    buf.push(attrs({
                                        href: "#",
                                        "x-data-category": cat,
                                        "class": "category-button" + " " + "select-category"
                                    }, {
                                        href: true,
                                        "x-data-category": true
                                    }));
                                    buf.push(">");
                                    var __val__ = cat;
                                    buf.push(escape(null == __val__ ? "" : __val__));
                                    buf.push("</a>");
                                }
                            }
                            if (index < categories.length - 1) {
                                {
                                    var __val__ = " - ";
                                    buf.push(escape(null == __val__ ? "" : __val__));
                                }
                            }
                        }
                    } else {
                        var $$l = 0;
                        for (var index in categories) {
                            $$l++;
                            var cat = categories[index];
                            if (cat == selected_category) {
                                {
                                    buf.push("<a");
                                    buf.push(attrs({
                                        href: "#",
                                        "x-data-category": cat,
                                        "class": "category-button-selected" + " " + "select-category"
                                    }, {
                                        href: true,
                                        "x-data-category": true
                                    }));
                                    buf.push(">");
                                    var __val__ = cat;
                                    buf.push(escape(null == __val__ ? "" : __val__));
                                    buf.push("</a>");
                                }
                            } else {
                                {
                                    buf.push("<a");
                                    buf.push(attrs({
                                        href: "#",
                                        "x-data-category": cat,
                                        "class": "category-button" + " " + "select-category"
                                    }, {
                                        href: true,
                                        "x-data-category": true
                                    }));
                                    buf.push(">");
                                    var __val__ = cat;
                                    buf.push(escape(null == __val__ ? "" : __val__));
                                    buf.push("</a>");
                                }
                            }
                            if (index < categories.length - 1) {
                                {
                                    var __val__ = " - ";
                                    buf.push(escape(null == __val__ ? "" : __val__));
                                }
                            }
                        }
                    }
                }).call(this);
                buf.push("\n    </div>");
            }
        }
        buf.push('\n    <div class="agent-listing">');
        (function() {
            if ("number" == typeof agents.length) {
                for (var $index = 0, $$l = agents.length; $index < $$l; $index++) {
                    var agent = agents[$index];
                    buf.push("\n      <div");
                    buf.push(attrs({
                        id: "agent-" + agent.id,
                        "class": "agent-container"
                    }, {
                        id: true
                    }));
                    buf.push('>\n        <div class="agent-name-container">\n          <div');
                    buf.push(attrs({
                        title: agent.user_email,
                        "class": "agent-name"
                    }, {
                        title: true
                    }));
                    buf.push(">");
                    var __val__ = agent.user_name;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</div><a");
                    buf.push(attrs({
                        href: "#",
                        "x-data-agent-id": agent.id,
                        "class": "agent-button" + " " + "plus"
                    }, {
                        href: true,
                        "x-data-agent-id": true
                    }));
                    buf.push(">+ Lisää poissaolo</a><a");
                    buf.push(attrs({
                        href: "#",
                        "x-data-agent-id": agent.id,
                        style: "display:none",
                        "class": "agent-button" + " " + "minus"
                    }, {
                        href: true,
                        "x-data-agent-id": true,
                        style: true
                    }));
                    buf.push('>Piilota lisäys</a>\n        </div>\n        <div style="display:none" class="agent-absence-adder">\n          <label');
                    buf.push(attrs({
                        "for": "agent-first-day-" + agent.id,
                        "class": "small"
                    }, {
                        "for": true
                    }));
                    buf.push("><span>");
                    var __val__ = "Ensimmäinen päivä";
                    buf.push(null == __val__ ? "" : __val__);
                    buf.push("</span><span>");
                    var __val__ = " ";
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push('</span><span class="hint">');
                    var __val__ = "(VVVV-KK-PP)";
                    buf.push(null == __val__ ? "" : __val__);
                    buf.push("</span></label><br/>\n          <input");
                    buf.push(attrs({
                        id: "agent-first-day-" + agent.id,
                        size: 10,
                        "class": "first-day" + " " + "js_dmy_datepicker_input"
                    }, {
                        id: true,
                        size: true
                    }));
                    buf.push("/><br/>\n          <label");
                    buf.push(attrs({
                        "for": "agent-last-day-" + agent.id,
                        "class": "small"
                    }, {
                        "for": true
                    }));
                    buf.push("><span>");
                    var __val__ = "Viimeinen päivä";
                    buf.push(null == __val__ ? "" : __val__);
                    buf.push("</span><span>");
                    var __val__ = " ";
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push('</span><span class="hint">');
                    var __val__ = "(VVVV-KK-PP)";
                    buf.push(null == __val__ ? "" : __val__);
                    buf.push("</span></label><br/>\n          <input");
                    buf.push(attrs({
                        id: "agent-last-day-" + agent.id,
                        size: 10,
                        "class": "last-day" + " " + "js_dmy_datepicker_input"
                    }, {
                        id: true,
                        size: true
                    }));
                    buf.push("/><br/>\n          <label");
                    buf.push(attrs({
                        "for": "agent-reason-" + agent.id,
                        "class": "small"
                    }, {
                        "for": true
                    }));
                    buf.push(">");
                    var __val__ = "Selite";
                    buf.push(null == __val__ ? "" : __val__);
                    buf.push("</label><br/>\n          <input");
                    buf.push(attrs({
                        id: "agent-reason-" + agent.id,
                        size: 40,
                        "class": "reason"
                    }, {
                        id: true,
                        size: true
                    }));
                    buf.push("/><br/>\n          <button");
                    buf.push(attrs({
                        "x-data-agent-id": agent.id,
                        "class": "add-absence-button"
                    }, {
                        "x-data-agent-id": true
                    }));
                    buf.push(">");
                    var __val__ = "Lisää" || MTN.t("Add");
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push('</button>\n        </div>\n        <div class="agent-absence-list">');
                    (function() {
                        if ("number" == typeof agent.absences.length) {
                            for (var $index = 0, $$l = agent.absences.length; $index < $$l; $index++) {
                                var absence = agent.absences[$index];
                                buf.push("\n          <div");
                                buf.push(attrs({
                                    id: "absence-" + absence.id,
                                    "class": "absence-container"
                                }, {
                                    id: true
                                }));
                                buf.push('>\n            <div class="absence-title-container"><a');
                                buf.push(attrs({
                                    href: "#",
                                    "x-data-absence-id": absence.id,
                                    "x-data-agent-id": agent.id,
                                    "class": "remove-absence-button"
                                }, {
                                    href: true,
                                    "x-data-absence-id": true,
                                    "x-data-agent-id": true
                                }));
                                buf.push(">[Poista]</a>");
                                begin = moment.utc((parseInt(absence.begin_epoch) + (absence.begin_epoch < user.time_zone_dst_change_epoch ? user.time_zone_offset : user.time_zone_dst_offset)) * 1e3).format("DD.MM.YYYY");
                                end = moment.utc((parseInt(absence.end_epoch) - (absence.end_epoch < user.time_zone_dst_change_epoch ? user.time_zone_offset : user.time_zone_dst_offset)) * 1e3).format("DD.MM.YYYY");
                                buf.push('\n              <div class="absence-title">');
                                var __val__ = begin + " - " + end + ": " + absence.reason;
                                buf.push(escape(null == __val__ ? "" : __val__));
                                buf.push('</div>\n            </div>\n            <div class="absence-overlap-list">');
                                (function() {
                                    if ("number" == typeof absence.overlapping_meetings.length) {
                                        for (var $index = 0, $$l = absence.overlapping_meetings.length; $index < $$l; $index++) {
                                            var overlap = absence.overlapping_meetings[$index];
                                            buf.push('\n              <div class="absence-overlap-container">');
                                            begin = moment.utc((parseInt(overlap.begin_epoch) + (overlap.begin_epoch < user.time_zone_dst_change_epoch ? user.time_zone_offset : user.time_zone_dst_offset)) * 1e3).format("DD.MM.YYYY HH:mm");
                                            buf.push('\n                <div class="overlap-title"><span class="overlap-warning">');
                                            var __val__ = "!!! ";
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                            buf.push("</span><a");
                                            buf.push(attrs({
                                                href: overlap.enter_url
                                            }, {
                                                href: true
                                            }));
                                            buf.push(">");
                                            var __val__ = begin + ": " + overlap.title;
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                            buf.push("</a></div>\n              </div>");
                                        }
                                    } else {
                                        var $$l = 0;
                                        for (var $index in absence.overlapping_meetings) {
                                            $$l++;
                                            var overlap = absence.overlapping_meetings[$index];
                                            buf.push('\n              <div class="absence-overlap-container">');
                                            begin = moment.utc((parseInt(overlap.begin_epoch) + (overlap.begin_epoch < user.time_zone_dst_change_epoch ? user.time_zone_offset : user.time_zone_dst_offset)) * 1e3).format("DD.MM.YYYY HH:mm");
                                            buf.push('\n                <div class="overlap-title"><span class="overlap-warning">');
                                            var __val__ = "!!! ";
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                            buf.push("</span><a");
                                            buf.push(attrs({
                                                href: overlap.enter_url
                                            }, {
                                                href: true
                                            }));
                                            buf.push(">");
                                            var __val__ = begin + ": " + overlap.title;
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                            buf.push("</a></div>\n              </div>");
                                        }
                                    }
                                }).call(this);
                                buf.push("\n            </div>\n          </div>");
                            }
                        } else {
                            var $$l = 0;
                            for (var $index in agent.absences) {
                                $$l++;
                                var absence = agent.absences[$index];
                                buf.push("\n          <div");
                                buf.push(attrs({
                                    id: "absence-" + absence.id,
                                    "class": "absence-container"
                                }, {
                                    id: true
                                }));
                                buf.push('>\n            <div class="absence-title-container"><a');
                                buf.push(attrs({
                                    href: "#",
                                    "x-data-absence-id": absence.id,
                                    "x-data-agent-id": agent.id,
                                    "class": "remove-absence-button"
                                }, {
                                    href: true,
                                    "x-data-absence-id": true,
                                    "x-data-agent-id": true
                                }));
                                buf.push(">[Poista]</a>");
                                begin = moment.utc((parseInt(absence.begin_epoch) + (absence.begin_epoch < user.time_zone_dst_change_epoch ? user.time_zone_offset : user.time_zone_dst_offset)) * 1e3).format("DD.MM.YYYY");
                                end = moment.utc((parseInt(absence.end_epoch) - (absence.end_epoch < user.time_zone_dst_change_epoch ? user.time_zone_offset : user.time_zone_dst_offset)) * 1e3).format("DD.MM.YYYY");
                                buf.push('\n              <div class="absence-title">');
                                var __val__ = begin + " - " + end + ": " + absence.reason;
                                buf.push(escape(null == __val__ ? "" : __val__));
                                buf.push('</div>\n            </div>\n            <div class="absence-overlap-list">');
                                (function() {
                                    if ("number" == typeof absence.overlapping_meetings.length) {
                                        for (var $index = 0, $$l = absence.overlapping_meetings.length; $index < $$l; $index++) {
                                            var overlap = absence.overlapping_meetings[$index];
                                            buf.push('\n              <div class="absence-overlap-container">');
                                            begin = moment.utc((parseInt(overlap.begin_epoch) + (overlap.begin_epoch < user.time_zone_dst_change_epoch ? user.time_zone_offset : user.time_zone_dst_offset)) * 1e3).format("DD.MM.YYYY HH:mm");
                                            buf.push('\n                <div class="overlap-title"><span class="overlap-warning">');
                                            var __val__ = "!!! ";
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                            buf.push("</span><a");
                                            buf.push(attrs({
                                                href: overlap.enter_url
                                            }, {
                                                href: true
                                            }));
                                            buf.push(">");
                                            var __val__ = begin + ": " + overlap.title;
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                            buf.push("</a></div>\n              </div>");
                                        }
                                    } else {
                                        var $$l = 0;
                                        for (var $index in absence.overlapping_meetings) {
                                            $$l++;
                                            var overlap = absence.overlapping_meetings[$index];
                                            buf.push('\n              <div class="absence-overlap-container">');
                                            begin = moment.utc((parseInt(overlap.begin_epoch) + (overlap.begin_epoch < user.time_zone_dst_change_epoch ? user.time_zone_offset : user.time_zone_dst_offset)) * 1e3).format("DD.MM.YYYY HH:mm");
                                            buf.push('\n                <div class="overlap-title"><span class="overlap-warning">');
                                            var __val__ = "!!! ";
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                            buf.push("</span><a");
                                            buf.push(attrs({
                                                href: overlap.enter_url
                                            }, {
                                                href: true
                                            }));
                                            buf.push(">");
                                            var __val__ = begin + ": " + overlap.title;
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                            buf.push("</a></div>\n              </div>");
                                        }
                                    }
                                }).call(this);
                                buf.push("\n            </div>\n          </div>");
                            }
                        }
                    }).call(this);
                    buf.push("\n        </div>\n      </div>");
                }
            } else {
                var $$l = 0;
                for (var $index in agents) {
                    $$l++;
                    var agent = agents[$index];
                    buf.push("\n      <div");
                    buf.push(attrs({
                        id: "agent-" + agent.id,
                        "class": "agent-container"
                    }, {
                        id: true
                    }));
                    buf.push('>\n        <div class="agent-name-container">\n          <div');
                    buf.push(attrs({
                        title: agent.user_email,
                        "class": "agent-name"
                    }, {
                        title: true
                    }));
                    buf.push(">");
                    var __val__ = agent.user_name;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</div><a");
                    buf.push(attrs({
                        href: "#",
                        "x-data-agent-id": agent.id,
                        "class": "agent-button" + " " + "plus"
                    }, {
                        href: true,
                        "x-data-agent-id": true
                    }));
                    buf.push(">+ Lisää poissaolo</a><a");
                    buf.push(attrs({
                        href: "#",
                        "x-data-agent-id": agent.id,
                        style: "display:none",
                        "class": "agent-button" + " " + "minus"
                    }, {
                        href: true,
                        "x-data-agent-id": true,
                        style: true
                    }));
                    buf.push('>Piilota lisäys</a>\n        </div>\n        <div style="display:none" class="agent-absence-adder">\n          <label');
                    buf.push(attrs({
                        "for": "agent-first-day-" + agent.id,
                        "class": "small"
                    }, {
                        "for": true
                    }));
                    buf.push("><span>");
                    var __val__ = "Ensimmäinen päivä";
                    buf.push(null == __val__ ? "" : __val__);
                    buf.push("</span><span>");
                    var __val__ = " ";
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push('</span><span class="hint">');
                    var __val__ = "(VVVV-KK-PP)";
                    buf.push(null == __val__ ? "" : __val__);
                    buf.push("</span></label><br/>\n          <input");
                    buf.push(attrs({
                        id: "agent-first-day-" + agent.id,
                        size: 10,
                        "class": "first-day" + " " + "js_dmy_datepicker_input"
                    }, {
                        id: true,
                        size: true
                    }));
                    buf.push("/><br/>\n          <label");
                    buf.push(attrs({
                        "for": "agent-last-day-" + agent.id,
                        "class": "small"
                    }, {
                        "for": true
                    }));
                    buf.push("><span>");
                    var __val__ = "Viimeinen päivä";
                    buf.push(null == __val__ ? "" : __val__);
                    buf.push("</span><span>");
                    var __val__ = " ";
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push('</span><span class="hint">');
                    var __val__ = "(VVVV-KK-PP)";
                    buf.push(null == __val__ ? "" : __val__);
                    buf.push("</span></label><br/>\n          <input");
                    buf.push(attrs({
                        id: "agent-last-day-" + agent.id,
                        size: 10,
                        "class": "last-day" + " " + "js_dmy_datepicker_input"
                    }, {
                        id: true,
                        size: true
                    }));
                    buf.push("/><br/>\n          <label");
                    buf.push(attrs({
                        "for": "agent-reason-" + agent.id,
                        "class": "small"
                    }, {
                        "for": true
                    }));
                    buf.push(">");
                    var __val__ = "Selite";
                    buf.push(null == __val__ ? "" : __val__);
                    buf.push("</label><br/>\n          <input");
                    buf.push(attrs({
                        id: "agent-reason-" + agent.id,
                        size: 40,
                        "class": "reason"
                    }, {
                        id: true,
                        size: true
                    }));
                    buf.push("/><br/>\n          <button");
                    buf.push(attrs({
                        "x-data-agent-id": agent.id,
                        "class": "add-absence-button"
                    }, {
                        "x-data-agent-id": true
                    }));
                    buf.push(">");
                    var __val__ = "Lisää" || MTN.t("Add");
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push('</button>\n        </div>\n        <div class="agent-absence-list">');
                    (function() {
                        if ("number" == typeof agent.absences.length) {
                            for (var $index = 0, $$l = agent.absences.length; $index < $$l; $index++) {
                                var absence = agent.absences[$index];
                                buf.push("\n          <div");
                                buf.push(attrs({
                                    id: "absence-" + absence.id,
                                    "class": "absence-container"
                                }, {
                                    id: true
                                }));
                                buf.push('>\n            <div class="absence-title-container"><a');
                                buf.push(attrs({
                                    href: "#",
                                    "x-data-absence-id": absence.id,
                                    "x-data-agent-id": agent.id,
                                    "class": "remove-absence-button"
                                }, {
                                    href: true,
                                    "x-data-absence-id": true,
                                    "x-data-agent-id": true
                                }));
                                buf.push(">[Poista]</a>");
                                begin = moment.utc((parseInt(absence.begin_epoch) + (absence.begin_epoch < user.time_zone_dst_change_epoch ? user.time_zone_offset : user.time_zone_dst_offset)) * 1e3).format("DD.MM.YYYY");
                                end = moment.utc((parseInt(absence.end_epoch) - (absence.end_epoch < user.time_zone_dst_change_epoch ? user.time_zone_offset : user.time_zone_dst_offset)) * 1e3).format("DD.MM.YYYY");
                                buf.push('\n              <div class="absence-title">');
                                var __val__ = begin + " - " + end + ": " + absence.reason;
                                buf.push(escape(null == __val__ ? "" : __val__));
                                buf.push('</div>\n            </div>\n            <div class="absence-overlap-list">');
                                (function() {
                                    if ("number" == typeof absence.overlapping_meetings.length) {
                                        for (var $index = 0, $$l = absence.overlapping_meetings.length; $index < $$l; $index++) {
                                            var overlap = absence.overlapping_meetings[$index];
                                            buf.push('\n              <div class="absence-overlap-container">');
                                            begin = moment.utc((parseInt(overlap.begin_epoch) + (overlap.begin_epoch < user.time_zone_dst_change_epoch ? user.time_zone_offset : user.time_zone_dst_offset)) * 1e3).format("DD.MM.YYYY HH:mm");
                                            buf.push('\n                <div class="overlap-title"><span class="overlap-warning">');
                                            var __val__ = "!!! ";
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                            buf.push("</span><a");
                                            buf.push(attrs({
                                                href: overlap.enter_url
                                            }, {
                                                href: true
                                            }));
                                            buf.push(">");
                                            var __val__ = begin + ": " + overlap.title;
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                            buf.push("</a></div>\n              </div>");
                                        }
                                    } else {
                                        var $$l = 0;
                                        for (var $index in absence.overlapping_meetings) {
                                            $$l++;
                                            var overlap = absence.overlapping_meetings[$index];
                                            buf.push('\n              <div class="absence-overlap-container">');
                                            begin = moment.utc((parseInt(overlap.begin_epoch) + (overlap.begin_epoch < user.time_zone_dst_change_epoch ? user.time_zone_offset : user.time_zone_dst_offset)) * 1e3).format("DD.MM.YYYY HH:mm");
                                            buf.push('\n                <div class="overlap-title"><span class="overlap-warning">');
                                            var __val__ = "!!! ";
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                            buf.push("</span><a");
                                            buf.push(attrs({
                                                href: overlap.enter_url
                                            }, {
                                                href: true
                                            }));
                                            buf.push(">");
                                            var __val__ = begin + ": " + overlap.title;
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                            buf.push("</a></div>\n              </div>");
                                        }
                                    }
                                }).call(this);
                                buf.push("\n            </div>\n          </div>");
                            }
                        } else {
                            var $$l = 0;
                            for (var $index in agent.absences) {
                                $$l++;
                                var absence = agent.absences[$index];
                                buf.push("\n          <div");
                                buf.push(attrs({
                                    id: "absence-" + absence.id,
                                    "class": "absence-container"
                                }, {
                                    id: true
                                }));
                                buf.push('>\n            <div class="absence-title-container"><a');
                                buf.push(attrs({
                                    href: "#",
                                    "x-data-absence-id": absence.id,
                                    "x-data-agent-id": agent.id,
                                    "class": "remove-absence-button"
                                }, {
                                    href: true,
                                    "x-data-absence-id": true,
                                    "x-data-agent-id": true
                                }));
                                buf.push(">[Poista]</a>");
                                begin = moment.utc((parseInt(absence.begin_epoch) + (absence.begin_epoch < user.time_zone_dst_change_epoch ? user.time_zone_offset : user.time_zone_dst_offset)) * 1e3).format("DD.MM.YYYY");
                                end = moment.utc((parseInt(absence.end_epoch) - (absence.end_epoch < user.time_zone_dst_change_epoch ? user.time_zone_offset : user.time_zone_dst_offset)) * 1e3).format("DD.MM.YYYY");
                                buf.push('\n              <div class="absence-title">');
                                var __val__ = begin + " - " + end + ": " + absence.reason;
                                buf.push(escape(null == __val__ ? "" : __val__));
                                buf.push('</div>\n            </div>\n            <div class="absence-overlap-list">');
                                (function() {
                                    if ("number" == typeof absence.overlapping_meetings.length) {
                                        for (var $index = 0, $$l = absence.overlapping_meetings.length; $index < $$l; $index++) {
                                            var overlap = absence.overlapping_meetings[$index];
                                            buf.push('\n              <div class="absence-overlap-container">');
                                            begin = moment.utc((parseInt(overlap.begin_epoch) + (overlap.begin_epoch < user.time_zone_dst_change_epoch ? user.time_zone_offset : user.time_zone_dst_offset)) * 1e3).format("DD.MM.YYYY HH:mm");
                                            buf.push('\n                <div class="overlap-title"><span class="overlap-warning">');
                                            var __val__ = "!!! ";
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                            buf.push("</span><a");
                                            buf.push(attrs({
                                                href: overlap.enter_url
                                            }, {
                                                href: true
                                            }));
                                            buf.push(">");
                                            var __val__ = begin + ": " + overlap.title;
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                            buf.push("</a></div>\n              </div>");
                                        }
                                    } else {
                                        var $$l = 0;
                                        for (var $index in absence.overlapping_meetings) {
                                            $$l++;
                                            var overlap = absence.overlapping_meetings[$index];
                                            buf.push('\n              <div class="absence-overlap-container">');
                                            begin = moment.utc((parseInt(overlap.begin_epoch) + (overlap.begin_epoch < user.time_zone_dst_change_epoch ? user.time_zone_offset : user.time_zone_dst_offset)) * 1e3).format("DD.MM.YYYY HH:mm");
                                            buf.push('\n                <div class="overlap-title"><span class="overlap-warning">');
                                            var __val__ = "!!! ";
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                            buf.push("</span><a");
                                            buf.push(attrs({
                                                href: overlap.enter_url
                                            }, {
                                                href: true
                                            }));
                                            buf.push(">");
                                            var __val__ = begin + ": " + overlap.title;
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                            buf.push("</a></div>\n              </div>");
                                        }
                                    }
                                }).call(this);
                                buf.push("\n            </div>\n          </div>");
                            }
                        }
                    }).call(this);
                    buf.push("\n        </div>\n      </div>");
                }
            }
        }).call(this);
        buf.push("\n    </div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// userProfile.jade compiled template
exports.userProfile = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="profile-wizard" class="m-modal">\n  <div class="modal-header">\n    <h3> <i class="ico-profile"></i>');
        var __val__ = MTN.t("Provide your contact details");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n    </h3>\n  </div>\n  <div class="modal-content">');
        if (typeof meetme_explain !== "undefined") {
            buf.push('\n    <p class="note">');
            var __val__ = MTN.t("%(B$One last thing:%) please provide some basic information of yourself. We will create a profile for you and let %1$s know who you are.", [ lock.accepter_name ]);
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>");
        }
        buf.push('\n    <div id="edit-profile-container">\n      <form class="meetings-form">\n        <input id="draft_id" type="hidden" name="draft_id"/>\n        <input id="event_id" type="hidden" name="event_id"/>\n        <div id="profile-edit-section">\n          <div id="photo-container">\n            <div class="profile-image-wrap"><img');
        buf.push(attrs({
            id: "profile-image",
            src: user.image,
            style: user.image ? "" : "display: none"
        }, {
            src: true,
            style: true
        }));
        buf.push('/></div><a id="upload-button" class="button blue"> <span class="text">');
        var __val__ = MTN.t("Upload photo");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</span>\n              <input id="fileupload" type="file" name="file"/></a>\n          </div>\n          <div class="form-row">\n            <label for="email" class="smaller">');
        var __val__ = MTN.t("Email");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</label>");
        var email_str = user.email || locals.suggestEmail || "";
        buf.push("\n            <input");
        buf.push(attrs({
            id: "profile-email",
            type: "text",
            name: "email",
            value: email_str
        }, {
            type: true,
            name: true,
            value: true
        }));
        buf.push('/><span class="required">*</span>\n          </div>\n          <div class="form-row">\n            <label for="first_name" class="smaller">');
        var __val__ = MTN.t("First name");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</label>\n            <input");
        buf.push(attrs({
            id: "profile-first-name",
            type: "text",
            name: "first_name",
            value: user.first_name
        }, {
            type: true,
            name: true,
            value: true
        }));
        buf.push('/><span class="required">*</span>\n          </div>\n          <div class="form-row">\n            <label for="last_name" class="smaller">');
        var __val__ = MTN.t("Last name");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</label>\n            <input");
        buf.push(attrs({
            id: "profile-last-name",
            type: "text",
            name: "last_name",
            value: user.last_name
        }, {
            type: true,
            name: true,
            value: true
        }));
        buf.push('/><span class="required">*</span>\n          </div>\n          <div class="form-row">\n            <label for="organization" class="smaller">');
        var __val__ = MTN.t("Organization");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</label>\n            <input");
        buf.push(attrs({
            id: "profile-organization",
            type: "text",
            name: "organization",
            value: user.organization
        }, {
            type: true,
            name: true,
            value: true
        }));
        buf.push('/><span class="required">*</span>\n          </div>\n          <div class="form-row">\n            <label for="organization_title" class="smaller">');
        var __val__ = MTN.t("Title//context:organizational title");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</label>\n            <input");
        buf.push(attrs({
            id: "profile-organization-title",
            type: "text",
            name: "organization_title",
            value: user.organization_title
        }, {
            type: true,
            name: true,
            value: true
        }));
        buf.push('/>\n          </div>\n          <div class="form-row">\n            <label for="phone" class="smaller">');
        var __val__ = MTN.t("Phone");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</label>\n            <input");
        buf.push(attrs({
            id: "profile-phone",
            type: "text",
            name: "phone",
            value: user.phone
        }, {
            type: true,
            name: true,
            value: true
        }));
        buf.push('/>\n          </div>\n          <div class="form-row">\n            <label for="skype" class="smaller">');
        var __val__ = MTN.t("Skype");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</label>\n            <input");
        buf.push(attrs({
            id: "profile-skype",
            type: "text",
            name: "skype",
            value: user.skype
        }, {
            type: true,
            name: true,
            value: true
        }));
        buf.push('/>\n          </div>\n          <div class="form-row">\n            <label for="linkedin" class="smaller">');
        var __val__ = MTN.t("LinkedIn");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</label>\n            <input");
        buf.push(attrs({
            id: "profile-linkedin",
            style: "width:258px;",
            type: "text",
            name: "linkedin",
            value: user.linkedin,
            placeholder: MTN.t("Copy & paste your LinkedIn URL here")
        }, {
            style: true,
            type: true,
            name: true,
            value: true,
            placeholder: false
        }));
        buf.push('/>\n          </div>\n          <div class="form-row last">\n            <label for="timezone" class="smaller">');
        var __val__ = MTN.t("Time zone");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</label>");
        var ua_tz_name = jstz.determine_timezone().name();
        var tz_data = dicole.get_global_variable("meetings_time_zone_data");
        var tz_offset = tz_data.data[ua_tz_name].offset_value;
        buf.push('\n            <select id="timezone-select" style="width:270px;" name="timezone" class="chosen">');
        (function() {
            if ("number" == typeof tz_data.choices.length) {
                for (var i = 0, $$l = tz_data.choices.length; i < $$l; i++) {
                    var tz = tz_data.choices[i];
                    if (tz === ua_tz_name) {
                        buf.push("\n              <option");
                        buf.push(attrs({
                            value: tz,
                            selected: "selected"
                        }, {
                            value: true,
                            selected: true
                        }));
                        buf.push(">");
                        var __val__ = tz_data.data[tz].readable_name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    } else {
                        buf.push("\n              <option");
                        buf.push(attrs({
                            value: tz
                        }, {
                            value: true
                        }));
                        buf.push(">");
                        var __val__ = tz_data.data[tz].readable_name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    }
                }
            } else {
                var $$l = 0;
                for (var i in tz_data.choices) {
                    $$l++;
                    var tz = tz_data.choices[i];
                    if (tz === ua_tz_name) {
                        buf.push("\n              <option");
                        buf.push(attrs({
                            value: tz,
                            selected: "selected"
                        }, {
                            value: true,
                            selected: true
                        }));
                        buf.push(">");
                        var __val__ = tz_data.data[tz].readable_name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    } else {
                        buf.push("\n              <option");
                        buf.push(attrs({
                            value: tz
                        }, {
                            value: true
                        }));
                        buf.push(">");
                        var __val__ = tz_data.data[tz].readable_name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    }
                }
            }
        }).call(this);
        buf.push('\n            </select>\n            <p class="time">');
        var __val__ = MTN.t("Time for this time zone:");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('<span id="current-time">');
        var __val__ = moment.utc(moment.utc().valueOf() + tz_offset * 1e3).format("hh:mm A");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</span></p>\n          </div>\n          <div style="clear:both;"></div>\n        </div>\n      </form>\n    </div>\n  </div>\n  <div class="modal-footer">\n    <div class="buttons left">\n      <p>');
        var __val__ = MTN.t("By continuing you accept the %(L$Terms of Service%).", {
            L: {
                href: "http://www.meetin.gs/terms-of-service/",
                target: "_blank"
            }
        });
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n    </div>\n    <div class="buttons right"><a class="save js-save-profile button blue">');
        var __val__ = MTN.t("Save");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// meetingMaterials.jade compiled template
exports.meetingMaterials = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        if (materials && materials.length) {
            (function() {
                if ("number" == typeof materials.length) {
                    for (var $index = 0, $$l = materials.length; $index < $$l; $index++) {
                        var material = materials[$index];
                        buf.push("<a");
                        buf.push(attrs({
                            href: material.data_url,
                            "class": "js_" + material.fetch_type + " material-item js_material_link"
                        }, {
                            "class": true,
                            href: true
                        }));
                        buf.push("><i");
                        buf.push(attrs({
                            "class": "ico-material_" + material.type_class
                        }, {
                            "class": true
                        }));
                        buf.push('></i>\n  <div class="title-container"><span class="material-title">');
                        var __val__ = dicole.meetings_common.truncate_text(material.title, 40);
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</span></div>");
                        if (material.comment_count > 0) {
                            buf.push('<span class="material-comments">');
                            var __val__ = material.comment_count;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</span>");
                        }
                        buf.push("</a>");
                    }
                } else {
                    var $$l = 0;
                    for (var $index in materials) {
                        $$l++;
                        var material = materials[$index];
                        buf.push("<a");
                        buf.push(attrs({
                            href: material.data_url,
                            "class": "js_" + material.fetch_type + " material-item js_material_link"
                        }, {
                            "class": true,
                            href: true
                        }));
                        buf.push("><i");
                        buf.push(attrs({
                            "class": "ico-material_" + material.type_class
                        }, {
                            "class": true
                        }));
                        buf.push('></i>\n  <div class="title-container"><span class="material-title">');
                        var __val__ = dicole.meetings_common.truncate_text(material.title, 40);
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</span></div>");
                        if (material.comment_count > 0) {
                            buf.push('<span class="material-comments">');
                            var __val__ = material.comment_count;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</span>");
                        }
                        buf.push("</a>");
                    }
                }
            }).call(this);
        } else {
            buf.push('\n<p class="no-material-message">');
            var __val__ = MTN.t("No material for this meeting.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>");
        }
    }
    return buf.join("");
};

// meetingLctCustomUrl.jade compiled template
exports.meetingLctCustomUrl = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="lct-picker" class="m-modal">\n  <div class="modal-header back-button">\n    <h3>');
        var __val__ = MTN.t("Custom URL settings");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3><i class="ico-leftarrow back"></i>\n  </div>\n  <div class="modal-content m-form">\n    <p>');
        var __val__ = MTN.t("Enter a link with instructions for joining the meeting with your custom tool.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</p>\n    <label>");
        var __val__ = MTN.t("Web address (URL)");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("\n      <input");
        buf.push(attrs({
            id: "com-custom-uri",
            type: "text",
            value: meeting.online_conferencing_data && meeting.online_conferencing_data.custom_uri ? meeting.online_conferencing_data.custom_uri : "",
            placeholder: MTN.t("Copy the URL here")
        }, {
            type: true,
            value: true,
            placeholder: false
        }));
        buf.push("/></label>\n    <label>");
        var __val__ = MTN.t("Name of the tool");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("\n      <input");
        buf.push(attrs({
            id: "com-custom-name",
            type: "text",
            value: meeting.online_conferencing_data && meeting.online_conferencing_data.custom_name ? meeting.online_conferencing_data.custom_name : "",
            placeholder: ""
        }, {
            type: true,
            value: true,
            placeholder: true
        }));
        buf.push("/></label>\n    <label>");
        var __val__ = MTN.t("Tool instructions for participants");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</label>\n    <textarea id="com-custom-description">');
        var __val__ = meeting.online_conferencing_data && meeting.online_conferencing_data.custom_description ? meeting.online_conferencing_data.custom_description : "";
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</textarea>\n  </div>\n  <div class="modal-footer">\n    <div class="buttons right"><a href="#" class="button blue save">');
        var __val__ = MTN.t("Save");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// meetmeEditDescription.jade compiled template
exports.meetmeEditDescription = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="meetme-edit-description" class="m-modal">\n  <div class="modal-header">\n    <h3>');
        var __val__ = MTN.t("Edit welcoming text");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3>\n  </div>\n  <div class="modal-content m-form">\n    <textarea id="meetme-description">');
        var __val__ = user.meetme_description || MTN.t("Hello! I have made my calendar available to you. Please click on the button below to start scheduling the meeting.");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</textarea>\n  </div>\n  <div class="modal-footer">\n    <div class="buttons right"><a id="save-description" class="button blue">');
        var __val__ = MTN.t("Save");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a><a class="button gray js_hook_showcase_close">');
        var __val__ = MTN.t("Cancel");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// browserWarning.jade compiled template
exports.browserWarning = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div class="browser-warning">\n  <div class="browser-warning-content">\n    <p>');
        var __val__ = MTN.t("Please note that Meetin.gs might still have some problems with your browser. If possible, please consider using a more modern browser while we fix things.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</p>\n  </div>\n</div>");
    }
    return buf.join("");
};

// wizardProfile.jade compiled template
exports.wizardProfile = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="profile-wizard" class="m-modal">\n  <div class="modal-header">\n    <h3> <i class="ico-profile"></i>');
        var __val__ = MTN.t("Provide your details");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n    </h3>\n  </div>\n  <div class="modal-content">\n    <div id="edit-profile-container">\n      <form class="meetings-form">\n        <input id="draft_id" type="hidden" name="draft_id"/>\n        <input id="event_id" type="hidden" name="event_id"/>\n        <div');
        buf.push(attrs({
            id: "facebook-form-fill-section",
            style: openProfile ? "display: none" : ""
        }, {
            style: true
        }));
        buf.push('>\n          <div id="social-logins"><a id="login-google" href="#" class="button"><img id="google-signup-image" src="/images/meetings/btn_google_signin_dark_normal_web.png"/></a></div>\n          <div id="manual-config-text">\n            <p> <a href="#" class="open-profile-form">');
        var __val__ = MTN.t("Do not connect - provide your information manually.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></p>\n          </div>\n        </div>\n        <div");
        buf.push(attrs({
            id: "profile-edit-section",
            style: openProfile ? "" : "display: none"
        }, {
            style: true
        }));
        buf.push('>\n          <div id="photo-container">\n            <div class="profile-image-wrap"><img');
        buf.push(attrs({
            id: "profile-image",
            src: model.image,
            style: model.image ? "" : "display: none"
        }, {
            src: true,
            style: true
        }));
        buf.push('/></div><a id="upload-button" class="button blue"> <span class="text">');
        var __val__ = MTN.t("Upload photo");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</span>\n              <input id="fileupload" type="file" name="file"/></a>\n          </div>\n          <div class="form-row">\n            <label for="email" class="smaller">');
        var __val__ = MTN.t("Email");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</label>");
        var email_str = model.email || locals.suggestEmail || "";
        if (lockEmail) {
            buf.push("\n            <input");
            buf.push(attrs({
                id: "profile-email",
                type: "text",
                disabled: "disabled",
                value: email_str
            }, {
                type: true,
                disabled: true,
                value: true
            }));
            buf.push("/>\n            <input");
            buf.push(attrs({
                type: "hidden",
                value: email_str,
                name: "email"
            }, {
                type: true,
                value: true,
                name: true
            }));
            buf.push("/>");
        } else {
            buf.push("\n            <input");
            buf.push(attrs({
                id: "profile-email",
                type: "text",
                name: "email",
                value: email_str
            }, {
                type: true,
                name: true,
                value: true
            }));
            buf.push("/>");
        }
        buf.push('<span class="required">*</span>\n          </div>\n          <div class="form-row">\n            <label for="first_name" class="smaller">');
        var __val__ = MTN.t("First name");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</label>\n            <input");
        buf.push(attrs({
            id: "profile-first-name",
            type: "text",
            name: "first_name",
            value: model.first_name
        }, {
            type: true,
            name: true,
            value: true
        }));
        buf.push('/><span class="required">*</span>\n          </div>\n          <div class="form-row">\n            <label for="last_name" class="smaller">');
        var __val__ = MTN.t("Last name");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</label>\n            <input");
        buf.push(attrs({
            id: "profile-last-name",
            type: "text",
            name: "last_name",
            value: model.last_name
        }, {
            type: true,
            name: true,
            value: true
        }));
        buf.push('/><span class="required">*</span>\n          </div>\n          <div class="form-row">\n            <label for="organization" class="smaller">');
        var __val__ = MTN.t("Organization");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</label>\n            <input");
        buf.push(attrs({
            id: "profile-organization",
            type: "text",
            name: "organization",
            value: model.organization
        }, {
            type: true,
            name: true,
            value: true
        }));
        buf.push('/><span class="required">*</span>\n          </div>\n          <div class="form-row">\n            <label for="organization_title" class="smaller">');
        var __val__ = MTN.t("Title//context:organizational title");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</label>\n            <input");
        buf.push(attrs({
            id: "profile-organization-title",
            type: "text",
            name: "organization_title",
            value: model.organization_title
        }, {
            type: true,
            name: true,
            value: true
        }));
        buf.push('/>\n          </div>\n          <div class="form-row">\n            <label for="phone" class="smaller">');
        var __val__ = MTN.t("Phone");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</label>\n            <input");
        buf.push(attrs({
            id: "profile-phone",
            type: "text",
            name: "phone",
            value: model.phone
        }, {
            type: true,
            name: true,
            value: true
        }));
        buf.push('/>\n          </div>\n          <div class="form-row">\n            <label for="skype" class="smaller">');
        var __val__ = MTN.t("Skype");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</label>\n            <input");
        buf.push(attrs({
            id: "profile-skype",
            type: "text",
            name: "skype",
            value: model.skype
        }, {
            type: true,
            name: true,
            value: true
        }));
        buf.push('/>\n          </div>\n          <div class="form-row">\n            <label for="linkedin" class="smaller">');
        var __val__ = MTN.t("LinkedIn");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</label>\n            <input");
        buf.push(attrs({
            id: "profile-linkedin",
            style: "width:258px;",
            type: "text",
            name: "linkedin",
            value: model.linkedin,
            placeholder: MTN.t("Copy & paste your LinkedIn URL here")
        }, {
            style: true,
            type: true,
            name: true,
            value: true,
            placeholder: false
        }));
        buf.push('/>\n          </div>\n          <div class="form-row">\n            <label for="timezone" class="smaller">');
        var __val__ = MTN.t("Time zone");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</label>");
        var ua_tz = app.options.ua_time_zone.name();
        var tz_data = dicole.get_global_variable("meetings_time_zone_data");
        buf.push('\n            <select id="timezone-select" style="width:270px;" name="timezone" class="chosen">');
        (function() {
            if ("number" == typeof tz_data.choices.length) {
                for (var i = 0, $$l = tz_data.choices.length; i < $$l; i++) {
                    var tz = tz_data.choices[i];
                    if (tz === ua_tz) {
                        buf.push("\n              <option");
                        buf.push(attrs({
                            value: tz,
                            selected: "selected"
                        }, {
                            value: true,
                            selected: true
                        }));
                        buf.push(">");
                        var __val__ = tz_data.data[tz].readable_name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    } else {
                        buf.push("\n              <option");
                        buf.push(attrs({
                            value: tz
                        }, {
                            value: true
                        }));
                        buf.push(">");
                        var __val__ = tz_data.data[tz].readable_name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    }
                }
            } else {
                var $$l = 0;
                for (var i in tz_data.choices) {
                    $$l++;
                    var tz = tz_data.choices[i];
                    if (tz === ua_tz) {
                        buf.push("\n              <option");
                        buf.push(attrs({
                            value: tz,
                            selected: "selected"
                        }, {
                            value: true,
                            selected: true
                        }));
                        buf.push(">");
                        var __val__ = tz_data.data[tz].readable_name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    } else {
                        buf.push("\n              <option");
                        buf.push(attrs({
                            value: tz
                        }, {
                            value: true
                        }));
                        buf.push(">");
                        var __val__ = tz_data.data[tz].readable_name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    }
                }
            }
        }).call(this);
        buf.push('\n            </select>\n            <p class="time">');
        var __val__ = MTN.t("Time for this time zone:");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('<span id="current-time">');
        var __val__ = moment.utc(d.getTime() + ua_tz_offset_value * 1e3).format("hh:mm A");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</span></p>\n          </div>\n          <div class="form-row last">\n            <label style="width:100%">\n              <input type="checkbox" checked="checked" style="margin-right:15px" class="newsletter"/>');
        var __val__ = MTN.t("Subscribe to our newsletter to receive important service updates");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n            </label>\n          </div>\n          <div style="clear:both;"></div>\n        </div>\n      </form>\n    </div>\n  </div>\n  <div class="modal-footer">\n    <div class="buttons left">\n      <p>');
        var __val__ = MTN.t("By continuing you accept the %(L$Terms of Service%).", {
            L: {
                href: "http://www.meetin.gs/terms-of-service/",
                target: "_blank"
            }
        });
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n    </div>\n    <div class="buttons right"><a');
        buf.push(attrs({
            style: openProfile ? "" : "display: none",
            "class": "save-profile-data" + " " + "button" + " " + "blue"
        }, {
            style: true
        }));
        buf.push(">");
        var __val__ = MTN.t("Save & continue");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// verifyTimezone.jade compiled template
exports.verifyTimezone = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="meetme-timezone-popup" class="m-modal">\n  <div class="modal-header">\n    <h3>');
        var __val__ = MTN.t("Check your time zone");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3>\n  </div>\n  <div class="modal-content">\n    <p>');
        var __val__ = MTN.t("Your currently chosen time zone is different from your device time zone. Which time zone would you like to use?");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n    <div class="m-form">\n      <label class="radio">\n        <input');
        buf.push(attrs({
            type: "radio",
            name: "tzname",
            checked: "checked",
            value: ua_tz
        }, {
            type: true,
            name: true,
            checked: true,
            value: true
        }));
        buf.push("/>");
        var __val__ = MTN.t("Your device's time zone") + " ";
        buf.push(null == __val__ ? "" : __val__);
        var __val__ = tz_data[ua_tz].readable_name;
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('\n      </label>\n      <p class="now">');
        var __val__ = MTN.t("Current time for this zone is:") + " ";
        buf.push(null == __val__ ? "" : __val__);
        buf.push("<span>");
        var __val__ = moment.utc(d.getTime() + tz_data[ua_tz].offset_value * 1e3).format("hh:mm A");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</span>\n      </p>\n      <p class="radio">\n        <input');
        buf.push(attrs({
            id: "user-tz",
            type: "radio",
            name: "tzname",
            value: tz_data[user_tz].name
        }, {
            type: true,
            name: true,
            value: true
        }));
        buf.push("/>");
        var __val__ = MTN.t("Your time zone setting") + " ";
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n        <select id="timezone-select" class="chosen">');
        (function() {
            if ("number" == typeof tz_choices.length) {
                for (var i = 0, $$l = tz_choices.length; i < $$l; i++) {
                    var tz = tz_choices[i];
                    if (tz === user_tz) {
                        buf.push("\n          <option");
                        buf.push(attrs({
                            value: tz_data[tz].name,
                            selected: "selected"
                        }, {
                            value: true,
                            selected: true
                        }));
                        buf.push(">");
                        var __val__ = tz_data[tz].readable_name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    } else {
                        buf.push("\n          <option");
                        buf.push(attrs({
                            value: tz_data[tz].name
                        }, {
                            value: true
                        }));
                        buf.push(">");
                        var __val__ = tz_data[tz].readable_name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    }
                }
            } else {
                var $$l = 0;
                for (var i in tz_choices) {
                    $$l++;
                    var tz = tz_choices[i];
                    if (tz === user_tz) {
                        buf.push("\n          <option");
                        buf.push(attrs({
                            value: tz_data[tz].name,
                            selected: "selected"
                        }, {
                            value: true,
                            selected: true
                        }));
                        buf.push(">");
                        var __val__ = tz_data[tz].readable_name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    } else {
                        buf.push("\n          <option");
                        buf.push(attrs({
                            value: tz_data[tz].name
                        }, {
                            value: true
                        }));
                        buf.push(">");
                        var __val__ = tz_data[tz].readable_name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    }
                }
            }
        }).call(this);
        buf.push('\n        </select>\n      </p>\n      <p class="now">');
        var __val__ = MTN.t("Current time for this zone is:") + " ";
        buf.push(null == __val__ ? "" : __val__);
        buf.push('<span id="user-time">');
        var __val__ = moment.utc(d.getTime() + tz_data[user_tz].offset_value * 1e3).format("hh:mm A");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</span>\n      </p>\n    </div>\n  </div>\n  <div class="modal-footer">\n    <div class="buttons right"><a href="#" class="change-timezone button blue">');
        var __val__ = MTN.t("Continue");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// userSettings.jade compiled template
exports.userSettings = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div class="user-settings">\n  <div class="menu"><a');
        buf.push(attrs({
            href: "/meetings/user/settings/login",
            "class": "menu-link" + " " + "login" + " " + (mode === "login" ? "selected" : "")
        }, {
            "class": true,
            href: true
        }));
        buf.push(">");
        var __val__ = MTN.t("Login methods");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a>");
        if (!dicole.get_global_variable("meetings_user_is_visitor")) {
            buf.push("<a");
            buf.push(attrs({
                href: "/meetings/user/settings/calendar",
                "class": "menu-link" + " " + "calendar" + " " + (mode === "calendar" ? "selected" : "")
            }, {
                "class": true,
                href: true
            }));
            buf.push(">");
            var __val__ = MTN.t("Calendar integration");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a><a");
            buf.push(attrs({
                href: "/meetings/user/settings/timeline",
                "class": "menu-link" + " " + "timeline" + " " + (mode === "timeline" ? "selected" : "")
            }, {
                "class": true,
                href: true
            }));
            buf.push(">");
            var __val__ = MTN.t("Timeline");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a>");
        }
        buf.push("<a");
        buf.push(attrs({
            href: "/meetings/user/settings/regional",
            "class": "menu-link" + " " + "timezone" + " " + (mode === "regional" ? "selected" : "")
        }, {
            "class": true,
            href: true
        }));
        buf.push(">");
        var __val__ = MTN.t("Regional");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a>");
        if (!dicole.get_global_variable("meetings_user_is_visitor")) {
            buf.push("<a");
            buf.push(attrs({
                href: "/meetings/user/settings/branding",
                "class": "menu-link" + " " + "branding" + " " + (mode === "branding" ? "selected" : "")
            }, {
                "class": true,
                href: true
            }));
            buf.push(">");
            var __val__ = MTN.t("Branding");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a>");
        }
        buf.push("<a");
        buf.push(attrs({
            href: "/meetings/user/settings/account",
            "class": "menu-link" + " " + "account" + " " + (mode === "account" ? "selected" : "")
        }, {
            "class": true,
            href: true
        }));
        buf.push(">");
        var __val__ = MTN.t("Account");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a>\n  </div>\n  <div class="settings-container"></div>\n</div>');
    }
    return buf.join("");
};

// meetmeMatchmakerSelect.jade compiled template
exports.meetmeMatchmakerSelect = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push("\n<p>");
        var __val__ = MTN.t("Meet Me page");
        buf.push(null == __val__ ? "" : __val__);
        if (mode === "edit") {
            buf.push('\n  <input id="mm-name" type="text"/><a id="mm-add" href="#">');
            var __val__ = MTN.t("Add");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a>");
        } else if (mode === "disabled") {
            buf.push('\n  <select id="mm-select" style="width:200px;" disabled="disabled" class="chosen">\n    <option value="0">');
            var __val__ = MTN.t("--- Select ---");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</option>");
            (function() {
                if ("number" == typeof matchmakers.models.length) {
                    for (var $index = 0, $$l = matchmakers.models.length; $index < $$l; $index++) {
                        var mm = matchmakers.models[$index];
                        var id = mm.id || mm.cid;
                        if (id == current_mm) {
                            buf.push("\n    <option");
                            buf.push(attrs({
                                value: id,
                                selected: "selected"
                            }, {
                                value: true,
                                selected: true
                            }));
                            buf.push(">");
                            var __val__ = mm.get("name") || MTN.t("Main Meet me page");
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</option>");
                        } else {
                            buf.push("\n    <option");
                            buf.push(attrs({
                                value: id
                            }, {
                                value: true
                            }));
                            buf.push(">");
                            var __val__ = mm.get("name") || MTN.t("Main Meet me page");
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</option>");
                        }
                    }
                } else {
                    var $$l = 0;
                    for (var $index in matchmakers.models) {
                        $$l++;
                        var mm = matchmakers.models[$index];
                        var id = mm.id || mm.cid;
                        if (id == current_mm) {
                            buf.push("\n    <option");
                            buf.push(attrs({
                                value: id,
                                selected: "selected"
                            }, {
                                value: true,
                                selected: true
                            }));
                            buf.push(">");
                            var __val__ = mm.get("name") || MTN.t("Main Meet me page");
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</option>");
                        } else {
                            buf.push("\n    <option");
                            buf.push(attrs({
                                value: id
                            }, {
                                value: true
                            }));
                            buf.push(">");
                            var __val__ = mm.get("name") || MTN.t("Main Meet me page");
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</option>");
                        }
                    }
                }
            }).call(this);
            buf.push("\n  </select>");
        } else {
            buf.push('\n  <select id="mm-select" style="width:200px;" class="chosen">\n    <option value="0">');
            var __val__ = MTN.t("--- Select ---");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</option>");
            (function() {
                if ("number" == typeof matchmakers.models.length) {
                    for (var $index = 0, $$l = matchmakers.models.length; $index < $$l; $index++) {
                        var mm = matchmakers.models[$index];
                        var id = mm.id || mm.cid;
                        if (id == current_mm) {
                            buf.push("\n    <option");
                            buf.push(attrs({
                                value: id,
                                selected: "selected"
                            }, {
                                value: true,
                                selected: true
                            }));
                            buf.push(">");
                            var __val__ = mm.get("name") || MTN.t("Main Meet me page");
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</option>");
                        } else {
                            buf.push("\n    <option");
                            buf.push(attrs({
                                value: id
                            }, {
                                value: true
                            }));
                            buf.push(">");
                            var __val__ = mm.get("name") || MTN.t("Main Meet me page");
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</option>");
                        }
                    }
                } else {
                    var $$l = 0;
                    for (var $index in matchmakers.models) {
                        $$l++;
                        var mm = matchmakers.models[$index];
                        var id = mm.id || mm.cid;
                        if (id == current_mm) {
                            buf.push("\n    <option");
                            buf.push(attrs({
                                value: id,
                                selected: "selected"
                            }, {
                                value: true,
                                selected: true
                            }));
                            buf.push(">");
                            var __val__ = mm.get("name") || MTN.t("Main Meet me page");
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</option>");
                        } else {
                            buf.push("\n    <option");
                            buf.push(attrs({
                                value: id
                            }, {
                                value: true
                            }));
                            buf.push(">");
                            var __val__ = mm.get("name") || MTN.t("Main Meet me page");
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</option>");
                        }
                    }
                }
            }).call(this);
            buf.push("\n  </select>");
        }
        buf.push("</p>");
    }
    return buf.join("");
};

// agentBookingPublicConfirm.jade compiled template
exports.agentBookingPublicConfirm = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="agent-booking-confirm" class="m-modal">\n  <div class="modal-header">\n    <h3> <i class="ico-time"></i>');
        var __val__ = "Vahvista varauksesi" || MTN.t("Confirm reservation");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n    </h3>\n  </div>\n  <div class="modal-content">\n    <div class="infos">\n      <div class="info">\n        <h3>');
        var __val__ = lock.times_string;
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</h3>\n      </div>\n      <div class="info">\n        <h3>');
        var __val__ = booking_data.meeting_type;
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push("</h3>");
        if (booking_data.meeting_type.toLowerCase() != "verkkotapaaminen") {
            {
                buf.push('\n        <p class="m-form location-area">');
                var __val__ = booking_data.agent.toimisto;
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push('</p>\n        <p><a href="#" class="change-location">');
                var __val__ = "Muuta sijaintia" || MTN.t("Change location");
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push('</a><span class="divider">');
                var __val__ = " | ";
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</span><a");
                buf.push(attrs({
                    href: booking_data.agent.verkkosivu,
                    target: "_blank",
                    "class": "home-page"
                }, {
                    href: true,
                    target: true
                }));
                buf.push(">");
                var __val__ = "Tulo-ohjeet" || MTN.t("Homepage");
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</a></p>");
            }
        }
        buf.push('\n      </div>\n      <div class="info">\n        <h3>');
        var __val__ = booking_data.agent.name;
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push("</h3>\n        <p>");
        var __val__ = booking_data.agent.title || MTN.t("Customer service agent");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</p>\n      </div>\n    </div>\n    <div class="m-form content-area">\n      <div class="left">\n        <div class="form-row">\n          <label class="required">');
        var __val__ = "Nimesi" || MTN.t("Customer name");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</label>\n          <input id="booking-form-name" type="text"/>\n        </div>\n        <div class="form-row">\n          <label class="required">');
        var __val__ = "Sähköpostisi" || MTN.t("Email");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</label>\n          <input id="booking-form-email" type="text"/>\n        </div>\n        <div class="form-row">\n          <label class="required">');
        var __val__ = "Puhelinnumerosi" || MTN.t("Phone number");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</label>\n          <input id="booking-form-phone" type="text"/>\n        </div>\n        <div class="form-row">\n          <label class="required">');
        var __val__ = "Syntymäaikasi" || MTN.t("Birth date");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</label>\n          <input id="booking-form-birthdate" type="text"/>\n        </div>\n        <div class="form-row">\n          <label class="required">');
        var __val__ = "Osoitteesi" || MTN.t("Address");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</label>\n          <input id="booking-form-address" type="text"/>\n        </div>\n        <div class="form-row">\n          <label class="required">');
        var __val__ = "Postitoimipaikka" || MTN.t("Area");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</label>\n          <input id="booking-form-area" type="text"/>\n        </div>\n      </div>\n      <div class="right">\n        <div class="form-row">\n          <label style="width:300px">');
        var __val__ = "Lisätietoja Lähixcustxzn edustajalle:" || MTN.t("Message to agenda:");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</label>\n        </div>\n        <div class="form-row">\n          <textarea id="booking-form-agenda" rows="6"></textarea>\n          <input id="booking-form-language" type="hidden"/>\n          <input id="booking-form-level" type="hidden"/>\n        </div>\n      </div>\n    </div>\n  </div>\n  <div class="modal-footer">\n    <div class="buttons right"><a href="#" class="button blue confirm">');
        var __val__ = "Vahvista" || MTN.t("Confirm");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a><a href="#" class="button gray cancel">');
        var __val__ = "Peruuta" || MTN.t("Cancel");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// meetingLctHangouts.jade compiled template
exports.meetingLctHangouts = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="lct-picker" class="m-modal">\n  <div class="modal-header back-button">\n    <h3>');
        var __val__ = MTN.t("Hangouts settings");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3><i class="ico-leftarrow back"></i>\n  </div>\n  <div class="modal-content m-form">\n    <p>');
        var __val__ = MTN.t("Hangouts will be enabled for this meeting.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n    <p class="note">');
        var __val__ = MTN.t("NOTE: You and the participants will receive the Hangouts url before the meeting.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n  </div>\n  <div class="modal-footer">\n    <div class="buttons right"><a href="#" class="button blue save">');
        var __val__ = MTN.t("Save");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// agentAdmin.jade compiled template
exports.agentAdmin = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="agent-admin" class="m-modal">\n  <div class="modal-header">\n    <h3> <i class="ico-profile"></i>');
        if (selected_area) {
            {
                (function() {
                    if ("number" == typeof all_areas.length) {
                        for (var $index = 0, $$l = all_areas.length; $index < $$l; $index++) {
                            var area = all_areas[$index];
                            if (selected_area == area.id) {
                                {
                                    buf.push("<span>");
                                    var __val__ = ("Käyttäjähallinta" || MTN.t("Manage users")) + ": " + area.name;
                                    buf.push(null == __val__ ? "" : __val__);
                                    buf.push("</span>");
                                    if (areas == "_all") {
                                        {
                                            buf.push('<a href="#" class="deselect-area">');
                                            var __val__ = " [vaihda]";
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                            buf.push("</a>");
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        var $$l = 0;
                        for (var $index in all_areas) {
                            $$l++;
                            var area = all_areas[$index];
                            if (selected_area == area.id) {
                                {
                                    buf.push("<span>");
                                    var __val__ = ("Käyttäjähallinta" || MTN.t("Manage users")) + ": " + area.name;
                                    buf.push(null == __val__ ? "" : __val__);
                                    buf.push("</span>");
                                    if (areas == "_all") {
                                        {
                                            buf.push('<a href="#" class="deselect-area">');
                                            var __val__ = " [vaihda]";
                                            buf.push(escape(null == __val__ ? "" : __val__));
                                            buf.push("</a>");
                                        }
                                    }
                                }
                            }
                        }
                    }
                }).call(this);
            }
        } else {
            {
                buf.push("<span>");
                var __val__ = "Käyttäjähallinta" || MTN.t("Manage users");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</span>");
            }
        }
        buf.push('\n    </h3>\n  </div>\n  <div class="modal-content">');
        if (selected_area) {
            {
                buf.push('\n    <div style="float:right" class="section-listing">');
                (function() {
                    if ("number" == typeof all_sections.length) {
                        for (var index = 0, $$l = all_sections.length; index < $$l; index++) {
                            var section = all_sections[index];
                            if (section.id == selected_section) {
                                {
                                    buf.push("<a");
                                    buf.push(attrs({
                                        href: "#",
                                        "x-data-section": section.id,
                                        "class": "section-button-selected" + " " + "select-section"
                                    }, {
                                        href: true,
                                        "x-data-section": true
                                    }));
                                    buf.push(">");
                                    var __val__ = section.name;
                                    buf.push(escape(null == __val__ ? "" : __val__));
                                    buf.push("</a>");
                                }
                            } else {
                                {
                                    buf.push("<a");
                                    buf.push(attrs({
                                        href: "#",
                                        "x-data-section": section.id,
                                        "class": "section-button" + " " + "select-section"
                                    }, {
                                        href: true,
                                        "x-data-section": true
                                    }));
                                    buf.push(">");
                                    var __val__ = section.name;
                                    buf.push(escape(null == __val__ ? "" : __val__));
                                    buf.push("</a>");
                                }
                            }
                            if (index < all_sections.length - 1) {
                                {
                                    var __val__ = " - ";
                                    buf.push(escape(null == __val__ ? "" : __val__));
                                }
                            }
                        }
                    } else {
                        var $$l = 0;
                        for (var index in all_sections) {
                            $$l++;
                            var section = all_sections[index];
                            if (section.id == selected_section) {
                                {
                                    buf.push("<a");
                                    buf.push(attrs({
                                        href: "#",
                                        "x-data-section": section.id,
                                        "class": "section-button-selected" + " " + "select-section"
                                    }, {
                                        href: true,
                                        "x-data-section": true
                                    }));
                                    buf.push(">");
                                    var __val__ = section.name;
                                    buf.push(escape(null == __val__ ? "" : __val__));
                                    buf.push("</a>");
                                }
                            } else {
                                {
                                    buf.push("<a");
                                    buf.push(attrs({
                                        href: "#",
                                        "x-data-section": section.id,
                                        "class": "section-button" + " " + "select-section"
                                    }, {
                                        href: true,
                                        "x-data-section": true
                                    }));
                                    buf.push(">");
                                    var __val__ = section.name;
                                    buf.push(escape(null == __val__ ? "" : __val__));
                                    buf.push("</a>");
                                }
                            }
                            if (index < all_sections.length - 1) {
                                {
                                    var __val__ = " - ";
                                    buf.push(escape(null == __val__ ? "" : __val__));
                                }
                            }
                        }
                    }
                }).call(this);
                buf.push("\n    </div>");
            }
        } else {
            {
                buf.push('\n    <div class="area-listing">');
                (function() {
                    if ("number" == typeof all_areas.length) {
                        for (var index = 0, $$l = all_areas.length; index < $$l; index++) {
                            var area = all_areas[index];
                            if (area.id == selected_area) {
                                {
                                    buf.push("<a");
                                    buf.push(attrs({
                                        href: "#",
                                        "x-data-area": area.id,
                                        "class": "area-button-selected" + " " + "select-area"
                                    }, {
                                        href: true,
                                        "x-data-area": true
                                    }));
                                    buf.push(">");
                                    var __val__ = area.name;
                                    buf.push(escape(null == __val__ ? "" : __val__));
                                    buf.push("</a>");
                                }
                            } else {
                                {
                                    buf.push("<a");
                                    buf.push(attrs({
                                        href: "#",
                                        "x-data-area": area.id,
                                        "class": "area-button" + " " + "select-area"
                                    }, {
                                        href: true,
                                        "x-data-area": true
                                    }));
                                    buf.push(">");
                                    var __val__ = area.name;
                                    buf.push(escape(null == __val__ ? "" : __val__));
                                    buf.push("</a>");
                                }
                            }
                            if (index < all_areas.length - 1) {
                                {
                                    var __val__ = " - ";
                                    buf.push(escape(null == __val__ ? "" : __val__));
                                }
                            }
                        }
                    } else {
                        var $$l = 0;
                        for (var index in all_areas) {
                            $$l++;
                            var area = all_areas[index];
                            if (area.id == selected_area) {
                                {
                                    buf.push("<a");
                                    buf.push(attrs({
                                        href: "#",
                                        "x-data-area": area.id,
                                        "class": "area-button-selected" + " " + "select-area"
                                    }, {
                                        href: true,
                                        "x-data-area": true
                                    }));
                                    buf.push(">");
                                    var __val__ = area.name;
                                    buf.push(escape(null == __val__ ? "" : __val__));
                                    buf.push("</a>");
                                }
                            } else {
                                {
                                    buf.push("<a");
                                    buf.push(attrs({
                                        href: "#",
                                        "x-data-area": area.id,
                                        "class": "area-button" + " " + "select-area"
                                    }, {
                                        href: true,
                                        "x-data-area": true
                                    }));
                                    buf.push(">");
                                    var __val__ = area.name;
                                    buf.push(escape(null == __val__ ? "" : __val__));
                                    buf.push("</a>");
                                }
                            }
                            if (index < all_areas.length - 1) {
                                {
                                    var __val__ = " - ";
                                    buf.push(escape(null == __val__ ? "" : __val__));
                                }
                            }
                        }
                    }
                }).call(this);
                buf.push("\n    </div>");
            }
        }
        if (selected_area && selected_section == "users") {
            {
                buf.push('\n    <h4><span>Käyttäjät</span><a href="#" class="show-object-adding">');
                var __val__ = " [lisää]";
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push('</a><a href="#" style="display:none" class="hide-object-adding">');
                var __val__ = " [peruuta lisääminen]";
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push('</a></h4>\n    <div id="object-adding-container" style="display:none">\n      <div class="input-row"><span class="input-label">Email</span>\n        <input');
                buf.push(attrs({
                    "x-data-object-field": "email",
                    size: 40,
                    value: typeof admin_user == "undefined" ? undefined : admin_user.email,
                    disabled: typeof admin_user == "undefined" ? undefined : "disabled",
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    size: true,
                    value: true,
                    disabled: true
                }));
                buf.push('/>\n      </div>\n      <div class="input-row"><span class="input-label">AD tunnus</span>\n        <input');
                buf.push(attrs({
                    "x-data-object-field": "ad_account",
                    size: 40,
                    value: typeof admin_user == "undefined" ? undefined : admin_user.ad_account,
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    size: true,
                    value: true
                }));
                buf.push('/>\n      </div>\n      <div class="input-row"><span class="input-label">Nimi</span>\n        <input');
                buf.push(attrs({
                    "x-data-object-field": "name",
                    size: 40,
                    value: typeof admin_user == "undefined" ? undefined : admin_user.name,
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    size: true,
                    value: true
                }));
                buf.push('/>\n      </div>\n      <div class="input-row"><span class="input-label">Titteli</span>\n        <input');
                buf.push(attrs({
                    "x-data-object-field": "title",
                    size: 40,
                    value: typeof admin_user == "undefined" ? undefined : admin_user.title,
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    size: true,
                    value: true
                }));
                buf.push('/>\n      </div>\n      <div class="input-row"><span class="input-label">Tiimi</span>\n        <input');
                buf.push(attrs({
                    "x-data-object-field": "team",
                    size: 40,
                    value: typeof admin_user == "undefined" ? undefined : admin_user.team,
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    size: true,
                    value: true
                }));
                buf.push('/>\n      </div>\n      <div class="input-row"><span class="input-label">Esimies</span>\n        <select x-data-object-field="supervisor" class="object-field">\n          <option value="">Ei</option>');
                (function() {
                    if ("number" == typeof users.length) {
                        for (var $index = 0, $$l = users.length; $index < $$l; $index++) {
                            var u = users[$index];
                            buf.push("\n          <option");
                            buf.push(attrs({
                                value: u.email,
                                selected: u.email == (typeof admin_user == "undefined" ? undefined : admin_user.supervisor) ? "selected" : undefined
                            }, {
                                value: true,
                                selected: true
                            }));
                            buf.push(">");
                            var __val__ = u.email;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</option>");
                        }
                    } else {
                        var $$l = 0;
                        for (var $index in users) {
                            $$l++;
                            var u = users[$index];
                            buf.push("\n          <option");
                            buf.push(attrs({
                                value: u.email,
                                selected: u.email == (typeof admin_user == "undefined" ? undefined : admin_user.supervisor) ? "selected" : undefined
                            }, {
                                value: true,
                                selected: true
                            }));
                            buf.push(">");
                            var __val__ = u.email;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</option>");
                        }
                    }
                }).call(this);
                buf.push('\n        </select>\n      </div>\n      <div class="input-row"><span class="input-label">Puhelinnumero</span>\n        <input');
                buf.push(attrs({
                    "x-data-object-field": "phone",
                    size: 40,
                    value: typeof admin_user == "undefined" ? undefined : admin_user.phone,
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    size: true,
                    value: true
                }));
                buf.push('/>\n      </div>\n      <div class="input-row">\n        <div class="input-label-row"><span>Käyttöoikeudet:</span></div>\n      </div>\n      <div class="input-row"><span class="input-label">Varaaminen</span>\n        <select x-data-object-field="booking_rights" class="object-field">\n          <option value="">Ei</option>\n          <option');
                buf.push(attrs({
                    value: selected_area,
                    selected: selected_area == (typeof admin_user == "undefined" ? undefined : admin_user.booking_rights) ? "selected" : undefined
                }, {
                    value: true,
                    selected: true
                }));
                buf.push(">");
                var __val__ = selected_area_name;
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</option>\n          <option");
                buf.push(attrs({
                    value: "_all",
                    selected: "_all" == (typeof admin_user == "undefined" ? undefined : admin_user.booking_rights) ? "selected" : undefined
                }, {
                    value: true,
                    selected: true
                }));
                buf.push('>Kaikki yhtiöt</option>\n        </select>\n      </div>\n      <div class="input-row"><span class="input-label">Varausten muokkaaminen</span>\n        <select x-data-object-field="manage_rights" class="object-field">\n          <option value="">Ei</option>\n          <option');
                buf.push(attrs({
                    value: selected_area,
                    selected: selected_area == (typeof admin_user == "undefined" ? undefined : admin_user.manage_rights) ? "selected" : undefined
                }, {
                    value: true,
                    selected: true
                }));
                buf.push(">");
                var __val__ = selected_area_name;
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</option>\n          <option");
                buf.push(attrs({
                    value: "_all",
                    selected: "_all" == (typeof admin_user == "undefined" ? undefined : admin_user.manage_rights) ? "selected" : undefined
                }, {
                    value: true,
                    selected: true
                }));
                buf.push('>Kaikki yhtiöt</option>\n        </select>\n      </div>\n      <div class="input-row"><span class="input-label">Käyttäjähallinta</span>\n        <select');
                buf.push(attrs({
                    "x-data-object-field": "admin_rights",
                    disabled: typeof admin_user == "undefined" ? undefined : admin_user.admin_rights == "_all" && areas != "_all" ? "disabled" : undefined,
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    disabled: true
                }));
                buf.push('>\n          <option value="">Ei</option>\n          <option');
                buf.push(attrs({
                    value: selected_area,
                    selected: selected_area == (typeof admin_user == "undefined" ? undefined : admin_user.admin_rights) ? "selected" : undefined
                }, {
                    value: true,
                    selected: true
                }));
                buf.push(">");
                var __val__ = selected_area_name;
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</option>");
                if (areas == "_all" || typeof admin_user != "undefined" && admin_user.admin_rights == "_all") {
                    {
                        buf.push("\n          <option");
                        buf.push(attrs({
                            value: "_all",
                            selected: "_all" == (typeof admin_user == "undefined" ? undefined : admin_user.admin_rights) ? "selected" : undefined
                        }, {
                            value: true,
                            selected: true
                        }));
                        buf.push(">Kaikki yhtiöt</option>");
                    }
                }
                buf.push('\n        </select>\n      </div>\n      <div class="input-row"><span class="input-label">Käyttö sisäverkon ulkopuolelta</span>\n        <select');
                buf.push(attrs({
                    "x-data-object-field": "access_outside_intranet",
                    disabled: areas != "_all" ? "disabled" : undefined,
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    disabled: true
                }));
                buf.push('>\n          <option value="">Ei</option>\n          <option');
                buf.push(attrs({
                    value: "allow",
                    selected: "allow" == (typeof admin_user == "undefined" ? undefined : admin_user.access_outside_intranet) ? "selected" : undefined
                }, {
                    value: true,
                    selected: true
                }));
                buf.push(">Kyllä</option>\n        </select>\n      </div>");
                if (typeof admin_user !== "undefined") {
                    {
                        buf.push('\n      <div class="input-row">\n        <div class="input-label-row"><span>Erityiset muutostyöt:</span></div>\n      </div>\n      <div class="input-row"><span class="input-label">Vaihtunut Email</span>\n        <input');
                        buf.push(attrs({
                            "x-data-object-field": "changed_email",
                            size: 40,
                            value: typeof admin_user == "undefined" ? undefined : admin_user.changed_email,
                            "class": "object-field"
                        }, {
                            "x-data-object-field": true,
                            size: true,
                            value: true
                        }));
                        buf.push("/>\n      </div>");
                    }
                }
                buf.push('\n      <div class="input-row input-button-row">\n        <button class="add-user-button">');
                var __val__ = "Lisää" || MTN.t("Add");
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</button>");
                var __val__ = " ";
                buf.push(null == __val__ ? "" : __val__);
                buf.push('<span class="save-reopen-indicator">');
                var __val__ = "Käyttäjä lisätty onnistuneesti!";
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push('</span>\n      </div>\n    </div>\n    <div class="user-listing">');
                (function() {
                    if ("number" == typeof users.length) {
                        for (var $index = 0, $$l = users.length; $index < $$l; $index++) {
                            var admin_user = users[$index];
                            buf.push("\n      <div");
                            buf.push(attrs({
                                id: "object-" + admin_user.safe_uid,
                                "class": "object-container"
                            }, {
                                id: true
                            }));
                            buf.push('>\n        <h5 class="user-name-container"><span');
                            buf.push(attrs({
                                title: admin_user.user_email,
                                "class": "user-name"
                            }, {
                                title: true
                            }));
                            buf.push(">");
                            var __val__ = admin_user.name;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</span><a");
                            buf.push(attrs({
                                href: "#",
                                "x-data-object-id": admin_user.safe_uid,
                                "class": "object-edit-button" + " " + "plus"
                            }, {
                                href: true,
                                "x-data-object-id": true
                            }));
                            buf.push(">");
                            var __val__ = " [muokkaa]";
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</a><a");
                            buf.push(attrs({
                                href: "#",
                                "x-data-object-id": admin_user.safe_uid,
                                style: "display:none",
                                "class": "object-edit-button" + " " + "minus"
                            }, {
                                href: true,
                                "x-data-object-id": true,
                                style: true
                            }));
                            buf.push(">");
                            var __val__ = " [peruuta muokkaus]";
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push('</a></h5>\n        <div style="display:none" class="object-editor">\n          <div class="input-row"><span class="input-label">Email</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "email",
                                size: 40,
                                value: typeof admin_user == "undefined" ? undefined : admin_user.email,
                                disabled: typeof admin_user == "undefined" ? undefined : "disabled",
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true,
                                disabled: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">AD tunnus</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "ad_account",
                                size: 40,
                                value: typeof admin_user == "undefined" ? undefined : admin_user.ad_account,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">Nimi</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "name",
                                size: 40,
                                value: typeof admin_user == "undefined" ? undefined : admin_user.name,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">Titteli</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "title",
                                size: 40,
                                value: typeof admin_user == "undefined" ? undefined : admin_user.title,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">Tiimi</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "team",
                                size: 40,
                                value: typeof admin_user == "undefined" ? undefined : admin_user.team,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">Esimies</span>\n            <select x-data-object-field="supervisor" class="object-field">\n              <option value="">Ei</option>');
                            (function() {
                                if ("number" == typeof users.length) {
                                    for (var $index = 0, $$l = users.length; $index < $$l; $index++) {
                                        var u = users[$index];
                                        buf.push("\n              <option");
                                        buf.push(attrs({
                                            value: u.email,
                                            selected: u.email == (typeof admin_user == "undefined" ? undefined : admin_user.supervisor) ? "selected" : undefined
                                        }, {
                                            value: true,
                                            selected: true
                                        }));
                                        buf.push(">");
                                        var __val__ = u.email;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</option>");
                                    }
                                } else {
                                    var $$l = 0;
                                    for (var $index in users) {
                                        $$l++;
                                        var u = users[$index];
                                        buf.push("\n              <option");
                                        buf.push(attrs({
                                            value: u.email,
                                            selected: u.email == (typeof admin_user == "undefined" ? undefined : admin_user.supervisor) ? "selected" : undefined
                                        }, {
                                            value: true,
                                            selected: true
                                        }));
                                        buf.push(">");
                                        var __val__ = u.email;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</option>");
                                    }
                                }
                            }).call(this);
                            buf.push('\n            </select>\n          </div>\n          <div class="input-row"><span class="input-label">Puhelinnumero</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "phone",
                                size: 40,
                                value: typeof admin_user == "undefined" ? undefined : admin_user.phone,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row">\n            <div class="input-label-row"><span>Käyttöoikeudet:</span></div>\n          </div>\n          <div class="input-row"><span class="input-label">Varaaminen</span>\n            <select x-data-object-field="booking_rights" class="object-field">\n              <option value="">Ei</option>\n              <option');
                            buf.push(attrs({
                                value: selected_area,
                                selected: selected_area == (typeof admin_user == "undefined" ? undefined : admin_user.booking_rights) ? "selected" : undefined
                            }, {
                                value: true,
                                selected: true
                            }));
                            buf.push(">");
                            var __val__ = selected_area_name;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</option>\n              <option");
                            buf.push(attrs({
                                value: "_all",
                                selected: "_all" == (typeof admin_user == "undefined" ? undefined : admin_user.booking_rights) ? "selected" : undefined
                            }, {
                                value: true,
                                selected: true
                            }));
                            buf.push('>Kaikki yhtiöt</option>\n            </select>\n          </div>\n          <div class="input-row"><span class="input-label">Varausten muokkaaminen</span>\n            <select x-data-object-field="manage_rights" class="object-field">\n              <option value="">Ei</option>\n              <option');
                            buf.push(attrs({
                                value: selected_area,
                                selected: selected_area == (typeof admin_user == "undefined" ? undefined : admin_user.manage_rights) ? "selected" : undefined
                            }, {
                                value: true,
                                selected: true
                            }));
                            buf.push(">");
                            var __val__ = selected_area_name;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</option>\n              <option");
                            buf.push(attrs({
                                value: "_all",
                                selected: "_all" == (typeof admin_user == "undefined" ? undefined : admin_user.manage_rights) ? "selected" : undefined
                            }, {
                                value: true,
                                selected: true
                            }));
                            buf.push('>Kaikki yhtiöt</option>\n            </select>\n          </div>\n          <div class="input-row"><span class="input-label">Käyttäjähallinta</span>\n            <select');
                            buf.push(attrs({
                                "x-data-object-field": "admin_rights",
                                disabled: typeof admin_user == "undefined" ? undefined : admin_user.admin_rights == "_all" && areas != "_all" ? "disabled" : undefined,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                disabled: true
                            }));
                            buf.push('>\n              <option value="">Ei</option>\n              <option');
                            buf.push(attrs({
                                value: selected_area,
                                selected: selected_area == (typeof admin_user == "undefined" ? undefined : admin_user.admin_rights) ? "selected" : undefined
                            }, {
                                value: true,
                                selected: true
                            }));
                            buf.push(">");
                            var __val__ = selected_area_name;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</option>");
                            if (areas == "_all" || typeof admin_user != "undefined" && admin_user.admin_rights == "_all") {
                                {
                                    buf.push("\n              <option");
                                    buf.push(attrs({
                                        value: "_all",
                                        selected: "_all" == (typeof admin_user == "undefined" ? undefined : admin_user.admin_rights) ? "selected" : undefined
                                    }, {
                                        value: true,
                                        selected: true
                                    }));
                                    buf.push(">Kaikki yhtiöt</option>");
                                }
                            }
                            buf.push('\n            </select>\n          </div>\n          <div class="input-row"><span class="input-label">Käyttö sisäverkon ulkopuolelta</span>\n            <select');
                            buf.push(attrs({
                                "x-data-object-field": "access_outside_intranet",
                                disabled: areas != "_all" ? "disabled" : undefined,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                disabled: true
                            }));
                            buf.push('>\n              <option value="">Ei</option>\n              <option');
                            buf.push(attrs({
                                value: "allow",
                                selected: "allow" == (typeof admin_user == "undefined" ? undefined : admin_user.access_outside_intranet) ? "selected" : undefined
                            }, {
                                value: true,
                                selected: true
                            }));
                            buf.push(">Kyllä</option>\n            </select>\n          </div>");
                            if (typeof admin_user !== "undefined") {
                                {
                                    buf.push('\n          <div class="input-row">\n            <div class="input-label-row"><span>Erityiset muutostyöt:</span></div>\n          </div>\n          <div class="input-row"><span class="input-label">Vaihtunut Email</span>\n            <input');
                                    buf.push(attrs({
                                        "x-data-object-field": "changed_email",
                                        size: 40,
                                        value: typeof admin_user == "undefined" ? undefined : admin_user.changed_email,
                                        "class": "object-field"
                                    }, {
                                        "x-data-object-field": true,
                                        size: true,
                                        value: true
                                    }));
                                    buf.push("/>\n          </div>");
                                }
                            }
                            buf.push('\n          <div class="input-row input-button-row">\n            <button');
                            buf.push(attrs({
                                "x-data-object-container-id": "object-" + admin_user.safe_uid,
                                "class": "edit-user-button"
                            }, {
                                "x-data-object-container-id": true
                            }));
                            buf.push(">");
                            var __val__ = "Tallenna" || MTN.t("Save");
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</button>");
                            var __val__ = " ";
                            buf.push(null == __val__ ? "" : __val__);
                            buf.push("\n            <button");
                            buf.push(attrs({
                                "x-data-object-container-id": "object-" + admin_user.safe_uid,
                                "class": "remove-user-button"
                            }, {
                                "x-data-object-container-id": true
                            }));
                            buf.push(">");
                            var __val__ = "Poista" || MTN.t("Remove");
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</button>");
                            var __val__ = " ";
                            buf.push(null == __val__ ? "" : __val__);
                            buf.push('<span class="save-reopen-indicator">');
                            var __val__ = "Käyttäjä tallennettu onnistuneesti!";
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</span>\n          </div>\n        </div>\n      </div>");
                        }
                    } else {
                        var $$l = 0;
                        for (var $index in users) {
                            $$l++;
                            var admin_user = users[$index];
                            buf.push("\n      <div");
                            buf.push(attrs({
                                id: "object-" + admin_user.safe_uid,
                                "class": "object-container"
                            }, {
                                id: true
                            }));
                            buf.push('>\n        <h5 class="user-name-container"><span');
                            buf.push(attrs({
                                title: admin_user.user_email,
                                "class": "user-name"
                            }, {
                                title: true
                            }));
                            buf.push(">");
                            var __val__ = admin_user.name;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</span><a");
                            buf.push(attrs({
                                href: "#",
                                "x-data-object-id": admin_user.safe_uid,
                                "class": "object-edit-button" + " " + "plus"
                            }, {
                                href: true,
                                "x-data-object-id": true
                            }));
                            buf.push(">");
                            var __val__ = " [muokkaa]";
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</a><a");
                            buf.push(attrs({
                                href: "#",
                                "x-data-object-id": admin_user.safe_uid,
                                style: "display:none",
                                "class": "object-edit-button" + " " + "minus"
                            }, {
                                href: true,
                                "x-data-object-id": true,
                                style: true
                            }));
                            buf.push(">");
                            var __val__ = " [peruuta muokkaus]";
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push('</a></h5>\n        <div style="display:none" class="object-editor">\n          <div class="input-row"><span class="input-label">Email</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "email",
                                size: 40,
                                value: typeof admin_user == "undefined" ? undefined : admin_user.email,
                                disabled: typeof admin_user == "undefined" ? undefined : "disabled",
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true,
                                disabled: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">AD tunnus</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "ad_account",
                                size: 40,
                                value: typeof admin_user == "undefined" ? undefined : admin_user.ad_account,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">Nimi</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "name",
                                size: 40,
                                value: typeof admin_user == "undefined" ? undefined : admin_user.name,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">Titteli</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "title",
                                size: 40,
                                value: typeof admin_user == "undefined" ? undefined : admin_user.title,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">Tiimi</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "team",
                                size: 40,
                                value: typeof admin_user == "undefined" ? undefined : admin_user.team,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">Esimies</span>\n            <select x-data-object-field="supervisor" class="object-field">\n              <option value="">Ei</option>');
                            (function() {
                                if ("number" == typeof users.length) {
                                    for (var $index = 0, $$l = users.length; $index < $$l; $index++) {
                                        var u = users[$index];
                                        buf.push("\n              <option");
                                        buf.push(attrs({
                                            value: u.email,
                                            selected: u.email == (typeof admin_user == "undefined" ? undefined : admin_user.supervisor) ? "selected" : undefined
                                        }, {
                                            value: true,
                                            selected: true
                                        }));
                                        buf.push(">");
                                        var __val__ = u.email;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</option>");
                                    }
                                } else {
                                    var $$l = 0;
                                    for (var $index in users) {
                                        $$l++;
                                        var u = users[$index];
                                        buf.push("\n              <option");
                                        buf.push(attrs({
                                            value: u.email,
                                            selected: u.email == (typeof admin_user == "undefined" ? undefined : admin_user.supervisor) ? "selected" : undefined
                                        }, {
                                            value: true,
                                            selected: true
                                        }));
                                        buf.push(">");
                                        var __val__ = u.email;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</option>");
                                    }
                                }
                            }).call(this);
                            buf.push('\n            </select>\n          </div>\n          <div class="input-row"><span class="input-label">Puhelinnumero</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "phone",
                                size: 40,
                                value: typeof admin_user == "undefined" ? undefined : admin_user.phone,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row">\n            <div class="input-label-row"><span>Käyttöoikeudet:</span></div>\n          </div>\n          <div class="input-row"><span class="input-label">Varaaminen</span>\n            <select x-data-object-field="booking_rights" class="object-field">\n              <option value="">Ei</option>\n              <option');
                            buf.push(attrs({
                                value: selected_area,
                                selected: selected_area == (typeof admin_user == "undefined" ? undefined : admin_user.booking_rights) ? "selected" : undefined
                            }, {
                                value: true,
                                selected: true
                            }));
                            buf.push(">");
                            var __val__ = selected_area_name;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</option>\n              <option");
                            buf.push(attrs({
                                value: "_all",
                                selected: "_all" == (typeof admin_user == "undefined" ? undefined : admin_user.booking_rights) ? "selected" : undefined
                            }, {
                                value: true,
                                selected: true
                            }));
                            buf.push('>Kaikki yhtiöt</option>\n            </select>\n          </div>\n          <div class="input-row"><span class="input-label">Varausten muokkaaminen</span>\n            <select x-data-object-field="manage_rights" class="object-field">\n              <option value="">Ei</option>\n              <option');
                            buf.push(attrs({
                                value: selected_area,
                                selected: selected_area == (typeof admin_user == "undefined" ? undefined : admin_user.manage_rights) ? "selected" : undefined
                            }, {
                                value: true,
                                selected: true
                            }));
                            buf.push(">");
                            var __val__ = selected_area_name;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</option>\n              <option");
                            buf.push(attrs({
                                value: "_all",
                                selected: "_all" == (typeof admin_user == "undefined" ? undefined : admin_user.manage_rights) ? "selected" : undefined
                            }, {
                                value: true,
                                selected: true
                            }));
                            buf.push('>Kaikki yhtiöt</option>\n            </select>\n          </div>\n          <div class="input-row"><span class="input-label">Käyttäjähallinta</span>\n            <select');
                            buf.push(attrs({
                                "x-data-object-field": "admin_rights",
                                disabled: typeof admin_user == "undefined" ? undefined : admin_user.admin_rights == "_all" && areas != "_all" ? "disabled" : undefined,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                disabled: true
                            }));
                            buf.push('>\n              <option value="">Ei</option>\n              <option');
                            buf.push(attrs({
                                value: selected_area,
                                selected: selected_area == (typeof admin_user == "undefined" ? undefined : admin_user.admin_rights) ? "selected" : undefined
                            }, {
                                value: true,
                                selected: true
                            }));
                            buf.push(">");
                            var __val__ = selected_area_name;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</option>");
                            if (areas == "_all" || typeof admin_user != "undefined" && admin_user.admin_rights == "_all") {
                                {
                                    buf.push("\n              <option");
                                    buf.push(attrs({
                                        value: "_all",
                                        selected: "_all" == (typeof admin_user == "undefined" ? undefined : admin_user.admin_rights) ? "selected" : undefined
                                    }, {
                                        value: true,
                                        selected: true
                                    }));
                                    buf.push(">Kaikki yhtiöt</option>");
                                }
                            }
                            buf.push('\n            </select>\n          </div>\n          <div class="input-row"><span class="input-label">Käyttö sisäverkon ulkopuolelta</span>\n            <select');
                            buf.push(attrs({
                                "x-data-object-field": "access_outside_intranet",
                                disabled: areas != "_all" ? "disabled" : undefined,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                disabled: true
                            }));
                            buf.push('>\n              <option value="">Ei</option>\n              <option');
                            buf.push(attrs({
                                value: "allow",
                                selected: "allow" == (typeof admin_user == "undefined" ? undefined : admin_user.access_outside_intranet) ? "selected" : undefined
                            }, {
                                value: true,
                                selected: true
                            }));
                            buf.push(">Kyllä</option>\n            </select>\n          </div>");
                            if (typeof admin_user !== "undefined") {
                                {
                                    buf.push('\n          <div class="input-row">\n            <div class="input-label-row"><span>Erityiset muutostyöt:</span></div>\n          </div>\n          <div class="input-row"><span class="input-label">Vaihtunut Email</span>\n            <input');
                                    buf.push(attrs({
                                        "x-data-object-field": "changed_email",
                                        size: 40,
                                        value: typeof admin_user == "undefined" ? undefined : admin_user.changed_email,
                                        "class": "object-field"
                                    }, {
                                        "x-data-object-field": true,
                                        size: true,
                                        value: true
                                    }));
                                    buf.push("/>\n          </div>");
                                }
                            }
                            buf.push('\n          <div class="input-row input-button-row">\n            <button');
                            buf.push(attrs({
                                "x-data-object-container-id": "object-" + admin_user.safe_uid,
                                "class": "edit-user-button"
                            }, {
                                "x-data-object-container-id": true
                            }));
                            buf.push(">");
                            var __val__ = "Tallenna" || MTN.t("Save");
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</button>");
                            var __val__ = " ";
                            buf.push(null == __val__ ? "" : __val__);
                            buf.push("\n            <button");
                            buf.push(attrs({
                                "x-data-object-container-id": "object-" + admin_user.safe_uid,
                                "class": "remove-user-button"
                            }, {
                                "x-data-object-container-id": true
                            }));
                            buf.push(">");
                            var __val__ = "Poista" || MTN.t("Remove");
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</button>");
                            var __val__ = " ";
                            buf.push(null == __val__ ? "" : __val__);
                            buf.push('<span class="save-reopen-indicator">');
                            var __val__ = "Käyttäjä tallennettu onnistuneesti!";
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</span>\n          </div>\n        </div>\n      </div>");
                        }
                    }
                }).call(this);
                buf.push("\n    </div>");
            }
        }
        if (selected_area && selected_section == "offices") {
            {
                buf.push('\n    <h4><span>Toimistot</span><a href="#" class="show-object-adding">');
                var __val__ = " [lisää]";
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push('</a><a href="#" style="display:none" class="hide-object-adding">');
                var __val__ = " [peruuta lisääminen]";
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push('</a></h4>\n    <div id="object-adding-container" style="display:none">\n      <div class="input-row"><span class="input-label">Toimiston nimi</span>\n        <input');
                buf.push(attrs({
                    "x-data-object-field": "name",
                    size: 40,
                    value: typeof office == "undefined" ? undefined : office.name,
                    disabled: typeof office == "undefined" ? undefined : "disabled",
                    "class": "object-field" + " " + "open-focus-target"
                }, {
                    "x-data-object-field": true,
                    size: true,
                    value: true,
                    disabled: true
                }));
                buf.push('/>\n      </div>\n      <div class="input-row"><span class="input-label">Alaryhmä</span>\n        <input');
                buf.push(attrs({
                    "x-data-object-field": "subgroup",
                    size: 40,
                    value: typeof office == "undefined" ? undefined : office.subgroup,
                    disabled: typeof office == "undefined" ? undefined : "disabled",
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    size: true,
                    value: true,
                    disabled: true
                }));
                buf.push('/>\n      </div>\n      <div class="input-row"><span class="input-label">Yhteinen email</span>\n        <input');
                buf.push(attrs({
                    "x-data-object-field": "group_email",
                    size: 40,
                    value: typeof office == "undefined" ? undefined : office.group_email,
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    size: true,
                    value: true
                }));
                buf.push('/>\n      </div>\n      <div class="input-row">\n        <div class="input-label-row"><span class="input-label">Aukioloajat:</span></div>\n      </div>\n      <div class="input-row"><span class="input-label">MA</span>\n        <input');
                buf.push(attrs({
                    "x-data-object-field": "open_mon",
                    size: 25,
                    value: typeof office == "undefined" ? undefined : office.open_mon,
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    size: true,
                    value: true
                }));
                buf.push('/><span class="input-hint">(esim. "9:00-17:00" tai "9:00-11:00; 12:00-19:00")</span>\n      </div>\n      <div class="input-row"><span class="input-label">TI</span>\n        <input');
                buf.push(attrs({
                    "x-data-object-field": "open_tue",
                    size: 25,
                    value: typeof office == "undefined" ? undefined : office.open_tue,
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    size: true,
                    value: true
                }));
                buf.push('/>\n      </div>\n      <div class="input-row"><span class="input-label">KE</span>\n        <input');
                buf.push(attrs({
                    "x-data-object-field": "open_wed",
                    size: 25,
                    value: typeof office == "undefined" ? undefined : office.open_wed,
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    size: true,
                    value: true
                }));
                buf.push('/>\n      </div>\n      <div class="input-row"><span class="input-label">TO</span>\n        <input');
                buf.push(attrs({
                    "x-data-object-field": "open_thu",
                    size: 25,
                    value: typeof office == "undefined" ? undefined : office.open_thu,
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    size: true,
                    value: true
                }));
                buf.push('/>\n      </div>\n      <div class="input-row"><span class="input-label">PE</span>\n        <input');
                buf.push(attrs({
                    "x-data-object-field": "open_fri",
                    size: 25,
                    value: typeof office == "undefined" ? undefined : office.open_fri,
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    size: true,
                    value: true
                }));
                buf.push('/>\n      </div>\n      <div class="input-row">\n        <div class="input-label-row"><span class="input-label">Osoite:</span></div>\n      </div>\n      <div class="input-row"><span class="input-label">Suomi</span>\n        <input');
                buf.push(attrs({
                    "x-data-object-field": "address_fi",
                    size: 40,
                    value: typeof office == "undefined" ? undefined : office.address_fi,
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    size: true,
                    value: true
                }));
                buf.push('/>\n      </div>\n      <div class="input-row"><span class="input-label">Svenska</span>\n        <input');
                buf.push(attrs({
                    "x-data-object-field": "address_sv",
                    size: 40,
                    value: typeof office == "undefined" ? undefined : office.address_sv,
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    size: true,
                    value: true
                }));
                buf.push('/>\n      </div>\n      <div class="input-row"><span class="input-label">English</span>\n        <input');
                buf.push(attrs({
                    "x-data-object-field": "address_en",
                    size: 40,
                    value: typeof office == "undefined" ? undefined : office.address_en,
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    size: true,
                    value: true
                }));
                buf.push('/>\n      </div>\n      <div class="input-row">\n        <div class="input-label-row"><span class="input-label">Saapumisohjeet:</span></div>\n      </div>\n      <div class="input-row"><span class="input-label">Suomi</span>\n        <input');
                buf.push(attrs({
                    "x-data-object-field": "instructions_fi",
                    size: 100,
                    value: typeof office == "undefined" ? undefined : office.instructions_fi,
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    size: true,
                    value: true
                }));
                buf.push('/>\n      </div>\n      <div class="input-row"><span class="input-label">Svenska</span>\n        <input');
                buf.push(attrs({
                    "x-data-object-field": "instructions_sv",
                    size: 100,
                    value: typeof office == "undefined" ? undefined : office.instructions_sv,
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    size: true,
                    value: true
                }));
                buf.push('/>\n      </div>\n      <div class="input-row"><span class="input-label">English</span>\n        <input');
                buf.push(attrs({
                    "x-data-object-field": "instructions_en",
                    size: 100,
                    value: typeof office == "undefined" ? undefined : office.instructions_en,
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    size: true,
                    value: true
                }));
                buf.push('/>\n      </div>\n      <div class="input-row">\n        <div class="input-label-row"><span class="input-label">Verkkosivu:</span></div>\n      </div>\n      <div class="input-row"><span class="input-label">Suomi</span>\n        <input');
                buf.push(attrs({
                    "x-data-object-field": "website_fi",
                    size: 100,
                    value: typeof office == "undefined" ? undefined : office.website_fi,
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    size: true,
                    value: true
                }));
                buf.push('/>\n      </div>\n      <div class="input-row"><span class="input-label">Svenska</span>\n        <input');
                buf.push(attrs({
                    "x-data-object-field": "website_sv",
                    size: 100,
                    value: typeof office == "undefined" ? undefined : office.website_sv,
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    size: true,
                    value: true
                }));
                buf.push('/>\n      </div>\n      <div class="input-row"><span class="input-label">English</span>\n        <input');
                buf.push(attrs({
                    "x-data-object-field": "website_en",
                    size: 100,
                    value: typeof office == "undefined" ? undefined : office.website_en,
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    size: true,
                    value: true
                }));
                buf.push('/>\n      </div>\n      <div class="input-row input-button-row">\n        <button class="add-office-button">');
                var __val__ = "Lisää" || MTN.t("Add");
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</button>");
                var __val__ = " ";
                buf.push(null == __val__ ? "" : __val__);
                buf.push('<span class="save-reopen-indicator">');
                var __val__ = "Toimisto lisätty onnistuneesti!";
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push('</span>\n      </div>\n    </div>\n    <div class="office-listing">');
                (function() {
                    if ("number" == typeof offices.length) {
                        for (var $index = 0, $$l = offices.length; $index < $$l; $index++) {
                            var office = offices[$index];
                            buf.push("\n      <div");
                            buf.push(attrs({
                                id: "object-" + office.safe_uid,
                                "class": "object-container"
                            }, {
                                id: true
                            }));
                            buf.push('>\n        <h5 class="office-name-container"><span class="office-name">');
                            var __val__ = office.full_name;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</span><a");
                            buf.push(attrs({
                                href: "#",
                                "x-data-object-id": office.safe_uid,
                                "class": "object-edit-button" + " " + "plus"
                            }, {
                                href: true,
                                "x-data-object-id": true
                            }));
                            buf.push(">");
                            var __val__ = " [muokkaa]";
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</a><a");
                            buf.push(attrs({
                                href: "#",
                                "x-data-object-id": office.safe_uid,
                                style: "display:none",
                                "class": "object-edit-button" + " " + "minus"
                            }, {
                                href: true,
                                "x-data-object-id": true,
                                style: true
                            }));
                            buf.push(">");
                            var __val__ = " [peruuta muokkaus]";
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push('</a></h5>\n        <div style="display:none" class="object-editor">\n          <div class="input-row"><span class="input-label">Toimiston nimi</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "name",
                                size: 40,
                                value: typeof office == "undefined" ? undefined : office.name,
                                disabled: typeof office == "undefined" ? undefined : "disabled",
                                "class": "object-field" + " " + "open-focus-target"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true,
                                disabled: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">Alaryhmä</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "subgroup",
                                size: 40,
                                value: typeof office == "undefined" ? undefined : office.subgroup,
                                disabled: typeof office == "undefined" ? undefined : "disabled",
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true,
                                disabled: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">Yhteinen email</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "group_email",
                                size: 40,
                                value: typeof office == "undefined" ? undefined : office.group_email,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row">\n            <div class="input-label-row"><span class="input-label">Aukioloajat:</span></div>\n          </div>\n          <div class="input-row"><span class="input-label">MA</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "open_mon",
                                size: 25,
                                value: typeof office == "undefined" ? undefined : office.open_mon,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/><span class="input-hint">(esim. "9:00-17:00" tai "9:00-11:00; 12:00-19:00")</span>\n          </div>\n          <div class="input-row"><span class="input-label">TI</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "open_tue",
                                size: 25,
                                value: typeof office == "undefined" ? undefined : office.open_tue,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">KE</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "open_wed",
                                size: 25,
                                value: typeof office == "undefined" ? undefined : office.open_wed,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">TO</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "open_thu",
                                size: 25,
                                value: typeof office == "undefined" ? undefined : office.open_thu,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">PE</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "open_fri",
                                size: 25,
                                value: typeof office == "undefined" ? undefined : office.open_fri,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row">\n            <div class="input-label-row"><span class="input-label">Osoite:</span></div>\n          </div>\n          <div class="input-row"><span class="input-label">Suomi</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "address_fi",
                                size: 40,
                                value: typeof office == "undefined" ? undefined : office.address_fi,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">Svenska</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "address_sv",
                                size: 40,
                                value: typeof office == "undefined" ? undefined : office.address_sv,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">English</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "address_en",
                                size: 40,
                                value: typeof office == "undefined" ? undefined : office.address_en,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row">\n            <div class="input-label-row"><span class="input-label">Saapumisohjeet:</span></div>\n          </div>\n          <div class="input-row"><span class="input-label">Suomi</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "instructions_fi",
                                size: 100,
                                value: typeof office == "undefined" ? undefined : office.instructions_fi,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">Svenska</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "instructions_sv",
                                size: 100,
                                value: typeof office == "undefined" ? undefined : office.instructions_sv,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">English</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "instructions_en",
                                size: 100,
                                value: typeof office == "undefined" ? undefined : office.instructions_en,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row">\n            <div class="input-label-row"><span class="input-label">Verkkosivu:</span></div>\n          </div>\n          <div class="input-row"><span class="input-label">Suomi</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "website_fi",
                                size: 100,
                                value: typeof office == "undefined" ? undefined : office.website_fi,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">Svenska</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "website_sv",
                                size: 100,
                                value: typeof office == "undefined" ? undefined : office.website_sv,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">English</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "website_en",
                                size: 100,
                                value: typeof office == "undefined" ? undefined : office.website_en,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row input-button-row">\n            <button');
                            buf.push(attrs({
                                "x-data-object-container-id": "object-" + office.safe_uid,
                                "class": "edit-office-button"
                            }, {
                                "x-data-object-container-id": true
                            }));
                            buf.push(">");
                            var __val__ = "Tallenna" || MTN.t("Save");
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</button>");
                            var __val__ = " ";
                            buf.push(null == __val__ ? "" : __val__);
                            buf.push("\n            <button");
                            buf.push(attrs({
                                "x-data-object-container-id": "object-" + office.safe_uid,
                                "class": "remove-office-button"
                            }, {
                                "x-data-object-container-id": true
                            }));
                            buf.push(">");
                            var __val__ = "Poista" || MTN.t("Remove");
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</button>");
                            var __val__ = " ";
                            buf.push(null == __val__ ? "" : __val__);
                            buf.push('<span class="save-reopen-indicator">');
                            var __val__ = "Toimisto tallennettu onnistuneesti!";
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</span>\n          </div>\n        </div>\n      </div>");
                        }
                    } else {
                        var $$l = 0;
                        for (var $index in offices) {
                            $$l++;
                            var office = offices[$index];
                            buf.push("\n      <div");
                            buf.push(attrs({
                                id: "object-" + office.safe_uid,
                                "class": "object-container"
                            }, {
                                id: true
                            }));
                            buf.push('>\n        <h5 class="office-name-container"><span class="office-name">');
                            var __val__ = office.full_name;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</span><a");
                            buf.push(attrs({
                                href: "#",
                                "x-data-object-id": office.safe_uid,
                                "class": "object-edit-button" + " " + "plus"
                            }, {
                                href: true,
                                "x-data-object-id": true
                            }));
                            buf.push(">");
                            var __val__ = " [muokkaa]";
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</a><a");
                            buf.push(attrs({
                                href: "#",
                                "x-data-object-id": office.safe_uid,
                                style: "display:none",
                                "class": "object-edit-button" + " " + "minus"
                            }, {
                                href: true,
                                "x-data-object-id": true,
                                style: true
                            }));
                            buf.push(">");
                            var __val__ = " [peruuta muokkaus]";
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push('</a></h5>\n        <div style="display:none" class="object-editor">\n          <div class="input-row"><span class="input-label">Toimiston nimi</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "name",
                                size: 40,
                                value: typeof office == "undefined" ? undefined : office.name,
                                disabled: typeof office == "undefined" ? undefined : "disabled",
                                "class": "object-field" + " " + "open-focus-target"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true,
                                disabled: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">Alaryhmä</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "subgroup",
                                size: 40,
                                value: typeof office == "undefined" ? undefined : office.subgroup,
                                disabled: typeof office == "undefined" ? undefined : "disabled",
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true,
                                disabled: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">Yhteinen email</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "group_email",
                                size: 40,
                                value: typeof office == "undefined" ? undefined : office.group_email,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row">\n            <div class="input-label-row"><span class="input-label">Aukioloajat:</span></div>\n          </div>\n          <div class="input-row"><span class="input-label">MA</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "open_mon",
                                size: 25,
                                value: typeof office == "undefined" ? undefined : office.open_mon,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/><span class="input-hint">(esim. "9:00-17:00" tai "9:00-11:00; 12:00-19:00")</span>\n          </div>\n          <div class="input-row"><span class="input-label">TI</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "open_tue",
                                size: 25,
                                value: typeof office == "undefined" ? undefined : office.open_tue,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">KE</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "open_wed",
                                size: 25,
                                value: typeof office == "undefined" ? undefined : office.open_wed,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">TO</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "open_thu",
                                size: 25,
                                value: typeof office == "undefined" ? undefined : office.open_thu,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">PE</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "open_fri",
                                size: 25,
                                value: typeof office == "undefined" ? undefined : office.open_fri,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row">\n            <div class="input-label-row"><span class="input-label">Osoite:</span></div>\n          </div>\n          <div class="input-row"><span class="input-label">Suomi</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "address_fi",
                                size: 40,
                                value: typeof office == "undefined" ? undefined : office.address_fi,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">Svenska</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "address_sv",
                                size: 40,
                                value: typeof office == "undefined" ? undefined : office.address_sv,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">English</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "address_en",
                                size: 40,
                                value: typeof office == "undefined" ? undefined : office.address_en,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row">\n            <div class="input-label-row"><span class="input-label">Saapumisohjeet:</span></div>\n          </div>\n          <div class="input-row"><span class="input-label">Suomi</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "instructions_fi",
                                size: 100,
                                value: typeof office == "undefined" ? undefined : office.instructions_fi,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">Svenska</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "instructions_sv",
                                size: 100,
                                value: typeof office == "undefined" ? undefined : office.instructions_sv,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">English</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "instructions_en",
                                size: 100,
                                value: typeof office == "undefined" ? undefined : office.instructions_en,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row">\n            <div class="input-label-row"><span class="input-label">Verkkosivu:</span></div>\n          </div>\n          <div class="input-row"><span class="input-label">Suomi</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "website_fi",
                                size: 100,
                                value: typeof office == "undefined" ? undefined : office.website_fi,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">Svenska</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "website_sv",
                                size: 100,
                                value: typeof office == "undefined" ? undefined : office.website_sv,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">English</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "website_en",
                                size: 100,
                                value: typeof office == "undefined" ? undefined : office.website_en,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row input-button-row">\n            <button');
                            buf.push(attrs({
                                "x-data-object-container-id": "object-" + office.safe_uid,
                                "class": "edit-office-button"
                            }, {
                                "x-data-object-container-id": true
                            }));
                            buf.push(">");
                            var __val__ = "Tallenna" || MTN.t("Save");
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</button>");
                            var __val__ = " ";
                            buf.push(null == __val__ ? "" : __val__);
                            buf.push("\n            <button");
                            buf.push(attrs({
                                "x-data-object-container-id": "object-" + office.safe_uid,
                                "class": "remove-office-button"
                            }, {
                                "x-data-object-container-id": true
                            }));
                            buf.push(">");
                            var __val__ = "Poista" || MTN.t("Remove");
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</button>");
                            var __val__ = " ";
                            buf.push(null == __val__ ? "" : __val__);
                            buf.push('<span class="save-reopen-indicator">');
                            var __val__ = "Toimisto tallennettu onnistuneesti!";
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</span>\n          </div>\n        </div>\n      </div>");
                        }
                    }
                }).call(this);
                buf.push("\n    </div>");
            }
        }
        if (selected_area && selected_section == "calendars") {
            {
                buf.push('\n    <h4><span>Kalenterit</span><a href="#" class="show-object-adding">');
                var __val__ = " [lisää]";
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push('</a><a href="#" style="display:none" class="hide-object-adding">');
                var __val__ = " [peruuta lisääminen]";
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push('</a></h4>\n    <div id="object-adding-container" style="display:none">\n      <div class="input-row"><span class="input-label">Käyttäjä</span>\n        <select');
                buf.push(attrs({
                    "x-data-object-field": "user_email",
                    disabled: typeof admin_calendar == "undefined" ? undefined : "disabled",
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    disabled: true
                }));
                buf.push('>\n          <option value="">[valitse käyttäjä]</option>');
                (function() {
                    if ("number" == typeof users.length) {
                        for (var $index = 0, $$l = users.length; $index < $$l; $index++) {
                            var u = users[$index];
                            buf.push("\n          <option");
                            buf.push(attrs({
                                value: u.email,
                                selected: u.email == (typeof admin_calendar == "undefined" ? undefined : admin_calendar.user_email) ? "selected" : undefined
                            }, {
                                value: true,
                                selected: true
                            }));
                            buf.push(">");
                            var __val__ = u.email;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</option>");
                        }
                    } else {
                        var $$l = 0;
                        for (var $index in users) {
                            $$l++;
                            var u = users[$index];
                            buf.push("\n          <option");
                            buf.push(attrs({
                                value: u.email,
                                selected: u.email == (typeof admin_calendar == "undefined" ? undefined : admin_calendar.user_email) ? "selected" : undefined
                            }, {
                                value: true,
                                selected: true
                            }));
                            buf.push(">");
                            var __val__ = u.email;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</option>");
                        }
                    }
                }).call(this);
                buf.push('\n        </select>\n      </div>\n      <div class="input-row"><span class="input-label">Toimisto</span>\n        <select');
                buf.push(attrs({
                    "x-data-object-field": "office_full_name",
                    disabled: typeof admin_calendar == "undefined" ? undefined : "disabled",
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    disabled: true
                }));
                buf.push('>\n          <option value="">[valitse toimisto]</option>');
                (function() {
                    if ("number" == typeof offices.length) {
                        for (var $index = 0, $$l = offices.length; $index < $$l; $index++) {
                            var o = offices[$index];
                            buf.push("\n          <option");
                            buf.push(attrs({
                                value: o.full_name,
                                selected: o.full_name == (typeof admin_calendar == "undefined" ? undefined : admin_calendar.office_full_name) ? "selected" : undefined
                            }, {
                                value: true,
                                selected: true
                            }));
                            buf.push(">");
                            var __val__ = o.full_name;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</option>");
                        }
                    } else {
                        var $$l = 0;
                        for (var $index in offices) {
                            $$l++;
                            var o = offices[$index];
                            buf.push("\n          <option");
                            buf.push(attrs({
                                value: o.full_name,
                                selected: o.full_name == (typeof admin_calendar == "undefined" ? undefined : admin_calendar.office_full_name) ? "selected" : undefined
                            }, {
                                value: true,
                                selected: true
                            }));
                            buf.push(">");
                            var __val__ = o.full_name;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</option>");
                        }
                    }
                }).call(this);
                buf.push('\n        </select>\n      </div>\n      <div class="input-row">\n        <div class="input-label-row"><span>Palvelukielet:</span></div>');
                (function() {
                    if ("number" == typeof all_languages.length) {
                        for (var $index = 0, $$l = all_languages.length; $index < $$l; $index++) {
                            var lang = all_languages[$index];
                            buf.push("\n        <div>\n          <input");
                            buf.push(attrs({
                                "x-data-object-field": "languages",
                                "x-data-object-field-type": "array",
                                type: "checkbox",
                                value: lang.id,
                                checked: typeof admin_calendar !== "undefined" && admin_calendar.languages_map[lang.id] ? "checked" : undefined,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                "x-data-object-field-type": true,
                                type: true,
                                value: true,
                                checked: true
                            }));
                            buf.push("/><span>");
                            var __val__ = lang.name;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</span>\n        </div>");
                        }
                    } else {
                        var $$l = 0;
                        for (var $index in all_languages) {
                            $$l++;
                            var lang = all_languages[$index];
                            buf.push("\n        <div>\n          <input");
                            buf.push(attrs({
                                "x-data-object-field": "languages",
                                "x-data-object-field-type": "array",
                                type: "checkbox",
                                value: lang.id,
                                checked: typeof admin_calendar !== "undefined" && admin_calendar.languages_map[lang.id] ? "checked" : undefined,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                "x-data-object-field-type": true,
                                type: true,
                                value: true,
                                checked: true
                            }));
                            buf.push("/><span>");
                            var __val__ = lang.name;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</span>\n        </div>");
                        }
                    }
                }).call(this);
                buf.push('\n      </div>\n      <div class="input-row">\n        <div class="input-label-row"><span>Palvelutasot:</span></div>');
                (function() {
                    if ("number" == typeof all_service_levels.length) {
                        for (var $index = 0, $$l = all_service_levels.length; $index < $$l; $index++) {
                            var sl = all_service_levels[$index];
                            buf.push("\n        <div>\n          <input");
                            buf.push(attrs({
                                "x-data-object-field": "service_levels",
                                "x-data-object-field-type": "array",
                                type: "checkbox",
                                value: sl.id,
                                checked: typeof admin_calendar !== "undefined" && admin_calendar.service_levels_map[sl.id] ? "checked" : undefined,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                "x-data-object-field-type": true,
                                type: true,
                                value: true,
                                checked: true
                            }));
                            buf.push("/><span>");
                            var __val__ = sl.name;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</span>\n        </div>");
                        }
                    } else {
                        var $$l = 0;
                        for (var $index in all_service_levels) {
                            $$l++;
                            var sl = all_service_levels[$index];
                            buf.push("\n        <div>\n          <input");
                            buf.push(attrs({
                                "x-data-object-field": "service_levels",
                                "x-data-object-field-type": "array",
                                type: "checkbox",
                                value: sl.id,
                                checked: typeof admin_calendar !== "undefined" && admin_calendar.service_levels_map[sl.id] ? "checked" : undefined,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                "x-data-object-field-type": true,
                                type: true,
                                value: true,
                                checked: true
                            }));
                            buf.push("/><span>");
                            var __val__ = sl.name;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</span>\n        </div>");
                        }
                    }
                }).call(this);
                buf.push('\n      </div>\n      <div class="input-row">\n        <div class="input-label-row"><span>Tapaamistyyypit:</span></div>');
                (function() {
                    if ("number" == typeof all_meeting_types.length) {
                        for (var $index = 0, $$l = all_meeting_types.length; $index < $$l; $index++) {
                            var mt = all_meeting_types[$index];
                            buf.push("\n        <div>\n          <input");
                            buf.push(attrs({
                                "x-data-object-field": "meeting_types",
                                "x-data-object-field-type": "array",
                                type: "checkbox",
                                value: mt.id,
                                checked: typeof admin_calendar !== "undefined" && admin_calendar.meeting_types_map[mt.id] ? "checked" : undefined,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                "x-data-object-field-type": true,
                                type: true,
                                value: true,
                                checked: true
                            }));
                            buf.push("/><span>");
                            var __val__ = mt.name;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</span>\n        </div>");
                        }
                    } else {
                        var $$l = 0;
                        for (var $index in all_meeting_types) {
                            $$l++;
                            var mt = all_meeting_types[$index];
                            buf.push("\n        <div>\n          <input");
                            buf.push(attrs({
                                "x-data-object-field": "meeting_types",
                                "x-data-object-field-type": "array",
                                type: "checkbox",
                                value: mt.id,
                                checked: typeof admin_calendar !== "undefined" && admin_calendar.meeting_types_map[mt.id] ? "checked" : undefined,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                "x-data-object-field-type": true,
                                type: true,
                                value: true,
                                checked: true
                            }));
                            buf.push("/><span>");
                            var __val__ = mt.name;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</span>\n        </div>");
                        }
                    }
                }).call(this);
                buf.push('\n      </div>\n      <div class="input-row">\n        <div class="input-label-row"><span>Verkkotapaamisen</span></div>\n      </div>\n      <div class="input-row"><span class="input-label">osoite</span>\n        <input');
                buf.push(attrs({
                    "x-data-object-field": "extra_meeting_email",
                    size: 40,
                    value: typeof admin_calendar == "undefined" ? undefined : admin_calendar.extra_meeting_email,
                    "class": "object-field"
                }, {
                    "x-data-object-field": true,
                    size: true,
                    value: true
                }));
                buf.push('/>\n      </div>\n      <div class="input-row">\n        <div class="input-label-row"><span>Kalenterin rajattu saatavuus:</span></div>\n      </div>\n      <div class="input-row"><span class="input-label">Ensimmäinen varattava päivä</span>\n        <input');
                buf.push(attrs({
                    id: "first-day-" + (typeof admin_calendar == "undefined" ? "new" : admin_calendar.safe_uid),
                    "x-data-object-field": "first_reservable_day",
                    size: 10,
                    value: typeof admin_calendar == "undefined" ? undefined : admin_calendar.first_reservable_day,
                    "class": "object-field" + " " + "js_dmy_datepicker_input"
                }, {
                    id: true,
                    "x-data-object-field": true,
                    size: true,
                    value: true
                }));
                buf.push('/>\n      </div>\n      <div class="input-row"><span class="input-label">Viimeinen varattava päivä</span>\n        <input');
                buf.push(attrs({
                    id: "last-day-" + (typeof admin_calendar == "undefined" ? "new" : admin_calendar.safe_uid),
                    "x-data-object-field": "last_reservable_day",
                    size: 10,
                    value: typeof admin_calendar == "undefined" ? undefined : admin_calendar.last_reservable_day,
                    "class": "object-field" + " " + "js_dmy_datepicker_input"
                }, {
                    id: true,
                    "x-data-object-field": true,
                    size: true,
                    value: true
                }));
                buf.push("/>\n      </div>");
                if (selected_area == "esim") {
                    {
                        buf.push('\n      <div class="input-row"><span class="input-label">Yhdistä sisäinen kalenteri</span>\n        <select x-data-object-field="disable_calendar_sync" class="object-field">\n          <option value="">Kyllä</option>\n          <option');
                        buf.push(attrs({
                            value: "yes",
                            selected: "yes" == (typeof admin_calendar == "undefined" ? undefined : admin_calendar.disable_calendar_sync) ? "selected" : undefined
                        }, {
                            value: true,
                            selected: true
                        }));
                        buf.push(">Ei</option>\n        </select>\n      </div>");
                    }
                }
                buf.push('\n      <div class="input-row input-button-row">\n        <button class="add-calendar-button">');
                var __val__ = "Lisää" || MTN.t("Add");
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</button>");
                var __val__ = " ";
                buf.push(null == __val__ ? "" : __val__);
                buf.push('<span class="save-reopen-indicator">');
                var __val__ = "Kalenteri lisätty onnistuneesti!";
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push('</span>\n      </div>\n    </div>\n    <div class="calendar-listing">');
                (function() {
                    if ("number" == typeof calendars.length) {
                        for (var $index = 0, $$l = calendars.length; $index < $$l; $index++) {
                            var admin_calendar = calendars[$index];
                            buf.push("\n      <div");
                            buf.push(attrs({
                                id: "object-" + admin_calendar.safe_uid,
                                "class": "object-container"
                            }, {
                                id: true
                            }));
                            buf.push('>\n        <h5 class="calendar-name-container"><span class="calendar-name">');
                            var __val__ = admin_calendar.office_full_name + " - " + admin_calendar.user_email;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</span><a");
                            buf.push(attrs({
                                href: "#",
                                "x-data-object-id": admin_calendar.safe_uid,
                                "class": "object-edit-button" + " " + "plus"
                            }, {
                                href: true,
                                "x-data-object-id": true
                            }));
                            buf.push(">");
                            var __val__ = " [muokkaa]";
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</a><a");
                            buf.push(attrs({
                                href: "#",
                                "x-data-object-id": admin_calendar.safe_uid,
                                style: "display:none",
                                "class": "object-edit-button" + " " + "minus"
                            }, {
                                href: true,
                                "x-data-object-id": true,
                                style: true
                            }));
                            buf.push(">");
                            var __val__ = " [peruuta muokkaus]";
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push('</a></h5>\n        <div style="display:none" class="object-editor">\n          <div class="input-row"><span class="input-label">Käyttäjä</span>\n            <select');
                            buf.push(attrs({
                                "x-data-object-field": "user_email",
                                disabled: typeof admin_calendar == "undefined" ? undefined : "disabled",
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                disabled: true
                            }));
                            buf.push('>\n              <option value="">[valitse käyttäjä]</option>');
                            (function() {
                                if ("number" == typeof users.length) {
                                    for (var $index = 0, $$l = users.length; $index < $$l; $index++) {
                                        var u = users[$index];
                                        buf.push("\n              <option");
                                        buf.push(attrs({
                                            value: u.email,
                                            selected: u.email == (typeof admin_calendar == "undefined" ? undefined : admin_calendar.user_email) ? "selected" : undefined
                                        }, {
                                            value: true,
                                            selected: true
                                        }));
                                        buf.push(">");
                                        var __val__ = u.email;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</option>");
                                    }
                                } else {
                                    var $$l = 0;
                                    for (var $index in users) {
                                        $$l++;
                                        var u = users[$index];
                                        buf.push("\n              <option");
                                        buf.push(attrs({
                                            value: u.email,
                                            selected: u.email == (typeof admin_calendar == "undefined" ? undefined : admin_calendar.user_email) ? "selected" : undefined
                                        }, {
                                            value: true,
                                            selected: true
                                        }));
                                        buf.push(">");
                                        var __val__ = u.email;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</option>");
                                    }
                                }
                            }).call(this);
                            buf.push('\n            </select>\n          </div>\n          <div class="input-row"><span class="input-label">Toimisto</span>\n            <select');
                            buf.push(attrs({
                                "x-data-object-field": "office_full_name",
                                disabled: typeof admin_calendar == "undefined" ? undefined : "disabled",
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                disabled: true
                            }));
                            buf.push('>\n              <option value="">[valitse toimisto]</option>');
                            (function() {
                                if ("number" == typeof offices.length) {
                                    for (var $index = 0, $$l = offices.length; $index < $$l; $index++) {
                                        var o = offices[$index];
                                        buf.push("\n              <option");
                                        buf.push(attrs({
                                            value: o.full_name,
                                            selected: o.full_name == (typeof admin_calendar == "undefined" ? undefined : admin_calendar.office_full_name) ? "selected" : undefined
                                        }, {
                                            value: true,
                                            selected: true
                                        }));
                                        buf.push(">");
                                        var __val__ = o.full_name;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</option>");
                                    }
                                } else {
                                    var $$l = 0;
                                    for (var $index in offices) {
                                        $$l++;
                                        var o = offices[$index];
                                        buf.push("\n              <option");
                                        buf.push(attrs({
                                            value: o.full_name,
                                            selected: o.full_name == (typeof admin_calendar == "undefined" ? undefined : admin_calendar.office_full_name) ? "selected" : undefined
                                        }, {
                                            value: true,
                                            selected: true
                                        }));
                                        buf.push(">");
                                        var __val__ = o.full_name;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</option>");
                                    }
                                }
                            }).call(this);
                            buf.push('\n            </select>\n          </div>\n          <div class="input-row">\n            <div class="input-label-row"><span>Palvelukielet:</span></div>');
                            (function() {
                                if ("number" == typeof all_languages.length) {
                                    for (var $index = 0, $$l = all_languages.length; $index < $$l; $index++) {
                                        var lang = all_languages[$index];
                                        buf.push("\n            <div>\n              <input");
                                        buf.push(attrs({
                                            "x-data-object-field": "languages",
                                            "x-data-object-field-type": "array",
                                            type: "checkbox",
                                            value: lang.id,
                                            checked: typeof admin_calendar !== "undefined" && admin_calendar.languages_map[lang.id] ? "checked" : undefined,
                                            "class": "object-field"
                                        }, {
                                            "x-data-object-field": true,
                                            "x-data-object-field-type": true,
                                            type: true,
                                            value: true,
                                            checked: true
                                        }));
                                        buf.push("/><span>");
                                        var __val__ = lang.name;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</span>\n            </div>");
                                    }
                                } else {
                                    var $$l = 0;
                                    for (var $index in all_languages) {
                                        $$l++;
                                        var lang = all_languages[$index];
                                        buf.push("\n            <div>\n              <input");
                                        buf.push(attrs({
                                            "x-data-object-field": "languages",
                                            "x-data-object-field-type": "array",
                                            type: "checkbox",
                                            value: lang.id,
                                            checked: typeof admin_calendar !== "undefined" && admin_calendar.languages_map[lang.id] ? "checked" : undefined,
                                            "class": "object-field"
                                        }, {
                                            "x-data-object-field": true,
                                            "x-data-object-field-type": true,
                                            type: true,
                                            value: true,
                                            checked: true
                                        }));
                                        buf.push("/><span>");
                                        var __val__ = lang.name;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</span>\n            </div>");
                                    }
                                }
                            }).call(this);
                            buf.push('\n          </div>\n          <div class="input-row">\n            <div class="input-label-row"><span>Palvelutasot:</span></div>');
                            (function() {
                                if ("number" == typeof all_service_levels.length) {
                                    for (var $index = 0, $$l = all_service_levels.length; $index < $$l; $index++) {
                                        var sl = all_service_levels[$index];
                                        buf.push("\n            <div>\n              <input");
                                        buf.push(attrs({
                                            "x-data-object-field": "service_levels",
                                            "x-data-object-field-type": "array",
                                            type: "checkbox",
                                            value: sl.id,
                                            checked: typeof admin_calendar !== "undefined" && admin_calendar.service_levels_map[sl.id] ? "checked" : undefined,
                                            "class": "object-field"
                                        }, {
                                            "x-data-object-field": true,
                                            "x-data-object-field-type": true,
                                            type: true,
                                            value: true,
                                            checked: true
                                        }));
                                        buf.push("/><span>");
                                        var __val__ = sl.name;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</span>\n            </div>");
                                    }
                                } else {
                                    var $$l = 0;
                                    for (var $index in all_service_levels) {
                                        $$l++;
                                        var sl = all_service_levels[$index];
                                        buf.push("\n            <div>\n              <input");
                                        buf.push(attrs({
                                            "x-data-object-field": "service_levels",
                                            "x-data-object-field-type": "array",
                                            type: "checkbox",
                                            value: sl.id,
                                            checked: typeof admin_calendar !== "undefined" && admin_calendar.service_levels_map[sl.id] ? "checked" : undefined,
                                            "class": "object-field"
                                        }, {
                                            "x-data-object-field": true,
                                            "x-data-object-field-type": true,
                                            type: true,
                                            value: true,
                                            checked: true
                                        }));
                                        buf.push("/><span>");
                                        var __val__ = sl.name;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</span>\n            </div>");
                                    }
                                }
                            }).call(this);
                            buf.push('\n          </div>\n          <div class="input-row">\n            <div class="input-label-row"><span>Tapaamistyyypit:</span></div>');
                            (function() {
                                if ("number" == typeof all_meeting_types.length) {
                                    for (var $index = 0, $$l = all_meeting_types.length; $index < $$l; $index++) {
                                        var mt = all_meeting_types[$index];
                                        buf.push("\n            <div>\n              <input");
                                        buf.push(attrs({
                                            "x-data-object-field": "meeting_types",
                                            "x-data-object-field-type": "array",
                                            type: "checkbox",
                                            value: mt.id,
                                            checked: typeof admin_calendar !== "undefined" && admin_calendar.meeting_types_map[mt.id] ? "checked" : undefined,
                                            "class": "object-field"
                                        }, {
                                            "x-data-object-field": true,
                                            "x-data-object-field-type": true,
                                            type: true,
                                            value: true,
                                            checked: true
                                        }));
                                        buf.push("/><span>");
                                        var __val__ = mt.name;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</span>\n            </div>");
                                    }
                                } else {
                                    var $$l = 0;
                                    for (var $index in all_meeting_types) {
                                        $$l++;
                                        var mt = all_meeting_types[$index];
                                        buf.push("\n            <div>\n              <input");
                                        buf.push(attrs({
                                            "x-data-object-field": "meeting_types",
                                            "x-data-object-field-type": "array",
                                            type: "checkbox",
                                            value: mt.id,
                                            checked: typeof admin_calendar !== "undefined" && admin_calendar.meeting_types_map[mt.id] ? "checked" : undefined,
                                            "class": "object-field"
                                        }, {
                                            "x-data-object-field": true,
                                            "x-data-object-field-type": true,
                                            type: true,
                                            value: true,
                                            checked: true
                                        }));
                                        buf.push("/><span>");
                                        var __val__ = mt.name;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</span>\n            </div>");
                                    }
                                }
                            }).call(this);
                            buf.push('\n          </div>\n          <div class="input-row">\n            <div class="input-label-row"><span>Verkkotapaamisen</span></div>\n          </div>\n          <div class="input-row"><span class="input-label">osoite</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "extra_meeting_email",
                                size: 40,
                                value: typeof admin_calendar == "undefined" ? undefined : admin_calendar.extra_meeting_email,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row">\n            <div class="input-label-row"><span>Kalenterin rajattu saatavuus:</span></div>\n          </div>\n          <div class="input-row"><span class="input-label">Ensimmäinen varattava päivä</span>\n            <input');
                            buf.push(attrs({
                                id: "first-day-" + (typeof admin_calendar == "undefined" ? "new" : admin_calendar.safe_uid),
                                "x-data-object-field": "first_reservable_day",
                                size: 10,
                                value: typeof admin_calendar == "undefined" ? undefined : admin_calendar.first_reservable_day,
                                "class": "object-field" + " " + "js_dmy_datepicker_input"
                            }, {
                                id: true,
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">Viimeinen varattava päivä</span>\n            <input');
                            buf.push(attrs({
                                id: "last-day-" + (typeof admin_calendar == "undefined" ? "new" : admin_calendar.safe_uid),
                                "x-data-object-field": "last_reservable_day",
                                size: 10,
                                value: typeof admin_calendar == "undefined" ? undefined : admin_calendar.last_reservable_day,
                                "class": "object-field" + " " + "js_dmy_datepicker_input"
                            }, {
                                id: true,
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push("/>\n          </div>");
                            if (selected_area == "esim") {
                                {
                                    buf.push('\n          <div class="input-row"><span class="input-label">Yhdistä sisäinen kalenteri</span>\n            <select x-data-object-field="disable_calendar_sync" class="object-field">\n              <option value="">Kyllä</option>\n              <option');
                                    buf.push(attrs({
                                        value: "yes",
                                        selected: "yes" == (typeof admin_calendar == "undefined" ? undefined : admin_calendar.disable_calendar_sync) ? "selected" : undefined
                                    }, {
                                        value: true,
                                        selected: true
                                    }));
                                    buf.push(">Ei</option>\n            </select>\n          </div>");
                                }
                            }
                            buf.push('\n          <div class="input-row input-button-row">\n            <button');
                            buf.push(attrs({
                                "x-data-object-container-id": "object-" + admin_calendar.safe_uid,
                                "class": "edit-calendar-button"
                            }, {
                                "x-data-object-container-id": true
                            }));
                            buf.push(">");
                            var __val__ = "Tallenna" || MTN.t("Save");
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</button>");
                            var __val__ = " ";
                            buf.push(null == __val__ ? "" : __val__);
                            buf.push("\n            <button");
                            buf.push(attrs({
                                "x-data-object-container-id": "object-" + admin_calendar.safe_uid,
                                "class": "remove-calendar-button"
                            }, {
                                "x-data-object-container-id": true
                            }));
                            buf.push(">");
                            var __val__ = "Poista" || MTN.t("Remove");
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</button>");
                            var __val__ = " ";
                            buf.push(null == __val__ ? "" : __val__);
                            buf.push('<span class="save-reopen-indicator">');
                            var __val__ = "Kalenteri tallennettu onnistuneesti!";
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</span>\n          </div>\n        </div>\n      </div>");
                        }
                    } else {
                        var $$l = 0;
                        for (var $index in calendars) {
                            $$l++;
                            var admin_calendar = calendars[$index];
                            buf.push("\n      <div");
                            buf.push(attrs({
                                id: "object-" + admin_calendar.safe_uid,
                                "class": "object-container"
                            }, {
                                id: true
                            }));
                            buf.push('>\n        <h5 class="calendar-name-container"><span class="calendar-name">');
                            var __val__ = admin_calendar.office_full_name + " - " + admin_calendar.user_email;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</span><a");
                            buf.push(attrs({
                                href: "#",
                                "x-data-object-id": admin_calendar.safe_uid,
                                "class": "object-edit-button" + " " + "plus"
                            }, {
                                href: true,
                                "x-data-object-id": true
                            }));
                            buf.push(">");
                            var __val__ = " [muokkaa]";
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</a><a");
                            buf.push(attrs({
                                href: "#",
                                "x-data-object-id": admin_calendar.safe_uid,
                                style: "display:none",
                                "class": "object-edit-button" + " " + "minus"
                            }, {
                                href: true,
                                "x-data-object-id": true,
                                style: true
                            }));
                            buf.push(">");
                            var __val__ = " [peruuta muokkaus]";
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push('</a></h5>\n        <div style="display:none" class="object-editor">\n          <div class="input-row"><span class="input-label">Käyttäjä</span>\n            <select');
                            buf.push(attrs({
                                "x-data-object-field": "user_email",
                                disabled: typeof admin_calendar == "undefined" ? undefined : "disabled",
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                disabled: true
                            }));
                            buf.push('>\n              <option value="">[valitse käyttäjä]</option>');
                            (function() {
                                if ("number" == typeof users.length) {
                                    for (var $index = 0, $$l = users.length; $index < $$l; $index++) {
                                        var u = users[$index];
                                        buf.push("\n              <option");
                                        buf.push(attrs({
                                            value: u.email,
                                            selected: u.email == (typeof admin_calendar == "undefined" ? undefined : admin_calendar.user_email) ? "selected" : undefined
                                        }, {
                                            value: true,
                                            selected: true
                                        }));
                                        buf.push(">");
                                        var __val__ = u.email;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</option>");
                                    }
                                } else {
                                    var $$l = 0;
                                    for (var $index in users) {
                                        $$l++;
                                        var u = users[$index];
                                        buf.push("\n              <option");
                                        buf.push(attrs({
                                            value: u.email,
                                            selected: u.email == (typeof admin_calendar == "undefined" ? undefined : admin_calendar.user_email) ? "selected" : undefined
                                        }, {
                                            value: true,
                                            selected: true
                                        }));
                                        buf.push(">");
                                        var __val__ = u.email;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</option>");
                                    }
                                }
                            }).call(this);
                            buf.push('\n            </select>\n          </div>\n          <div class="input-row"><span class="input-label">Toimisto</span>\n            <select');
                            buf.push(attrs({
                                "x-data-object-field": "office_full_name",
                                disabled: typeof admin_calendar == "undefined" ? undefined : "disabled",
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                disabled: true
                            }));
                            buf.push('>\n              <option value="">[valitse toimisto]</option>');
                            (function() {
                                if ("number" == typeof offices.length) {
                                    for (var $index = 0, $$l = offices.length; $index < $$l; $index++) {
                                        var o = offices[$index];
                                        buf.push("\n              <option");
                                        buf.push(attrs({
                                            value: o.full_name,
                                            selected: o.full_name == (typeof admin_calendar == "undefined" ? undefined : admin_calendar.office_full_name) ? "selected" : undefined
                                        }, {
                                            value: true,
                                            selected: true
                                        }));
                                        buf.push(">");
                                        var __val__ = o.full_name;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</option>");
                                    }
                                } else {
                                    var $$l = 0;
                                    for (var $index in offices) {
                                        $$l++;
                                        var o = offices[$index];
                                        buf.push("\n              <option");
                                        buf.push(attrs({
                                            value: o.full_name,
                                            selected: o.full_name == (typeof admin_calendar == "undefined" ? undefined : admin_calendar.office_full_name) ? "selected" : undefined
                                        }, {
                                            value: true,
                                            selected: true
                                        }));
                                        buf.push(">");
                                        var __val__ = o.full_name;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</option>");
                                    }
                                }
                            }).call(this);
                            buf.push('\n            </select>\n          </div>\n          <div class="input-row">\n            <div class="input-label-row"><span>Palvelukielet:</span></div>');
                            (function() {
                                if ("number" == typeof all_languages.length) {
                                    for (var $index = 0, $$l = all_languages.length; $index < $$l; $index++) {
                                        var lang = all_languages[$index];
                                        buf.push("\n            <div>\n              <input");
                                        buf.push(attrs({
                                            "x-data-object-field": "languages",
                                            "x-data-object-field-type": "array",
                                            type: "checkbox",
                                            value: lang.id,
                                            checked: typeof admin_calendar !== "undefined" && admin_calendar.languages_map[lang.id] ? "checked" : undefined,
                                            "class": "object-field"
                                        }, {
                                            "x-data-object-field": true,
                                            "x-data-object-field-type": true,
                                            type: true,
                                            value: true,
                                            checked: true
                                        }));
                                        buf.push("/><span>");
                                        var __val__ = lang.name;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</span>\n            </div>");
                                    }
                                } else {
                                    var $$l = 0;
                                    for (var $index in all_languages) {
                                        $$l++;
                                        var lang = all_languages[$index];
                                        buf.push("\n            <div>\n              <input");
                                        buf.push(attrs({
                                            "x-data-object-field": "languages",
                                            "x-data-object-field-type": "array",
                                            type: "checkbox",
                                            value: lang.id,
                                            checked: typeof admin_calendar !== "undefined" && admin_calendar.languages_map[lang.id] ? "checked" : undefined,
                                            "class": "object-field"
                                        }, {
                                            "x-data-object-field": true,
                                            "x-data-object-field-type": true,
                                            type: true,
                                            value: true,
                                            checked: true
                                        }));
                                        buf.push("/><span>");
                                        var __val__ = lang.name;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</span>\n            </div>");
                                    }
                                }
                            }).call(this);
                            buf.push('\n          </div>\n          <div class="input-row">\n            <div class="input-label-row"><span>Palvelutasot:</span></div>');
                            (function() {
                                if ("number" == typeof all_service_levels.length) {
                                    for (var $index = 0, $$l = all_service_levels.length; $index < $$l; $index++) {
                                        var sl = all_service_levels[$index];
                                        buf.push("\n            <div>\n              <input");
                                        buf.push(attrs({
                                            "x-data-object-field": "service_levels",
                                            "x-data-object-field-type": "array",
                                            type: "checkbox",
                                            value: sl.id,
                                            checked: typeof admin_calendar !== "undefined" && admin_calendar.service_levels_map[sl.id] ? "checked" : undefined,
                                            "class": "object-field"
                                        }, {
                                            "x-data-object-field": true,
                                            "x-data-object-field-type": true,
                                            type: true,
                                            value: true,
                                            checked: true
                                        }));
                                        buf.push("/><span>");
                                        var __val__ = sl.name;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</span>\n            </div>");
                                    }
                                } else {
                                    var $$l = 0;
                                    for (var $index in all_service_levels) {
                                        $$l++;
                                        var sl = all_service_levels[$index];
                                        buf.push("\n            <div>\n              <input");
                                        buf.push(attrs({
                                            "x-data-object-field": "service_levels",
                                            "x-data-object-field-type": "array",
                                            type: "checkbox",
                                            value: sl.id,
                                            checked: typeof admin_calendar !== "undefined" && admin_calendar.service_levels_map[sl.id] ? "checked" : undefined,
                                            "class": "object-field"
                                        }, {
                                            "x-data-object-field": true,
                                            "x-data-object-field-type": true,
                                            type: true,
                                            value: true,
                                            checked: true
                                        }));
                                        buf.push("/><span>");
                                        var __val__ = sl.name;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</span>\n            </div>");
                                    }
                                }
                            }).call(this);
                            buf.push('\n          </div>\n          <div class="input-row">\n            <div class="input-label-row"><span>Tapaamistyyypit:</span></div>');
                            (function() {
                                if ("number" == typeof all_meeting_types.length) {
                                    for (var $index = 0, $$l = all_meeting_types.length; $index < $$l; $index++) {
                                        var mt = all_meeting_types[$index];
                                        buf.push("\n            <div>\n              <input");
                                        buf.push(attrs({
                                            "x-data-object-field": "meeting_types",
                                            "x-data-object-field-type": "array",
                                            type: "checkbox",
                                            value: mt.id,
                                            checked: typeof admin_calendar !== "undefined" && admin_calendar.meeting_types_map[mt.id] ? "checked" : undefined,
                                            "class": "object-field"
                                        }, {
                                            "x-data-object-field": true,
                                            "x-data-object-field-type": true,
                                            type: true,
                                            value: true,
                                            checked: true
                                        }));
                                        buf.push("/><span>");
                                        var __val__ = mt.name;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</span>\n            </div>");
                                    }
                                } else {
                                    var $$l = 0;
                                    for (var $index in all_meeting_types) {
                                        $$l++;
                                        var mt = all_meeting_types[$index];
                                        buf.push("\n            <div>\n              <input");
                                        buf.push(attrs({
                                            "x-data-object-field": "meeting_types",
                                            "x-data-object-field-type": "array",
                                            type: "checkbox",
                                            value: mt.id,
                                            checked: typeof admin_calendar !== "undefined" && admin_calendar.meeting_types_map[mt.id] ? "checked" : undefined,
                                            "class": "object-field"
                                        }, {
                                            "x-data-object-field": true,
                                            "x-data-object-field-type": true,
                                            type: true,
                                            value: true,
                                            checked: true
                                        }));
                                        buf.push("/><span>");
                                        var __val__ = mt.name;
                                        buf.push(escape(null == __val__ ? "" : __val__));
                                        buf.push("</span>\n            </div>");
                                    }
                                }
                            }).call(this);
                            buf.push('\n          </div>\n          <div class="input-row">\n            <div class="input-label-row"><span>Verkkotapaamisen</span></div>\n          </div>\n          <div class="input-row"><span class="input-label">osoite</span>\n            <input');
                            buf.push(attrs({
                                "x-data-object-field": "extra_meeting_email",
                                size: 40,
                                value: typeof admin_calendar == "undefined" ? undefined : admin_calendar.extra_meeting_email,
                                "class": "object-field"
                            }, {
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row">\n            <div class="input-label-row"><span>Kalenterin rajattu saatavuus:</span></div>\n          </div>\n          <div class="input-row"><span class="input-label">Ensimmäinen varattava päivä</span>\n            <input');
                            buf.push(attrs({
                                id: "first-day-" + (typeof admin_calendar == "undefined" ? "new" : admin_calendar.safe_uid),
                                "x-data-object-field": "first_reservable_day",
                                size: 10,
                                value: typeof admin_calendar == "undefined" ? undefined : admin_calendar.first_reservable_day,
                                "class": "object-field" + " " + "js_dmy_datepicker_input"
                            }, {
                                id: true,
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push('/>\n          </div>\n          <div class="input-row"><span class="input-label">Viimeinen varattava päivä</span>\n            <input');
                            buf.push(attrs({
                                id: "last-day-" + (typeof admin_calendar == "undefined" ? "new" : admin_calendar.safe_uid),
                                "x-data-object-field": "last_reservable_day",
                                size: 10,
                                value: typeof admin_calendar == "undefined" ? undefined : admin_calendar.last_reservable_day,
                                "class": "object-field" + " " + "js_dmy_datepicker_input"
                            }, {
                                id: true,
                                "x-data-object-field": true,
                                size: true,
                                value: true
                            }));
                            buf.push("/>\n          </div>");
                            if (selected_area == "esim") {
                                {
                                    buf.push('\n          <div class="input-row"><span class="input-label">Yhdistä sisäinen kalenteri</span>\n            <select x-data-object-field="disable_calendar_sync" class="object-field">\n              <option value="">Kyllä</option>\n              <option');
                                    buf.push(attrs({
                                        value: "yes",
                                        selected: "yes" == (typeof admin_calendar == "undefined" ? undefined : admin_calendar.disable_calendar_sync) ? "selected" : undefined
                                    }, {
                                        value: true,
                                        selected: true
                                    }));
                                    buf.push(">Ei</option>\n            </select>\n          </div>");
                                }
                            }
                            buf.push('\n          <div class="input-row input-button-row">\n            <button');
                            buf.push(attrs({
                                "x-data-object-container-id": "object-" + admin_calendar.safe_uid,
                                "class": "edit-calendar-button"
                            }, {
                                "x-data-object-container-id": true
                            }));
                            buf.push(">");
                            var __val__ = "Tallenna" || MTN.t("Save");
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</button>");
                            var __val__ = " ";
                            buf.push(null == __val__ ? "" : __val__);
                            buf.push("\n            <button");
                            buf.push(attrs({
                                "x-data-object-container-id": "object-" + admin_calendar.safe_uid,
                                "class": "remove-calendar-button"
                            }, {
                                "x-data-object-container-id": true
                            }));
                            buf.push(">");
                            var __val__ = "Poista" || MTN.t("Remove");
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</button>");
                            var __val__ = " ";
                            buf.push(null == __val__ ? "" : __val__);
                            buf.push('<span class="save-reopen-indicator">');
                            var __val__ = "Kalenteri tallennettu onnistuneesti!";
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</span>\n          </div>\n        </div>\n      </div>");
                        }
                    }
                }).call(this);
                buf.push("\n    </div>");
            }
        }
        if (selected_area && selected_section == "settings") {
            {
                buf.push('\n    <h4><span>Asetukset</span></h4>\n    <div id="object-general">');
                admin_setting = settings[0];
                buf.push('\n      <div class="input-row">\n        <div class="input-label-row"><span>Tapaamisten pituus:</span></div>\n      </div>\n      <div class="input-row"><span class="input-label">Etutaso 0-1</span>\n        <select x-data-object-field="etutaso0-1_length_minutes" class="object-field">\n          <option');
                buf.push(attrs({
                    value: "60",
                    selected: "60" == (typeof admin_setting == "undefined" ? undefined : admin_setting["etutaso0-1_length_minutes"]) ? "selected" : undefined
                }, {
                    value: true,
                    selected: true
                }));
                buf.push(">1 tunti</option>\n          <option");
                buf.push(attrs({
                    value: "90",
                    selected: "90" == (typeof admin_setting == "undefined" ? undefined : admin_setting["etutaso0-1_length_minutes"]) ? "selected" : undefined
                }, {
                    value: true,
                    selected: true
                }));
                buf.push(">1,5 tuntia</option>\n          <option");
                buf.push(attrs({
                    value: "120",
                    selected: "120" == (typeof admin_setting == "undefined" ? undefined : admin_setting["etutaso0-1_length_minutes"]) ? "selected" : undefined
                }, {
                    value: true,
                    selected: true
                }));
                buf.push('>2 tuntia</option>\n        </select>\n      </div>\n      <div class="input-row"><span class="input-label">Etutaso 2-4</span>\n        <select x-data-object-field="etutaso2-4_length_minutes" class="object-field">\n          <option');
                buf.push(attrs({
                    value: "60",
                    selected: "60" == (typeof admin_setting == "undefined" ? undefined : admin_setting["etutaso2-4_length_minutes"]) ? "selected" : undefined
                }, {
                    value: true,
                    selected: true
                }));
                buf.push(">1 tunti</option>\n          <option");
                buf.push(attrs({
                    value: "90",
                    selected: "90" == (typeof admin_setting == "undefined" ? undefined : admin_setting["etutaso2-4_length_minutes"]) ? "selected" : undefined
                }, {
                    value: true,
                    selected: true
                }));
                buf.push(">1,5 tuntia</option>\n          <option");
                buf.push(attrs({
                    value: "120",
                    selected: "120" == (typeof admin_setting == "undefined" ? undefined : admin_setting["etutaso2-4_length_minutes"]) ? "selected" : undefined
                }, {
                    value: true,
                    selected: true
                }));
                buf.push('>2 tuntia</option>\n        </select>\n      </div>\n      <div class="input-row input-button-row">\n        <button x-data-object-container-id="object-general" class="edit-setting-button">');
                var __val__ = "Tallenna" || MTN.t("Save");
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</button>");
                var __val__ = " ";
                buf.push(null == __val__ ? "" : __val__);
                buf.push('<span class="save-reopen-indicator">');
                var __val__ = "Asetukset tallennettu onnistuneesti!";
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</span>\n      </div>\n    </div>");
            }
        }
        if (selected_area && selected_section == "reports") {
            {
                buf.push("\n    <h4><span>Raportit</span></h4>");
                (function() {
                    if ("number" == typeof reports.length) {
                        for (var $index = 0, $$l = reports.length; $index < $$l; $index++) {
                            var report = reports[$index];
                            buf.push('\n    <div class="input-row"><a');
                            buf.push(attrs({
                                href: report.url
                            }, {
                                href: false
                            }));
                            buf.push(">");
                            var __val__ = report.name;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</a></div>");
                        }
                    } else {
                        var $$l = 0;
                        for (var $index in reports) {
                            $$l++;
                            var report = reports[$index];
                            buf.push('\n    <div class="input-row"><a');
                            buf.push(attrs({
                                href: report.url
                            }, {
                                href: false
                            }));
                            buf.push(">");
                            var __val__ = report.name;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</a></div>");
                        }
                    }
                }).call(this);
            }
        }
        buf.push("\n  </div>\n</div>");
    }
    return buf.join("");
};

// agentManage.jade compiled template
exports.agentManage = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="agent-admin" class="m-modal">\n  <div class="modal-header">\n    <h3> <i class="ico-profile"></i><span>');
        var __val__ = "Tapaamisten hallinta" || MTN.t("Manage meetings");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</span></h3>\n  </div>\n  <div class="modal-content">\n    <div class="area-listing">');
        (function() {
            if ("number" == typeof shared_accounts.length) {
                for (var index = 0, $$l = shared_accounts.length; index < $$l; index++) {
                    var area = shared_accounts[index];
                    buf.push("<a");
                    buf.push(attrs({
                        href: "#",
                        "x-data-area": area.safe_uid,
                        "class": "area-button" + " " + "select-area"
                    }, {
                        href: true,
                        "x-data-area": true
                    }));
                    buf.push(">");
                    var __val__ = area.name;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</a>");
                    if (index < shared_accounts.length - 1) {
                        {
                            var __val__ = " - ";
                            buf.push(escape(null == __val__ ? "" : __val__));
                        }
                    }
                }
            } else {
                var $$l = 0;
                for (var index in shared_accounts) {
                    $$l++;
                    var area = shared_accounts[index];
                    buf.push("<a");
                    buf.push(attrs({
                        href: "#",
                        "x-data-area": area.safe_uid,
                        "class": "area-button" + " " + "select-area"
                    }, {
                        href: true,
                        "x-data-area": true
                    }));
                    buf.push(">");
                    var __val__ = area.name;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</a>");
                    if (index < shared_accounts.length - 1) {
                        {
                            var __val__ = " - ";
                            buf.push(escape(null == __val__ ? "" : __val__));
                        }
                    }
                }
            }
        }).call(this);
        buf.push("\n    </div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// userSettingsAccountReceipts.jade compiled template
exports.userSettingsAccountReceipts = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div class="setting-section">\n  <h3 class="setting-sub-title">');
        var __val__ = MTN.t("Get receipts");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</h3>\n  <p>");
        var __val__ = MTN.t("Below you see all your transactions. You can get the receipt via email.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n  <ul class="receipts"></ul>');
        (function() {
            if ("number" == typeof receipts.length) {
                for (var $index = 0, $$l = receipts.length; $index < $$l; $index++) {
                    var receipt = receipts[$index];
                    buf.push('\n  <li class="receipt">');
                    var __val__ = app.helpers.paymentDateString(receipt.payment_date_epoch) + " - " + receipt.amount + " " + receipt.currency;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("<a");
                    buf.push(attrs({
                        href: "#",
                        "data-id": receipt.id,
                        "class": "send-receipt"
                    }, {
                        href: true,
                        "data-id": true
                    }));
                    buf.push(">");
                    var __val__ = MTN.t("Send receipt");
                    buf.push(null == __val__ ? "" : __val__);
                    buf.push("</a></li>");
                }
            } else {
                var $$l = 0;
                for (var $index in receipts) {
                    $$l++;
                    var receipt = receipts[$index];
                    buf.push('\n  <li class="receipt">');
                    var __val__ = app.helpers.paymentDateString(receipt.payment_date_epoch) + " - " + receipt.amount + " " + receipt.currency;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("<a");
                    buf.push(attrs({
                        href: "#",
                        "data-id": receipt.id,
                        "class": "send-receipt"
                    }, {
                        href: true,
                        "data-id": true
                    }));
                    buf.push(">");
                    var __val__ = MTN.t("Send receipt");
                    buf.push(null == __val__ ? "" : __val__);
                    buf.push("</a></li>");
                }
            }
        }).call(this);
        buf.push("\n</div>");
    }
    return buf.join("");
};

// summaryPast.jade compiled template
exports.summaryPast = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="summary-past" class="tab">\n  <div class="loader"></div>\n  <div class="tab-items">\n    <div id="past-yesterday" class="section"></div>\n    <div id="past-this-week" class="section"></div>\n    <div id="past-last-week" class="section"></div>\n    <div id="past-all" class="section"></div>');
        if (!dicole.get_global_variable("meetings_user_is_visitor")) {
            buf.push('\n    <div class="section">\n      <div class="line vertical"></div>\n      <div class="row">\n        <div class="line horizontal1"></div>\n        <div class="badge bl"><i class="ico-add"></i></div><a href="#" class="action create-meeting"><i class="ico-schedule"></i><br/>');
            var __val__ = MTN.t("Organize a new meeting");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a>\n      </div>\n    </div>");
        }
        buf.push('\n  </div>\n  <p class="bottom-tip">');
        var __val__ = MTN.t("Looking for %(L$Future meetings%)?", {
            L: {
                href: "#",
                classes: "upcoming"
            }
        });
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</p>\n</div>");
    }
    return buf.join("");
};

// meetingNextAction.jade compiled template
exports.meetingNextAction = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="next-action-wrap">');
        if (type === "matchmaking") {
            buf.push('\n  <div class="action">\n    <p class="icon"><i class="ico-note"></i>');
            var __val__ = MTN.t("%1$s wants to meet you", {
                params: [ requester_name ]
            });
            buf.push(null == __val__ ? "" : __val__);
            if (event_name) {
                var __val__ = " at " + event_name + ". ";
                buf.push(escape(null == __val__ ? "" : __val__));
            } else {
                var __val__ = ". ";
                buf.push(escape(null == __val__ ? "" : __val__));
            }
            var __val__ = MTN.t("Accept or decline?");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('\n    </p>\n  </div>\n  <div class="buttons"><a href="#" id="js_accept_matchmaking" class="button green-button"><i class="ico-check"></i>');
            var __val__ = MTN.t("Accept");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</a><a href="#" id="js_decline_matchmaking" class="button gray"><i class="ico-cross"></i>');
            var __val__ = MTN.t("Decline");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a></div>");
        }
        if (type === "followup") {
            buf.push('\n  <div class="action">\n    <p>');
            var __val__ = MTN.t("The meeting is over. Do you want to organize a follow-up meeting?");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</p>\n  </div>\n  <div class="buttons"><a');
            buf.push(attrs({
                href: params.create_followup_url,
                id: "js_create_followup",
                "class": "button" + " " + "pink"
            }, {
                href: true
            }));
            buf.push(">");
            var __val__ = MTN.t("Schedule a follow-up");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a></div>");
        }
        if (type === "ready_button") if (type === "rsvp") if (type === "tutorial") buf.push("\n</div>");
    }
    return buf.join("");
};

// summaryGoogleLoading.jade compiled template
exports.summaryGoogleLoading = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="summary-connecting" class="tab">\n  <div id="google-connecting" class="m-modal">\n    <div class="modal-header">\n      <h3> <i class="ico-calendar"></i>');
        var __val__ = MTN.t("Connecting your calendar");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n      </h3>\n    </div>\n    <div class="modal-content">\n      <p>');
        var __val__ = MTN.t("We are now importing your calendar items.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n      <p style="text-align:center; margin-bottom:40px;">');
        var __val__ = MTN.t("Please wait.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n      <div id="loader"></div>\n    </div>\n  </div>\n</div>');
    }
    return buf.join("");
};

// waitingForPayment.jade compiled template
exports.waitingForPayment = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="sell-subscription" class="m-modal">\n  <div class="modal-header">\n    <h3>');
        var __val__ = MTN.t("Waiting for transaction");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3>\n  </div>\n  <div class="modal-content">\n    <p>');
        var __val__ = MTN.t("A new window will now open where you can complete the transaction and activate Meetin.gs PRO subscription.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</p>\n    <p>");
        var __val__ = MTN.t("If the window does not open in a short while, please click the link below:");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</p>\n    <p><a");
        buf.push(attrs({
            href: upgrade_url,
            target: "_blank",
            "class": "paypal-link"
        }, {
            href: true,
            target: true
        }));
        buf.push(">");
        var __val__ = MTN.t("Pay now");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a></p>\n  </div>\n  <div class="modal-footer"> \n    <div class="buttons right"><a href="#" class="button gray cancel-payment">');
        var __val__ = MTN.t("Cancel payment");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// quickMeets.jade compiled template
exports.quickMeets = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        (function() {
            if ("number" == typeof quickmeets.length) {
                for (var $index = 0, $$l = quickmeets.length; $index < $$l; $index++) {
                    var qm = quickmeets[$index];
                    buf.push('\n<div class="quickmeet">\n  <h3 class="title">');
                    var __val__ = qm.email;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push('</h3>\n  <p class="url">');
                    var __val__ = qm.full_url;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</p><a");
                    buf.push(attrs({
                        href: "#",
                        "data-id": qm.id,
                        "class": "qm-send"
                    }, {
                        href: true,
                        "data-id": true
                    }));
                    buf.push(">");
                    var __val__ = MTN.t("Send invite");
                    buf.push(null == __val__ ? "" : __val__);
                    buf.push("</a>\n</div>");
                }
            } else {
                var $$l = 0;
                for (var $index in quickmeets) {
                    $$l++;
                    var qm = quickmeets[$index];
                    buf.push('\n<div class="quickmeet">\n  <h3 class="title">');
                    var __val__ = qm.email;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push('</h3>\n  <p class="url">');
                    var __val__ = qm.full_url;
                    buf.push(escape(null == __val__ ? "" : __val__));
                    buf.push("</p><a");
                    buf.push(attrs({
                        href: "#",
                        "data-id": qm.id,
                        "class": "qm-send"
                    }, {
                        href: true,
                        "data-id": true
                    }));
                    buf.push(">");
                    var __val__ = MTN.t("Send invite");
                    buf.push(null == __val__ ? "" : __val__);
                    buf.push("</a>\n</div>");
                }
            }
        }).call(this);
    }
    return buf.join("");
};

// meetingLctTeleconf.jade compiled template
exports.meetingLctTeleconf = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="lct-picker" class="m-modal">\n  <div class="modal-header back-button">\n    <h3>');
        var __val__ = MTN.t("Teleconference settings");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3><i class="ico-leftarrow back"></i>\n  </div>\n  <div class="modal-content m-form">\n    <p>');
        var __val__ = MTN.t("Enter the teleconference number given by your chosen operator.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</p>\n    <label>");
        var __val__ = MTN.t("Phone number");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("\n      <input");
        buf.push(attrs({
            id: "com-number",
            type: "text",
            value: meeting.online_conferencing_data && meeting.online_conferencing_data.teleconf_number ? meeting.online_conferencing_data.teleconf_number : "",
            placeholder: "e.g. +358 12 345 678"
        }, {
            type: true,
            value: true,
            placeholder: true
        }));
        buf.push("/></label>\n    <label>");
        var __val__ = MTN.t("Pin (optional)");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("\n      <input");
        buf.push(attrs({
            id: "com-pin",
            type: "text",
            value: meeting.online_conferencing_data && meeting.online_conferencing_data.teleconf_pin ? meeting.online_conferencing_data.teleconf_pin : "",
            placeholder: "e.g. 1234"
        }, {
            type: true,
            value: true,
            placeholder: true
        }));
        buf.push('/></label><br/>\n    <p class="note">');
        var __val__ = MTN.t("NOTE: If you know your pin code you can preset it here to allow participants to join without having to type the pin when making the call.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n  </div>\n  <div class="modal-footer">\n    <div class="buttons right"><a href="#" class="button blue save">');
        var __val__ = MTN.t("Save");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// meetmeConfirmDelete.jade compiled template
exports.meetmeConfirmDelete = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="meetme-confirm-delete" class="m-modal">\n  <div class="modal-header">\n    <h3>');
        var __val__ = MTN.t("Remove scheduler");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3>\n  </div>\n  <div class="modal-content">\n    <p>');
        var __val__ = MTN.t("Are you sure you want to remove %1$s. There is no undo.", {
            params: [ model.name ]
        });
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n  </div>\n  <div class="modal-footer"> \n    <div class="buttons right"><a href="#" class="confirm-delete button blue">');
        var __val__ = MTN.t("Remove");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a><a href="#" class="button gray js_hook_showcase_close">');
        var __val__ = MTN.t("Cancel");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// connectionError.jade compiled template
exports.connectionError = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="connection-error" class="m-modal">\n  <div class="modal-header">\n    <h3>');
        var __val__ = MTN.t("Sorry");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3>\n  </div>\n  <div class="modal-content">\n    <p>');
        var __val__ = MTN.t("Unfortunately we are unable to connect to our servers.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n  </div>\n  <div class="modal-footer">\n    <div class="buttons right"><a href="#" class="button blue retry">');
        var __val__ = MTN.t("Try again");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// meetingLctLync.jade compiled template
exports.meetingLctLync = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="lct-picker" class="m-modal">\n  <div class="modal-header back-button">\n    <h3>');
        var __val__ = MTN.t("Lync settings");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3><i class="ico-leftarrow back"></i>\n  </div>\n  <div class="modal-content m-form">\n    <p>');
        var __val__ = MTN.t("Select one the options below to activate Lync for this meeting.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n    <div class="m-form">\n      <label class="radio use-lync-uri">\n        <input type="radio" name="lync_mode" value="uri"/>');
        var __val__ = MTN.t("Paste your Lync invitation");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n      </label>\n      <textarea id="com-lync-pastearea">');
        var __val__ = meeting.online_conferencing_data && meeting.online_conferencing_data.lync_copypaste ? meeting.online_conferencing_data.lync_copypaste : "";
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n      </textarea><br/>\n      <p class="note">');
        var __val__ = MTN.t("How to get the invitation?");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("<br/>");
        var __val__ = MTN.t("Office 365 user: Create a new meeting in the  %(L$Web scheduler%).", {
            L: {
                href: "https://sched.lync.com",
                "class": "underline",
                target: "_blank"
            }
        });
        buf.push(null == __val__ ? "" : __val__);
        buf.push("<br/>");
        var __val__ = MTN.t('Desktop user: Press "New Lync Meeting" in your Outlook Calendar.');
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n    </div>\n    <div style="margin-top:28px;" class="m-form">\n      <label class="radio use-lync-sip">\n        <input type="radio" name="lync_mode" value="sip"/>');
        var __val__ = MTN.t("Use Lync address (SIP)");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n      </label>\n      <div class="form-row">\n        <input');
        buf.push(attrs({
            id: "com-lync-sip",
            type: "text",
            value: meeting.online_conferencing_data && meeting.online_conferencing_data.lync_sip ? meeting.online_conferencing_data.lync_sip : "",
            placeholder: MTN.t("Your Lync address")
        }, {
            type: true,
            value: true,
            placeholder: false
        }));
        buf.push('/>\n      </div>\n    </div>\n  </div>\n  <div class="modal-footer">\n    <div class="buttons right"><a href="#" class="button blue save">');
        var __val__ = MTN.t("Save");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// wizardProfileError.jade compiled template
exports.wizardProfileError = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="profile-wizard">\n  <div class="m-modal">\n    <div class="modal-header">\n      <h3>');
        var __val__ = MTN.t("Hang on for a while...");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3>\n    </div>\n    <div class="modal-content">');
        if (user_email && user_email != "0") {
            buf.push("\n      <p>");
            var __val__ = MTN.t("We are now synchronizing the data and creating your profile for %1$s. Don't worry, this might take several minutes.", [ user_email ]);
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</p>\n      <div style="height:100px;" class="loader-container"></div>\n      <p>');
            var __val__ = MTN.t("If your profile page doesn't show up in 5 minutes, please contact our support at %1$s.", [ contact_email ]);
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>");
            setTimeout(function() {
                window.location.reload();
            }, 1e4);
        } else {
            buf.push("\n      <p>");
            var __val__ = MTN.t("Oops, seems like you haven't registered. Please register to the event at %1$s to proceed. If you have already registered, please contact us at %2$s for more information.", [ event_website, contact_email ]);
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>");
        }
        buf.push("\n    </div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// headerBase.jade compiled template
exports.headerBase = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="header">\n  <div id="header-menu-positioner"></div>\n  <div id="header-logo">\n    <!-- TODO: Logolink--><a');
        buf.push(attrs({
            href: user && user.new_user_flow ? "#" : dicole.get_global_variable("meetings_logo_link") || "/meetings/summary/"
        }, {
            href: true
        }));
        buf.push(">\n      <h1");
        buf.push(attrs({
            "class": locals.user && locals.user.is_pro ? "pro" : ""
        }, {
            "class": true
        }));
        buf.push('></h1></a>\n  </div>\n  <div id="header-right">');
        if (user && user.id && (user.email_confirmed === 0 || user.email_confirmed === "0")) {
            buf.push('<a id="header-cancel" href="#" class="header-toplink">');
            var __val__ = MTN.t("Cancel registration");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a>");
        } else if (user && user.id && !user.new_user_flow) {
            buf.push("\n    <div");
            buf.push(attrs({
                id: "header-search",
                title: MTN.t("Search meetings")
            }, {
                title: false
            }));
            buf.push('><i class="ico-search"></i>\n      <div id="header-quickbar" style="display:none;">\n        <div id="meetings-quickbar-wrap">\n          <select');
            buf.push(attrs({
                id: "meetings-quickbar",
                "data-placeholder": MTN.t("Choose a meeting..."),
                "class": "chosen"
            }, {
                "data-placeholder": false
            }));
            buf.push(">");
            var __val__ = templatizer.headerSearchOptions({
                meetings: meetings
            });
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("</select>\n        </div>\n      </div>\n    </div>");
            if (!admin_return_link) {
                buf.push("\n    <div");
                buf.push(attrs({
                    id: "header-notifications",
                    title: MTN.t("Notifications")
                }, {
                    title: false
                }));
                buf.push('><i class="ico-notification"></i>\n      <div class="counter"></div>\n    </div>');
            }
            if (!dicole.get_global_variable("meetings_user_is_visitor")) {
                buf.push('\n    <div id="header-my-meetings">');
                var __val__ = MTN.t("My Meetings");
                buf.push(null == __val__ ? "" : __val__);
                buf.push('\n      <div class="menu-arrow"></div>\n    </div>');
            }
            if (admin_return_link) {
                buf.push('<a id="header-admin-absences-link" href="/meetings/agent_absences" class="header-admin-link">');
                var __val__ = "Poissaolot";
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</a><a");
                buf.push(attrs({
                    id: "header-admin-return-link",
                    href: admin_return_link,
                    "class": "header-admin-link"
                }, {
                    href: true
                }));
                buf.push(">");
                var __val__ = "Lopeta " + locals.user.name;
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</a>");
            } else {
                buf.push('<a id="header-profile-image" href="#"><img');
                buf.push(attrs({
                    src: locals.user.image ? locals.user.image : "/images/theme/default/default-user-avatar-36px.png",
                    alt: "User Image"
                }, {
                    src: true,
                    alt: true
                }));
                buf.push('/>\n      <div class="menu-arrow"></div><span class="initials"></span></a>');
            }
        } else if (view_type === "matchmaking" && dicole.get_global_variable("meetings_event_listing_registration_url")) {
            if (dicole.get_global_variable("meetings_event_matchmaker_found_for_user")) {
                buf.push('<a id="header-event-configure" href="#" class="header-toplink">');
                var __val__ = "Configure your matchmaking settings";
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</a>");
            } else {
                buf.push('<a id="header-event-configure" href="#" class="header-toplink">');
                var __val__ = "Join the matchmaking and get your own Schedule button";
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</a>");
            }
        } else if (view_type === "matchmaking" && !app.auth.user) {
            buf.push('<a id="header-login" href="#" class="header-toplink">');
            var __val__ = MTN.t("Already a Meetin.gs user? Sign in here");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a>");
        }
        buf.push('\n  </div>\n</div>\n<div id="header-meeting-menu" style="display:none;" data-open-selector="#header-my-meetings" data-x-adjust="0" class="header-menu">\n  <div class="header-menu-top"></div>\n  <div class="header-menu-main"><a href="#" class="add-new js_meetings_new_meeting_open">');
        var __val__ = MTN.t("Add new");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a><a id="header-timeline" href="/meetings/summary" target="_self" class="timeline">');
        var __val__ = MTN.t("Timeline");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a><a href="/meetings/meetme_config" target="_self" class="meetme-config js-open-url">');
        var __val__ = MTN.t("Meet Me page");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a>");
        (function() {
            if ("number" == typeof extra_meeting_links.length) {
                for (var $index = 0, $$l = extra_meeting_links.length; $index < $$l; $index++) {
                    var extra_link = extra_meeting_links[$index];
                    buf.push("<a");
                    buf.push(attrs({
                        href: extra_link.url,
                        target: "_self",
                        "class": "extra-link"
                    }, {
                        href: true,
                        target: true
                    }));
                    buf.push(">");
                    var __val__ = extra_link.title;
                    buf.push(null == __val__ ? "" : __val__);
                    buf.push("</a>");
                }
            } else {
                var $$l = 0;
                for (var $index in extra_meeting_links) {
                    $$l++;
                    var extra_link = extra_meeting_links[$index];
                    buf.push("<a");
                    buf.push(attrs({
                        href: extra_link.url,
                        target: "_self",
                        "class": "extra-link"
                    }, {
                        href: true,
                        target: true
                    }));
                    buf.push(">");
                    var __val__ = extra_link.title;
                    buf.push(null == __val__ ? "" : __val__);
                    buf.push("</a>");
                }
            }
        }).call(this);
        buf.push('\n  </div>\n</div>\n<div id="header-profile-menu" style="display:none;" data-open-selector="#header-profile-image" data-x-adjust="96" class="header-menu">\n  <div class="header-menu-top"></div>\n  <div class="header-menu-main"><a id="header-profile" href="#" target="_self" class="js_meetings_edit_my_profile_open">');
        var __val__ = MTN.t("Profile");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a><a href="/meetings/user/settings" target="_self" class="js-open-url">');
        var __val__ = MTN.t("Settings");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a><a href="/meetings_global/logout" target="_self">');
        var __val__ = MTN.t("Logout");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a></div>\n</div>\n<div id="header-notifications-menu" style="display:none;" data-open-selector="#header-notifications" data-x-adjust="365" class="header-menu notifications">\n  <div class="triangle"></div>\n  <div class="triangle white"></div>\n  <div class="header-menu-main">\n    <h3 class="head">');
        var __val__ = MTN.t("Notifications");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3>\n    <div class="notifications-container">\n      <div class="notification"><img src="/images/meetings/showcase_spinner.gif"/></div>\n    </div>\n  </div>\n</div>');
    }
    return buf.join("");
};

// sellSubscription.jade compiled template
exports.sellSubscription = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="sell-subscription" class="m-modal">\n  <div class="modal-header">');
        if (mode === "trial_ending") {
            buf.push("\n    <h3>");
            var __val__ = MTN.t("Continue using Meetin.gs PRO ");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</h3>");
        } else if (mode === "upgrade_now") {
            buf.push("\n    <h3>");
            var __val__ = MTN.t("Upgrade to Meetin.gs PRO");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</h3>");
        } else {
            buf.push("\n    <h3>");
            var __val__ = MTN.t("Your Meetin.gs trial has expired");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</h3>");
        }
        buf.push('\n  </div>\n  <div class="modal-content">');
        if (mode === "upgrade_now") {
            buf.push("\n    <p>");
            var __val__ = MTN.t("Upgrade Meetin.gs now to secure a seamless transition after your trial ends. You will not be charged for the trial period anyways.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>");
        } else if (mode === "trial_ending") {
            buf.push("\n    <p>");
            var __val__ = MTN.t("Thank you for trying Meetin.gs PRO. Upgrade now and claim your first year as a Meetin.gs PRO user for half the price.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>");
        } else if (mode === "meetme") {
            buf.push("\n    <p>");
            var __val__ = MTN.t("Additional Meet Me pages is a Meetin.gs PRO feature.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>");
        } else if (mode === "lct") {
            buf.push("\n    <p>");
            var __val__ = MTN.t("Google Hangouts, Microsoft Lync and custom options are PRO features.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>");
        } else if (mode === "invite") {
            buf.push("\n    <p>");
            var __val__ = MTN.t("Meetings with more than 6 participants is a PRO feature.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>");
        } else if (mode === "settings") {
            buf.push("\n    <p>");
            var __val__ = MTN.t("Configuring user rights on a per meeting basis is a PRO feature.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>");
        }
        buf.push('\n    <div class="pro-trial-upgrade">\n      <div class="star-box">\n        <h3>');
        var __val__ = MTN.t("$ 12");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</h3>\n        <p>");
        var __val__ = MTN.t("/ month");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n      </div>\n    </div>\n    <h3 class="pro-header">');
        var __val__ = MTN.t("Benefits for upgrading:");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</h3>");
        if (mode === "upgrade_now") {
            buf.push('\n    <ul class="pro-list">\n      <li>');
            var __val__ = MTN.t("Save everyone from the pain of scheduling meetings.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</li>\n      <li>");
            var __val__ = MTN.t("Avoid the hassle by gathering all the meeting materials into one place.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</li>\n      <li>");
            var __val__ = MTN.t("No more access codes: Join in with phone, Skype, Lync and Hangouts with a single tap.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</li>\n      <li>");
            var __val__ = MTN.t("Be notified of meeting updates in an instant.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</li>\n    </ul>");
        } else {
            buf.push('\n    <ul class="pro-list">\n      <li>');
            var __val__ = MTN.t("Unlimited meeting schedulers");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</li>\n      <li>");
            var __val__ = MTN.t("Expanded live communication tools");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</li>\n      <li>");
            var __val__ = MTN.t("Visual customization and branding");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</li>\n      <li>");
            var __val__ = MTN.t("Unlimited meeting participants");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</li>\n      <li>");
            var __val__ = MTN.t("Unlimited meeting materials");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</li>\n    </ul>");
        }
        buf.push('\n  </div>\n  <div class="modal-footer"> \n    <div class="buttons right"><a href="#" class="start-subscription button blue">');
        var __val__ = MTN.t("Upgrade now");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a><a href="#" class="button gray close js_hook_showcase_close">');
        var __val__ = MTN.t("Later");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// schedulingBar.jade compiled template
exports.schedulingBar = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="meeting-scheduling">\n  <p><i class="ico-schedule"> </i>\n    <This>meeting is being scheduled on the mobile using SwipeToMeet.</This>\n  </p>\n</div>\n<div class="drop-shadow"></div>');
    }
    return buf.join("");
};

// userSettingsRegional.jade compiled template
exports.userSettingsRegional = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div class="setting-head">\n  <h3 class="setting-title"><i class="icon ico-language"></i>');
        var __val__ = MTN.t("Regional settings");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n  </h3>\n  <p class="setting-desc">');
        var __val__ = MTN.t("Choose the language and time zone in which you want to use the service.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n</div>\n<div class="setting-content m-form">\n  <div class="setting-section">\n    <h3 class="setting-sub-title">');
        var __val__ = MTN.t("Select language");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</h3>\n    <p>");
        var __val__ = MTN.t("Choose the language you want to use the service with.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n    <p class="note">');
        var __val__ = MTN.t("Note: Your invitations to new meeting participants will be sent using the selected language by default.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n    <p>\n      <label for="language" class="inline">');
        var __val__ = MTN.t("Language:");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n        <select id="language" name="language">');
        if (user.language === "en") {
            buf.push('\n          <option value="en" selected="selected">English</option>');
        } else {
            buf.push('\n          <option value="en">English</option>');
        }
        if (user.language === "fi") {
            buf.push('\n          <option value="fi" selected="selected">Suomi</option>');
        } else {
            buf.push('\n          <option value="fi">Suomi</option>');
        }
        if (user.language === "sv") {
            buf.push('\n          <option value="sv" selected="selected">Svenska</option>');
        } else {
            buf.push('\n          <option value="sv">Svenska</option>');
        }
        if (user.language === "nl") {
            buf.push('\n          <option value="nl" selected="selected">Nederlands</option>');
        } else {
            buf.push('\n          <option value="nl">Nederlands</option>');
        }
        if (user.language === "fr") {
            buf.push('\n          <option value="fr" selected="selected">Français</option>');
        } else {
            buf.push('\n          <option value="fr">Français</option>');
        }
        buf.push('\n        </select></label>\n    </p>\n  </div>\n  <div class="setting-section">\n    <h3 class="setting-sub-title">');
        var __val__ = MTN.t("Select time zone");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</h3>\n    <p>");
        var __val__ = MTN.t("After changing your time zone, we will automatically display all your meeting times according to your new setting.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n    <label for="timezone">');
        var __val__ = MTN.t("Time zone:");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n      <select id="timezone" name="timezone" class="chosen timezone-select">');
        (function() {
            if ("number" == typeof dicole.get_global_variable("meetings_time_zone_data")["choices"].length) {
                for (var $index = 0, $$l = dicole.get_global_variable("meetings_time_zone_data")["choices"].length; $index < $$l; $index++) {
                    var tz = dicole.get_global_variable("meetings_time_zone_data")["choices"][$index];
                    if (user.time_zone == tz) {
                        buf.push("\n        <option");
                        buf.push(attrs({
                            value: tz,
                            selected: "selected"
                        }, {
                            value: true,
                            selected: true
                        }));
                        buf.push(">");
                        var __val__ = dicole.get_global_variable("meetings_time_zone_data")["data"][tz].readable_name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    } else {
                        buf.push("\n        <option");
                        buf.push(attrs({
                            value: tz
                        }, {
                            value: true
                        }));
                        buf.push(">");
                        var __val__ = dicole.get_global_variable("meetings_time_zone_data")["data"][tz].readable_name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    }
                }
            } else {
                var $$l = 0;
                for (var $index in dicole.get_global_variable("meetings_time_zone_data")["choices"]) {
                    $$l++;
                    var tz = dicole.get_global_variable("meetings_time_zone_data")["choices"][$index];
                    if (user.time_zone == tz) {
                        buf.push("\n        <option");
                        buf.push(attrs({
                            value: tz,
                            selected: "selected"
                        }, {
                            value: true,
                            selected: true
                        }));
                        buf.push(">");
                        var __val__ = dicole.get_global_variable("meetings_time_zone_data")["data"][tz].readable_name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    } else {
                        buf.push("\n        <option");
                        buf.push(attrs({
                            value: tz
                        }, {
                            value: true
                        }));
                        buf.push(">");
                        var __val__ = dicole.get_global_variable("meetings_time_zone_data")["data"][tz].readable_name;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    }
                }
            }
        }).call(this);
        buf.push("\n      </select></label>\n    <p>");
        var __val__ = MTN.t("Current time in the selected time zone: ");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('<span id="js_timezone_preview">');
        var __val__ = moment().utc().add("seconds", user.time_zone_offset).format("HH:mm dddd");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</span></p>\n  </div>\n</div>\n<div class="setting-footer"><a class="button blue save-regional"><span class="label">');
        var __val__ = MTN.t("Save");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</span></a></div>");
    }
    return buf.join("");
};

// meetmeConfig.jade compiled template
exports.meetmeConfig = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="meetme-config" class="meetme-setup">\n  <div class="buttons">');
        if (Modernizr.localstorage) {
            buf.push('<a class="button blue preview">');
            var __val__ = MTN.t("Preview");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a>");
        }
        buf.push('<a class="button pink save">');
        var __val__ = MTN.t("Save");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a>");
        if (!locals.in_event_flow) {
            buf.push('<a class="button gray cancel">');
            var __val__ = MTN.t("Cancel");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a>");
        }
        buf.push("\n  </div>\n  <!-- ------ Basic config ------->\n  <div");
        buf.push(attrs({
            style: locals.in_event_flow ? "height:0px;overflow:hidden;" : ""
        }, {
            style: true
        }));
        buf.push('>\n    <h2 class="divider fat">');
        var __val__ = MTN.t("Edit meeting scheduler");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h2>\n    <div class="section basic-config">\n      <div class="info m-form">\n        <input');
        buf.push(attrs({
            disabled: matchmaker.disable_title_edit ? true : false,
            type: "text",
            placeholder: MTN.t("Meeting scheduler name"),
            value: matchmaker.name || MTN.t("Meeting with %1$s", {
                params: [ user.name ]
            }),
            "class": "matchmaker-name"
        }, {
            disabled: true,
            type: true,
            placeholder: false,
            value: true
        }));
        buf.push('/>\n      </div>\n      <div class="type m-form">\n        <div class="type-change"><i');
        buf.push(attrs({
            "class": app.meetme_types[matchmaker.meeting_type || 0].icon_class
        }, {
            "class": true
        }));
        buf.push("></i>\n          <input");
        buf.push(attrs({
            type: "hidden",
            value: matchmaker.meeting_type || 0,
            "class": "meeting-type"
        }, {
            type: true,
            value: true
        }));
        buf.push('/><span class="text">');
        var __val__ = MTN.t("Change");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</span>\n        </div>\n        <label>\n          <input");
        buf.push(attrs({
            type: "checkbox",
            checked: matchmaker.meetme_hidden ? "checked" : undefined,
            "class": "meetme-hidden"
        }, {
            type: true,
            checked: true
        }));
        buf.push("/>");
        var __val__ = MTN.t("Hide from the public cover page");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("\n        </label>\n        <label>\n          <input");
        buf.push(attrs({
            type: "checkbox",
            checked: matchmaker.direct_link_enabled ? "checked" : undefined,
            "class": "toggle-direct-url"
        }, {
            type: true,
            checked: true
        }));
        buf.push("/>");
        var __val__ = MTN.t("Enable direct link & custom background");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("\n        </label>\n        <label>\n          <input");
        buf.push(attrs({
            id: "require-verified-user",
            type: "checkbox",
            checked: matchmaker.require_verified_user ? "checked" : undefined
        }, {
            type: true,
            checked: true
        }));
        buf.push("/>");
        var __val__ = MTN.t("Ask for email authentication from requesters");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("\n        </label>\n      </div>\n    </div>\n  </div>\n  <!-- ------ Direct link -------->");
        var class_name = matchmaker.event_data && matchmaker.event_data.show_youtube_url ? "open2 direct-link-container" : "open direct-link-container";
        var dl_name = locals.in_event_flow;
        buf.push("\n  <div");
        buf.push(attrs({
            "class": matchmaker.direct_link_enabled ? class_name : "direct-link-container"
        }, {
            "class": true
        }));
        buf.push(">");
        if (locals.in_event_flow) {
            buf.push('\n    <h2 class="divider fat">');
            var __val__ = "Review & press save to complete the registration";
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</h2>");
        } else {
            buf.push('\n    <h2 class="divider">');
            var __val__ = MTN.t("Direct link");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</h2>");
        }
        buf.push('\n    <div class="section direct-link">');
        if (!locals.in_event_flow) {
            buf.push('\n      <div class="url-container">\n        <p>URL:');
            var __val__ = "https://" + window.location.hostname + "/meet/" + user.meetme_fragment + "/";
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push('<span class="vanity-url">');
            var __val__ = matchmaker.vanity_url_path;
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push('</span><a id="copy-url" href="#">');
            var __val__ = MTN.t("copy to clipboard");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a>\n        </p>\n      </div>");
        }
        buf.push('\n      <div class="left">\n        <p>');
        var __val__ = MTN.t("Your greeting on the %(B$Meet Me%) page:");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n        <div class="bubble">\n          <textarea id="matchmaker-description">');
        var __val__ = matchmaker.description;
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push("</textarea>\n        </div>");
        if (matchmaker.event_data && matchmaker.event_data.show_youtube_url) {
            buf.push('\n        <div class="m-form">\n          <label>');
            var __val__ = "Video link:";
            buf.push(null == __val__ ? "" : __val__);
            buf.push("<br/>\n            <input");
            buf.push(attrs({
                id: "video",
                type: "text",
                value: matchmaker.youtube_url
            }, {
                type: true,
                value: true
            }));
            buf.push('/></label>\n        </div>\n        <p class="note video">');
            var __val__ = "Share your video about company, team, product or services.";
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>");
        }
        buf.push("\n      </div>");
        if (!matchmaker.event_data.force_background_image_url) {
            buf.push('\n      <div class="right">');
            if (matchmaker.background_theme === "c" || matchmaker.background_theme === "u") {
                var bg_url = matchmaker.background_preview_url || matchmaker.background_image_url;
                buf.push("<img");
                buf.push(attrs({
                    src: bg_url,
                    "class": "mm-bg-img"
                }, {
                    src: true
                }));
                buf.push("/>");
            } else {
                buf.push("<img");
                buf.push(attrs({
                    src: app.meetme_themes[matchmaker.background_theme].image,
                    "class": "mm-bg-img"
                }, {
                    src: true
                }));
                buf.push("/>");
            }
            buf.push('\n        <div><span class="button blue bg-change">');
            var __val__ = MTN.t("Change background");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</span></div>\n      </div>");
        }
        buf.push('\n    </div>\n  </div>\n  <!-- ------ Settings -------->\n  <h2 class="divider">');
        var __val__ = MTN.t("Settings");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h2>\n  <div class="settings">\n    <div class="menu"><a data-target="location" class="menu-item location selected">\n        <div class="wrap">\n          <div class="centered"><i class="ico-location"></i>');
        var __val__ = MTN.t("Location");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n          </div>\n        </div></a><a data-target="communication" class="menu-item communication">\n        <div class="wrap">\n          <div class="centered"><i class="ico-teleconf"></i>');
        var __val__ = MTN.t("Communication");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n          </div>\n        </div></a><a data-target="calendars" class="menu-item calendars">\n        <div class="wrap">\n          <div class="centered"><i class="ico-calendar"></i>');
        var __val__ = MTN.t("Calendars");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n          </div>\n        </div></a><a data-target="mtn-date-picker" class="menu-item date">\n        <div class="wrap">\n          <div class="centered"><i class="ico-calendars"></i>');
        var __val__ = MTN.t("Date picker");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n          </div>\n        </div></a><a data-target="time" class="menu-item time">\n        <div class="wrap">\n          <div class="centered"><i class="ico-time"></i>');
        var __val__ = MTN.t("Time");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n          </div>\n        </div></a><a data-target="materials" class="menu-item materials">\n        <div class="wrap">\n          <div class="centered"><i class="ico-material_editabledocument"></i>');
        var __val__ = MTN.t("Preset materials");
        buf.push(null == __val__ ? "" : __val__);
        if (!(user.is_pro || matchmaker.matchmaking_event_id)) {
            buf.push('<span class="pro"></span>');
        }
        buf.push('\n          </div>\n        </div></a></div>\n    <div class="settings-pages">\n      <div style="display:block;" class="page location">\n        <p class="m-form">');
        if (matchmaker.locations_description) {
            var __val__ = matchmaker.locations_description;
            buf.push(escape(null == __val__ ? "" : __val__));
        } else if (matchmaker.event_data.force_location || matchmaker.disable_location_edit) {
            var __val__ = MTN.t("Meeting location:");
            buf.push(null == __val__ ? "" : __val__);
            var __val__ = " " + (matchmaker.event_data.force_location || matchmaker.location);
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push('\n          <p class="note"><i class="ico-lock"></i>');
            var __val__ = matchmaker.event_data.force_location ? MTN.t("The meeting location is fixed for this event.") : MTN.t("The meeting location can not be changed.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("\n          </p>\n          <input");
            buf.push(attrs({
                id: "matchmaker-location",
                type: "hidden",
                value: matchmaker.event_data.force_location || matchmaker.location
            }, {
                type: true,
                value: true
            }));
            buf.push("/>");
        } else {
            var __val__ = MTN.t("Default meeting location");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("\n          <input");
            buf.push(attrs({
                id: "matchmaker-location",
                type: "text",
                value: matchmaker.location
            }, {
                type: true,
                value: true
            }));
            buf.push("/>");
        }
        buf.push('\n        </p>\n      </div>\n      <div class="page communication">');
        if (matchmaker.disable_tool_edit) {
            buf.push('\n        <p class="note"><i class="ico-lock"></i>');
            var __val__ = MTN.t("The meeting live communication tool can not be changed.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("\n        </p>");
        } else {
            buf.push('\n        <div class="com-texts">\n          <p>');
            var __val__ = MTN.t("Choose the live communication tool for the scheduler.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>\n          <p>");
            var __val__ = MTN.t("15 minutes before the meeting participants will receive a notification containing instructions and a link to join the meeting remotely.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</p>\n        </div>\n        <div class="lctools"><a data-tool-name="skype" class="tool skype"><i class="ico-skype"></i>');
            var __val__ = MTN.t("Skype call");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</a><a data-tool-name="teleconf" class="tool teleconf"><i class="ico-teleconf"></i>');
            var __val__ = MTN.t("Teleconference");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</a><a data-tool-name="hangout" class="tool hangout"><i class="ico-hangout"></i>');
            var __val__ = MTN.t("Google Hangouts");
            buf.push(null == __val__ ? "" : __val__);
            if (!user.is_pro) {
                buf.push('<span class="pro"></span>');
            }
            buf.push('</a><a data-tool-name="lync" class="tool lync"><i class="ico-lync"></i>');
            var __val__ = MTN.t("Microsoft Lync");
            buf.push(null == __val__ ? "" : __val__);
            if (!user.is_pro) {
                buf.push('<span class="pro"></span>');
            }
            buf.push('</a><a data-tool-name="custom" class="tool custom"><i class="ico-custom"></i>');
            var __val__ = MTN.t("Custom Tool");
            buf.push(null == __val__ ? "" : __val__);
            if (!user.is_pro) {
                buf.push('<span class="pro"></span>');
            }
            buf.push('</a><a class="tool disable"><i class="ico-cross"></i>');
            var __val__ = MTN.t("Disable");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</a></div>\n        <div class="configs">\n          <div class="custom m-form">\n            <P>');
            var __val__ = MTN.t("Enter a link with instructions for joining the meeting with your custom tool.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</P>\n            <label>");
            var __val__ = MTN.t("Web address (URL)");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("\n              <input");
            buf.push(attrs({
                id: "com-custom-uri",
                type: "text",
                value: matchmaker.online_conferencing_data && matchmaker.online_conferencing_data.custom_uri ? matchmaker.online_conferencing_data.custom_uri : "",
                placeholder: MTN.t("Copy the URL here")
            }, {
                type: true,
                value: true,
                placeholder: false
            }));
            buf.push("/></label>\n            <label>");
            var __val__ = MTN.t("Name of the tool");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("\n              <input");
            buf.push(attrs({
                id: "com-custom-name",
                type: "text",
                value: matchmaker.online_conferencing_data && matchmaker.online_conferencing_data.custom_name ? matchmaker.online_conferencing_data.custom_name : "",
                placeholder: ""
            }, {
                type: true,
                value: true,
                placeholder: true
            }));
            buf.push("/></label>\n            <label>");
            var __val__ = MTN.t("Tool instructions for participants");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</label>\n            <textarea id="com-custom-description">');
            var __val__ = matchmaker.online_conferencing_data && matchmaker.online_conferencing_data.custom_description ? matchmaker.online_conferencing_data.custom_description : "";
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push('</textarea>\n          </div>\n          <div class="hangout m-form">\n            <p>');
            var __val__ = MTN.t("Hangouts will be enabled for this meeting.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</p>\n            <p class="note">');
            var __val__ = MTN.t("NOTE: You and the participants will receive the Hangouts url before the meeting.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</p>\n          </div>\n          <div class="skype m-form">\n            <p>');
            var __val__ = MTN.t("Type in the Skype account that will be used to receive the calls from the participants.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>\n            <label>");
            var __val__ = MTN.t("Skype account name");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("\n              <input");
            buf.push(attrs({
                id: "com-skype",
                type: "text",
                value: matchmaker.online_conferencing_data && matchmaker.online_conferencing_data.skype_account ? matchmaker.online_conferencing_data.skype_account : user.skype ? user.skype : "",
                placeholder: MTN.t("Skype account name")
            }, {
                type: true,
                value: true,
                placeholder: false
            }));
            buf.push('/></label>\n            <p class="note">');
            var __val__ = MTN.t("NOTE: If you are not connected with the participants in Skype, remember to allow incoming calls from anyone using Skype privacy settings.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</p>\n          </div>\n          <div class="teleconf m-form">\n            <p>');
            var __val__ = MTN.t("Enter the teleconference number given by your chosen operator.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>\n            <label>");
            var __val__ = MTN.t("Phone number");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("\n              <input");
            buf.push(attrs({
                id: "com-number",
                type: "text",
                value: matchmaker.online_conferencing_data && matchmaker.online_conferencing_data.teleconf_number ? matchmaker.online_conferencing_data.teleconf_number : "",
                placeholder: "e.g. +358 12 345 678"
            }, {
                type: true,
                value: true,
                placeholder: true
            }));
            buf.push("/></label>\n            <label>");
            var __val__ = MTN.t("Pin (optional)");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("\n              <input");
            buf.push(attrs({
                id: "com-pin",
                type: "text",
                value: matchmaker.online_conferencing_data && matchmaker.online_conferencing_data.teleconf_pin ? matchmaker.online_conferencing_data.teleconf_pin : "",
                placeholder: "e.g. 1234"
            }, {
                type: true,
                value: true,
                placeholder: true
            }));
            buf.push('/></label>\n            <p class="note">');
            var __val__ = MTN.t("NOTE: If you know your pin code you can preset it here to allow participants to join without having to type the pin when making the call.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</p>\n          </div>\n          <div class="lync m-form">\n            <label>');
            var __val__ = MTN.t("Lync address (SIP)");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("\n              <input");
            buf.push(attrs({
                id: "com-lync",
                type: "text",
                value: matchmaker.online_conferencing_data && matchmaker.online_conferencing_data.lync_sip ? matchmaker.online_conferencing_data.lync_sip : "",
                placeholder: MTN.t("Your Lync address")
            }, {
                type: true,
                value: true,
                placeholder: false
            }));
            buf.push("/></label>\n          </div>\n        </div>");
        }
        buf.push('\n      </div>\n      <div class="page materials">\n        <p class="page-section">');
        var __val__ = MTN.t("Preset agenda and upload materials for all the meetings that are booked using this scheduler. You will be able to fine-tune each individual meeting before sharing the meeting page with participants.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</p>\n        <div");
        buf.push(attrs({
            id: "preset-features-wrap",
            style: user.is_pro || matchmaker.matchmaking_event_id ? "" : "display:none;"
        }, {
            style: true
        }));
        buf.push('>\n          <div class="page-section">\n            <p class="m-form">\n              <label>');
        var __val__ = MTN.t("Preset meeting agenda");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</label>\n              <textarea id="meetme-agenda" class="meetme-agenda">');
        var __val__ = matchmaker.preset_agenda || (matchmaker.event_data && matchmaker.event_data.default_agenda ? matchmaker.event_data.default_agenda : "");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push("\n              </textarea>\n            </p>\n          </div>");
        if (!locals.in_event_flow) {
            buf.push('\n          <div id="preset-materials" class="page-section"></div>');
        }
        buf.push("\n        </div>\n        <div");
        buf.push(attrs({
            id: "preset-features-pitch",
            style: user.is_pro || matchmaker.matchmaking_event_id ? "display:none;" : ""
        }, {
            style: true
        }));
        buf.push(">\n          <p>");
        var __val__ = MTN.t("Preset meeting materials are a PRO feature of Meetin.gs.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</p>");
        if (user.is_free_trial_expired) {
            buf.push("\n          <p>");
            var __val__ = MTN.t("Get your Meetin.gs PRO now to start enjoying all the features included in the full suite.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</p>\n          <p><a class="button blue show-preset-features">');
            var __val__ = MTN.t("Upgrade now");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a></p>");
        } else {
            buf.push("\n          <p>");
            var __val__ = MTN.t("Start your free 30-day PRO trial to explore all the features included in the full suite.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</p>\n          <p><a class="button blue show-preset-features">');
            var __val__ = MTN.t("Start your free trial");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a></p>");
        }
        buf.push('\n        </div>\n      </div>\n      <div class="page calendars">\n        <div class="calendar-options"></div>');
        if (!user.google_connected) {
            buf.push('\n        <p class="info">');
            var __val__ = MTN.t("Connect your Google Calendar so we can take your calendar into account:");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('<a href="#" class="connect-google"></a></p>');
        }
        if (Modernizr.localstorage) {
            buf.push('<a class="button blue preview-calendar">');
            var __val__ = MTN.t("Preview availability");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a>");
        }
        buf.push('\n      </div>\n      <div class="page mtn-date-picker">\n        <div class="timezone">');
        if (matchmaker.event_data.force_time_zone || matchmaker.disable_time_zone_edit) {
            var __val__ = MTN.t("Time zone:");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("\n          <!-- TODO:use event timezone if event stilll in future, othewise use current-->");
            var tz = dicole.get_global_variable("meetings_time_zone_data").data[matchmaker.event_data.force_time_zone || matchmaker.time_zone];
            if (matchmaker.available_timespans && matchmaker.available_timespans.length && matchmaker.available_timespans[0].start > tz.dst_change_epoch) {
                var __val__ = tz.changed_readable_name;
                buf.push(escape(null == __val__ ? "" : __val__));
            } else {
                var __val__ = tz.readable_name;
                buf.push(escape(null == __val__ ? "" : __val__));
            }
        } else {
            var __val__ = MTN.t("Set time zone for the times shown");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('\n          <select id="timezone-select" class="chosen">');
            var tz_data = dicole.get_global_variable("meetings_time_zone_data");
            var current_tz = matchmaker.time_zone || user.time_zone;
            (function() {
                if ("number" == typeof tz_data.choices.length) {
                    for (var i = 0, $$l = tz_data.choices.length; i < $$l; i++) {
                        var tz = tz_data.choices[i];
                        if (tz === current_tz) {
                            buf.push("\n            <option");
                            buf.push(attrs({
                                value: tz,
                                selected: "selected"
                            }, {
                                value: true,
                                selected: true
                            }));
                            buf.push(">");
                            var __val__ = tz_data.data[tz].readable_name;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</option>");
                        } else {
                            buf.push("\n            <option");
                            buf.push(attrs({
                                value: tz
                            }, {
                                value: true
                            }));
                            buf.push(">");
                            var __val__ = tz_data.data[tz].readable_name;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</option>");
                        }
                    }
                } else {
                    var $$l = 0;
                    for (var i in tz_data.choices) {
                        $$l++;
                        var tz = tz_data.choices[i];
                        if (tz === current_tz) {
                            buf.push("\n            <option");
                            buf.push(attrs({
                                value: tz,
                                selected: "selected"
                            }, {
                                value: true,
                                selected: true
                            }));
                            buf.push(">");
                            var __val__ = tz_data.data[tz].readable_name;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</option>");
                        } else {
                            buf.push("\n            <option");
                            buf.push(attrs({
                                value: tz
                            }, {
                                value: true
                            }));
                            buf.push(">");
                            var __val__ = tz_data.data[tz].readable_name;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</option>");
                        }
                    }
                }
            }).call(this);
            buf.push("\n          </select>");
        }
        buf.push('\n        </div>\n        <div class="time-spans"></div>\n        <div class="pick-slots">');
        if (locals.in_event_flow) {
            buf.push("\n          <p>");
            var __val__ = MTN.t("Highlight the times you want to make available for others to schedule a meeting with you at %1$s:", {
                params: [ matchmaker.event_data.name ]
            });
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>");
        } else {
            buf.push("\n          <p>");
            var __val__ = MTN.t("People can schedule a meeting with me only between the time slots highlighted below on a weekly basis:");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>");
        }
        buf.push('\n          <div class="calendar-container">\n            <div id="btd-cal"></div>');
        if (user.google_connected) {
            buf.push("\n            <p>");
            var __val__ = MTN.t("Note: Your Google Calendar will be taken into account to further block out unavailable time slots.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>");
        }
        buf.push('\n          </div>\n        </div>\n      </div>\n      <div class="page time">\n        <div class="demonstrator">\n          <div class="bg">\n            <div class="empty-tiles">\n              <div class="line"></div>\n            </div>\n            <div style="border-top:none;" class="empty-tiles">\n              <div class="line"></div>\n            </div>\n            <div style="border-top:none;" class="empty-tiles">\n              <div class="line"></div>\n            </div>\n            <div style="border-top:none;" class="empty-tiles">\n              <div class="line"></div>\n            </div>\n            <div style="border-top:none;" class="empty-tiles">\n              <div class="line"></div>\n            </div>\n            <div style="border-top:none;" class="empty-tiles">\n              <div class="line"></div>\n            </div>\n            <div style="border-top:none;" class="empty-tiles">\n              <div class="line"></div>\n            </div>\n            <div style="border-top:none;" class="empty-tiles">\n              <div class="line"></div>\n            </div>\n            <div style="border-top:none;" class="empty-tiles">\n              <div class="line"></div>\n            </div>\n            <div style="border-top:none;" class="empty-tiles">\n              <div class="line"></div>\n            </div>\n            <div style="border-top:none;" class="empty-tiles">\n              <div class="line"></div>\n            </div>\n          </div>\n          <div class="other-meeting first">');
        var __val__ = MTN.t("Previous meeting");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</div>\n          <div");
        buf.push(attrs({
            style: "height:" + matchmaker.buffer * (10 / 15) + "px;",
            "class": "reserve-pattern"
        }, {
            style: true
        }));
        buf.push("></div>\n          <div");
        buf.push(attrs({
            id: "demonstrator_m1",
            style: "height:" + matchmaker.duration * (10 / 15) + "px;",
            "class": "meeting"
        }, {
            style: true
        }));
        buf.push(">");
        var __val__ = matchmaker.duration < 25 ? "" : MTN.t("Meeting") + " - " + humanizeDuration(matchmaker.duration * 60 * 1e3, dicole.get_global_variable("meetings_lang"));
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</div>\n          <div class="reserve-pattern"></div>\n          <style>');
        var __val__ = "height:" + (matchmaker.buffer * (10 / 15) + "px;");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</style>\n          <div class="other-meeting">');
        var __val__ = MTN.t("Next meeting");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</div>\n        </div>\n        <div class="length">');
        if (matchmaker.event_data.force_duration || matchmaker.disable_duration_edit) {
            var __val__ = MTN.t("Meeting length") + " ";
            buf.push(null == __val__ ? "" : __val__);
            var __val__ = app.views.current.humanizedTimeFromMinutes(matchmaker.duration);
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push('\n          <p class="note"><i class="ico-lock"></i>');
            var __val__ = matchmaker.event_data.force_duration ? MTN.t("The meeting length is fixed for this event.") : MTN.t("The meeting length can not be changed.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("\n          </p>");
        } else {
            var __val__ = MTN.t("Meeting length") + " ";
            buf.push(null == __val__ ? "" : __val__);
            buf.push('\n          <div class="slide-and-indicator">\n            <div class="indicator meeting"></div>\n            <div id="timeslider" class="noUiSlider"></div>\n          </div>\n          <div class="value"><span class="meeting-len">');
            var __val__ = app.views.current.humanizedTimeFromMinutes(matchmaker.duration);
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("</span></div>");
        }
        buf.push('\n        </div>\n        <div class="buffer">');
        if (matchmaker.event_data && (matchmaker.event_data.force_buffer || matchmaker.event_data.force_buffer === 0)) {
            if (matchmaker.event_data.force_buffer !== 0) {
                var __val__ = MTN.t("Time between meetings") + " ";
                buf.push(null == __val__ ? "" : __val__);
                buf.push('<span class="time-container"><span class="pause-len">');
                var __val__ = app.views.current.humanizedTimeFromMinutes(matchmaker.buffer);
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</span></span>");
            }
        } else {
            var __val__ = MTN.t("Reserve time between meetings") + " ";
            buf.push(null == __val__ ? "" : __val__);
            buf.push('\n          <div class="slide-and-indicator">\n            <div class="indicator pause"></div>\n            <div id="pauseslider" class="noUiSlider gray"></div>\n          </div>\n          <div class="value"><span class="pause-len">');
            var __val__ = app.views.current.humanizedTimeFromMinutes(matchmaker.buffer);
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("</span></div>");
        }
        buf.push('\n        </div>\n        <div class="planahead">');
        var __val__ = MTN.t("Advance notice");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n          <div class="slide-and-indicator">\n            <div class="indicator"></div>\n            <div id="planaheadslider" class="noUiSlider gray"></div>\n          </div>\n          <div class="value">');
        var planahead = matchmaker.planning_buffer ? matchmaker.planning_buffer * 1e3 : 30 * 60 * 1e3;
        buf.push('<span class="planahead-len">');
        var __val__ = humanizeDuration(planahead, dicole.get_global_variable("meetings_lang"));
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push("</span>");
        var format_string = moment.lang() === "en" ? "dddd D.M h:mm A" : "dddd D.M HH:mm";
        buf.push('\n          </div>\n          <p id="planahead_tip" class="note">');
        var __val__ = MTN.t("E.g. if booked now, the first available meeting slot would be on %1$s.", [ moment().set("minutes", 0).add("minutes", Math.ceil((matchmaker.planning_buffer / 60 + moment().get("minutes")) / 30) * 30).format(format_string) ]);
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</p>\n        </div>\n      </div>\n    </div>\n  </div>\n  <!-- ------ Remember! -------->");
        if (locals.in_event_flow) {
            buf.push('\n  <div class="buttons">');
            if (Modernizr.localstorage) {
                buf.push('<a class="button blue preview">');
                var __val__ = MTN.t("Preview");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</a>");
            }
            buf.push('<a class="button pink save">');
            var __val__ = MTN.t("Save");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a>");
            if (!locals.in_event_flow) {
                buf.push('<a class="button gray cancel">');
                var __val__ = MTN.t("Cancel");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</a>");
            }
            buf.push('\n  </div>\n  <h2 class="divider fat">');
            var __val__ = "Press save to complete the registration";
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</h2>");
        }
        buf.push("\n</div>");
    }
    return buf.join("");
};

// meetingCard.jade compiled template
exports.meetingCard = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        if (locals.source && locals.source.indexOf("google") !== -1) {
            buf.push("\n<div");
            buf.push(attrs({
                "data-tooltip-text": MTN.t("Imported from Google Calendar. Click here to hide."),
                "class": "google-corner" + " " + "js_tooltip"
            }, {
                "data-tooltip-text": false
            }));
            buf.push("></div>");
        }
        if (locals.source && locals.source.indexOf("phone") !== -1) {
            buf.push("\n<div");
            buf.push(attrs({
                "data-tooltip-text": MTN.t("Imported from your phone calendar. Click here to hide."),
                "class": "phone-corner" + " " + "js_tooltip"
            }, {
                "data-tooltip-text": false
            }));
            buf.push("></div>");
        }
        buf.push("\n<h3");
        buf.push(attrs({
            title: title
        }, {
            title: true
        }));
        buf.push(">");
        var __val__ = title;
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</h3>\n<p class="time"><i class="ico-time"></i>');
        if (time_string) {
            var __val__ = time_string;
            buf.push(escape(null == __val__ ? "" : __val__));
        } else {
            var __val__ = MTN.t("Time is not set");
            buf.push(null == __val__ ? "" : __val__);
        }
        buf.push("\n</p>\n<p");
        buf.push(attrs({
            title: location,
            "class": "loc"
        }, {
            title: true
        }));
        buf.push('><i class="ico-location"></i>');
        var __val__ = location;
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push("\n</p>");
        if (participants.length) {
            buf.push('\n<div class="participants">');
            participants = _.sortBy(participants, function(p) {
                if (p.is_creator) return 0; else if (p.rsvp_status === "yes") return 1; else if (p.rsvp_status === "no") return 3; else return 2;
            });
            _.each(participants, function(participant, i) {
                {
                    if (i < 5 || participants.length < 6) {
                        buf.push('\n  <div class="wrap">');
                        if (participant.image !== "") {
                            buf.push("<img");
                            buf.push(attrs({
                                src: participant.image,
                                width: "47",
                                height: "47",
                                title: participant.name ? participant.name : participant.email
                            }, {
                                src: true,
                                width: true,
                                height: true,
                                title: true
                            }));
                            buf.push("/>");
                        } else {
                            buf.push("<span");
                            buf.push(attrs({
                                title: participant.name ? participant.name : participant.email,
                                "class": "placeholder"
                            }, {
                                title: true
                            }));
                            buf.push(">");
                            var __val__ = participant.initials;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</span>");
                        }
                        if (date_string == "") {
                            buf.push("\n    <!-- Time not set-->");
                        } else if (participant.rsvp_status === "yes") {
                            buf.push('<span class="rsvp yes"></span>');
                        } else if (participant.rsvp_status === "no") {
                            buf.push('<span class="rsvp no"></span>');
                        } else {
                            buf.push('<span class="rsvp unknown"></span>');
                        }
                        buf.push("\n  </div>");
                    } else {
                        {
                            buf.push('\n  <div class="wrap">');
                            var str = "+ " + (participants.length - 5);
                            buf.push('<span class="placeholder more">');
                            var __val__ = str;
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("<br/>");
                            var __val__ = MTN.t("More");
                            buf.push(null == __val__ ? "" : __val__);
                            buf.push("</span>\n  </div>");
                        }
                    }
                }
            });
            buf.push("\n</div>");
        }
    }
    return buf.join("");
};

// userSettingsCalendar.jade compiled template
exports.userSettingsCalendar = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="meeting-settings">\n  <div class="setting-head">\n    <h3 class="setting-title"><i class="icon ico-settings"></i>');
        var __val__ = MTN.t("Calendar integration");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n    </h3>\n    <p class="setting-desc">');
        var __val__ = MTN.t("Connect your calendars to see your upcoming events on the Meeting Timeline and show your availability on the Meet Me page.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n  </div>\n  <div class="setting-content">\n    <div class="setting-section third-party">\n      <h3 class="setting-sub-title">');
        var __val__ = MTN.t("Manage accounts");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</h3>\n      <p>");
        var __val__ = MTN.t("Connect and disconnect third-party accounts.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n      <div id="google_connect_container">\n        <p');
        buf.push(attrs({
            style: user.google_connected ? "display:none;" : "",
            "class": "disconnected"
        }, {
            style: true
        }));
        buf.push("><a");
        buf.push(attrs({
            id: "connect-google",
            href: app.helpers.getServiceUrl({
                service: "google",
                action: "connect",
                return_url: "/meetings/user/settings/calendar"
            }),
            "class": "button" + " " + "login" + " " + "google-blue"
        }, {
            href: true
        }));
        buf.push('><i class="ico-google"></i>');
        var __val__ = MTN.t("Connect with Google");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></p>\n        <p");
        buf.push(attrs({
            style: user.google_connected ? "" : "display:none;",
            "class": "connected"
        }, {
            style: true
        }));
        buf.push('><span class="ok"></span>');
        var __val__ = MTN.t("Your account is connected to Google");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('<a href="#" data-network-id="google" class="disconnect">');
        var __val__ = MTN.t("Disconnect");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a>\n        </p>\n      </div>\n    </div>");
        if (containers && containers.length) {
            buf.push('\n    <div class="setting-section connected-devices">\n      <h3 class="setting-sub-title">');
            var __val__ = MTN.t("Manage connected devices");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</h3>\n      <p>");
            var __val__ = MTN.t("This is a list of your devices connected with the service.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</p>\n      <p class="note">');
            var __val__ = MTN.t("Note: Disconnected devices can only be reconnected using that device.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>");
            (function() {
                if ("number" == typeof containers.length) {
                    for (var $index = 0, $$l = containers.length; $index < $$l; $index++) {
                        var container = containers[$index];
                        if (container.container_id === "google") continue;
                        buf.push("\n      <p><a");
                        buf.push(attrs({
                            href: "#",
                            "data-id": container.container_id,
                            "data-name": container.container_name,
                            "data-type": container.container_type,
                            "class": "disconnect-device" + " " + "underline"
                        }, {
                            href: true,
                            "data-id": true,
                            "data-name": true,
                            "data-type": true
                        }));
                        buf.push(">");
                        var __val__ = MTN.t("Disconnect %1$s", [ container.container_name ]);
                        buf.push(null == __val__ ? "" : __val__);
                        buf.push("</a></p>");
                    }
                } else {
                    var $$l = 0;
                    for (var $index in containers) {
                        $$l++;
                        var container = containers[$index];
                        if (container.container_id === "google") continue;
                        buf.push("\n      <p><a");
                        buf.push(attrs({
                            href: "#",
                            "data-id": container.container_id,
                            "data-name": container.container_name,
                            "data-type": container.container_type,
                            "class": "disconnect-device" + " " + "underline"
                        }, {
                            href: true,
                            "data-id": true,
                            "data-name": true,
                            "data-type": true
                        }));
                        buf.push(">");
                        var __val__ = MTN.t("Disconnect %1$s", [ container.container_name ]);
                        buf.push(null == __val__ ? "" : __val__);
                        buf.push("</a></p>");
                    }
                }
            }).call(this);
            buf.push("\n    </div>");
        }
        buf.push('\n    <div class="setting-section ics-export">\n      <h3 class="setting-sub-title">');
        var __val__ = MTN.t("Export meetings to your calendar");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3>\n      <div class="ics m-form">\n        <p>');
        var __val__ = MTN.t("Copy this ICS-calendar feed to your calendar software to automatically export all your meetings to your calendar. For more detailed instructions, click %(L$here%).", {
            L: {
                href: "#",
                classes: "underline js_meetings_ics_feed_instructions_open"
            }
        });
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n        <textarea id="ics-url" cols="30" rows="3" style="width:90%;" readonly="readonly">');
        var __val__ = user.external_ics_url;
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('\n        </textarea>\n        <p class="note">');
        var __val__ = MTN.t("Note: This is your private link and it should be handled with care.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</p>\n      </div>\n    </div>\n  </div>\n</div>");
    }
    return buf.join("");
};

// newsBar.jade compiled template
exports.newsBar = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div class="feature">\n  <p>');
        var __val__ = item.contenthtml;
        buf.push(null == __val__ ? "" : __val__);
        if (count_left > 1) {
            buf.push("<a");
            buf.push(attrs({
                href: "#",
                "data-id": item.uniqueid,
                "class": "next-link"
            }, {
                href: true,
                "data-id": true
            }));
            buf.push(">");
            var __val__ = MTN.t("Next");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a>");
        } else {
            buf.push("<a");
            buf.push(attrs({
                href: "#",
                "data-id": item.uniqueid,
                "class": "next-link"
            }, {
                href: true,
                "data-id": true
            }));
            buf.push(">");
            var __val__ = MTN.t("Dismiss");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a>");
        }
        buf.push("</p>\n</div>");
    }
    return buf.join("");
};

// userSettingsDelete.jade compiled template
exports.userSettingsDelete = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="meeting-settings">\n  <div class="m-modal">\n    <div class="modal-header back-button">\n      <h3>');
        var __val__ = MTN.t("Remove your account");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3><i class="ico-leftarrow back"></i>\n    </div>\n    <div class="modal-content">\n      <p>');
        var __val__ = MTN.t("Here you can remove your account permanently.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n    </div>\n    <div class="modal-footer">\n      <div class="buttons right">\n        <div class="step-one"><a class="button blue delete-start">Remove account</a></div>\n        <div style="display:none;" class="step-two"><a class="button pink delete-do">Really remove</a><a class="button gray delete-cancel">Cancel</a></div>\n      </div>\n    </div><a href="#" class="close-modal"><i class="ico-cross"></i></a>\n  </div>\n</div>');
    }
    return buf.join("");
};

// headerSearchOptions.jade compiled template
exports.headerSearchOptions = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<option value=""></option>');
        (function() {
            if ("number" == typeof meetings.length) {
                for (var $index = 0, $$l = meetings.length; $index < $$l; $index++) {
                    var meeting = meetings[$index];
                    var date_string = meeting.begin_epoch ? app.helpers.dateString(meeting.begin_epoch * 1e3, app.models.user.get("time_zone_offset")) : MTN.t("Time not set");
                    if (meeting.id === dicole.get_global_variable("meetings_meeting_id")) {
                        buf.push("\n<option");
                        buf.push(attrs({
                            value: meeting.desktop_url,
                            selected: "selected"
                        }, {
                            value: true,
                            selected: true
                        }));
                        buf.push(">");
                        var __val__ = (meeting.begin_date || "") + " - " + meeting.title;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    } else {
                        buf.push("\n<option");
                        buf.push(attrs({
                            value: meeting.desktop_url
                        }, {
                            value: true
                        }));
                        buf.push(">");
                        var __val__ = date_string + " - " + meeting.title;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    }
                }
            } else {
                var $$l = 0;
                for (var $index in meetings) {
                    $$l++;
                    var meeting = meetings[$index];
                    var date_string = meeting.begin_epoch ? app.helpers.dateString(meeting.begin_epoch * 1e3, app.models.user.get("time_zone_offset")) : MTN.t("Time not set");
                    if (meeting.id === dicole.get_global_variable("meetings_meeting_id")) {
                        buf.push("\n<option");
                        buf.push(attrs({
                            value: meeting.desktop_url,
                            selected: "selected"
                        }, {
                            value: true,
                            selected: true
                        }));
                        buf.push(">");
                        var __val__ = (meeting.begin_date || "") + " - " + meeting.title;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    } else {
                        buf.push("\n<option");
                        buf.push(attrs({
                            value: meeting.desktop_url
                        }, {
                            value: true
                        }));
                        buf.push(">");
                        var __val__ = date_string + " - " + meeting.title;
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    }
                }
            }
        }).call(this);
    }
    return buf.join("");
};

// meetmeBgSelector.jade compiled template
exports.meetmeBgSelector = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="meetme-background-selector" class="m-modal">\n  <div class="modal-header">\n    <h3>');
        var __val__ = MTN.t("Select background");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h3>\n  </div>\n  <div class="modal-content">\n    <div class="backgrounds">');
        for (var i = 0; i < app.meetme_themes.length; i++) {
            {
                if (model.background_theme == i || !model.background_theme && i === 0) {
                    buf.push("\n      <div");
                    buf.push(attrs({
                        "data-theme-id": i,
                        "data-image": app.meetme_themes[i].image,
                        style: 'background-image:url("' + app.meetme_themes[i].image + '");',
                        "class": "background" + " " + "active"
                    }, {
                        "data-theme-id": true,
                        "data-image": true,
                        style: true
                    }));
                    buf.push("></div>");
                } else {
                    buf.push("\n      <div");
                    buf.push(attrs({
                        "data-theme-id": i,
                        "data-image": app.meetme_themes[i].image,
                        style: 'background-image:url("' + app.meetme_themes[i].image + '");',
                        "class": "background"
                    }, {
                        "data-theme-id": true,
                        "data-image": true,
                        style: true
                    }));
                    buf.push("></div>");
                }
            }
        }
        if (model.background_theme === "c" || model.background_theme === "u") {
            var bg_url = model.background_preview_url || model.background_image_url;
            buf.push("\n      <div");
            buf.push(attrs({
                id: "own-bg",
                "data-theme-id": model.background_theme,
                style: "background-image:url(" + bg_url + ")",
                "data-upload-id": model.background_upload_id,
                "data-upload-image": model.background_image_url,
                "class": "background" + " " + "active"
            }, {
                "data-theme-id": true,
                style: true,
                "data-upload-id": true,
                "data-upload-image": true
            }));
            buf.push('>\n        <div class="progress-bar"></div>\n      </div>');
        } else {
            buf.push('\n      <div id="own-bg" data-theme-id="c" style="display:none;" class="background">\n        <div class="progress-bar"></div>\n      </div>');
        }
        buf.push('\n    </div><span class="upload-button button blue">');
        var __val__ = MTN.t("Upload your own");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n      <input type="file" name="file" id="fileupload-bg"/></span>\n    <p style="display:inline-block; margin-left: 30px" class="upload-button-help">(min. 1024x768, .jpg, .png)</p>\n  </div><a href="#" class="close-modal"><i class="ico-cross"></i></a>\n</div>');
    }
    return buf.join("");
};

// agentAdminOffices.jade compiled template
exports.agentAdminOffices = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div class="input-row"><span class="input-label">Toimiston nimi</span>\n  <input');
        buf.push(attrs({
            "x-data-object-field": "name",
            size: 40,
            value: typeof office == "undefined" ? undefined : office.name,
            disabled: typeof office == "undefined" ? undefined : "disabled",
            "class": "object-field" + " " + "open-focus-target"
        }, {
            "x-data-object-field": true,
            size: true,
            value: true,
            disabled: true
        }));
        buf.push('/>\n</div>\n<div class="input-row"><span class="input-label">Alaryhmä</span>\n  <input');
        buf.push(attrs({
            "x-data-object-field": "subgroup",
            size: 40,
            value: typeof office == "undefined" ? undefined : office.subgroup,
            disabled: typeof office == "undefined" ? undefined : "disabled",
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            size: true,
            value: true,
            disabled: true
        }));
        buf.push('/>\n</div>\n<div class="input-row"><span class="input-label">Yhteinen email</span>\n  <input');
        buf.push(attrs({
            "x-data-object-field": "group_email",
            size: 40,
            value: typeof office == "undefined" ? undefined : office.group_email,
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            size: true,
            value: true
        }));
        buf.push('/>\n</div>\n<div class="input-row">\n  <div class="input-label-row"><span class="input-label">Aukioloajat:</span></div>\n</div>\n<div class="input-row"><span class="input-label">MA</span>\n  <input');
        buf.push(attrs({
            "x-data-object-field": "open_mon",
            size: 25,
            value: typeof office == "undefined" ? undefined : office.open_mon,
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            size: true,
            value: true
        }));
        buf.push('/><span class="input-hint">(esim. "9:00-17:00" tai "9:00-11:00; 12:00-19:00")</span>\n</div>\n<div class="input-row"><span class="input-label">TI</span>\n  <input');
        buf.push(attrs({
            "x-data-object-field": "open_tue",
            size: 25,
            value: typeof office == "undefined" ? undefined : office.open_tue,
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            size: true,
            value: true
        }));
        buf.push('/>\n</div>\n<div class="input-row"><span class="input-label">KE</span>\n  <input');
        buf.push(attrs({
            "x-data-object-field": "open_wed",
            size: 25,
            value: typeof office == "undefined" ? undefined : office.open_wed,
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            size: true,
            value: true
        }));
        buf.push('/>\n</div>\n<div class="input-row"><span class="input-label">TO</span>\n  <input');
        buf.push(attrs({
            "x-data-object-field": "open_thu",
            size: 25,
            value: typeof office == "undefined" ? undefined : office.open_thu,
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            size: true,
            value: true
        }));
        buf.push('/>\n</div>\n<div class="input-row"><span class="input-label">PE</span>\n  <input');
        buf.push(attrs({
            "x-data-object-field": "open_fri",
            size: 25,
            value: typeof office == "undefined" ? undefined : office.open_fri,
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            size: true,
            value: true
        }));
        buf.push('/>\n</div>\n<div class="input-row">\n  <div class="input-label-row"><span class="input-label">Osoite:</span></div>\n</div>\n<div class="input-row"><span class="input-label">Suomi</span>\n  <input');
        buf.push(attrs({
            "x-data-object-field": "address_fi",
            size: 40,
            value: typeof office == "undefined" ? undefined : office.address_fi,
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            size: true,
            value: true
        }));
        buf.push('/>\n</div>\n<div class="input-row"><span class="input-label">Svenska</span>\n  <input');
        buf.push(attrs({
            "x-data-object-field": "address_sv",
            size: 40,
            value: typeof office == "undefined" ? undefined : office.address_sv,
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            size: true,
            value: true
        }));
        buf.push('/>\n</div>\n<div class="input-row"><span class="input-label">English</span>\n  <input');
        buf.push(attrs({
            "x-data-object-field": "address_en",
            size: 40,
            value: typeof office == "undefined" ? undefined : office.address_en,
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            size: true,
            value: true
        }));
        buf.push('/>\n</div>\n<div class="input-row">\n  <div class="input-label-row"><span class="input-label">Saapumisohjeet:</span></div>\n</div>\n<div class="input-row"><span class="input-label">Suomi</span>\n  <input');
        buf.push(attrs({
            "x-data-object-field": "instructions_fi",
            size: 100,
            value: typeof office == "undefined" ? undefined : office.instructions_fi,
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            size: true,
            value: true
        }));
        buf.push('/>\n</div>\n<div class="input-row"><span class="input-label">Svenska</span>\n  <input');
        buf.push(attrs({
            "x-data-object-field": "instructions_sv",
            size: 100,
            value: typeof office == "undefined" ? undefined : office.instructions_sv,
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            size: true,
            value: true
        }));
        buf.push('/>\n</div>\n<div class="input-row"><span class="input-label">English</span>\n  <input');
        buf.push(attrs({
            "x-data-object-field": "instructions_en",
            size: 100,
            value: typeof office == "undefined" ? undefined : office.instructions_en,
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            size: true,
            value: true
        }));
        buf.push('/>\n</div>\n<div class="input-row">\n  <div class="input-label-row"><span class="input-label">Verkkosivu:</span></div>\n</div>\n<div class="input-row"><span class="input-label">Suomi</span>\n  <input');
        buf.push(attrs({
            "x-data-object-field": "website_fi",
            size: 100,
            value: typeof office == "undefined" ? undefined : office.website_fi,
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            size: true,
            value: true
        }));
        buf.push('/>\n</div>\n<div class="input-row"><span class="input-label">Svenska</span>\n  <input');
        buf.push(attrs({
            "x-data-object-field": "website_sv",
            size: 100,
            value: typeof office == "undefined" ? undefined : office.website_sv,
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            size: true,
            value: true
        }));
        buf.push('/>\n</div>\n<div class="input-row"><span class="input-label">English</span>\n  <input');
        buf.push(attrs({
            "x-data-object-field": "website_en",
            size: 100,
            value: typeof office == "undefined" ? undefined : office.website_en,
            "class": "object-field"
        }, {
            "x-data-object-field": true,
            size: true,
            value: true
        }));
        buf.push("/>\n</div>");
    }
    return buf.join("");
};

// meetingsTips.jade compiled template
exports.meetingsTips = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="meetings-tips">\n  <p>here be tips what to do with meetings!</p>\n</div>');
    }
    return buf.join("");
};

// meetmeShare.jade compiled template
exports.meetmeShare = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="meetme-share" class="meetme-setup">');
        var ts = user.organization_title != "" && user.organization != "" ? user.organization_title + ", " + user.organization : user.organization + user.organization_title;
        buf.push('\n  <h2 class="divider fat">');
        var __val__ = MTN.t("Share your %(B$meet me%) page");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h2>\n  <div class="buttons">');
        if (user.new_user_flow) {
            buf.push('<a class="button pink continue">');
            var __val__ = MTN.t("Continue");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a>");
        } else {
            buf.push('<a class="button gray return">');
            var __val__ = MTN.t("Back");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a>");
        }
        buf.push('\n  </div>\n  <div class="section share-url-and-signature">\n    <p class="select">');
        var __val__ = MTN.t("Choose Meet Me Page to share:");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n      <select id="mm-select" style="width:200px;" class="chosen">');
        if (!selected_matchmaker_path) {
            buf.push('\n        <option value="" selected="selected">');
            var __val__ = MTN.t("Meet Me Cover Page");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</option>");
        } else {
            buf.push('\n        <option value="">');
            var __val__ = MTN.t("Meet Me Cover Page");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</option>");
        }
        var mms = _.filter(matchmakers, function(o) {
            return o.last_active_epoch === 0 || o.last_active_epoch * 1e3 > new Date().getTime();
        });
        (function() {
            if ("number" == typeof mms.length) {
                for (var $index = 0, $$l = mms.length; $index < $$l; $index++) {
                    var mm = mms[$index];
                    if (mm.vanity_url_path == selected_matchmaker_path) {
                        buf.push("\n        <option");
                        buf.push(attrs({
                            value: mm.vanity_url_path,
                            selected: "selected"
                        }, {
                            value: true,
                            selected: true
                        }));
                        buf.push(">");
                        var __val__ = mm.name || MTN.t("Default Meet Me page");
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    } else {
                        buf.push("\n        <option");
                        buf.push(attrs({
                            value: mm.vanity_url_path
                        }, {
                            value: true
                        }));
                        buf.push(">");
                        var __val__ = mm.name || MTN.t("Default Meet Me page");
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    }
                }
            } else {
                var $$l = 0;
                for (var $index in mms) {
                    $$l++;
                    var mm = mms[$index];
                    if (mm.vanity_url_path == selected_matchmaker_path) {
                        buf.push("\n        <option");
                        buf.push(attrs({
                            value: mm.vanity_url_path,
                            selected: "selected"
                        }, {
                            value: true,
                            selected: true
                        }));
                        buf.push(">");
                        var __val__ = mm.name || MTN.t("Default Meet Me page");
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    } else {
                        buf.push("\n        <option");
                        buf.push(attrs({
                            value: mm.vanity_url_path
                        }, {
                            value: true
                        }));
                        buf.push(">");
                        var __val__ = mm.name || MTN.t("Default Meet Me page");
                        buf.push(escape(null == __val__ ? "" : __val__));
                        buf.push("</option>");
                    }
                }
            }
        }).call(this);
        buf.push('\n      </select></p>\n    <p class="url meetings-form">URL: \n      <input');
        buf.push(attrs({
            value: share_url,
            readonly: "readonly",
            "class": "url-input"
        }, {
            value: true,
            readonly: true
        }));
        buf.push('/><a id="copy-url" class="button blue">');
        var __val__ = MTN.t("Copy to clipboard");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a>\n    </p>\n    <p>");
        var __val__ = MTN.t("Copy and paste the following tagline to your email signature:");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</p>\n    <textarea>");
        var __val__ = "--\n" + user.name + "\n" + ts + "\n" + "Schedule a meeting: " + share_url;
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</textarea>\n  </div>\n  <h2 class="divider">');
        var __val__ = MTN.t("Share with your social networks");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h2>\n  <div class="section networks">\n    <p>');
        var __val__ = MTN.t("Share the Meet Me page with the contacts in your social networks:");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n    <div class="twitter"><a');
        buf.push(attrs({
            "data-count": "none",
            "data-related": "meetin_gs",
            href: "https://twitter.com/share",
            "data-url": share_url,
            "data-text": MTN.t("Here's my Meet Me page where you can book a meeting with me easily:"),
            "class": "twitter-share-button"
        }, {
            "data-count": true,
            "data-related": true,
            href: true,
            "data-url": true,
            "data-text": false
        }));
        buf.push('>Tweet</a></div>\n    <div class="linkedin">\n      <script');
        buf.push(attrs({
            type: "IN/Share",
            "data-url": share_url,
            "data-size": "large"
        }, {
            type: true,
            "data-url": true,
            "data-size": true
        }));
        buf.push("></script>\n    </div><a");
        buf.push(attrs({
            href: "https://www.facebook.com/sharer/sharer.php?u=" + share_url,
            target: "_blank",
            "class": "facebook"
        }, {
            href: true,
            target: true
        }));
        buf.push('></a>\n    <div class="gplus">\n      <div');
        buf.push(attrs({
            id: "gplus",
            "data-action": "share",
            "data-annotation": "none",
            "data-href": share_url,
            "class": "g-plus"
        }, {
            "data-action": true,
            "data-annotation": true,
            "data-href": true
        }));
        buf.push('></div>\n    </div>\n  </div>\n  <h2 class="divider">');
        var __val__ = MTN.t("Generate a %(B$meet me%) button");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</h2>\n  <div class="section generate-button">\n    <p>');
        var __val__ = MTN.t("Get your %(B$meet me%) button to share your availability on your website.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n    <p class="choose">');
        var __val__ = MTN.t("Choose the button:");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n    <div class="meetme-buttons">\n      <div class="button-group">\n        <div class="button">\n          <input name="mmbutton" type="radio" data-type="schedule" data-color="blue"/>\n          <script');
        buf.push(attrs({
            type: "MTN/app",
            "data-user": user.matchmaker_fragment,
            "data-scheduler": selected_matchmaker_path || "",
            "data-color": "blue",
            "data-type": "schedule"
        }, {
            type: true,
            "data-user": true,
            "data-scheduler": true,
            "data-color": true,
            "data-type": true
        }));
        buf.push('></script>\n          <div class="clickjacker"></div>\n        </div>\n        <div class="button">\n          <input name="mmbutton" type="radio" data-type="schedule" data-color="silver"/>\n          <script');
        buf.push(attrs({
            type: "MTN/app",
            "data-user": user.matchmaker_fragment,
            "data-scheduler": selected_matchmaker_path || "",
            "data-color": "silver",
            "data-type": "schedule"
        }, {
            type: true,
            "data-user": true,
            "data-scheduler": true,
            "data-color": true,
            "data-type": true
        }));
        buf.push('></script>\n          <div class="clickjacker"></div>\n        </div>\n        <div class="button">\n          <input name="mmbutton" type="radio" data-type="schedule" data-color="gray"/>\n          <script');
        buf.push(attrs({
            type: "MTN/app",
            "data-user": user.matchmaker_fragment,
            "data-scheduler": selected_matchmaker_path || "",
            "data-color": "gray",
            "data-type": "schedule"
        }, {
            type: true,
            "data-user": true,
            "data-scheduler": true,
            "data-color": true,
            "data-type": true
        }));
        buf.push('></script>\n          <div class="clickjacker"></div>\n        </div>\n        <div class="button">\n          <input name="mmbutton" type="radio" data-type="schedule" data-color="dark"/>\n          <script');
        buf.push(attrs({
            type: "MTN/app",
            "data-user": user.matchmaker_fragment,
            "data-scheduler": selected_matchmaker_path || "",
            "data-color": "dark",
            "data-type": "schedule"
        }, {
            type: true,
            "data-user": true,
            "data-scheduler": true,
            "data-color": true,
            "data-type": true
        }));
        buf.push('></script>\n          <div class="clickjacker"></div>\n        </div>\n      </div>\n      <div class="button-group">\n        <div class="button">\n          <input name="mmbutton" type="radio" data-type="meetme" data-color="blue"/>\n          <script');
        buf.push(attrs({
            type: "MTN/app",
            "data-user": user.matchmaker_fragment,
            "data-scheduler": selected_matchmaker_path || "",
            "data-color": "blue",
            "data-type": "meetme"
        }, {
            type: true,
            "data-user": true,
            "data-scheduler": true,
            "data-color": true,
            "data-type": true
        }));
        buf.push('></script>\n          <div class="clickjacker"></div>\n        </div>\n        <div class="button">\n          <input name="mmbutton" type="radio" data-type="meetme" data-color="silver"/>\n          <script');
        buf.push(attrs({
            type: "MTN/app",
            "data-user": user.matchmaker_fragment,
            "data-scheduler": selected_matchmaker_path || "",
            "data-color": "silver",
            "data-type": "meetme"
        }, {
            type: true,
            "data-user": true,
            "data-scheduler": true,
            "data-color": true,
            "data-type": true
        }));
        buf.push('></script>\n          <div class="clickjacker"></div>\n        </div>\n        <div class="button">\n          <input name="mmbutton" type="radio" data-type="meetme" data-color="gray"/>\n          <script');
        buf.push(attrs({
            type: "MTN/app",
            "data-user": user.matchmaker_fragment,
            "data-scheduler": selected_matchmaker_path || "",
            "data-color": "gray",
            "data-type": "meetme"
        }, {
            type: true,
            "data-user": true,
            "data-scheduler": true,
            "data-color": true,
            "data-type": true
        }));
        buf.push('></script>\n          <div class="clickjacker"></div>\n        </div>\n        <div class="button">\n          <input name="mmbutton" type="radio" data-type="meetme" data-color="dark"/>\n          <script');
        buf.push(attrs({
            type: "MTN/app",
            "data-user": user.matchmaker_fragment,
            "data-scheduler": selected_matchmaker_path || "",
            "data-color": "dark",
            "data-type": "meetme"
        }, {
            type: true,
            "data-user": true,
            "data-scheduler": true,
            "data-color": true,
            "data-type": true
        }));
        buf.push('></script>\n          <div class="clickjacker"></div>\n        </div>\n      </div>\n    </div>\n    <p class="code-help">');
        var __val__ = MTN.t("Copy and paste the code below into the HTML of your site:");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n    <textarea id="meetme-code"></textarea>\n  </div>');
        if (dicole.get_global_variable("meetings_feature_quickmeet") && current_matchmaker) {
            buf.push('\n  <h2 class="divider">');
            var __val__ = MTN.t("Generate and send quickmeet links");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</h2>\n  <div class="section manage-quickmeet">\n    <form class="m-form">\n      <p>\n        <label for="quickmeet_email">Email\n          <input id="quickmeet_email" name="email" value=""/>\n        </label>\n      </p>\n      <p>\n        <label for="quickmeet_name">Name\n          <input id="quickmeet_name" name="name" value=""/>\n        </label>\n      </p>\n      <p>\n        <label for="quickmeet_organization">Organization\n          <input id="quickmeet_organization" name="organization" value=""/>\n        </label>\n      </p>\n      <p>\n        <label for="quickmeet_title">Title\n          <input id="quickmeet_title" name="title" value=""/>\n        </label>\n      </p>\n      <p>\n        <label for="quickmeet_phone">Phone\n          <input id="quickmeet_phone" name="phone" value=""/>\n        </label>\n      </p>\n      <p>\n        <label for="quickmeet_meeting_title">Meeting title\n          <input id="quickmeet_meeting_title" name="text" value=""/>\n        </label>\n      </p>\n      <p>\n        <label for="quickmeet_message">Custom message\n          <textarea id="quickmeet_message" name="text" value=""></textarea>\n        </label>\n      </p>\n      <p>\n        <input id="js_add_quickmeet" type="submit" name="save" value="add"/>\n      </p>\n    </form>\n    <div id="quickmeets-container"></div>\n  </div>');
        }
        buf.push("\n</div>");
    }
    return buf.join("");
};

// meetmeMatchmakerTimespan.jade compiled template
exports.meetmeMatchmakerTimespan = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        if (locals.event_data && event_data.force_available_timespans || locals.disable_available_timespans_edit) {
            var tz = event_data.force_time_zone || time_zone;
            var tz_data = dicole.get_global_variable("meetings_time_zone_data").data[tz];
            var spans = event_data.force_available_timespans || available_timespans;
            buf.push("\n<p");
            buf.push(attrs({
                style: "height:" + (spans ? spans.length : 1) * 28 + "px;",
                "class": "availability"
            }, {
                style: true
            }));
            buf.push(">");
            var __val__ = MTN.t("The time period has been set as:");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</p>\n<div class="selects">');
            if (spans) {
                (function() {
                    if ("number" == typeof spans.length) {
                        for (var $index = 0, $$l = spans.length; $index < $$l; $index++) {
                            var timespan = spans[$index];
                            buf.push("\n  <p>");
                            var __val__ = app.helpers.fullTimeSpanString(timespan.start, timespan.end, tz_data);
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</p>");
                        }
                    } else {
                        var $$l = 0;
                        for (var $index in spans) {
                            $$l++;
                            var timespan = spans[$index];
                            buf.push("\n  <p>");
                            var __val__ = app.helpers.fullTimeSpanString(timespan.start, timespan.end, tz_data);
                            buf.push(escape(null == __val__ ? "" : __val__));
                            buf.push("</p>");
                        }
                    }
                }).call(this);
            } else {
                buf.push("\n  <p>");
                var __val__ = MTN.t("Live starting today");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</p>");
            }
            buf.push("\n</div>");
        } else {
            var tz_data = dicole.get_global_variable("meetings_time_zone_data").data[time_zone];
            buf.push('\n<div class="set-availability">\n  <div class="left-side">\n    <p>');
            var __val__ = MTN.t("Scheduler availability");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</p>\n  </div>\n  <div class="right-side">\n    <label for="availability-always">');
            if (locals.available_timespans && locals.available_timespans.length) {
                buf.push('\n      <input type="radio" name="availability_mode" value="always" id="availability-always"/>');
            } else {
                buf.push('\n      <input type="radio" name="availability_mode" value="always" id="availability-always" checked="checked"/>');
            }
            var __val__ = MTN.t("Live starting today");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('\n    </label>\n    <label for="availability-set">');
            if (locals.available_timespans && locals.available_timespans.length) {
                buf.push('\n      <input type="radio" name="availability_mode" value="set-time" id="availability-set" checked="checked"/>');
            } else {
                buf.push('\n      <input type="radio" name="availability_mode" value="set-time" id="availability-set"/>');
            }
            var __val__ = MTN.t("Preset time period");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("\n    </label>\n    <div");
            buf.push(attrs({
                style: locals.available_timespans && locals.available_timespans.length ? "display:block;" : "",
                "class": "availability-controls" + " " + "m-form"
            }, {
                style: true
            }));
            buf.push(">");
            var start = moment().format("YYYY-MM-DD");
            var end = moment().add("months", 1).format("YYYY-MM-DD");
            if (locals.available_timespans && locals.available_timespans.length) {
                var start = moment.utc((available_timespans[0].start - tz_data.offset_value) * 1e3).format("YYYY-MM-DD");
                var end = moment.utc((available_timespans[0].end - tz_data.offset_value) * 1e3 - 1e3).format("YYYY-MM-DD");
            }
            buf.push('\n      <label class="inline">');
            var __val__ = MTN.t("Starting date and time");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("\n        <input");
            buf.push(attrs({
                id: "av_date_start",
                name: "availability",
                type: "text",
                value: start
            }, {
                name: true,
                type: true,
                value: true
            }));
            buf.push('/></label>\n      <label class="inline">');
            var __val__ = MTN.t("Ending date and time");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("\n        <input");
            buf.push(attrs({
                id: "av_date_end",
                name: "availability",
                type: "text",
                value: end
            }, {
                name: true,
                type: true,
                value: true
            }));
            buf.push("/></label>\n    </div>\n  </div>\n</div>");
        }
    }
    return buf.join("");
};

// meetmeSuccess.jade compiled template
exports.meetmeSuccess = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="matchmaking-success" class="m-modal">');
        if (lock && lock.quickmeet_key) {
            buf.push('\n  <div class="modal-header">\n    <h3>');
            var __val__ = MTN.t("Thank you!");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</h3>\n  </div>\n  <div class="modal-content">\n    <p><img');
            buf.push(attrs({
                src: meetme_user.image || "/images/meetings/new_profile.png",
                "class": "portrait"
            }, {
                src: true
            }));
            buf.push("/>");
            var __val__ = MTN.t("%(B$%1$s%) is now preparing the online meeting page where you can further discuss details, create an agenda, and share materials before the actual meeting.", {
                params: [ lock.accepter_name ],
                escape_params: 1
            });
            buf.push(null == __val__ ? "" : __val__);
            buf.push('\n    </p>\n    <p class="spaced">');
            var __val__ = MTN.t("When ready, we will send you an automated notification containing a link to the meeting page.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</p>\n    <p class="spaced">');
            var __val__ = MTN.t("Title://context:meeting title") + " " + lock.title;
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</p>\n    <p class="spaced">');
            var __val__ = MTN.t("When:") + " " + lock.times_string;
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>\n  </div>");
        } else if (lock && lock.request_sent) {
            buf.push('\n  <div class="modal-header">\n    <h3>');
            var __val__ = MTN.t("We've sent the meeting request");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</h3>\n  </div>\n  <div class="modal-content">\n    <p>');
            var __val__ = MTN.t("Next %1$s will answer your request to meet. We will notify you once we have a response.", {
                params: [ lock.accepter_name ],
                escape_params: 1
            });
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</p>\n    <p class="title">');
            var __val__ = MTN.t("Title://context:meeting title") + " " + lock.title;
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</p>\n    <p class="time">');
            var __val__ = MTN.t("When:") + " " + lock.times_string;
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("</p>");
            if (lock.location_string) {
                buf.push('\n    <p class="time">');
                var __val__ = MTN.t("Where:") + " " + lock.location_string;
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</p>");
            }
            buf.push('\n    <p class="location">');
            var __val__ = MTN.t("Who:") + " " + lock.accepter_name;
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</p>\n    <p class="cal-links"><a');
            buf.push(attrs({
                href: lock.tentative_calendar_url
            }, {
                href: true
            }));
            buf.push(">MS Outlook </a>");
            var __val__ = " | ";
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("<a");
            buf.push(attrs({
                target: "_blank",
                href: lock.tentative_gcal_url
            }, {
                target: true,
                href: true
            }));
            buf.push(">");
            var __val__ = MTN.t("Google calendar");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a>");
            var __val__ = " | ";
            buf.push(escape(null == __val__ ? "" : __val__));
            buf.push("<a");
            buf.push(attrs({
                href: lock.tentative_calendar_url
            }, {
                href: true
            }));
            buf.push(">");
            var __val__ = MTN.t("Other ICS");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a>\n    </p>");
            if (lock.matchmaking_list_url) {
                buf.push("\n    <p><a");
                buf.push(attrs({
                    href: lock.matchmaking_list_url,
                    "class": "button" + " " + "blue"
                }, {
                    href: true
                }));
                buf.push(">");
                var __val__ = MTN.t("Back to matchmaking list");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</a></p>");
            }
            if (current_user.meetme_fragment === "") {
                buf.push('\n    <p class="bold">');
                var __val__ = MTN.t("Do you want to have a similar meeting page? It's easy and works with your calendar.");
                buf.push(null == __val__ ? "" : __val__);
                buf.push('</p>\n    <p><a href="/meetings/wizard" class="button blue">');
                var __val__ = MTN.t("Claim your free Meet Me page now");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</a></p>");
            }
            buf.push("\n  </div>");
        } else {
            buf.push('\n  <div class="modal-header">\n    <h3>');
            var __val__ = MTN.t("Check your inbox to continue");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</h3>\n  </div>\n  <div class="modal-content">\n    <p>');
            var __val__ = MTN.t("We have sent you an email to %(B$%1$s%) from %(B$info@meetin.gs%).", {
                params: [ meetme_user.user_email ],
                B: {
                    classes: "email"
                }
            });
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>\n    <p>");
            var __val__ = MTN.t("Open the email and %(B$confirm your request to meet%) by following the link in the email. If you have not received the email, please check your spam folder.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>\n    <p>");
            var __val__ = MTN.t("You have %(B$24 hours%) to confirm, after which the reservation we're holding will be released to others.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</p>\n  </div>");
        }
        buf.push('\n</div>\n<div class="matchmaking-link"></div>');
    }
    return buf.join("");
};

// userSettingsAccount.jade compiled template
exports.userSettingsAccount = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="meeting-settings">\n  <!-- TODO: Req user subscriptions info-->\n  <div class="setting-head">\n    <h3 class="setting-title"><i class="icon ico-settings"></i>');
        var __val__ = MTN.t("Your account settings");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n    </h3>\n    <p class="setting-desc">');
        var __val__ = MTN.t("Manage your account and subscription.");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</p>\n  </div>\n  <div class="setting-content">\n    <div class="setting-section">');
        if (!dicole.get_global_variable("meetings_user_is_visitor")) {
            buf.push('\n      <h3 class="setting-sub-title">');
            var __val__ = MTN.t("Subscription");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</h3>\n      <!-- Not yet started trial-->");
            if (!user.is_pro && !user.is_trial_pro && !user.is_free_trial_expired) {
                buf.push("\n      <p>");
                var __val__ = MTN.t("You are using the limited version of Meetin.gs. Start your free 30-day trial to explore the full suite with all the benefits.");
                buf.push(null == __val__ ? "" : __val__);
                buf.push('</p><a href="#" class="button blue upgrade">');
                var __val__ = MTN.t("Start the trial");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</a>");
            } else if (user.subscription_type === "trial") {
                buf.push("\n      <p>");
                var __val__ = MTN.t("Your free trial sponsored by Meetin.gs will end %(B$%1$s%).", [ moment(user.subscription_trial_expires_epoch * 1e3).fromNow() ]);
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</p>\n      <p>");
                var __val__ = MTN.t("Upgrade Meetin.gs now to secure a seamless transition after your trial ends. We will give you free credit for the time you have left on your trial. So your first billing cycle would start %1$s.", [ app.helpers.paymentDateString(user.subscription_trial_expires_epoch) ]);
                buf.push(null == __val__ ? "" : __val__);
                buf.push('</p>\n      <p><a href="#" class="button blue upgrade">');
                var __val__ = MTN.t("Upgrade now");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</a></p>\n      <p>");
                var __val__ = MTN.t("Learn more about %(L$paid subscriptions%).", {
                    L: {
                        href: app.helpers.getPricingLink(),
                        "class": "underline",
                        target: "_blank"
                    }
                });
                buf.push(null == __val__ ? "" : __val__);
                buf.push('</p>\n      <p class="note">');
                var __val__ = MTN.t("Are you running out of time or require additional information on our service? Don't worry, just %(L$contact%) our Head of Customer happiness Antti to request an extension or %(A$schedule%) a short call with him to learn more.", {
                    L: {
                        href: "mailto:antti@meetin.gs",
                        "class": "underline"
                    },
                    A: {
                        href: "http://meetin.gs/meet/amv",
                        "class": "underline",
                        target: "_blank"
                    }
                });
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</p>");
            } else if (user.is_free_trial_expired && !user.is_pro) {
                buf.push("\n      <p>");
                var __val__ = MTN.t("Your free trial of Meetin.gs has expired. Upgrade to PRO to continue using the full suite with only:");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</p>\n      <ul>\n        <li>");
                var __val__ = MTN.t("$12 / month / organizer");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</li>\n        <li>");
                var __val__ = MTN.t("$129 / year / organizer (ten percent discount)");
                buf.push(null == __val__ ? "" : __val__);
                buf.push('</li>\n      </ul>\n      <p><a href="#" class="button blue upgrade">');
                var __val__ = MTN.t("Upgrade now");
                buf.push(null == __val__ ? "" : __val__);
                buf.push('</a></p>\n      <p class="note">');
                var __val__ = MTN.t("Did you miss the trial or require additional information of the service? Don't worry, just %(L$contact%) our Head of Customer happiness Antti to request an extension or %(A$schedule%) a short call with him to learn more.", {
                    L: {
                        href: "mailto:antti@meetin.gs",
                        "class": "underline"
                    },
                    A: {
                        href: "http://meetin.gs/meet/amv",
                        "class": "underline",
                        target: "_blank"
                    }
                });
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</p>");
            } else if (user.subscription_type === "sponsored" && user.is_pro) {
                buf.push("\n      <p>");
                var __val__ = MTN.t("You are using the free PRO account sponsored by Meetin.gs. Your PRO subscription will stay active for the time being. We sincerely hope you are enjoying it and would appreciate any %(L$feedback%).", {
                    L: {
                        href: "mailto:info@meetin.gs",
                        "class": "underline"
                    }
                });
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</p>\n      <p>");
                var __val__ = MTN.t("Do you like our service? Support our cause and further development by upgrading to the paid PRO with only:");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</p>\n      <ul>\n        <li>");
                var __val__ = MTN.t("$12 / month / organizer");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</li>\n        <li>");
                var __val__ = MTN.t("$129 / year / organizer (ten percent discount)");
                buf.push(null == __val__ ? "" : __val__);
                buf.push('</li>\n      </ul><a href="#" class="button blue upgrade">');
                var __val__ = MTN.t("Support us & upgrade");
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</a>\n      <p>");
                var __val__ = MTN.t("Learn more about %(L$paid subscriptions%).", {
                    L: {
                        href: app.helpers.getPricingLink(),
                        "class": "underline",
                        target: "_blank"
                    }
                });
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</p>");
            } else if (user.subscription_type === "user") {
                if (user.subscription_user_admin_url) {
                    buf.push("\n      <p>");
                    var __val__ = MTN.t("Thank you for your subscription. We really appreciate it.");
                    buf.push(null == __val__ ? "" : __val__);
                    buf.push("</p>\n      <p>");
                    var __val__ = MTN.t("Use Paypal to manage your subscription:");
                    buf.push(null == __val__ ? "" : __val__);
                    buf.push("</p>\n      <p><a");
                    buf.push(attrs({
                        href: user.subscription_user_admin_url,
                        "class": "button" + " " + "blue"
                    }, {
                        href: true
                    }));
                    buf.push(">");
                    var __val__ = MTN.t("Manage your subscription");
                    buf.push(null == __val__ ? "" : __val__);
                    buf.push("</a></p>");
                } else if (user.subscription_user_expires_epoch) {
                    buf.push("\n      <p>");
                    var __val__ = MTN.t("You have canceled your subscription. Your account will be downgraded once your last billing cycle ends %1$s.", [ moment(user.subscription_user_expires_epoch * 1e3).fromNow() ]);
                    buf.push(null == __val__ ? "" : __val__);
                    buf.push('</p>\n      <p><a href="#" class="button blue upgrade">');
                    var __val__ = MTN.t("Re-subscribe");
                    buf.push(null == __val__ ? "" : __val__);
                    buf.push("</a></p>");
                } else {
                    if (user.subscription_user_plan === "yearly") {
                        buf.push("\n      <p>");
                        var __val__ = MTN.t("You are on the yearly Meetin.gs PRO plan.");
                        buf.push(null == __val__ ? "" : __val__);
                        buf.push("</p>");
                    } else {
                        buf.push("\n      <p>");
                        var __val__ = MTN.t("You are on the monthly Meetin.gs PRO plan.");
                        buf.push(null == __val__ ? "" : __val__);
                        buf.push("</p>");
                    }
                    buf.push("\n      <p>");
                    var __val__ = MTN.t("Your next billing cycle starts %1$s.", [ moment(user.subscription_user_next_payment_epoch * 1e3).fromNow() ]);
                    buf.push(null == __val__ ? "" : __val__);
                    buf.push("</p>\n      <p>");
                    var __val__ = MTN.t("Thank you for your subscription. We really appreciate it.");
                    buf.push(null == __val__ ? "" : __val__);
                    buf.push('</p>\n      <p><a href="#" class="button gray cancel-subscription">');
                    var __val__ = MTN.t("Cancel subscription");
                    buf.push(null == __val__ ? "" : __val__);
                    buf.push("</a></p>");
                }
            } else if (user.subscription_type === "company") {
                buf.push("\n      <p>");
                var __val__ = MTN.t("Your %1$s PRO subscription is paid by %2$s.", [ service_name, user.subscription_company_name ]);
                buf.push(null == __val__ ? "" : __val__);
                buf.push("</p>");
                if (user.subscription_company_admin_name) {
                    buf.push("\n      <p>");
                    var __val__ = MTN.t("The administrator managing this company account is %1$s.", [ user.subscription_company_admin_name ]);
                    buf.push(null == __val__ ? "" : __val__);
                    buf.push("</p>");
                }
            }
        }
        buf.push('\n    </div>\n    <div class="receipts-container"></div>');
        if (user.subscription_type !== "company") {
            buf.push('\n    <div class="setting-section">\n      <h3 class="setting-sub-title">');
            var __val__ = MTN.t("Remove account");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</h3>\n      <p>");
            var __val__ = MTN.t("Removing your account will delete all your personal information from the service, remove your Meet Me page, unsubscribe you from our mailing lists, and anonymise stored data like comments, meetings, and materials.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</p>\n      <p class="note">');
            var __val__ = MTN.t("Note: Others will still be able to invite you as a new participant to a meeting using the same email address.");
            buf.push(null == __val__ ? "" : __val__);
            buf.push('</p>\n      <p><a href="#" class="button gray remove-account">');
            var __val__ = MTN.t("Remove account");
            buf.push(null == __val__ ? "" : __val__);
            buf.push("</a></p>\n    </div>");
        }
        buf.push("\n  </div>\n</div>");
    }
    return buf.join("");
};

// agentBookingConfirm.jade compiled template
exports.agentBookingConfirm = function anonymous(locals, attrs, escape, rethrow, merge) {
    attrs = attrs || jade.attrs;
    escape = escape || jade.escape;
    rethrow = rethrow || jade.rethrow;
    merge = merge || jade.merge;
    var buf = [];
    with (locals || {}) {
        var interp;
        var __indent = [];
        buf.push('\n<div id="agent-booking-confirm" class="m-modal">\n  <div class="modal-header">\n    <h3> <i class="ico-profile"></i>');
        var __val__ = "Vahvista varaus" || MTN.t("Confirm reservation");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('\n    </h3>\n  </div>\n  <div class="modal-content">\n    <div class="infos">\n      <div class="info">\n        <h3>');
        var __val__ = lock.times_string;
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</h3>\n      </div>\n      <div class="info">\n        <h3>');
        var __val__ = booking_data.meeting_type;
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</h3>\n        <p class="m-form location-area-display"></p>\n        <p class="m-form location-area">\n          <input type="text" class="location-field"/><i class="ico-cross js-cancel-location"></i><i class="ico-check js-save-location"></i>\n        </p>\n        <p><a href="#" class="change-location">');
        var __val__ = "Muuta sijaintia" || MTN.t("Change location");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push("</a>");
        if (booking_data.agent.verkkosivu) {
            {
                buf.push('<span class="divider">');
                var __val__ = " | ";
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</span><a");
                buf.push(attrs({
                    href: booking_data.agent.verkkosivu,
                    target: "_blank",
                    "class": "home-page"
                }, {
                    href: true,
                    target: true
                }));
                buf.push(">");
                var __val__ = "Toimiston verkkosivu" || MTN.t("Homepage");
                buf.push(escape(null == __val__ ? "" : __val__));
                buf.push("</a>");
            }
        }
        buf.push('\n        </p>\n      </div>\n      <div class="info">\n        <h3>');
        var __val__ = booking_data.agent.name;
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push("</h3>\n        <p>");
        var __val__ = booking_data.agent.title || MTN.t("Customer service agent");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</p>\n      </div>\n    </div>\n    <div class="m-form content-area">\n      <div class="left">\n        <div class="form-row">\n          <label class="required">');
        var __val__ = "Asiakkaan nimi" || MTN.t("Customer name");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</label>\n          <input id="booking-form-name" type="text"/>\n        </div>\n        <div class="form-row">\n          <label>');
        var __val__ = "Sähköposti" || MTN.t("Email");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</label>\n          <input id="booking-form-email" type="text" placeholder="Älä täytä jos ei ole sähköpostia"/>\n        </div>\n        <div class="form-row">\n          <label class="required">');
        var __val__ = "Puhelinnumero" || MTN.t("Phone number");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</label>\n          <input id="booking-form-phone" type="text"/>\n        </div>\n        <div class="form-row">\n          <label class="required">');
        var __val__ = "Syntymäaika" || MTN.t("Birth date");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</label>\n          <input id="booking-form-birthdate" type="text"/>\n        </div>\n        <div class="form-row">\n          <label class="required">');
        var __val__ = "Osoite" || MTN.t("Address");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</label>\n          <input id="booking-form-address" type="text"/>\n        </div>\n        <div class="form-row">\n          <label class="required">');
        var __val__ = "Postitoimipaikka" || MTN.t("Area");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</label>\n          <input id="booking-form-area" type="text"/>\n        </div>\n      </div>\n      <div class="right">\n        <div class="form-row">\n          <label class="language-label">');
        var __val__ = "Kieli" || MTN.t("Language");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</label>\n          <select id="booking-form-language" type="text">\n            <option value="fi">Suomi</option>\n            <option value="sv">Svenska</option>\n            <option value="en">English</option>\n          </select>\n        </div>\n        <div class="form-row">\n          <label class="language-label">');
        var __val__ = "Taso" || MTN.t("Level");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</label>\n          <select id="booking-form-level" type="text">\n            <option value="etutaso0-1">Etutaso 0-1</option>\n            <option value="etutaso2-4">Etutaso 2-4</option>\n          </select>\n        </div>\n        <div class="form-row">\n          <label style="width:300px">');
        var __val__ = "Lisätiedot Lähixcustxzn edustajalle:" || MTN.t("Message to agenda:");
        buf.push(escape(null == __val__ ? "" : __val__));
        buf.push('</label>\n        </div>\n        <div class="form-row">\n          <textarea id="booking-form-agenda" rows="6"></textarea>\n        </div>\n      </div>\n    </div>\n  </div>\n  <div class="modal-footer">\n    <div class="buttons right"><a href="#" class="button blue confirm">');
        var __val__ = "Vahvista" || MTN.t("Confirm");
        buf.push(null == __val__ ? "" : __val__);
        buf.push('</a><a href="#" class="button gray cancel">');
        var __val__ = "Peruuta" || MTN.t("Cancel");
        buf.push(null == __val__ ? "" : __val__);
        buf.push("</a></div>\n  </div>\n</div>");
    }
    return buf.join("");
};


// attach to window or export with commonJS
if (typeof module !== "undefined") {
    module.exports = exports;
} else if (typeof define === "function" && define.amd) {
    define(exports);
} else {
    root.templatizer = exports;
}

})();