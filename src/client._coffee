{EventEmitter} = require 'events'
querystring = require 'querystring'
ld = require 'lodash'

RateLimiter = require './rateLimiter'

# Emits the following events:
# * `hitRateLimit` if the client receives a rate limit error from the server.  This shouldn't
#   happen, but this is here so we can monitor and make sure it doesn't.  :)
#
module.exports = class Client extends EventEmitter

    # Options:
    # * `apiKey` - the API key [assigned to you by Riot](https://developer.riotgames.com/).
    # * `defaultRegion` - the region to use for queries if none is specified.  Defaults to 'na'.
    # * `cache` - a cache object or `null` to disable caching (see below).
    # * `rateLimit` - a list of limit objects.  Each limit object is a `{time, limit}` pair where
    #   `time` is a duration in seconds and `limit` is the maximum number of requests to make in
    #   that duration.  Defaults to `[{time: 10, limit: 10}, {time: 600, limit: 500}]`.
    #
    constructor: (options={}) ->
        if !options.apiKey? then throw new Error 'apiKey is required.'
        @apiKey = options.apiKey
        @defaultRegion = options.defaultRegion ? 'na'
        @cacheTTL = options.cacheTTL ? {
            short: 60 * 5            # 5 minutes
            long:  60 * 60 * 24 * 31 # 31 days
        }

        if options.cache?
            # Wrap the cache functions - we don't want exceptions from the cache to prevent us from
            # returning data.
            @cache = {
                get: (params, _) =>
                    try
                        answer = options.cache.get(params, _)
                        if answer? then @_cacheHits++ else @_cacheMisses++
                        return answer
                    catch err
                        @emit 'cacheGetError', err
                        return null
                set: (params, value) =>
                    try
                        options.cache.set(params, value)
                    catch err
                        @emit 'cacheSetError', err

            }
        else
            @cache = {
                get: (params, done) -> done null, null
                set: ->
            }

        @_rateLimiter = new RateLimiter options.rateLimit ? [{time: 10, limit: 10}, {time: 600, limit: 500}]
        @_queuedRequests = []
        @_cacheHits = 0
        @_cacheMisses = 0
        @_request = require 'request'

    # Return cache statistics
    getCacheStats: -> {hits: @_cacheHits, misses: @_cacheMisses}

    # Make a request to the Riot API.
    #
    # Parameters:
    # * `params.region` - The region of the summoner.
    # * `params.url` - The URL used to fetch the data (without the query string.)
    # * `params.queryParams` - The query parameters to use to fetch the data (without the API key.)
    # * `params.rateLimit` - If true (the default) then we will rate limit the request.
    #
    _riotRequest: (params, _) ->
        if params.rateLimit ? true then @_rateLimiter.wait _

        queryString = querystring.stringify params.queryParams
        queryString = if queryString then "&#{queryString}" else ""
        url = "#{params.url}?api_key=#{@apiKey}#{queryString}"

        [response, body] = @_request url, [_]
        if response.statusCode is 429
            # Hit rate limit.  Try again later.
            answer = @_riotRequest params, _
        else if response.statusCode is 404
            answer = null
        else if response.statusCode isnt 200
            throw new Error("Error retrieving data: #{response.statusCode}")
        else
            answer = JSON.parse body

        return answer

    # Make a request to the Riot API, but automatically check the cache for results first and
    # store results in the cache.
    #
    # * `params` is identical to `params` from `_riotRequest()`.
    # * `cacheParams` is a `{key, ttl, api, objectType, region, params}` object, as decsribed
    #   in the README.md file in the cache section.
    _riotRequestWithCache: (params, cacheParams, _) ->
        # cacheParams can be passed to third party cache providers, so it's important we
        # provide a consistent interface.  Therefore, blow up here if we're missing
        # any cache parameters.
        for key in ['key', 'api', 'objectType', 'region', 'params']
            if !(key of cacheParams) then throw new Error "Missing #{key} in cacheParams."
        cacheParams.ttl ?= @cacheTTL.short

        answer = @cache.get cacheParams, _
        if answer?
            @_cacheHits++
            if answer is "none" then answer = null
        else
            @_cacheMisses++
            answer = @_riotRequest params, _
            @cache.set cacheParams, answer ? "none"

        return answer

    # Many riot API methods take a comma delimited list of IDs as a parameter, and return
    # a map where keys are the IDs and values are the return values.  This is a function
    # which automates this.
    #
    # Parameters:
    # * `baseUrl` the base URL to fetch from.
    # * `ids` the list of IDs to pass.
    # * `getCacheParamsFn(region, id, options)` - Called to get cache params for an id.
    # * `cacheResultFn(region, result, options)` - Called to write a single result to the cache.
    #   If null, then result of `getCacheParamsFn()` will be used.
    # * `queryParams` is query params to pass to the Riot API.
    # * `options.region` is used to determine the region.  `options` is also passed on to the
    #   `getCacheParamsFn` and `cacheResultFn`.
    #
    # Returns a map where keys are the `ids` passed in, and values are either object returned
    # from Riot or `null` if the objects can't be found.
    _riotMultiGet: (baseUrl, ids, urlSuffix, getCacheParamsFn, cacheResultFn, queryParams, options, _) ->
        region = options?.region ? @defaultRegion
        if !ld.isArray ids then ids = [ids]

        answer = {}
        missingObjects = []

        # Try to fetch each object from the cache
        for id in ids
            cacheParams = getCacheParamsFn region, id, options
            object = @cache.get cacheParams, _
            if object is "none"
                answer[id] = null
            else if object?
                answer[id] = object
            else
                missingObjects.push {id, cacheParams}

        # If we couldn't find some objects, go fetch them from Riot
        if missingObjects.length > 0
            fetchedObjects = @_riotRequest {
                region: region,
                url: "#{baseUrl}/#{ld.pluck(missingObjects, "id").join ","}#{urlSuffix}"
                queryParams: queryParams
            }, _
            fetchedObjects ?= {}
            for {id, cacheParams} in missingObjects
                # Note that Riot always returns summoner name keys as all lower case.
                fetchedId = if ld.isString(id) then id.toLowerCase() else id
                answer[id] = fetchedObjects[fetchedId] ? null

                if answer[id]? and cacheResultsFn?
                    cacheResultFn region, answer[id], options
                else
                    @cache.set cacheParams, (answer[id] ? "none")

        return answer

    _makeUrl: (region, api) -> "https://#{region}.api.pvp.net/api/lol/#{region}/#{api.version}/#{api.name}"

# Copy methods from the various API implementations to Client.
apis = [
    require('./api/lolStaticData')
    require('./api/match')
    require('./api/summoner')
]
for api in apis
    ld.extend Client::, api.methods
