# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands
- Run all tests: `make test`
- Run a single test: `nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/path/to/specific_test.lua { minimal_init = 'tests/minimal_init.lua' }"`

## Code Style Guidelines
- Modules: Use local `M = {}` pattern with `return M` at the end
- Functions: Define as `function M.function_name(params)`
- Error Handling: Use callbacks for async operations; check exit codes
- Notifications: Use `vim.notify` with appropriate log levels
- Configuration: Use `vim.tbl_deep_extend` for merging configurations
- Types: Follow Lua typing conventions (no explicit types)
- Testing: Use mock functions with before_each/after_each hooks
- Telescope Extension: Follow Telescope extension API patterns
- Treesitter: Use query files (.scm) for detecting Kubernetes resources
- Autocommands: Group with `vim.api.nvim_create_augroup`
- Commands: Register with `vim.api.nvim_create_user_command`