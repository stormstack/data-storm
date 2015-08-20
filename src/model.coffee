Registry = require './registry'

class ModelRegistryProperty extends Registry.Property

  constructor: (@model, opts, obj) -> super 'object', opts, obj

  match: (query, keys=false) ->
    switch
      when query instanceof Array then super
      when query instanceof Object
        for k, v of @get() when v.match query
          if keys then k else v
      else
        super

  serialize: (opts={}) ->
    ids: Object.keys(@value)
    numRecords: Object.keys(@value).length

class ModelRegistry extends Registry

  @Property = ModelRegistryProperty

  register: (model, opts) ->
    # may not need this...
    # model.meta ?= name: model.name
    # model.meta.name ?= model.name
    super model.meta.name, new ModelRegistryProperty model, opts, this

  add: (records...) ->
    obj = {}
    obj[record.get('id')] = record for record in records when record instanceof Model
    super record.constructor.meta.name, obj

  remove: (records...) ->
    query = (record.get('id') for record in records when record instanceof Model)
    super record.constructor.meta.name, query

  contains: (key) -> (@access key)


Promise = require 'promise'

class SynthModel extends (require './object')
  @set synth: 'model'

  @belongsTo = (model, opts) ->
    class extends (require './property/belongsTo')
      @set model: model
      @merge opts

  @hasMany = (model, opts) ->
    class extends (require './property/hasMany')
      @set model: model
      @merge opts

  @action = (func, opts) ->
    class extends (require './property/action')
      @set func: func
      @merge opts

  @schema
    modifiedOn: @attr 'date', private: true
    # internal tracking of bound model records (those that should be
    # destroyed when this record is destroyed)
    children: @hasMany SynthModel, private: true

  # invoke allows you to apply arbitrary function on the Model as a Promise
  invoke: (action, args..., cb) ->
    new Promise (resolve, reject) =>
      if cb instanceof Function
        action.apply this, args.concat ->
          try resolve cb.apply null, arguments
          catch err then reject err
      else
        try resolve action.apply this, args.concat cb
        catch err then reject err

  set: ->
    # before setting ANY new value, keep track of any changes
    # only after successful 'save' the transaction logs are cleared
    super

  save: ->
    # XXX - a bit ugly at the moment...
    # console.log 'SAVING:'
    isValid = @validate()
    # console.log isValid
    if isValid.length is 0
      (@set 'modifiedOn', new Date) if @isDirty()
      @clearDirty()
      @_models.add this
      this
    else
      null

  rollback: ->
    
  RelationshipProperty = (require './property/relationship')

  getRelationships: (kind) ->
      @everyProperty (key) -> this if this instanceof RelationshipProperty
      .filter (x) -> x? and (not kind? or kind is (x.constructor.get 'kind'))

  ###*
  # `bind` subjugates passed in records to be bound to the lifespan of
  # the current model record.
  #
  # When this current model record is destroyed, all bound dependents
  # will also be destroyed.
  ###

  bind: (records...) ->
    for record in records
      continue unless record? and record instanceof SynthModel
      (@access 'children').push record.save()

  match: (query) ->
      for k, v of query
          x = (@access k)?.normalize (@get k)
          x = "#{x}" if typeof x is 'boolean' and typeof v is 'string'
          return false unless x is v
      return true

  destroy: ->
      record.destroy() for record in @get '_bindings'
      @_models.remove this

module.exports = SynthModel
