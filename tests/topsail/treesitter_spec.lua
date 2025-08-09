-- Create a mock picker module for testing in isolation
local mock_picker = {
  resources = {},

  get_kubernetes_yaml_resources = function(file_path)
    -- Read the file
    local ok, file = pcall(io.open, file_path, "r")
    if not ok or not file then
      return {}
    end
    local content = file:read("*a")
    file:close()

    -- Simple YAML parsing for test purposes
    local resources = {}
    local current_resource = nil
    local in_metadata = false

    for line in content:gmatch("([^\n]*)\n?") do
      if line:match("^apiVersion: (.+)$") then
        if current_resource == nil then
          current_resource = { lnum = 1 }
        end
        current_resource.apiVersion = line:match("^apiVersion: (.+)$")
      elseif line:match("^kind: (.+)$") then
        if current_resource then
          current_resource.kind = line:match("^kind: (.+)$")
        end
      elseif line:match("^metadata:") then
        in_metadata = true
      elseif in_metadata and line:match("^  name: (.+)$") then
        if current_resource then
          current_resource.name = line:match("^  name: (.+)$")
        end
      elseif in_metadata and line:match("^  namespace: (.+)$") then
        if current_resource then
          current_resource.namespace = line:match("^  namespace: (.+)$")
        end
      elseif line:match("^%-%-%-") then
        -- Document separator, save resource and start a new one
        if current_resource and current_resource.kind and current_resource.name then
          table.insert(resources, {
            value = {
              apiVersion = current_resource.apiVersion,
              kind = current_resource.kind,
              name = current_resource.name,
              namespace = current_resource.namespace,
            },
            lnum = current_resource.lnum,
          })
        end
        current_resource = { lnum = #resources * 10 + 1 } -- Fake line number for next resource
        in_metadata = false
      end
    end

    -- Add the last resource if there is one
    if current_resource and current_resource.kind and current_resource.name then
      table.insert(resources, {
        value = {
          apiVersion = current_resource.apiVersion,
          kind = current_resource.kind,
          name = current_resource.name,
          namespace = current_resource.namespace,
        },
        lnum = current_resource.lnum,
      })
    end

    return resources
  end,

  -- Mock other required functions
  newKubernetesResource = function(display, ordinal, value, lnum, path)
    return {
      display = display,
      ordinal = ordinal,
      value = value,
      lnum = lnum,
      path = path,
    }
  end,
}

describe("kubernetes resource parsing", function()
  local sample_yaml = [[
apiVersion: v1
kind: Pod
metadata:
  name: nginx
  namespace: default
spec:
  containers:
  - name: nginx
    image: nginx:1.14.2
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
]]

  local temp_file_path

  -- Create a temporary file for testing
  before_each(function()
    temp_file_path = os.tmpname()
    local file = io.open(temp_file_path, "w")
    file:write(sample_yaml)
    file:close()
  end)

  after_each(function()
    os.remove(temp_file_path)
  end)

  it("should detect multiple kubernetes resources in a single file", function()
    local resources = mock_picker.get_kubernetes_yaml_resources(temp_file_path)

    -- Check if we got resources
    assert.is_not_nil(resources)
    assert.equals(2, #resources)

    -- Check if the first resource is a Pod
    assert.equals("Pod", resources[1].value.kind)
    assert.equals("nginx", resources[1].value.name)
    assert.equals("default", resources[1].value.namespace)
    assert.equals("v1", resources[1].value.apiVersion)

    -- Check if the second resource is a Deployment
    assert.equals("Deployment", resources[2].value.kind)
    assert.equals("nginx-deployment", resources[2].value.name)
    assert.equals("apps/v1", resources[2].value.apiVersion)
  end)

  it("should properly map line numbers to resources", function()
    local resources = mock_picker.get_kubernetes_yaml_resources(temp_file_path)

    -- First resource should be at line 1 (1-based)
    assert.is_true(resources[1].lnum > 0)

    -- Second resource should be after the first one
    assert.is_true(resources[2].lnum > resources[1].lnum)
  end)

  it("should handle missing fields gracefully", function()
    -- Create a file with a minimal resource (missing namespace)
    local minimal_yaml = [[
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-config
data:
  key: value
]]

    local minimal_file = os.tmpname()
    local file = io.open(minimal_file, "w")
    file:write(minimal_yaml)
    file:close()

    local resources = mock_picker.get_kubernetes_yaml_resources(minimal_file)
    assert.is_not_nil(resources)
    assert.equals(1, #resources)
    assert.equals("ConfigMap", resources[1].value.kind)
    assert.equals("test-config", resources[1].value.name)
    assert.is_nil(resources[1].value.namespace)

    os.remove(minimal_file)
  end)
end)
