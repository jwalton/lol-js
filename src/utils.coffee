ld = require 'lodash'

# This is used to define a function that has as it's last two parameters `options` and `done`.
# If `options` is not passed in, then this replaces `options` with `{}`.
exports.optCb = (fn) ->
    ->
        if arguments.length < fn.length
            arguments.length++
            arguments[arguments.length-1] = arguments[arguments.length-2] # done = options
            arguments[arguments.length-2] = {} # options = {}
        fn.apply(this, arguments)
