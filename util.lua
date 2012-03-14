--! @file   util.lua
--
-- @brief
--
-- @author  Perry Hargrave
-- @date    2012-03-14
--

-- Standard libraries.
local ipairs = ipairs
local pairs = pairs
local tonumber = tonumber
local type = type

-- Awesome stuff.
local awful = require("awful")
local capi = {
    screen = screen,
    mouse = mouse,
}

-- Shifty stuff
local config = require("shifty.config")

module("shifty.util")

local matchp = ""
local index_cache = {}
for i = 1, capi.screen.count() do index_cache[i] = {} end

-- completion : prompt completion
function completion(cmd, cur_pos, ncomp, sources, matchers)
    -- get sources and matches tables
    sources = sources or config.prompt_sources
    matchers = matchers or config.prompt_matchers

    local get_source = {
        -- gather names from config.tags
        config_tags = function()
            local ret = {}
            for n, p in pairs(config.tags) do
                table.insert(ret, n)
            end
            return ret
        end,
        -- gather names from config.apps
        config_apps = function()
            local ret = {}
            for i, p in pairs(config.apps) do
                if p.tag then
                    if type(p.tag) == "string" then
                        table.insert(ret, p.tag)
                    else
                        ret = awful.util.table.join(ret, p.tag)
                    end
                end
            end
            return ret
        end,
        -- gather names from existing tags, starting with the
        -- current screen
        existing = function()
            local ret = {}
            for i = 1, capi.screen.count() do
                local s = awful.util.cycle(capi.screen.count(),
                                            capi.mouse.screen + i - 1)
                local tags = capi.screen[s]:tags()
                for j, t in pairs(tags) do
                    table.insert(ret, t.name)
                end
            end
            return ret
        end,
        -- gather names from history
        history = function()
            local ret = {}
            local f = io.open(awful.util.getdir("cache") ..
                                    "/history_tags")
            for name in f:lines() do table.insert(ret, name) end
            f:close()
            return ret
        end,
    }

    -- if empty, match all
    if #cmd == 0 or cmd == " " then cmd = "" end

    -- match all up to the cursor if moved or no matchphrase
    if matchp == "" or
        cmd:sub(cur_pos, cur_pos+#matchp) ~= matchp then
        matchp = cmd:sub(1, cur_pos)
    end

    -- find matching commands
    local matches = {}
    for i, src in ipairs(sources) do
        local source = get_source[src]()
        for j, matcher in ipairs(matchers) do
            for k, name in ipairs(source) do
                if name:find(matcher .. matchp) then
                    table.insert(matches, name)
                end
            end
        end
    end

    -- no matches
    if #matches == 0 then return cmd, cur_pos end

    -- remove duplicates
    matches = remove_dup(matches)

    -- cycle
    while ncomp > #matches do ncomp = ncomp - #matches end

    -- put cursor at the end of the matched phrase
    if #matches == 1 then
        cur_pos = #matches[ncomp] + 1
    else
        cur_pos = matches[ncomp]:find(matchp) + #matchp
    end

    -- return match and position
    return matches[ncomp], cur_pos
end

-- count : Utility function returns the number of objects in table.
-- @param tbl A table to iterate.
-- @param obj An object to count.
-- @return The number of obj found in tbl.
function count(tbl, obj)
    local v = 0
    for i, e in pairs(tbl) do
        if obj == e then v = v + 1 end
    end
    return v
end


-- remove_dup : used by shifty.completion when more than one
--              tag at a position exists
-- @param tbl The table to remove duplicates from
-- @return A new table that copied `tbl` but does not contain duplicates.
function remove_dup(tbl)
    local v = {}
    for i, entry in ipairs(tbl) do
        if util.count(v, entry) == 0 then v[#v+ 1] = entry end
    end
    return v
end


-- select : Chooses the first non-nil argument
-- @param args - table of arguments
function select(args)
    for i, a in pairs(args) do
        if a ~= nil then
            return a
        end
    end
end


-- isnumber : Checks if the string is convertible to a number.
-- @param s A string to evaluate.
-- @return True if `s` can be converted to a number.
function isnumber(s)
    if tonumber(s) ~= nil then
        return true
    else
        return false
    end
end
