url         = require 'url'
querystring = require 'querystring'
{expect}    = require 'chai'
testUtils   = require './testUtils'
Client      = require '../src/client'

testMethod = (callClientFn, data, expected, _) ->
    {expectedHost, expectedPathname, expectedQueryParams} = expected

    parsedUrl = null
    client = new Client {apiKey:'TESTKEY', defaultRegion: 'na'}
    client._request = (u, cb) ->
        parsedUrl = url.parse u
        cb null, {statusCode: 200}, data
    value = callClientFn client, _

    expect(parsedUrl.protocol).to.equal('https:')
    expect(parsedUrl.host).to.equal(expectedHost)
    expect(parsedUrl.pathname).to.equal(expectedPathname)
    queryParams = querystring.parse(parsedUrl.query)
    expect(queryParams['api_key']).to.equal('TESTKEY')
    for expectedParamName, expectedParamValue of expectedQueryParams
        expect(queryParams[expectedParamName]).to.equal("#{expectedParamValue}", expectedParamName)

    return value

describe 'Client', ->
    it 'should generate the correct URL and parameters', (_) ->
        value = testMethod(
            ( (client, _) -> client.getMatch(1234, {region: 'eune'}, _) ),
            '{"fakeData": true}',
            {
                expectedHost: 'eune.api.pvp.net'
                expectedPathname: '/api/lol/eune/v2.2/match/1234'
                expectedQueryParams: {
                    includeTimeline: false
                    api_key: 'TESTKEY'
                }
            }, _)

        expect(value).to.eql({fakeData: true})

    it 'should transparently retry if we hit the rate limit', (_) ->
        reqCount = 0

        client = new Client {apiKey:'TESTKEY'}
        client._request = (u, cb) ->
            reqCount++
            switch reqCount
                when 1 then cb null, {statusCode: 429}, ""
                when 2 then cb null, {statusCode: 200}, '{"fakeData": true}'

        value = client.getMatch 1234, _
        expect(reqCount).to.equal 2
        expect(value).to.exist

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

        p1 = client.getMatchAsync 1234
        p2 = client.getMatchAsync 1234
        p1Result = null
        p1.then (r) ->
            p1Result = r
            expect(p1Result).to.exist
            return p2
        .then (p2Result) ->
            expect(p2Result).to.exist
            expect(p1Result).to.equal(p2Result)
