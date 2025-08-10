return require("telescope").register_extension({
  setup = require("telescope.topsail.picker").setup,
  exports = {
    workspace = require("telescope.topsail.picker").workspace,
    single_file = require("telescope.topsail.picker").single_file,
    by_kind_and_annotations = require("telescope.topsail.picker").by_kind_and_annotations,
    by_kind_and_labels = require("telescope.topsail.picker").by_kind_and_labels,
  },
})
