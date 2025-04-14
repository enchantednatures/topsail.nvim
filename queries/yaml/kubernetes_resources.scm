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
               (#eq? @_name_key "name")))))

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


