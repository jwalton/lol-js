{expect} = require 'chai'
{Promise} = require 'es6-promise'
utils = require '../src/utils'

describe 'utils', ->
    describe 'promiseToCb', ->
        it 'should convert a function that returns a promise into one that accepts a cb', (done) ->
            myPromiseFn = (name) -> return Promise.resolve(name)
            cbFn = utils.promiseToCb myPromiseFn

            cbFn "Jason", (err, result) ->
                return done err if err?
                try
                    expect(result).to.equal("Jason")
                    done()
                catch err
                    done err

        it 'should pass back errors', (done) ->
            myPromiseFn = (name) -> return Promise.reject("foo")
            cbFn = utils.promiseToCb myPromiseFn

            cbFn "Jason", (err, result) ->
                try
                    expect(err).to.equal("foo")
                    done()
                catch err
                    done err

        it 'should transparently add extra parameters if required', (done) ->
            myPromiseFn = (a,b,c) -> return Promise.resolve({a,b,c})
            cbFn = utils.promiseToCb myPromiseFn

            cbFn "Jason", (err, result) ->
                return done err if err?
                try
                    expect(result).to.eql {a: "Jason", b: undefined, c: undefined}
                    done()
                catch err
                    done err

        it 'should maintain the "this" reference', (done) ->
            obj = {
                myPromiseFn: -> return Promise.resolve(@foo)
                foo: "foo"
            }
            obj.cbFn = utils.promiseToCb obj.myPromiseFn

            obj.cbFn (err, result) ->
                return done err if err?
                try
                    expect(result).to.equal "foo"
                    done()
                catch err
                    done err

    describe "depromisifyAll", ->
        it 'should work', (done) ->
            obj = {
                myPromiseFnAsync: -> return Promise.resolve(@foo)
                foo: "foo"
            }
            utils.depromisifyAll obj

            obj.myPromiseFn (err, result) ->
                return done err if err?
                try
                    expect(result).to.equal "foo"
                    done()
                catch err
                    done err
