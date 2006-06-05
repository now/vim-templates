" Vim plugin file
" Maintainer:	    Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-05-25
" Dependencies:
"   plugin/pcplib.vim

if exists('loaded_now_templates')
  finish
endif
let loaded_now_templates = 1

if !exists('NOW')
  let NOW = {}
endif

let NOW.Templates = {}

command! -nargs=? Template call s:template(<f-args>)

augroup templates
  autocmd BufNewFile		    * call s:template(&ft, expand('<afile>:t'))
  autocmd BufWritePre,FileWritePre  * call s:header_update()
augroup end

" Setup reasonable defaults for our needed GLOBAL values.

" Path to the templates.
if !exists('g:now_templates_template_path')
  let g:now_templates_template_path =
        \ substitute(&runtimepath,
                   \ '\([^\,]\+\%(\\,[^\,]*\)*\),.*', '\1/templates/', '')
endif

" Pattern used to match lines that are skipped before a header is to be found.
if !exists('g:now_templates_skip_before_header_regex')
  let g:now_templates_skip_before_header_regex = ""
endif

" Pattern used to find the beginning of a header.
if !exists('g:now_templates_beginning_of_header_regex')
  let g:now_templates_beginning_of_header_regex = '^'
endif

" Pattern used to find the end of a header.
if !exists('g:now_templates_end_of_header_regex')
  let g:now_templates_end_of_header_regex = '^\s*$'
endif

" Find a variable 'varname' in the bufferlocal namespace or in the global
" namespace.
function s:borgval(varname)
  if exists('b:' . a:varname)
    execute 'return ' . 'b:' . a:varname
  elseif exists('g:' . a:varname)
    execute 'return ' . 'g:' . a:varname
  else
    return ''
  end
endfunction

" Generate an error message that can be thrown to the user.
function s:message(file, line, lnum, offset, message, ...)
  let message = a:0 > 0 ? call('printf', extend([a:message], a:000)) : a:message
  return printf("%s:%d:%d: %s\n%s\n%*s", a:file, a:lnum, a:offset + 1,
              \ message, a:line, a:offset + 1, '^')
endfunction

" Try to get some input from the user.  If the user is uninterested, throw an
" error that can be caught further up to exit the substitution of placeholders.
function s:try_input(prompt, text)
  let input = input(a:prompt, a:text)
  if input == ''
    throw 'abort substitution'
  else
    return input
  end
endfunction


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

function s:skip_while(pattern, ...)
  let i = (a:0 > 0 ? a:1 : 1)
  let n = (a:0 > 1 ? a:2 : line('$') + 1)
  while i < n && getline(i) =~ a:pattern
    let i += 1
  endwhile
  return i
endfunctio

function s:skip_until(pattern, ...)
  let i = (a:0 > 0 ? a:1 : 1)
  let n = (a:0 > 1 ? a:2 : line('$') + 1)
  while i < n && getline(i) !~ a:pattern
    let i += 1
  endwhile
  return i
endfunction

let NOW.Templates.Template = {}

function NOW.Templates.Template.new(file) dict
  let template = deepcopy(self)
  let template.file = a:file
  let template.line = ""
  let template.lnum = 1
  let template.offset = 0
  return template
endfunction

function NOW.Templates.Template.expand() dict
  " Read in the template.  Remove the last line if this is a new file, since it
  " will be a remnant of the sole empty line from the new buffer.
  let empty = (line('$') == 1 && getline('$') == "")
  silent execute '0read' self.file
  silent! '[,']foldopen!
  if empty
    silent $delete _
  endif

  let skip = s:borgval('now_templates_skip_before_header_regex')
  if skip != ""
    let self.lnum = s:skip_while(skip, self.lnum)
  endif

  let self.lnum = s:skip_until(s:borgval('now_templates_beginning_of_header_regex'),
                             \ self.lnum)

  let end = s:borgval('now_templates_end_of_header_regex')
  let n = line('$') + 1
  let self.line = getline(self.lnum)
  while self.lnum < n && self.line !~ end
    try
      call self.expand_line()
    catch /^abort substitution$/
      break
    endtry
    let self.lnum += 1
    let self.line = getline(self.lnum)
  endwhile
endfunction

function NOW.Templates.Template.message(message, ...) dict
"  let message = a:0 > 0 ? call('printf', extend([a:message], a:000)) : a:message
"  return printf("%s:%d:%d: %s\n%s\n%*s", self.file, self.lnum, self.offset + 1,
"              \ message, self.line, self.offset + 1, '^')
  call call(self.positioned_message,
          \ extend([self.lnum, self.offset, a:message], a:000), self)
endfunction

function NOW.Templates.Template.positioned_message(lnum, offset, message, ...) dict
  let message = a:0 > 0 ? call('printf', extend([a:message], a:000)) : a:message
  return printf("%s:%d:%d: %s\n%s\n%*s", self.file, a:lnum, a:offset + 1,
              \ message, self.line, a:offset + 1, '^')
endfunction

function NOW.Templates.Template.expand_line() dict
  let self.offset = 0
  let len = strlen(self.line)
  let new = ""
  while self.offset < len
    let c = self.line[self.offset]
    if c == '&'
      let c = self.get_char()
      let new .= c
    elseif c == '<'
      let saved_offset = self.offset
      let self.offset += 1
      let [tag, attributes] = self.parse_tag(len)
      " TODO: Perhaps move all this code to parse_tag?
      if !g:NOW.Templates.placeholders.has(tag)
        let self.offset = saved_offset
        throw self.message('unrecognized element ‘%s’', tag)
      endif
      let placeholder = g:NOW.Templates.placeholders.lookup(tag)
      let instance_attributes = {}
      for attribute in attributes
        if !has_key(placeholder.attributes, attribute.name)
          throw self.positioned_message(attribute.lnum, attribute.offset,
                                     \ 'illegal attribute ‘%s’ for placeholder ‘%s’',
                                      \ attribute.name, placeholder.name)
        endif
        let instance_attributes[attribute.name] = attribute
      endfor
      for name in keys(placeholder.attributes)
        if !has_key(instance_attributes, name)
          let attribute = g:NOW.Templates.Attribute.new(-1, -1, name)
          let attribute.value = placeholder.attributes[name]
          let instance_attributes[name] = attribute
        endif
      endfor
      let real_offset = self.offset
      let self.offset = saved_offset
      let new .= placeholder.substitute(self, instance_attributes)
      let self.offset = real_offset
"      let new .= placeholder.substitute(self.lnum, saved_offset, instance_attributes)
    else
      let new .= c
      let self.offset += 1
    endif
  endwhile
  let lines = split(new, "\n", 1)
  let last_line = lines[len(lines) - 1]
  let lines[len(lines) - 1] = last_line . strpart(self.line, self.offset)
  call setline(self.lnum, lines)
  let self.lnum += len(lines) - 1
  let self.offset = len(last_line)
endfunction

function NOW.Templates.Template.parse_tag(end) dict
  let tag = matchstr(self.line, '^[[:alpha:]_][[:alnum:]._-]*', self.offset)
  if tag == ""
    throw self.message('invalid element name')
  endif
  let attributes =[]
  " TODO: Only update self.offset on successful parses and turn saved_offset
  " into the iterator (and call it offset, or something).
  let saved_offset = self.offset + len(tag)
  let self.offset = matchend(self.line, '^\s\+', saved_offset)
  while self.offset != -1
    let saved_offset = self.offset
    if self.line[self.offset] == '>'
      break
    endif
    let name = matchstr(self.line, '^[[:alpha:]_][[:alnum:]._-]*', self.offset)
    let attribute = g:NOW.Templates.Attribute.new(self.lnum, self.offset, name)
    let offset = matchend(self.line, '^\s*=\s*', self.offset + strlen(name))
    if offset == -1 || offset == a:end
      throw self.message('attribute without value')
    endif
    let self.offset = offset
    let delimiter = self.line[self.offset]
    if delimiter != '"' && delimiter != "'"
      throw self.message('expected ‘"’ or ‘''’')
    endif
    let saved_offset = self.offset
    let self.offset += strlen(delimiter)
    let value = ""
    while self.offset < a:end && self.line[self.offset] != delimiter
      let c = self.get_char()
      let value .= c
    endwhile
    if self.offset == a:end
      let self.offset = saved_offset
      throw self.message('unterminated attribute-value')
    endif
    let attribute.value = value
    " TODO: Should check for duplicate attributes, and this should be a hash
    " after all.
    call add(attributes, attribute)
    let saved_offset = self.offset + 1
    let self.offset = matchend(self.line, '^\s\+', saved_offset)
  endwhile
  let self.offset = saved_offset
  if self.offset >= a:end
    throw self.message('unterminated tag')
  endif
  if self.line[self.offset] != '>'
    throw self.message('expected ‘>’ but got ‘%s’', self.line[self.offset])
  endif
  let self.offset += 1
  return [tag, attributes]
endfunction

function NOW.Templates.Template.get_char() dict
  if self.line[self.offset] == '&'
    self.offset += 1
    " TODO: Use a regex here instead, as the name of the entity can only be \w
    " or some suche.
    let end = stridx(self.line, ';', self.offset)
    if end == -1
      throw self.message('unterminated character reference')
    end

    let entity = s:Entities.lookup(self, strpart(self.line, self.offset, end - self.offset))
    let self.offset = end + 1
    return entity
  endif

  let c = self.line[self.offset]
  let self.offset += 1
  return c
endfunction

let NOW.Templates.Attribute = {}

function NOW.Templates.Attribute.new(lnum, offset, name) dict
  let attribute = deepcopy(self)
  let attribute.lnum = a:lnum
  let attribute.offset = a:offset
  let attribute.name = a:name
  return attribute
endfunction

let s:Entities = { 'lt': '<', 'gt': '>', 'amp': '&' }

function s:Entities.lookup(template, name) dict
  if !has_key(self, a:name)
    throw a:template.message('unrecognized character reference ‘%s’', a:name)
  endif

  return self[a:name]
endfunction

" Format a format-string with directives.
function s:format(template, placeholder, format)
  let i = 0
  let n = strlen(a:format.value)
  let new = ""
  while i < n
    let c = a:format.value[i]
    if c == '%'
      let i += 1
      if i == n
        throw a:template.positioned_message(a:format.lnum, a:format.column + i,
                                          \ 'unterminated format-directive')
      endif
      let c = a:format.value[i]
      if c == '%'
        let new .= '%'
      else
        let new .= a:placeholder.directive(a:template, a:format.lnum,
                                         \ a:format.column + i, c)
      endif
    else
      let new .= c
    endif
    let i += 1
  endwhile
  return new
endfunction

" TODO: I guess these should really be instantiated for every template.
let s:FileDescriptionPlaceholder = {
      \   'name': 'file-description',
      \   'attributes': {'format': 'contents: %s'}
      \ }

function s:FileDescriptionPlaceholder.substitute(template, attributes) dict
  return s:format(a:template, self, a:attributes['format'])
endfunction

function s:FileDescriptionPlaceholder.directive(template, lnum, column, directive) dict
  if a:directive == 's'
    return s:try_input('Contents of this file: ', "")
  elseif a:directive == 'f'
    return expand('%:t')
  elseif a:directive == 'F'
    return expand('%')
  else
    throw a:template.positioned_message(a:lnum, a:column,
                                      \ 'unrecognized directive ‘%s’',
                                      \ a:directive)
  end
endfunction

call NOW.Templates.placeholders.register(s:FileDescriptionPlaceholder)

let s:CopyrightPlaceholder = {
      \   'name': 'copyright',
      \   'attributes': {'format': 'Copyright © %Y %N'}
      \ }

function s:CopyrightPlaceholder.substitute(template, attributes) dict
  return s:format(a:template, self, a:attributes['format'])
endfunction

function s:CopyrightPlaceholder.directive(template, lnum, column, directive) dict
  if a:directive == 'N'
    return g:pcp_plugins_username
  else
    return strftime('%' . a:directive)
  end
endfunction

call NOW.Templates.placeholders.register(s:CopyrightPlaceholder)

" Join file components, checking for separators and adding as necessary.
function s:join_filenames(head, tail)
  return a:head . (a:head =~ '/$' ? "" : '/') . a:tail
endfunction

function s:find_template_file(ft)
  return s:join_filenames(expand(g:now_templates_template_path),
                        \ a:ft . '.template')
endfunction

" Called by autocmd above and Template command.
function s:template(...)
  " Get the 'filetype' of the file we want to find a template for.
  let ft = (a:0 > 0) ? a:1 : &ft

  let template_file = s:find_template_file(ft)

  " If we weren’t able to find a template, then depending on if we were called
  " from an autocmd or not, either simply return, or report an error.
  if !filereadable(template_file)
    if a:0 < 2
      echohl ErrorMsg
      echo printf('Unable to find template file for filetype ‘%s’', ft)
      echohl None
    endif
    return
  endif

  let template = g:NOW.Templates.Template.new(template_file)
  try
    call template.expand()
  catch
    echohl ErrorMsg
    echo v:exception
    echohl None
  endtry


  " Move the cursor to the end of the template.
  let i = 1

  let skip = s:borgval('now_templates_skip_before_header_regex')
  if skip != ""
    let i = s:skip_while(skip, i)
  endif

  let i = s:skip_until(s:borgval('now_templates_beginning_of_header_regex'), i)
  let i = s:skip_until(s:borgval('now_templates_end_of_header_regex'), i)
  call cursor(i + 1, 0)

  " Mark the buffer as modified.
  set modified
endfunction

if !exists('g:now_templates_license_regex')
  let g:now_templates_license_regex = '<License>'
endif

if !exists('g:now_templates_author_regex')
  let g:now_templates_author_regex = '^\(.\{1,3}\<Author\>\s*:\s*\).*$'
endif

if !exists('g:now_templates_url_regex')
  let g:now_templates_url_regex = '^\(.\{1,3}\<URL\>\s*:\s*\).*$'
endif

if !exists('g:now_templates_revised_on_regex')
  let g:now_templates_revised_on_regex = 
	\'^\(.\{1,3}\<Latest Revision\>\s*:\s*\).*$'
endif

" called by autocmd above.
function s:header_update()
  " if we don't have a template for this kind of file, don't update it.
  if !filereadable(s:join_filenames(expand(g:now_templates_template_path), 
        \ 
	\'template.' . &ft))
    return
  endif

  " don't update headers for files in template directory.
  if expand("%:p:h") . '/' == expand(g:now_templates_template_path)
    return
  endif

  " only update if necessary
  let lnum = s:find_hline(s:borgval('now_templates_revised_on_regex'))
  let line = getline(lnum)
  let newline = substitute(line,
	\s:borgval('now_templates_revised_on_regex'),
	\'\1' . strftime(g:pcp_plugins_dateformat), '')
  if line != newline
    call setline(lnum, newline)
  endif
endfunction


"  let licensefile = s:borgval('now_templates_license')
"  " and license statements.
"  let licensefile = s:join_filenames(expand(g:now_templates_template_path),
"	\licensefile.'.LICENSE')
"  if filereadable(licensefile)
"    let lnum = s:find_hline(g:now_templates_license_regex)
"    if lnum != 0
"      let prefix = substitute(getline(lnum),
"	    \'^\(.\{-}\)' . g:now_templates_license_regex, '\1', '')
"      silent execute lnum . 'read ' . licensefile
"      silent execute "'[,']s/^/".prefix."/e"
"      '[,']s/\s\+$//e
"      silent execute lnum . 'delete _'
"    endif
"  else
"    call s:update_hline(g:now_templates_license_regex,
"	  \'see the COPYING file for license information.')
"  endif
