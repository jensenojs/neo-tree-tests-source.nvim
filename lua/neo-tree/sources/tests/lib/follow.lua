local renderer = require("neo-tree.ui.renderer")
local utils = require("neo-tree.utils")

local M = {}

local function range_distance(line, range)
    if line < range[1] then
        return range[1] - line
    elseif line <= range[3] then
        return 0
    end
    return line - range[3]
end

local function range_size(range)
    return range[3] - range[1] + 1
end

---@param state neotree.StateWithTree
---@param path string
---@param line integer zero-indexed line
---@return NuiTree.Node|nil
function M.find_nearest_node(state, path, line)
    if not state or not state.tree or not path or path == "" then
        return nil
    end

    local normalized_path = utils.normalize_path(path)
    local best = nil

    local function visit(node)
        local extra = node.extra
        if extra and extra.real_path and extra.range and node.type ~= "file" then
            local real_path = utils.normalize_path(extra.real_path)
            local range = extra.range
            if real_path == normalized_path and line >= range[1] then
                local distance = range_distance(line, range)
                local size = range_size(range)
                if
                    not best
                    or distance < best.distance
                    or (distance == best.distance and size < best.size)
                then
                    best = {
                        node = node,
                        distance = distance,
                        size = size,
                    }
                end
            end
        end

        if node:has_children() then
            for _, child in ipairs(state.tree:get_nodes(node:get_id())) do
                visit(child)
            end
        end
    end

    for _, root in ipairs(state.tree:get_nodes()) do
        visit(root)
    end

    return best and best.node or nil
end

---@param state neotree.StateWithTree
function M.follow_editor_cursor(state)
    if not state or not state.tree or not renderer.window_exists(state) then
        return
    end
    if vim.bo.filetype == "neo-tree" or vim.bo.filetype == "neo-tree-popup" then
        return
    end

    local path = vim.api.nvim_buf_get_name(0)
    if not utils.is_real_file(path) then
        return
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local node = M.find_nearest_node(state, path, cursor[1] - 1)
    if node then
        renderer.focus_node(state, node:get_id(), true)
    end
end

return M
