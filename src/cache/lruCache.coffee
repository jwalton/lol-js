ld = require 'lodash'
LRU = require 'lru-cache'

module.exports = class LRUCache
    constructor: (options) ->
        @cache = LRU options

    get: (params, cb) ->
        setImmediate =>
            if !params.key? then cb new Error("Missing key")
            cacheEntry = @cache.get params.key
            if cacheEntry?
                answer = if cacheEntry.expires? and (Date.now() > cacheEntry.expires)
                    null
                else
                    ld.cloneDeep cacheEntry.value
            cb null, answer

    set: (params, value) ->
        @cache.set params.key, {
            expires: if params.ttl? then (Date.now() + params.ttl * 1000) else null
            value: ld.cloneDeep(value)
        }
