# topsail.nvim

Topsail is a comprehensive Neovim plugin for managing Kubernetes resources directly from your editor. It combines the power of kubectl with Neovim's editing capabilities, enhanced by TreeSitter parsing and Telescope integration.

## Features

### Core Functionality
- **Automatic Kubernetes YAML detection** - Intelligently detects Kubernetes resource files using `kubectl --dry-run`
- **Apply and Create resources** - Execute `kubectl apply` and `kubectl create` directly from Neovim
- **Async operations** - All kubectl operations run asynchronously without blocking the editor
- **Configurable notifications** - Get feedback on operations with customizable log levels

### Advanced Copy System
- **Smart resource copying** - Copy entire YAML files or individual resources from multi-resource files
- **TreeSitter-powered parsing** - Precise resource boundary detection using TreeSitter queries
- **Multiple copy modes** - Copy to system clipboard, named registers, or custom registers
- **Intelligent fallback** - Graceful degradation when TreeSitter is unavailable

### Telescope Integration
- **Workspace resource browser** - View all Kubernetes resources in your current working directory
- **Single-file resource picker** - Navigate resources within a specific YAML file
- **Interactive copying** - Copy resources directly from Telescope pickers
- **Resource metadata display** - See name, namespace, kind, API version, and file location at a glance

### Configuration & Customization
- **Flexible keymaps** - Customize all keybindings including Telescope picker actions
- **Configurable registers** - Choose which register to use for copy operations
- **Log level control** - Adjust notification verbosity from DEBUG to ERROR
- **Buffer-local mappings** - Automatic keymap setup for detected Kubernetes files

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "enchantednatures/topsail.nvim",
    lazy = true,
    event = {"VeryLazy"},
    cmd = {"KubernetesApply", "KubernetesCreate"},
    dependencies = {
        "nvim-telescope/telescope.nvim",  -- Required for resource browsing
        "nvim-treesitter/nvim-treesitter", -- Optional: for precise YAML parsing
    },
    keys = {
        { "<leader>ka", "<cmd>KubernetesApply<cr>", desc = "Apply the current Kubernetes resource" },
        { "<leader>kc", "<cmd>KubernetesCreate<cr>", desc = "Create a new Kubernetes resource" },
        { "<leader>ky", function() require('topsail').copy_resource() end, desc = "Copy current YAML resource to register" },
        { "<leader>tcr", function()
            require("telescope").load_extension("topsail")
            require("telescope").extensions.topsail.workspace()
        end, desc = "[T]elescope [C]luster [R]esources" },
        { "<leader>tsf", function()
            require("telescope").load_extension("topsail")
            require("telescope").extensions.topsail.single_file()
        end, desc = "[T]elescope [S]ingle [F]ile" },
    },
    config = function()
        require('topsail').setup({
            -- your configuration here
        })
    end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
    'enchantednatures/topsail.nvim',
    requires = {
        'nvim-telescope/telescope.nvim',
        'nvim-treesitter/nvim-treesitter', -- optional
    },
    config = function()
        require('topsail').setup()
    end
}
```

## Configuration

Topsail comes with sensible defaults but can be extensively customized:

```lua
require('topsail').setup({
    -- Notification settings
    notify = true,                    -- Enable/disable notifications
    log_level = vim.log.levels.INFO,  -- DEBUG, INFO, WARN, ERROR

    -- Copy register configuration
    copy_register = function()
        return "+"  -- Use system clipboard by default
        -- return '"'  -- Use unnamed register
        -- return "a"  -- Use named register 'a'
    end,

    -- Keymap configuration
    keymaps = {
        -- Buffer-local keymaps (set automatically for Kubernetes YAML files)
        apply = '<leader>ka',                    -- Apply current resource
        create = '<leader>kc',                   -- Create current resource  
        copy = '<leader>ky',                     -- Copy current file to register

        -- Telescope picker keymaps (active within telescope)
        telescope_copy_file = '<C-y>',           -- Copy entire file
        telescope_copy_resource = '<C-r>',       -- Copy selected resource only
    }
})
```

### Advanced Configuration Examples

**Use different registers for different operations:**
```lua
require('topsail').setup({
    copy_register = function()
        -- Use different registers based on context
        if vim.fn.has('clipboard') == 1 then
            return "+"  -- System clipboard if available
        else
            return '"'  -- Default register otherwise
        end
    end,
})
```

**Customize log levels for different environments:**
```lua
require('topsail').setup({
    log_level = vim.env.NVIM_DEBUG and vim.log.levels.DEBUG or vim.log.levels.WARN,
    notify = not vim.env.CI,  -- Disable notifications in CI
})
```

## Commands

The following commands are available globally:

- `:KubernetesApply` - Apply the current YAML file as a Kubernetes resource
- `:KubernetesCreate` - Create a new Kubernetes resource from the current YAML file

**Note:** Commands will only execute successfully if the current file passes `kubectl apply --dry-run=client -f %` validation.

## Telescope Commands

Access the Telescope integration with these commands:

- `:Telescope topsail workspace` - Browse all Kubernetes resources in the current working directory
- `:Telescope topsail single_file` - Browse resources within a specific YAML file

## Copy Functionality

Topsail provides a sophisticated copying system that works with both single and multi-resource YAML files.

### Copy Modes

#### 1. Buffer-Level Copying
When editing a detected Kubernetes YAML file:
- `<leader>ky` (default) - Copy the entire file content to the configured register

#### 2. Telescope Picker Copying
Within Telescope pickers (`:Telescope topsail workspace` or `:Telescope topsail single_file`):
- `<C-y>` (default) - Copy the entire YAML file to the configured register
- `<C-r>` (default) - Copy only the selected Kubernetes resource to the configured register

### Smart Resource Extraction

The `<C-r>` mapping uses intelligent parsing to extract individual resources from multi-resource files:

1. **TreeSitter-based extraction** (preferred) - Uses the custom `kubernetes_resources.scm` query for precise boundary detection
2. **Fallback line-based parsing** - When TreeSitter is unavailable, uses indentation and YAML document separators

### Usage Examples

#### Single Resource Files
```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3
```

1. Open the file in Neovim
2. Press `<leader>ky` to copy the entire file
3. Paste with `p` or `"0p` (depending on your register configuration)

#### Multi-Resource Files
```yaml
# kustomization.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: production
data:
  database_url: "postgres://..."
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
  namespace: production
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
---
apiVersion: v1
kind: Service
metadata:
  name: app-service
  namespace: production
spec:
  selector:
    app: my-app
  ports:
  - port: 80
```

**Using Telescope workspace picker:**
1. Run `:Telescope topsail workspace`
2. See all resources: `app-config (production)`, `app-deployment (production)`, `app-service (production)`
3. Navigate to `app-deployment (production)`
4. Press `<C-r>` to copy only the Deployment resource (lines 7-19)
5. Press `<C-y>` to copy the entire file instead

**Using Telescope single-file picker:**
1. Run `:Telescope topsail single_file`
2. Select `kustomization.yaml`
3. Choose from the three resources in the file
4. Use `<C-r>` for individual resources or `<C-y>` for the whole file

### Register Configuration

Control where copied content goes:

```lua
-- Copy to system clipboard
copy_register = function() return "+" end

-- Copy to unnamed register (default paste target)
copy_register = function() return '"' end

-- Copy to a specific named register
copy_register = function() return "k" end  -- Access with "kp

-- Dynamic register selection
copy_register = function()
    if vim.fn.has('clipboard') == 1 then
        return "+"  -- System clipboard if available
    else
        return '"'  -- Unnamed register otherwise
    end
end
```

## Keymaps

### Buffer-Local Keymaps
Automatically set when editing detected Kubernetes YAML files:

| Keymap | Action | Description |
|--------|--------|-------------|
| `<leader>ka` | Apply resource | Execute `kubectl apply -f %` |
| `<leader>kc` | Create resource | Execute `kubectl create -f %` |
| `<leader>ky` | Copy file | Copy entire file to configured register |

### Telescope Picker Keymaps
Active within Telescope pickers:

| Keymap | Action | Description |
|--------|--------|-------------|
| `<Enter>` | Open file | Open file and jump to resource line |
| `<C-y>` | Copy file | Copy entire YAML file to register |
| `<C-r>` | Copy resource | Copy selected resource only to register |

All keymaps are configurable via the `keymaps` option in setup.

## Requirements

- **Neovim** >= 0.8.0
- **kubectl** installed and available in PATH
- **Telescope.nvim** (required for resource browsing)
- **nvim-treesitter** (optional, for precise YAML parsing)

### TreeSitter Setup

For optimal resource parsing, install the YAML TreeSitter parser:

```vim
:TSInstall yaml
```

Or configure in your TreeSitter setup:

```lua
require('nvim-treesitter.configs').setup({
    ensure_installed = { "yaml", "lua", "vim", "help" },
    -- ... other config
})
```

## Troubleshooting

### TreeSitter Issues

**Quoted keys/values not parsed correctly:**
```yaml
apiVersion: "database.arangodb.com/v1"  # May not be detected
kind: "ArangoDeployment"                # May not be detected
metadata:
  "name": "arangodb-cluster"            # May not be detected
```

**Solution:** The plugin falls back to line-based parsing when TreeSitter fails, so functionality is preserved.

**TreeSitter parser not found:**
```
Treesitter YAML language not found.
```

**Solution:** Install the YAML parser with `:TSInstall yaml`

### Display Issues

**Telescope table alignment:**
Long resource names may cause column misalignment in the Telescope picker.

**Solution:** This is a cosmetic issue and doesn't affect functionality. Consider using shorter resource names or adjusting terminal width.

### kubectl Issues

**Command not found:**
```
kubectl: command not found
```

**Solution:** Ensure kubectl is installed and in your PATH.

**Permission denied:**
```
error: You must be logged in to the server (Unauthorized)
```

**Solution:** Configure kubectl with valid cluster credentials using `kubectl config`.

## Performance

- **Async operations:** All kubectl commands run asynchronously
- **Lazy loading:** Plugin loads only when needed (VeryLazy event or explicit commands)
- **TreeSitter caching:** Parsed results are cached within the same session
- **Minimal startup impact:** No performance impact on Neovim startup

## Development

### Running Tests

```bash
# Run all tests
make test

# Run specific test file
nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedFile tests/topsail/config_spec.lua"

# Format code
stylua .
```

### Project Structure

```
topsail.nvim/
├── lua/
│   ├── topsail.lua              # Main plugin module
│   ├── types.lua                # Type definitions
│   └── telescope/
│       ├── _extensions/
│       │   └── topsail.lua      # Telescope extension registration
│       └── topsail/
│           └── picker.lua       # Telescope picker implementation
├── plugin/
│   └── topsail.lua              # Plugin initialization and commands
├── queries/
│   └── yaml/
│       └── kubernetes_resources.scm  # TreeSitter query for K8s resources
├── tests/                       # Test suite
└── doc/                         # Generated vim documentation
```

### Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes and add tests
4. Run the test suite: `make test`
5. Format your code: `stylua .`
6. Commit your changes: `git commit -m 'feat: add amazing feature'`
7. Push to the branch: `git push origin feature/amazing-feature`
8. Open a Pull Request

### Architecture Notes

- **Async by design:** All kubectl operations use `vim.fn.jobstart()` for non-blocking execution
- **TreeSitter integration:** Custom queries in `queries/yaml/kubernetes_resources.scm` for precise YAML parsing
- **Graceful degradation:** Fallback mechanisms when TreeSitter or other dependencies are unavailable
- **Configuration-driven:** Extensive customization through the setup function
- **Test coverage:** Comprehensive test suite covering core functionality, edge cases, and error conditions

## License

MIT

