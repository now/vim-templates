" Vim autoload file
" Maintainer:	    Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2007-09-20

let s:cpo_save = &cpo
set cpo&vim

function now#template#attribute#new(lnum, offset, name)
  let attribute = deepcopy(g:now#template#attribute#object)
  let attribute.lnum = a:lnum
  let attribute.offset = a:offset
  let attribute.name = a:name
  return attribute
endfunction

let now#template#attribute#object = {}

let &cpo = s:cpo_save
