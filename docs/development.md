Development
-----------

Language
========

lol-js is written in [CoffeeScript](http://coffeescript.org/), using
[streamline.js](https://github.com/Sage/streamlinejs) to simplify async calls.  If you are
unfamiliar with streamline, a quick introduction would be; in any file that ends in `._coffee`,
anywhere where you'd pass a callback, you can replace the callback with `_`, and now you can
pretend the function is synchronous.  Streamline takes care of all the messy async details behind
the scenes at compile time.

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
    getRecentGamesForSummoner: (summonerId, _) ->
        ...
}
```

`api` should always be a `{fullname, name, version}` object.  The `fullname` is used when
generating cache keys, so that results from old APIs won't be retrieved from the cache.  If you
write a function in one API that calls into a function in another API, it is best practice to
[assert](http://nodejs.org/api/assert.html#assert_assert_value_message_assert_ok_value_message)
that the other API's version is what you expect it to be; this way when Riot changes an API,
we'll be sure to catch all the places where we need to update functions to deal with the changes.

`methods` is a hash of functions which will be mixed in to the `Client` class's prototype.  These
methods can call into methods in the core `Client` class or even into methods defined in other APIs.

Writing API Modules
===================

If you are adding a new API module to `src/api`, or updating an existing API, there are three
core methods in the `Client` class which you can use to easily implement your API.

* `Client._riotRequest(params, done)` makes requests to the Riot API and returns the raw results.
  `_riotRequest()` doesn't do any caching, but by default enforces rate limits (although you
  can disable rate limit checks by passing `params.rateLimit` as false - handy for APIs such as
  lol-static-data where queries do not count against your rate limit.)
* `Client._riotRequestWithCache(params, cacheParams, options, done)` is similar to `_riotRequest()`,
  but automatically caches results.  `params` is identical to the `params` object passed to
  `_riotRequest()`.  `cacheParams` is the params object which will be passed to `cache.get()`
  and `cache.set()`.
* There are many Riot APIs where you can pass a comma delimited list of IDs or names in the URL,
  and get back a hash where keys are IDs and values are the values you want to request.
  `Client._riotMultiGet(...)` was written to deal with these cases; it caches each value by ID
  individually.  This helps in the case where, for example, you do something like:

      client.getSummonersById([1,2], ...)
      client.getSummonersById([1], ...)

  Here, we've already retrieved summoner 1 and 2 in the first call, so there should be no need to
  fetch summoner 1 again in the second call.  `_riotMultiGet()` takes care of caching this common
  case automatically.
