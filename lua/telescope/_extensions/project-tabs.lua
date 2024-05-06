return require("telescope").register_extension {
    setup = function(ext_config, _)
        require("telescope-project-tabs").setup(ext_config)
    end,
    exports = {
        switch_project = require("telescope-project-tabs").switch_project,
    },
}
