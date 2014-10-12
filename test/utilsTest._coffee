{expect} = require 'chai'
utils = require '../src/utils'

describe 'utils', ->
    describe 'optCb', ->
        it 'should pass through a callback if it exists', ->
            results = null
            f = utils.optCb 2, (options, done) ->
                results = {options, done}

            f("a", "b")
            expect(results.options).to.equal("a")
            expect(results.done).to.equal("b")

        it "should generate empty options if they don't exist", ->
            results = null
            f = utils.optCb 2, (options, done) ->
                results = {options, done}

            f("b")
            expect(results.options).to.eql({})
            expect(results.done).to.equal("b")
