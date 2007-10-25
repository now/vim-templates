" Vim plugin file
" Maintainer:	    Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2007-09-20

if exists('loaded_plugin_now_templates')
  finish
endif
let loaded_plugin_now_templates = 1

let s:cpo_save = &cpo
set cpo&vim

command! -nargs=? Template call s:template_cmd(<f-args>)

augroup templates
  autocmd BufNewFile		    * call s:template(0, &ft, "")
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
    throw 'abort expansion'
  else
    return input
  end
endfunction

" TODO: Placeholders and updatable-headerlines should probably be in the
" NOW.Templates namespace, so that people can modify them easily, if they so
" desire.

" TODO: I guess these should really be instantiated for every template.
let s:file_description_placeholder = {
      \   'name': 'file-description',
      \   'attributes': {'format': 'contents: %s'}
      \ }

function s:file_description_placeholder.expand(template, attributes) dict
  return now#template#formatter#new(a:template, self, a:attributes['format']).format()
endfunction

function s:file_description_placeholder.directive(template, lnum, offset, directive) dict
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

call now#template#placeholders#register(s:file_description_placeholder)

let s:copyright_placeholder = {
      \   'name': 'copyright',
      \   'attributes': {'format': 'Copyright © %Y %N'}
      \ }

" TODO: Placeholders should be based off of a placeholder mix-in that has this
" method, as it is usually the same.
function s:copyright_placeholder.expand(template, attributes) dict
  return now#template#formatter#new(a:template, self, a:attributes['format']).format()
endfunction

function s:copyright_placeholder.directive(template, lnum, offset, directive) dict
  if a:directive == 'N'
    return now#system#user#email_address()
  else
    return strftime('%' . a:directive)
  end
endfunction

call now#template#placeholders#register(s:copyright_placeholder)

let s:license_placeholder = {
      \   'name': 'license',
      \   'attributes': {'name': "", 'file': ""}
      \ }

function s:license_placeholder.expand(template, attributes) dict
  let file = a:attributes['file'].value
  if file == ""
    if a:attributes['name'].value == ""
      let a:attributes['name'].value = now#vim#b_or_g('now_templates_license', 'GPL')
    endif
    let file = now#file#join(expand(g:now_templates_template_path),
          \                  a:attributes['name'].value . '.license')
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

function s:license_placeholder.cleanup(line) dict
  return substitute(a:line, '\s\+$', "", "")
endfunction

call now#template#placeholders#register(s:license_placeholder)

let s:name_placeholder = {
      \   'name': 'name',
      \   'attributes': {'format': '%N'}
      \ }

function s:name_placeholder.expand(template, attributes) dict
  return now#template#formatter#new(a:template, self, a:attributes['format']).format()
endfunction

function s:name_placeholder.directive(template, lnum, offset, directive) dict
  if a:directive == 'N'
    return now#system#user#email_address()
  else
    throw a:template.positioned_message(a:lnum, a:offset,
                                      \ 'unrecognized directive ‘%s’',
                                      \ a:directive)
  end
endfunction

call now#template#placeholders#register(s:name_placeholder)

function s:find_template_file(interactive, filetype, subtype)
  if a:filetype == ""
    return ""
  endif
  let template_path = expand(g:now_templates_template_path)
  let template_file = now#file#join(template_path, a:filetype . '.template')
  let template_subpath = now#file#join(template_path, a:filetype)
  if isdirectory(template_subpath)
    let template_path = template_subpath
    if !a:interactive
      return template_path
    endif
    let subtype = a:subtype
    if subtype == ""
      let subtype = input('Subtemplate to use for filetype ' . a:filetype . ': ')
      if subtype == ""
        let subtype = 'default'
      endif
    endif
    let template_file = now#file#join(template_path, subtype . '.template')
  endif

  " If we weren’t able to find a template, then depending on if we were called
  " from an autocmd or not, either simply return, or report an error.
  if !filereadable(template_file)
    if a:interactive
      throw printf('Unable to find template file for filetype ‘%s’', a:filetype)
    endif
    return ""
  endif

  return template_file
endfunction

function s:template_cmd(...)
  call s:template(0, (a:0 > 0) ? a:1 : &filetype, (a:0 > 1) ? a:1 : "")
endfunction

" Called by autocmd above.
function s:template(interactive, filetype, subtype)
  try
    let template_file = s:find_template_file(1, a:filetype, a:subtype)
    if template_file == ""
      return
    endif
    let template = now#template#new(template_file)
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
  let lnum = 1

  let skip = now#vim#b_or_g('now_templates_skip_before_header_regex')
  if skip != ""
    let lnum = now#vim#motion#iterate_lines_matching(skip, lnum)
  endif

  let lnum = now#vim#motion#iterate_lines_not_matching(
                 \ now#vim#b_or_g('now_templates_beginning_of_header_regex'),
                                  \ lnum)

  let lnum = now#vim#motion#iterate_lines_not_matching(
                \ now#vim#b_or_g('now_templates_end_of_header_regex'), lnum)

  call cursor(lnum + 1, 0)
endfunction

let s:latest_revision_updater = {
      \ 'pattern': '^\(.\{1,3}\<Latest Revision\>\s*:\s*\).*$',
      \ 'time_format': '%Y-%m-%d'
      \ }

function s:latest_revision_updater.update(line, lnum, matches) dict
  return printf("%s%s", a:matches[1],
              \ strftime(now#vim#b_or_g('now_templates_latest_revision_time_format',
                                        \ self.time_format)))
endfunction

call now#template#updatableheaderlines#register(s:latest_revision_updater)

" Called by autocmd above.
function s:update_updatable_headerlines()
  " If we don't have a template for this kind of file, don't update it.
  if s:find_template_file(0, &filetype, "") == ""
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
    call now#template#updatableheaderlines#update()
  catch /^\%(Vim\)\@!/
    echohl ErrorMsg
    echo v:exception
    echohl None
  endtry
endfunction

let &cpo = s:cpo_save
