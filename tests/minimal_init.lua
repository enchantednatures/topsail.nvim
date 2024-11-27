local function ensure_plugin(name, url)
    local plugin_dir = "/tmp/" .. name
    local is_not_a_directory = vim.fn.isdirectory(plugin_dir) == 0
    if is_not_a_directory then
        vim.fn.system({ "git", "clone", url, plugin_dir })
    end
    vim.opt.rtp:append(plugin_dir)
    return plugin_dir
end

-- Ensure plenary is available (required for tests)
local plenary_dir = os.getenv("PLENARY_DIR") or ensure_plugin("plenary.nvim", "https://github.com/nvim-lua/plenary.nvim")

-- Ensure telescope is available (for telescope tests)
local telescope_dir = os.getenv("TELESCOPE_DIR") or ensure_plugin("telescope.nvim", "https://github.com/nvim-telescope/telescope.nvim")

-- Add our plugin to the rtp
vim.opt.rtp:append(".")

-- Load plenary
vim.cmd("runtime plugin/plenary.vim")
require("plenary.busted")

-- Make plugin modules available to tests
package.loaded["telescope.topsail.picker"] = require("telescope.topsail.picker")
