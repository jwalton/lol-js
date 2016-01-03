{expect}  = require 'chai'
testUtils = require '../testUtils'
lol       = require '../../src/lol'

describe 'lol-static-data API', ->
    it 'should fetch champions by id', ->
        client = lol.client {apiKey: 'TESTKEY'}
        testUtils.expectRequest(client,
            "https://global.api.pvp.net/api/lol/static-data/na/v1.2/champion?dataById=true",
            'static/championsById.json')

        client.getChampionById 53
        .then (champion) ->
            expect(champion).to.exist
            expect(champion.name).to.equal "Blitzcrank"

    it 'should fetch champions by key', ->
        client = lol.client {apiKey: 'TESTKEY'}
        testUtils.expectRequest(client,
            "https://global.api.pvp.net/api/lol/static-data/na/v1.2/champion?dataById=false",
            'static/champions.json')

        client.getChampionByKey "Velkoz"
        .then (champion) ->
            expect(champion).to.exist
            expect(champion.name).to.equal "Vel'Koz"

    it 'should fetch champions by name', ->
        client = lol.client {apiKey: 'TESTKEY'}
        testUtils.expectRequest(client,
            "https://global.api.pvp.net/api/lol/static-data/na/v1.2/champion?dataById=false",
            'static/champions.json')

        champion = client.getChampionByName "Vel koz"
        .then (champion) ->
            expect(champion.name).to.equal "Vel'Koz"
