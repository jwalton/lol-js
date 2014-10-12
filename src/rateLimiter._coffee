{RateLimiter} = require 'limiter'

module.exports = class LolRateLimiter
    # `limits` is an array of `{time, limit}` objects where `time` is a value in seconds, and
    # `limit` is the maximum number of occurances which can happen in that time frame.  For
    # example `[{time: 10, limit: 10}, {time: 600, limit: 500}]` would be a limit of 10 events
    # every 10 seconds or 500 events every 10 minutes.
    constructor: (limits) ->
        @limiters = []
        for l in limits
            @limiters.push new RateLimiter(l.limit, l.time * 1000)

    # Waits until the next event can occur.
    wait: (_) ->
        for limiter in @limiters
            limiter.removeTokens 1, _
