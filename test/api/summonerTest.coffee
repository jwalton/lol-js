ld = require 'lodash'
{expect}  = require 'chai'
testUtils = require '../testUtils'
lol       = require '../../src/lol'

describe 'summoner API', ->
    it 'should fetch summoners by name', ->
        client = lol.client {
            apiKey: 'TESTKEY'
            cache: lol.lruCache(50)
        }
        testUtils.expectRequest(client,
            "https://na.api.pvp.net/api/lol/na/v1.4/summoner/by-name/summonera,summonerb",
            'summoner/byName.json')

        client.getSummonersByName 'na', ["Summoner A", "SummonerB"]
        .then (value) ->
            expect(value).to.exist
            expect(value["Summoner A"]).to.exist
            expect(value["Summoner A"].id).to.equal 1
            expect(value["SummonerB"]).to.exist

            # Trying to fetch a second time should fetch from cache.
            client.getSummonersByName 'na', ["Summoner A", "SummonerB"]

    it 'should work for non-ascii summoner names', ->
        client = lol.client {apiKey: 'TESTKEY'}

        testUtils.expectRequest(client,
            "https://na.api.pvp.net/api/lol/na/v1.4/summoner/by-name/j%C3%A1%C3%BDce",
            'summoner/byName.json')

        client.getSummonersByName 'na', ['jáýce']
        .then (value) ->
            expect(value).to.exist


    it 'should fetch 60 summoners by name', ->
        client = lol.client {
            apiKey: 'TESTKEY'
        }

        summoners = [1..60].map (s) -> "#{s}"

        # This should result in two API calls; one for the first 40 summoners, and another for the
        # next 40.
        testUtils.expectRequests client, [
            {
                url: "https://na.api.pvp.net/api/lol/na/v1.4/summoner/by-name/1,2,3,4,5,6,7,8,9," +
                    "10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34," +
                    "35,36,37,38,39,40",
                body: JSON.stringify ld.indexBy([1..40].map((s) -> {id: s, name: "#{s}"}), 'id')
            }
            {
                url: "https://na.api.pvp.net/api/lol/na/v1.4/summoner/by-name/41,42,43,44,45,46," +
                    "47,48,49,50,51,52,53,54,55,56,57,58,59,60"
                body: JSON.stringify ld.indexBy([41..60].map((s) -> {id: s, name: "#{s}"}), 'id')
            }
        ]

        value = client.getSummonersByName 'na', summoners
        .then (value) ->
            for i in [1..60]
                expect(value["#{i}"].id).to.equal i
                expect(value["#{i}"].name).to.equal "#{i}"

    it 'should fetch summoners masteries', ->
        client = lol.client {apiKey: 'TESTKEY'}
        testUtils.expectRequest(client,
            "https://na.api.pvp.net/api/lol/na/v1.4/summoner/1,2/masteries",
            'summoner/masteries.json')

        client.getSummonerMasteries 'na', [1, 2]
        .then (value) ->
            expect(value).to.exist
            expect(value["1"]).to.exist
            expect(value["2"]).to.exist

    it 'should fetch summoner names', ->
        client = lol.client {apiKey: 'TESTKEY'}
        testUtils.expectRequest(client,
            "https://na.api.pvp.net/api/lol/na/v1.4/summoner/1,2,3",
            'summoner/byId.json')

        client.getSummonerNames 'na', [1, 2, 3]
        .then (value) ->
            expect(value).to.exist
            expect(value["1"]).to.equal 'SummonerA'
            expect(value["2"]).to.equal 'SummonerB'
            expect(value["3"]).to.equal null
