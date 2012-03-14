-- shifty/tag.lua
--
-- @author resixian (aka bioe007) &lt;resixian@gmail.com&gt;
--
-- http://awesome.naquadah.org/wiki/index.php?title=Shifty

-- environment
local math = math
local type = type
local ipairs = ipairs
local table = table
local beautiful = require("beautiful")
local awful = require("awful")
local pairs = pairs
local setmetatable = setmetatable
local tonumber = tonumber
local capi = {
    client = client,
    tag = tag,
    image = image,
    screen = screen,
    mouse = mouse,
    root = root,
    timer = timer
}

local config = require("shifty.config")
local util = require("shifty.util")

module("shifty.tag")

local matchp = ""
local index_cache = {}
for i = 1, capi.screen.count() do index_cache[i] = {} end

local function _stub(s) print("STUB: " .. s or "NIL PASSED") end

get = {}
-- get.list_by_name: matches string 'name' to tag objects
-- @param name : tag name to find
-- @param scr : screen to look for tags on
-- @return table of tag objects or nil
function get.list_by_name(name, scr)
    local ret = {}
    local a, b = scr or 1, scr or capi.screen.count()
    for s = a, b do
        for i, t in ipairs(capi.screen[s]:tags()) do
            if name == t.name then
                table.insert(ret, t)
            end
        end
    end
    if #ret > 0 then return ret end
end

function get.by_name(name, scr, idx)
    local ts = get.list_by_name(name, scr)
    if ts then return ts[idx or 1] end
end

function get.by_position(pos, scr)
    local v = nil
    local existing = {}
    local selected = nil
    local scr = scr_arg or capi.mouse.screen or 1

    -- search for existing tag assigned to pos
    for i = 1, capi.screen.count() do
        for j, t in ipairs(capi.screen[i]:tags()) do
            if awful.tag.getproperty(t, "position") == pos then
                table.insert(existing, t)
                if t.selected and i == scr then
                    selected = #existing
                end
            end
        end
    end

    if #existing > 0 then
        -- if making another of an existing tag, return the end of
        -- the list the optional 2nd argument decides if we return
        -- only
        if scr_arg ~= nil then
            for _, tag in pairs(existing) do
                if tag.screen == scr_arg then return tag end
            end
            -- no tag with a position and scr_arg match found, clear
            -- v and allow the subseqeunt conditions to be evaluated
            v = nil
        else
            v = (selected and
                    existing[awful.util.cycle(#existing, selected + 1)]) or
                    existing[1]
        end
    end

    if not v then
        -- search for preconf with 'pos' and create it
        for i, j in pairs(config.tags) do
            if j.position == pos then
                v = add({name = i,
                        position = pos,
                        noswitch = not switch})
            end
        end
    end

    if not v then
        -- not existing, not preconfigured
        v = add({position = pos,
                rename = pos .. ':',
                no_selectall = true,
                noswitch = not switch})
    end
    return v
end

get.index = {}
-- get.index: Finds index of a tag object.
-- @param scr : screen number to look for tag on
-- @param tag : the tag object to find
-- @return the index [or zero] or end of the list
local function _get_index(_, scr, tag)
    for i, t in ipairs(capi.screen[scr]:tags()) do
        if t == tag then return i end
    end
end

setmetatable(get.index,
             {__call = _get_index})


-- get.index.by_position: Translate shifty position to tag index.
-- @param pos: position (an integer)
-- @param scr: screen number
function get.index.by_position(pos, scr)
    local v = 1
    if pos and scr then
        for i = #capi.screen[scr]:tags() , 1, -1 do
            local t = capi.screen[scr]:tags()[i]
            if awful.tag.getproperty(t, "position") and
                awful.tag.getproperty(t, "position") <= pos then
                v = i + 1
                break
            end
        end
    end
    return v
end


local _cb_rename_prompt = function()
    if t.name == before then
        if awful.tag.getproperty(t, "initial") then del(t) end
    else
        awful.tag.setproperty(t, "initial", true)
        set(t)
    end
    _cb_keys(capi.screen[scr])
    t:emit_signal("property::name")
end

--rename
--@param tag: tag object to be renamed
--@param prefix: if any prefix is to be added
--@param no_selectall:
function rename(tag, prefix, no_selectall)
    local theme = beautiful.get()
    local t = tag or awful.tag.selected(capi.mouse.screen)
    local scr = t.screen
    local bg = nil
    local fg = nil
    local text = prefix or t.name
    local before = t.name

    if t == awful.tag.selected(scr) then
        bg = theme.bg_focus or '#535d6c'
        fg = theme.fg_urgent or '#ffffff'
    else
        bg = theme.bg_normal or '#222222'
        fg = theme.fg_urgent or '#ffffff'
    end

    awful.prompt.run(
        {
            fg_cursor = fg,
            bg_cursor = bg,
            ul_cursor = "single",
            text = text,
            selectall = not no_selectall
        },
        config.taglist[scr][get.index(scr, t) * 2],
        function(name)
            if name:len() > 0 then t.name = name; end
        end,
        completion,
        awful.util.getdir("cache") .. "/history_tags",
        nil,
        _cb_rename_prompt
        )
end


move = {}
-- _move
-- @pos Target position, integer
-- @scr Target screen, integer
local function _move(pos, scr, t)
    local target_tag = target_tag or selected()
    local scr = target_tag.screen
    local tmp_tags = capi.screen[scr]:tags()

    if (not new_index) or (new_index < 1) or (new_index > #tmp_tags) then
        return
    end

    for i, t in ipairs(tmp_tags) do
        if t == target_tag then
            table.remove(tmp_tags, i)
            break
        end
    end

    table.insert(tmp_tags, new_index, target_tag)
    capi.screen[scr]:tags(tmp_tags)
end

-- tagtoscr : move an entire tag to another screen
--
-- @param scr : the screen to move tag to
-- @param t : the tag to be moved [awful.tag.selected()]
-- @return the tag
function move.screen(scr, t)
    -- break if called with an invalid screen number
    if not scr or scr < 1 or scr > capi.screen.count() then return end
    -- tag to move
    local otag = t or awful.tag.selected()

    otag.screen = scr
    -- set screen and then reset tag to order properly
    if #otag:clients() > 0 then
        for _ , c in ipairs(otag:clients()) do
            if not c.sticky then
                c.screen = scr
                c:tags({otag})
            else
                awful.client.toggletag(otag, c)
            end
        end
    end
    return otag
end

-- move.position
-- @param pos An integer
move.position = function(pos, t) _move(pos, nil, t) end

move.index = function()
    -- I think maybe this should only work if .position = nil
    _stub()
end

-- move.left : Moves a tag to the left based on position.
function move.left(t) move.position(t.position -1) end

-- move.right : Moves a tag to the right based on position.
function move.right(t) move.position(t.position +1) end

setmetatable(move,
             {__call = _move})

local function _guess_position(args, preset, t)
    if not (args.position or preset.position) and config.guess_position then
        local num = t.name:find('^[1-9]')
        if num then return tonumber(t.name:sub(1, 1)) end
    end
end

local function _select_layout(preset, scr)
    -- allow preset.layout to be a table to provide a different layout per
    -- screen for a given tag
    -- FIXME:
    -- if preset and preset.layout[scr] then
    --     return preset.layout[scr]
    -- end
    return preset.layout or config.defaults.layout
end

local function _select_screen(...)
    local scr = capi.mouse.screen
    for _, v in pairs({...}) do
        if util.isnumber(v) then break end
    end

    return math.min(scr, capi.screen.count())
end

-- set : set a tags properties
-- @param t: the tag
-- @param args : a table of optional (?) tag properties
-- @return t - the tag object
function set(t, args)
    if not t then return end
    if not args then args = {} end

    -- set the name
    t.name = args.name or t.name

    -- attempt to load preset on initial run
    local preset = (awful.tag.getproperty(t, "initial") and config.tags[t.name])
                    or {}

    local scr = _select_screen(args.screen,
                               preset.screen,
                               t.screen,
                               capi.mouse.screen)

    local tags = capi.screen[scr]:tags()

    -- try to guess position from the name
    local guessed_position = _guess_position(args, preset, t)

    local preset_layout = _select_layout(preset, scr)

    -- select from args, preset, getproperty,
    -- config.defaults.configs or defaults
    local props = {
        layout = util.select{args.layout, preset_layout,
                        awful.tag.getproperty(t, "layout"),
                        config.defaults.layout, awful.layout.suit.tile},
        mwfact = util.select{args.mwfact, preset.mwfact,
                        awful.tag.getproperty(t, "mwfact"),
                        config.defaults.mwfact, 0.55},
        nmaster = util.select{args.nmaster, preset.nmaster,
                        awful.tag.getproperty(t, "nmaster"),
                        config.defaults.nmaster, 1},
        ncol = util.select{args.ncol, preset.ncol,
                        awful.tag.getproperty(t, "ncol"),
                        config.defaults.ncol, 1},
        matched = util.select{args.matched,
                        awful.tag.getproperty(t, "matched")},
        exclusive = util.select{args.exclusive, preset.exclusive,
                        awful.tag.getproperty(t, "exclusive"),
                        config.defaults.exclusive},
        persist = util.select{args.persist, preset.persist,
                        awful.tag.getproperty(t, "persist"),
                        config.defaults.persist},
        nopopup = util.select{args.nopopup, preset.nopopup,
                        awful.tag.getproperty(t, "nopopup"),
                        config.defaults.nopopup},
        leave_kills = util.select{args.leave_kills, preset.leave_kills,
                        awful.tag.getproperty(t, "leave_kills"),
                        config.defaults.leave_kills},
        max_clients = util.select{args.max_clients, preset.max_clients,
                        awful.tag.getproperty(t, "max_clients"),
                        config.defaults.max_clients},
        position = util.select{args.position, preset.position, guessed_position,
                        awful.tag.getproperty(t, "position")},
        icon = util.select{args.icon and capi.image(args.icon),
                        preset.icon and capi.image(preset.icon),
                        awful.tag.getproperty(t, "icon"),
                    config.defaults.icon and capi.image(config.defaults.icon)},
        icon_only = util.select{args.icon_only, preset.icon_only,
                        awful.tag.getproperty(t, "icon_only"),
                        config.defaults.icon_only},
        sweep_delay = util.select{args.sweep_delay, preset.sweep_delay,
                        awful.tag.getproperty(t, "sweep_delay"),
                        config.defaults.sweep_delay},
        overload_keys = util.select{args.overload_keys, preset.overload_keys,
                        awful.tag.getproperty(t, "overload_keys"),
                        config.defaults.overload_keys},
    }

    -- get layout by name if given as string
    if type(props.layout) == "string" then
        props.layout = config.getlayout(props.layout)
    end

    -- set keys
    if args.keys or preset.keys then
        local keys = awful.util.table.join(config.globalkeys,
        args.keys or preset.keys)
        if props.overload_keys then
            props.keys = keys
        else
            props.keys = squash_keys(keys)
        end
    end

    -- calculate desired taglist index
    local index = args.index or preset.index or config.defaults.index
    local rel_index = args.rel_index or
    preset.rel_index or
    config.defaults.rel_index
    local sel = awful.tag.selected(scr)
    --TODO: what happens with rel_idx if no tags selected
    local sel_idx = (sel and get.index(scr, sel)) or 0
    local t_idx = get.index(scr, t)
    local limit = (not t_idx and #tags + 1) or #tags
    local idx = nil

    if rel_index then
        idx = awful.util.cycle(limit, (t_idx or sel_idx) + rel_index)
    elseif index then
        idx = awful.util.cycle(limit, index)
    elseif props.position then
        idx = get.index.by_position(props.position, scr)
        if t_idx and t_idx < idx then idx = idx - 1 end
    elseif config.remember_index and index_cache[scr][t.name] then
        idx = index_cache[scr][t.name]
    elseif not t_idx then
        idx = #tags + 1
    end

    -- if we have a new index, remove from old index and insert
    if idx then
        if t_idx then table.remove(tags, t_idx) end
        table.insert(tags, idx, t)
        index_cache[scr][t.name] = idx
    end

    -- set tag properties and push the new tag table
    capi.screen[scr]:tags(tags)
    for prop, val in pairs(props) do awful.tag.setproperty(t, prop, val) end

    -- execute run/spawn
    if awful.tag.getproperty(t, "initial") then
        local spawn = args.spawn or preset.spawn or config.defaults.spawn
        local run = args.run or preset.run or config.defaults.run
        if spawn and args.matched ~= true then
            awful.util.spawn_with_shell(spawn, scr)
        end
        if run then run(t) end
        awful.tag.setproperty(t, "initial", nil)
    end


    return t
end

function shift_next() set(awful.tag.selected(), {rel_index = 1}) end
function shift_prev() set(awful.tag.selected(), {rel_index = -1}) end

--add : adds a tag
--@param args: table of optional arguments
function add(args)
    if not args then args = {} end
    local name = args.name or " "

    -- initialize a new tag object and its data structure
    local t = capi.tag{name = name}

    -- tell set() that this is the first time
    awful.tag.setproperty(t, "initial", true)

    -- apply tag settings
    set(t, args)

    -- unless forbidden or if first tag on the screen, show the tag
    if not (awful.tag.getproperty(t, "nopopup") or args.noswitch) or
        #capi.screen[t.screen]:tags() == 1 then
        awful.tag.viewonly(t)
    end

    -- get the name or rename
    if args.name then
        t.name = args.name
    else
        -- FIXME: hack to delay rename for un-named tags for
        -- tackling taglist refresh which disabled prompt
        -- from being rendered until input
        awful.tag.setproperty(t, "initial", true)
        local f
        if args.position then
            f = function() rename(t, args.rename, true); tmr:stop() end
        else
            f = function() rename(t); tmr:stop() end
        end
        tmr = capi.timer({timeout = 0.01})
        tmr:add_signal("timeout", f)
        tmr:start()
    end

    return t
end

--del : delete a tag
--@param tag : the tag to be deleted [current tag]
function del(tag)
    local scr = (tag and tag.screen) or capi.mouse.screen or 1
    local tags = capi.screen[scr]:tags()
    local sel = awful.tag.selected(scr)
    local t = tag or sel
    local idx = get.index(scr, t)

    -- return if tag not empty (except sticky)
    local clients = t:clients()
    local sticky = 0
    for i, c in ipairs(clients) do
        if c.sticky then sticky = sticky + 1 end
    end
    if #clients > sticky then return end

    -- store index for later
    index_cache[scr][t.name] = idx

    -- remove tag
    t.screen = nil

    -- if the current tag is being deleted, restore from history
    if t == sel and #tags > 1 then
        awful.tag.history.restore(scr, 1)
        -- this is supposed to cycle if history is invalid?
        -- e.g. if many tags are deleted in a row
        if not awful.tag.selected(scr) then
            awful.tag.viewonly(tags[awful.util.cycle(#tags, idx - 1)])
        end
    end

    -- FIXME: what is this for??
    if capi.client.focus then capi.client.focus:raise() end
end

-- sweep : hook function that marks tags as used, visited,
-- deserted also handles deleting used and empty tags
function _cb_sweep()
    for s = 1, capi.screen.count() do
        for i, t in ipairs(capi.screen[s]:tags()) do
            local clients = t:clients()
            local sticky = 0
            for i, c in ipairs(clients) do
                if c.sticky then sticky = sticky + 1 end
            end
            if #clients == sticky then
                if awful.tag.getproperty(t, "used") and
                    not awful.tag.getproperty(t, "persist") then
                    if awful.tag.getproperty(t, "deserted") or
                        not awful.tag.getproperty(t, "leave_kills") then
                        local delay = awful.tag.getproperty(t, "sweep_delay")
                        if delay then
                            local f = function()
                                        del(t); tmr:stop()
                                    end
                            tmr = capi.timer({timeout = delay})
                            tmr:add_signal("timeout", f)
                            tmr:start()
                        else
                            del(t)
                        end
                    else
                        if awful.tag.getproperty(t, "visited") and
                            not t.selected then
                            awful.tag.setproperty(t, "deserted", true)
                        end
                    end
                end
            else
                awful.tag.setproperty(t, "used", true)
            end
            if t.selected then
                awful.tag.setproperty(t, "visited", true)
            end
        end
    end
end

-- _cb_keys : Hook function that sets keybindings per tag.
-- @param s
function _cb_keys(s)
    local sel = awful.tag.selected(s.index)
    local keys = awful.tag.getproperty(sel, "keys") or
                    config.globalkeys
    if keys and sel.selected then capi.root.keys(keys) end
end

-- squash_keys: helper function which removes duplicate
-- keybindings by picking only the last one to be listed in keys
-- table arg
function squash_keys(keys)
    local squashed = {}
    local ret = {}
    for i, k in ipairs(keys) do
        squashed[table.concat(k.modifiers) .. k.key] = k
    end
    for i, k in pairs(squashed) do
        table.insert(ret, k)
    end
    return ret
end

-- init : search shifty.config.tags for initial set of
--        tags to open
function init()
    local numscr = capi.screen.count()

    for i, j in pairs(config.tags) do
        local scr = j.screen or {1}
        if type(scr) ~= 'table' then
            scr = {scr}
        end
        for _, s in pairs(scr) do
            if j.init and (s <= numscr) then
                add({name = i,
                                persist = true,
                                screen = s,
                                layout = j.layout,
                                mwfact = j.mwfact})
            end
        end
    end
end

-- signals
capi.client.add_signal("unmanage", _cb_sweep)
capi.client.remove_signal("manage", awful.tag.withcurrent)

for s = 1, capi.screen.count() do
    awful.tag.attached_add_signal(s, "property::selected", _cb_sweep)
    awful.tag.attached_add_signal(s, "tagged", _cb_sweep)
    capi.screen[s]:add_signal("tag::history::update", _cb_keys)
end

