expect  = require 'expect.js'
mockery = require 'mockery'
sinon   = require 'sinon'

Map    = require 'es6-map'
LRUMap = require '../src/lru-map'

describe 'LRUMap', ->
	beforeEach ->
		undefined

	describe 'module entry point index.js', ->
		it 'should export the LRUMap class', ->
			expect(require('../index.js')).to.be LRUMap

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

		it 'errors when onEvict is not a function', ->
			expect(->
				new LRUMap(onEvict: true)
			).to.throwError /onEvict.*function/

		it 'errors when onStale is not a function', ->
			expect(->
				new LRUMap(onStale: true)
			).to.throwError /onStale.*function/

		it 'errors when onRemove is not a function', ->
			expect(->
				new LRUMap(onRemove: true)
			).to.throwError /onRemove.*function/

	describe '#maxSize', ->
		it 'gets and sets maxSize', ->
			expect(new LRUMap().maxSize()).to.be Infinity
			expect(new LRUMap(maxSize: 10).maxSize()).to.be 10

		it 'errors when size is not positive', ->
			expect(->
				new LRUMap().maxSize(0)
			).to.throwError /size.*positive/

		it 'reaps stales', ->
			called = false
			lmap = new LRUMap
			lmap.reapStale = -> called = true
			lmap.maxSize(100)
			expect(called).to.be true

		it 'evicts entries when size decreases', ->
			lmap = new LRUMap(calcSize: (value) -> value)
			lmap.set 'one', 1
			lmap.set 'two', 2
			lmap.set 'three', 3

			expect(lmap.has('one') and lmap.has('two') and lmap.has('three')).to.be true

			lmap.maxSize 4

			expect(lmap.has('three')).to.be true
			expect(lmap.has('one') or lmap.has('two')).to.be false

	describe '#currentSize()', ->
		it 'should report the _total', ->
			lmap = new LRUMap
			lmap._total = 1234

			expect(lmap.currentSize()).to.be 1234



	describe '#maxAge', ->
		it 'gets and sets maxAge', ->
			expect(new LRUMap().maxAge()).to.be Infinity
			expect(new LRUMap(maxAge: 10).maxAge()).to.be 10

		it 'errors when age is not positive', ->
			expect(->
				new LRUMap().maxAge(0)
			).to.throwError /age.*positive/

		it 'reaps stales', ->
			called = false
			lmap = new LRUMap
			lmap.reapStale = -> called = true
			lmap.maxAge(100)
			expect(called).to.be true

	describe '#accessUpdatesTimestamp', ->
		it 'gets and sets accessUpdatesTimestamp', ->
			expect(new LRUMap(accessUpdatesTimestamp: true).accessUpdatesTimestamp()).to.be true
			expect(new LRUMap(accessUpdatesTimestamp: false).accessUpdatesTimestamp()).to.be false

			lmap = new LRUMap
			lmap.accessUpdatesTimestamp true
			expect(lmap.accessUpdatesTimestamp()).to.be true
			lmap.accessUpdatesTimestamp false
			expect(lmap.accessUpdatesTimestamp()).to.be false

		it 'errors if not passed a boolean', ->
			expect(->
				new LRUMap().accessUpdatesTimestamp('hello')
			).to.throwError /boolean/

	describe '#reapStale()', ->
		it 'should reap the stale entries', ->
			lmap = new LRUMap(maxAge: 100)

			lmap._map.set 'staleA', {
				size: 1
				value: 'hi'
				timestamp: +(new Date) - (1000 * 1000)
			}

			lmap._map.set 'staleB', {
				size: 1
				value: 'hi'
				timestamp: +(new Date) - (1000 * 1000)
			}

			lmap._map.set 'freshA', {
				size: 1
				value: 'hi'
				timestamp: +(new Date)
			}

			lmap._map.set 'freshB', {
				size: 1
				value: 'hi'
				timestamp: +(new Date)
			}

			lmap._map.set 'staleC', {
				size: 1
				value: 'hi'
				timestamp: +(new Date) - (1000 * 1000)
			}

			lmap._map.set 'freshC', {
				size: 1
				value: 'hi'
				timestamp: +(new Date)
			}

			lmap._total = 6

			['staleA', 'staleB', 'staleC', 'freshA', 'freshB', 'freshC']
			.forEach (x) -> expect(lmap._map.has(x)).to.be true

			lmap.reapStale()

			['freshA', 'freshB', 'freshC']
			.forEach (x) -> expect(lmap._map.has(x)).to.be true

			['staleA', 'staleB', 'staleC']
			.forEach (x) -> expect(lmap._map.has(x)).to.be false

		it 'should update the _total', ->
			lmap = new LRUMap

			for key in ['1', '2', '3', '4', '5', '6']
				lmap._map.set(key, {
					size: 1
					value: 'hi'
					timestamp: +(new Date) - (parseInt(key) * 1000)
				})

			lmap._total = 6
			lmap._maxAge = 3
			lmap.reapStale()

			expect(lmap._total).to.be 3

		it 'should trigger onStale', ->
			lmap = new LRUMap(maxAge: 3)
			lmap._map.set 'one', {
				size: 1
				value: 'hi'
				timestamp: +(new Date) - 4000
			}

			lmap._total = 1

			called = false
			lmap.onStale (key, value) ->
				expect(key).to.be 'one'
				expect(value).to.be 'hi'
				called = true

			lmap.reapStale()

			expect(called).to.be true

		it 'should trigger onRemove', ->
			lmap = new LRUMap(maxAge: 3)
			lmap._map.set 'one', {
				size: 1
				value: 'hi'
				timestamp: +(new Date) - 4000
			}

			lmap._total = 1

			called = false
			lmap.onRemove (key, value) ->
				expect(key).to.be 'one'
				expect(value).to.be 'hi'
				called = true

			lmap.reapStale()

			expect(called).to.be true

		it 'should respect accessUpdatesTimestamp'

	describe '#forEach', ->
		it 'calls back with correct parameters', ->
			lmap = new LRUMap()
			lmap.set 'foo', 'whizbang'
			lmap.set 'bar', -Infinity
			called = false

			lmap.forEach (value, key, map) ->
				called = true

				if key is 'foo'
					expect(value).to.be 'whizbang'
				else if key is 'bar'
					expect(value).to.be -Infinity
				else
					expect().fail 'bad key'

				expect(map).to.be lmap

			expect(called).to.be true

		it 'binds thisArg', ->
			lmap = new LRUMap()
			lmap.set 'foo', 'whizbang'
			called = false
			someObject = {hi: 'mom'}

			lmap.forEach (value, key, map) ->
				called = true
				expect(map).to.be lmap
				expect(this).to.be someObject
			, someObject

			expect(called).to.be true

	describe '#_total', ->
		it 'should be the correct total size after basic operations', ->
			lmap = new LRUMap

			expect(lmap.currentSize()).to.be 0

			lmap.set 'one', 1
			lmap.set 'two', 1
			lmap.set 'three', 1

			expect(lmap.currentSize()).to.be 3

			lmap.delete 'one'

			expect(lmap.currentSize()).to.be 2

			lmap.set 'four', 1
			lmap.set 'five', 1

			expect(lmap.currentSize()).to.be 4

			lmap.maxSize 2

			expect(lmap.currentSize()).to.be 2

			lmap.clear()

			expect(lmap.currentSize()).to.be 0

			lmap.set 'one', 1
			lmap.set 'two', 1
			lmap.set 'three', 1

	describe 'eviction', ->
		it 'should evict the oldest entries'
		it 'should update the _total'
		it 'should reap stales'
		it 'should trigger onEvict'
		it 'should trigger onRemove'
