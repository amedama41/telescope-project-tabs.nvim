local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values

local M = {}

---@class Configs
---@field root_dirs string[]
---@field max_depth number

---@type Configs
M.default_configs = {
    root_dirs = {},
    max_depth = 1,
}

---@type Configs
M.configs = vim.deepcopy(M.default_config)

---@param configs Configs
M.setup = function(configs)
    M.configs = vim.tbl_deep_extend("force", M.configs, configs)
end

M.project_tab = function(opts)
    opts = opts or {}
    local configs = M.configs
    if vim.tbl_isempty(configs.root_dirs or {}) then
        return
    end

    local cmd = { "find" }
    vim.list_extend(cmd, configs.root_dirs)
    vim.list_extend(cmd, { "-type", "d", "-name", ".git", "-maxdepth", configs.max_depth })
    pickers.new(opts, {
        prompt_tile = "projects",
        finder = finders.new_oneshot_job(cmd, opts),
        sorter = conf.generic_sorter(opts),
    }):find()
end

return M
