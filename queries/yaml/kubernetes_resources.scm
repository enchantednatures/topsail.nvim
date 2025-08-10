(document 
  (block_node
    (block_mapping) @resource_root))

; Match apiVersion at top level
(document 
  (block_node
    (block_mapping
      (block_mapping_pair
        key: (flow_node (plain_scalar (string_scalar) @_apiVersion_key))
        value: (flow_node (_) @apiVersion) 
        (#eq? @_apiVersion_key "apiVersion"))
      )
    )
)

; Match kind at top level
(document 
  (block_node
    (block_mapping
      (block_mapping_pair
        key: (flow_node (plain_scalar (string_scalar) @_kind_key))
        value: (flow_node (_) @kind)
        (#eq? @_kind_key "kind")))
    )
  )


; Match name in metadata
(block_mapping_pair
  key: (flow_node (plain_scalar (string_scalar) @_metadata_key))
  (#eq? @_metadata_key "metadata")
  value: (block_node
           (block_mapping
               (block_mapping_pair
                 key: (flow_node (plain_scalar (string_scalar) @_name_key))
                 value: (flow_node (_) @name)
                 (#match? @_name_key "^(name|generateName)$")))))

; Match namespace in metadata (optional)
(block_mapping_pair
  key: (flow_node (plain_scalar (string_scalar) @_metadata_key))
  (#eq? @_metadata_key "metadata")
  value: (block_node
           (block_mapping
             (block_mapping_pair
               key: (flow_node (plain_scalar (string_scalar) @_namespace_key))
               value: (flow_node (_) @namespace)
               (#eq? @_namespace_key "namespace")))))

; Match labels in metadata
(block_mapping_pair
  key: (flow_node (plain_scalar (string_scalar) @_metadata_key))
  (#eq? @_metadata_key "metadata")
  value: (block_node
           (block_mapping
             (block_mapping_pair
               key: (flow_node (plain_scalar (string_scalar) @_labels_key))
               (#eq? @_labels_key "labels")
               value: (block_node
                        (block_mapping
                          (block_mapping_pair
                            key: (flow_node (plain_scalar (string_scalar) @label_key))
                            value: (flow_node (_) @label_value))))))))

; Match annotations in metadata
(block_mapping_pair
  key: (flow_node (plain_scalar (string_scalar) @_metadata_key))
  (#eq? @_metadata_key "metadata")
  value: (block_node
           (block_mapping
             (block_mapping_pair
               key: (flow_node (plain_scalar (string_scalar) @_annotations_key))
               (#eq? @_annotations_key "annotations")
               value: (block_node
                        (block_mapping
                          (block_mapping_pair
                            key: (flow_node (plain_scalar (string_scalar) @annotation_key))
                            value: (flow_node (_) @annotation_value))))))))

; Match kustomization files
(document 
  (block_node
    (block_mapping
      (block_mapping_pair
        key: (flow_node (plain_scalar (string_scalar) @_kind_key))
        value: (flow_node (_) @_kind_value)
        (#eq? @_kind_key "kind")
        (#eq? @_kind_value "Kustomization"))
      ) @kustomization_root))

; Match commonLabels in kustomization
(block_mapping_pair
  key: (flow_node (plain_scalar (string_scalar) @_common_labels_key))
  (#eq? @_common_labels_key "commonLabels")
  value: (block_node
           (block_mapping
             (block_mapping_pair
               key: (flow_node (plain_scalar (string_scalar) @common_label_key))
               value: (flow_node (_) @common_label_value)))))

; Match commonAnnotations in kustomization
(block_mapping_pair
  key: (flow_node (plain_scalar (string_scalar) @_common_annotations_key))
  (#eq? @_common_annotations_key "commonAnnotations")
  value: (block_node
           (block_mapping
             (block_mapping_pair
               key: (flow_node (plain_scalar (string_scalar) @common_annotation_key))
               value: (flow_node (_) @common_annotation_value)))))


