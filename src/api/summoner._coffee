ld = require 'lodash'
{optCb} = require '../utils'

api = exports.api = {
    fullname: "summoner-v1.4",
    name: "summoner",
    version: "v1.4"
}

exports.methods = {
    # Get one or more summoners by name.
    #
    # Parameters:
    # * `summonerNames` - An array of summoner names.
    # * `options.region` - The region of the summoner.  Defaults to the `defaultRegion` passed
    #   to the construtor.
    #
    # Returns a hash where keys are summoner names and values are
    # `{id, name, profileIconId, revsionData, summonerLevel}` objects.  If a given summoner name
    # is not found, it will be returned as `null` in the results.
    getSummonersByName: optCb 3, (summonerNames, options, _) ->
        region = options.region ? @defaultRegion
        @_riotMultiGet("getSummonersByName",
            "#{@_makeUrl region, api}/by-name", summonerNames, "",
            summonerByNameCacheParams,
            cacheSummoner,
            null, options, _
        )

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
    getSummonersById: optCb 3, (summonerIds, options, _) ->
        region = options.region ? @defaultRegion
        @_riotMultiGet("getSummonersById",
            "#{@_makeUrl region, api}", summonerIds, "",
            summonerByIdCacheParams('summoner'),
            null, null, options, _
        )

    # Get the names for one or more summonerIds.
    #
    # Note that the current implementation doesn't go through the summoner name API - instead it
    # fetches full summoner records and then maps them.  This increases the likelyhood that we'll
    # find the appropriate records in the cache.
    #
    getSummonerNames: optCb 3, (summonerIds, options, _) ->
        summoners = @getSummonersById summonerIds, options, _
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
    getSummonerMasteries: optCb 3, (summonerIds, options, _) ->
        region = options.region ? @defaultRegion
        @_riotMultiGet("getSummonerMasteries",
            "#{@_makeUrl region, api}", summonerIds, "/masteries",
            summonerByIdCacheParams('masteries'),
            null, null, options, _
        )

    # Get one or more summoner's runes.
    #
    # Parameters:
    # * `summonerIds` - An array of summoner IDs.
    # * `options.region` - The region of the summoner.  Defaults to the `defaultRegion` passed
    #   to the construtor.
    #
    # Returns a hash where keys are summoner IDs and values are `{pages, summonerId}` objects.  If
    # a given summoner ID is not found, the value will be `null` in the results.
    getSummonerRunes: optCb 3, (summonerIds, options, _) ->
        region = options.region ? @defaultRegion
        @_riotMultiGet("getSummonerRunes",
            "#{@_makeUrl region, api}", summonerIds, "/runes",
            summonerByIdCacheParams('runes'),
            null, null, options, _
        )
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
