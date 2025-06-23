local type = TYPEOF(value)

if type == "Instance" then
	DESTROY((value :: any))
elseif type == "RBXScriptConnection" then
	DISCONNECT((value :: any))
elseif type == "function" then
	(value :: any)()
elseif type == "table" then
	METHOD_CLEAN()
elseif type == "thread" then
	CLOSE((value :: any))
end
REMOVE()