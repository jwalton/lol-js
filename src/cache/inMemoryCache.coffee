module.exports = class InMemoryCache
    constructor: ->
        @cache = Object.create(null)

    get: (params, cb) ->
        if !params.key? then cb new Error("Missing key")
        answer = @cache[params.key]
        if answer?
            if Date.now() > answer.expires then answer = null else answer = answer.value
        cb null, @cache[params.key]

    set: (params, value) ->
        @cache[params.key] = {
            expires: Date.now() + params.ttl * 1000
            value
        }
