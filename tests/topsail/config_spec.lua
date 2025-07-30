local plugin = require("topsail")

describe("plugin configuration", function()
  local original_config

  before_each(function()
    -- Save original config
    original_config = vim.deepcopy(plugin.config)
  end)

  after_each(function()
    -- Restore original config
    plugin.config = original_config
  end)

  it("should use default configuration when not provided", function()
    plugin.setup({})

    -- Check default values
    assert.equals(true, plugin.config.notify)
    assert.equals("<leader>ka", plugin.config.keymaps.apply)
    assert.equals("<leader>kc", plugin.config.keymaps.create)
    assert.equals("<leader>ky", plugin.config.keymaps.copy)
    assert.equals("<C-y>", plugin.config.keymaps.telescope_copy_file)
    assert.equals("<C-r>", plugin.config.keymaps.telescope_copy_resource)
  end)

  it("should merge user configuration with defaults", function()
    plugin.setup({
      notify = false,
      keymaps = {
        apply = "<leader>kA",
      },
    })

    -- Check merged values
    assert.equals(false, plugin.config.notify)
    assert.equals("<leader>kA", plugin.config.keymaps.apply)
    assert.equals("<leader>kc", plugin.config.keymaps.create) -- Unchanged default
    assert.equals("<leader>ky", plugin.config.keymaps.copy) -- Unchanged default
    assert.equals("<C-y>", plugin.config.keymaps.telescope_copy_file) -- Unchanged default
    assert.equals("<C-r>", plugin.config.keymaps.telescope_copy_resource) -- Unchanged default
  end)

  it("should handle deep merging of complex configs", function()
    plugin.setup({
      keymaps = {
        apply = "<leader>kA",
        create = "<leader>kC",
      },
      custom_option = {
        foo = "bar",
      },
    })

    -- Check deep merged values
    assert.equals("<leader>kA", plugin.config.keymaps.apply)
    assert.equals("<leader>kC", plugin.config.keymaps.create)
    assert.equals("bar", plugin.config.custom_option.foo)
  end)

  it("should allow customizing telescope copy keymaps", function()
    plugin.setup({
      keymaps = {
        telescope_copy_file = "<C-f>",
        telescope_copy_resource = "<C-x>",
      },
    })

    -- Check telescope keymap values
    assert.equals("<C-f>", plugin.config.keymaps.telescope_copy_file)
    assert.equals("<C-x>", plugin.config.keymaps.telescope_copy_resource)
    -- Check other defaults are preserved
    assert.equals("<leader>ka", plugin.config.keymaps.apply)
    assert.equals("<leader>kc", plugin.config.keymaps.create)
    assert.equals("<leader>ky", plugin.config.keymaps.copy)
  end)
end)
