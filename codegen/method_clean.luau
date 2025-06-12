local VARIABLE = (value :: any).KEY

if VARIABLE then
	VARIABLE(value)
	REMOVE()
	return
end