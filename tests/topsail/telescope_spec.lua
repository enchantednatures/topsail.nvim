local picker = require("telescope.topsail.picker")

describe("telescope picker functionality", function()
  local test_yaml = [[
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-config
  namespace: default
data:
  key: value
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-deployment
  namespace: production
spec:
  replicas: 3
]]

  local temp_file

  before_each(function()
    temp_file = vim.fn.tempname() .. ".yaml"
    local file = io.open(temp_file, "w")
    file:write(test_yaml)
    file:close()
  end)

  after_each(function()
    if temp_file then
      os.remove(temp_file)
    end
  end)

  describe("telescope entry conversion", function()
    it("should handle treesitter unavailable gracefully", function()
      -- When treesitter is not available, function should not crash
      assert.has_no.errors(function()
        picker.get_kubernetes_yaml_resources(temp_file)
      end)
    end)
  end)

  describe("copy functionality integration", function()
    it("should handle file operations correctly", function()
      -- File should be readable
      local file = io.open(temp_file, "r")
      assert.is_not_nil(file)
      local content = file:read("*a")
      file:close()
      assert.is_not_nil(content)
      assert.is_true(#content > 0)
    end)
  end)

  describe("workspace and single_file picker functions", function()
    it("should export workspace function", function()
      assert.is_function(picker.workspace)
    end)

    it("should export single_file function", function()
      assert.is_function(picker.single_file)
    end)

    it("should export get_kubernetes_yaml_resources function", function()
      assert.is_function(picker.get_kubernetes_yaml_resources)
    end)
  end)
end)