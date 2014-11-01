{EventEmitter} = require 'events'
querystring = require 'querystring'
ld = require 'lodash'
fs = require 'fs'
path = require 'path'
async = require 'async'

RateLimiter = require './rateLimiter'

# Emits the following events:
# * `hitRateLimit` if the client receives a rate limit error from the server.  This shouldn't
#   happen, but this is here so we can monitor and make sure it doesn't.  :)
#
module.exports = class Client extends EventEmitter
    constants: require './constants'

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
            short: 60 * 5  # 5 minutes
            long:  null    # Forever
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
                        @_cacheErrors++
                        @emit 'cacheGetError', err
                        return null
                set: (params, value) =>
                    try
                        options.cache.set(params, value)
                    catch err
                        @_cacheErrors++
                        @emit 'cacheSetError', err
                destroy: -> options.cache.destroy?()

            }
        else
            @cache = {
                get: (params, done) -> done null, null
                set: ->
                destroy: ->
            }

        @_rateLimiter = new RateLimiter options.rateLimit ? [{time: 10, limit: 10}, {time: 600, limit: 500}]
        @_queuedRequests = []
        @_processingRequests = false

        @_cacheHits = 0
        @_cacheMisses = 0
        @_cacheErrors = 0
        @_hitRateLimit = 0
        @_queueHighWaterMark = 0
        @_request = require 'request'

    # Destroy this client.
    destroy: ->
        @cache.destroy()

    # Return cache statistics
    getStats: -> {
        hits: @_cacheHits,
        misses: @_cacheMisses
        errors: @_cacheErrors
        rateLimitErrors: @_hitRateLimit
        queueLength: @_queuedRequests.length
        queueHighWaterMark: @_queueHighWaterMark
    }

    # This sends a request to the Riot API, without queueing it.
    _doRequest: (params, _) ->
        queryString = querystring.stringify params.queryParams
        queryString = if queryString then "&#{queryString}" else ""
        url = "#{params.url}?api_key=#{@apiKey}#{queryString}"

        [response, body] = @_request url, [_]
        if response.statusCode is 429
            # Hit rate limit.  Try again later.
            @_hitRateLimit++
            @_rateLimiter.wait _
            answer = @_doRequest params, _
        else if response.statusCode is 404
            answer = null
        else if response.statusCode isnt 200
            throw new Error("Error calling #{params.caller}: #{response.statusCode}")
        else
            # console.log "Requested #{url}"
            answer = JSON.parse body

        return answer

    # Starts the "background worker" which drains requests from the queue and sends them.
    _startRequestWorker: ->
        # If there's already a worker running, just return immediately.
        return if @_processingRequests

        @_processingRequests = true

        doWork = =>
            if @_queuedRequests.length is 0
                @_processingRequests = false
            else
                @_rateLimiter.wait =>
                    # Go process another request immediately - we don't want to wait for this
                    # request to finish, we just want to wait for the rate limiter.
                    setImmediate doWork

                    {params, done} = @_queuedRequests.shift()
                    @_doRequest params, done

        doWork()

    # Make a request to the Riot API.
    #
    # This method will add the request to the request queue; requests in the queue will be
    # processed in the order they were submitted.
    #
    # Parameters:
    # * `params.region` - The region of the summoner.
    # * `params.url` - The URL used to fetch the data (without the query string.)
    # * `params.queryParams` - The query parameters to use to fetch the data (without the API key.)
    # * `params.rateLimit` - If true (the default) then we will rate limit the request.
    #
    _riotRequest: (params, done) ->
        if !(params.rateLimit ? true)
            # Not rate limited - do this request immediately instead of adding it to the queue.
            @_doRequest params, done
        else
            # Queue the request
            # TODO: If I make the same request multiple times, I could find the existing request and
            # just add another callback to it.
            @_queuedRequests.push {params, done}
            @_queueHighWaterMark = Math.max @_queueHighWaterMark, @_queuedRequests.length
            @_startRequestWorker()

    _validateCacheParams: (cacheParams) ->
        # cacheParams can be passed to third party cache providers, so it's important we
        # provide a consistent interface.  Therefore, blow up here if we're missing
        # any cache parameters.
        for key in ['key', 'api', 'objectType', 'region', 'params']
            if !(key of cacheParams) then throw new Error "Missing #{key} in cacheParams."
        if not 'ttl' of cacheParams
            cacheParams.ttl ?= @cacheTTL.short

    # Make a request to the Riot API, but automatically check the cache for results first and
    # store results in the cache.
    #
    # * `params` is identical to `params` from `_riotRequest()`.
    # * `cacheParams` is a `{key, ttl, api, objectType, region, params}` object, as decsribed
    #   in the README.md file in the cache section.
    # * `options.preCache(value, cb)` - If provided, this will be passed the raw value from
    #   `_riotRequest` before the value is cached.  This allows us to manipulate the data
    #   prior to caching.
    #
    _riotRequestWithCache: (params, cacheParams, options, _) ->
        @_validateCacheParams(cacheParams)
        answer = @cache.get cacheParams, _
        if answer?
            if answer is "none" then answer = null
        else
            answer = @_riotRequest params, _
            if options.preCache? then options.preCache answer, _
            @cache.set cacheParams, answer ? "none"

        return answer

    # Many riot API methods take a comma delimited list of IDs as a parameter, and return
    # a map where keys are the IDs and values are the return values.  This is a function
    # which automates this.
    #
    # Parameters:
    # * `params.caller` is the name of the public client function calling _riotMultiGet.
    # * `params.baseUrl` the base URL to fetch from.
    # * `params.ids` the list of IDs to pass.  These are appended to the baseUrl as a list of comma
    #   seperated strings.
    # * `params.urlSuffix` is appended to the baseUrl after the comma separated list of IDs.
    # * `params.getCacheParamsFn(client, region, id, options)` - Called to get cache params for an
    #   id.
    # * `params.cacheResultFn(client, region, result, options)` - Called to write a single result
    #   to the cache.  If null, then result of `getCacheParamsFn()` will be used.
    # * `params.queryParams` is queryParams to pass to _riotRequest().
    # * `params.maxObjs` is the maximum number of ids to pull in a single request.
    # * `options.region` is used to determine the region.  `options` is also passed on to the
    #   `getCacheParamsFn` and `cacheResultFn`.
    #
    # Returns a map where keys are the `ids` passed in, and values are either object returned
    # from Riot or `null` if the objects can't be found.
    _riotMultiGet: (params, options, _) ->
        {caller, baseUrl, ids, urlSuffix, getCacheParamsFn, cacheResultFn, queryParams, maxObjs} = params
        region = options?.region ? @defaultRegion
        if !ld.isArray ids then ids = [ids]

        answer = {}
        missingObjects = []

        # Try to fetch each object from the cache
        for id in ids
            cacheParams = getCacheParamsFn this, region, id, options
            @_validateCacheParams(cacheParams)
            object = @cache.get cacheParams, _
            if object is "none"
                answer[id] = null
            else if object?
                answer[id] = object
            else
                missingObjects.push {id, cacheParams}

        # If we couldn't find some objects, go fetch them from Riot
        if missingObjects.length > 0
            # Divide up the objects we need to get into groups of `maxObjs` each.
            groups = for i in [0...Math.ceil(missingObjects.length/maxObjs)]
                missingObjects.slice(i*maxObjs, i*maxObjs + maxObjs)

            async.each groups, ( (group, _) =>
                fetchedObjects = @_riotRequest {
                    caller: caller,
                    region: region,
                    url: "#{baseUrl}/#{ld.pluck(group, "id").join ","}#{urlSuffix ? ''}"
                    queryParams: queryParams
                }, _
                fetchedObjects ?= {}
                for {id, cacheParams} in group
                    # Note that Riot always returns summoner name keys as all lower case.
                    fetchedId = if ld.isString(id) then id.toLowerCase() else id
                    answer[id] = fetchedObjects[id] ? fetchedObjects[fetchedId] ? null

                    if answer[id]? and cacheResultsFn?
                        cacheResultFn this, region, answer[id], options
                    else
                        @cache.set cacheParams, (answer[id] ? "none")
            ), _

        return answer

    _makeUrl: (region, api) -> "https://#{region}.api.pvp.net/api/lol/#{region}/#{api.version}/#{api.name}"

# Copy methods from the various API implementations to Client.
do ->
    for moduleFile in fs.readdirSync(path.join(__dirname, "api"))
        moduleName = path.basename(moduleFile, path.extname(moduleFile))
        api = require "./api/#{moduleName}"
        ld.extend Client::, api.methods
