class ListProperty extends (require '../property')
  @set synth: 'list'
  @merge options: [ 'subtype', 'key', 'ordered-by' ]

  constructor: ->
    unless (@constructor.get 'type') is 'array'
      @constructor.set type: 'array', subtype: (@constructor.get 'type')
    super

  get: (key) ->
    list = (super null).map (x) -> x.get?() ? x
    return list unless key?
    mkey = @meta 'key'
    for item in list when key is item[mkey]
      return item
    undefined

  match: (query={}) ->
    super
      .map (x) -> x.get?() ? x
      .where query

  access: (key) ->
    mkey = @meta 'key'
    for item in @value
      check = (item.get? mkey) ? item[mkey]
      if key is check
        return item
    undefined
    
  push: -> @set @value.concat arguments...

  remove: (keys...) ->
    query = ListProperty.objectify (@meta 'key'), [].concat keys...
    @set @value.without query

  Meta = require '../meta'
  normalize: ->
    super.map (x) => switch
      when (Meta.instanceof @opts.subtype)
        if x instanceof @opts.subtype then x
        else new @opts.subtype x, this
      else x

  validate: (value=@value) ->
    isClass = @opts.subtype instanceof Function
    super and value.every (x) =>
      (not @opts.subtype?) or (typeof x is @opts.subtype) or (isClass and x instanceof @opts.subtype)

module.exports = ListProperty
