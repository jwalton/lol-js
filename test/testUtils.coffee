path        = require 'path'
fs          = require 'fs'
url         = require 'url'
querystring = require 'querystring'
{expect}    = require 'chai'

exports.expectRequest = (client, expectedUrl, expectedParams, sampleFile) ->
    filename = path.resolve __dirname, 'sampleResults', sampleFile

    reqCount = 0
    client._request = (u, cb) ->
            parsedUrl = url.parse u
            reqCount++
            switch reqCount
                when 1
                    expect(parsedUrl.protocol + "//" + parsedUrl.host + parsedUrl.pathname).to.equal(expectedUrl)
                    queryParams = querystring.parse(parsedUrl.query)
                    expect(queryParams['api_key']).to.equal('TESTKEY',
                        "URL query parameter api_key has incorrect value")
                    for expectedParamName, expectedParamValue of expectedParams
                        expect(queryParams[expectedParamName]).to.equal("#{expectedParamValue}",
                            "URL query parameter #{expectedParamName} has incorrect value")
                    cb null, {statusCode: 200}, fs.readFileSync(filename, {encoding: 'utf8'})
                when 2
                    cb new Error("Shouldn't be a second request")
