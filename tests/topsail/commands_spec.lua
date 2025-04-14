local plugin = require("topsail")

describe("kubernetes commands", function()
  -- Store original functions
  local original_jobstart
  local original_notify
  local original_expand

  local mock_kubectl_commands = {}
  local notifications = {}

  before_each(function()
    -- Save original functions
    original_jobstart = vim.fn.jobstart
    original_notify = vim.notify
    original_expand = vim.fn.expand

    -- Mock vim.notify to capture notifications
    vim.notify = function(msg, level)
      table.insert(notifications, { message = msg, level = level })
    end

    -- Mock vim.fn.expand to return a consistent file path
    vim.fn.expand = function(pattern)
      if pattern == "%" then
        return "/mock/path/deployment.yaml"
      end
      return pattern
    end

    -- Mock jobstart to simulate kubectl
    vim.fn.jobstart = function(cmd, opts)
      table.insert(mock_kubectl_commands, cmd)
      
      -- Simulate command execution
      if opts.on_stdout then
        opts.on_stdout(0, { "resource created/applied successfully" })
      end
      
      if opts.on_exit then
        opts.on_exit(0, 0) -- exit_code 0 means success
      end
      
      return 1234 -- Return a fake job id
    end

    -- Reset test state
    mock_kubectl_commands = {}
    notifications = {}
    
    -- Make sure notify is enabled
    plugin.config.notify = true
  end)

  after_each(function()
    -- Restore original functions
    vim.fn.jobstart = original_jobstart
    vim.notify = original_notify
    vim.fn.expand = original_expand
  end)

  it("should execute kubectl apply command", function()
    plugin.apply_resource()
    
    -- Check if jobstart was called with the correct command
    assert.equals(1, #mock_kubectl_commands)
    assert.same({"kubectl", "apply", "-f", "/mock/path/deployment.yaml"}, mock_kubectl_commands[1])
    
    -- Verify notification was sent
    assert.equals(1, #notifications)
    assert.equals("resource created/applied successfully", notifications[1].message)
    assert.equals(vim.log.levels.INFO, notifications[1].level)
  end)

  it("should execute kubectl create command", function()
    plugin.create_resource()
    
    -- Check if jobstart was called with the correct command
    assert.equals(1, #mock_kubectl_commands)
    assert.same({"kubectl", "create", "-f", "/mock/path/deployment.yaml"}, mock_kubectl_commands[1])
    
    -- Verify notification was sent
    assert.equals(1, #notifications)
    assert.equals("resource created/applied successfully", notifications[1].message)
    assert.equals(vim.log.levels.INFO, notifications[1].level)
  end)
  
  it("should respect notify setting", function()
    plugin.config.notify = false
    plugin.apply_resource()
    
    -- Verify no notification was sent
    assert.equals(0, #notifications)
  end)
  
  it("should handle command errors", function()
    -- Override jobstart to simulate an error
    vim.fn.jobstart = function(cmd, opts)
      table.insert(mock_kubectl_commands, cmd)
      
      -- Simulate an error
      if opts.on_stderr then
        opts.on_stderr(0, { "Error: resource not found" })
      end
      
      if opts.on_exit then
        opts.on_exit(0, 1) -- exit_code 1 means error
      end
      
      return 1234 -- Return a fake job id
    end
    
    plugin.apply_resource()
    
    -- Verify error notification was sent
    assert.equals(1, #notifications)
    assert.equals("Error: resource not found", notifications[1].message)
    assert.equals(vim.log.levels.ERROR, notifications[1].level)
  end)
end)