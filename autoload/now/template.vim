let s:cpo_save = &cpo
set cpo&vim

function! now#template#new(file)
  let template = deepcopy(g:now#template#object)
  let template.file = a:file
  let template.line = ""
  let template.lnum = 1
  let template.offset = 0
  return template
endfunction

let now#template#object = {}

function! now#template#object.expand() dict
  call self.read_template_file()

  let skip = now#vim#b_or_g('now_templates_skip_before_header_regex')
  if skip != ""
    let self.lnum = now#vim#motion#iterate_lines_matching(skip, self.lnum)
  endif

  let self.lnum = now#vim#motion#iterate_lines_not_matching(
                 \  now#vim#b_or_g('now_templates_beginning_of_header_regex'),
                 \                 self.lnum)

  call now#vim#motion#iterate_lines_not_matching(
        \ now#vim#b_or_g('now_templates_end_of_header_regex'),
        \ self.lnum, 0, self.expand_line, self)
endfunction

" Read in the template.  Remove the last line if this is a new file, since it
" will be a remnant of the sole empty line from the new buffer.
function! now#template#object.read_template_file() dict
  let empty = (line('$') == 1 && getline('$') == "")

  silent execute 'keepjumps keepalt 0read' self.file
  silent! '[,']foldopen!

  if empty
    silent $delete _
  endif
endfunction

function! now#template#object.message(message, ...) dict
  return call(self.positioned_message,
            \ extend([self.lnum, self.offset, a:message], a:000), self)
endfunction

function! now#template#object.positioned_message(lnum, offset, message, ...) dict
  let message = a:0 > 0 ? call('printf', extend([a:message], a:000)) : a:message
  return printf("%s:%d:%d: %s\n%s\n%*s", self.file, a:lnum, a:offset + 1,
              \ message, self.line, a:offset + 1, '^')
endfunction

function! now#template#object.expand_line(line, lnum) dict
  try
    let self.line = a:line
    let self.lnum = a:lnum
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
  catch /^abort expansion$/
    return 0
  endtry
  return 1
endfunction

function! now#template#object.expand_placeholder(end) dict
  let start = self.offset
  let self.offset += 1
  let [tag, attributes] = self.parse_tag(a:end)
  let placeholder = now#template#placeholders#lookup(tag)
  let instance_attributes = self.merge_attributes(attributes,
                                                \ placeholder.attributes,
                                                \ placeholder.name)
  let saved_offset = self.offset
  let self.offset = start
  let expansion = placeholder.expand(self, instance_attributes)
  let self.offset = saved_offset
  return expansion
endfunction

function! now#template#object.merge_attributes(attributes, defaults, name) dict
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
      let attribute = now#template#attribute#new(-1, -1, name)
      let attribute.value = a:defaults[name]
      let instance_attributes[name] = attribute
    endif
  endfor

  return instance_attributes
endfunction

" TODO: should check that a:new isn’t equal to self.line, if it is, just skip
" it.
function! now#template#object.update_line(new) dict
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

function! now#template#object.parse_tag(end) dict
  let start = self.offset - 1

  let tag = matchstr(self.line, '^[[:alpha:]_][[:alnum:]._-]*', self.offset)
  if tag == ""
    throw self.message('invalid element name')
  elseif !now#template#placeholders#has(tag)
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

function! now#template#object.parse_attributes(limit) dict
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

function! now#template#object.parse_attribute(limit) dict
  let attribute = self.parse_attribute_name()
  call self.skip_attribute_equals(a:limit)
  let attribute.value = self.parse_attribute_value(a:limit)
  return attribute
endfunction

function! now#template#object.parse_attribute_name() dict
  let name = matchstr(self.line, '^[[:alpha:]_][[:alnum:]._-]*', self.offset)
  if name == ""
    throw self.message('invalid attribute name')
  endif
  let attribute = now#template#attribute#new(self.lnum, self.offset, name)
  let self.offset += strlen(name)
  return attribute
endfunction

function! now#template#object.skip_attribute_equals(limit) dict
  let end = matchend(self.line, '^\s*=\s*', self.offset)
  if end == -1 || end == a:limit || self.offset == a:limit
    throw self.message('attribute without value')
  endif
  let self.offset = end
endfunction

function! now#template#object.parse_attribute_value(limit) dict
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

function! now#template#object.parse_attribute_value_delimiter(limit) dict
  let delimiter = self.line[self.offset]
  if delimiter != '"' && delimiter != "'"
    throw self.message('expected ‘"’ or ‘''’')
  endif
  let self.offset += strlen(delimiter)
  return delimiter
endfunction

function! now#template#object.get_char() dict
  if self.line[self.offset] == '&'
    self.offset += 1
    return self.parse_entity_reference()
  endif

  let c = self.line[self.offset]
  let self.offset += 1
  return c
endfunction

function! now#template#object.parse_entity_reference() dict
  let end = matchend(self.line, '^[[:alpha:]_][[:alnum:]._-]*', self.offset)
  if end == -1
    throw self.message('character reference without a name')
  elseif self.line[end] != ';'
    throw self.message('‘;’ expected')
  endif

  let name = strpart(self.line, self.offset, end - self.offset)
  let self.offset = end + 1

  return now#template#entities#lookup(self, name)
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save
