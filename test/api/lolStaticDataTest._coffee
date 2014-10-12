path = require 'path'
fs = require 'fs'
url = require 'url'
querystring = require 'querystring'
{expect} = require 'chai'

testUtils = require '../testUtils'
lol = require '../../src/lol'

describe 'lol-static-data API', ->
    it 'should fetch champions by id', (_) ->
        client = lol.client {apiKey: 'TESTKEY'}
        testUtils.expectRequest(client,
            "https://na.api.pvp.net/api/lol/static-data/na/v1.2/champion",
            {dataById: 'true'},
            'staticChampionsById.json')

        champion = client.getChampionById 53, _

        expect(champion).to.exist
        expect(champion.name).to.equal "Blitzcrank"

    it 'should fetch champions by key', (_) ->
        client = lol.client {apiKey: 'TESTKEY'}
        testUtils.expectRequest(client,
            "https://na.api.pvp.net/api/lol/static-data/na/v1.2/champion",
            {dataById: 'false'},
            'staticChampions.json')

        champion = client.getChampionByKey "Velkoz", _

        expect(champion).to.exist
        expect(champion.name).to.equal "Vel'Koz"
