expect  = require 'expect.js'
mockery = require 'mockery'
sinon   = require 'sinon'

Map    = require 'es6-map'
LRUMap = require '../src/lru-map'

describe 'LRUMap', ->
	beforeEach ->
		undefined

	describe 'module entry point index.js', ->
		it 'exports the LRUMap class', ->
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
		it 'reports the current size', ->
			lmap = new LRUMap
			lmap._total = 1234

			expect(lmap.currentSize()).to.be 1234

	describe '#fits()', ->
		it 'says whether the value argument would fit in the map', ->
			lmap = new LRUMap {
				calcSize: (x) -> x.size
			}

			expect(lmap.fits({size: 0})).to.be true
			expect(lmap.fits({size: Infinity})).to.be true

			lmap.maxSize 10
			expect(lmap.fits({size: 10})).to.be true
			expect(lmap.fits({size: 11})).to.be false

			lmap.set 'five', {size: 5}
			expect(lmap.fits({size: 5})).to.be true
			expect(lmap.fits({size: 6})).to.be true
			expect(lmap.fits({size: 10})).to.be true
			expect(lmap.fits({size: 11})).to.be false

	describe '#wouldCauseEviction()', ->
		it 'says whether the value argument would cause other value(s) to be evicted', ->
			lmap = new LRUMap {
				calcSize: (x) -> x.size
			}

			expect(lmap.wouldCauseEviction({size: 0})).to.be false
			expect(lmap.wouldCauseEviction({size: Infinity})).to.be false

			lmap.maxSize 10
			expect(lmap.wouldCauseEviction({size: 10})).to.be false
			expect(lmap.wouldCauseEviction({size: 11})).to.be false

			lmap.set 'five', {size: 5}
			expect(lmap.wouldCauseEviction({size: 5})).to.be false
			expect(lmap.wouldCauseEviction({size: 6})).to.be true

			lmap.maxSize 15
			expect(lmap.wouldCauseEviction({size: 10})).to.be false
			expect(lmap.wouldCauseEviction({size: 11})).to.be true

	describe '#onEvict()', ->
		it 'errors if the argument is not a function', ->
			expect(->
				new LRUMap().onEvict(1234)
			).to.throwError /function/

		it 'sets the onEvict handler', ->
			lmap = new LRUMap maxSize: 1
			called = 0
			handler = -> called++
			lmap.onEvict handler

			lmap.set 'one', 'hi'
			expect(called).to.be 0

			lmap.set 'two', 'hi'
			expect(called).to.be 1

	describe '#onStale()', ->
		it 'errors if the argument is not a function', ->
			expect(->
				new LRUMap().onStale(1234)
			).to.throwError /function/

		it 'sets the onStale handler', ->
			lmap = new LRUMap maxAge: 3
			called = 0
			handler = -> called++
			lmap.onStale handler

			lmap._map.set 'one', {
				size: 1
				value: 'hi'
				timestamp: +(new Date) - 4000
			}

			lmap._total = 1

			expect(called).to.be 0

			lmap.reapStale()

			expect(called).to.be 1

	describe '#onRemove()', ->
		it 'errors if the argument is not a function', ->
			expect(->
				new LRUMap().onRemove(1234)
			).to.throwError /function/

		it 'sets the onRemove handler', ->
			lmap = new LRUMap {maxAge: 3, maxSize: 1}
			called = 0
			handler = -> called++
			lmap.onRemove handler

			lmap._map.set 'one', {
				size: 1
				value: 'hi'
				timestamp: +(new Date) - 4000
			}

			lmap._total = 1

			expect(called).to.be 0

			lmap.reapStale()

			expect(called).to.be 1

			lmap.set 'two', 'hi'
			expect(called).to.be 1

			lmap.set 'three', 'hi'
			expect(called).to.be 2

	describe '#reapStale()', ->
		it 'reaps the stale entries', ->
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

		it 'updates the _total', ->
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

		it 'triggers onStale', ->
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

		it 'triggers onRemove', ->
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

		it 'respects accessUpdatesTimestamp', ->
			lmap = new LRUMap({maxAge: 3, accessUpdatesTimestamp: true})

			staleDate = +(new Date) - 4000

			entry = {
				size: 1
				value: 'hi'
				timestamp: staleDate
			}

			lmap._map.set 'one', entry
			lmap._total = 1

			lmap.get 'one'
			expect(entry.timestamp).to.be.greaterThan +(new Date) - 50
			lmap.reapStale()
			expect(lmap.currentSize()).to.be 1

			lmap.accessUpdatesTimestamp false
			entry.timestamp = staleDate
			lmap.get 'one'
			expect(entry.timestamp).to.be staleDate
			lmap.reapStale()
			expect(lmap.currentSize()).to.be 0

	describe '#set()', ->
		it 'reaps stale entries', ->
			lmap = new LRUMap
			called = false
			lmap.reapStale = -> called = true
			lmap.set 'hello', 'world'

			expect(called).to.be true

		it 'errors if calcSize does not return a positive number', ->
			lmap = new LRUMap calcSize: (x) -> x.size

			expect(->
				lmap.set 'negative', {size: -1}
			).to.throwError /positive/

		it 'errors if the value cannot fit', ->
			lmap = new LRUMap {maxSize: 10, calcSize: (x) -> x.size}

			expect(->
				lmap.set 'big', {size: 100}
			).to.throwError /size/

		it 'updates the current size on insert', ->
			lmap = new LRUMap {calcSize: (x) -> x.size}
			expect(lmap.currentSize()).to.be 0

			lmap.set 'one', {size: 5}
			expect(lmap.currentSize()).to.be 5

			lmap.set 'two', {size: 10}
			expect(lmap.currentSize()).to.be 15

		it 'updates the current size on redefine', ->
			lmap = new LRUMap {calcSize: (x) -> x.size}
			expect(lmap.currentSize()).to.be 0

			lmap.set 'one', {size: 5}
			expect(lmap.currentSize()).to.be 5

			lmap.set 'one', {size: 10}
			expect(lmap.currentSize()).to.be 10

		it 'sets the specified key to the specified value', ->
			lmap = new LRUMap

			# test the primitive cases
			lmap.set true, 1234
			lmap.set 'hello', null
			lmap.set 56, 'sup'

			expect(lmap.get true).to.be 1234
			expect(lmap.get 'hello').to.be null
			expect(lmap.get 56).to.be 'sup'

			# build a non-trivial object key to test ref eq
			objKey = {foo: 'bar', quux: {frank: new Date}}
			objKey.baz = objKey

			# also use a non-trivial value
			objValue = objKey.quux

			lmap.set objKey, objValue
			expect(lmap.get objKey).to.be objValue

			# finally verify that non-primitives aren't compared w/ value eq
			objKey2 = {hey: 'how are ya'}
			lmap.set objKey2, {i: 'dunno lol'}

			expect(lmap.get {hey: 'how are ya'}).to.not.be {i: 'dunno lol'}
			expect(lmap.get objKey2).to.not.be {i: 'dunno lol'}

		it 'returns the map', ->
			lmap = new LRUMap
			expect(lmap.set('foo', 'bar')).to.be lmap

		it 'causes eviction when appropriate', ->
			lmap = new LRUMap {maxSize: 10, calcSize: (x) -> x.size}
			lmap.set 'seven', {size: 7}
			lmap.set 'six', {size: 6}

			expect(lmap.get 'seven').to.be undefined
			expect(lmap.get 'six').to.eql {size: 6}

		describe 'eviction', ->
			it 'evicts the oldest entries', ->
				lmap = new LRUMap {maxSize: 10, calcSize: (x) -> x.size}
				lmap.set 'one', {size: 3}
				lmap.set 'two', {size: 3}
				lmap.set 'three', {size: 3}
				lmap.get 'one'
				lmap.set 'four', {size: 3}

				expect(lmap.get 'one').to.eql {size: 3}
				expect(lmap.get 'two').to.be undefined
				expect(lmap.get 'three').to.eql {size: 3}
				expect(lmap.get 'four').to.eql {size: 3}

			it 'updates the current size', ->
				lmap = new LRUMap {maxSize: 10, calcSize: (x) -> x.size}
				lmap.set 'one', {size: 3}
				expect(lmap.currentSize()).to.be 3
				lmap.set 'two', {size: 4}
				expect(lmap.currentSize()).to.be 7
				lmap.set 'three', {size: 5}
				expect(lmap.currentSize()).to.be 9
				lmap.set 'four', {size: 6}
				expect(lmap.currentSize()).to.be 6

			it 'reaps stales', ->
				lmap = new LRUMap
				called = false
				lmap.reapStale = -> called = true
				lmap.set 'hello', 'world'

				expect(called).to.be true

			it 'triggers onEvict correctly', ->
				called = 0

				lmap = new LRUMap {
					maxSize: 5
					calcSize: (x) -> x.size
				}

				lmap.set 'five', {size: 5}

				lmap.onEvict (k, v) ->
					called++
					expect(k).to.be 'five'
					expect(v.size).to.be 5

				lmap.set 'one', {size: 1}
				expect(called).to.be 1

				lmap.onEvict -> expect().fail('should not have evicted')
				lmap.set 'two', {size: 2}
				lmap.set 'alsotwo', {size: 2}

				lmap.onEvict (k, v) ->
					unless k in ['one', 'two']
						expect().fail 'wrong entry evicted'

					if k is 'one'
						expect(v.size).to.be 1
					else
						expect(v.size).to.be 2

					called++

				lmap.set 'three', {size: 3}
				expect(called).to.be 3

			it 'triggers onRemove', ->
				called = 0

				lmap = new LRUMap {
					maxSize: 5
					calcSize: (x) -> x.size
				}

				lmap.set 'five', {size: 5}

				lmap.onRemove (k, v) ->
					called++
					expect(k).to.be 'five'
					expect(v.size).to.be 5

				lmap.set 'one', {size: 1}
				expect(called).to.be 1

				lmap.onRemove -> expect().fail('should not have evicted')
				lmap.set 'two', {size: 2}
				lmap.set 'alsotwo', {size: 2}

				lmap.onRemove (k, v) ->
					unless k in ['one', 'two']
						expect().fail 'wrong entry evicted'

					if k is 'one'
						expect(v.size).to.be 1
					else
						expect(v.size).to.be 2

					called++

				lmap.set 'three', {size: 3}
				expect(called).to.be 3

	describe '#delete()', ->
		it 'removes the specified key and its value', ->
			lmap = new LRUMap
			lmap.set 'one', 'yessir'
			expect(lmap.get 'one').to.be 'yessir'

			lmap.delete 'one'
			expect(lmap.get 'one').to.be undefined

			objKey = {foo: 'bar'}
			objKey.baz = objKey

			lmap.set objKey, 'here i am'
			expect(lmap.get objKey).to.be 'here i am'

			lmap.delete objKey
			expect(lmap.get objKey).to.be undefined

		it 'updates the current size', ->
			lmap = new LRUMap calcSize: (x) -> x.size
			lmap.set 'one', {size: 1}
			lmap.set 'five', {size: 5}
			lmap.set 'ten', {size: 10}
			expect(lmap.currentSize()).to.be 16

			lmap.delete 'five'
			expect(lmap.currentSize()).to.be 11
			lmap.delete 'ten'
			expect(lmap.currentSize()).to.be 1
			lmap.delete 'one'
			expect(lmap.currentSize()).to.be 0

		it 'reaps stale entries after deleting the specified key', ->
			lmap = new LRUMap
			called = 0
			lmap.reapStale = -> called++
			lmap.set 'hello', 'world'
			lmap.delete 'hello'
			lmap.delete 'hello'
			lmap.delete 'nope'
			expect(called).to.be 4

		it 'returns true iff the key existed', ->
			lmap = new LRUMap
			lmap.set 'hello', 'world'
			expect(lmap.delete 'nope').to.be false
			expect(lmap.delete 'hello').to.be true
			expect(lmap.delete 'hello').to.be false

	describe '#clear()', ->
		it 'removes all entries', ->
			lmap = new LRUMap
			lmap.set 'one', 1
			lmap.set 'two', 2

			lmap.clear()
			lmap.forEach -> expect().fail 'should have no entries'

		it 'updates the current size', ->
			lmap = new LRUMap
			lmap.set 'one', 1
			lmap.set 'two', 2

			lmap.clear()
			expect(lmap.currentSize()).to.be 0

	describe '#get()', ->
		it 'returns undefined if the key does not exist'
		it 'returns the value if the key exists'
		it 'works with object keys'
		it 'works with primitive keys'
		it 'updates timestamp iff accessUpdatesTimestamp'
		it 'updates LRU order correctly'

	describe '#has()', ->
		it 'reaps stales'
		it 'says if the map contains the key'

	describe '#peek()', ->
		it 'reaps stales'
		it 'returns the value without affected timestamp or LRU order'

	describe '#sizeOf()', ->
		it 'returns the stored size of the value for the specified key'

	describe '#keys()', ->
		it 'returns an iterator to the map\'s keys'

	describe '#values()', ->
		it 'returns an iterator to the map\'s values'
		it 'updates a value\'s timestamp when the iterator reaches that value, iff accessUpdatesTimestamp'

	describe '#entries()', ->
		it 'returns an iterator to [key, value] pairs'
		it 'updates a value\'s timestamp when the iterator reaches that pair, iff accessUpdatesTimestamp'

	describe '#forEach()', ->
		it 'calls back with correct parameters for each entry in order', ->
			lmap = new LRUMap()
			lmap.set 'foo', 'whizbang'
			lmap.set 'bar', -Infinity
			called = []

			lmap.forEach (value, key, map) ->
				called.push key

				if key is 'foo'
					expect(value).to.be 'whizbang'
				else if key is 'bar'
					expect(value).to.be -Infinity
				else
					expect().fail 'bad key'

				expect(map).to.be lmap

			expect(called).to.eql ['foo', 'bar']

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

		it 'updates all timestamps, iff accessUpdatesTimestamp'

	describe '#_total', ->
		it 'is correct after basic operations', ->
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
