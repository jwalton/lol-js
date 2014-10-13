ld = require 'lodash'

module.exports = class InMemoryCache
    constructor: ->
        @cache = Object.create(null)

    get: (params, cb) ->
        if !params.key? then cb new Error("Missing key")
        cacheEntry = @cache[params.key]
        if cacheEntry?
            answer = if Date.now() > cacheEntry.expires
                null
            else
                ld.cloneDeep cacheEntry.value
        cb null, answer

    set: (params, value) ->
        @cache[params.key] = {
            expires: Date.now() + params.ttl * 1000
            value: ld.cloneDeep(value)
        }
