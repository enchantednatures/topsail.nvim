local plugin = require("topsail")

describe("error handling", function()
  -- Store original functions
  local original_jobstart
  local original_notify

  before_each(function()
    -- Save original functions
    original_jobstart = vim.fn.jobstart
    original_notify = vim.notify

    -- Create a test buffer
    vim.cmd("new")
  end)

  after_each(function()
    -- Restore original functions
    vim.fn.jobstart = original_jobstart
    vim.notify = original_notify

    -- Clean up the buffer
    vim.cmd("bdelete!")
  end)

  it("should handle invalid YAML gracefully", function()
    -- Mock invalid YAML content
    local invalid_yaml = [[
apiVersion v1  # Missing colon
kind: Pod
metadata:
  name nginx   # Missing colon
]]

    -- Set buffer content
    vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(invalid_yaml, "\n"))

    -- Mock jobstart to simulate kubectl failure
    vim.fn.jobstart = function(cmd, opts)
      vim.schedule(function()
        opts.on_stderr(0, { "Error: invalid YAML" })
        opts.on_exit(0, 1) -- exit_code 1 means error
      end)
      return 1234 -- Return a fake job id
    end

    -- Capture notifications
    local notifications = {}
    vim.notify = function(msg, level)
      table.insert(notifications, { message = msg, level = level })
    end

    -- Test callback handling
    local detection_result
    plugin.detect_kubernetes_resource(function(is_kubernetes)
      detection_result = is_kubernetes
    end)

    -- Wait for async callback to complete
    vim.defer_fn(function()
      assert.is_false(detection_result)
    end, 50)
  end)

  it("should handle kubectl not found gracefully", function()
    -- Set up test environment
    local mock_buffer_content = [[
apiVersion: v1
kind: Pod
metadata:
  name: nginx
]]
    vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(mock_buffer_content, "\n"))

    -- Mock jobstart to simulate kubectl not found
    vim.fn.jobstart = function(cmd, opts)
      vim.schedule(function()
        opts.on_exit(0, 127) -- exit_code 127 often means command not found
      end)
      return 1234 -- Return a fake job id
    end

    -- Capture notifications
    local notifications = {}
    vim.notify = function(msg, level)
      table.insert(notifications, { message = msg, level = level })
    end

    -- Test callback handling
    local detection_result
    plugin.detect_kubernetes_resource(function(is_kubernetes)
      detection_result = is_kubernetes
    end)

    -- Wait for async callback to complete
    vim.defer_fn(function()
      assert.is_false(detection_result)
    end, 50)
  end)

  it("should handle empty files", function()
    -- Set up an empty buffer
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })

    -- Mock jobstart
    vim.fn.jobstart = function(cmd, opts)
      vim.schedule(function()
        opts.on_stderr(0, { "Error: empty file" })
        opts.on_exit(0, 1) -- exit_code 1 means error
      end)
      return 1234 -- Return a fake job id
    end

    -- Capture notifications
    local notifications = {}
    vim.notify = function(msg, level)
      table.insert(notifications, { message = msg, level = level })
    end

    -- Test callback handling
    local detection_result
    plugin.detect_kubernetes_resource(function(is_kubernetes)
      detection_result = is_kubernetes
    end)

    -- Wait for async callback to complete
    vim.defer_fn(function()
      assert.is_false(detection_result)
    end, 50)
  end)
end)
