assert  = require 'assert'
ld      = require 'lodash'
pb      = require 'promise-breaker'
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
    # * `region` - The region of the summoner.
    # * `summonerIds` - One or more summoner IDs to retrieve teams for.
    #
    # Returns a hash of lists of TeamDTO objects, indexed by summonerId.
    #
    getTeamsBySummoner: pb.break (region, summonerIds) ->
        # TODO: cache each team by teamId here?
        @_riotMultiGet(
            region,
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
            }
        )

    # Gets recent games for this given summoner.
    #
    # Parameters:
    # * `region` - The region of the team.
    # * `teamIds` - One or more team IDs to retrieve.
    #
    # Returns a hash of lists of TeamDTO objects, indexed by teamId.
    #
    getTeams: pb.break (region, teamIds) ->
        @_riotMultiGet(
            region,
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
            }
        )

    # Get record for a single team.
    #
    # This is a convenience wrapper around getTeams which takes a single `teamId`, and returns the
    # team associated with it.
    #
    getTeam: pb.break (region, teamId) ->
        @getTeams region, [teamId]
        .then (answer) -> return answer?[teamId]
}
