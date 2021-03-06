local maps = {
	-- When queue gets a table value, it'll return a random value when processed.
	queue = { 1, 2, 3, { 1, 2, 3 } },

	[1] = {
		queue = { }, -- Maps goes herem
		fBefore = function(mapCode)
			-- Triggered before the map gets started
		end,
		fAfter = function(mapCode)
			-- Trigered after the map is started
		end
	},
	[2] = {
		queue = { }
	},
	[3] = {
		queue = { }
	}
}
do
	local shuffle = function(list)
		local index
		for i = #list, 1, -1 do
			index = math.random(i)
			list[index], list[i] = list[i], list[index]
		end
	end
	local set = function(list)
		local out = { }
		for _, index in next, list do
			out[index] = true
		end
		return out
	end

	maps.queue._next = 1
	maps.queue._lastCat = nil
	maps.queue._len = #maps.queue
	for i = 1, #maps do
		shuffle(maps[i].queue)
		maps[i] = {
			_next = 1, -- Don't change
			fBefore = maps[i].fBefore,
			fAfter = maps[i].fAfter,
			queue = maps[i].queue,
			_queueLen = #maps[i].queue,
			_hashedQueue = set(maps[i].queue)
		}
	end

	maps = setmetatable(maps, {
		__call = function(this, category)
			category = tonumber(category)
			local hasCat = not not category
			if not hasCat or not this[category] then
				category = this.queue[this.queue._next]
				if type(category) == "table" then
					category = category[math.random(#category)]
				end
				this.queue._next = this.queue._next % maps.queue._len + 1
			end
			this.queue._lastCat = category

			local map
			if hasCat then
				map = this[category].queue[math.random(this[category]._queueLen)]
			else
				map = this[category].queue[this[category]._next]

				if this[category]._next == this[category]._queueLen then
					shuffle(this[category].queue)
					this[category]._next = 1
				else
					this[category]._next = this[category]._next + 1
				end
			end

			if this[category].fBefore then
				this[category].fBefore(map)
			end

			return map
		end
	})
end

local alive, nextMap = 0
eventNewGame = function()
	nextMap = nil
	do
		local category = maps.queue._lastCat
		if maps[category].fAfter then
			local currentMap = tonumber(tfm.get.room.currentMap)
			local isMap = maps[category]._hashedQueue[currentMap]
			if not isMap and tfm.get.room.xmlMapInfo then
				isMap = maps[category]._hashedQueue[tfm.get.room.xmlMapInfo.mapCode] or maps[category]._hashedQueue[tonumber(tfm.get.room.xmlMapInfo.mapCode)]
			end
			if isMap then
				maps[category].fAfter(currentMap)
			end
		end
	end
	alive = 0
	for _ in next, tfm.get.room.playerList do
		alive = alive + 1
	end
end

eventLoop = function(currentTime, remainingTime)
	if alive < 1 or remainingTime < 500 then
		if not nextMap then
			nextMap = maps()
		end
		tfm.exec.newGame(nextMap)
	end
end

eventPlayerDied = function()
	alive = alive - 1
end
eventPlayerRespawn = function()
	alive = alive + 1
end

tfm.exec.disableAutoNewGame()
tfm.exec.setGameTime(0)
