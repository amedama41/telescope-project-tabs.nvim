local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local actions = require 'telescope.actions'
local action_state = require 'telescope.actions.state'
local make_entry = require "telescope.make_entry"
local conf = require("telescope.config").values

---Switch to or open project tab
---@param entry table
local function switch_or_open_project_tab(entry)
    local project_dir = entry.value
    local path = entry.path
    vim.schedule(function()
        for _, tabpage in pairs(vim.api.nvim_list_tabpages()) do
            local tabnr = vim.api.nvim_tabpage_get_number(tabpage)
            local tabcwd = vim.fn.getcwd(1, tabnr)
            if tabcwd == project_dir then
                vim.api.nvim_set_current_tabpage(tabpage)
                vim.cmd(("lcd %s"):format(vim.fn.fnameescape(project_dir)))
                return
            end
        end
        vim.cmd(("tab drop %s"):format(vim.fn.fnameescape(path)))
        vim.cmd(("lcd %s"):format(vim.fn.fnameescape(project_dir)))
    end)
end

---@return string[]
local function get_opened_project_dirs()
    return vim.tbl_map(function(tabpage)
        return vim.fn.getcwd(1, vim.api.nvim_tabpage_get_number(tabpage))
    end, vim.api.nvim_list_tabpages())
end

---@param project_dir string
local function delete_all_buffers(project_dir)
    local bufnr_list = vim.tbl_filter(function(bufnr)
        if vim.fn.buflisted(bufnr) ~= 1 then
            return false
        end
        local bufname = vim.api.nvim_buf_get_name(bufnr)
        return vim.startswith(bufname, project_dir)
    end, vim.api.nvim_list_bufs())
    for _, bufnr in pairs(bufnr_list) do
        if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_delete(bufnr, { force = false, unload = false })
        end
    end
end

---@param entry table
local function close_project_tab(entry)
    local project_dir = entry.value
    vim.schedule(function()
        delete_all_buffers(project_dir)
        local project_tabpage_list = vim.tbl_filter(function(tabpage)
            return vim.fn.getcwd(1, vim.api.nvim_tabpage_get_number(tabpage)) == project_dir
        end, vim.api.nvim_list_tabpages())
        for _, tabpage in pairs(project_tabpage_list) do
            for _, winid in pairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
                if vim.api.nvim_win_is_valid(winid) then
                    vim.api.nvim_win_close(winid, false)
                end
            end
        end
    end)
end

local M = {}

---@class Configs
---@field root_dirs string[]
---@field max_depth number
---@field default_files string[]

---@type Configs
M.default_configs = {
    root_dirs = {},
    max_depth = 1,
    default_files = { "README.md", "README.rst" },
}

---@type Configs
M.configs = vim.deepcopy(M.default_configs)

---@param configs Configs
M.setup = function(configs)
    M.configs = vim.tbl_deep_extend("force", M.configs, configs)
end

---@param opts { root_dirs: string[]?, max_depth: number?, default_files: string[]?, only_opened: boolean? }
M.switch_project = function(opts)
    local configs = M.configs
    opts = opts or {}
    local root_dirs = opts.root_dirs or configs.root_dirs
    if vim.tbl_isempty(root_dirs or {}) then
        return
    end
    local max_depth = opts.max_depth or configs.max_depth
    local default_files = opts.default_files or configs.default_files
    local only_opened = opts.only_opened
    local opened_project_dirs = get_opened_project_dirs()
    vim.print(opened_project_dirs)

    local cmd = { "find" }
    vim.list_extend(cmd, vim.tbl_map(vim.fn.expand, root_dirs))
    vim.list_extend(cmd, { "-type", "d", "-name", ".git", "-maxdepth", max_depth })

    opts = vim.deepcopy(opts)
    local entry_maker = opts.entry_maker or make_entry.gen_from_string(opts)
    ---@param git_dirpath string
    local wrapping_entry_maker = function(git_dirpath)
        local project_dir = vim.fn.fnamemodify(git_dirpath, ":h:p")
        if only_opened and not vim.tbl_contains(opened_project_dirs, project_dir) then
            return nil
        end

        local entry = entry_maker(project_dir)
        entry.path = project_dir
        for _, default_file in pairs(default_files) do
            local path = project_dir .. '/' .. default_file
            if vim.fn.filereadable(path) == 1 then
                entry.path = path
                break
            end
        end
        return entry
    end
    opts.entry_maker = wrapping_entry_maker

    pickers.new(opts, {
        prompt_tile = "projects",
        finder = finders.new_oneshot_job(cmd, opts),
        sorter = conf.generic_sorter(opts),
        previewer = conf.file_previewer(opts),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                local selection = action_state.get_selected_entry()
                switch_or_open_project_tab(selection)
                actions.close(prompt_bufnr)
            end)
            map({ "n" }, "D", function()
                local picker = action_state.get_current_picker(prompt_bufnr)
                for _, selection in pairs(picker:get_multi_selection()) do
                    close_project_tab(selection)
                    actions.close(prompt_bufnr)
                end
            end)
            return true
        end,
    }):find()
end

return M
