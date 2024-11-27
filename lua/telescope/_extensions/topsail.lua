return require("telescope").register_extension({
  exports = {
    workspace = require("telescope.topsail.picker").workspace,
    single_file = require("telescope.topsail.picker").single_file,
  },
})
