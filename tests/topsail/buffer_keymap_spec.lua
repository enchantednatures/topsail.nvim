local topsail = require("topsail")

describe("buffer keymap functionality", function()
  local test_yaml = [[
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-config
  namespace: default
data:
  key: value
]]

  local temp_file
  local original_config
  local original_jobstart

  before_each(function()
    -- Save original config and functions
    original_config = vim.deepcopy(topsail.config)
    original_jobstart = vim.fn.jobstart

    -- Mock kubectl for detection
    vim.fn.jobstart = function(cmd, opts)
      if cmd[2] == "apply" and cmd[3] == "--dry-run=client" then
        vim.schedule(function()
          opts.on_exit(0, 0) -- Success - valid k8s resource
        end)
      end
      return 1
    end

    -- Create temporary test file
    temp_file = vim.fn.tempname() .. ".yaml"
    local file = io.open(temp_file, "w")
    file:write(test_yaml)
    file:close()
  end)

  after_each(function()
    -- Restore original config and functions
    topsail.config = original_config
    vim.fn.jobstart = original_jobstart

    -- Clean up temporary file
    if temp_file then
      os.remove(temp_file)
    end

    -- Clear any test registers
    vim.fn.setreg("+", "")
  end)

  describe("copy_resource function", function()
    it("should copy file content to default register", function()
      local reg = topsail.config.copy_register()
      -- Clear register first
      vim.fn.setreg(reg, "")

      -- Open the test file
      vim.cmd("edit " .. temp_file)

      -- Call copy_resource function
      topsail.copy_resource()

      -- Check that content was copied to register
      local register_content = vim.fn.getreg(reg)
      assert.is_not_nil(register_content)
      assert.is_true(#register_content > 0)
      assert.is_true(register_content:find("apiVersion: v1", 1, true) ~= nil)
      assert.is_true(register_content:find("kind: ConfigMap", 1, true) ~= nil)
      assert.is_true(register_content:find("name: test-config", 1, true) ~= nil)
    end)

    it("should copy file content to custom register", function()
      topsail.config.copy_register = function()
        return "a"
      end
      local reg = topsail.config.copy_register()
      -- Clear register first
      vim.fn.setreg(reg, "")

      -- Open the test file
      vim.cmd("edit " .. temp_file)

      -- Call copy_resource function
      topsail.copy_resource()

      -- Check that content was copied to register
      local register_content = vim.fn.getreg(reg)
      assert.is_not_nil(register_content)
      assert.is_true(#register_content > 0)
      assert.is_true(register_content:find("apiVersion: v1", 1, true) ~= nil)
      assert.is_true(register_content:find("kind: ConfigMap", 1, true) ~= nil)
      assert.is_true(register_content:find("name: test-config", 1, true) ~= nil)
    end)

    it("should handle file read errors gracefully", function()
      -- Try to copy from a non-existent file
      vim.cmd("edit /non/existent/file.yaml")

      -- Should not throw an error
      assert.has_no.errors(function()
        topsail.copy_resource()
      end)
    end)

    it("should respect notify configuration", function()
      -- Test with notify enabled
      topsail.config.notify = true
      vim.cmd("edit " .. temp_file)

      -- Mock vim.notify to capture calls
      local notify_called = false
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        notify_called = true
        assert.is_string(msg)
        assert.is_true(msg:find("copied", 1, true) ~= nil)
      end

      topsail.copy_resource()
      assert.is_true(notify_called)

      -- Restore original notify
      vim.notify = original_notify
    end)

    it("should not notify when disabled", function()
      -- Test with notify disabled
      topsail.config.notify = false
      vim.cmd("edit " .. temp_file)

      -- Mock vim.notify to capture calls
      local notify_called = false
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        notify_called = true
      end

      topsail.copy_resource()
      assert.is_false(notify_called)

      -- Restore original notify
      vim.notify = original_notify
    end)
  end)

  describe("keymap configuration", function()
    it("should use default copy keymap", function()
      assert.equals("<leader>ky", topsail.config.keymaps.copy)
    end)

    it("should allow custom copy keymap configuration", function()
      local custom_config = {
        keymaps = {
          copy = "<leader>kx",
        },
      }

      topsail.setup(custom_config)
      assert.equals("<leader>kx", topsail.config.keymaps.copy)
    end)

    it("should preserve other keymap settings when customizing", function()
      local custom_config = {
        keymaps = {
          copy = "<leader>kx",
        },
      }

      topsail.setup(custom_config)
      assert.equals("<leader>ka", topsail.config.keymaps.apply)
      assert.equals("<leader>kc", topsail.config.keymaps.create)
      assert.equals("<leader>kx", topsail.config.keymaps.copy)
    end)
  end)

  describe("buffer keymap setup", function()
    it("should export setup_buffer_keymaps function", function()
      assert.is_function(topsail.setup_buffer_keymaps)
    end)

    it("should export copy_resource function", function()
      assert.is_function(topsail.copy_resource)
    end)

    it("should have all required keymap functions", function()
      assert.is_function(topsail.apply_resource)
      assert.is_function(topsail.create_resource)
      assert.is_function(topsail.copy_resource)
    end)
  end)

  describe("kubernetes resource detection", function()
    it("should export detect_kubernetes_resource function", function()
      assert.is_function(topsail.detect_kubernetes_resource)
    end)

    it("should detect valid kubernetes resources", function()
      vim.cmd("edit " .. temp_file)

      local detection_result = nil
      topsail.detect_kubernetes_resource(function(is_kubernetes)
        detection_result = is_kubernetes
      end)

      -- Wait a bit for the async operation
      vim.wait(1000, function()
        return detection_result ~= nil
      end)

      -- Should detect as kubernetes resource
      assert.is_true(detection_result)
    end)
  end)
end)
