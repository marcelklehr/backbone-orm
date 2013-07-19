util = require 'util'
_ = require 'underscore'

MemoryCursor = require './lib/memory_cursor'
Schema = require './lib/schema'
Utils = require './lib/utils'

# Backbone Sync for in-memory models.
#
# @example How to configure using a model name
#   class Thing extends Backbone.Model
#     @model_name: 'Thing'
#     sync: require('backbone-orm/memory_sync')(Thing)
#
# @example How to configure using a url
#   class Thing extends Backbone.Model
#     url: '/things'
#     sync: require('backbone-orm/memory_sync')(Thing)
#
class MemorySync
  # @private
  constructor: (@model_type) ->
    @store = {}

    unless @model_type.model_name # model_name will come from the url
      throw new Error('Missing url for model') unless url = _.result(@model_type.prototype, 'url')
      @model_type.model_name = Utils.parseUrl(url).model_name
    @schema = new Schema(@model_type)

  # @private
  initialize: ->
    return if @is_initialized; @is_initialized = true
    @schema.initialize()

  # @private
  read: (model, options) ->
    options.success(if model.models then (json for id, json of @store) else @store[model.attributes.id])

  # @private
  create: (model, options) ->
    model.attributes.id = Utils.guid()
    model_json = @store[model.attributes.id] = model.toJSON()
    options.success(model_json)

  # @private
  update: (model, options) ->
    return @create(model, options) unless model_json = @store[model.attributes.id] # if bootstrapped, it may not yet be in the store
    _.extend(model_json, model.toJSON())
    options.success(model_json)

  # @private
  delete: (model, options) ->
    return options.error(new Error('Model not found')) unless model_json = @store[model.attributes.id]
    delete @store[model.attributes.id]
    options.success(model_json)

  ###################################
  # Backbone ORM - Class Extensions
  ###################################

  # @private
  cursor: (query={}) -> return new MemoryCursor(query, _.pick(@, ['model_type', 'store']))

  # @private
  destroy: (query, callback) ->
    if (keys = _.keys(query)).length
      for id, model_json of @store
        delete @store[id] if _.isEqual(_.pick(model_json, keys), query)
    else
      @store = {}
    return callback()


module.exports = (model_type, cache) ->
  sync = new MemorySync(model_type)

  model_type::sync = sync_fn = (method, model, options={}) -> # save for access by model extensions
    sync.initialize()
    return module.exports.apply(null, Array::slice.call(arguments, 1)) if method is 'createSync' # create a new sync
    return sync if method is 'sync'
    return sync.schema if method is 'schema'
    if sync[method] then sync[method].apply(sync, Array::slice.call(arguments, 1)) else return undefined

  require('./lib/model_extensions')(model_type) # mixin extensions
  return if cache then require('./lib/cache_sync')(model_type, sync_fn) else sync_fn