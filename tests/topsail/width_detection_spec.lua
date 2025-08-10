local picker = require("telescope.topsail.picker")

describe("width detection and table sizing", function()
  local test_resources = {
    {
      apiVersion = "v1",
      kind = "ConfigMap",
      name = "short-name",
      namespace = "default",
      lnum = 1,
      filename = "config.yaml",
      dir = "manifests",
      full_path = "/path/to/manifests/config.yaml",
    },
    {
      apiVersion = "apps/v1",
      kind = "Deployment",
      name = "very-long-deployment-name-that-exceeds-normal-width",
      namespace = "production-environment",
      lnum = 10,
      filename = "deployment.yaml",
      dir = "apps",
      full_path = "/path/to/apps/deployment.yaml",
    },
    {
      apiVersion = "networking.k8s.io/v1",
      kind = "NetworkPolicy",
      name = "medium-length-policy",
      namespace = "staging",
      lnum = 5,
      filename = "network.yaml",
      dir = "networking",
      full_path = "/path/to/networking/network.yaml",
    },
  }

  describe("get_picker_width", function()
    it("should detect telescope picker width", function()
      local width = picker.get_picker_width()
      assert.is_number(width)
      assert.is_true(width > 0)
    end)

    it("should return reasonable default when detection fails", function()
      -- Mock vim.api to simulate failure
      local original_nvim_get_option = vim.api.nvim_get_option
      vim.api.nvim_get_option = function()
        error("Mock error")
      end

      local width = picker.get_picker_width()
      assert.is_number(width)
      assert.is_true(width >= 80) -- Should fallback to reasonable default

      -- Restore original function
      vim.api.nvim_get_option = original_nvim_get_option
    end)
  end)

  describe("calculate_column_widths", function()
    it("should calculate optimal column widths based on content", function()
      local widths = picker.calculate_column_widths(test_resources, 200) -- Use wider picker for this test
      
      assert.is_table(widths)
      assert.is_number(widths.name)
      assert.is_number(widths.namespace)
      assert.is_number(widths.kind)
      assert.is_number(widths.apiVersion)
      assert.is_number(widths.filename)
      assert.is_number(widths.dir)
      
      -- Should accommodate the longest name when space allows
      assert.is_true(widths.name >= string.len("very-long-deployment-name-that-exceeds-normal-width"))
      
      -- Should accommodate the longest namespace when space allows
      assert.is_true(widths.namespace >= string.len("production-environment"))
      
      -- Should accommodate the longest apiVersion when space allows
      assert.is_true(widths.apiVersion >= string.len("networking.k8s.io/v1"))
    end)

    it("should respect minimum column widths", function()
      local widths = picker.calculate_column_widths(test_resources, 120)
      
      -- All columns should have minimum reasonable widths
      assert.is_true(widths.name >= 8)
      assert.is_true(widths.namespace >= 8)
      assert.is_true(widths.kind >= 8)
      assert.is_true(widths.apiVersion >= 8)
      assert.is_true(widths.filename >= 8)
      assert.is_true(widths.dir >= 8)
    end)

    it("should handle narrow picker widths gracefully", function()
      local widths = picker.calculate_column_widths(test_resources, 80) -- Use more realistic narrow width
      
      -- Should still provide reasonable widths even with constraints
      local total_width = widths.name + widths.namespace + widths.kind + 
                         widths.apiVersion + widths.filename + widths.dir + 5 -- spaces
      assert.is_true(total_width <= 80)
      
      -- All columns should still have minimum widths
      assert.is_true(widths.name >= 8)
      assert.is_true(widths.namespace >= 8)
      assert.is_true(widths.kind >= 8)
      assert.is_true(widths.apiVersion >= 8)
      assert.is_true(widths.filename >= 8)
      assert.is_true(widths.dir >= 8)
    end)

    it("should handle empty resources list", function()
      local widths = picker.calculate_column_widths({}, 120)
      
      assert.is_table(widths)
      -- Should return minimum widths for empty list
      assert.is_true(widths.name >= 8)
      assert.is_true(widths.namespace >= 8)
    end)
  end)

  describe("format_table_entry", function()
    it("should format entries with calculated widths", function()
      local widths = {
        name = 20,
        namespace = 15,
        kind = 12,
        apiVersion = 18,
        filename = 15,
        dir = 10
      }
      
      local entry = test_resources[1]
      local formatted = picker.format_table_entry(entry, widths)
      
      assert.is_string(formatted)
      -- Should contain all the expected data
      assert.has_match("short%-name", formatted)
      assert.has_match("default", formatted)
      assert.has_match("ConfigMap", formatted)
      assert.has_match("v1", formatted)
    end)

    it("should handle long names with proper truncation", function()
      local widths = {
        name = 15, -- Shorter than the long name
        namespace = 15,
        kind = 12,
        apiVersion = 18,
        filename = 15,
        dir = 10
      }
      
      local entry = test_resources[2] -- Has very long name
      local formatted = picker.format_table_entry(entry, widths)
      
      assert.is_string(formatted)
      -- Should be properly formatted without exceeding width
      local name_part = formatted:match("^([^%s]*)")
      assert.is_true(string.len(name_part) <= widths.name)
    end)

    it("should handle nil values gracefully", function()
      local widths = {
        name = 20,
        namespace = 15,
        kind = 12,
        apiVersion = 18,
        filename = 15,
        dir = 10
      }
      
      local entry = {
        apiVersion = "v1",
        kind = "ConfigMap",
        name = "test",
        namespace = nil, -- nil namespace
        lnum = 1,
        filename = "test.yaml",
        dir = "test",
        full_path = "/test/test.yaml",
      }
      
      local formatted = picker.format_table_entry(entry, widths)
      assert.is_string(formatted)
      assert.has_match("test", formatted)
    end)
  end)

  describe("integration", function()
    it("should work together for dynamic table sizing", function()
      -- Simulate the full workflow
      local picker_width = 120
      local widths = picker.calculate_column_widths(test_resources, picker_width)
      
      for _, resource in ipairs(test_resources) do
        local formatted = picker.format_table_entry(resource, widths)
        assert.is_string(formatted)
        assert.is_true(string.len(formatted) <= picker_width)
      end
    end)
  end)
end)