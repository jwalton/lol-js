url         = require 'url'
querystring = require 'querystring'
{expect}    = require 'chai'
testUtils   = require './testUtils'
Client      = require '../src/client'
LRUCache    = require '../src/cache/lruCache'

testMethod = (callClientFn, data, expected) ->
    {expectedHost, expectedPathname, expectedQueryParams} = expected

    parsedUrl = null
    client = new Client {apiKey:'TESTKEY'}
    client._request = (opts, cb) ->
        u = opts.uri
        parsedUrl = url.parse u
        cb null, {statusCode: 200}, data

    callClientFn client
    .then (value) ->
        expect(parsedUrl.protocol).to.equal('https:')
        expect(parsedUrl.host).to.equal(expectedHost)
        expect(parsedUrl.pathname).to.equal(expectedPathname)
        queryParams = querystring.parse(parsedUrl.query)
        expect(queryParams['api_key']).to.equal('TESTKEY')
        for expectedParamName, expectedParamValue of expectedQueryParams
            expect(queryParams[expectedParamName]).to.equal("#{expectedParamValue}", expectedParamName)

        return value

describe 'Client', ->
    it 'should generate the correct URL and parameters', ->
        testMethod(
            ( (client) -> client.getMatch('eune', 1234) ),
            '{"fakeData": true}',
            {
                expectedHost: 'eune.api.pvp.net'
                expectedPathname: '/api/lol/eune/v2.2/match/1234'
                expectedQueryParams: {
                    includeTimeline: false
                    api_key: 'TESTKEY'
                }
            })
        .then (value) ->
            expect(value).to.eql({fakeData: true})

    it 'should transparently retry if we hit the rate limit', ->
        reqCount = 0

        client = new Client {apiKey:'TESTKEY'}
        client._request = (u, cb) ->
            reqCount++
            switch reqCount
                when 1 then cb null, {statusCode: 429}, ""
                when 2 then cb null, {statusCode: 200}, '{"fakeData": true}'

        client.getMatch 'na', 1234
        .then (value) ->
            expect(reqCount).to.equal 2
            expect(value).to.exist

    it 'should transparently retry if the Riot API is unavailable', ->
        reqCount = 0

        client = new Client {apiKey:'TESTKEY'}
        client._request = (u, cb) ->
            reqCount++
            switch reqCount
                when 1 then cb null, {statusCode: 503}, ""
                when 2 then cb null, {statusCode: 200}, '{"fakeData": true}'

        client.getMatch 'na', 1234
        .then (value) ->
            expect(reqCount).to.equal 2
            expect(value).to.exist

    it 'should not transparently retry if the Riot API is unavailable and we have a cached copy available', ->
        reqCount = 0

        client = new Client {apiKey:'TESTKEY'}
        client._request = (u, cb) ->
            reqCount++
            cb null, {statusCode: 503}, ""

        passed = false

        return client._doRequest {
            url: 'https://na.api.pvp.net/api/lol/na/v2.2/match/1234?includeTimeline=false&api_key=TESTKEY'
            caller: 'clientTest'
            allowRetries: false
        }
        .catch (err) ->
            passed = err.statusCode is 503
        .then ->
            expect(reqCount).to.equal 1
            if !passed then throw new Error "Expected exception"

    it 'should work out that two requests are the same request', ->
        reqCount = 0

        client = new Client {apiKey:'TESTKEY'}
        testUtils.expectRequests client, [
            {
                url: "https://na.api.pvp.net/api/lol/na/v1.4/summoner/by-name/SummonerA,summonerb"
                body: '{"fakeData": true}'
            }
        ]

        client._request = (u, cb) ->
            reqCount++
            switch reqCount
                when 1 then cb null, {statusCode: 200}, '{"fakeData": true}'

        p1 = client.getMatch 'na', 1234
        p2 = client.getMatch 'na', 1234
        p1Result = null
        p1.then (r) ->
            p1Result = r
            expect(p1Result).to.exist
            return p2
        .then (p2Result) ->
            expect(p2Result).to.exist
            expect(p1Result).to.equal(p2Result)

    it 'should fetch from the cache immediately', ->
        client = new Client {
            apiKey: 'TESTKEY'
            cache: new LRUCache(50)
        }

        cacheParams = {
            key: 'myobject',
            ttl: 100
            api: {name: 'myapi', version: 'v2.2'}
            objectType: 'object'
            region: 'na'
            params: {foo: 'bar'}
        }

        client.cache.set cacheParams, {foo: 'bar'}
        client.cache.get(cacheParams)
        .then (result) ->
            expect(result.value).to.eql {foo: 'bar'}
