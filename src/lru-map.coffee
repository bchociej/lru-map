Map = require 'es6-map'

module.exports = class LRUMap extends Map
	constructor: (opts = {}) ->
		@_maxSize = opts.maxSize ? (Infinity)
		@_maxAge = opts.maxAge ? (Infinity)
		@_calcSize = opts.calcSize ? ((value) -> 1)
		@_user_onEvict = opts.onEvict ? ((key, value) -> undefined)
		@_user_onStale = opts.onStale ? ((key, value) -> undefined)
		@_onRemove = opts.onRemove ? ((key, value) -> undefined)
		@_accessUpdatesTimestamp = opts.accessUpdatesTimestamp ? false

		unless typeof @_maxSize is 'number' and @_maxSize >= 0
			throw new Error 'maxSize must be a non-negative number'

		unless typeof @_calcSize is 'function'
			throw new TypeError 'calcSize must be a function'

		unless typeof @_user_onEvict is 'function'
			throw new TypeError 'onEvict must be a function'

		unless typeof @_user_onStale is 'function'
			throw new TypeError 'onStale must be a function'

		unless typeof @_onRemove is 'function'
			throw new TypeError 'onRemove must be a function'

		@_onEvict = (key, value) =>
			@_onRemove(key, value)
			@_user_onEvict(key, value)

		@_onStale = (key, value) =>
			@_onRemove(key, value)
			@_user_onStale(key, value)

		@_map = new Map
		@_total = 0

	# immediate effect; reaps stales
	maxAge: (age) ->
		if age?
			unless typeof age is 'number' and age > 0
				throw new Error 'age must be a positive number of seconds'

			@_maxAge = age

			@reapStale()

		return @_maxAge

	# no immediate effect
	accessUpdatesTimestamp: (doesIt) ->
		if doesIt?
			unless typeof doesIt is 'boolean'
				throw new TypeError 'accessUpdatesTimestamp accepts a boolean'

			@_accessUpdatesTimestamp = doesIt

		return @_accessUpdatesTimestamp

	# immediate effect; reaps stales
	maxSize: (size) ->
		if size?
			unless typeof size is 'number' and size > 0
				throw new Error 'size must be a positive number'

			@_maxSize = size

			@reapStale()

			entries = @_map.entries()
			while @_total > @_maxSize
				oldest = entries.next().value

				break unless oldest?

				@_map.delete oldest[0]
				@_total -= oldest[1].size

				@_onEvict oldest[0], oldest[1].value

		return @_maxSize

	# non-mutating; idempotent
	currentSize: ->
		return @_total

	# non-mutating configuration method; no immediate effect
	onEvict: (fn) ->
		unless typeof fn is 'function'
			throw new TypeError 'argument to onEvict must be a function'

		@_onEvict = fn

	# non-mutating configuration method; no immediate effect
	onStale: (fn) ->
		unless typeof fn is 'function'
			throw new TypeError 'argument to onStale must be a function'

		@_onStale = fn

	# non-mutating configuration method; no immediate effect
	onRemove: (fn) ->
		unless typeof fn is 'function'
			throw new TypeError 'argument to onRemove must be a function'

		@_onRemove = fn

	# reaps stales; idempotent as to non-stale entries
	fits: (value) ->
		@reapStale()
		return @_calcSize(value) <= @_maxSize

	# reaps stales; idempotent as to non-stale entries
	wouldCauseEviction: (value) ->
		@reapStale()
		return @_calcSize(value) + @total > @_maxSize

	# reaps stales
	reapStale: ->
		return if @_maxAge is Infinity

		entries = @_map.entries()
		cur = entries.next().value

		while cur?
			diff = (+(new Date) - cur[1].timestamp) / 1000
			
			if diff > @_maxAge
				@_map.delete cur[0]
				@_total -= cur[1].size

				@_onStale cur[0], cur[1].value
			else
				if @_accessUpdatesTimestamp
					break

			cur = entries.next().value

	# mutates Map state; affects LRU eviction; affects staleness; reaps stales
	set: (key, value, oldTimestamp = null) ->
		@reapStale()

		size = @_calcSize value
		timestamp = +(new Date)

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

			@_onEvict oldest[0], oldest[1].value

		@_map.set key, {size, value, timestamp}
		@_total += size

		return this

	# mutates Map state; affects LRU eviction; affects staleness; reaps stales
	delete: (key) ->
		entry = @_map.get key

		if entry?
			@_map.delete key
			@_total -= entry.size
			@reapStale()
			return true
		else
			@reapStale()
			return false

	# mutates Map state
	clear: ->
		@_map.clear()
		@_total = 0
		return

	# affects LRU eviction; affects staleness if accessUpdatesTimestamp
	get: (key) ->
		entry = @_map.get key

		return undefined unless entry?

		@_map.delete key

		if @_accessUpdatesTimestamp
			entry.timestamp = +(new Date)

		@_map.set key, entry

		return entry.value

	# non-evicting; reaps stales
	has: (key) ->
		@reapStale()
		return @_map.has key

	# non-evicting; reaps stales
	peek: (key) ->
		@reapStale()
		entry = @_map.get key
		return entry?.value

	# non-evicting; reaps stales
	sizeOf: (key) ->
		@reapStale()
		entry = @_map.get key
		return entry?.size

	# non-evicting; reaps stales
	keys: ->
		@reapStale()
		return @_map.keys()

	# non-evicting; reaps stales
	values: ->
		@reapStale()
		iter = @_map.values()

		return {
			next: =>
				ev = iter.next().value

				if ev? and @_accessUpdatesTimestamp
					ev.timestamp = +(new Date)

				return {value: ev?.value}
		}

	# non-evicting; reaps stales
	entries: ->
		@reapStale()
		iter = @_map.entries()

		return {
			next: =>
				entry = iter.next().value

				if entry?
					if @_accessUpdatesTimestamp
						entry[1].timestamp = +(new Date)

					return {value: [entry[0], entry[1].value]}
				else
					return {}
		}

	# non-evicting; reaps stales
	forEach: (callback, thisArg) ->
		@reapStale()
		@_map.forEach (value, key, map) =>
			if @_accessUpdatesTimestamp
				value.timestamp = +(new Date)

			callback.call thisArg, value.value, key, this

		return
