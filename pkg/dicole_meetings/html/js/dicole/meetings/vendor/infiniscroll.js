dojo.provide("dicole.meetings.vendor.infiniscroll");

dojo.require('dicole.meetings.vendor.jquery');

// Created by Jonathan Eatherly, (https://github.com/joneath)
// MIT license
// Version 0.1

(function() {
    Backbone.InfiniScroll = function(collection, options) {
        options = options || { };

        var self = { },
        $target,
        fetchOn,
        page,
        pageSize,
        prevScrollY = 0;

        pageSize = 20;

        self.collection = collection;
        self.options = _.defaults(options, {
            success: function(){ },
            error: function(){ },
            onFetch: function(){ },
            target: $(window),
            param: "until",
            untilAttr: "id",
            pageSize: pageSize,
            scrollOffset: 100,
            scrollOn: true,
            add: true,
            update: true,
            strict: false,
            includePage: true,
            extraParams : {},
            direction: 'down'
        });

        var initialize = function() {
            $target = $(self.options.target);
            fetchOn = true;
            page = 1;

            $target.on("scroll", self.watchScroll);
        };

        self.destroy = function() {
            $target.off("scroll", self.watchScroll);
        };

        self.enableFetch = function() {
            fetchOn = true;
        };

        self.disableFetch = function() {
            fetchOn = false;
        };

        self.onFetch = function() {
            self.options.onFetch();
        };

        self.fetchSuccess = function(collection, response) {
            if ((self.options.strict && collection.length >= (page + 1) * self.options.pageSize) || (!self.options.strict && response.length >= self.options.pageSize)) {
                self.enableFetch();
                page += 1;
            } else {
                self.disableFetch();
            }
            self.options.success(collection, response);
        };

        self.fetchError = function(collection, response) {
            self.enableFetch();

            self.options.error(collection, response);
        };

        self.watchScroll = function(e) {
            var queryParams,
            scrollY = $target.scrollTop() + $target.height(),
            scrollYbottom = $target.scrollTop(),
            docHeight = $target.get(0).scrollHeight;

            if (!docHeight) {
                docHeight = $(document).height();
            }

            // Check scroll params
            var getmore = false;
            if( self.options.direction === 'down'){
                getmore = ( scrollY >= docHeight - self.options.scrollOffset && prevScrollY <= scrollY ) ? true : false;
            }
            else if( self.options.direction === 'up'){
                getmore = ( scrollYbottom <= self.options.scrollOffset && prevScrollY >= scrollY ) ? true : false;
            }

            if ( getmore && fetchOn ) {
                var lastModel = self.collection.last();
                if (!lastModel) { return; }

                self.onFetch();
                self.disableFetch();
                self.collection.fetch({
                    success: self.fetchSuccess,
                    error: self.fetchError,
                    add: self.options.add,
                    update: self.options.update,
                    remove: false,
                    data: buildQueryParams(lastModel)
                    //silent: true
                });
            }
            prevScrollY = scrollY;
        };

        function buildQueryParams(model) {
            var params = { };

            params[self.options.param] = typeof(model[self.options.untilAttr]) === "function" ? model[self.options.untilAttr]() : model.get(self.options.untilAttr);

            if (self.options.includePage) {
                params.offset = (page ) * self.options.pageSize;
                params.limit = self.options.pageSize;
            }

            if ( self.options.extraParams ){
               params =  _.extend( self.options.extraParams, params );
            }

            if( self.options.query ){
                params = _.extend( params, self.options.query );
            }

            params = _.extend( params, { image_size : 50, include_draft : 1 });

            return params;
        }

        initialize();

        return self;
    };
})();


//fgnass.github.com/spin.js#v1.3.1
(function(t,e){if(typeof exports=="object")module.exports=e();else if(typeof define=="function"&&define.amd)define(e);else t.Spinner=e()})(this,function(){"use strict";var t=["webkit","Moz","ms","O"],e={},i;function o(t,e){var i=document.createElement(t||"div"),o;for(o in e)i[o]=e[o];return i}function n(t){for(var e=1,i=arguments.length;e<i;e++)t.appendChild(arguments[e]);return t}var r=function(){var t=o("style",{type:"text/css"});n(document.getElementsByTagName("head")[0],t);return t.sheet||t.styleSheet}();function s(t,o,n,s){var a=["opacity",o,~~(t*100),n,s].join("-"),f=.01+n/s*100,l=Math.max(1-(1-t)/o*(100-f),t),u=i.substring(0,i.indexOf("Animation")).toLowerCase(),d=u&&"-"+u+"-"||"";if(!e[a]){r.insertRule("@"+d+"keyframes "+a+"{"+"0%{opacity:"+l+"}"+f+"%{opacity:"+t+"}"+(f+.01)+"%{opacity:1}"+(f+o)%100+"%{opacity:"+t+"}"+"100%{opacity:"+l+"}"+"}",r.cssRules.length);e[a]=1}return a}function a(e,i){var o=e.style,n,r;if(o[i]!==undefined)return i;i=i.charAt(0).toUpperCase()+i.slice(1);for(r=0;r<t.length;r++){n=t[r]+i;if(o[n]!==undefined)return n}}function f(t,e){for(var i in e)t.style[a(t,i)||i]=e[i];return t}function l(t){for(var e=1;e<arguments.length;e++){var i=arguments[e];for(var o in i)if(t[o]===undefined)t[o]=i[o]}return t}function u(t){var e={x:t.offsetLeft,y:t.offsetTop};while(t=t.offsetParent)e.x+=t.offsetLeft,e.y+=t.offsetTop;return e}function d(t,e){return typeof t=="string"?t:t[e%t.length]}var p={lines:12,length:7,width:5,radius:10,rotate:0,corners:1,color:"#000",direction:1,speed:1,trail:100,opacity:1/4,fps:20,zIndex:2e9,className:"spinner",top:"auto",left:"auto",position:"relative"};function c(t){if(typeof this=="undefined")return new c(t);this.opts=l(t||{},c.defaults,p)}c.defaults={};l(c.prototype,{spin:function(t){this.stop();var e=this,n=e.opts,r=e.el=f(o(0,{className:n.className}),{position:n.position,width:0,zIndex:n.zIndex}),s=n.radius+n.length+n.width,a,l;if(t){t.insertBefore(r,t.firstChild||null);l=u(t);a=u(r);f(r,{left:(n.left=="auto"?l.x-a.x+(t.offsetWidth>>1):parseInt(n.left,10)+s)+"px",top:(n.top=="auto"?l.y-a.y+(t.offsetHeight>>1):parseInt(n.top,10)+s)+"px"})}r.setAttribute("role","progressbar");e.lines(r,e.opts);if(!i){var d=0,p=(n.lines-1)*(1-n.direction)/2,c,h=n.fps,m=h/n.speed,y=(1-n.opacity)/(m*n.trail/100),g=m/n.lines;(function v(){d++;for(var t=0;t<n.lines;t++){c=Math.max(1-(d+(n.lines-t)*g)%m*y,n.opacity);e.opacity(r,t*n.direction+p,c,n)}e.timeout=e.el&&setTimeout(v,~~(1e3/h))})()}return e},stop:function(){var t=this.el;if(t){clearTimeout(this.timeout);if(t.parentNode)t.parentNode.removeChild(t);this.el=undefined}return this},lines:function(t,e){var r=0,a=(e.lines-1)*(1-e.direction)/2,l;function u(t,i){return f(o(),{position:"absolute",width:e.length+e.width+"px",height:e.width+"px",background:t,boxShadow:i,transformOrigin:"left",transform:"rotate("+~~(360/e.lines*r+e.rotate)+"deg) translate("+e.radius+"px"+",0)",borderRadius:(e.corners*e.width>>1)+"px"})}for(;r<e.lines;r++){l=f(o(),{position:"absolute",top:1+~(e.width/2)+"px",transform:e.hwaccel?"translate3d(0,0,0)":"",opacity:e.opacity,animation:i&&s(e.opacity,e.trail,a+r*e.direction,e.lines)+" "+1/e.speed+"s linear infinite"});if(e.shadow)n(l,f(u("#000","0 0 4px "+"#000"),{top:2+"px"}));n(t,n(l,u(d(e.color,r),"0 0 1px rgba(0,0,0,.1)")))}return t},opacity:function(t,e,i){if(e<t.childNodes.length)t.childNodes[e].style.opacity=i}});function h(){function t(t,e){return o("<"+t+' xmlns="urn:schemas-microsoft.com:vml" class="spin-vml">',e)}r.addRule(".spin-vml","behavior:url(#default#VML)");c.prototype.lines=function(e,i){var o=i.length+i.width,r=2*o;function s(){return f(t("group",{coordsize:r+" "+r,coordorigin:-o+" "+-o}),{width:r,height:r})}var a=-(i.width+i.length)*2+"px",l=f(s(),{position:"absolute",top:a,left:a}),u;function p(e,r,a){n(l,n(f(s(),{rotation:360/i.lines*e+"deg",left:~~r}),n(f(t("roundrect",{arcsize:i.corners}),{width:o,height:i.width,left:i.radius,top:-i.width>>1,filter:a}),t("fill",{color:d(i.color,e),opacity:i.opacity}),t("stroke",{opacity:0}))))}if(i.shadow)for(u=1;u<=i.lines;u++)p(u,-2,"progid:DXImageTransform.Microsoft.Blur(pixelradius=2,makeshadow=1,shadowopacity=.3)");for(u=1;u<=i.lines;u++)p(u);return n(e,l)};c.prototype.opacity=function(t,e,i,o){var n=t.firstChild;o=o.shadow&&o.lines||0;if(n&&e+o<n.childNodes.length){n=n.childNodes[e+o];n=n&&n.firstChild;n=n&&n.firstChild;if(n)n.opacity=i}}}var m=f(o("group"),{behavior:"url(#default#VML)"});if(!a(m,"transform")&&m.adj)h();else i=a(m,"animation");return c});
