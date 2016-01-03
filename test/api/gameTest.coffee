{expect}  = require 'chai'
testUtils = require '../testUtils'
lol       = require '../../src/lol'

describe 'game API', ->
    it 'should fetch recent games for a summoner', ->
        client = lol.client { apiKey: 'TESTKEY', cache: lol.lruCache(100) }
        testUtils.expectRequests client, [
            {
                url: "https://na.api.pvp.net/api/lol/na/v1.3/game/by-summoner/24125166/recent"
                sampleFile: 'game/recent.json'
            }
        ]

        client.getRecentGamesForSummoner 24125166
        .then (games) ->
            expect(games.games.length).to.equal 2
            expect(games.matches).to.not.exist

    it 'should fetch recent matches for a summoner', ->
        client = lol.client { apiKey: 'TESTKEY', cache: lol.lruCache(100), defaultRegion: "ru" }
        testUtils.expectRequests client, [
            {
                url: "https://na.api.pvp.net/api/lol/na/v1.3/game/by-summoner/24125166/recent"
                sampleFile: 'game/recent.json'
            }, {
                url: "https://na.api.pvp.net/api/lol/na/v2.2/match/1578614245?includeTimeline=false"
                sampleFile: 'match/normal.json'
            }, {
                url: "https://na.api.pvp.net/api/lol/na/v2.2/match/1578623302?includeTimeline=false"
                sampleFile: 'match/normal.json'
            }, {
                url: "https://na.api.pvp.net/api/lol/na/v1.4/summoner/1,2,48789267,23876500,43531069,25804545,51526625,49040039,24052480,24125166"
                sampleFile: 'summoner/byId.json'
            }, {
                # FIXME: Shouldn't re-fetch the same summoners we've already fetched.
                # url: "https://na.api.pvp.net/api/lol/na/v1.4/summoner/23931413,26142186,48385754,23789144,25986871,48432170"
                url: "https://na.api.pvp.net/api/lol/na/v1.4/summoner/23931413,26142186,48385754,23789144,25986871,23876500,25804545,48432170,24052480,24125166"
                sampleFile: 'summoner/byId.json'
            }
        ]

        client.getRecentGamesForSummoner 24125166, {region: "na", asMatches: true}
        .then (games) ->
            expect(games.games.length).to.equal 2
            expect(games.matches.length).to.equal 2
            expect(games.matches).to.exist
            expect(games.matches[0].participantIdentities[1].player.summonerName).to.equal "SummonerB"
            expect(games.matches[0].participantIdentities[5].player.summonerName).to.equal "SummonerA"

    it 'should convert a recent game to a recent match', ->
        client = lol.client { apiKey: 'TESTKEY', cache: lol.lruCache(100), defaultRegion: "ru" }

        # Grab a game to convert
        recentGames = require '../sampleResults/game/recent.json'
        game = recentGames.games[0]

        testUtils.expectRequests client, [
            {
                url: "https://na.api.pvp.net/api/lol/na/v2.2/match/1578614245?includeTimeline=false"
                sampleFile: 'match/normal.json'
            }, {
                url: "https://na.api.pvp.net/api/lol/na/v1.4/summoner/1,2,48789267,23876500,43531069,25804545,51526625,49040039,24052480,24125166"
                sampleFile: 'summoner/byId.json'
            }
        ]

        client.recentGameToMatch(game, 24125166, {region: 'na'})
        .then (match) ->
            expect(match).to.exist
            expect(match.participantIdentities[1].player.summonerName).to.equal "SummonerB"
            expect(match.participantIdentities[5].player.summonerName).to.equal "SummonerA"
