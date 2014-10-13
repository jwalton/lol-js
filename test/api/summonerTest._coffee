{expect}  = require 'chai'
testUtils = require '../testUtils'
lol       = require '../../src/lol'

describe 'summoner API', ->
    it 'should fetch summoners by name', (_) ->
        client = lol.client {
            apiKey: 'TESTKEY'
            cache: lol.inMemoryCache()
        }
        testUtils.expectRequest(client,
            "https://na.api.pvp.net/api/lol/na/v1.4/summoner/by-name/SummonerA,SummonerB",
            'summoner/byName.json')

        value = client.getSummonersByName ["SummonerA", "SummonerB"], _
        expect(value).to.exist
        expect(value["SummonerA"]).to.exist
        expect(value["SummonerA"].id).to.equal 1
        expect(value["SummonerB"]).to.exist

        # Trying to fetch a second time should fetch from cache.
        value = client.getSummonersByName ["SummonerA", "SummonerB"], _

    it 'should fetch summoners masteries', (_) ->
        client = lol.client {apiKey: 'TESTKEY'}
        testUtils.expectRequest(client,
            "https://na.api.pvp.net/api/lol/na/v1.4/summoner/1,2/masteries",
            'summoner/masteries.json')

        value = client.getSummonerMasteries [1, 2], _
        expect(value).to.exist
        expect(value["1"]).to.exist
        expect(value["2"]).to.exist

    it 'should fetch summoners names', (_) ->
        client = lol.client {apiKey: 'TESTKEY'}
        testUtils.expectRequest(client,
            "https://na.api.pvp.net/api/lol/na/v1.4/summoner/1,2,3",
            'summoner/byId.json')

        value = client.getSummonerNames [1, 2, 3], _
        expect(value).to.exist
        expect(value["1"]).to.equal 'SummonerA'
        expect(value["2"]).to.equal 'SummonerB'
        expect(value["3"]).to.equal null
