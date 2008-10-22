let s:cpo_save = &cpo
set cpo&vim

let s:updaters = []

function! now#template#updatableheaderlines#register(updater)
  call add(s:updaters, a:updater)
endfunction

function! now#template#updatableheaderlines#update()
  let lnum = 1

  let skip = now#vim#b_or_g('now_templates_skip_before_header_regex')
  if skip != ""
    let lnum = now#vim#motion#iterate_lines_matching(skip, lnum)
  endif

  let lnum = now#vim#motion#iterate_lines_not_matching(
                 \ now#vim#b_or_g('now_templates_beginning_of_header_regex'),
                                  \ lnum)

  call now#vim#motion#iterate_lines_not_matching(
                \ now#vim#b_or_g('now_templates_end_of_header_regex'), lnum,
                \ 0, 'now#template#updatableheaderlines#update_line')
endfunction

function! now#template#updatableheaderlines#update_line(line, lnum)
  for updater in s:updaters
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
  return 1
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save
