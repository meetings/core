dojo.provide("dicole.twitter");

dojo.require("dojo.io.script");

dojo.require("dicole.base");

dojo.addOnLoad(function() {
	dicole.register_template("twitter_container", {templatePath: dojo.moduleUrl("dicole.twitter", "twitter_container.html")});
	dicole.register_template("twitter_tweet", {templatePath: dojo.moduleUrl("dicole.twitter", "twitter_tweet.html")});
});

dojo.declare("dicole.twitter", null, {
	"constructor": function(query, results) {
		if(!query || typeof query != "string") throw new Error("No query specified!");
		
		this._query = encodeURI(query);
		this._results = results ? results : 15;
		this._tweets = {};
		this._instances = {};
		
		setInterval(dojo.hitch(this, this._poll), 30000);
		setInterval(dojo.hitch(this, this._update_ago_strings), 1000);
	},
	
	"render": function(settings) {
		if(!("id" in settings)) throw new Error("No placeholder id specified!");
		if(!("title" in settings)) settings.title = "Didddididiid";
		if(!("height" in settings)) settings.height = 200;
		if(!("scroll" in settings)) settings.scroll = false;
	
		dojo.place(dicole.process_template("twitter_container", {
			"id": settings.id,
			"title": settings.title,
			"query": settings.query
		}), settings.id, "replace");
	
		var container = dojo.byId(settings.id);
	
		this._instances[settings.id] = {
			"settings": settings,
			"container": container,
			"logo": dojo.query(".twitter_logo", container)[0],
			"spinner": dojo.query(".twitter_spinner", container)[0],
			"error": dojo.query(".twitter_error", container)[0],
			"tweets": dojo.query(".twitter_tweets", container)[0],
			"empty": dojo.query(".twitter_empty", container)[0]
		};
		
		dojo.style(this._instances[settings.id].tweets, "height", settings.height + "px");
		if(settings.scroll) dojo.addClass(this._instances[settings.id].tweets, "twitter_scroll");
		
		this._poll();
	},
	
	"_poll": function() {
		for(var instance in this._instances) {
			dojo.style(this._instances[instance].spinner, "display", "block");
		}
	
		dojo.io.script.get({
			"url": "http://search.twitter.com/search.json",
			"callbackParamName": "callback",
			"content": {
				"q": this._query,
				"rpp": this._results,
				"result_type": "recent"
			},
			"handle": dojo.hitch(this, function(response) {
				for(var instance in this._instances) {
					dojo.style(this._instances[instance].spinner, "display", "none");
				}
			}),
			"load": dojo.hitch(this, this._on_load),
			"error": dojo.hitch(this, this._on_error)
		});
	},
	
	"_on_load": function(response) {
		var result = "";
		
		dojo.forEach(response.results, function(tweet) {
			if(!(tweet.id in this._tweets)) {
				result += dicole.process_template("twitter_tweet", tweet);
				this._tweets[tweet.id] = tweet;
			}
		}, this);
		
		if(result.length) {
			for(var instance in this._instances) {
				dojo.place(result, this._instances[instance].tweets, "first");
				dojo.style(this._instances[instance].error, "display", "none");
				dojo.style(this._instances[instance].empty, "display", "none");
				dojo.style(this._instances[instance].tweets, "display", "block");
				dojo.removeClass(this._instances[instance].logo, "twitter_broken");
			}
		}
	},
	
	"_on_error": function(response) {
		for(var instance in this._instances) {
			dojo.addClass(this._instances[instance].logo, "twitter_broken");
		}
	},
	
	"_calculate_ago_string": function(date) {
		var now = Math.floor(new Date().getTime() / 1000);
		var difference = now - Math.floor(date.getTime() / 1000);
		if(!difference) return dicole.msg("now");
		var value = 0;
		if(value = Math.floor(difference / (60 * 60 * 24 * 365))) return value + " " + dicole.msg(value > 1 ? "years ago" : "year ago");
		else if(value = Math.floor(difference / (60 * 60 * 24 * 30))) return value + " " + dicole.msg(value > 1 ? "months ago" : "month ago");
		else if(value = Math.floor(difference / (60 * 60 * 24))) return value + " " + dicole.msg(value > 1 ? "days ago" : "day ago");
		else if(value = Math.floor(difference / (60 * 60))) return value + " " + dicole.msg(value > 1 ? "hours ago" : "hour ago");
		else if(value = Math.floor(difference / 60)) return value + " " + dicole.msg(value > 1 ? "minutes ago" : "minute ago");
		else return Math.floor(difference) + " " + dicole.msg(difference > 1 ? "seconds ago" : "second ago");
	},
	
	"_update_ago_strings": function() {
		for(var tweet_id in this._tweets) {
			dojo.query(".twitter_tweet_" + tweet_id + " .twitter_tweet_content_time").forEach(function(tweet_time) {
				tweet_time.innerHTML = this._calculate_ago_string(new Date(this._tweets[tweet_id].created_at));
			}, this);
		}
	}
});