local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local scandir = require("plenary.scandir")

local M = {
  config = {
    default_register = function()
      return "+"
    end,
    log_level = vim.log.levels.INFO,
    keymaps = {
      telescope_copy_file = "<C-y>",
      telescope_copy_resource = "<C-r>",
    },
  },
}

-- Helper function to log messages with level filtering
local function log_message(message, level)
  if level >= M.config.log_level then
    vim.notify(message, level)
  end
end

---@param opts TopsailConfig
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

-- Helper function to copy entire file content to register
local function copy_file_to_register(selection, opts)
  if not opts then
    return
  end
  local file = io.open(selection.path, "r")

  if file then
    local content = file:read("*a")
    file:close()

    vim.fn.setreg(opts.register, content)
    log_message("Entire YAML file copied to register " .. opts.register, vim.log.levels.INFO)
  else
    log_message("Failed to open file: " .. selection.path, vim.log.levels.ERROR)
  end
end

-- Extract a specific Kubernetes resource from a YAML file using treesitter
local function extract_resource_content(file_path, target_line)
  local file = io.open(file_path, "r")
  if not file then
    return nil
  end

  local content = file:read("*a")
  file:close()

  -- Try treesitter approach first
  local lang = vim.treesitter.language.get_lang("yaml")
  if lang then
    local ok_parser, parser = pcall(vim.treesitter.get_string_parser, content, lang)
    if ok_parser then
      local ok_parse, trees = pcall(parser.parse, parser)
      if ok_parse and trees and #trees > 0 then
        local tree = trees[1]
        local root = tree:root()
        local ts_query = vim.treesitter.query.get(lang, "kubernetes_resources")

        if ts_query then
          -- Find the resource that contains our target line
          local target_resource_node = nil
          for id, node in ts_query:iter_captures(root, content, 0, -1) do
            local capture = ts_query.captures[id]
            if capture == "resource_root" then
              local start_row, _, end_row, _ = node:range()
              -- Convert to 1-based line numbers for comparison
              if target_line >= start_row + 1 and target_line <= end_row + 1 then
                target_resource_node = node
                break
              end
            end
          end

          if target_resource_node then
            -- Extract the exact resource using treesitter node boundaries
            local start_row, start_col, end_row, end_col = target_resource_node:range()
            local lines = vim.split(content, "\n")
            local resource_lines = {}

            for i = start_row + 1, end_row + 1 do
              if i <= #lines then
                local line = lines[i]
                if i == start_row + 1 and start_col > 0 then
                  line = line:sub(start_col + 1)
                end
                if i == end_row + 1 and end_col > 0 then
                  line = line:sub(1, end_col)
                end
                table.insert(resource_lines, line)
              end
            end

            return table.concat(resource_lines, "\n")
          end
        end
      end
    end
  end

  -- Fallback to simple line-based extraction
  local lines = vim.split(content, "\n")
  local resource_lines = {}
  local start_line = target_line
  local base_indent = nil

  -- Find the start of the resource (look for apiVersion or kind at same or less indentation)
  for i = target_line, 1, -1 do
    local line = lines[i]
    if line:match("^%s*apiVersion:") or line:match("^%s*kind:") then
      start_line = i
      base_indent = line:match("^(%s*)")
      break
    end
  end

  -- Extract from start_line until we hit another resource or end
  for i = start_line, #lines do
    local line = lines[i]
    local current_indent = line:match("^(%s*)")

    if i == start_line then
      table.insert(resource_lines, line)
    elseif line:match("^%s*$") then
      table.insert(resource_lines, line)
    elseif line:match("^%s*#") then
      table.insert(resource_lines, line)
    elseif line:match("^%s*%-%-%-") then
      break
    elseif
      base_indent
      and #current_indent <= #base_indent
      and (line:match("^%s*apiVersion:") or line:match("^%s*kind:"))
    then
      break
    else
      table.insert(resource_lines, line)
    end
  end

  -- Remove trailing empty lines
  while #resource_lines > 0 and resource_lines[#resource_lines]:match("^%s*$") do
    table.remove(resource_lines)
  end

  return table.concat(resource_lines, "\n")
end

-- Helper function to copy specific resource content to register
local function copy_resource_to_register(selection, opts)
  if not opts then
    return
  end
  local resource_content = extract_resource_content(selection.path, selection.lnum)
  if resource_content then
    vim.fn.setreg(opts.register, resource_content)
    log_message("Kubernetes resource copied to register " .. opts.register, vim.log.levels.INFO)
  else
    log_message("Failed to extract resource from file: " .. selection.path, vim.log.levels.ERROR)
  end
end

-- Get the current picker width from telescope or vim
function M.get_picker_width()
  local ok, width = pcall(function()
    -- Try to get the current window width
    local win_width = vim.api.nvim_win_get_width(0)
    -- Account for telescope UI elements (borders, prompt, etc.)
    return math.max(80, win_width - 10)
  end)
  
  if ok and width then
    return width
  end
  
  -- Fallback to terminal columns or reasonable default
  local term_width = vim.api.nvim_get_option("columns")
  return math.max(80, term_width - 10)
end

-- Calculate optimal column widths based on content and available space
function M.calculate_column_widths(resources, picker_width)
  local min_widths = {
    name = 8,
    namespace = 8,
    kind = 8,
    apiVersion = 8,
    filename = 8,
    dir = 8,
  }
  
  local max_lengths = {
    name = 0,
    namespace = 0,
    kind = 0,
    apiVersion = 0,
    filename = 0,
    dir = 0,
  }
  
  -- Find the maximum length for each column
  for _, resource in ipairs(resources) do
    max_lengths.name = math.max(max_lengths.name, string.len(resource.name or ""))
    max_lengths.namespace = math.max(max_lengths.namespace, string.len(resource.namespace or ""))
    max_lengths.kind = math.max(max_lengths.kind, string.len(resource.kind or ""))
    max_lengths.apiVersion = math.max(max_lengths.apiVersion, string.len(resource.apiVersion or ""))
    max_lengths.filename = math.max(max_lengths.filename, string.len(resource.filename or ""))
    max_lengths.dir = math.max(max_lengths.dir, string.len(resource.dir or ""))
  end
  
  -- Apply minimum widths
  for key, min_width in pairs(min_widths) do
    max_lengths[key] = math.max(max_lengths[key], min_width)
  end
  
  -- Calculate total needed width (including spaces between columns)
  local total_content_width = max_lengths.name + max_lengths.namespace + max_lengths.kind + 
                             max_lengths.apiVersion + max_lengths.filename + max_lengths.dir
  local spaces_needed = 5 -- spaces between 6 columns
  local total_needed = total_content_width + spaces_needed
  
  -- If we have enough space, use the calculated widths
  if total_needed <= picker_width then
    return max_lengths
  end
  
  -- Otherwise, proportionally reduce widths while maintaining minimums
  local available_width = picker_width - spaces_needed
  local scale_factor = available_width / total_content_width
  
  local scaled_widths = {}
  local total_scaled = 0
  
  -- First pass: scale all widths
  for key, width in pairs(max_lengths) do
    scaled_widths[key] = math.max(min_widths[key], math.floor(width * scale_factor))
    total_scaled = total_scaled + scaled_widths[key]
  end
  
  -- Second pass: adjust if we're still over the limit
  local remaining = available_width - total_scaled
  if remaining < 0 then
    -- Need to reduce further, start with the largest columns
    local keys_by_width = {}
    for key, width in pairs(scaled_widths) do
      table.insert(keys_by_width, {key = key, width = width})
    end
    table.sort(keys_by_width, function(a, b) return a.width > b.width end)
    
    local reduction_needed = -remaining
    for _, item in ipairs(keys_by_width) do
      if reduction_needed <= 0 then break end
      local key = item.key
      local can_reduce = scaled_widths[key] - min_widths[key]
      local reduce_by = math.min(can_reduce, reduction_needed)
      scaled_widths[key] = scaled_widths[key] - reduce_by
      reduction_needed = reduction_needed - reduce_by
    end
  end
  
  return scaled_widths
end

-- Format a table entry with calculated widths
function M.format_table_entry(entry, widths)
  local function truncate_or_pad(text, width)
    text = text or ""
    if string.len(text) > width then
      return string.sub(text, 1, width - 3) .. "..."
    else
      return string.format("%-" .. width .. "s", text)
    end
  end
  
  return string.format(
    "%s %s %s %s %s %s",
    truncate_or_pad(entry.name, widths.name),
    truncate_or_pad(entry.namespace, widths.namespace),
    truncate_or_pad(entry.kind, widths.kind),
    truncate_or_pad(entry.apiVersion, widths.apiVersion),
    truncate_or_pad(entry.filename, widths.filename),
    truncate_or_pad(entry.dir, widths.dir)
  )
end

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
--- @param widths table Optional pre-calculated column widths
local function convert_to_telescope(entry, widths)
  -- Use provided widths or calculate them (fallback for compatibility)
  local display
  if widths then
    display = M.format_table_entry(entry, widths)
  else
    -- Fallback to original fixed-width formatting for compatibility
    display = string.format(
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
  end

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
    log_message("Failed to open file: " .. file_path, vim.log.levels.ERROR)
    return nil
  end
  local content = file:read("*a")
  file:close()

  local lang = vim.treesitter.language.get_lang("yaml")
  if not lang then
    log_message("Treesitter YAML language not found.", vim.log.levels.ERROR)
    return nil
  end

  local ok_parser, parser = pcall(vim.treesitter.get_string_parser, content, lang)
  if not ok_parser then
    log_message("Failed to create YAML parser.", vim.log.levels.ERROR)
    return nil
  end

  local ok_parse, trees = pcall(parser.parse, parser)
  if not ok_parse or not trees or #trees == 0 then
    log_message("Failed to parse YAML content.", vim.log.levels.ERROR)
    return nil
  end

  local tree = trees[1]
  local root = tree:root()
  local ts_query = vim.treesitter.query.get(lang, "kubernetes_resources")

  if ts_query == nil then
    log_message("Treesitter query 'kubernetes_resources' for yaml not found or empty.", vim.log.levels.ERROR)
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
  
  -- Calculate optimal column widths based on content and picker width
  local picker_width = M.get_picker_width()
  local widths = M.calculate_column_widths(resources, picker_width)

  pickers
    .new({}, {
      prompt_title = "Kubernetes Resources Table",
      finder = finders.new_table({
        results = resources,
        entry_maker = function(entry)
          return convert_to_telescope(entry, widths)
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        -- Add a header row with dynamic widths
        local header = M.format_table_entry({
          name = "Name",
          namespace = "Namespace", 
          kind = "Kind",
          apiVersion = "API Version",
          filename = "File",
          dir = "Path"
        }, widths)
        vim.api.nvim_buf_set_lines(prompt_bufnr, 0, 0, false, { header, string.rep("-", #header) })

        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          vim.cmd("edit " .. selection.path)
          vim.api.nvim_win_set_cursor(0, { selection.lnum, 0 })
        end)

        local opts = { register = M.config.default_register() }

        map("i", M.config.keymaps.telescope_copy_file, function()
          local selection = action_state.get_selected_entry()
          local opts = { register = M.config.default_register() }
          copy_file_to_register(selection, opts)
        end)

        map("n", M.config.keymaps.telescope_copy_file, function()
          local selection = action_state.get_selected_entry()
          local opts = { register = M.config.default_register() }
          copy_file_to_register(selection, opts)
        end)

        map("i", M.config.keymaps.telescope_copy_resource, function()
          local selection = action_state.get_selected_entry()
          local opts = { register = M.config.default_register() }
          copy_resource_to_register(selection, opts)
        end)

        map("n", M.config.keymaps.telescope_copy_resource, function()
          local selection = action_state.get_selected_entry()
          local opts = { register = M.config.default_register() }
          copy_resource_to_register(selection, opts)
        end)

        map("n", M.config.keymaps.telescope_copy_file, function()
          local selection = action_state.get_selected_entry()
          local opts = { register = M.config.default_register() }
          copy_file_to_register(selection, opts)
        end)

        map("i", M.config.keymaps.telescope_copy_resource, function()
          local selection = action_state.get_selected_entry()
          local opts = { register = M.config.default_register() }
          copy_resource_to_register(selection, opts)
        end)

        map("n", M.config.keymaps.telescope_copy_resource, function()
          local selection = action_state.get_selected_entry()
          local opts = { register = M.config.default_register() }
          copy_resource_to_register(selection, opts)
        end)
        map("n", M.config.keymaps.telescope_copy_file, function()
          local selection = action_state.get_selected_entry()
          local opts = { register = get_target_register() }
          copy_file_to_register(selection, opts)
        end)

        map("i", M.config.keymaps.telescope_copy_resource, function()
          local selection = action_state.get_selected_entry()
          local opts = { register = get_target_register() }
          copy_resource_to_register(selection, opts)
        end)

        map("n", M.config.keymaps.telescope_copy_resource, function()
          local selection = action_state.get_selected_entry()
          local opts = { register = get_target_register() }
          copy_resource_to_register(selection, opts)
        end)

        map("n", M.config.keymaps.telescope_copy_file, function()
          local selection = action_state.get_selected_entry()
          copy_file_to_register(selection, opts)
        end)

        map("i", M.config.keymaps.telescope_copy_resource, function()
          local selection = action_state.get_selected_entry()
          copy_resource_to_register(selection, opts)
        end)

        map("n", M.config.keymaps.telescope_copy_resource, function()
          local selection = action_state.get_selected_entry()
          copy_resource_to_register(selection, opts)
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
          
          -- Calculate optimal column widths for this file's resources
          local picker_width = M.get_picker_width()
          local widths = M.calculate_column_widths(resources, picker_width)
          
          pickers
            .new({}, {
              prompt_title = "Kubernetes Resources in " .. file_path,
              finder = finders.new_table({
                results = resources,
                entry_maker = function(entry)
                  return convert_to_telescope(entry, widths)
                end,
              }),
              sorter = conf.generic_sorter({}),
              attach_mappings = function(prompt_bufnr, map)
                actions.select_default:replace(function()
                  actions.close(prompt_bufnr)
                  local selection = action_state.get_selected_entry()
                  vim.cmd("edit " .. selection.path)
                  vim.api.nvim_win_set_cursor(0, { selection.lnum, 0 })
                end)

                local opts = { register = M.config.default_register() }

                map("i", M.config.keymaps.telescope_copy_file, function()
                  local selection = action_state.get_selected_entry()
                  copy_file_to_register(selection, opts)
                end)

                map("n", M.config.keymaps.telescope_copy_file, function()
                  local selection = action_state.get_selected_entry()
                  copy_file_to_register(selection, opts)
                end)

                map("i", M.config.keymaps.telescope_copy_resource, function()
                  local selection = action_state.get_selected_entry()
                  copy_resource_to_register(selection, opts)
                end)

                map("n", M.config.keymaps.telescope_copy_resource, function()
                  local selection = action_state.get_selected_entry()
                  copy_resource_to_register(selection, opts)
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
