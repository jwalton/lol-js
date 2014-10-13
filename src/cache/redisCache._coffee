ld = require 'lodash'
redis = require 'redis'

module.exports = class RedisCache
    constructor: (options) ->
        options = ld.defaults {}, options, {
            host: '127.0.0.1'
            port: 6379
            keyPrefix: 'loljs-'
        }

        @client = redis.createClient(options.port, options.host)

    get: (params, _) ->
        answer = @client.get params.key, _
        return JSON.parse answer

    set: (params, value) ->
        @client.set params.key, JSON.stringify(value)
        @client.expire params.key, params.ttl

    destroy: ->
        @client.quit()
