ld = require 'lodash'
redis = require 'redis'

module.exports = class RedisCache
    constructor: (options) ->
        options = ld.defaults {}, options, {
            host: '127.0.0.1'
            port: 6379
            keyPrefix: 'loljs-'
        }
        @keyPrefix = options.keyPrefix

        @client = redis.createClient(options.port, options.host)

    get: (params, done) ->
        @client.get "#{@keyPrefix}-#{params.key}", (err, answer) ->
            return done err if err?
            answer = JSON.parse answer
            done null, answer

    set: (params, value) ->
        key = "#{@keyPrefix}-#{params.key}"
        @client.set key, JSON.stringify(value)
        if params.ttl? then @client.expire key, params.ttl

    destroy: ->
        @client.quit()
