local plugin = require("topsail")

describe("kubernetes detection", function()
    -- Store original jobstart function
    local original_jobstart
    local mock_buffer_content = [[
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
  - name: nginx
image: nginx:1.14.2
]]

    before_each(function()
        -- Save original jobstart
        original_jobstart = vim.fn.jobstart

        -- Mock jobstart to simulate kubectl response
        vim.fn.jobstart = function(cmd, opts)
            -- Simulate successful kubectl validation
            vim.schedule(function()
                opts.on_exit(0, 0) -- exit_code 0 means success
            end)
            return 1234            -- Return a fake job id
        end

        -- Create a new buffer with mock kubernetes content
        vim.cmd('new')
        local bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(mock_buffer_content, "\n"))
    end)

    after_each(function()
        -- Clean up the buffer
        vim.cmd('bdelete!')
        -- Restore original jobstart
        vim.fn.jobstart = original_jobstart
    end)

    it("should detect kubernetes resource", function(done)
        local detection_result = false

        plugin.detect_kubernetes_resource(function(is_kubernetes)
            detection_result = is_kubernetes
            -- Move the assertion inside the callback
            assert.is_true(detection_result, "Failed to detect kubernetes resource")
            done()
        end)
    end)
end)
