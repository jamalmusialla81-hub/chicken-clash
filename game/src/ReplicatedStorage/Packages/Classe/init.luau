local Types = require(script.Types)

type Meta<A, M, E> = setmetatable<M, {
	a: A & index<Types.find<E, 'phantomMeta'>, 'a'>,
	m: M & index<Types.find<E, 'phantomMeta'>, 'm'>, 
	e: E
}>

type Super<E> = Types.moveParams<index<E, '_init'>
, '1', nil, '1', () -> ()>

export type Self<M> = index<getmetatable<M>, 'a'>
& index<getmetatable<M>, 'm'>

export type ISelf<M> = Types.elementsTo<
	index<getmetatable<M>, 'a'>, any>

export type Classe<M> = {
	childs: {[number]: any},
	overrides: Types.table,
	parent: index<getmetatable<M>, 'e'>,

	phantomMeta: getmetatable<M>,
	meta: {
		__index: index<getmetatable<M>, 'm'>,
	},

	new: Types.moveParams<Types.find<
		index<getmetatable<M>, 'm'>, 'construct'>, 
	'2', nil, '1', () -> Types.sortTable<Self<M>, '^_'>>,

	initChain: {(self: Types.table, ...any) -> ()},

	_construct: Types.find<index<
		getmetatable<M>, 'm'>, 'construct'>,
}


local Classe, __meta = {}, {}

function __meta:__newindex(key: any, value: any)
	if value == nil then
		value = self.parent.meta.__index[key]
		self.overrides[key] = nil
	else
		self.overrides[key] = true
	end

	self.meta.__index[key] = value

	for i, child in self.childs do
		if child.overrides[key] then continue end
		child.meta.__index[key] = value
	end
end

table.freeze(__meta)

Classe.build = function<M>(meta: M): Classe<M>
	assert(type(meta)=='table', 'Meta must be a table')

	local construct = meta.construct
	assert(construct, "Construct function not found!")

	local self = {
		childs = {},
		overrides = {},
		meta = meta,
	}

	local parent = getmetatable(meta).e
	setmetatable(meta, nil)

	self.parent = parent

	local initChain = nil; if parent then
		table.insert(parent.childs, self)

		for k, v in parent.meta.__index do
			if meta[k] == nil then meta[k] = v
				continue 
			end 
			self.overrides[k] = true
		end

		if meta.init then
			initChain = if parent.initChaing then 
				table.clone(parent.initChain)
				else {}

			table.insert(initChain, meta.init)
			table.freeze(initChain)
		else
			initChain = parent.initChain
		end

	else 
		initChain = if meta.init then 
			table.freeze{meta.init} 
			else nil 
	end

	self.initChain = initChain

	meta.__index = {}
	meta.construct, meta.init = nil, nil;
	self._construct = construct

	for index, data in meta do
		if type(index)=='string'and
			index:find('^__') then

			continue
		end

		meta[index] = nil
		meta.__index[index] = data
	end

	if initChain then
		local initChainLen = #initChain

		function self.new(...: any)
			local obj = {}; construct(obj, ...)
			setmetatable(obj, meta)

			for i = 1, initChainLen do
				initChain[i](obj)
			end

			return obj
		end
	else
		function self.new(...: any)
			local obj = {}; construct(obj, ...)
			setmetatable(obj, meta)

			return obj
		end
	end

	setmetatable(self, __meta)
	return table.freeze(self)
end

Classe.meta = function<A, M, E>(attrs: A, meta: M, 
	extends: E?): (Meta<A, M, E>, Super<E>?)

	assert(type(meta)=='table', 'Meta must be a table')

	setmetatable(meta, table.freeze{
		e = extends,	
	})

	return meta, extends and extends._construct
end

return table.freeze(Classe)