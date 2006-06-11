" Vim library file
" Maintainer:	    Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-06-12

if exists('loaded_lib_now_templates_attribute')
  finish
endif
let loaded_lib_now_templates_attribute = 1

let NOW.Templates.Attribute = {}

function NOW.Templates.Attribute.new(lnum, offset, name) dict
  let attribute = deepcopy(self)
  let attribute.lnum = a:lnum
  let attribute.offset = a:offset
  let attribute.name = a:name
  return attribute
endfunction
