# topsail.nvim

Topsail is a Neovim plugin for managing Kubernetes resources directly from your editor.

- Originally, `topsail.nvim` was is a thin wrapper around `:!kubectl apply -f %` on files which are detected as Kubernetes resources.
- Secondly, it is now poor man's `aerial.nvim` but for kubernetes resources in the cwd.

## Features

- Automatic detection of Kubernetes YAML files
- Apply and Create resources directly from Neovim
- **Copy Kubernetes resources to clipboard/register**
- Async operations that don't block the editor
- Configurable keymaps and notifications
- Telescope integration for searching and managing Kubernetes resources

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "enchantednatures/topsail.nvim",
    lazy = true,
    event = {"VeryLazy"},
    cmd = {"KubernetesApply", "KubernetesCreate"},
    keys = {
        { "<leader>ka", "<cmd>KubernetesApply<cr>", desc = "Apply the current Kubernetes resource" },
        { "<leader>kc", "<cmd>KubernetesCreate<cr>", desc = "Create a new Kubernetes resource" },
        { "<leader>ky", function() require('topsail').copy_resource() end, desc = "Copy current YAML resource to register" },
        { "<leader>tcr", function()
            -- only load the extension if it's not already loaded
            require("telescope").load_extension "topsail"
            require("telescope").extensions.topsail.workspace()
        end, desc = "[T]elescope [C]luster [R]esources" },
        { "<leader>tsf", function()
            require("telescope").load_extension "topsail"
            require("telescope").extensions.topsail.single_file()
        end, desc = "[T]elescope [S]ingle [F]ile" },
    },
}
```

## Setup

You can setup the plugin with custom configuration:

```lua
require('topsail').setup({
    notify = true, -- Enable notifications
    keymaps = {
        apply = '<leader>ka',
        create = '<leader>kc',
        copy = '<leader>ky'
    }
})
```

## Commands

The following commands are available only if the current file passes `kubectl apply --dry-run=client -f % `:

- `:KubernetesApply` - Apply the current YAML file as a Kubernetes resource.
- `:KubernetesCreate` - Create a new Kubernetes resource from the current YAML file.

## Copy Functionality

Topsail provides multiple ways to copy Kubernetes resources:

### Buffer Keymaps (when editing a Kubernetes YAML file)
- `<leader>ky` - Copy the entire YAML file content to the default register

### Telescope Picker Keymaps
When using `:Telescope topsail workspace` or `:Telescope topsail single_file`:

- `<C-y>` - Copy the entire YAML file to the default register
- `<C-r>` - Copy only the selected Kubernetes resource to the default register

The `<C-r>` mapping is particularly useful for files containing multiple Kubernetes resources separated by `---`. It intelligently extracts just the specific resource you have selected, using treesitter for precise boundaries when available, with a smart fallback to line-based parsing.

### Usage Examples

**Copying from a single resource file:**
1. Open a Kubernetes YAML file (e.g., `deployment.yaml`)
2. Press `<leader>ky` to copy the entire file to your default register
3. Paste anywhere with `p` or `"0p`

**Copying from telescope picker:**
1. Run `:Telescope topsail workspace` to see all Kubernetes resources in your project
2. Navigate to the resource you want
3. Press `<C-y>` to copy the entire file, or `<C-r>` to copy just that resource
4. Press `<Esc>` to close telescope and paste with `p`

**Copying specific resources from multi-resource files:**
```yaml
# multi-resource.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  key: value
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
spec:
  replicas: 3
```

1. Run `:Telescope topsail single_file` and select `multi-resource.yaml`
2. Choose either "app-config" or "app-deployment" from the picker
3. Press `<C-r>` to copy only that specific resource (not the entire file)

## Mappings

The following buffer-local mappings are automatically set up when editing Kubernetes YAML files:

- `<leader>ka` - Apply the current Kubernetes resource
- `<leader>kc` - Create the current Kubernetes resource  
- `<leader>ky` - Copy the current YAML file to the default register

These mappings can be customized via the `keymaps` configuration option.

## Configuration


## Requirements

- Neovim >=0.11.0
- kubectl installed and in your PATH
<img width="1704" alt="Screenshot 2025-06-28 at 11 39 39 AM" src="https://github.com/user-attachments/assets/6ad61820-6a1d-4711-b3a0-64206dea0447" />

## Known Issues

### Quoted Keys and values

The tree-sitter query is not working when keys or values are quoted.

```yaml
apiVersion: "database.arangodb.com/v1"
kind: "ArangoDeployment"
metadata:
  "name": "arangodb-cluster"
  namespace: "arangodb"
```

### Alignment

Yeah, yeah the table doesn't look quite right if your resources have long names.

## License

MIT

