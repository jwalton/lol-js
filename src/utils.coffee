ld = require 'lodash'

endsWith = (str, suffix) -> return str[-suffix.length..] is suffix

# Given a funciton which returns a promise, this returns a new function which takes one extra
# parameter, a `callback(err, result)`, and calls the callback with the result of the promise.
exports.promiseToCb = (fn) ->
    return ->
        args = Array.prototype.slice.call(arguments, 0)
        done = args.pop()

        if !ld.isFunction done then throw new Error "No callback provided!"

        expectedArgs = fn.length
        while args.length < expectedArgs
            args.push undefined

        promise = fn.apply (this), args
        promise.then(
            (result) -> done null, result
            (err) -> done err
        )

exports.depromisifyAll = (obj, options={}) ->
    self = if options.isPrototype then null else obj
    for key, value of obj
        ((key, value) ->
            return if key[0] is "_" and !options.includePrivate
            if endsWith key, "Async"
                newKey = key[0...-5]
                obj[newKey] = exports.promiseToCb value
        )(key, value)
