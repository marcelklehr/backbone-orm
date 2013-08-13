util = require 'util'
_ = require 'underscore'
Backbone = require 'backbone'
Queue = require 'queue-async'

Utils = require '../utils'
bbCallback = Utils.bbCallback

module.exports = class Relation

  _saveRelated: (model, related_models, callback) ->
    return callback() if @embed or not @reverse_relation

    @cursor(model, @key).toJSON (err, json) =>
      return callback(err) if err

      json = [] unless json
      json = [json] unless _.isArray(json)
      queue = new Queue(1)
      ids_generated = false

      # ensure there are ids
      for related_model in related_models
        continue if related_model.id
        ids_generated = true
        do (related_model) => queue.defer (callback) => related_model.save {}, Utils.bbCallback callback

      use_join = @join_table and not @reverse_model_type::sync('isRemote') and (@reverse_relation.type is 'hasMany')
      related_ids = _.pluck(related_models, 'id')
      changes = _.groupBy(json, (test) -> if _.contains(related_ids, test.id) then 'kept' else 'removed')
      added_ids = if changes.added then _.difference(related_ids, (test.id for test in changes.kept)) else related_ids

      # update store through join table
      if use_join
        # destroy removed
        if changes.removed
          do (model_json) => queue.defer (callback) =>
            @join_table.destroy {id: {$in: (model_json.id for model_json in changes.removed)}}, callback

        # create new - TODO: optimize through batch create
        for related_id in added_ids
          do (related_id) => queue.defer (callback) =>
            attributes = {}
            attributes[@foreign_key] = model.id
            attributes[@reverse_relation.foreign_key] = related_id
            # console.log "Creating join for: #{@model_type.model_name} join: #{util.inspect(attributes)}"
            join = new @join_table(attributes)
            join.save {}, Utils.bbCallback callback

      # clear back links on models and save
      else
        # clear removed - TODO: optimize using batch update
        if changes.removed
          for related_json in changes.removed
            do (related_json) => queue.defer (callback) => @_clearAndSaveRelatedBacklink(model, new @reverse_model_type(related_json), callback)

        # add new
        for added_id in added_ids
          related_model = _.find(related_models, (test) -> test.id is added_id)
          do (related_model) => queue.defer (callback) =>
            related_model.save {}, Utils.bbCallback (err, saved_model) =>
              cache.set(saved_model.id, saved_model) if not err and cache = @reverse_model_type.cache
              callback(err)

      # need to resave ourself - TODO: optimize before save is called
      queue.defer (callback) =>
        return callback() unless ids_generated
        model.save {}, bbCallback callback

      queue.await callback

  _clearAndSaveRelatedBacklink: (model, related_model, callback) ->
    return callback() unless (@reverse_relation and related_related = related_model.get(@reverse_relation.key))

    if related_related.models # collection
      related_related.remove(found) if found = related_related.get(model.id)
    else # model
      found = related_related if related_related.id is model.id
      related_model.set(@reverse_relation.foreign_key, null) if found
    return callback() unless found # no longer related, skip

    related_model.save {}, Utils.bbCallback (err, saved_model) =>
      cache.set(saved_model.id, saved_model) if not err and cache = @reverse_relation.model_type.cache
      callback(err)