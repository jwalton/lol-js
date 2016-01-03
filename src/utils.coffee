ld = require 'lodash'

# Converts an array to a comma delimited list, or null to null.
exports.arrayToList = (arr) ->
    return arr if !arr?
    return arr.join ','

exports.paramsToCacheKey = (params) ->
    ld.values(params).join('-')
