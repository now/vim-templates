let s:cpo_save = &cpo
set cpo&vim

let s:entities = { 'lt': '<', 'gt': '>', 'amp': '&' }

function! now#template#entities#lookup(template, name)
  if !has_key(s:entities, a:name)
    throw a:template.message('unrecognized character reference ‘%s’', a:name)
  endif

  return s:entities[a:name]
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save
