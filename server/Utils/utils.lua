Utils = {}

-- operand: 1 = OR, 3 = XOR, 4 = AND
function Utils.bit_oper(a, b, operand)
	local r, m, s = 0, 2^31, nil
	repeat
		s,a,b = a+b+m, a%m, b%m
		r,m = r + m*operand%(s-a-b), m/2
	until m < 1
	return math.floor(r)
end

-- Bitwise XOR operation
function Utils.bit_xor(value1, value2)
	return Utils.bit_oper(value1, value2, 3)
end

-- gets bits from least significant to most
function Utils.getbits(value, startIndex, numBits)
	return math.floor(Utils.bit_rshift(value, startIndex) % Utils.bit_lshift(1, numBits))
end

-- Shifts bits of 'value', 'n' bits to the right
function Utils.bit_rshift(value, n)
	return math.floor(value / (2 ^ n))
end

-- Shifts bits of 'value', 'n' bits to the left
function Utils.bit_lshift(value, n)
	return math.floor(value) * (2 ^ n)
end


return Utils