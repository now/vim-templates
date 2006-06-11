" Vim library file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-06-12

if exists('loaded_lib_now_templates_updatableheaderlines')
  finish
endif
let loaded_lib_now_templates_updatableheaderlines = 1

let NOW.Templates.UpdatableHeaderlines = {'updaters': []}

function NOW.Templates.UpdatableHeaderlines.register(updater) dict
  call add(self.updaters, a:updater)
endfunction

function NOW.Templates.UpdatableHeaderlines.update() dict
  let lnum = 1

  let skip = g:NOW.Vim.b_or_g('now_templates_skip_before_header_regex')
  if skip != ""
    let lnum = g:NOW.Vim.Motion.iterate_lines_matching(skip, lnum)
  endif

  let lnum = g:NOW.Vim.Motion.iterate_lines_not_matching(
                 \ g:NOW.Vim.b_or_g('now_templates_beginning_of_header_regex'),
                                  \ lnum)

  call g:NOW.Vim.Motion.iterate_lines_not_matching(
                \ g:NOW.Vim.b_or_g('now_templates_end_of_header_regex'), lnum,
                \ 0, self.update_line, self)
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
  return 1
endfunction
