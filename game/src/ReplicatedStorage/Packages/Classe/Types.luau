export type table = {[any]: any}

export type function sortTable(t: type, pattern: type)
	pattern = pattern:value()

	if t:is'intersection' then
		local components = t:components()

		for i, comp in components do
			if not comp:is'table' then continue end

			for k, v in comp:properties() do
				if k:value():find(pattern) then 
					continue 
				end

				comp:setproperty(k, nil)
			end
		end

		return types.intersectionof(unpack(components))
	end

	for k, v in t:properties() do
		if not k:value():find(pattern) then 
			continue 
		end

		t:setproperty(k, nil)
	end

	return t
end

export type function moveParams(src: type, 
	i: type, j: type, t: type, to: type)

	--assert(src:is'function'and i:is'singleton'and 
	--	j:is'singleton'and to:is'function')

	i = tonumber(i:value()) or 1
	t = tonumber(t:value()) or 1
	j = tonumber(j:value())

	local srcParams = src:parameters()
	if not srcParams.head then return to end

	local head = table.move(srcParams.head, 
		i, j or #srcParams.head, t, to:parameters().head or {})

	to:setparameters(head, srcParams.tail)

	return to
end

export type function setproperty(t: type, key: type, value: type)
	--assert((t:is'table' or t:is'intersection') and 
	--	key:is'singleton')

	if t:is('intersection') then
		local components = t:components()

		local sometablecomp: type
		local target: type

		for i, comp in components do
			if not comp:is'table' then continue end
			sometablecomp = comp

			if not comp:readproperty(key) then 
				continue 
			end

			target = comp
		end

		if not target then target = sometablecomp end
		if not sometablecomp then return t end

		target:setproperty(key, value)

		return types.intersectionof(unpack(components))
	end

	t:setproperty(key, value)

	return t
end

export type function find(t: type, key: type)
	if not (t:is'table' or t:is'intersection') then
		return types.any
	end

	assert(key:is'singleton')

	if t:is('intersection') then
		local components = t:components()
		local target: type

		for i, comp in components do
			if not comp:is'table' then continue end
			local read = comp:readproperty(key)

			if read then return read end
		end

		return types.any
	end

	return t:readproperty(key) or types.any
end

export type function absent(t1: type, t2: type, t3: type)
	if not (t1:is'singleton' or t1:is'nil' or t1:is'unknown') then return t1 end
	return if t1:is'unknown' or not t1:value() then t2 else not t3:is'nil' and t3 or t1
end

export type function elementsTo(t: type, e: type)
	assert(t:is'table' or t:is'intersection')

	if t:is'intersection' then
		local components = t:components()

		for i, comp in components do
			if not comp:is'table' then continue end

			for k in comp:properties() do
				comp:setproperty(k, e)
			end

		end

		return types.intersectionof(unpack(components))
	end

	for k in t:properties() do
		t:setproperty(k, e)
	end

	return t
end

return nil