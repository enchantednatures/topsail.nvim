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
