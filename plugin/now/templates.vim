" Vim plugin file
" Maintainer:	    Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-06-11

if exists('loaded_now_templates')
  finish
endif
let loaded_now_templates = 1

runtime lib/now.vim
runtime lib/now/system.vim
runtime lib/now/system/network.vim
runtime lib/now/system/passwd.vim
runtime lib/now/system/user.vim
runtime lib/now/vim.vim

command! -nargs=? Template call s:template(<f-args>)

augroup templates
  autocmd BufNewFile		    * call s:template(&ft, expand('<afile>:t'))
  autocmd BufWritePre,FileWritePre  * call s:update_updatable_headerlines()
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

function s:skip_while(pattern, ...)
  return call('s:skip_while_or_until', extend([0, a:pattern], a:000))
endfunction

function s:skip_until(pattern, ...)
  return call('s:skip_while_or_until', extend([1, a:pattern], a:000))
endfunction

function s:skip_while_or_until(until, pattern, ...)
  let i = (a:0 > 0 ? a:1 : 1)
  let n = (a:0 > 1 ? a:2 : line('$') + 1)
  while i < n
    let matched = getline(i) =~ a:pattern
    if (a:until && matched) || (!a:until && !matched)
      break
    endif
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
  call self.read_template_file()

  let skip = g:NOW.Vim.b_or_g('now_templates_skip_before_header_regex')
  if skip != ""
    let self.lnum = s:skip_while(skip, self.lnum)
  endif

  let self.lnum = s:skip_until(g:NOW.Vim.b_or_g('now_templates_beginning_of_header_regex'),
                             \ self.lnum)

  " TODO: Move this to a separate function called expand_lines().
  let end = g:NOW.Vim.b_or_g('now_templates_end_of_header_regex')
  let self.line = getline(self.lnum)
  while self.lnum < line('$') + 1 && self.line !~ end
    try
      call self.expand_line()
    catch /^abort substitution$/
      break
    endtry
    let self.lnum += 1
    let self.line = getline(self.lnum)
  endwhile
endfunction

" Read in the template.  Remove the last line if this is a new file, since it
" will be a remnant of the sole empty line from the new buffer.
function NOW.Templates.Template.read_template_file() dict
  let empty = (line('$') == 1 && getline('$') == "")

  silent execute '0read' self.file
  silent! '[,']foldopen!

  if empty
    silent $delete _
  endif
endfunction

function NOW.Templates.Template.message(message, ...) dict
  return call(self.positioned_message,
            \ extend([self.lnum, self.offset, a:message], a:000), self)
endfunction

function NOW.Templates.Template.positioned_message(lnum, offset, message, ...) dict
  let message = a:0 > 0 ? call('printf', extend([a:message], a:000)) : a:message
  return printf("%s:%d:%d: %s\n%s\n%*s", self.file, a:lnum, a:offset + 1,
              \ message, self.line, a:offset + 1, '^')
endfunction

function NOW.Templates.Template.expand_line() dict
  let self.offset = 0
  let end = strlen(self.line)
  let new = ""
  while self.offset < end
    if self.line[self.offset] == '<'
      let new .= self.expand_placeholder(end)
    else
      let new .= self.get_char()
    endif
  endwhile
  call self.update_line(new)
endfunction

function NOW.Templates.Template.expand_placeholder(end) dict
  let start = self.offset
  let self.offset += 1
  let [tag, attributes] = self.parse_tag(a:end)
  let placeholder = g:NOW.Templates.placeholders.lookup(tag)
  let instance_attributes = self.merge_attributes(attributes,
                                                \ placeholder.attributes,
                                                \ placeholder.name)
  let saved_offset = self.offset
  let self.offset = start
  let expansion = placeholder.expand(self, instance_attributes)
  let self.offset = saved_offset
  return expansion
endfunction

function NOW.Templates.Template.merge_attributes(attributes, defaults, name) dict
  for attribute in values(a:attributes)
    if !has_key(a:defaults, attribute.name)
      throw self.positioned_message(attribute.lnum, attribute.offset,
                                  \ 'illegal attribute ‘%s’ for placeholder ‘%s’',
                                  \ attribute.name, a:name)
    endif
  endfor

  let instance_attributes = a:attributes

  for name in keys(a:defaults)
    if !has_key(instance_attributes, name)
      let attribute = g:NOW.Templates.Attribute.new(-1, -1, name)
      let attribute.value = a:defaults[name]
      let instance_attributes[name] = attribute
    endif
  endfor

  return instance_attributes
endfunction

" TODO: should check that a:new isn’t equal to self.line, if it is, just skip
" it.
function NOW.Templates.Template.update_line(new) dict
  let lines = split(a:new, "\n", 1)
  let last_line = lines[len(lines) - 1]
  let lines[len(lines) - 1] = last_line . strpart(self.line, self.offset)
  call setline(self.lnum, lines[0])
  if len(lines) > 1
    call remove(lines, 0)
    call append(self.lnum, lines)
    let self.lnum += len(lines)
  endif

  let self.offset = len(last_line)
endfunction

function NOW.Templates.Template.parse_tag(end) dict
  let start = self.offset - 1

  let tag = matchstr(self.line, '^[[:alpha:]_][[:alnum:]._-]*', self.offset)
  if tag == ""
    throw self.message('invalid element name')
  elseif !g:NOW.Templates.placeholders.has(tag)
    throw self.message('unrecognized element ‘%s’', tag)
  endif

  let self.offset += strlen(tag)
  let attributes = self.parse_attributes(a:end)

  if self.offset >= a:end
    let self.offset = start
    throw self.message('unterminated placeholder')
  endif

  if self.line[self.offset] != '>'
    throw self.message('expected ‘>’ but got ‘%s’', self.line[self.offset])
  endif
  let self.offset += 1

  return [tag, attributes]
endfunction

function NOW.Templates.Template.parse_attributes(limit) dict
  let attributes = {}
  let end = matchend(self.line, '^\s\+', self.offset)
  while end != -1
    let self.offset = end
    if self.line[self.offset] == '>'
      break
    endif
    let attribute = self.parse_attribute(a:limit)
    if has_key(attributes, attribute.name)
      throw self.message('attribute ‘%s’ redefined', attribute.name)
    endif
    let attributes[attribute.name] = attribute
    let end = matchend(self.line, '^\s\+', self.offset)
  endwhile
  return attributes
endfunction

function NOW.Templates.Template.parse_attribute(limit) dict
  let attribute = self.parse_attribute_name()
  call self.skip_attribute_equals(a:limit)
  let attribute.value = self.parse_attribute_value(a:limit)
  return attribute
endfunction

function NOW.Templates.Template.parse_attribute_name() dict
  let name = matchstr(self.line, '^[[:alpha:]_][[:alnum:]._-]*', self.offset)
  if name == ""
    throw self.message('invalid attribute name')
  endif
  let attribute = g:NOW.Templates.Attribute.new(self.lnum, self.offset, name)
  let self.offset += strlen(name)
  return attribute
endfunction

function NOW.Templates.Template.skip_attribute_equals(limit) dict
  let end = matchend(self.line, '^\s*=\s*', self.offset)
  if end == -1 || end == a:limit || self.offset == a:limit
    throw self.message('attribute without value')
  endif
  let self.offset = end
endfunction

function NOW.Templates.Template.parse_attribute_value(limit) dict
  let start = self.offset
  let delimiter = self.parse_attribute_value_delimiter(a:limit)
  let value = ""
  while self.offset < a:limit && self.line[self.offset] != delimiter
    let value .= self.get_char()
  endwhile
  if self.offset == a:limit
    let self.offset = start
    throw self.message('unterminated attribute-value')
  endif
  let self.offset += strlen(delimiter)
  return value
endfunction

function NOW.Templates.Template.parse_attribute_value_delimiter(limit) dict
  let delimiter = self.line[self.offset]
  if delimiter != '"' && delimiter != "'"
    throw self.message('expected ‘"’ or ‘''’')
  endif
  let self.offset += strlen(delimiter)
  return delimiter
endfunction

function NOW.Templates.Template.get_char() dict
  if self.line[self.offset] == '&'
    self.offset += 1
    return self.parse_entity_reference()
  endif

  let c = self.line[self.offset]
  let self.offset += 1
  return c
endfunction

function NOW.Templates.Template.parse_entity_reference() dict
  let end = matchend(self.line, '^[[:alpha:]_][[:alnum:]._-]*', self.offset)
  if end == -1
    throw self.message('character reference without a name')
  elseif self.line[end] != ';'
    throw self.message('‘;’ expected')
  endif

  let name = strpart(self.line, self.offset, end - self.offset)
  let self.offset = end + 1

  return g:NOW.Templates.Entities.lookup(self, name)
endfunction

let NOW.Templates.Attribute = {}

function NOW.Templates.Attribute.new(lnum, offset, name) dict
  let attribute = deepcopy(self)
  let attribute.lnum = a:lnum
  let attribute.offset = a:offset
  let attribute.name = a:name
  return attribute
endfunction

let NOW.Templates.Entities = { 'lt': '<', 'gt': '>', 'amp': '&' }

function NOW.Templates.Entities.lookup(template, name) dict
  if !has_key(self, a:name)
    throw a:template.message('unrecognized character reference ‘%s’', a:name)
  endif

  return self[a:name]
endfunction

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

" TODO: I guess these should really be instantiated for every template.
let s:FileDescriptionPlaceholder = {
      \   'name': 'file-description',
      \   'attributes': {'format': 'contents: %s'}
      \ }

function s:FileDescriptionPlaceholder.expand(template, attributes) dict
  return g:NOW.Templates.Formatter.new(a:template, self, a:attributes['format'])
                                 \.format()
endfunction

function s:FileDescriptionPlaceholder.directive(template, lnum, offset, directive) dict
  if a:directive == 's'
    return s:try_input('Contents of this file: ', "")
  elseif a:directive == 'f'
    return expand('%:t')
  elseif a:directive == 'F'
    return expand('%')
  else
    throw a:template.positioned_message(a:lnum, a:offset,
                                      \ 'unrecognized directive ‘%s’',
                                      \ a:directive)
  end
endfunction

call NOW.Templates.placeholders.register(s:FileDescriptionPlaceholder)

let s:CopyrightPlaceholder = {
      \   'name': 'copyright',
      \   'attributes': {'format': 'Copyright © %Y %N'}
      \ }

function s:CopyrightPlaceholder.expand(template, attributes) dict
  return g:NOW.Templates.Formatter.new(a:template, self, a:attributes['format'])
                                 \.format()
endfunction

function s:CopyrightPlaceholder.directive(template, lnum, offset, directive) dict
  if a:directive == 'N'
    return g:NOW.System.User.email_address()
  else
    return strftime('%' . a:directive)
  end
endfunction

call NOW.Templates.placeholders.register(s:CopyrightPlaceholder)

let s:LicensePlaceholder = {
      \   'name': 'license',
      \   'attributes': {'name': "", 'file': ""}
      \ }

function s:LicensePlaceholder.expand(template, attributes) dict
  let file = a:attributes['file'].value
  if file == ""
    if a:attributes['name'].value == ""
      let a:attributes['name'].value = g:NOW.Vim.b_or_g('now_templates_license', 'GPL')
    endif
    let file = s:join_filenames(expand(g:now_templates_template_path),
                              \ a:attributes['name'].value . '.license')
  endif

  if !filereadable(file)
    " TODO: should really be positioned over the start of the placeholder
    throw a:template.message('can’t find license file ‘%s’', file)
  endif

  " TODO: We really need to instantiate placeholders with the proper
  " information about where they are.  This works, but is a bit of a hack.
  let prefix = strpart(a:template.line, 0, a:template.offset)
  let contents = readfile(file)
  if len(contents) == 0
    return ""
  endif
  let first_line = self.cleanup(remove(contents, 0))
  let contents = map(contents, 'self.cleanup(prefix . v:val)')
  call insert(contents, first_line)

  return join(contents, "\n")
endfunction

function s:LicensePlaceholder.cleanup(line) dict
  return substitute(a:line, '\s\+$', "", "")
endfunction

call NOW.Templates.placeholders.register(s:LicensePlaceholder)

" Join file components, checking for separators and adding as necessary.
function s:join_filenames(head, tail)
  return a:head . (a:head =~ '/$' ? "" : '/') . a:tail
endfunction

function s:find_template_file(ft, interactive)
  let template_file = s:join_filenames(expand(g:now_templates_template_path),
                                     \ a:ft . '.template')

  " If we weren’t able to find a template, then depending on if we were called
  " from an autocmd or not, either simply return, or report an error.
  if !filereadable(template_file)
    if a:interactive
      throw printf('Unable to find template file for filetype ‘%s’', ft)
    endif
    return ""
  endif

  return template_file
endfunction

" Called by autocmd above and Template command.
function s:template(...)
  " Get the 'filetype' of the file we want to find a template for.
  let ft = (a:0 > 0) ? a:1 : &ft

  try
    let template_file = s:find_template_file(ft, a:0 < 2)
    if template_file == ""
      return
    endif
    let template = g:NOW.Templates.Template.new(template_file)
    call template.expand()
  catch /^\%(Vim\)\@!/
    echohl ErrorMsg
    echo v:exception
    echohl None
  endtry

  call s:position_cursor_at_end_of_template()

  " Mark the buffer as modified.
  set modified
endfunction

" Move the cursor to the end of the template.
function s:position_cursor_at_end_of_template()
  let i = 1

  let skip = g:NOW.Vim.b_or_g('now_templates_skip_before_header_regex')
  if skip != ""
    let i = s:skip_while(skip, i)
  endif

  let i = s:skip_until(g:NOW.Vim.b_or_g('now_templates_beginning_of_header_regex'), i)
  let i = s:skip_until(g:NOW.Vim.b_or_g('now_templates_end_of_header_regex'), i)
  call cursor(i + 1, 0)
endfunction

let NOW.Templates.UpdatableHeaderlines = {'updaters': []}

function NOW.Templates.UpdatableHeaderlines.register(updater) dict
  call add(self.updaters, a:updater)
endfunction

function NOW.Templates.UpdatableHeaderlines.update() dict
  let lnum = 1

  let skip = g:NOW.Vim.b_or_g('now_templates_skip_before_header_regex')
  if skip != ""
    let lnum = s:skip_while(skip, lnum)
  endif

  let lnum = s:skip_until(g:NOW.Vim.b_or_g('now_templates_beginning_of_header_regex'), lnum)

  let end = g:NOW.Vim.b_or_g('now_templates_end_of_header_regex')
  let line = getline(lnum)
  while lnum < line('$') + 1 && line !~ end
    call self.update_line(line, lnum)
    let lnum += 1
    let line = getline(lnum)
  endwhile
endfunction

function NOW.Templates.UpdatableHeaderlines.update_line(line, lnum) dict
  for updater in self.updaters
    let matches = matchlist(a:line, updater.pattern)
    if len(matches) == 0
      continue
    endif
    let new = updater.update(a:line, a:lnum, matches)
    if new == a:line
      continue
    endif
    call setline(a:lnum, new)
  endfor
endfunction

let NOW.Templates.LatestRevisionUpdater = {
      \ 'pattern': '^\(.\{1,3}\<Latest Revision\>\s*:\s*\).*$',
      \ 'time_format': '%Y-%m-%d'
      \ }

function NOW.Templates.LatestRevisionUpdater.update(line, lnum, matches) dict
  return printf("%s%s", a:matches[1],
              \ strftime(g:NOW.Vim.b_or_g('now_templates_latest_revision_time_format',
                                        \ self.time_format)))
endfunction

call NOW.Templates.UpdatableHeaderlines.register(NOW.Templates.LatestRevisionUpdater)

" Called by autocmd above.
function s:update_updatable_headerlines()
  " If we don't have a template for this kind of file, don't update it.
  if s:find_template_file(&ft, 0) == ""
    return
  endif

  " Don't update headers for files in template directory.
  let path = expand('%:p:h')
  let template_path = expand(g:now_templates_template_path)
  if template_path =~ '/$'
    let path .= '/'
  endif
  if path == template_path
    return
  endif

  try
    call g:NOW.Templates.UpdatableHeaderlines.update()
  catch /^\%(Vim\)\@!/
    echohl ErrorMsg
    echo v:exception
    echohl None
  endtry
endfunction

if !exists('g:now_templates_author_regex')
  let g:now_templates_author_regex = '^\(.\{1,3}\<Author\>\s*:\s*\).*$'
endif

if !exists('g:now_templates_url_regex')
  let g:now_templates_url_regex = '^\(.\{1,3}\<URL\>\s*:\s*\).*$'
endif
