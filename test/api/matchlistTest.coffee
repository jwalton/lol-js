{expect}  = require 'chai'
testUtils = require '../testUtils'
lol       = require '../../src/lol'

describe 'matchlist API', ->
    it 'should fetch a list of games for a summoner', ->
        client = lol.client { apiKey: 'TESTKEY', cache: lol.lruCache(100) }
        testUtils.expectRequests client, [
            {
                url: "https://na.api.pvp.net/api/lol/na/v2.2/matchlist/by-summoner/24125166"
                sampleFile: 'matchlist/results.json'
            }
        ]

        client.getMatchlistBySummoner 24125166
        .then (matches) ->
            expect(matches.matches.length).to.equal 44
