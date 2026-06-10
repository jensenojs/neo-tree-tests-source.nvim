local manager = require("neo-tree.sources.manager")
local defaults = require("neo-tree.sources.tests.defaults")
local events = require("neo-tree.events")
local utils = require("neo-tree.utils")
local follow = require("neo-tree.sources.tests.lib.follow")

local M = {
    name = "tests",
    display_name = "  Tests",
}

local get_state = function()
    return manager.get_state(M.name)
end

local function follow_editor_cursor_debounced(args)
    if args and args.afile and not utils.is_real_file(args.afile) then
        return
    end

    utils.debounce("tests_follow_cursor", function()
        follow.follow_editor_cursor(get_state())
    end, 100, utils.debounce_strategy.CALL_LAST_ONLY)
end

---Navigate to the given path. Navigates to a source, can be used to setup data on first navigation.
---@param state neotree.State
---@param path string Path to navigate to. If empty, will navigate to the cwd.
M.navigate = function(state, path, path_to_reveal, callback, _)
    state.path = path or state.path
    state.dirty = false
    if path_to_reveal then
        local renderer = require("neo-tree.ui.renderer")
        renderer.position.set(state, path_to_reveal)
    end

    require("neo-tree.sources.tests.lib.items").render_items(state)

    if type(callback) == "function" then
        vim.schedule(callback)
    end
end

M.refresh = function()
    manager.refresh(M.name)
end

---Configures the plugin, should be called before the plugin is used.
---@param config table Configuration table containing any keys that the user
--wants to change from the defaults. May be empty to accept default values.
M.setup = function(config, _)
    if config.before_render then
        --convert to new event system
        manager.subscribe(M.name, {
            event = events.BEFORE_RENDER,
            handler = function(state)
                local this_state = get_state()
                if state == this_state then
                    config.before_render(this_state)
                end
            end,
        })
    end

    if config.bind_to_cwd then
        manager.subscribe(M.name, {
            event = events.VIM_DIR_CHANGED,
            handler = M.refresh,
        })
    end

    local follow_current_file = config.follow_current_file
    if type(follow_current_file) == "table" and follow_current_file.enabled then
        manager.subscribe(M.name, {
            event = events.VIM_CURSOR_MOVED,
            handler = follow_editor_cursor_debounced,
        })
        manager.subscribe(M.name, {
            event = events.VIM_BUFFER_ENTER,
            handler = follow_editor_cursor_debounced,
        })
        manager.subscribe(M.name, {
            event = events.AFTER_RENDER,
            handler = function(state)
                if state == get_state() then
                    follow_editor_cursor_debounced({ afile = vim.api.nvim_buf_get_name(0) })
                end
            end,
        })
    end

    if config.follow_tree_cursor then
        manager.subscribe(M.name, {
            event = events.NEO_TREE_BUFFER_ENTER,
            handler = function()
                local bufnr = vim.api.nvim_get_current_buf()
                local state = get_state()
                if not state or state.bufnr ~= bufnr then
                    return
                end

                local group = vim.api.nvim_create_augroup("neo_tree_tests_follow_tree_cursor", {
                    clear = true,
                })
                vim.api.nvim_create_autocmd("CursorMoved", {
                    group = group,
                    buffer = bufnr,
                    callback = function()
                        local current_state = get_state()
                        if not current_state or not current_state.tree then
                            return
                        end
                        if vim.api.nvim_get_current_buf() ~= current_state.bufnr then
                            return
                        end

                        require("neo-tree.sources.tests.commands").show_test(current_state)
                    end,
                })
            end,
        })
    end
end

M.default_config = defaults

return M
