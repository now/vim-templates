let s:cpo_save = &cpo
set cpo&vim

function! now#template#formatter#new(template, placeholder, format)
  let formatter = deepcopy(g:now#template#formatter#object)
  let formatter.template = a:template
  let formatter.placeholder = a:placeholder
  let formatter.fmt = a:format
  return formatter
endfunction

let now#template#formatter#object = {}

function! now#template#formatter#object.format() dict
  let self.offset = 0
  let self.end = strlen(self.fmt.value)
  let new = ""
  while self.offset < self.end
    let new .= self.format_char(self.fmt.value[self.offset])
    let self.offset += 1
  endwhile
  return new
endfunction

function! now#template#formatter#object.format_char(c) dict
  return (a:c == '%') ? self.format_directive() : a:c
endfunction

function! now#template#formatter#object.format_directive() dict
  let self.offset += 1
  if self.offset == self.end
    throw self.template.positioned_message(self.fmt.lnum,
                                         \ self.fmt.offset + self.offset,
                                         \ 'unterminated format-directive')
  endif

  let c = self.fmt.value[self.offset]
  return (c == '%') ?
        \ '%' :
        \ self.placeholder.directive(self.template, self.fmt.lnum,
                                   \ self.fmt.offset + self.offset, c)
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save
