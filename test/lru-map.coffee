expect  = require 'expect.js'
mockery = require 'mockery'
sinon   = require 'sinon'

Map    = require 'es6-map'
LRUMap = require '../src/lru-map'

describe 'LRUMap', ->
	beforeEach ->
		undefined

	describe 'constructor', ->
		it 'constructs an LRUMap', ->
			expect(new LRUMap).to.be.an LRUMap

		it 'constructs an instanceof Map', ->
			expect(new LRUMap).to.be.a Map

		it 'errors when maxSize is negative', ->
			expect(->
				new LRUMap(maxSize: -1)
			).to.throwError /negative/

		it 'errors when calcSize is not a function', ->
			expect(->
				new LRUMap(calcSize: true)
			).to.throwError /calcSize.*function|function.*calcSize/

	describe '#maxSize', ->
		it 'returns maxSize', ->
			expect(new LRUMap().maxSize()).to.be Infinity
			expect(new LRUMap(maxSize: 10).maxSize()).to.be 10
