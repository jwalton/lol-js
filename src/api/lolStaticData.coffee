ld = require 'lodash'
{promiseToCb} = require '../utils'

api = exports.api = {
    fullname: "lol-static-data-v1.2",
    name: "lol-static-data",
    version: "v1.2"
}

makeUrl = (region) -> "https://#{region}.api.pvp.net/api/lol/static-data/#{region}/v1.2"


exports.methods = {
    # Retrieve a list of champions
    #
    # Parameters:
    # * `options.region` - Region from which to retrieve data.
    # * `options.locale` - Locale code for returned data (e.g., en_US, es_ES). If not specified,
    #   the default locale for the region is used.
    # * `options.version` - Data dragon version for returned data. If not specified, the latest
    #    version for the region is used. List of valid versions can be obtained from
    #    `getVersions()`.
    # * `options.dataById` - If true, the results will be indexed by ID instead of by key.
    # * `options.champData` - Array of tags to return additional data. Only type, version, data,
    #   id, key, name, and title are returned by default if this parameter isn't specified. To
    #   return all additional data, use the tag 'all'.  Valid values are: 'all', 'allytips',
    #   'altimages', 'blurb', 'enemytips', 'image', 'info', 'lore', 'partype', 'passive',
    #   'recommended', 'skins', 'spells', 'stats', 'tags'.
    #
    getChampionsAsync: (options={}) ->
        options = ld.defaults {}, options, {
            region: @defaultRegion,
            dataById: false
        }
        region = options.region ? @defaultRegion

        requestParams = {
            caller: "getChampions",
            region: region,
            url: "#{makeUrl region, api}/champion",
            queryParams: ld.pick options, ['locale', 'version', 'dataById', 'champData']
            rateLimit: false
        }
        cacheParams = {
            key: "#{api.fullname}-champions-#{region}-#{options.locale}-#{options.version}-" +
                "#{if options.dataById then 't' else 'f'}-#{(options.champData ? []).join ','}"
            api, region, objectType: 'champions', params: requestParams.queryParams
        }
        @_riotRequestWithCache requestParams, cacheParams, {}

    # Retrieve a champion using its ID.
    #
    # Parameters:
    # * `id` - the ID of the champion to retrieve.
    # * `options` are the same as for `getChampions()`, except that `dataById` cannot be specified.
    #
    getChampionByIdAsync: (id, options={}) ->
        options = ld.extend {}, options, {dataById: true}
        @getChampionsAsync(options)
        .then (champions) -> champions.data[id]

    # Retrieve a champion using its key.
    #
    # Parameters:
    # * `id` - the ID of the champion to retrieve.
    # * `options` are the same as for `getChampions()`, except that `dataById` cannot be specified.
    #
    getChampionByKeyAsync: (key, options={}) ->
        options = ld.extend {}, options, {dataById: false}
        @getChampionsAsync(options)
        .then (champions) -> champions.data[key]

    getChampionByNameAsync: (name, options={}) ->
        options = ld.extend {}, options, {dataById: false}
        @getChampionsAsync(options)
        .then (champions) ->
            # First try the name as a key, because this is the fastest way to do this.
            answer = champions.data[name]

            # If this doesn't work, try searching for a champion with the same name, ignoring
            # punctuation and case.
            if !answer?
                championsByName = ld.indexBy champions.data, (c) ->
                    c.name.toLowerCase().replace(/\W/g, '')
                answer = championsByName[name.toLowerCase().replace(/\W/g, '')]

            return answer

    # Retrieve a list of items.
    #
    # Parameters:
    # * `options.region` - Region from which to retrieve data.
    # * `options.locale` - Locale code for returned data (e.g., en_US, es_ES). If not specified,
    #   the default locale for the region is used.
    # * `options.version` - Data dragon version for returned data. If not specified, the latest
    #    version for the region is used. List of valid versions can be obtained from
    #    `getVersions()`.
    # * `options.tags` - Tags to return additional data. Only type, version, basic, data, id, name,
    #    plaintext, group, and description are returned by default if this parameter isn't
    #    specified. To return all additional data, use the tag 'all'.  Valid options are:
    #    all, colloq, consumeOnFull, consumed, depth, from, gold, groups, hideFromAll, image,
    #    inStore, into, maps, requiredChampion, sanitizedDescription, specialRecipe, stacks, stats,
    #    tags, tree
    #
    getItemsAsync: (options={}) ->
        options = ld.defaults {}, options, {
            region: @defaultRegion,
            dataById: false
        }
        region = options.region ? @defaultRegion

        requestParams = {
            caller: "getItems",
            region: region,
            url: "#{makeUrl region, api}/item",
            queryParams: ld.pick options, ['locale', 'version', 'tags']
            rateLimit: false
        }
        cacheParams = {
            key: "#{api.fullname}-champions-#{region}-#{options.locale}-#{options.version}-" +
                options.tags.join(",")
            api, region, objectType: 'items', params: requestParams.queryParams
        }
        @_riotRequestWithCache requestParams, cacheParams, {}

    # Retrieve an item using its ID.
    #
    # Parameters:
    # * `id` - the ID of the item to retrieve.
    # * `options` are the same as for `getItems()`.
    #
    getItemByIdAsync: (id, options={}) ->
        @getItemsAsync(options)
        .then (objects) ->
            return objects.data[id]

    # TODO: Lots more things to implement here.

    # Retrieve a list of items.
    #
    # Parameters:
    # * `options.region` - Region from which to retrieve data.
    getVersionsAsync: (options={}) ->
        region = options?.region ? @defaultRegion

        requestParams = {
            caller: "getVersions",
            region: region,
            url: "#{makeUrl region, api}/versions",
            rateLimit: false
        }
        cacheParams = {
            key: "#{api.fullname}-versions-#{region}"
            api, region, objectType: 'versions', params: {}
        }
        @_riotRequestWithCache requestParams, cacheParams, {}

    # Converts a team name ("red" or "blue") to a team ID (100, 200).
    # Note this returns the actual value, and not a promise.
    teamNameToId: (teamName) ->
        if teamName.toLowerCase() is "blue" then 100 else 200
}
