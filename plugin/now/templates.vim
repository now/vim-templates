" Vim plugin file
" Maintainer:	    Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-06-16

if exists('loaded_plugin_now_templates')
  finish
endif
let loaded_plugin_now_templates = 1

let s:cpo_save = &cpo
set cpo&vim

runtime lib/now.vim
runtime lib/now/file.vim
runtime lib/now/system.vim
runtime lib/now/system/network.vim
runtime lib/now/system/passwd.vim
runtime lib/now/system/user.vim
runtime lib/now/vim.vim
runtime lib/now/vim/motion.vim
runtime lib/now/templates.vim
runtime lib/now/templates/attribute.vim
runtime lib/now/templates/entities.vim
runtime lib/now/templates/formatter.vim
runtime lib/now/templates/template.vim
runtime lib/now/templates/updatableheaderlines.vim

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
    throw 'abort expansion'
  else
    return input
  end
endfunction

" TODO: Placeholders and updatable-headerlines should probably be in the
" NOW.Templates namespace, so that people can modify them easily, if they so
" desire.

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
    let file = g:NOW.File.join(expand(g:now_templates_template_path),
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

let s:NamePlaceholder = {
      \   'name': 'name',
      \   'attributes': {'format': '%N'}
      \ }

function s:NamePlaceholder.expand(template, attributes) dict
  return g:NOW.Templates.Formatter.new(a:template, self, a:attributes['format'])
                                 \.format()
endfunction

function s:NamePlaceholder.directive(template, lnum, offset, directive) dict
  if a:directive == 'N'
    return g:NOW.System.User.email_address()
  else
    throw a:template.positioned_message(a:lnum, a:offset,
                                      \ 'unrecognized directive ‘%s’',
                                      \ a:directive)
  end
endfunction

call NOW.Templates.placeholders.register(s:NamePlaceholder)

function s:find_template_file(ft, interactive)
  let template_file = g:NOW.File.join(expand(g:now_templates_template_path),
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
  let lnum = 1

  let skip = g:NOW.Vim.b_or_g('now_templates_skip_before_header_regex')
  if skip != ""
    let lnum = g:NOW.Vim.Motion.iterate_lines_matching(skip, lnum)
  endif

  let lnum = g:NOW.Vim.Motion.iterate_lines_not_matching(
                 \ g:NOW.Vim.b_or_g('now_templates_beginning_of_header_regex'),
                                  \ lnum)

  call g:NOW.Vim.Motion.iterate_lines_not_matching(
                \ g:NOW.Vim.b_or_g('now_templates_end_of_header_regex'), lnum)

  call cursor(lnum + 1, 0)
endfunction

let s:LatestRevisionUpdater = {
      \ 'pattern': '^\(.\{1,3}\<Latest Revision\>\s*:\s*\).*$',
      \ 'time_format': '%Y-%m-%d'
      \ }

function s:LatestRevisionUpdater.update(line, lnum, matches) dict
  return printf("%s%s", a:matches[1],
              \ strftime(g:NOW.Vim.b_or_g('now_templates_latest_revision_time_format',
                                        \ self.time_format)))
endfunction

call NOW.Templates.UpdatableHeaderlines.register(s:LatestRevisionUpdater)

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

let &cpo = s:cpo_save
