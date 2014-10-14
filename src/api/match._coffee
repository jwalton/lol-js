assert           = require 'assert'
ld               = require 'lodash'
summonerApi      = require './summoner'
lolStaticDataApi = require './lolStaticData'
{optCb}          = require '../utils'

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
    # * `options.players` - same as the `players` parameter to `populateMatch()`.  If `players`
    #   is passed here, then the populated version of the match will be stored in the cache,
    #   preventing the need to re-populate it later.
    #
    getMatch: optCb (matchId, options, _) ->
        options = ld.defaults {}, options, {
            region: @defaultRegion
            includeTimeline: false
        }
        region = options.region ? @defaultRegion

        requestParams = {
            caller: "getMatch",
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
        requestOptions = {}
        if options.players?
            requestOptions.preCache = (match, _) => @populateMatch match, options.players, options, _

        @_riotRequestWithCache requestParams, cacheParams, requestOptions, _

    # When non-ranked matches are fetched via the `getMatch()`, they have empty
    # `participantIdentities`.  In other words, you don't know which summoners are playing which
    # champions.  If you have this information through some other means (for example, you fetch
    # a game using `getRecentGamesForSummoner()`) then you can use this function to fill in
    # the `participantIdentities` field.
    #
    # Note that the `matchHistoryUri` is not populated in `participantIdentities`.
    #
    # Paramaters:
    # * `match` is a match record returned from `getMatch()`.
    # * `players` is an array of player descriptors which, ideally, are
    #   `{championId, teamId, summonerId}` objects (e.g. the `fellowPlayers` field in a game
    #   returned by `getRecentGamesForSummoner()`.)  You can replace `championId` with `championKey`
    #   and provide a chamion key or a champion name.  You can similarly replace `summonerId` with
    #   `summonerName`.  You can also replace `teamId` with `team` which should be either "red" or
    #   "blue".
    # * `options.region` - The region of the summoner.  Defaults to the `defaultRegion` passed
    #   to the construtor.
    #
    # Returns the number of participantIdentities that were filled in, via the callback.
    #
    populateMatch: optCb (match, players, options, _) ->
        assert(ld.isArray(players), "'players' must be an array!")

        # If all participantIdentity objects are populated, we have nothing to do, so check this first.
        return 0 if ld.every(match.participantIdentities, "player")

        # TODO: If less than 10 players are passed in, can we do a quick check to see if all
        # the players are here before we call @_loadPlayers?  This could potentially save us
        # some API calls.

        populated = 0

        playerData = @_loadPlayers players, options, _

        participantIdentitiesById = ld.indexBy match.participantIdentities, "participantId"
        for participant in match.participants
            participantIdentity = participantIdentitiesById[participant.participantId]

            # If we don't know the identity of this player, try to find them in the players list.
            if !participantIdentity.player
                player = ld.find playerData, (p) ->
                    p.championId is participant.championId and p.teamId is participant.teamId

                if player?
                    populated++
                    participantIdentity.player = {
                        profileIcon: player.summoner.profileIconId
                        matchHistoryUri: null
                        summonerName: player.summoner.name
                        summonerId: player.summoner.id
                    }

        return populated

    # This is a helper function for `populateMatch()`.
    #
    # Given a collection of `{championId or championKey, teamId or team, summonerId or summonerName}`
    # objects, return a collection of `{championId, teamId, summoner}` objects.  `summoner` will be
    # a Riot API object.  If there are any objects where the given champion or summoner cannot be
    # loaded, these results will be omitted from the returned data.
    _loadPlayers: optCb (players, options, _) ->
        # Since we're relying on other APIs, we assert here so that if those APIs change, we'll get
        # unit test failures if we don't update this method.
        assert.equal(summonerApi.api.version, "v1.4", "Can't load players - summoner API version has changed.")
        assert.equal(lolStaticDataApi.api.version, "v1.2",
            "Can't load players - lol-static-data API version has changed.")

        # Fetch summoners by ID if available
        summonerIds = ld(players).filter('summonerId').map('summonerId').value()
        summonersById = if summonerIds.length > 0
            @getSummonersById(summonerIds, options, _)
        else
            {}

        # Only pull data for summoners where we don't have an ID.
        summonerNames = ld(players).reject('summonerId').map("summonerName").value()
        summonersByName = if summonerNames.length > 0
            @getSummonersByName(summonerNames, options, _)
        else
            {}

        answer = []
        for player in players
            summoner = if player.summonerId?
                summonersById[player.summonerId]
            else if player.summonerName
                summonersByName[player.summonerName]
            else
                throw new Error("player record has no summonerId and no summonerName")

            championId = if player.championId?
                player.championId
            else
                # Use `getChampionByName()`, because it will always try to get by key first, but
                # it is much more forgiving than `getChampionByKey()`.
                champion = @getChampionByName(player.championKey, options, _)
                champion?.id

            if summoner? and championId?
                answer.push {
                    summoner,
                    championId,
                    teamId: player.teamId ? @teamNameToId(player.team)
                }

        return answer

    # Figure out which team a given summoner is on.
    # Returns the teamId, or null if the summoner could not be found.
    getTeamIdForSummonerId: (match, summonerId) ->
        participantIdentity = ld.find match.participantIdentities, {player: {summonerId}}

        if !participantIdentity?
            answer = null
        else
            participantId = participantIdentity.participantId
            participant = ld.find match.participants, {participantId}
            answer = participant.teamId

        return answer
}
