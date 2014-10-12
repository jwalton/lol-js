ld = require 'lodash'
{optCb} = require '../utils'

api = exports.api = {
    fullname: "match-v2.2",
    name: "match",
    version: "v2.2"
}

exports.methods = {
    # Retrieve a match.
    #
    # Parameters:
    # * `matchId` - The ID of the match.
    # * `options.region` - The region of the summoner.  Defaults to the `defaultRegion` passed
    #   to the construtor.
    # * `options.includeTimeline` - Flag indicating whether or not to include match timeline data.
    #   Defaults to `true`.
    #
    getMatch: optCb 3, (matchId, options, done) ->
        options = ld.defaults {}, options, {
            region: @defaultRegion
            includeTimeline: false
        }
        region = options.region ? @defaultRegion

        requestParams = {
            region: region,
            url: "#{@_makeUrl region, api}/#{matchId}",
            queryParams: {includeTimeline: options.includeTimeline}
        }
        cacheParams = {
            key: "#{api.fullname}-match-#{region}-#{matchId}-#{options.includeTimeline}"
            region, api,
            ttl: @cacheTTL.long
            objectType: 'match'
            params: {matchId, includeTimeline: options.includeTimeline}
        }
        @_riotRequestWithCache requestParams, cacheParams, done
}
