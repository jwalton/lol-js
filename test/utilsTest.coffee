{expect} = require 'chai'
{Promise} = require 'es6-promise'
utils = require '../src/utils'

describe 'utils', ->
    describe 'arrayToList', ->
        it 'should work for an array', ->
            expect(utils.arrayToList([1,2,3])).to.equal "1,2,3"

        it 'should work for null', ->
            expect(utils.arrayToList(null)).to.equal null

    describe 'paramsToCacheKey', ->
        expect(
            utils.paramsToCacheKey {
                c: 1,
                b: 7,
                a: "hello",
                d: null
                e: 9
            }
        ).to.equal "1-7-hello--9"
