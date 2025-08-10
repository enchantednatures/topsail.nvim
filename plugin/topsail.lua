if vim.g.topsail_loaded then
  return
end
vim.g.topsail_loaded = true

-- Optional: Add any vim commands here
vim.api.nvim_create_user_command("KubernetesApply", function()
  require("topsail").apply_resource()
end, {})

vim.api.nvim_create_user_command("KubernetesCreate", function()
  require("topsail").create_resource()
end, {})

-- Telescope picker commands
vim.api.nvim_create_user_command("TopsailByAnnotations", function()
  require("telescope.topsail.picker").by_kind_and_annotations()
end, { desc = "Search Kubernetes resources by kind and annotations" })

vim.api.nvim_create_user_command("TopsailByLabels", function()
  require("telescope.topsail.picker").by_kind_and_labels()
end, { desc = "Search Kubernetes resources by kind and labels" })
