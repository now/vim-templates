" Vim library file
" Maintainer:	    Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-06-12

if exists('loaded_lib_now_templates_formatter')
  finish
endif
let loaded_lib_now_templates_formatter = 1

let NOW.Templates.Formatter = {}

function NOW.Templates.Formatter.new(template, placeholder, format) dict
  let formatter = deepcopy(self)
  let formatter.template = a:template
  let formatter.placeholder = a:placeholder
  let formatter.fmt = a:format
  return formatter
endfunction

function NOW.Templates.Formatter.format() dict
  let self.offset = 0
  let self.end = strlen(self.fmt.value)
  let new = ""
  while self.offset < self.end
    let new .= self.format_char(self.fmt.value[self.offset])
    let self.offset += 1
  endwhile
  return new
endfunction

function NOW.Templates.Formatter.format_char(c) dict
  return (a:c == '%') ? self.format_directive() : a:c
endfunction

function NOW.Templates.Formatter.format_directive() dict
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
