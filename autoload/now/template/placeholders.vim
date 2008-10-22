let s:cpo_save = &cpo
set cpo&vim

let s:placeholders = {}

function! now#template#placeholders#register(placeholder)
  let s:placeholders[a:placeholder.name] = a:placeholder
endfunction

function! now#template#placeholders#has(element)
  return has_key(s:placeholders, a:element)
endfunction

function! now#template#placeholders#lookup(element)
  return s:placeholders[a:element]
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save
