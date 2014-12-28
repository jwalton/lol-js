ld            = require 'lodash'
{promiseToCb} = require '../utils'

api = exports.api = {
    fullname: "matchhistory-v2.2",
    name: "matchhistory",
    version: "v2.2"
}

exports.methods = {
    # Retrieve match history for a summoner.
    #
    # Parameters:
    # * `summonerId` - The ID of the summoner.
    # * `options.region` - The region of the summoner.  Defaults to the `defaultRegion` passed
    #   to the construtor.
    # * `options.championIds` - Comma-separated list of champion IDs to use for fetching games.
    # * `options.rankedQueues` - Comma-separated list of ranked queue types to use for fetching
    #   games. Non-ranked queue types will be ignored.
    # * `options.beginIndex` - The begin index to use for fetching games.
    # * `options.endIndex` - The end index to use for fetching games.
    #
    # The maximum range for begin and end index is 15. If the range is more than 15, the end index
    # will be modified to enforce the 15 game limit. If only one of the index parameters is
    # specified, the other will be computed accordingly.
    #
    # `beginIndex` is inclusive, and `endIndex` is exclusive (so `{beginIndex: 0, endIndex: 2}`
    # will return at most 2 results.)
    #
    # Note that right now match histories are NOT cached - to be fixed in a future release.
    #
    # Returns a promise.
    getMatchHistoryForSummonerAsync: (summonerId, options={}) ->
        options = ld.defaults {}, options, {
            region: @defaultRegion
            championIds: null
            rankedQueues: ['RANKED_SOLO_5x5', 'RANKED_TEAM_3x3', 'RANKED_TEAM_5x5']
            beginIndex: 0
            endIndex: 15
        }
        region = options.region ? @defaultRegion

        queryParams = {
            championIds: options.championIds
            rankedQueues: (options.rankedQueues or []).join(",")
            beginIndex: options.beginIndex
            endIndex: options.endIndex
        }

        requestParams = {
            caller: "getMatchHistoryForSummoner",
            region: region,
            url: "#{@_makeUrl region, api}/#{summonerId}",
            queryParams
        }

        toCacheParam = (arr) -> arr?.sort().join(',')

        cacheParams = {
            key: "#{api.fullname}-matchhistory-#{region}-#{summonerId}-" +
                "#{toCacheParam options.championIds}-#{toCacheParam options.rankedQueues}-#{options.beginIndex}-#{options.endIndex}"
            region, api,
            ttl: @cacheTTL.short
            objectType: 'matchhistory'
            params: ld.merge({summonerId}, queryParams, {rankedQueues: options.rankedQueues or []})
        }


        @_riotRequestWithCache requestParams, cacheParams
}
