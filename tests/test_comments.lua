-- This script contains many kind of comments and contains "comments" inside strings

print(" -- this is not a comment! ")
print([[
    -- neither this
    -- take care
]])

--[[
    im trying so hard to get
    [ [whitelisted] ] [[i really am]]
--]]

local a = {
    [10] = 1
}

print('hey') --[[
    what about this
]] print('how are you?')

print('i am feeling ' .. --[==[good]==] 'good') --[==[
    i think
]==]

print("that's nice!")