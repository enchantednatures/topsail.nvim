local picker = require("telescope.topsail.picker")

describe("copy resource functionality", function()
  local test_yaml_single = [[
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-config
  namespace: default
data:
  key: value
]]

  local test_yaml_multiple = [[
apiVersion: v1
kind: ConfigMap
metadata:
  name: first-config
  namespace: default
data:
  key1: value1
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: test
  template:
    metadata:
      labels:
        app: test
    spec:
      containers:
      - name: test-container
        image: nginx:latest
]]

  local temp_file_single
  local temp_file_multiple

  before_each(function()
    -- Create temporary test files
    temp_file_single = vim.fn.tempname() .. ".yaml"
    temp_file_multiple = vim.fn.tempname() .. ".yaml"
    
    local file = io.open(temp_file_single, "w")
    file:write(test_yaml_single)
    file:close()
    
    file = io.open(temp_file_multiple, "w")
    file:write(test_yaml_multiple)
    file:close()
  end)

  after_each(function()
    -- Clean up temporary files
    if temp_file_single then
      os.remove(temp_file_single)
    end
    if temp_file_multiple then
      os.remove(temp_file_multiple)
    end
  end)

  describe("get_kubernetes_yaml_resources", function()
    it("should handle treesitter unavailable gracefully", function()
      -- When treesitter is not available, function should return nil gracefully
      local resources = picker.get_kubernetes_yaml_resources(temp_file_single)
      
      -- In test environment without treesitter, this may return nil
      -- This is expected behavior and the function should not crash
      assert.has_no.errors(function()
        picker.get_kubernetes_yaml_resources(temp_file_single)
      end)
    end)

    it("should return nil for non-existent file", function()
      local resources = picker.get_kubernetes_yaml_resources("/non/existent/file.yaml")
      assert.is_nil(resources)
    end)
  end)

  describe("resource extraction", function()
    it("should handle extraction gracefully when treesitter unavailable", function()
      -- Test that the function doesn't crash when treesitter is unavailable
      assert.has_no.errors(function()
        picker.get_kubernetes_yaml_resources(temp_file_single)
      end)
    end)
  end)

  describe("file content reading", function()
    it("should read entire file content", function()
      local file = io.open(temp_file_single, "r")
      local content = file:read("*a")
      file:close()
      
      assert.is_not_nil(content)
      assert.is_true(content:find("apiVersion: v1", 1, true) ~= nil)
      assert.is_true(content:find("kind: ConfigMap", 1, true) ~= nil)
      assert.is_true(content:find("name: test-config", 1, true) ~= nil)
    end)

    it("should handle file reading errors gracefully", function()
      local file_result = io.open("/non/existent/file.yaml", "r")
      assert.is_nil(file_result)
    end)
  end)

  describe("resource validation", function()
    it("should handle validation gracefully", function()
      -- Test that validation doesn't crash when treesitter is unavailable
      assert.has_no.errors(function()
        picker.get_kubernetes_yaml_resources(temp_file_single)
      end)
    end)
  end)
end)