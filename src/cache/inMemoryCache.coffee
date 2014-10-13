ld = require 'lodash'

module.exports = class InMemoryCache
    constructor: ->
        @cache = Object.create(null)

    get: (params, cb) ->
        if !params.key? then cb new Error("Missing key")
        cacheEntry = @cache[params.key]
        if cacheEntry?
            answer = if cacheEntry.expires? and (Date.now() > cacheEntry.expires)
                null
            else
                ld.cloneDeep cacheEntry.value
        cb null, answer

    set: (params, value) ->
        @cache[params.key] = {
            expires: if params.ttl? then (Date.now() + params.ttl * 1000) else null
            value: ld.cloneDeep(value)
        }
