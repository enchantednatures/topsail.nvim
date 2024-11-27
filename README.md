# topsail.nvim

What is Topsail?

Topsail is a Neovim plugin for managing Kubernetes resources directly from your editor.

Originally, `topsail.nvim` was is a thin wrapper around `:!kubectl apply -f %` on files which are detected as Kubernetes resources.

Secondly, it is now poor man's `aerial.nvim` but for kubernetes resources in the cwd.

## Installation

### Lazy.nvim

```lua

{
    "enchantednatures/topsail.nvim",
    lazy = true,
    event = {"VeryLazy"},
    -- opts = {},
    cmd = {"KubernetesApply", "KubernetesCreate"},
    keys = {
        { "<leader>ka", "<cmd>KubernetesApply<cr>", desc = "Apply the current Kubernetes resource" },
        { "<leader>kc", "<cmd>KubernetesCreate<cr>", desc = "Create a new Kubernetes resource" },
        { "<leader>tcr", function()
              require("telescope").load_extension "topsail"
              require("telescope").extensions.topsail.workspace()
        end, desc = "[T]elescope [C]luster [R]esources" },
    },
}

```

## Known Issues

The tree-sitter query is not working when keys or values are quoted.

```yaml
apiVersion: "database.arangodb.com/v1"
kind: "ArangoDeployment"
metadata:
  "name": "arangodb-cluster"
  namespace: "arangodb"
```
