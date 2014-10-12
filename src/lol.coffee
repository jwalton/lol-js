Client = require './client'

exports.client = (options) -> new Client(options)
exports.inMemoryCache = ->
    InMemoryCache = require('./cache/inMemoryCache')
    return new InMemoryCache()
exports.redisCache = ->
    RedisCache = require('./cache/redisCache')
    return new RedisCache()
