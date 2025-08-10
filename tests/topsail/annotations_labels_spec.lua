describe("annotations and labels parsing", function()
  local picker = require("telescope.topsail.picker")

  describe("basic annotations and labels parsing", function()
    local sample_yaml_with_metadata = [[
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: default
  labels:
    app: my-app
    version: "1.0"
    environment: production
  annotations:
    description: "Application configuration"
    managed-by: kustomize
    last-updated: "2024-01-15"
data:
  config.yaml: |
    database_url: postgres://localhost:5432/myapp
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
  namespace: default
  labels:
    app: my-app
    component: backend
  annotations:
    deployment.kubernetes.io/revision: "3"
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"apps/v1","kind":"Deployment"}
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
]]

    local temp_file_path

    before_each(function()
      temp_file_path = os.tmpname()
      local file = io.open(temp_file_path, "w")
      file:write(sample_yaml_with_metadata)
      file:close()
    end)

    after_each(function()
      os.remove(temp_file_path)
    end)

    it("should parse resources with annotations and labels", function()
      local resources = picker.get_kubernetes_yaml_resources(temp_file_path)
      
      assert.is_not_nil(resources)
      assert.equals(2, #resources)

      -- Check ConfigMap
      local configmap = resources[1]
      assert.equals("ConfigMap", configmap.value.kind)
      assert.equals("app-config", configmap.value.name)
      
      -- Check that annotations are captured
      assert.is_table(configmap.value.annotations)
      assert.equals("Application configuration", configmap.value.annotations.description)
      assert.equals("kustomize", configmap.value.annotations["managed-by"])
      assert.equals("2024-01-15", configmap.value.annotations["last-updated"])
      
      -- Check that labels are captured
      assert.is_table(configmap.value.labels)
      assert.equals("my-app", configmap.value.labels.app)
      assert.equals("1.0", configmap.value.labels.version)
      assert.equals("production", configmap.value.labels.environment)

      -- Check Deployment
      local deployment = resources[2]
      assert.equals("Deployment", deployment.value.kind)
      assert.equals("app-deployment", deployment.value.name)
      
      -- Check deployment annotations
      assert.is_table(deployment.value.annotations)
      assert.equals("3", deployment.value.annotations["deployment.kubernetes.io/revision"])
      assert.is_string(deployment.value.annotations["kubectl.kubernetes.io/last-applied-configuration"])
      
      -- Check deployment labels
      assert.is_table(deployment.value.labels)
      assert.equals("my-app", deployment.value.labels.app)
      assert.equals("backend", deployment.value.labels.component)
    end)

    it("should handle resources without annotations or labels", function()
      local minimal_yaml = [[
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: default
type: Opaque
data:
  password: cGFzc3dvcmQ=
]]

      local minimal_file = os.tmpname()
      local file = io.open(minimal_file, "w")
      file:write(minimal_yaml)
      file:close()

      local resources = picker.get_kubernetes_yaml_resources(minimal_file)
      assert.is_not_nil(resources)
      assert.equals(1, #resources)

      local secret = resources[1]
      assert.equals("Secret", secret.value.kind)
      assert.equals("my-secret", secret.value.name)
      
      -- Should have empty tables for annotations and labels
      assert.is_table(secret.value.annotations)
      assert.equals(0, vim.tbl_count(secret.value.annotations))
      assert.is_table(secret.value.labels)
      assert.equals(0, vim.tbl_count(secret.value.labels))

      os.remove(minimal_file)
    end)

    it("should handle mixed resources with and without metadata", function()
      local mixed_yaml = [[
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-with-labels
  labels:
    app: test
data:
  key: value
---
apiVersion: v1
kind: Secret
metadata:
  name: secret-with-annotations
  annotations:
    description: "Test secret"
type: Opaque
data:
  password: cGFzc3dvcmQ=
---
apiVersion: v1
kind: Service
metadata:
  name: service-minimal
spec:
  selector:
    app: test
  ports:
  - port: 80
]]

      local mixed_file = os.tmpname()
      local file = io.open(mixed_file, "w")
      file:write(mixed_yaml)
      file:close()

      local resources = picker.get_kubernetes_yaml_resources(mixed_file)
      assert.is_not_nil(resources)
      assert.equals(3, #resources)

      -- ConfigMap with labels only
      local configmap = resources[1]
      assert.equals("ConfigMap", configmap.value.kind)
      assert.is_table(configmap.value.labels)
      assert.equals("test", configmap.value.labels.app)
      assert.is_table(configmap.value.annotations)
      assert.equals(0, vim.tbl_count(configmap.value.annotations))

      -- Secret with annotations only
      local secret = resources[2]
      assert.equals("Secret", secret.value.kind)
      assert.is_table(secret.value.annotations)
      assert.equals("Test secret", secret.value.annotations.description)
      assert.is_table(secret.value.labels)
      assert.equals(0, vim.tbl_count(secret.value.labels))

      -- Service with neither
      local service = resources[3]
      assert.equals("Service", service.value.kind)
      assert.is_table(service.value.annotations)
      assert.equals(0, vim.tbl_count(service.value.annotations))
      assert.is_table(service.value.labels)
      assert.equals(0, vim.tbl_count(service.value.labels))

      os.remove(mixed_file)
    end)
  end)

  describe("kustomization support", function()
    local kustomization_yaml = [[
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
metadata:
  name: my-kustomization

commonLabels:
  app: my-app
  managed-by: kustomize

commonAnnotations:
  description: "Managed by kustomization"
  version: "1.0.0"

resources:
- deployment.yaml
- service.yaml
]]

    local deployment_yaml = [[
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
  namespace: default
  labels:
    component: backend
  annotations:
    deployment-specific: "true"
spec:
  replicas: 3
]]

    local service_yaml = [[
apiVersion: v1
kind: Service
metadata:
  name: app-service
  namespace: default
  labels:
    component: frontend
spec:
  selector:
    app: my-app
  ports:
  - port: 80
]]

    local temp_dir
    local kustomization_file, deployment_file, service_file

    before_each(function()
      temp_dir = vim.fn.tempname()
      vim.fn.mkdir(temp_dir, "p")
      
      kustomization_file = temp_dir .. "/kustomization.yaml"
      deployment_file = temp_dir .. "/deployment.yaml"
      service_file = temp_dir .. "/service.yaml"

      local file = io.open(kustomization_file, "w")
      file:write(kustomization_yaml)
      file:close()

      file = io.open(deployment_file, "w")
      file:write(deployment_yaml)
      file:close()

      file = io.open(service_file, "w")
      file:write(service_yaml)
      file:close()
    end)

    after_each(function()
      vim.fn.delete(temp_dir, "rf")
    end)

    it("should parse kustomization files", function()
      local kustomization = picker.get_kustomization_config(kustomization_file)
      
      assert.is_not_nil(kustomization)
      assert.is_table(kustomization.commonLabels)
      assert.equals("my-app", kustomization.commonLabels.app)
      assert.equals("kustomize", kustomization.commonLabels["managed-by"])
      
      assert.is_table(kustomization.commonAnnotations)
      assert.equals("Managed by kustomization", kustomization.commonAnnotations.description)
      assert.equals("1.0.0", kustomization.commonAnnotations.version)
    end)

    it("should apply kustomization annotations and labels to resources", function()
      -- This test will verify that when we parse resources in a directory with kustomization,
      -- the common annotations and labels are applied
      local resources = picker.get_kubernetes_yaml_resources_with_kustomization(temp_dir)
      
      assert.is_not_nil(resources)
      assert.is_true(#resources >= 2)

      -- Find deployment and service
      local deployment, service
      for _, resource in ipairs(resources) do
        if resource.value.kind == "Deployment" then
          deployment = resource
        elseif resource.value.kind == "Service" then
          service = resource
        end
      end

      assert.is_not_nil(deployment)
      assert.is_not_nil(service)

      -- Check that deployment has both its own labels and kustomization labels
      assert.equals("backend", deployment.value.labels.component) -- original
      assert.equals("my-app", deployment.value.labels.app) -- from kustomization
      assert.equals("kustomize", deployment.value.labels["managed-by"]) -- from kustomization

      -- Check that deployment has both its own annotations and kustomization annotations
      assert.equals("true", deployment.value.annotations["deployment-specific"]) -- original
      assert.equals("Managed by kustomization", deployment.value.annotations.description) -- from kustomization
      assert.equals("1.0.0", deployment.value.annotations.version) -- from kustomization

      -- Check that service has kustomization metadata applied
      assert.equals("frontend", service.value.labels.component) -- original
      assert.equals("my-app", service.value.labels.app) -- from kustomization
      assert.equals("kustomize", service.value.labels["managed-by"]) -- from kustomization
      assert.equals("Managed by kustomization", service.value.annotations.description) -- from kustomization
    end)
  end)

  describe("search by type and annotations", function()
    local sample_resources_yaml = [[
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-1
  namespace: default
  annotations:
    app.kubernetes.io/managed-by: kustomize
    description: "Config for app 1"
data:
  key: value
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deploy-1
  namespace: default
  annotations:
    app.kubernetes.io/managed-by: helm
    deployment.kubernetes.io/revision: "3"
spec:
  replicas: 1
---
apiVersion: v1
kind: Service
metadata:
  name: service-1
  namespace: default
  annotations:
    description: "Service for app 1"
spec:
  selector:
    app: test
]]

    local temp_file_path

    before_each(function()
      temp_file_path = os.tmpname()
      local file = io.open(temp_file_path, "w")
      file:write(sample_resources_yaml)
      file:close()
    end)

    after_each(function()
      os.remove(temp_file_path)
    end)

    it("should filter resources by kind and annotation key", function()
      local resources = picker.get_kubernetes_yaml_resources(temp_file_path)
      assert.is_not_nil(resources)
      
      -- Filter by kind=ConfigMap and annotation key="description"
      local filtered = picker.filter_by_kind_and_annotation_key(resources, "ConfigMap", "description")
      assert.equals(1, #filtered)
      assert.equals("config-1", filtered[1].value.name)
      assert.equals("ConfigMap", filtered[1].value.kind)
      
      -- Filter by kind=Deployment and annotation key="app.kubernetes.io/managed-by"
      local filtered2 = picker.filter_by_kind_and_annotation_key(resources, "Deployment", "app.kubernetes.io/managed-by")
      assert.equals(1, #filtered2)
      assert.equals("deploy-1", filtered2[1].value.name)
      
      -- Filter by non-existent combination
      local filtered3 = picker.filter_by_kind_and_annotation_key(resources, "Service", "nonexistent")
      assert.equals(0, #filtered3)
    end)

    it("should filter resources by kind and annotation key-value pair", function()
      local resources = picker.get_kubernetes_yaml_resources(temp_file_path)
      assert.is_not_nil(resources)
      
      -- Filter by kind=ConfigMap and annotation app.kubernetes.io/managed-by=kustomize
      local filtered = picker.filter_by_kind_and_annotation(resources, "ConfigMap", "app.kubernetes.io/managed-by", "kustomize")
      assert.equals(1, #filtered)
      assert.equals("config-1", filtered[1].value.name)
      
      -- Filter by kind=Deployment and annotation app.kubernetes.io/managed-by=helm
      local filtered2 = picker.filter_by_kind_and_annotation(resources, "Deployment", "app.kubernetes.io/managed-by", "helm")
      assert.equals(1, #filtered2)
      assert.equals("deploy-1", filtered2[1].value.name)
      
      -- Filter by wrong value
      local filtered3 = picker.filter_by_kind_and_annotation(resources, "ConfigMap", "app.kubernetes.io/managed-by", "helm")
      assert.equals(0, #filtered3)
    end)
  end)

  describe("search by type and labels", function()
    local sample_resources_yaml = [[
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-1
  namespace: default
  labels:
    app: my-app
    version: "1.0"
    environment: production
data:
  key: value
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deploy-1
  namespace: default
  labels:
    app: my-app
    component: backend
    version: "2.0"
spec:
  replicas: 1
---
apiVersion: v1
kind: Service
metadata:
  name: service-1
  namespace: default
  labels:
    app: other-app
    component: frontend
spec:
  selector:
    app: test
]]

    local temp_file_path

    before_each(function()
      temp_file_path = os.tmpname()
      local file = io.open(temp_file_path, "w")
      file:write(sample_resources_yaml)
      file:close()
    end)

    after_each(function()
      os.remove(temp_file_path)
    end)

    it("should filter resources by kind and label key", function()
      local resources = picker.get_kubernetes_yaml_resources(temp_file_path)
      assert.is_not_nil(resources)
      
      -- Filter by kind=ConfigMap and label key="environment"
      local filtered = picker.filter_by_kind_and_label_key(resources, "ConfigMap", "environment")
      assert.equals(1, #filtered)
      assert.equals("config-1", filtered[1].value.name)
      
      -- Filter by kind=Deployment and label key="component"
      local filtered2 = picker.filter_by_kind_and_label_key(resources, "Deployment", "component")
      assert.equals(1, #filtered2)
      assert.equals("deploy-1", filtered2[1].value.name)
      
      -- Filter by label key that exists on multiple kinds
      local filtered3 = picker.filter_by_kind_and_label_key(resources, "Service", "app")
      assert.equals(1, #filtered3)
      assert.equals("service-1", filtered3[1].value.name)
    end)

    it("should filter resources by kind and label key-value pair", function()
      local resources = picker.get_kubernetes_yaml_resources(temp_file_path)
      assert.is_not_nil(resources)
      
      -- Filter by kind=ConfigMap and label app=my-app
      local filtered = picker.filter_by_kind_and_label(resources, "ConfigMap", "app", "my-app")
      assert.equals(1, #filtered)
      assert.equals("config-1", filtered[1].value.name)
      
      -- Filter by kind=Deployment and label component=backend
      local filtered2 = picker.filter_by_kind_and_label(resources, "Deployment", "component", "backend")
      assert.equals(1, #filtered2)
      assert.equals("deploy-1", filtered2[1].value.name)
      
      -- Filter by kind=Service and label app=other-app
      local filtered3 = picker.filter_by_kind_and_label(resources, "Service", "app", "other-app")
      assert.equals(1, #filtered3)
      assert.equals("service-1", filtered3[1].value.name)
      
      -- Filter by wrong value
      local filtered4 = picker.filter_by_kind_and_label(resources, "ConfigMap", "app", "wrong-app")
      assert.equals(0, #filtered4)
    end)
  end)
end)