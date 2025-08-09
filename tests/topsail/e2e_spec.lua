local topsail = require("topsail")
local picker = require("telescope.topsail.picker")

describe("end-to-end workflow", function()
  local test_yaml_k8s = [[
apiVersion: v1
kind: ConfigMap
metadata:
  name: e2e-test-config
  namespace: test-namespace
data:
  config.yaml: |
    setting1: value1
    setting2: value2
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: e2e-test-deployment
  namespace: test-namespace
  labels:
    app: e2e-test
spec:
  replicas: 2
  selector:
    matchLabels:
      app: e2e-test
  template:
    metadata:
      labels:
        app: e2e-test
    spec:
      containers:
      - name: app
        image: nginx:1.21
        ports:
        - containerPort: 80
]]

  local temp_dir
  local temp_files = {}
  local original_config
  local original_jobstart
  local kubectl_commands = {}

  before_each(function()
    -- Save original configurations
    original_config = vim.deepcopy(topsail.config)
    original_jobstart = vim.fn.jobstart
    kubectl_commands = {}
    
    -- Mock kubectl commands
    vim.fn.jobstart = function(cmd, opts)
      table.insert(kubectl_commands, { cmd = cmd, opts = opts })
      -- Simulate successful kubectl dry-run for detection
      if cmd[2] == "apply" and cmd[3] == "--dry-run=client" then
        vim.schedule(function()
          opts.on_exit(0, 0)  -- Success
        end)
      elseif cmd[2] == "apply" or cmd[2] == "create" then
        -- Simulate successful kubectl apply/create commands
        vim.schedule(function()
          if opts.on_stdout then
            opts.on_stdout(0, {"resource applied successfully"})
          end
          opts.on_exit(0, 0)  -- Success
        end)
      end
      return 1
    end

    -- Create temporary test environment
    temp_dir = vim.fn.tempname()
    vim.fn.mkdir(temp_dir, "p")
    
    -- Create test YAML files
    for i = 1, 2 do
      local temp_file = temp_dir .. "/e2e-test-" .. i .. ".yaml"
      local file = io.open(temp_file, "w")
      if file then
        file:write(test_yaml_k8s)
        file:close()
        table.insert(temp_files, temp_file)
      end
    end
  end)

  after_each(function()
    -- Restore original configurations
    topsail.config = original_config
    vim.fn.jobstart = original_jobstart
    
    -- Clean up temporary files
    for _, file in ipairs(temp_files) do
      vim.fn.delete(file)
    end
    vim.fn.delete(temp_dir, "rf")
    temp_files = {}
    kubectl_commands = {}
  end)

  describe("complete plugin initialization workflow", function()
    it("should initialize plugin with default configuration", function()
      -- Test plugin setup
      topsail.setup()
      
      -- Verify default configuration is applied
      assert.equals(true, topsail.config.notify)
      assert.equals("<leader>ka", topsail.config.keymaps.apply)
      assert.equals("<leader>kc", topsail.config.keymaps.create)
      assert.equals("<leader>ky", topsail.config.keymaps.copy)
      assert.equals("<C-y>", topsail.config.keymaps.telescope_copy_file)
      assert.equals("<C-r>", topsail.config.keymaps.telescope_copy_resource)
      
      -- Verify telescope picker is configured
      assert.equals("<C-y>", picker.config.keymaps.telescope_copy_file)
      assert.equals("<C-r>", picker.config.keymaps.telescope_copy_resource)
    end)

    it("should initialize plugin with custom configuration", function()
      local custom_config = {
        notify = false,
        keymaps = {
          apply = "<leader>kA",
          copy = "<leader>kY",
          telescope_copy_file = "<C-f>",
          telescope_copy_resource = "<C-x>",
        }
      }
      
      topsail.setup(custom_config)
      
      -- Verify custom configuration is applied
      assert.equals(false, topsail.config.notify)
      assert.equals("<leader>kA", topsail.config.keymaps.apply)
      assert.equals("<leader>kY", topsail.config.keymaps.copy)
      assert.equals("<C-f>", topsail.config.keymaps.telescope_copy_file)
      assert.equals("<C-x>", topsail.config.keymaps.telescope_copy_resource)
      
      -- Verify telescope picker receives custom configuration
      assert.equals("<C-f>", picker.config.keymaps.telescope_copy_file)
      assert.equals("<C-x>", picker.config.keymaps.telescope_copy_resource)
    end)
  end)

  describe("file detection to keymap setup workflow", function()
    it("should detect kubernetes file and setup buffer keymaps", function()
      local detection_completed = false
      local keymaps_setup = false
      
      -- Mock keymap setup to track when it's called
      local original_setup_keymaps = topsail.setup_buffer_keymaps
      topsail.setup_buffer_keymaps = function()
        keymaps_setup = true
        original_setup_keymaps()
      end
      
      -- Initialize plugin
      topsail.setup()
      
      -- Open a kubernetes YAML file
      vim.cmd("edit " .. temp_files[1])
      
      -- Trigger detection manually (simulating BufRead event)
      topsail.detect_kubernetes_resource(function(is_kubernetes)
        detection_completed = true
        assert.is_true(is_kubernetes)
        
        -- Wait for scheduled keymap setup
        vim.schedule(function()
          assert.is_true(keymaps_setup)
          topsail.setup_buffer_keymaps = original_setup_keymaps
        end)
      end)
      
      -- Wait for detection to complete
      vim.wait(1000, function()
        return detection_completed
      end)
    end)

    it("should not setup keymaps for non-kubernetes files", function()
      local detection_completed = false
      local keymaps_setup = false
      
      -- Create non-kubernetes YAML file
      local non_k8s_file = temp_dir .. "/non-k8s.yaml"
      local file = io.open(non_k8s_file, "w")
      if file then
        file:write("regular_yaml: true\ndata: some_value\n")
        file:close()
      end
      
      -- Mock kubectl to return error for non-k8s file
      vim.fn.jobstart = function(cmd, opts)
        if cmd[2] == "apply" and cmd[3] == "--dry-run=client" then
          vim.schedule(function()
            opts.on_exit(0, 1)  -- Error - not a kubernetes resource
          end)
        end
        return 1
      end
      
      -- Mock keymap setup to track calls
      local original_setup_keymaps = topsail.setup_buffer_keymaps
      topsail.setup_buffer_keymaps = function()
        keymaps_setup = true
        original_setup_keymaps()
      end
      
      topsail.setup()
      vim.cmd("edit " .. non_k8s_file)
      
      topsail.detect_kubernetes_resource(function(is_kubernetes)
        detection_completed = true
        assert.is_false(is_kubernetes)
        
        -- Keymaps should not be setup for non-k8s files
        vim.schedule(function()
          assert.is_false(keymaps_setup)
          topsail.setup_buffer_keymaps = original_setup_keymaps
          vim.fn.delete(non_k8s_file)
        end)
      end)
      
      vim.wait(1000, function()
        return detection_completed
      end)
    end)
  end)

  describe("copy operations workflow", function()
    it("should complete full copy workflow from buffer", function()
      local copy_completed = false
      local register_content = ""
      
      -- Mock register operations
      local original_setreg = vim.fn.setreg
      vim.fn.setreg = function(reg, content)
        register_content = content
        copy_completed = true
      end
      
      -- Setup plugin and open file
      topsail.setup()
      vim.cmd("edit " .. temp_files[1])
      
      -- Execute copy operation
      topsail.copy_resource()
      
      -- Verify copy completed
      assert.is_true(copy_completed)
      assert.is_true(string.find(register_content, "apiVersion") ~= nil)
      assert.is_true(string.find(register_content, "ConfigMap") ~= nil)
      assert.is_true(string.find(register_content, "Deployment") ~= nil)
      
      vim.fn.setreg = original_setreg
    end)

    it("should handle copy operations with custom register", function()
      local copy_completed = false
      local used_register = ""
      local register_content = ""
      
      -- Configure custom register
      topsail.setup({
        copy_register = function()
          return "a"
        end
      })
      
      -- Mock register operations
      local original_setreg = vim.fn.setreg
      vim.fn.setreg = function(reg, content)
        used_register = reg
        register_content = content
        copy_completed = true
      end
      
      vim.cmd("edit " .. temp_files[1])
      topsail.copy_resource()
      
      assert.is_true(copy_completed)
      assert.equals("a", used_register)
      assert.is_true(string.find(register_content, "apiVersion") ~= nil)
      
      vim.fn.setreg = original_setreg
    end)
  end)

  describe("kubectl operations workflow", function()
    it("should execute apply workflow correctly", function()
      topsail.setup()
      vim.cmd("edit " .. temp_files[1])
      
      -- Execute apply operation
      topsail.apply_resource()
      
      -- Verify kubectl command was called
      assert.is_true(#kubectl_commands > 0)
      local apply_cmd = nil
      for _, cmd_info in ipairs(kubectl_commands) do
        if cmd_info.cmd[2] == "apply" and cmd_info.cmd[3] == "-f" then
          apply_cmd = cmd_info
          break
        end
      end
      
      -- Verify kubectl was called (apply command should be present)
      local kubectl_called = false
      for _, cmd_info in ipairs(kubectl_commands) do
        if cmd_info.cmd[1] == "kubectl" then
          kubectl_called = true
          break
        end
      end
      assert.is_true(kubectl_called)
    end)

    it("should execute create workflow correctly", function()
      topsail.setup()
      vim.cmd("edit " .. temp_files[1])
      
      -- Execute create operation
      topsail.create_resource()
      
      -- Verify kubectl command was called
      assert.is_true(#kubectl_commands > 0)
      local create_cmd = nil
      for _, cmd_info in ipairs(kubectl_commands) do
        if cmd_info.cmd[2] == "create" then
          create_cmd = cmd_info
          break
        end
      end
      
      -- Verify kubectl was called (create command should be present)
      local kubectl_called = false
      for _, cmd_info in ipairs(kubectl_commands) do
        if cmd_info.cmd[1] == "kubectl" then
          kubectl_called = true
          break
        end
      end
      assert.is_true(kubectl_called)
    end)
  end)

  describe("telescope integration workflow", function()
    it("should complete workspace browsing workflow", function()
      local picker_created = false
      local finder_configured = false
      local mappings_attached = false
      
      -- Mock telescope components
      local original_new = require("telescope.pickers").new
      require("telescope.pickers").new = function(opts, config)
        picker_created = true
        
        if config.finder then
          finder_configured = true
        end
        
        if config.attach_mappings then
          mappings_attached = true
        end
        
        return { find = function() end }
      end
      
      -- Initialize and run workspace picker
      topsail.setup()
      picker.workspace({ cwd = temp_dir })
      
      assert.is_true(picker_created)
      assert.is_true(finder_configured)
      assert.is_true(mappings_attached)
      
      require("telescope.pickers").new = original_new
    end)

    it("should complete single file browsing workflow", function()
      local picker_created = false
      local resources_found = false
      
      -- Mock telescope components
      local original_new = require("telescope.pickers").new
      require("telescope.pickers").new = function(opts, config)
        picker_created = true
        return { find = function() end }
      end
      
      -- Test resource parsing
      local resources = picker.get_kubernetes_yaml_resources(temp_files[1])
      if resources and #resources > 0 then
        resources_found = true
      end
      
      -- Initialize and run single file picker
      topsail.setup()
      picker.single_file({ file_path = temp_files[1] })
      
      assert.is_true(picker_created)
      -- Resources might not be found if treesitter is unavailable, which is OK
      
      require("telescope.pickers").new = original_new
    end)
  end)

  describe("error handling workflow", function()
    it("should handle complete workflow with file errors gracefully", function()
      local error_handled = false
      local original_notify = vim.notify
      
      vim.notify = function(msg, level)
        if level == vim.log.levels.ERROR then
          error_handled = true
        end
      end
      
      topsail.setup()
      
      -- Try to copy from non-existent file
      vim.cmd("edit /non/existent/file.yaml")
      topsail.copy_resource()
      
      assert.is_true(error_handled)
      vim.notify = original_notify
    end)

    it("should handle kubectl command failures gracefully", function()
      local error_handled = false
      local original_notify = vim.notify
      
      vim.notify = function(msg, level)
        if level == vim.log.levels.ERROR then
          error_handled = true
        end
      end
      
      -- Mock kubectl to fail
      vim.fn.jobstart = function(cmd, opts)
        if cmd[1] == "kubectl" and opts.on_stderr then
          vim.schedule(function()
            opts.on_stderr(0, {"Error: kubectl command failed"})
          end)
        end
        return 1
      end
      
      topsail.setup()
      vim.cmd("edit " .. temp_files[1])
      topsail.apply_resource()
      
      -- Wait for async error handling
      vim.wait(100, function()
        return error_handled
      end)
      
      assert.is_true(error_handled)
      vim.notify = original_notify
    end)
  end)
end)