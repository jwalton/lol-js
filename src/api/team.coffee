assert  = require 'assert'
ld      = require 'lodash'
async   = require 'async'
matchApi = require './match'
{promiseToCb} = require '../utils'

api = exports.api = {
    fullname: "team-v2.4",
    name: "team",
    version: "v2.4"
}

exports.methods = {

    # Gets recent games for this given summoner.
    #
    # Parameters:
    # * `summonerIds` - One or more summoner IDs to retrieve teams for.
    # * `options.region` - The region of the summoner.
    #
    # Returns a hash of lists of TeamDTO objects, indexed by summonerId.
    #
    getTeamsBySummonerAsync: (summonerIds, options={}) ->
        # TODO: cache each team by teamId here?
        region = options.region ? @defaultRegion
        @_riotMultiGet(
            {
                caller: "getTeamsBySummoner",
                baseUrl: "#{@_makeUrl region, api}/by-summoner",
                ids: summonerIds,
                getCacheParamsFn: ((client, region, summonerId) -> {
                    key: "#{api.fullname}-teamsForSummonerId-#{region}-#{summonerId}"
                    api, region,
                    objectType: 'teamsForSummonerId'
                    params: {summonerId}
                }),
                maxObjs: 10
            }, options)

    # Gets recent games for this given summoner.
    #
    # Parameters:
    # * `teamIds` - One or more team IDs to retrieve.
    # * `options.region` - The region of the team.
    #
    # Returns a hash of lists of TeamDTO objects, indexed by teamId.
    #
    getTeamsAsync: (teamIds, options={}) ->
        region = options.region ? @defaultRegion
        @_riotMultiGet(
            {
                caller: "getTeams",
                baseUrl: "#{@_makeUrl region, api}",
                ids: teamIds,
                getCacheParamsFn: ((client, region, teamId) -> {
                    key: "#{api.fullname}-team-#{region}-#{teamId}"
                    api, region,
                    objectType: 'team'
                    params: {teamId}
                }),
                maxObjs: 10
            }, options)

    # Get record for a single team.
    #
    # This is a convenience wrapper around getTeams which takes a single `teamId`, and returns the
    # team associated with it.
    #
    getTeamAsync: (teamId, options={}) ->
        @getTeamsAsync teamId, options
        .then (answer) -> return answer?[teamId]
}
