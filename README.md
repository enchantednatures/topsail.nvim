# topsail.nvim

Topsail is a Neovim plugin for managing Kubernetes resources directly from your editor.

- Originally, `topsail.nvim` was is a thin wrapper around `:!kubectl apply -f %` on files which are detected as Kubernetes resources.
- Secondly, it is now poor man's `aerial.nvim` but for kubernetes resources in the cwd.

## Features

- Automatic detection of Kubernetes YAML files
- Apply and Create resources directly from Neovim
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
        create = '<leader>kc'
    }
})
```

## Commands

The following commands are available only if the current file passes `kubectl apply --dry-run=client -f % `:

- `:KubernetesApply` - Apply the current YAML file as a Kubernetes resource.
- `:KubernetesCreate` - Create a new Kubernetes resource from the current YAML file.

## Mappings

No default mappings are provided.

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

