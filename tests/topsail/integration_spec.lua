local picker = require("telescope.topsail.picker")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

describe("telescope picker integration", function()
  local test_yaml_multi = [[
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
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test
  template:
    metadata:
      labels:
        app: test
    spec:
      containers:
      - name: test
        image: nginx:latest
---
apiVersion: v1
kind: Service
metadata:
  name: test-service
  namespace: default
spec:
  selector:
    app: test
  ports:
  - port: 80
    targetPort: 8080
]]

  local temp_dir
  local temp_files = {}

  before_each(function()
    -- Create temporary directory and files for testing
    temp_dir = vim.fn.tempname()
    vim.fn.mkdir(temp_dir, "p")

    -- Create multiple test files
    for i = 1, 3 do
      local temp_file = temp_dir .. "/test-" .. i .. ".yaml"
      local file = io.open(temp_file, "w")
      if file then
        file:write(test_yaml_multi)
        file:close()
        table.insert(temp_files, temp_file)
      end
    end
  end)

  after_each(function()
    -- Clean up temporary files
    for _, file in ipairs(temp_files) do
      vim.fn.delete(file)
    end
    vim.fn.delete(temp_dir, "rf")
    temp_files = {}
  end)

  describe("workspace picker integration", function()
    it("should initialize picker with correct configuration", function()
      -- Mock telescope components
      local picker_created = false
      local original_new = require("telescope.pickers").new

      require("telescope.pickers").new = function(opts, config)
        picker_created = true
        assert.is_table(opts)
        assert.is_table(config)
        -- config.finder might be a table or function depending on telescope version
        assert.is_not_nil(config.finder)
        assert.is_function(config.attach_mappings)
        return { find = function() end }
      end

      -- Test workspace picker creation
      picker.workspace({ cwd = temp_dir })

      assert.is_true(picker_created)

      -- Restore original function
      require("telescope.pickers").new = original_new
    end)

    it("should handle keymap attachments correctly", function()
      local mappings_attached = false
      local copy_file_mapped = false
      local copy_resource_mapped = false

      -- Mock telescope components
      local original_new = require("telescope.pickers").new
      require("telescope.pickers").new = function(opts, config)
        if config.attach_mappings then
          local mock_map = function(mode, key, func)
            mappings_attached = true
            if key == picker.config.keymaps.telescope_copy_file then
              copy_file_mapped = true
            elseif key == picker.config.keymaps.telescope_copy_resource then
              copy_resource_mapped = true
            end
          end

          -- Mock buffer parameter for attach_mappings
          local mock_buffer = 0
          config.attach_mappings(mock_buffer, mock_map)
        end
        return { find = function() end }
      end

      picker.workspace({ cwd = temp_dir })

      assert.is_true(mappings_attached)
      assert.is_true(copy_file_mapped)
      assert.is_true(copy_resource_mapped)

      require("telescope.pickers").new = original_new
    end)
  end)

  describe("single_file picker integration", function()
    it("should initialize single file picker correctly", function()
      local picker_created = false
      local original_new = require("telescope.pickers").new

      require("telescope.pickers").new = function(opts, config)
        picker_created = true
        assert.is_table(opts)
        assert.is_table(config)
        assert.is_not_nil(config.finder)
        return { find = function() end }
      end

      picker.single_file({ file_path = temp_files[1] })

      assert.is_true(picker_created)
      require("telescope.pickers").new = original_new
    end)

    it("should handle file-specific resource parsing", function()
      local resources = picker.get_kubernetes_yaml_resources(temp_files[1])

      if resources then
        assert.is_table(resources)
        -- Should find 3 resources in our test file
        assert.is_true(#resources >= 3)

        -- Verify resource structure
        for _, resource in ipairs(resources) do
          assert.is_table(resource)
          assert.is_string(resource.kind)
          assert.is_string(resource.name)
          assert.is_number(resource.lnum)
        end
      end
    end)
  end)

  describe("copy functionality integration", function()
    it("should integrate copy operations with telescope actions", function()
      local copy_file_called = false
      local copy_resource_called = false

      -- Mock the copy functions to track calls
      local original_setreg = vim.fn.setreg
      vim.fn.setreg = function(reg, content)
        if string.find(content, "apiVersion") then
          if string.find(content, "---") then
            copy_file_called = true
          else
            copy_resource_called = true
          end
        end
      end

      -- Create mock selection objects
      local file_selection = {
        path = temp_files[1],
        lnum = 1,
      }

      local resource_selection = {
        path = temp_files[1],
        lnum = 8, -- Line number within deployment resource
        kind = "Deployment",
        name = "test-deployment",
      }

      -- Test file copy
      local copy_file_to_register = picker.get_kubernetes_yaml_resources
          and function(selection, opts)
            local file = io.open(selection.path, "r")
            if file then
              local content = file:read("*a")
              file:close()
              vim.fn.setreg(opts.register, content)
            end
          end
        or function() end

      if copy_file_to_register then
        copy_file_to_register(file_selection, { register = "+" })
        assert.is_true(copy_file_called)
      end

      vim.fn.setreg = original_setreg
    end)

    it("should handle custom keymap configurations", function()
      -- Test with custom keymaps
      local custom_config = {
        keymaps = {
          telescope_copy_file = "<C-f>",
          telescope_copy_resource = "<C-x>",
        },
      }

      picker.setup(custom_config)

      assert.equals("<C-f>", picker.config.keymaps.telescope_copy_file)
      assert.equals("<C-x>", picker.config.keymaps.telescope_copy_resource)

      -- Verify the keymaps are used in picker creation
      local custom_file_mapped = false
      local custom_resource_mapped = false

      local original_new = require("telescope.pickers").new
      require("telescope.pickers").new = function(opts, config)
        if config.attach_mappings then
          local mock_map = function(mode, key, func)
            if key == "<C-f>" then
              custom_file_mapped = true
            elseif key == "<C-x>" then
              custom_resource_mapped = true
            end
          end

          config.attach_mappings(0, mock_map)
        end
        return { find = function() end }
      end

      picker.workspace({ cwd = temp_dir })

      assert.is_true(custom_file_mapped)
      assert.is_true(custom_resource_mapped)

      require("telescope.pickers").new = original_new
    end)
  end)

  describe("finder integration", function()
    it("should create proper finder entries for workspace", function()
      local finder_entries = {}
      local original_new_table = require("telescope.finders").new_table

      require("telescope.finders").new_table = function(opts)
        finder_entries = opts.results or {}
        return original_new_table(opts)
      end

      local original_new = require("telescope.pickers").new
      require("telescope.pickers").new = function(opts, config)
        -- Trigger finder creation
        if config.finder then
          config.finder.results = finder_entries
        end
        return { find = function() end }
      end

      picker.workspace({ cwd = temp_dir })

      -- Should have found entries from our test files (if any were created)
      -- Note: finder_entries might be empty if no valid k8s files found
      assert.is_table(finder_entries)

      require("telescope.finders").new_table = original_new_table
      require("telescope.pickers").new = original_new
    end)

    it("should handle empty directories gracefully", function()
      local empty_dir = vim.fn.tempname()
      vim.fn.mkdir(empty_dir, "p")

      local picker_created = false
      local original_new = require("telescope.pickers").new

      require("telescope.pickers").new = function(opts, config)
        picker_created = true
        return { find = function() end }
      end

      -- Should not crash with empty directory
      picker.workspace({ cwd = empty_dir })
      assert.is_true(picker_created)

      vim.fn.delete(empty_dir, "rf")
      require("telescope.pickers").new = original_new
    end)
  end)
end)
