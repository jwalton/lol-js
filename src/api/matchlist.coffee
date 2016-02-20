ld            = require 'lodash'
pb            = require 'promise-breaker'
{arrayToList, paramsToCacheKey} = require '../utils'

api = exports.api = {
    fullname: "matchlist-v2.2",
    name: "matchlist",
    version: "v2.2"
}

exports.methods = {
    # Retrieve match history for a summoner.
    #
    # Parameters:
    # * `region` - The region of the summoner.
    # * `summonerId` - The ID of the summoner.
    # * `options.championIds` - Array of championIds to use for fetching games.
    # * `options.rankedQueues` - Array of ranked queue types to use for fetching
    #   games. Non-ranked queue types will be ignored.
    # * `options.seasons` - Array of seasons to use for fetching games.
    # * `options.beginIndex` - The begin index to use for fetching games.
    # * `options.endIndex` - The end index to use for fetching games.
    # * `options.beginTime` - The begin time to use for fetching games.  This can be a Date or a value in
    #   milliseconds since the epoch.
    # * `options.endTime` - The end time to use for fetching games.
    #
    # Returns a promise.
    #
    getMatchlistBySummoner: pb.break (region, summonerId, options={}) ->
        queryParams = {
            championIds:  arrayToList options.championIds
            rankedQueues: arrayToList(options.rankedQueues ?
                ['RANKED_SOLO_5x5', 'RANKED_TEAM_3x3', 'RANKED_TEAM_5x5', 'TEAM_BUILDER_DRAFT_RANKED_5x5'])
            seasons:      arrayToList options.seasons
            beginIndex:   options.beginIndex
            endIndex:     options.endIndex
            beginTime:    options.beginTime?.valueOf()
            endTime:      options.endTime?.valueOf()
        }

        requestParams = {
            caller: "getMatchListForSummoner",
            region: region,
            url: "#{@_makeUrl region, api}/by-summoner/#{summonerId}",
            queryParams
        }

        toCacheParam = (arr) -> arr?.sort().join(',')

        cacheParams = {
            key: "#{api.fullname}-matchlist-#{region}-#{summonerId}-" + paramsToCacheKey(queryParams)
            region, api,
            ttl: @cacheTTL.short
            objectType: 'matchhistory'
            params: ld.merge({summonerId}, queryParams)
        }

        @_riotRequestWithCache requestParams, cacheParams
}
