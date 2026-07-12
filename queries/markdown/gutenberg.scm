; Block constructs gutenberg recognizes, one capture per feature module.
; Query files are resolved by name across the whole 'runtimepath'
; (queries/markdown/gutenberg.scm), so the file name carries the plugin
; namespace. Extend from your own runtimepath with an `;; extends` query
; to teach a module additional node types.

(atx_heading) @heading

(fenced_code_block) @code_block

(list_item) @list_item

(pipe_table) @table

(link_reference_definition) @link_definition
