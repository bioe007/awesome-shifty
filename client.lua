-- shifty.client
--
-- @author resixian (aka bioe007) &lt;resixian@gmail.com&gt;

-- environment
local type = type
local ipairs = ipairs
local table = table
local string = string
local beautiful = require("beautiful")
local awful = require("awful")
local pairs = pairs
local io = io
local setmetatable = setmetatable
local tonumber = tonumber
local capi = {
    client = client,
    tag = tag,
    image = image,
    screen = screen,
    button = button,
    mouse = mouse,
    root = root,
    timer = timer
}

local config = require("shifty.config")
local tag = require("shifty.tag")

module("shifty.client")

move = {}
-- client.move: moves client.focus to tag[idx]
-- @param idx The tag number to send a client to, an integer.
--
-- If idx is not in len(capi.screen[scr]:tags()) then it will cycle.
local function _move(idx)
    local scr = capi.client.focus.screen or capi.mouse.screen
    local sel = awful.tag.selected(scr)
    local sel_idx = tag.get.index(scr, sel)
    local tags = capi.screen[scr]:tags()
    local target = awful.util.cycle(#tags, sel_idx + idx)
    awful.client.movetotag(tags[target], capi.client.focus)
    awful.tag.viewonly(tags[target])
end

function move.left() _move(1) end
function move.right() _move(-1) end

setmetatable(move, {__call = _move})

-- is_tagged : replicate behavior in tag.c - returns true if the
--              given client is tagged with the given tag
function is_tagged(tag, client)
    for i, c in ipairs(tag:clients()) do
        if c == client then
            return true
        end
    end
    return false
end

-- match : Handles app->tag matching, a replacement for the manage hook in
--         rc.lua
-- @param c The client to be matched.
-- @param startup
function match(c, startup)
    local nopopup, intrusive, nofocus, run, slave
    local wfact, struts, geom, float
    local target_tag_names, target_tags = {}, {}
    local typ = c.type
    local cls = c.class
    local inst = c.instance
    local role = c.role
    local name = c.name
    local keys = config.clientkeys or c:keys() or {}
    local target_screen = capi.mouse.screen

    c.border_color = beautiful.border_normal
    c.border_width = beautiful.border_width

    -- try matching client to config.apps
    for i, a in ipairs(config.apps) do
        if a.match then
            for k, w in ipairs(a.match) do
                if
                    (cls and cls:find(w)) or
                    (inst and inst:find(w)) or
                    (name and name:find(w)) or
                    (role and role:find(w)) or
                    (typ and typ:find(w)) then
                    if a.screen then target_screen = a.screen end
                    if a.tag then
                        if type(a.tag) == "string" then
                            target_tag_names = {a.tag}
                        else
                            target_tag_names = a.tag
                        end
                    end
                    if a.startup and startup then
                        a = awful.util.table.join(a, a.startup)
                    end
                    if a.geometry ~=nil then
                        geom = {x = a.geometry[1],
                        y = a.geometry[2],
                        width = a.geometry[3],
                        height = a.geometry[4]}
                    end
                    if a.float ~= nil then float = a.float end
                    if a.slave ~=nil then slave = a.slave end
                    if a.border_width ~= nil then
                        c.border_width = a.border_width
                    end
                    if a.nopopup ~=nil then nopopup = a.nopopup end
                    if a.intrusive ~=nil then
                        intrusive = a.intrusive
                    end
                    if a.fullscreen ~=nil then
                        c.fullscreen = a.fullscreen
                    end
                    if a.honorsizehints ~=nil then
                        c.size_hints_honor = a.honorsizehints
                    end
                    if a.kill ~=nil then c:kill(); return end
                    if a.ontop ~= nil then c.ontop = a.ontop end
                    if a.above ~= nil then c.above = a.above end
                    if a.below ~= nil then c.below = a.below end
                    if a.buttons ~= nil then
                        c:buttons(a.buttons)
                    end
                    if a.nofocus ~= nil then nofocus = a.nofocus end
                    if a.keys ~= nil then
                        keys = awful.util.table.join(keys, a.keys)
                    end
                    if a.hidden ~= nil then c.hidden = a.hidden end
                    if a.minimized ~= nil then
                        c.minimized = a.minimized
                    end
                    if a.dockable ~= nil then
                        awful.client.dockable.set(c, a.dockable)
                    end
                    if a.urgent ~= nil then
                        c.urgent = a.urgent
                    end
                    if a.opacity ~= nil then
                        c.opacity = a.opacity
                    end
                    if a.run ~= nil then run = a.run end
                    if a.sticky ~= nil then c.sticky = a.sticky end
                    if a.wfact ~= nil then wfact = a.wfact end
                    if a.struts then struts = a.struts end
                    if a.skip_taskbar ~= nil then
                        c.skip_taskbar = a.skip_taskbar
                    end
                    if a.props then
                        for kk, vv in pairs(a.props) do
                            awful.client.property.set(c, kk, vv)
                        end
                    end
                end
            end
        end
    end

    -- set key bindings
    c:keys(keys)

    -- Add titlebars to all clients when the float, remove when they are
    -- tiled.
    if config.float_bars then
        c:add_signal("property::floating", function(c)
            if awful.client.floating.get(c) then
                awful.titlebar.add(c, {modkey=modkey})
            else
                awful.titlebar.remove(c)
            end
            awful.placement.no_offscreen(c)
        end)
    end

    -- set properties of floating clients
    if float ~= nil then
        awful.client.floating.set(c, float)
        awful.placement.no_offscreen(c)
    end

    local sel = awful.tag.selectedlist(target_screen)
    if not target_tag_names or #target_tag_names == 0 then
        -- if not matched to some names try putting
        -- client in c.transient_for or current tags
        if c.transient_for then
            target_tags = c.transient_for:tags()
        elseif #sel > 0 then
            for i, t in ipairs(sel) do
                local mc = awful.tag.getproperty(t, "max_clients")
                if intrusive or
                    not (awful.tag.getproperty(t, "exclusive") or
                                    (mc and mc >= #t:clients())) then
                    table.insert(target_tags, t)
                end
            end
        end
    end

    if (not target_tag_names or #target_tag_names == 0) and
        (not target_tags or #target_tags == 0) then
        -- if we still don't know any target names/tags guess
        -- name from class or use default
        if config.guess_name and cls then
            target_tag_names = {cls:lower()}
        else
            target_tag_names = {config.default_name}
        end
    end

    if #target_tag_names > 0 and #target_tags == 0 then
        -- translate target names to tag objects, creating
        -- missing ones
        for i, tn in ipairs(target_tag_names) do
            local res = {}
            for j, t in ipairs(tag.get.list_by_name(tn, target_screen) or
                               tag.get.list_by_name(tn) or {}) do
                local mc = awful.tag.getproperty(t, "max_clients")
                local tagged = is_tagged(t, c)
                if intrusive or
                    not (mc and (((#t:clients() >= mc) and not
                    tagged) or
                    (#t:clients() > mc))) or
                    intrusive then
                    table.insert(res, t)
                end
            end
            if #res == 0 then
                table.insert(target_tags,
                add({name = tn,
                noswitch = true,
                matched = true}))
            else
                target_tags = awful.util.table.join(target_tags, res)
            end
        end
    end

    -- set client's screen/tag if needed
    target_screen = target_tags[1].screen or target_screen
    if c.screen ~= target_screen then c.screen = target_screen end
    if slave then awful.client.setslave(c) end
    c:tags(target_tags)

    if wfact then awful.client.setwfact(wfact, c) end
    if geom then c:geometry(geom) end
    if struts then c:struts(struts) end

    local showtags = {}
    local u = nil
    if #target_tags > 0 and not startup then
        -- switch or highlight
        for i, t in ipairs(target_tags) do
            if not (nopopup or awful.tag.getproperty(t, "nopopup")) then
                table.insert(showtags, t)
            elseif not startup then
                c.urgent = true
            end
        end
        if #showtags > 0 then
            local ident = false
            -- iterate selected tags and and see if any targets
            -- currently selected
            for kk, vv in pairs(showtags) do
                for _, tag in pairs(sel) do
                    if tag == vv then
                        ident = true
                    end
                end
            end
            if not ident then
                awful.tag.viewmore(showtags, c.screen)
            end
        end
    end

    if not (nofocus or c.hidden or c.minimized) then
        --focus and raise accordingly or lower if supressed
        if (target and target ~= sel) and
           (awful.tag.getproperty(target, "nopopup") or nopopup)  then
            awful.client.focus.history.add(c)
        else
            capi.client.focus = c
        end
        c:raise()
    else
        c:lower()
    end

    if config.sloppy then
        -- Enable sloppy focus
        c:add_signal("mouse::enter", function(c)
            if awful.client.focus.filter(c) and
                awful.layout.get(c.screen) ~= awful.layout.suit.magnifier then
                capi.client.focus = c
            end
        end)
    end

    -- execute run function if specified
    if run then run(c, target) end
end

capi.client.add_signal("manage", match)
