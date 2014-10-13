path        = require 'path'
fs          = require 'fs'
url         = require 'url'
querystring = require 'querystring'
{expect}    = require 'chai'

# Calling this will force the passed in `client` to respond to HTTP requests with mock data instead
# of actually calling out to the Riot API.
#
# `requests` should be an array of `{url, sampleFile}` objects.
# `url` is a URL without a query string
# (e.g. "https://na.api.pvp.net/api/lol/static-data/na/v1.2/champion")  and `sampleFile` is the
# name of a file in the sampleResults folder to return as the request body
# (e.g.'staticChampions.json'.)
#
# You can also specify a `query` in the `requests` object, which is a hash
# of query parameters without the api_key (e.g. `{dataById: 'false'}`).  This is deprecated in
# favor of passing the query parameters directly in the URL.  `expectRequests()` is smart enough
# to pass even if query parameters are specified in a different order in the `requests` object
# than are given by the actual request.
#
# `expectRequests()` will expect the client to make requests in the order provided, with the
# expected URLs and parameters.  `expectRequests()` will generate an error if any of unexpected
# requests come in, or if any requests come in after the last request in `requests`.
# `expectRequests()` also expects the client to use an API Key of 'TESTKEY'.
#
# Note that you can call `expectRequests()` multiple times in a single test - each call will
# replace the requests from any previous calls.
#
exports.expectRequests = (client, requests) ->
    reqCount = 0
    client._request = (u, cb) ->
        reqCount++

        if reqCount > requests.length
            return cb new Error("Was only expecting #{requests.length} request(s).
            Request #{reqCount} is: #{u}.")

        expectedRequest = requests[reqCount-1]
        try
            parsedUrl = url.parse u
            parsedExpectedUrl = url.parse expectedRequest.url
            expect(parsedUrl.protocol + "//" + parsedUrl.host + parsedUrl.pathname)
                .to.equal(parsedExpectedUrl.protocol + "//" + parsedExpectedUrl.host + parsedExpectedUrl.pathname,
                "Request has incorrect URL")

            expectedQuery = expectedRequest.query
            if !expectedParams? and parsedUrl.query? then expectedQuery = querystring.parse()

            queryParams = querystring.parse(parsedUrl.query)
            expect(queryParams['api_key'])
                .to.equal('TESTKEY', "URL query parameter api_key has incorrect value")

            # TODO: use `eql` here instead?
            for expectedParamName, expectedParamValue of expectedQuery
                expect(queryParams[expectedParamName]).to.equal("#{expectedParamValue}",
                    "URL query parameter #{expectedParamName} has incorrect value")

            filename = path.resolve __dirname, 'sampleResults', expectedRequest.sampleFile
            cb null, {statusCode: 200}, fs.readFileSync(filename, {encoding: 'utf8'})
        catch err
            return cb err



exports.expectRequest = (client, expectedUrl, sampleFile) ->
    exports.expectRequests client, [{
        url: expectedUrl, sampleFile
    }]
