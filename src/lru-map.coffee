Map = require 'es6-map'

module.exports = class LRUMap extends Map
	constructor: (opts = {}) ->
		@_maxSize = opts.maxSize ? (Infinity)
		@calcSize = opts.calcSize ? ((value) -> 1)
		@onEvict = opts.onEvict ? ((key, value) -> undefined)

		unless typeof @_maxSize is 'number' and @_maxSize >= 0
			throw new Error 'maxSize must be a non-negative number'

		unless typeof @calcSize is 'function'
			throw new TypeError 'calcSize must be a function'

		unless typeof @onEvict is 'function'
			throw new TypeError 'onEvict must be a function'

		@_map = new Map
		@_total = 0

	maxSize: (size) ->
		if size?
			unless size is 'number' and size >= 0
				throw new Error 'size must be a non-negative number'

			@_maxSize = size

			entries = @_map.entries()
			while @_total > @_maxSize
				oldest = entries.next().value

				break unless oldest?

				@_map.delete oldest[0]
				@_total -= oldest[1].size

				@onEvict oldest[0], oldest[1].value

		return @_maxSize

	currentSize: ->
		return @_total

	onEvict: (fn) ->
		unless typeof fn is 'function'
			throw new TypeError 'argument to onEvict must be a function'

		@onEvict = fn

	fits: (value) -> return @calcSize(value) <= @_maxSize

	wouldCauseEviction: (value) -> return @calcSize(value) + @total > @_maxSize

	set: (key, value) ->
		size = @calcSize value

		if isNaN(size) or size < 0 or typeof size isnt 'number'
			throw new Error 'calcSize() must return a non-negative number'

		if size > @_maxSize
			throw new Error "cannot store an object of that size (maxSize = #{@_maxSize}; value size = #{size})"

		entries = @_map.entries()

		while @_total + size > @_maxSize
			oldest = entries.next().value

			break unless oldest?

			@_map.delete oldest[0]
			@_total -= oldest[1].size

			@onEvict oldest[0], oldest[1].value

		@_map.set key, {size, value}
		@_total += size

		return this

	delete: (key) ->
		entry = @_map.get key

		if entry?
			@_map.delete key
			@_total -= entry.size
			return true

		return false

	clear: ->
		@_map.clear()
		@_total = 0
		return

	get: (key) ->
		entry = @_map.get key

		return undefined unless entry?

		@_map.delete key
		@_map.set key, entry

		return entry.value

	has: (key) -> return @_map.has key

	peek: (key) ->
		entry = @_map.get key
		return entry?.value

	sizeOf: (key) ->
		entry = @_map.get key
		return entry?.size

	keys: -> return @_map.keys()

	values: ->
		iter = @_map.values()

		return {
			next: -> {value: iter.next().value?.value}
		}

	entries: ->
		iter = @_map.entries()

		return {
			next: ->
				entry = iter.next().value

				if entry?
					return {value: [entry[0], entry[1].value]}
				else
					return {}
		}

	forEach: (callback, thisArg) ->
		@_map.forEach callback, thisArg
		return
