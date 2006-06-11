" Vim library file
" Maintainer:	    Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-06-12

if exists('loaded_lib_now_templates_entities')
  finish
endif
let loaded_lib_now_templates_entities = 1

let NOW.Templates.Entities = { 'lt': '<', 'gt': '>', 'amp': '&' }

function NOW.Templates.Entities.lookup(template, name) dict
  if !has_key(self, a:name)
    throw a:template.message('unrecognized character reference ‘%s’', a:name)
  endif

  return self[a:name]
endfunction
