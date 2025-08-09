local picker = require("telescope.topsail.picker")
local topsail = require("topsail")

describe("performance tests", function()
  local temp_dir
  local large_files = {}

  -- Generate a large YAML file with many resources
  local function generate_large_yaml(num_resources)
    local yaml_parts = {}
    
    for i = 1, num_resources do
      local resource = string.format([[
apiVersion: v1
kind: ConfigMap
metadata:
  name: perf-test-config-%d
  namespace: perf-test-ns-%d
  labels:
    app: perf-test
    instance: config-%d
  annotations:
    description: "Performance test ConfigMap number %d"
    created-by: "topsail-performance-test"
data:
  config-%d.yaml: |
    setting1: value1-%d
    setting2: value2-%d
    setting3: value3-%d
    nested:
      key1: nested-value1-%d
      key2: nested-value2-%d
      key3: nested-value3-%d
  app.properties: |
    app.name=perf-test-%d
    app.version=1.0.%d
    app.environment=test
    app.debug=true
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: perf-test-deployment-%d
  namespace: perf-test-ns-%d
  labels:
    app: perf-test
    component: deployment-%d
spec:
  replicas: 3
  selector:
    matchLabels:
      app: perf-test
      component: deployment-%d
  template:
    metadata:
      labels:
        app: perf-test
        component: deployment-%d
    spec:
      containers:
      - name: app-%d
        image: nginx:1.21-alpine
        ports:
        - containerPort: 80
          name: http
        env:
        - name: INSTANCE_ID
          value: "%d"
        - name: CONFIG_NAME
          value: "perf-test-config-%d"
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
        volumeMounts:
        - name: config-volume
          mountPath: /etc/config
      volumes:
      - name: config-volume
        configMap:
          name: perf-test-config-%d
---
apiVersion: v1
kind: Service
metadata:
  name: perf-test-service-%d
  namespace: perf-test-ns-%d
  labels:
    app: perf-test
    component: service-%d
spec:
  selector:
    app: perf-test
    component: deployment-%d
  ports:
  - port: 80
    targetPort: 8080
    name: http
  - port: 443
    targetPort: 8443
    name: https
  type: ClusterIP
]], i, i, i, i, i, i, i, i, i, i, i, i, i, i, i, i, i, i, i, i, i, i, i, i, i, i, i)
      
      table.insert(yaml_parts, resource)
    end
    
    return table.concat(yaml_parts, "\n---\n")
  end

  before_each(function()
    temp_dir = vim.fn.tempname()
    vim.fn.mkdir(temp_dir, "p")
  end)

  after_each(function()
    for _, file in ipairs(large_files) do
      vim.fn.delete(file)
    end
    vim.fn.delete(temp_dir, "rf")
    large_files = {}
  end)

  describe("large file parsing performance", function()
    it("should parse 50 resources efficiently", function()
      local start_time = vim.loop.hrtime()
      
      -- Create file with 50 resources (150 total objects)
      local large_yaml = generate_large_yaml(50)
      local large_file = temp_dir .. "/large-50-resources.yaml"
      local file = io.open(large_file, "w")
      if file then
        file:write(large_yaml)
        file:close()
        table.insert(large_files, large_file)
      end
      
      -- Parse the file
      local resources = picker.get_kubernetes_yaml_resources(large_file)
      
      local end_time = vim.loop.hrtime()
      local duration_ms = (end_time - start_time) / 1000000  -- Convert to milliseconds
      
      -- Performance assertion: should complete within 500ms
      assert.is_true(duration_ms < 500, string.format("Parsing took %dms, expected < 500ms", duration_ms))
      
      -- Verify parsing worked correctly
      if resources then
        assert.is_true(#resources >= 150, "Should find at least 150 resources")
        
        -- Verify resource structure
        for _, resource in ipairs(resources) do
          assert.is_table(resource)
          assert.is_string(resource.kind)
          assert.is_string(resource.name)
          assert.is_number(resource.lnum)
        end
      end
    end)

    it("should parse 100 resources efficiently", function()
      local start_time = vim.loop.hrtime()
      
      -- Create file with 100 resources (300 total objects)
      local large_yaml = generate_large_yaml(100)
      local large_file = temp_dir .. "/large-100-resources.yaml"
      local file = io.open(large_file, "w")
      if file then
        file:write(large_yaml)
        file:close()
        table.insert(large_files, large_file)
      end
      
      local resources = picker.get_kubernetes_yaml_resources(large_file)
      
      local end_time = vim.loop.hrtime()
      local duration_ms = (end_time - start_time) / 1000000
      
      -- Performance assertion: should complete within 1 second
      assert.is_true(duration_ms < 1000, string.format("Parsing took %dms, expected < 1000ms", duration_ms))
      
      if resources then
        assert.is_true(#resources >= 300, "Should find at least 300 resources")
      end
    end)

    it("should handle very large files gracefully", function()
      local start_time = vim.loop.hrtime()
      
      -- Create file with 200 resources (600 total objects)
      local large_yaml = generate_large_yaml(200)
      local large_file = temp_dir .. "/very-large-200-resources.yaml"
      local file = io.open(large_file, "w")
      if file then
        file:write(large_yaml)
        file:close()
        table.insert(large_files, large_file)
      end
      
      local resources = picker.get_kubernetes_yaml_resources(large_file)
      
      local end_time = vim.loop.hrtime()
      local duration_ms = (end_time - start_time) / 1000000
      
      -- Performance assertion: should complete within 2 seconds even for very large files
      assert.is_true(duration_ms < 2000, string.format("Parsing took %dms, expected < 2000ms", duration_ms))
      
      -- Should not crash (resources might be nil if treesitter unavailable)
      -- This is acceptable behavior
    end)
  end)

  describe("copy operation performance", function()
    it("should copy large files efficiently", function()
      local large_yaml = generate_large_yaml(50)
      local large_file = temp_dir .. "/copy-perf-test.yaml"
      local file = io.open(large_file, "w")
      if file then
        file:write(large_yaml)
        file:close()
        table.insert(large_files, large_file)
      end
      
      local copy_completed = false
      local register_content = ""
      
      -- Mock register operations
      local original_setreg = vim.fn.setreg
      vim.fn.setreg = function(reg, content)
        register_content = content
        copy_completed = true
      end
      
      local start_time = vim.loop.hrtime()
      
      -- Open file and copy
      vim.cmd("edit " .. large_file)
      topsail.copy_resource()
      
      local end_time = vim.loop.hrtime()
      local duration_ms = (end_time - start_time) / 1000000
      
      -- Performance assertion: copy should complete within 200ms
      assert.is_true(duration_ms < 200, string.format("Copy took %dms, expected < 200ms", duration_ms))
      assert.is_true(copy_completed)
      assert.is_true(#register_content > 1000, "Should copy substantial content")
      
      vim.fn.setreg = original_setreg
    end)

    it("should handle multiple rapid copy operations", function()
      local yaml_content = generate_large_yaml(20)
      local test_file = temp_dir .. "/rapid-copy-test.yaml"
      local file = io.open(test_file, "w")
      if file then
        file:write(yaml_content)
        file:close()
        table.insert(large_files, test_file)
      end
      
      local copy_count = 0
      local original_setreg = vim.fn.setreg
      vim.fn.setreg = function(reg, content)
        copy_count = copy_count + 1
      end
      
      vim.cmd("edit " .. test_file)
      
      local start_time = vim.loop.hrtime()
      
      -- Perform 10 rapid copy operations
      for i = 1, 10 do
        topsail.copy_resource()
      end
      
      local end_time = vim.loop.hrtime()
      local duration_ms = (end_time - start_time) / 1000000
      
      -- Performance assertion: 10 copies should complete within 500ms
      assert.is_true(duration_ms < 500, string.format("10 copies took %dms, expected < 500ms", duration_ms))
      assert.equals(10, copy_count)
      
      vim.fn.setreg = original_setreg
    end)
  end)

  describe("telescope picker performance", function()
    it("should handle workspace with many files efficiently", function()
      -- Create multiple large files
      for i = 1, 20 do
        local yaml_content = generate_large_yaml(10)  -- 10 resources per file
        local file_path = temp_dir .. "/workspace-perf-" .. i .. ".yaml"
        local file = io.open(file_path, "w")
        if file then
          file:write(yaml_content)
          file:close()
          table.insert(large_files, file_path)
        end
      end
      
      local picker_created = false
      local start_time = vim.loop.hrtime()
      
      -- Mock telescope picker creation
      local original_new = require("telescope.pickers").new
      require("telescope.pickers").new = function(opts, config)
        picker_created = true
        return { find = function() end }
      end
      
      -- Create workspace picker
      picker.workspace({ cwd = temp_dir })
      
      local end_time = vim.loop.hrtime()
      local duration_ms = (end_time - start_time) / 1000000
      
      -- Performance assertion: workspace creation should complete within 1 second
      assert.is_true(duration_ms < 1000, string.format("Workspace creation took %dms, expected < 1000ms", duration_ms))
      assert.is_true(picker_created)
      
      require("telescope.pickers").new = original_new
    end)

    it("should handle resource extraction performance", function()
      local yaml_content = generate_large_yaml(100)
      local large_file = temp_dir .. "/extraction-perf-test.yaml"
      local file = io.open(large_file, "w")
      if file then
        file:write(yaml_content)
        file:close()
        table.insert(large_files, large_file)
      end
      
      local start_time = vim.loop.hrtime()
      
      -- Test resource extraction multiple times
      for i = 1, 5 do
        local resources = picker.get_kubernetes_yaml_resources(large_file)
        -- Resources might be nil if treesitter is unavailable, which is OK
      end
      
      local end_time = vim.loop.hrtime()
      local duration_ms = (end_time - start_time) / 1000000
      
      -- Performance assertion: 5 extractions should complete within 2 seconds
      assert.is_true(duration_ms < 2000, string.format("5 extractions took %dms, expected < 2000ms", duration_ms))
    end)
  end)

  describe("memory usage performance", function()
    it("should not leak memory during repeated operations", function()
      local yaml_content = generate_large_yaml(50)
      local test_file = temp_dir .. "/memory-test.yaml"
      local file = io.open(test_file, "w")
      if file then
        file:write(yaml_content)
        file:close()
        table.insert(large_files, test_file)
      end
      
      -- Force garbage collection before test
      collectgarbage("collect")
      local initial_memory = collectgarbage("count")
      
      -- Perform many operations
      for i = 1, 50 do
        local resources = picker.get_kubernetes_yaml_resources(test_file)
        if i % 10 == 0 then
          collectgarbage("collect")  -- Periodic cleanup
        end
      end
      
      -- Force final garbage collection
      collectgarbage("collect")
      local final_memory = collectgarbage("count")
      
      local memory_increase = final_memory - initial_memory
      
      -- Memory assertion: should not increase by more than 10MB
      assert.is_true(memory_increase < 10240, string.format("Memory increased by %.2fKB, expected < 10MB", memory_increase))
    end)

    it("should handle concurrent operations efficiently", function()
      local yaml_content = generate_large_yaml(30)
      local concurrent_files = {}
      
      -- Create multiple files for concurrent testing
      for i = 1, 5 do
        local file_path = temp_dir .. "/concurrent-" .. i .. ".yaml"
        local file = io.open(file_path, "w")
        if file then
          file:write(yaml_content)
          file:close()
          table.insert(large_files, file_path)
          table.insert(concurrent_files, file_path)
        end
      end
      
      local start_time = vim.loop.hrtime()
      local completed_operations = 0
      
      -- Simulate concurrent operations
      for _, file_path in ipairs(concurrent_files) do
        vim.schedule(function()
          local resources = picker.get_kubernetes_yaml_resources(file_path)
          completed_operations = completed_operations + 1
        end)
      end
      
      -- Wait for all operations to complete
      vim.wait(2000, function()
        return completed_operations == #concurrent_files
      end)
      
      local end_time = vim.loop.hrtime()
      local duration_ms = (end_time - start_time) / 1000000
      
      -- Performance assertion: concurrent operations should complete within 3 seconds
      assert.is_true(duration_ms < 3000, string.format("Concurrent operations took %dms, expected < 3000ms", duration_ms))
      assert.equals(#concurrent_files, completed_operations)
    end)
  end)
end)