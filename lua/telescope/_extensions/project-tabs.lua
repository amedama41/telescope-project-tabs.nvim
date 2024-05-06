return require("telescope").register_extension {
    setup = function(ext_config, _)
        require("telescope-project-tabs").setup(ext_config)
    end,
    exports = {
        project_tab = require("telescope-project-tabs").project_tab,
    },
}
