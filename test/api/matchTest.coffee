{expect}  = require 'chai'
testUtils = require '../testUtils'
lol       = require '../../src/lol'

describe 'match API', ->
    describe 'populateMatch()', ->
        it 'should populate players in a match', ->
            client = lol.client { apiKey: 'TESTKEY', cache: lol.lruCache(50) }
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

            client.getMatch 'na', 1514152049
            .then (match) ->
                client.populateMatch 'na', match, [
                    {championId: 120, teamId: 100, summonerId: 1}
                ]
                .then (populated) ->
                    expect(populated).to.equal 1
                    expect(match.participantIdentities[0].player.summonerName).to.equal "SummonerA"

        it 'should populate players in a match and cache them', ->
            client = lol.client { apiKey: 'TESTKEY', cache: lol.lruCache(50) }
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

            client.getMatch 'na', 1514152049, {
                players: [{championId: 120, teamId: 100, summonerId: 1}]
            }
            .then (match) ->
                expect(match.participantIdentities[0].player.summonerName).to.equal "SummonerA"

                # Try to fetch the match without populating it - should still be populated since
                # we cached the populated version.
                client.getMatch 'na', 1514152049
            .then (cachedMatch) ->
                expect(cachedMatch.participantIdentities[0].player.summonerName).to.equal "SummonerA"

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

        it 'should work when IDs are specified', ->
            client = lol.client { apiKey: 'TESTKEY', cache: lol.lruCache(50) }
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

            client._loadPlayers 'na', players
            .then (loadedPlayers) ->
                checkLoadedPlayers loadedPlayers

        it 'should work when names are specified', ->
            client = lol.client {apiKey: 'TESTKEY', cache: lol.lruCache(50)}
            testUtils.expectRequests client, [
                {
                    url: "https://na.api.pvp.net/api/lol/na/v1.4/summoner/by-name/summonera,summonerb"
                    sampleFile: 'summoner/byName.json'
                }
                {
                    url: "https://global.api.pvp.net/api/lol/static-data/na/v1.2/champion?dataById=false"
                    sampleFile: 'static/champions.json'
                }
                # FIXME: We see two requests to fetch champion data.  :/
                {
                    url: "https://global.api.pvp.net/api/lol/static-data/na/v1.2/champion?dataById=false"
                    sampleFile: 'static/champions.json'
                }
            ]

            players = [
                {championKey: "Thresh", team: "blue", summonerName: "SummonerA"}
                {championKey: "Aatrox", team: "red",  summonerName: "summonerb"}
            ]

            client._loadPlayers 'na', players
            .then (loadedPlayers) ->
                checkLoadedPlayers loadedPlayers

    describe 'getTeamIdForSummonerId', ->
        client = lol.client {apiKey: 'TESTKEY', cache: lol.lruCache(50)}
        match = require '../sampleResults/match/ranked.json'

        it 'should find the correct team for a summoner', ->
            teamId = client.getTeamIdForSummonerId match, 24125166
            expect(teamId).to.equal 100

        it 'should return null if the summoner is not on any team', ->
            teamId = client.getTeamIdForSummonerId match, 3
            expect(teamId).to.equal null
