--! @file   _config.lua
--
-- @brief
--
-- @author  Perry Hargrave
-- @date    2012-03-14
--

local setmetatable = setmetatable

local awful = require("awful")

module("shifty.config")

local _config = {}

-- variables
_config.tags = {}
_config.apps = {}
_config.defaults = {}
_config.float_bars = false
_config.guess_name = true
_config.guess_position = true
_config.remember_index = true
_config.sloppy = true
_config.default_name = "new"
_config.clientkeys = {}
_config.globalkeys = nil
_config.layouts = {}
_config.prompt_sources = {
    "config_tags",
    "config_apps",
    "existing",
    "history"
}
_config.prompt_matchers = {
    "^",
    ":",
    ""
}

-- getlayout: returns a layout by name
function getlayout(name)
    for _, layout in ipairs(_config.layouts) do
        if awful.layout.getname(layout) == name then
            return layout
        end
    end
end

setmetatable(_M, {__index = _config})
