; Inline constructs gutenberg recognizes. Each link pattern declares a
; `kind` that tells gutenberg.link how to decode the node; patterns added
; via `;; extends` must `#set!` one of these kinds.

((inline_link) @link
  (#set! kind "inline"))

((full_reference_link) @link
  (#set! kind "reference_full"))

((collapsed_reference_link) @link
  (#set! kind "reference_collapsed"))

((shortcut_link) @link
  (#set! kind "reference_shortcut"))

((uri_autolink) @link
  (#set! kind "autolink"))

; Delimited inline spans. The delimiters are child nodes, so the feature
; modules strip them by range rather than by pattern.
(emphasis) @emphasis

(strong_emphasis) @strong

(strikethrough) @strikethrough

(code_span) @code_span
