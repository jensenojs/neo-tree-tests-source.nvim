local cc = require("neo-tree.sources.common.commands")

local M = {}

M.jump_to_test = function(state, toggle_directory)
    local node = state.tree:get_node()
    if not node or not node.extra then
        return
    end

    ---@type neotree-neotest.Node.Extra
    local extra = node.extra
    local _type = node.type

    -- The node's current path includes the adapter_id as the root.
    -- This was done to organize tests via adapter incase the developer
    -- uses multiple test runners in the same project.
    -- Due to this, we retrieve the real path here
    node.path = extra.real_path or node.path

    if _type == "namespace" then
        -- This tricks the open function into opening namespaces.
        node.type = "file"
    end

    cc.open(state, toggle_directory)

    -- Position cursor
    if _type == "namespace" or _type == "test" then
        local utils = require("neo-tree.utils")
        local winid = utils.get_appropriate_window(state)
        vim.api.nvim_win_set_cursor(winid, { extra.range[1] + 1, extra.range[2] })
    end
end

---Show test location without moving focus away from the tests tree.
---@param state neotree.StateWithTree
---@param node? NuiTree.Node
M.show_test = function(state, node)
    if not state or not state.tree then
        return
    end

    node = node or state.tree:get_node()
    if not node or not node.extra or not node.extra.real_path then
        return
    end

    local neo_win = vim.api.nvim_get_current_win()
    local target_win = require("neo-tree.utils").get_appropriate_window(state)
    if not target_win or not vim.api.nvim_win_is_valid(target_win) then
        return
    end

    local bufnr = vim.fn.bufadd(node.extra.real_path)
    if bufnr <= 0 then
        return
    end
    vim.fn.bufload(bufnr)

    vim.api.nvim_win_call(target_win, function()
        if vim.api.nvim_win_get_buf(target_win) ~= bufnr then
            vim.api.nvim_win_set_buf(target_win, bufnr)
        end

        local range = node.extra.range
        if range then
            pcall(vim.api.nvim_win_set_cursor, target_win, { range[1] + 1, range[2] })
        end
    end)

    if vim.api.nvim_win_is_valid(neo_win) then
        vim.api.nvim_set_current_win(neo_win)
    end
end

---@param state neotree.StateWithTree
M.run_tests = function(state)
    local tree = state.tree
    local node = tree:get_node()
    require("neotest.consumers.neotree").run_tests(node)
end

---@param state neotree.StateWithTree
M.stop_tests = function(state)
    local tree = state.tree
    local node = tree:get_node()
    require("neotest.consumers.neotree").stop_tests(node)
end

---@param state neotree.StateWithTree
M.debug_tests = function(state)
    local tree = state.tree
    local node = tree:get_node()
    require("neotest.consumers.neotree").run_tests(node, { strategy = "dap" })
end

M.run_all_tests = function(_)
    require("neotest.consumers.neotree").run_tests()
end

M.open = M.jump_to_test

---@param state neotree.StateWithTree
M.watch_tests = function(state)
    local tree = state.tree
    local node = tree:get_node()
    require("neotest.consumers.neotree").watch(node)
end

M.show_test_output = function(state)
    local tree = state.tree
    local node = tree:get_node()
    -- There is no test output for these node types
    if node.type == "directory" or node.type == "file" then
        return
    end
    require("neotest.consumers.neotree").output(node)
end

cc._add_common_commands(M)
return M
