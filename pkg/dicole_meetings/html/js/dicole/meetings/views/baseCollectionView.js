dojo.provide("dicole.meetings.views.baseCollectionView");

app.baseCollectionView = Backbone.View.extend({
    getDateString : function( epoch ){
        return moment.utc( parseInt(epoch) + 1000 * parseInt(dicole.get_global_variable('meetings_user_timezone_offset_value')) ).format('ddd<br/>DD MMM');
    },
    initialize : function(options) {

        // Check requirements
        if (!options.childViewConstructor) throw "no child view constructor provided";
        if (!options.childViewTagName) throw "no child view tag name provided";

        // Setup render extras
        if ( options.renderExtras ) this.renderExtras = options.renderExtras;
        if ( options.badgeHtml ) this.badgeHtml = options.badgeHtml;

        // Bind this to this object
        _(this).bindAll('add', 'remove', 'reset');

        // Save options
        this.opts = _.extend( {
            infiniScroll : false,
            mode : 'normal',
            showTimestamps : true
        }, options );

        // Cache jQuery selector for parent element
        this.el = $(this.el);

        // Initiate add buffer
        this.addHtmlBuffer = '';

        // Setup infinite scrolling
        if (this.opts.infiniScroll){
            var direction = this.opts.infiniScrollDirection || 'down';
            var extraParams = this.opts.infiniScrollExtraParams || {};
            this.infiniScroll = new Backbone.InfiniScroll(this.collection, {
                success: function(col, res){ this.view.scrolledMore(col, res); },
                onFetch: function(){
                    this.view.showLoader();
                },
                direction: direction,
                extraParams: extraParams,
                view: this
            });
        }

        // Setup childviews & bind events
        this._childViewConstructor = options.childViewConstructor;
        this._childViewTagName = options.childViewTagName;
        this._childViews = [];
        this.collection.each(this.add);
        this.collection.bind('add', this.add);
        this.collection.bind('remove', this.remove);
        this.collection.bind('reset', this.reset);

        // Setup onRender function
        if ( typeof options.onRender === 'function' ) {
            this.onRender = options.onRender;
        }

        // Setup on empty function
        if ( typeof options.emptyString === 'string' ) {
            this.emptyString = options.emptyString;
        }
    },

    // Clean the model
    reset : function(collection, options){
        this._childViews = [];
        var that = this;
        $.each( collection.models, function(){
            var cv = new that._childViewConstructor({
                tagName : that._childViewTagName,
                model : this
            });
            that._childViews.push(cv);
        });
        this.render();
    },

    // Add model to the collection
    // // TODO FIX This
    add : function(model, self, options) {
        var childView = new this._childViewConstructor({
            tagName : this._childViewTagName,
            model : model
        });

        var start_pos = this._childViews.length - 1;
        this._childViews.push(childView);

        if (this._rendered) {
            var previous = this.collection.at(start_pos);
            var prev_day = moment( previous.get('begin_epoch') * 1000 ).startOf('day').format();
            var this_day = moment( model.get('begin_epoch') * 1000 ).startOf('day').format();

            if( prev_day === this_day ){
                // Find last row and insert inside
                $('.row:last-child', this.el).append( childView.render().el );
            }
            else{
                // Create new day row and insert inside
                var $row = $('<div class="row"></div>');
                $row.append('<div class="line horizontal1"></div>');
                if( this.opts.showTimestamps ){
                    $row.append('<div class="timestamp alone">'+ this.getDateString( 1000 * parseInt(model.get('begin_epoch') ) )+'</div>');
                }
                $row.append( childView.render().el );
                this.$el.append( $row );

            }
        }
    },

    // Remove model from the collection
    remove : function(model) {
        var viewToRemove = _.filter(this._childViews, function(cv) { return cv.model === model; })[0];
        this._childViews = _.without(this._childViews, viewToRemove);

        this.reset( this.collection );

        // Remove whole view if it was the last meeting
        if( this._childViews.length === 0 ) this.$el.remove();
        return;

        if (this._rendered) {
            $(viewToRemove.el).remove();
        }
    },

    // Render the whole view
    render : function() {

        // If empty, remove view
        if( this.collection.length === 0 ){
            this.$el.remove();
            return;
        }

        this._rendered = true;

        this.$el.html('');

        this.$el.append('<div class="line vertical"></div>');
        var $buf = $('<div class="row"></div>');
        var prevdate = '';
        $buf.append('<div class="line horizontal1"></div>' + this.badgeHtml);
        var s = this._childViews.length;
        for (var i = 0; i < s ; i++ ){

            // Timestamp
            var epoch = this._childViews[i].model.get('begin_epoch');
            var datestring = this.getDateString(parseInt(epoch)*1000);
            // TODO: Check that moementr retuns valid datestifng
            if( i === 0 && datestring && this.opts.showTimestamps ){
                $buf.append('<div class="timestamp">'+ datestring +'</div>');
            }

            // If day changed change row and add datum
            else if( prevdate !== datestring && ! this._childViews[i].model.get('highlight') ){
                this.$el.append( $buf );
                $buf = $('<div class="row"></div>');
                if( this.opts.showTimestamps )
                    $buf.append('<div class="timestamp alone">'+ datestring +'</div><div class="line horizontal1"></div>');
            }

            $buf.append( this._childViews[i].render().el );

            // Set datestring
            prevdate = datestring;
        }

        this.$el.append($buf);

        // Call on render function
        if ( typeof this.onRender === 'function' ) {
            this.onRender();
        }

        // Call onEmpty if no results
        if( ! s && typeof this.emptyString === 'string' ){
            this.el.html( this.emptyString );
        }

        return this;
    },

    scrolledMore : function(col, res) {
        this.loader.remove();
    },

    showLoader : function(){
        this.loader = $('<div style="height:80px;"></div>');
        this.$el.append(this.loader);
        var spinner = new Spinner(app.defaults.spinner_opts).spin( this.loader[0] );
    }
});
