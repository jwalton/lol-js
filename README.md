
[![NPM](https://nodei.co/npm/lol-js.png?downloads=true&downloadRank=true&stars=true)](https://nodei.co/npm/lol-js/)

[![Dependencies Badge](https://img.shields.io/david/jwalton/lol-js.svg)](http://shields.io/)
[![Npm Version](https://badge.fury.io/js/lol-js.svg)](http://badge.fury.io/js/lol-js)

lol.js is a client for fetching data from the [Riot API](https://developer.riotgames.com/api/methods)
for [League of Legends](http://na.leagueoflegends.com/).  There are
[many node.js packages](https://developer.riotgames.com/discussion/riot-games-api/show/iXR9Vl2A) out
there which give you access to the Riot API, but none has as complete a feature set as lol.js.

Features
========

* Support for the following APIs:
  * game-v1.3
  * lol-static-data-v1.2 (partial)
  * match-v2.2
  * matchhistory-v2.2
  * summoner-v1.4
  * team-v2.4
  * it's fairly easy to add other APIs - if you need something please raise an issue and I'll
    add it in for you, or send a Pull Request.
* Native promise support
* Built in support for rate limiting.
* Built in support for flexible caching with the caching engine of your choice.  Built in support
  is available for Redis and an in-memory cache, however it is easy to write support for other
  databases if you wish.

Installation
============

    npm install --save lol-js

Example Usage
=============

With callbacks:

```
var lol = require('lol-js');
var lolClient = lol.client({
    apiKey: 'blahblahblah',
    defaultRegion: 'na',
    cache: lol.redisCache({host: '127.0.0.1', port: 6379})
};
lolClient.getChampionById(53, {champData: ['all']}, function(err, data) {
    console.log("Found ", data.name);
    lolClient.destroy();
});
```

With promises:

```
var lol = require('lol-js');
var lolClient = lol.client({
    apiKey: 'blahblahblah',
    defaultRegion: 'na',
    cache: lol.redisCache({host: '127.0.0.1', port: 6379})
};
lolClient.getChampionByIdAsync(53, {champData: ['all']})
.then(function (data) {
    console.log("Found ", data.name);
    lolClient.destroy();
});
```

Creating a Client
=================

The first step to using lol-js is to create a new client by calling `lol.client()`.  This function
takes a configuation object with the following options:

* `apiKey` - the API key [assigned to you by Riot](https://developer.riotgames.com/).
* `defaultRegion` - the region to use for queries if none is specified.  Defaults to 'na'.
* `cache` - a cache object or `null` to disable caching (see below).
* `cacheTTL` - a `{long, short, flex}` object which controls how long objects are cached
  for.  Each is a value in seconds.  `long` applies to match objects, which don't change very
  often.  Most objects are cached for the `short` duration.  Default is one month for `long` and
  5 minutes for `short`.  If `flex` is not null (defaults to one month) then all objects will be
  stored in the cache for the `flex` TTL, however when an object is retrieved from the cache, we
  will still try to fetch a new copy of the object from Riot if the object is older than the
  short/long TTLs.  If the Riot API is unavailable for some reason (the Riot API rather frequently
  returns 503) then the "expired" value will be used from the cache.  Note that if `flex` is null
  then in such a case lol-js will retry the request a few times instead.
* `rateLimit` - a list of limit objects.  Each limit object is a `{time, limit}` pair where `time`
  is a duration in seconds and `limit` is the maximum number of requests to make in that
  duration.  Defaults to `[{time: 10, limit: 10}, {time: 600, limit: 500}]`.

Functions
=========

You can browse the well-documented code in the [`src/api`](https://github.com/jwalton/lol-js/tree/master/src/api)
folder for a complete description of all the functions you can call.  Each file in `src/api` is a
mixin object which is added to the client object's prototype.  Note that the source files only
contain the promise version of the code - the callback versions are generated automatically.

Caching
=======

lol-js will automatically cache results from Riot's API for you, allowing you to focus on using
the data rather than worrying about rate limits and the Riot server going down.

The easiest way to cache objects is to use a built-in cache type.  The following built in cache
types exist:

* `lol.lruCache(options)` - Caches all objects in memory.  Based on [isaacs](https://github.com/isaacs)'s
  [lru-cache](https://github.com/isaacs/node-lru-cache), and can take any options that the
  `LRU` constructor can take.
* `lol.redisCache({host, port, keyPrefix})` - Caches objects in Redis.  `host` and `port` are
  the connection details for your redis server and default to `'127.0.0.1'` and `6379`,
  respectively.  `keyPrefix` is a prefix to prepend to all keys stored in Redis and defaults
  to `'loljs-'`.  You may want to read about [using Redis as an LRU cache](http://redis.io/topics/lru-cache)
  if you want to use Redis, or you can risk running out of memory.

If you don't want to use one of the built in cache types, you can easily specify your own caching
functions.  The `cache` parameter passed to a new client is a `{set, get, destroy}` object, where
`set(params, value)` stores an object in the cache, and `get(params, callback)`
is a function which retrieves an object from the cache and calls `callback(err, value)` returning
the cached value or `null` if the value is not available.  In both cases, params is an object
consisting of:

* `params.key` - A string which uniquely identifies this object.
* `params.ttl` - The suggested length, in seconds, to cache the object for.  `null` if the object
  can be cached forever.
* `params.api` - A `{name, version}` object (e.g. `{name: 'match', version: 'v2.2'}`.)
* `params.objectType` - The type of object being cached.  This is always a string consisting of
  only letters.
* `params.region` - The region used to make the request.
* `params.params` - A hash of parameters which identify the object - this is different for each
  object type.  For example, for a "summonerByName" `objectType`, this will be a `{summonerName}`
  object.

When calling `cache.set()`, lol-js may pass in `"none"` in place of a value to indicate the value
does not exist.  `cache.get()` should return `"none"` if such a params object is passed in.
lol-js will always try to retrieve an object from the cache first, and will only make a REST
request if the cached object is not available.

Finally, if the cache defines a `destroy()` function, this will be called when the lol-js client
is destroyed.

Development
===========

If you're interested in contributing, check out the [development docs](./docs/development.md).
