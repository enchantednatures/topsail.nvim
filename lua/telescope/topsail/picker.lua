local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local scandir = require("plenary.scandir")

local M = {}

local columns = {
  { name = "Name", width = 24 },
  { name = "Namespace", width = 24 },
  { name = "Kind", width = 20 },
  { name = "API Version", width = 28 },
  { name = "File", width = 24 },
  { name = "Path", width = 30 },
}

--- Format a table entry for telescope display
--- @param entry { apiVersion: string, kind: string, name: string, namespace: string, lnum: integer, filename: string, dir: string, full_path: string }
local function convert_to_telescope(entry)
  -- Create a properly aligned display string
  local name_display = entry.namespace and entry.name .. " (" .. entry.namespace .. ")" or entry.name

  local display = string.format(
    "%-"
      .. columns[1].width
      .. "s %-"
      .. columns[2].width
      .. "s %-"
      .. columns[3].width
      .. "s %-"
      .. columns[4].width
      .. "s %-"
      .. columns[5].width
      .. "s %-s",
    entry.name or "",
    entry.namespace or "",
    entry.kind or "",
    entry.apiVersion or "",
    entry.filename or "",
    entry.dir or ""
  )

  -- Create the ordinal string with nil checks
  local ordinal = (entry.apiVersion or "")
    .. " "
    .. (entry.namespace or "")
    .. " "
    .. (entry.name or "")
    .. " "
    .. (entry.kind or "")

  return {
    value = entry,
    display = display,
    ordinal = ordinal,
    path = entry.full_path,
    lnum = entry.lnum,
  }
end
-- Extract file name from path
local function get_filename(path)
  return vim.fn.fnamemodify(path, ":t")
end

-- Extract directory name from path
local function get_dirname(path)
  return vim.fn.fnamemodify(path, ":h:t")
end

local function parse(file_path)
  local ok, file = pcall(io.open, file_path, "r")
  if not ok or not file then
    vim.notify("Failed to open file: " .. file_path, vim.log.levels.ERROR)
    return {}
  end
  local content = file:read("*a")
  file:close()

  local lang = vim.treesitter.language.get_lang("yaml")
  if not lang then
    vim.notify("Treesitter YAML language not found.", vim.log.levels.ERROR)
    return {}
  end

  local parser = vim.treesitter.get_string_parser(content, lang)
  local tree = parser:parse()[1]
  local root = tree:root()
  local ts_query = vim.treesitter.query.get(lang, "kubernetes_resources")

  if ts_query == nil then
    vim.notify("Treesitter query 'kubernetes_resources' for yaml not found or empty.", vim.log.levels.ERROR)
    return nil
  end
  return { ts_query, root, content }
end

--- Fetches kubernetes resources from a YAML file path.
--- Uses a mapping approach to associate related captures.
--- @param file_path string The path to the YAML file.
--- @return KubernetesResourceList|nil A list of matches, or nil on error.
function M.get_kubernetes_yaml_resources(file_path)
  local res = parse(file_path)
  if not res then
    return nil
  end
  local ts_query, root, content = unpack(res)
  local results_list = {}

  -- Store resources by their start position to later associate fields with resources
  local resource_map = {}
  local current_resource = nil
  local resource_count = 0

  -- First collect all captures and organize them
  for id, node in ts_query:iter_captures(root, content, 0, -1) do
    local capture = ts_query.captures[id]
    local text = vim.treesitter.get_node_text(node, content)

    -- Find or create a resource based on capture type
    if capture == "resource_root" then
      -- New resource found, make it current
      local row, _, _ = node:start()
      local resource_id = tostring(node:id())
      resource_count = resource_count + 1

      current_resource = {
        id = resource_id,
        position = row,
        lnum = row + 1, -- Convert to1-based line number for display
      }
      resource_map[resource_id] = current_resource
    elseif capture == "apiVersion" then
      if current_resource then
        current_resource.apiVersion = text
      end
    elseif capture == "kind" then
      if current_resource then
        current_resource.kind = text
      end
    elseif capture == "name" then
      if current_resource then
        current_resource.name = text
      end
    elseif capture == "namespace" then
      if current_resource then
        current_resource.namespace = text
      end
    end
  end

  -- Convert collected resources to the required format
  for _, resource in pairs(resource_map) do
    if resource.kind and resource.name then
      local resource_entry = M.newKubernetesResource(
        string.format(
          "%s (%s) - %s",
          resource.name or "unknown",
          resource.namespace or "unknown",
          resource.kind or "unknown"
        ),
        resource.name or "",
        {
          kind = resource.kind,
          name = resource.name,
          namespace = resource.namespace,
          apiVersion = resource.apiVersion,
        },
        resource.lnum,
        file_path
      )
      if resource_entry ~= nil then
        table.insert(results_list, resource_entry)
      end
    end
  end

  return results_list
end

---@return KubernetesResourceList
function M.newKubernetesResourceList()
  return {}
end

---@param display string
---@param ordinal string
---@param value { kind: string, name: string, namespace: string, apiVersion: string }
---@param lnum integer
---@param path string
---@return KubernetesResource|nil
function M.newKubernetesResource(display, ordinal, value, lnum, path)
  if not display or not value or not lnum or not path then
    return nil
  end
  return {
    display = display,
    ordinal = ordinal,
    value = value,
    lnum = lnum,
    path = path,
  }
end

-- Organize matches into resource records
--- @param all_matches KubernetesResource[] A list of matches.
--- @return { apiVersion: string, kind: string, name: string, namespace: string, lnum: integer, filename: string, dir: string, full_path: string }[] A list of resources.
local function organize_matches(all_matches)
  local resources = {}

  for _, match in ipairs(all_matches) do
    local path = match.path
    local dir = get_dirname(path)
    local filename = get_filename(path)

    local resource = {
      apiVersion = match.value.apiVersion,
      kind = match.value.kind,
      name = match.value.name,
      namespace = match.value.namespace,
      lnum = match.lnum,
      filename = filename,
      dir = dir,
      full_path = path,
    }

    table.insert(resources, resource)
  end

  return resources
end

function M.workspace()
  local cwd = vim.loop.cwd()
  local files = scandir.scan_dir(cwd, { search_pattern = "%.ya?ml$" })
  local all_matches = {}

  for _, file in ipairs(files) do
    local matches = M.get_kubernetes_yaml_resources(file) -- Use local function, not query

    if matches then
      for _, match in ipairs(matches) do
        table.insert(all_matches, match)
      end
    end
  end

  local resources = organize_matches(all_matches)

  pickers
    .new({}, {
      prompt_title = "Kubernetes Resources Table",
      finder = finders.new_table({
        results = resources,
        entry_maker = convert_to_telescope,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, _)
        -- Add a header row
        local header = string.format("%-20s %-25s %-25s %-25s %-s", "Name", "Kind", "Api Version", "File", "Path")
        vim.api.nvim_buf_set_lines(prompt_bufnr, 0, 0, false, { header, string.rep("-", #header) })

        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          vim.cmd("edit " .. selection.path)
          vim.api.nvim_win_set_cursor(0, { selection.lnum, 0 })
        end)
        return true
      end,
    })
    :find()
end

function M.single_file()
  local opts = {
    prompt_title = "Select YAML File",
    finder = finders.new_oneshot_job({ "fd", "-t", "f", "-e", "yaml", "-e", "yml" }, {}),
    sorter = conf.file_sorter({}),
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        local file_path = selection[1]
        local matches = M.get_kubernetes_yaml_resources(file_path)

        if matches then
          local resources = organize_matches(matches)
          pickers
            .new({}, {
              prompt_title = "Kubernetes Resources in " .. file_path,
              finder = finders.new_table({
                results = resources,
                entry_maker = convert_to_telescope,
              }),
              sorter = conf.generic_sorter({}),
              attach_mappings = function(prompt_bufnr, _)
                actions.select_default:replace(function()
                  actions.close(prompt_bufnr)
                  local selection = action_state.get_selected_entry()
                  vim.cmd("edit " .. selection.path)
                  vim.api.nvim_win_set_cursor(0, { selection.lnum, 0 })
                end)
                return true
              end,
            })
            :find()
        end
      end)
      return true
    end,
  }
  pickers.new({}, opts):find()
end

return M
