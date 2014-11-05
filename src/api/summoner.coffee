ld = require 'lodash'
{promiseToCb} = require '../utils'

api = exports.api = {
    fullname: "summoner-v1.4",
    name: "summoner",
    version: "v1.4"
}

MAX_SUMMONER_NAMES_PER_REQUEST = 40
MAX_SUMMONER_IDS_PER_REQUEST = 40

exports.methods = {
    # Get one or more summoners by name.
    #
    # Parameters:
    # * `summonerNames` - An array of summoner names.  Note the Riot API only allows you to
    #   pass 40 summoner names in a single request; you can pass more than 40 here, but it will
    #   result in multiple requests.
    # * `options.region` - The region of the summoner.  Defaults to the `defaultRegion` passed
    #   to the construtor.
    #
    # Returns a hash where keys are summoner names and values are
    # `{id, name, profileIconId, revsionData, summonerLevel}` objects.  If a given summoner name
    # is not found, it will be returned as `null` in the results.
    getSummonersByNameAsync: (summonerNames, options={}) ->
        region = options.region ? @defaultRegion
        @_riotMultiGet(
            {
                caller: "getSummonersByName",
                baseUrl: "#{@_makeUrl region, api}/by-name",
                ids: summonerNames,
                getCacheParamsFn: summonerByNameCacheParams,
                cacheResultFn: cacheSummoner,
                maxObjs: MAX_SUMMONER_NAMES_PER_REQUEST
            }, options)

    # Get one or more summoners by ID.
    #
    # Parameters:
    # * `summonerIds` - An array of summoner IDs.
    # * `options.region` - The region of the summoner.  Defaults to the `defaultRegion` passed
    #   to the construtor.
    #
    # Returns a hash where keys are summoner IDs and values are
    # `{id, name, profileIconId, revsionData, summonerLevel}` objects.  If a given summoner ID
    # is not found, it will be returned as `null` in the results.
    getSummonersByIdAsync: (summonerIds, options={}) ->
        region = options.region ? @defaultRegion
        @_riotMultiGet(
            {
                caller: "getSummonersById",
                baseUrl: @_makeUrl(region, api)
                ids: summonerIds,
                getCacheParamsFn: summonerByIdCacheParams('summoner'),
                maxObjs: MAX_SUMMONER_NAMES_PER_REQUEST
            }, options)

    # Get the names for one or more summonerIds.
    #
    # Note that the current implementation doesn't go through the summoner name API - instead it
    # fetches full summoner records and then maps them.  This increases the likelyhood that we'll
    # find the appropriate records in the cache.
    #
    getSummonerNamesAsync: (summonerIds, options={}) ->
        @getSummonersByIdAsync summonerIds, options
        .then (summoners) ->
            return ld.mapValues summoners, (x) -> x?.name ? null

    # Get one or more summoner's masteries.
    #
    # Parameters:
    # * `summonerIds` - An array of summoner IDs.
    # * `options.region` - The region of the summoner.  Defaults to the `defaultRegion` passed
    #   to the construtor.
    #
    # Returns a hash where keys are summoner IDs and values are `{pages, summonerId}` objects.  If
    # a given summoner ID is not found, the value will be `null` in the results.
    getSummonerMasteriesAsync: (summonerIds, options={}) ->
        region = options.region ? @defaultRegion
        @_riotMultiGet(
            {
                caller: "getSummonerMasteries",
                baseUrl: @_makeUrl(region, api)
                ids: summonerIds,
                urlSuffix: "/masteries",
                getCacheParamsFn: summonerByIdCacheParams('masteries'),
                maxObjs: MAX_SUMMONER_NAMES_PER_REQUEST
            }, options)

    # Get one or more summoner's runes.
    #
    # Parameters:
    # * `summonerIds` - An array of summoner IDs.
    # * `options.region` - The region of the summoner.  Defaults to the `defaultRegion` passed
    #   to the construtor.
    #
    # Returns a hash where keys are summoner IDs and values are `{pages, summonerId}` objects.  If
    # a given summoner ID is not found, the value will be `null` in the results.
    getSummonerRunesAsync: (summonerIds, options={}) ->
        region = options.region ? @defaultRegion
        @_riotMultiGet(
            {
                caller: "getSummonerRunes",
                baseUrl: @_makeUrl(region, api)
                ids: summonerIds,
                urlSuffix: "/runes",
                getCacheParamsFn: summonerByIdCacheParams('runes'),
                maxObjs: MAX_SUMMONER_NAMES_PER_REQUEST
            }, options)
}


cacheSummoner = (client, region, summoner) ->
    client.cache.set summonerByIdCacheParams(this, region, summoner.id), summoner
    client.cache.set summonerByNameCacheParams(this, region, summoner.name), summoner

summonerByNameCacheParams = (client, region, summonerName) -> {
        key: "#{api.fullname}-summonerByName-#{region}-#{summonerName.toLowerCase()}"
        api, region,
        objectType: 'summonerByName'
        params: {summonerName: summonerName.toLowerCase()}
    }

summonerByIdCacheParams = (objectType) -> (client, region, summonerId) -> {
        key: "#{api.fullname}-#{objectType}-#{region}-#{summonerId}"
        api, region,
        objectType: objectType
        params: {summonerId}
    }
