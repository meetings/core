dojo.provide("dicole.event_source.ServerConnection");

dojo.require("dojo.io.script");

dojo.declare("dicole.event_source.ServerConnection", null, {
	"error": {
		"no_session_open": new Error("No session open.")
	},
	
	"constructor": function(url) {
		this.url = url;
		this.session = null;
		this.received = {};
	},
	
	"open": function(domain, credentials, handler) {
		if(this.session) this.close();
		
		var open_handler = dojo.hitch(this, function(response) {
			if(response && response.result) this.session = response.result.session;
			if(handler) handler(response);
		});
		
		if(credentials.username && credentials.password) {
			this._rpc("open", {"domain": domain, "username": credentials.username, "password": credentials.password}, open_handler);
		}
		else if(credentials.token) {
			this._rpc("open", {"domain": domain, "token": credentials.token}, open_handler);
		}
	},
	
	"connected": function() {
		if(this.session) return true;
		return false;
	},

	"close": function(handler) {
		if(!this.session) throw this.error.no_session_open;	
		this._rpc("close", {"session": this.session}, dojo.hitch(this, function(response) {
			if(response.result) this.session = null;
			if(handler) handler(response);
		}));
	},

	"subscribe": function(subscription, handler) {
		if(!this.session) throw this.error.no_session_open;
		var params = dojo.clone(subscription);
		params.session = this.session;
		this._rpc("subscribe", params, handler);
	},

	"extend": function(subscription, handler) {
		if(!this.session) throw this.error.no_session_open;
		var params = {
			"session": this.session,
			"subscription": subscription.name,
			"history" : subscription.history ? subscription.history : 0,
			"future" : subscription.future ? subscription.future : 0
		};
		this._rpc("extend", params, handler);
	},

	"unsubscribe": function(name, handler) {
		if(!this.session) throw this.error.no_session_open;
		this._rpc("unsubscribe", {"session": this.session, "subscription": name}, handler);
	},

	"poll": function(amount, handler) {
		if(!this.session) throw this.error.no_session_open;
		this._rpc("poll", {"session": this.session, "amount": amount, "received": this.received}, dojo.hitch(this, function(response) {
			if(response && response.result) {
				for(var subscription in response.result) {
					this.received[subscription] = dojo.filter(this.received[subscription] ? this.received[subscription] : [], function(id) {
						return dojo.indexOf(response.result[subscription].confirmed, id) == -1;
					});
					
					dojo.forEach(response.result[subscription]["new"], function(event) {
						this.received[subscription].push(event.id);
					}, this);
				}
			}
			if(handler) handler(response);
		}));
	},
	
	"passthrough": function(method, params, handler) {
		if(!this.session) throw this.error.no_session_open;
		this._rpc("passthrough", {"session": this.session, "method": method, "params": params}, handler);
	},
	
	"_rpc": function(method, params, handler) {
		dojo.io.script.get({
			"url": this.url + method,
			"callbackParamName": "callback",
			"content": {"params": dojo.toJson(params)},
			"handle": handler
		});
	}
});