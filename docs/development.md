Development
-----------

Language
========

lol-js is written in [CoffeeScript](http://coffeescript.org/), using
the [es6-promise](https://github.com/jakearchibald/es6-promise) promise polyfill.

Building lol-js
===============

You can build the project with `npm run build`.

Run `npm test` to run unit tests.  Tests are excuted directly from the CoffeeScript source files,
as this makes for better stack traces when things go wrong.  Note the first test may take a while
to run, as compiling streamline files is slow.

Design Overview
===============

Calling `lol.client()` will return an instance of the Client class.  The core functionality of
the `Client` class is defined in `src/client`, however many of the methods on the client class are
defined in files located in the `src/api` folder.

The Riot API is divided into multiple "child APIs" each with their own version (match, summoner,
game, etc...).  `src/api` contains one file for each of these child APIs.  Each file exports two
parameters:

```
api = exports.api = {
    fullname: "game-v1.3",
    name: "game",
    version: "v1.3"
}

exports.methods = {
    getRecentGamesForSummonerAsync: (summonerId, options) ->
        ...
}
```

`api` should always be a `{fullname, name, version}` object.  The `fullname` is used when
generating cache keys, so that results from old APIs won't be retrieved from the cache.  If you
write a function in one API that calls into a function in another API, it is best practice to
[assert](http://nodejs.org/api/assert.html#assert_assert_value_message_assert_ok_value_message)
that the other API's version is what you expect it to be; this way when Riot changes an API,
we'll be sure to catch all the places where we need to update functions to deal with the changes.
The `api` object is also handy for using the `_makeUrl` helper function.

`methods` is a hash of functions which will be mixed in to the `Client` class's prototype.  These
methods can call into methods in the core `Client` class or even into methods defined in other APIs.

For any method name that end is `Async`, `Client` will automatically have a method added to it
without the `Async` suffix that accepts a callback as the last parameter, so in the above example
the client will end up with a method called `getRecentGamesForSummonerAsync(summonerId, options)`
which returns a promise, and `getRecentGamesForSummoner(summonerId, options, done)`, which will
call `done(err, result)` with a result.

Writing API Modules
===================

If you are adding a new API module to `src/api`, or updating an existing API, there are three
core methods in the `Client` class which you can use to easily implement your API.  Note that all
of the following return promises.

* `Client._riotRequest(params)` makes requests to the Riot API and returns the raw results.
  `_riotRequest()` doesn't do any caching, but by default enforces rate limits (although you
  can disable rate limit checks by passing `params.rateLimit` as false - handy for APIs such as
  lol-static-data where queries do not count against your rate limit.)
* `Client._riotRequestWithCache(params, cacheParams, options)` is similar to `_riotRequest()`,
  but automatically caches results.  `params` is identical to the `params` object passed to
  `_riotRequest()`.  `cacheParams` is the params object which will be passed to `cache.get()`
  and `cache.set()`.  See below for more details on `cacheParams`.
* There are many Riot APIs where you can pass a comma delimited list of IDs or names in the URL,
  and get back a hash where keys are IDs and values are the values you want to request.
  `Client._riotMultiGet(...)` was written to deal with these cases; it caches each value by ID
  individually.  This helps in the case where, for example, you do something like:

      client.getSummonersById([1,2], ...)
      client.getSummonersById([1], ...)

  Here, we've already retrieved summoner 1 and 2 in the first call, so there should be no need to
  fetch summoner 1 again in the second call.  `_riotMultiGet()` takes care of caching this common
  case automatically.

  All of the above methods require you to pass a URL to fetch data from.  Most (but not all) Riot
  APIs follow the same pattern for APIs, so you can use the `_makeUrl()` function to generate a
  URL for you:

  ```
  url = "#{@_makeUrl region, api}/by-summoner/#{summonerId}/recent"
  ```

### cacheParams

`cacheParams` is a `{key, region, api, ttl, objectType, params}` object which is passed to
cache.get and cache.set.  Most cache implementations will probably only need the `key`, but some
cache implementations (like writing to an SQL database) may want more fine grained control, so
we pass this extra data.

The key must uniquely identify the resource being retrieved.  The usual format is a dash separated
string of the format:

    "#{api.fullname}-#{objectType}-#{region}-#{paramsWithDashes}"

Any parameters which we pass up to the Riot API should be in `paramsWithDashes`.

The `ttl` should generally be either `@cacheTTL.long` or `@cacheTTL.short`.  If you don't pass a
`ttl`, it defaults to `@cacheTTL.short`.
