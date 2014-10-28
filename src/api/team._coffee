assert  = require 'assert'
ld      = require 'lodash'
async   = require 'async'
{optCb} = require '../utils'
matchApi = require './match'

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
    getTeamsBySummoner: optCb (summonerIds, options, _) ->
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
            }, options, _)

    # Gets recent games for this given summoner.
    #
    # Parameters:
    # * `teamIds` - One or more team IDs to retrieve.
    # * `options.region` - The region of the team.
    #
    # Returns a hash of lists of TeamDTO objects, indexed by teamId.
    #
    getTeams: optCb (teamIds, options, _) ->
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
            }, options, _)

}
