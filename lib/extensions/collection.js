
/*
  backbone-orm.js 0.5.10
  Copyright (c) 2013 Vidigami - https://github.com/vidigami/backbone-orm
  License: MIT (http://www.opensource.org/licenses/mit-license.php)
  Dependencies: Backbone.js, Underscore.js, Moment.js, and Inflection.js.
 */
var Backbone, Utils, collection_type, fn, key, overrides, _;

_ = require('underscore');

Backbone = require('backbone');

Utils = require('../utils');

collection_type = Backbone.Collection;

overrides = {
  fetch: function(options) {
    var callback;
    if (_.isFunction(callback = arguments[arguments.length - 1])) {
      switch (arguments.length) {
        case 1:
          options = Utils.wrapOptions({}, callback);
          break;
        case 2:
          options = Utils.wrapOptions(options, callback);
      }
    }
    return collection_type.prototype._orm_original_fns.fetch.call(this, Utils.wrapOptions(options, (function(_this) {
      return function(err, model, resp, options) {
        if (err) {
          return typeof options.error === "function" ? options.error(_this, resp, options) : void 0;
        }
        return typeof options.success === "function" ? options.success(model, resp, options) : void 0;
      };
    })(this)));
  },
  _prepareModel: function(attrs, options) {
    var id, is_new, model;
    if (!Utils.isModel(attrs) && (id = Utils.dataId(attrs))) {
      if (this.model.cache) {
        is_new = !!this.model.cache.get(id);
      }
      model = Utils.updateOrNew(attrs, this.model);
      if (is_new && !model._validate(attrs, options)) {
        this.trigger('invalid', this, attrs, options);
        return false;
      }
      return model;
    }
    return collection_type.prototype._orm_original_fns._prepareModel.call(this, attrs, options);
  }
};

if (!collection_type.prototype._orm_original_fns) {
  collection_type.prototype._orm_original_fns = {};
  for (key in overrides) {
    fn = overrides[key];
    collection_type.prototype._orm_original_fns[key] = collection_type.prototype[key];
    collection_type.prototype[key] = fn;
  }
}
