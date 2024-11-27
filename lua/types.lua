---@class KubernetesResource
---@field display string
---@field ordinal string
---@field value { kind: string, name: string, namespace: string, apiVersion: string }
---@field lnum integer
---@field path string

---@class KubernetesResourceList
---@field [1] KubernetesResource[]

local M = {}

---@return KubernetesResourceList
function M.newKubernetesResourceList()
  return {}
end

---@param display string
---@param ordinal string
---@param value { kind: string, name: string, namespace: string, apiVersion: string }
---@param lnum integer
---@param path string
---@return KubernetesResource
function M.newKubernetesResource(display, ordinal, value, lnum, path)
  return {
    display = display,
    ordinal = ordinal,
    value = value,
    lnum = lnum,
    path = path,
  }
end

return M
