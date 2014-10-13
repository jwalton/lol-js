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

    get: (params, _) ->
        answer = @client.get "#{@keyPrefix}-#{params.key}", _
        return JSON.parse answer

    set: (params, value) ->
        key = "#{@keyPrefix}-#{params.key}"
        @client.set key, JSON.stringify(value)
        @client.expire key, params.ttl

    destroy: ->
        @client.quit()
