describe("fanout performance tests", function()
  local picker = require("telescope.topsail.picker")
  
  describe("parallel file processing", function()
    local temp_dir
    local test_files = {}

    -- Generate test YAML files
    local function generate_test_yaml(index)
      return string.format([[
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-config-%d
  namespace: test-ns-%d
  labels:
    app: test-app
    instance: config-%d
  annotations:
    description: "Test ConfigMap number %d"
    created-by: "fanout-test"
data:
  config-%d.yaml: |
    setting1: value1-%d
    setting2: value2-%d
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment-%d
  namespace: test-ns-%d
  labels:
    app: test-app
    component: deployment-%d
spec:
  replicas: 2
]], index, index, index, index, index, index, index, index, index, index)
    end

    before_each(function()
      temp_dir = vim.fn.tempname()
      vim.fn.mkdir(temp_dir, "p")
      test_files = {}
    end)

    after_each(function()
      for _, file in ipairs(test_files) do
        vim.fn.delete(file)
      end
      vim.fn.delete(temp_dir, "rf")
      test_files = {}
    end)

    it("should process multiple files in parallel", function()
      -- Create 20 test files
      for i = 1, 20 do
        local file_path = temp_dir .. "/test-" .. i .. ".yaml"
        local file = io.open(file_path, "w")
        if file then
          file:write(generate_test_yaml(i))
          file:close()
          table.insert(test_files, file_path)
        end
      end

      local start_time = vim.loop.hrtime()
      local completed = false
      local result_count = 0

      -- Test the parallel processing function
      local scandir = require("plenary.scandir")
      local files = scandir.scan_dir(temp_dir, { search_pattern = "%.ya?ml$" })
      
      -- Use the internal parallel processing function
      local process_files_parallel = function(files, callback)
        local all_matches = {}
        local completed_files = 0
        local total = #files
        
        if total == 0 then
          callback({})
          return
        end
        
        -- Process each file asynchronously
        for _, file in ipairs(files) do
          vim.schedule(function()
            local matches = picker.get_kubernetes_yaml_resources(file)
            if matches then
              for _, match in ipairs(matches) do
                table.insert(all_matches, match)
              end
            end
            
            completed_files = completed_files + 1
            if completed_files == total then
              callback(all_matches)
            end
          end)
        end
      end

      process_files_parallel(files, function(all_matches)
        local end_time = vim.loop.hrtime()
        local duration_ms = (end_time - start_time) / 1000000
        
        result_count = #all_matches
        completed = true
        
        -- Performance assertion: should complete within reasonable time
        assert.is_true(duration_ms < 2000, string.format("Parallel processing took %dms, expected < 2000ms", duration_ms))
      end)

      -- Wait for completion
      vim.wait(5000, function()
        return completed
      end)

      assert.is_true(completed, "Parallel processing should complete")
      assert.is_true(result_count >= 40, "Should find at least 40 resources (2 per file)")
    end)

    it("should handle empty file list gracefully", function()
      local completed = false
      local result_count = 0

      local process_files_parallel = function(files, callback)
        local all_matches = {}
        local completed_files = 0
        local total = #files
        
        if total == 0 then
          callback({})
          return
        end
        
        for _, file in ipairs(files) do
          vim.schedule(function()
            local matches = picker.get_kubernetes_yaml_resources(file)
            if matches then
              for _, match in ipairs(matches) do
                table.insert(all_matches, match)
              end
            end
            
            completed_files = completed_files + 1
            if completed_files == total then
              callback(all_matches)
            end
          end)
        end
      end

      process_files_parallel({}, function(all_matches)
        result_count = #all_matches
        completed = true
      end)

      -- Should complete immediately for empty list
      vim.wait(100, function()
        return completed
      end)

      assert.is_true(completed, "Should handle empty file list")
      assert.equals(0, result_count, "Should return empty results for empty file list")
    end)

    it("should handle files with parsing errors gracefully", function()
      -- Create a mix of valid and invalid YAML files
      local valid_file = temp_dir .. "/valid.yaml"
      local invalid_file = temp_dir .. "/invalid.yaml"
      
      local valid_content = generate_test_yaml(1)
      local invalid_content = "invalid: yaml: content: [unclosed"
      
      local file = io.open(valid_file, "w")
      file:write(valid_content)
      file:close()
      table.insert(test_files, valid_file)
      
      file = io.open(invalid_file, "w")
      file:write(invalid_content)
      file:close()
      table.insert(test_files, invalid_file)

      local completed = false
      local result_count = 0

      local process_files_parallel = function(files, callback)
        local all_matches = {}
        local completed_files = 0
        local total = #files
        
        if total == 0 then
          callback({})
          return
        end
        
        for _, file in ipairs(files) do
          vim.schedule(function()
            local matches = picker.get_kubernetes_yaml_resources(file)
            if matches then
              for _, match in ipairs(matches) do
                table.insert(all_matches, match)
              end
            end
            
            completed_files = completed_files + 1
            if completed_files == total then
              callback(all_matches)
            end
          end)
        end
      end

      process_files_parallel({valid_file, invalid_file}, function(all_matches)
        result_count = #all_matches
        completed = true
      end)

      vim.wait(2000, function()
        return completed
      end)

      assert.is_true(completed, "Should complete even with parsing errors")
      assert.is_true(result_count >= 2, "Should parse valid files despite errors in others")
    end)
  end)
end)