{expect}  = require 'chai'
testUtils = require '../testUtils'
lol       = require '../../src/lol'

describe 'match API', ->
    describe 'populateMatch()', ->
        it 'should populate players in a match', (_) ->
            client = lol.client { apiKey: 'TESTKEY', cache: lol.inMemoryCache() }
            testUtils.expectRequests client, [
                {
                    url: "https://na.api.pvp.net/api/lol/na/v2.2/match/1514152049?includeTimeline=false"
                    sampleFile: 'match/normal.json'
                }
                {
                    url: "https://na.api.pvp.net/api/lol/na/v1.4/summoner/1"
                    sampleFile: 'summoner/byId.json'
                }
            ]

            match = client.getMatch 1514152049, _
            populated = client.populateMatch match, [
                {championId: 120, teamId: 100, summonerId: 1}
            ], _

            expect(populated).to.equal 1
            expect(match.participantIdentities[0].player.summonerName).to.equal "SummonerA"

    describe '_loadPlayers()', ->
        checkLoadedPlayers = (loadedPlayers) ->
            expect(loadedPlayers.length).to.equal 2
            expect(loadedPlayers[0].championId).to.equal 412
            expect(loadedPlayers[0].teamId).to.equal 100
            expect(loadedPlayers[0].summoner?.id).to.equal 1
            expect(loadedPlayers[0].summoner?.name).to.equal "SummonerA"

            expect(loadedPlayers[1].championId).to.equal 266
            expect(loadedPlayers[1].teamId).to.equal 200
            expect(loadedPlayers[1].summoner?.id).to.equal 2
            expect(loadedPlayers[1].summoner?.name).to.equal "SummonerB"

        it 'should work when IDs are specified', (_) ->
            client = lol.client { apiKey: 'TESTKEY', cache: lol.inMemoryCache() }
            testUtils.expectRequests client, [
                {
                    url: "https://na.api.pvp.net/api/lol/na/v1.4/summoner/1,2",
                    sampleFile: 'summoner/byId.json'
                }
            ]

            players = [
                {championId: 412, teamId: 100, summonerId: 1}
                {championId: 266, teamId: 200, summonerId: 2}
            ]

            loadedPlayers = client._loadPlayers players, _
            checkLoadedPlayers loadedPlayers

        it 'should work when names are specified', (_) ->
            client = lol.client {
                apiKey: 'TESTKEY'
                cache: lol.inMemoryCache()
            }
            testUtils.expectRequests client, [
                {
                    url: "https://na.api.pvp.net/api/lol/na/v1.4/summoner/by-name/SummonerA,summonerb"
                    sampleFile: 'summoner/byName.json'
                }
                {
                    url: "https://na.api.pvp.net/api/lol/static-data/na/v1.2/champion?dataById=false"
                    sampleFile: 'static/champions.json'
                }
            ]

            players = [
                {championKey: "Thresh", team: "blue", summonerName: "SummonerA"}
                {championKey: "Aatrox", team: "red",  summonerName: "summonerb"}
            ]

            loadedPlayers = client._loadPlayers players, _
            checkLoadedPlayers loadedPlayers
