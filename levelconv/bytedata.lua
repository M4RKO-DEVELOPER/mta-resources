function float2hex (n)
    if n == 0.0 then return 0.0 end

    local sign = 0
    if n < 0.0 then
        sign = 0x80
        n = -n
    end

    local mant, expo = math.frexp(n)
    local hext = {}

    if mant ~= mant then
        hext[#hext+1] = string.char(0xFF, 0x88, 0x00, 0x00)

    elseif mant == math.huge or expo > 0x80 then
        if sign == 0 then
            hext[#hext+1] = string.char(0x7F, 0x80, 0x00, 0x00)
        else
            hext[#hext+1] = string.char(0xFF, 0x80, 0x00, 0x00)
        end

    elseif (mant == 0.0 and expo == 0) or expo < -0x7E then
        hext[#hext+1] = string.char(sign, 0x00, 0x00, 0x00)

    else
        expo = expo + 0x7E
        mant = (mant * 2.0 - 1.0) * math.ldexp(0.5, 24)
		mant = math.floor ( mant )
        hext[#hext+1] = string.char(sign + math.floor(expo / 0x2),
                                    (expo % 0x2) * 0x80 + math.floor(mant / 0x10000),
                                    math.floor(mant / 0x100) % 0x100,
                                    mant % 0x100)
    end

    return tonumber(string.gsub(table.concat(hext),"(.)",
                                function (c) return string.format("%02X%s",string.byte(c),"") end), 16)
end

function dataToBytes(...)
	local arg = {...}
	local format = arg[1]
	local datanum = 2
	local fcnum = 1
	local flen = format:len()
	local bstr,bstr_i = {},1
	while fcnum <= flen do
		local count
		local byte = format:byte(fcnum)
		fcnum = fcnum+1
		-- Проверяем, есть ли числа в формате
		if byte < 58 then
			count = byte-48
			while true do
				byte = format:byte(fcnum)
				fcnum = fcnum+1
				if byte < 58 then
					count = count*10+byte-48
				else
					break
				end
			end
		else
			count = 1
		end

		local unsigned
		if byte == 117 then
			unsigned = true
			byte = format:byte(fcnum)
			fcnum = fcnum+1
		end

		if byte == 76 then							--big-endian long long L
			while count > 0 do
				local data = arg[datanum]%0x10000000000000000
				local value = string.char(
					math.floor(data/0x100000000000000%0x100),
					math.floor(data/0x1000000000000  %0x100),
					math.floor(data/0x10000000000    %0x100),
					math.floor(data/0x100000000      %0x100),
					math.floor(data/0x1000000        %0x100),
					math.floor(data/0x10000          %0x100),
					math.floor(data/0x100            %0x100),
					math.floor(data                  %0x100))
				table.insert ( bstr, value )
				bstr_i,datanum = bstr_i+1,datanum+1
				count = count-1
			end
		elseif byte == 73 then						--big-endian long I
			while count > 0 do
				local data = arg[datanum]%0x100000000
				local value = string.char(
					math.floor(data/0x1000000        %0x100),
					math.floor(data/0x10000          %0x100),
					math.floor(data/0x100            %0x100),
					math.floor(data                  %0x100))
				table.insert ( bstr, value )
				bstr_i,datanum = bstr_i+1,datanum+1
				count = count-1
			end
		elseif byte == 83 then						--big-endian short S(2 bytes)
			while count > 0 do
				local data = arg[datanum]%0x10000
				local value = string.char(
					math.floor(data/0x100            %0x100),
					math.floor(data                  %0x100))
				table.insert ( bstr, value )
				bstr_i,datanum = bstr_i+1,datanum+1
				count = count-1
			end
		elseif byte == 108 then						--little-endian long long
			while count > 0 do
				local data = arg[datanum]%0x10000000000000000
				local value = string.char(
					math.floor(data                  %0x100),
					math.floor(data/0x100            %0x100),
					math.floor(data/0x10000          %0x100),
					math.floor(data/0x1000000        %0x100),
					math.floor(data/0x100000000      %0x100),
					math.floor(data/0x10000000000    %0x100),
					math.floor(data/0x1000000000000  %0x100),
					math.floor(data/0x100000000000000%0x100))
				table.insert ( bstr, value )
				bstr_i,datanum = bstr_i+1,datanum+1
				count = count-1
			end
		elseif byte == 105 then						--little-endian long i(4 bytes)
			while count > 0 do
				--outputDebugString ( format )
				local data = arg[datanum]%0x100000000
				local value = string.char(
					math.floor(data                  %0x100),
					math.floor(data/0x100            %0x100),
					math.floor(data/0x10000          %0x100),
					math.floor(data/0x1000000        %0x100))
				table.insert ( bstr, value )
				bstr_i,datanum = bstr_i+1,datanum+1
				count = count-1
			end
		elseif byte == 115 then						--little-endian short
			while count > 0 do
				local data = arg[datanum]%0x10000
				local value = string.char(
					math.floor(data                  %0x100),
					math.floor(data/0x100            %0x100))
				table.insert ( bstr, value )
				bstr_i,datanum = bstr_i+1,datanum+1
				count = count-1
			end
		elseif byte == 66 or byte == 98 then		--byte
			while count > 0 do
				local data = arg[datanum]
				local value = string.char(
					math.floor(data                  %0x100))
				table.insert ( bstr, value )
				bstr_i,datanum = bstr_i+1,datanum+1
				count = count-1
			end
		elseif byte == 70 or byte == 102 then		--float
			while count > 0 do
				local data = arg[datanum]
				--[[local datapos = math.abs(data)
				local intval
				if data ~= data then -- WTF?
					intval = 0xFFFFFFFF
				else
					local exp,fract
					exp = math.floor(math.log(datapos,2))
					if exp < -126 then
						exp,fract = 0,0
					elseif exp > 127 then
						exp,fract = 255,0
					else
						fract = (datapos/(2^exp)-1)*0x800000
						exp = exp+127
					end
					intval = (data < 0 and 0x80000000 or 0)+exp*0x800000+fract
				end]]

				local intval = float2hex(data)
				if byte == 70 then					--big-endian
					local value = string.char(
						math.floor(intval/0x1000000%0x100),
						math.floor(intval/0x10000  %0x100),
						math.floor(intval/0x100    %0x100),
						math.floor(intval          %0x100))
					table.insert ( bstr, value )
				else						--little-endian
					--outputDebugString(math.floor(intval          %0x100))
					local value = string.char(
						math.floor(intval          %0x100),
						math.floor(intval/0x100    %0x100),
						math.floor(intval/0x10000  %0x100),
						math.floor(intval/0x1000000%0x100))
					table.insert ( bstr, value )
				end
				bstr_i,datanum = bstr_i+1,datanum+1
				count = count-1
			end
		elseif byte == 68 or byte == 100 then		--double
			while count > 0 do
				local data = arg[datanum]
				local datapos = math.abs(data)
				local intval
				if data ~= data then
					intval = 0xFFFFFFFFFFFFFFFF
				else
					local exp,fract
					exp = math.floor(math.log(datapos,2))
					if exp < -1023 then
						exp,fract = 0,0
					elseif exp >= 1024 then
						exp,fract = 2046,0
					else
						fract = (datapos/(2^exp)-1)*(2^52)
						exp = exp+1023
					end
					intval = (data < 0 and 0x8000000000000000 or 0)+exp*(2^52)+fract
				end
				
				if byte == 68 then					--big-endian
					local value = string.char(
						math.floor(intval/0x100000000000000%0x100),
						math.floor(intval/0x1000000000000  %0x100),
						math.floor(intval/0x10000000000    %0x100),
						math.floor(intval/0x100000000      %0x100),
						math.floor(intval/0x1000000        %0x100),
						math.floor(intval/0x10000          %0x100),
						math.floor(intval/0x100            %0x100),
						math.floor(intval                  %0x100))
					table.insert ( bstr, value )
				else								--little-endian
					local value = string.char(
						math.floor(intval                  %0x100),
						math.floor(intval/0x100            %0x100),
						math.floor(intval/0x10000          %0x100),
						math.floor(intval/0x1000000        %0x100),
						math.floor(intval/0x100000000      %0x100),
						math.floor(intval/0x10000000000    %0x100),
						math.floor(intval/0x1000000000000  %0x100),
						math.floor(intval/0x100000000000000%0x100))
					table.insert ( bstr, value )
				end
				bstr_i,datanum = bstr_i+1,datanum+1
				count = count-1
			end
		elseif byte == 99 then						--string
			local data = arg[datanum]
			local datalen = data:len()
			if datalen < count then
				local value = data..('\0'):rep(count-datalen)
				table.insert ( bstr, value )
			elseif datalen == count then
				local value = data
				table.insert ( bstr, value )
			elseif datalen > count then
				local value = data:sub(1,count)
				table.insert ( bstr, value )
			end
			bstr_i,datanum = bstr_i+1,datanum+1
		end

	end
	return table.concat(bstr)
end

function bytesToData(format,bstr)
	local data = {}
	local datanum = 1
	local fcnum = 1
	local flen = format:len()
	local bstr_i = 1
	while fcnum <= flen do
		local count
		local byte = format:byte(fcnum)
		fcnum = fcnum+1
		if byte < 58 then
			count = byte-48
			while true do
				byte = format:byte(fcnum)
				fcnum = fcnum+1
				if byte < 58 then
					count = count*10+byte-48
				else
					break
				end
			end
		else
			count = 1
		end

		local unsigned
		if byte == 117 then
			unsigned = true
			byte = format:byte(fcnum)
			fcnum = fcnum+1
		end

		if byte == 76 then							--big-endian long long
			while count > 0 do
				local i1,i2,i3,i4,i5,i6,i7,i8 = bstr:byte(bstr_i,bstr_i+7)
				local this_data = i1*0x100000000000000+i2*0x1000000000000+i3*0x10000000000+i4*0x100000000+i5*0x1000000+i6*0x10000+i7*0x100+i8
				if not unsigned and this_data > 0x7FFFFFFFFFFFFFFF then
					this_data = this_data-0x10000000000000000
				end
				data[datanum] = this_data
				bstr_i,datanum = bstr_i+8,datanum+1
				count = count-1
			end
		elseif byte == 73 then						--big-endian long
			while count > 0 do
				local i1,i2,i3,i4 = bstr:byte(bstr_i,bstr_i+3)
				local this_data = i1*0x1000000+i2*0x10000+i3*0x100+i4
				if not unsigned and this_data > 0x7FFFFFFF then
					this_data = this_data-0x100000000
				end
				data[datanum] = this_data
				bstr_i,datanum = bstr_i+4,datanum+1
				count = count-1
			end
		elseif byte == 83 then						--big-endian short
			while count > 0 do
				local i1,i2 = bstr:byte(bstr_i,bstr_i+1)
				local this_data = i1*0x100+i2
				if not unsigned and this_data > 0x7FFF then
					this_data = this_data-0x10000
				end
				data[datanum] = this_data
				bstr_i,datanum = bstr_i+2,datanum+1
				count = count-1
			end
		elseif byte == 108 then						--little-endian long long
			while count > 0 do
				local i1,i2,i3,i4,i5,i6,i7,i8 = bstr:byte(bstr_i,bstr_i+7)
				local this_data = i8*0x100000000000000+i7*0x1000000000000+i6*0x10000000000+i5*0x100000000+i4*0x1000000+i3*0x10000+i2*0x100+i1
				if not unsigned and this_data > 0x7FFFFFFFFFFFFFFF then
					this_data = this_data-0x10000000000000000
				end
				data[datanum] = this_data
				bstr_i,datanum = bstr_i+8,datanum+1
				count = count-1
			end
		elseif byte == 105 then						--little-endian long
			while count > 0 do
				local i1,i2,i3,i4 = bstr:byte(bstr_i,bstr_i+3)
				local this_data = i4*0x1000000+i3*0x10000+i2*0x100+i1
				if not unsigned and this_data > 0x7FFFFFFF then
					this_data = this_data-0x100000000
				end
				data[datanum] = this_data
				bstr_i,datanum = bstr_i+4,datanum+1
				count = count-1
			end
		elseif byte == 115 then						--little-endian short
			while count > 0 do
				local i1,i2 = bstr:byte(bstr_i,bstr_i+1)
				local this_data = i2*0x100+i1
				if not unsigned and this_data > 0x7FFF then
					this_data = this_data-0x10000
				end
				data[datanum] = this_data
				bstr_i,datanum = bstr_i+2,datanum+1
				count = count-1
			end
		elseif byte == 66 or byte == 98 then		--byte
			while count > 0 do
				local this_data = bstr:byte(bstr_i)
				if not unsigned and this_data > 0x7F then
					this_data = this_data-0x100
				end
				data[datanum] = this_data
				bstr_i,datanum = bstr_i+1,datanum+1
				count = count-1
			end
		elseif byte == 70 or byte == 102 then		--float
			while count > 0 do
				local i1,i2,i3,i4
				if byte == 70 then					--big-endian
					i1,i2,i3,i4 = bstr:byte(bstr_i,bstr_i+3)
				else								--little-endian
					i4,i3,i2,i1 = bstr:byte(bstr_i,bstr_i+3)
				end
				local fract = i2%0x80*0x10000+i3*0x100+i4
				local exp = math.floor(((i1%0x80)*0x100+i2)/0x80)-127
				local this_data = 2^exp*(fract/0x800000+1)
				if i1 > 0x80 then this_data = -this_data end
				data[datanum] = this_data
				bstr_i,datanum = bstr_i+4,datanum+1
				count = count-1
			end
		elseif byte == 68 or byte == 100 then		--double
			while count > 0 do
				local i1,i2,i3,i4,i5,i6,i7,i8
				if byte == 70 then					--big-endian
					i1,i2,i3,i4,i5,i6,i7,i8 = bstr:byte(bstr_i,bstr_i+7)
				else								--little-endian
					i8,i7,i6,i5,i4,i3,i2,i1 = bstr:byte(bstr_i,bstr_i+7)
				end
				local fract = (i2%0x10)*0x1000000000000+i3*0x10000000000+i4*0x100000000+i5*0x1000000+i6*0x10000+i7*0x100+i8
				local exp = math.floor(((i1%0x80)*0x100+i2)/0x10)-1023
				local this_data = 2^exp*(fract/(2^52)+1)
				if i1 > 0x80 then this_data = -this_data end
				data[datanum] = this_data
				bstr_i,datanum = bstr_i+8,datanum+1
				count = count-1
			end
		elseif byte == 99 then						--string
			local this_data = bstr:sub(bstr_i,bstr_i+count-1)
			local strend = this_data:find('\0',1,true)
			if strend then this_data = this_data:sub(1,strend-1) end
			data[datanum] = this_data
			bstr_i,datanum = bstr_i+count,datanum+1
		end

	end
	return unpack(data)
end

