{expect}  = require 'chai'
testUtils = require '../testUtils'
lol       = require '../../src/lol'

describe 'game API', ->
    it 'should fetch recent games for a summoner', (_) ->
        client = lol.client { apiKey: 'TESTKEY', cache: lol.inMemoryCache() }
        testUtils.expectRequests client, [
            {
                url: "https://na.api.pvp.net/api/lol/na/v1.3/game/by-summoner/24125166/recent"
                sampleFile: 'game/recent.json'
            }
        ]

        games = client.getRecentGamesForSummoner 24125166, _

        expect(games.games.length).to.equal 2
        expect(games.matches).to.not.exist

    it 'should fetch recent matches for a summoner', (_) ->
        client = lol.client { apiKey: 'TESTKEY', cache: lol.inMemoryCache(), defaultRegion: "ru" }
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
                url: "https://na.api.pvp.net/api/lol/na/v1.4/summoner/23931413,26142186,48385754,23789144,25986871,23876500,25804545,48432170,24052480,24125166"
                sampleFile: 'summoner/byId.json'
            }
        ]

        games = client.getRecentGamesForSummoner 24125166, {region: "na", asMatches: true},  _

        expect(games.games.length).to.equal 2
        expect(games.matches).to.exist
        expect(games.matches[0].participantIdentities[1].player.summonerName).to.equal "SummonerB"
        expect(games.matches[0].participantIdentities[5].player.summonerName).to.equal "SummonerA"
