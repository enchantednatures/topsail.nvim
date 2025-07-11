local M = {}

-- Configuration with defaults
M.config = {
  notify = true,
  keymaps = {
    apply = "<leader>ka",
    create = "<leader>kc",
    copy = "<leader>ky",
  },
}

local function setup_autocommands()
  local group = vim.api.nvim_create_augroup("topsail", { clear = true })

  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    group = group,
    pattern = { "*.yaml", "*.yml" },
    callback = function(args)
      M.detect_kubernetes_resource(function(is_kubernetes)
        if is_kubernetes then
          if M.config.notify then
            vim.notify("Kubernetes resource detected", vim.log.levels.DEBUG)
          end
          vim.schedule(function()
            M.setup_buffer_keymaps()
          end)
        end
      end)
    end,
  })
end

function M.detect_kubernetes_resource(callback)
  local current_file = vim.fn.expand("%")
  local cmd = { "kubectl", "apply", "--dry-run=client", "-f", current_file }

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_exit = function(_, exit_code)
      if exit_code == 0 then
        callback(true)
      else
        callback(false)
      end
    end,
  })
end

function M.create_resource()
  local current_file = vim.fn.expand("%")
  local cmd = { "kubectl", "create", "-f", current_file }

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data and M.config.notify then
        vim.notify(table.concat(data, "\n"), vim.log.levels.INFO)
      end
    end,
    on_stderr = function(_, data)
      if data and M.config.notify then
        vim.notify(table.concat(data, "\n"), vim.log.levels.ERROR)
      end
    end,
  })
end

function M.apply_resource()
  local current_file = vim.fn.expand("%")
  local cmd = { "kubectl", "apply", "-f", current_file }

  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data and M.config.notify then
        vim.notify(table.concat(data, "\n"), vim.log.levels.INFO)
      end
    end,
    on_stderr = function(_, data)
      if data and M.config.notify then
        vim.notify(table.concat(data, "\n"), vim.log.levels.ERROR)
      end
    end,
  })
end

function M.copy_resource()
  local current_file = vim.fn.expand("%")
  local file = io.open(current_file, "r")
  if not file then
    if M.config.notify then
      vim.notify("Failed to open file: " .. current_file, vim.log.levels.ERROR)
    end
    return
  end
  
  local content = file:read("*a")
  file:close()
  
  vim.fn.setreg('"', content)
  if M.config.notify then
    vim.notify("YAML resource copied to default register", vim.log.levels.INFO)
  end
end

function M.setup_buffer_keymaps()
  vim.keymap.set("n", M.config.keymaps.apply, M.apply_resource, { buffer = true, desc = "Apply Kubernetes resource" })
  vim.keymap.set(
    "n",
    M.config.keymaps.create,
    M.create_resource,
    { buffer = true, desc = "Create Kubernetes resource" }
  )
  vim.keymap.set("n", M.config.keymaps.copy, M.copy_resource, { buffer = true, desc = "Copy YAML resource to register" })
end

function M.setup(opts)
  -- Merge user config with defaults
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  setup_autocommands()
end

return M
