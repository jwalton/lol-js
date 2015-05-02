{EventEmitter} = require 'events'
querystring = require 'querystring'
ld = require 'lodash'
fs = require 'fs'
path = require 'path'
{Promise} = require 'es6-promise'
utils = require './utils'

RateLimiter = require './rateLimiter'

MAX_RETRIES_ON_RIOT_API_UNAVAILABLE = 10
TIME_TO_WAIT_FOR_RIOT_API_IN_MS = 100

ONE_MONTH_IN_SECONDS = 30 * 24 * 60 * 60

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
        @Promise = options.Promise ? Promise

        if !options.apiKey? then throw new Error 'apiKey is required.'
        @apiKey = options.apiKey
        @defaultRegion = options.defaultRegion ? 'na'
        @cacheTTL = ld.defaults {}, options.cacheTTL, {
            short: 60 * 5  # 5 minutes
            long:  ONE_MONTH_IN_SECONDS
            flex:  ONE_MONTH_IN_SECONDS
        }

        if options.cache?
            # Wrap the cache functions - we don't want exceptions from the cache to prevent us from
            # returning data.
            @cache = {
                get: (params) =>
                    return new @Promise (resolve, reject) =>
                        answer = options.cache.get params, (err, answer) =>
                            if err?
                                @_stats.errors++
                                @emit 'cacheGetError', err
                                return resolve null

                            if !answer?
                                @_stats.misses++
                            else
                                @_stats.hits++
                                if answer.cacheTime?
                                    resolve answer
                                else
                                    # Cache entry is from v1.3.3 or earlier
                                    if answer is 'none' then answer = null
                                    resolve {value: answer, cacheTime: 0, ttl: 0}

                            resolve answer

                set: (params, value) =>
                    try
                        cacheTime = Date.now()
                        ttl = params.ttl ? @cacheTTL.short
                        cacheValue = {value, cacheTime, ttl}

                        # If flexCache is enabled, cache for the maximum of the TTL or the
                        # flexCache TTL
                        if ttl < @cacheTTL.flex then ttl = @cacheTTL.flex
                        if !params.ttl? then params = ld.extend {}, params, {ttl}

                        options.cache.set params, cacheValue

                    catch err
                        @_stats.errors++
                        @emit 'cacheSetError', err

                destroy: -> options.cache.destroy?()

            }
        else
            @cache = {
                get: (params) => return new @Promise (resolve, reject) -> resolve null
                set: ->
                destroy: ->
            }

        rateLimitOptions = options.rateLimit ? [{time: 10, limit: 10}, {time: 600, limit: 500}]
        @_rateLimiter = new RateLimiter rateLimitOptions, @Promise

        # Queue of `{url, caller, resolve, reject, promise}` objects.
        @_queuedRequests = []
        @_processingRequests = false

        @_stats = {
            hits: 0
            misses: 0
            errors: 0
            rateLimitErrors: 0
            queueHighWaterMark: 0
            riotApiUnavailable: 0
        }
        @_request = require 'request'

    # Destroy this client.
    destroy: ->
        @cache.destroy()

    # Return cache statistics
    getStats: ->
        ld.merge {}, @_stats, {
            queueLength: @_queuedRequests.length
        }

    _sleepAsync: (durationInMs) ->
        return new @Promise (resolve, reject) ->
            setTimeout (-> resolve()), durationInMs

    # This sends a request to the Riot API, without queueing it.
    #
    # * `params.url` - The URL to fetch from.
    # * `params.caller` - The name of the public function making this request.
    # * `params.retries` - The number of times we have retried this request due to the Riot API
    #   being unavailable.
    # * `params.allowRetries` - If false, this will not retry when the Riot API is unavailable.
    #
    _doRequest: (params) ->
        params.retries ?= 0
        {url, caller, retries} = params
        allowRetries = params.allowRetries ? true


        return new @Promise (resolve, reject) =>
            @_request {uri: url, gzip: true}, (err, response, body) =>
                try
                    return reject err if err?

                    if response.statusCode is 429
                        # Hit rate limit.  Try again later.
                        @_stats.rateLimitErrors++

                        # Reset retries - retry forever on a rate limit error
                        params.retries = 0

                        return @_rateLimiter.wait()
                        .then => @_doRequest(params).then resolve, reject

                    else if response.statusCode is 404
                        return resolve null

                    else if response.statusCode is 503
                        @_riotApiUnavailable++
                        if allowRetries and retries < MAX_RETRIES_ON_RIOT_API_UNAVAILABLE
                            return @_sleepAsync TIME_TO_WAIT_FOR_RIOT_API_IN_MS
                            .then =>
                                # We probably don't need the rate limiter here... But,
                                # because we keep processing requests from the queue, we might
                                # end up with a whole bunch of requests queued up.  The rate limiter
                                # call here won't slow us down more than the sleep anyways.
                                return @_rateLimiter.wait()
                            .then =>
                                params.retries++
                                @_doRequest(params)
                                .then(resolve, reject)
                            .catch reject
                        else
                            err = new Error("Riot API is temporarily unavailable")
                            err.statusCode = response.statusCode
                            err.caller = caller
                            return reject err

                    else if response.statusCode isnt 200
                        err = new Error("Error calling #{params.caller}: #{response.statusCode}")
                        err.statusCode = response.statusCode
                        err.caller = caller
                        return reject err

                    else
                        return resolve JSON.parse(body)

                catch err
                    reject err

    # Starts the "background worker" which drains requests from the queue and sends them.
    _startRequestWorker: ->
        # If there's already a worker running, just return immediately.
        return if @_processingRequests

        @_processingRequests = true

        doWork = =>
            if @_queuedRequests.length is 0
                @_processingRequests = false
            else
                @_rateLimiter.wait().then =>
                    # Go process another request immediately - we don't want to wait for this
                    # request to finish, we just want to wait for the rate limiter.
                    #
                    # TODO: If the Riot API is unavailable, should we stop pulling stuff off
                    # the work queue here?  We could end up with a whole bunch of queries
                    # "in flight" at the same time.
                    #
                    setImmediate doWork

                    {url, caller, allowRetries, resolve, reject} = @_queuedRequests.shift()
                    @_doRequest({url, caller, allowRetries}).then(resolve, reject)

                .catch (err) ->
                    # This should never happen.
                    console.err "Fatal error in lol-js worker"
                    console.err err.stack ? err
                    process.exit(-1)

        setImmediate doWork

    # Make a request to the Riot API.
    #
    # This method will add the request to the request queue; requests in the queue will be
    # processed in the order they were submitted.
    #
    # Parameters:
    # * `params.region` - The region of the summoner.
    # * `params.url` - The URL used to fetch the data (without the query string.)
    # * `params.queryParams` - The query parameters to use to fetch the data (without the API key.)
    # * `params.caller` - The name of the public function making this request.
    # * `params.rateLimit` - If true (the default) then we will rate limit the request.
    #
    # Returns a promise.
    #
    _riotRequest: (params, haveCached) ->
        if params.queryParams
            # Sort the quereyParams so the URL will be the same for the same query.
            queryParams = ld(params.queryParams)
                .map (v,k) -> [k,v]
                .sortBy 0
                .zipObject()
                .value()
            queryString = querystring.stringify queryParams
        else
            queryString = null

        requestId = "#{params.url}?#{queryString ? ''}"
        url = "#{requestId}#{(if queryString? then '&' else '')}api_key=#{@apiKey}"

        caller = params.caller
        if !(params.rateLimit ? true)
            # Not rate limited - do this request immediately instead of adding it to the queue.
            answer = @_doRequest {url, caller, allowRetries: !haveCached}
        else if (existingRequest = ld.find @_queuedRequests, {requestId})?
            # We already have a request outstanding for this query - wait for it to come back.
            answer = existingRequest.promise
        else
            # Queue the request
            queueItem = {requestId, url, caller, allowRetries: !haveCached}
            answer = promise = new @Promise (resolve, reject) ->
                # Need `setImmediate` here so `promise` will be defined.
                queueItem.resolve = resolve
                queueItem.reject = reject
            queueItem.promise = promise
            @_queuedRequests.push queueItem
            @_stats.queueHighWaterMark = Math.max @_stats.queueHighWaterMark, @_queuedRequests.length
            @_startRequestWorker()

        return answer

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
    # * `options.preCache(value)` - If provided, this will be passed the raw value from
    #   `_riotRequest` before the value is cached.  This allows us to manipulate the data
    #   prior to caching.  Should return a new result via a promise.
    #
    # Returns a promise.
    _riotRequestWithCache: (params, cacheParams, options={}) ->
        @_validateCacheParams(cacheParams)

        cachedAnswer = null

        return @cache.get(cacheParams)
        .then (cachedAnswer) =>
            {value, cacheTime, ttl} = cachedAnswer ? {}

            # Check to see if the item has timed out
            ttl ?= 0
            expires = (cacheTime ? 0) + (ttl * 1000)

            # If we didn't get a result from the cache, go to Riot.
            if !cachedAnswer? or (expires < Date.now())
                answer = @_riotRequest(params, cachedAnswer?)
                .then (result) ->
                    # Do pre-caching
                    if options.preCache?
                        return options.preCache result
                    else
                        return result
                .then (result) =>
                    # Store the value in the cache
                    @cache.set cacheParams, result
                    return result

                .catch (err) ->
                    # If an error occurs fetching the value from riot, try to use the expired value
                    # from the cache.
                    if cachedAnswer?
                        return cachedAnswer.value
                    else
                        throw err
            else
                answer = cachedAnswer.value

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
    # Returns a promise which resolves to a map where keys are the `ids` passed in, and values are
    # either object returned from Riot or `null` if the objects can't be found.
    _riotMultiGet: (params, options) ->
        {caller, baseUrl, ids, urlSuffix, getCacheParamsFn, cacheResultFn, queryParams, maxObjs} = params
        region = options?.region ? @defaultRegion
        if !ld.isArray ids then ids = [ids]

        answer = {}

        # Try to fetch each object from the cache
        @Promise.all ids.map (id) =>
            new @Promise (resolve, reject) =>
                cacheParams = getCacheParamsFn this, region, id, options
                @_validateCacheParams(cacheParams)
                @cache.get(cacheParams)
                .then(
                    (object) -> resolve {id, cacheParams, object}
                    reject
                )
        .then (objects) =>
            missingObjects = []
            for {id, cacheParams, object} in objects
                if !object? or (object?.expires? and object.expires < Date.now())
                    missingObjects.push {id, cacheParams, cached: object}
                else
                    answer[id] = object.value

            if missingObjects.length is 0
                return answer
            else
                # If we couldn't find some objects, go fetch them from Riot
                # Divide up the objects we need to get into groups of `maxObjs` each.
                groups = for i in [0...Math.ceil(missingObjects.length/maxObjs)]
                    missingObjects.slice(i*maxObjs, i*maxObjs + maxObjs)

                return @Promise.all groups.map (group) =>
                    haveCached = ld.every group, (g) -> g.cached?
                    @_riotRequest({
                        caller: caller,
                        region: region,
                        url: "#{baseUrl}/#{ld.pluck(group, "id").join ","}#{urlSuffix ? ''}"
                        queryParams: queryParams
                    }, haveCached)
                    .then (fetchedObjects = {}) =>
                        for {id, cacheParams} in group
                            answer[id] = fetchedObjects[id] ? null

                            if answer[id]? and cacheResultsFn?
                                cacheResultFn this, region, answer[id], options
                            else
                                @cache.set cacheParams, answer[id]
                        return null
                    .catch (err) ->
                        # If we have an error fetching data from Riot, and we have expired
                        # cached values for everything we were trying to fetch, then use
                        # the expired data from the cache.
                        for {id, cached} in group
                            if !cached? then throw err
                            answer[id] = cached.value

                        return null

        .then ->
            answer

    _makeUrl: (region, api) -> "https://#{region}.api.pvp.net/api/lol/#{region}/#{api.version}/#{api.name}"

# Copy methods from the various API implementations to Client.
do ->
    for moduleFile in fs.readdirSync(path.join(__dirname, "api"))
        moduleName = path.basename(moduleFile, path.extname(moduleFile))
        api = require "./api/#{moduleName}"
        ld.extend Client::, api.methods
    utils.depromisifyAll Client::, {isPrototype: true}
