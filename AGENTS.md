# Agent Guidelines for topsail.nvim

## Build/Test Commands
- Run all tests: `make test`
- Run single test: `nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedFile tests/path/to/test_spec.lua"`
- Format code: `stylua .` (uses .stylua.toml config)

## Code Style
- **Formatting**: 2 spaces, 120 column width, Unix line endings, double quotes preferred
- **Imports**: Use `require()` at top of files, local variables for modules
- **Types**: Use LuaLS annotations (`---@class`, `---@param`, `---@return`)
- **Naming**: snake_case for functions/variables, PascalCase for classes/types
- **Error handling**: Use vim.notify() with appropriate log levels (INFO, ERROR, DEBUG)
- **Async**: Use vim.schedule() for deferred execution, vim.fn.jobstart() for external commands

## Architecture
- Main module: `lua/topsail.lua` with M table pattern
- Types: Define in `lua/types.lua` with LuaLS annotations
- Tests: Use Plenary.nvim framework in `tests/` directory
- Telescope integration: Extensions in `lua/telescope/_extensions/`
- Buffer-local keymaps for Kubernetes YAML files only