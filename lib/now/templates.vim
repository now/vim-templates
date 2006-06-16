" Vim library file
" Maintainer:	    Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-06-16

if exists('loaded_lib_now_templates')
  finish
endif
let loaded_lib_now_templates = 1

let s:cpo_save = &cpo
set cpo&vim

let NOW.Templates = {}

let NOW.Templates.placeholders = { 'placeholders': {} }

function NOW.Templates.placeholders.register(placeholder) dict
  let self.placeholders[a:placeholder.name] = a:placeholder
endfunction

function NOW.Templates.placeholders.has(element) dict
  return has_key(self.placeholders, a:element)
endfunction

function NOW.Templates.placeholders.lookup(element) dict
  return self.placeholders[a:element]
endfunction

let &cpo = s:cpo_save
