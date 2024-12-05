if exists('g:loaded_ECY_terminal')
  finish
endif
let g:loaded_ECY_terminal = 1

let g:is_windows  = has('win32')
let g:is_macvim    = has('gui_macvim')
" must put these outside a function
" s:current_file_dir look like: /home/myplug/plugin_for_ECY
let s:current_file_dir = expand( '<sfile>:p:h:h:h' )
let s:current_file_dir = tr(s:current_file_dir, '\', '/')



""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                       Init some variables you need                        "
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
let g:terminal_last_cmd = []
let g:terminal_current_cmd = ''
let g:terminal_cached_file_path = s:current_file_dir . '/cached_cmd.json'
let g:terminal_new_cmd = "<C-t>"
let g:terminal_new_windows = "<C-y>"
let g:terminal_do_cmd_keymap = "<C-t>"

let g:term_input_buffer_nr = {}

exe 'nmap ' . g:terminal_new_cmd .
      \ ' :call terminal#Keymap()<CR>'

exe 'nmap ' . g:terminal_new_windows .
      \ ' :call terminal#NewTerminal()<CR>'


exe 'tmap ' . g:terminal_new_windows .
      \ ' <C-w><C-c>:close!<CR>'

exe 'imap ' . g:terminal_do_cmd_keymap .
      \ ' <ESC>:call terminal#DoCmd()<CR>'

exe 'tmap ' . g:terminal_do_cmd_keymap .
      \ ' <C-w>N:call terminal#StartTimer(bufnr())<CR>a'

exe 'tmap ' . g:terminal_do_cmd_keymap .
      \ ' <C-w>N:call terminal#StartTimer(bufnr())<CR>a'


""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"                                  my stuff                                  "
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
fun! terminal#Keymap()
  if &filetype != 'ECY_terminal'
    call terminal#NewCmd()
  else
    call terminal#DoCmd()
  endif
  return ''
endf

fun! terminal#NewCmd()
  if mode() == 'i'
    call feedkeys("\<ESC>", 'i')
  endif
  execute 'new cwd:' . getcwd()
  let &filetype = 'ECY_terminal'
  call feedkeys('i', 'i') " sept into insert mode

endf

fun! terminal#InputCMD(term_buffer_nr, time_id)
  execute 'new cwd:' . getcwd() . '_' . a:term_buffer_nr
  let &filetype = 'ECY_terminal'
  call feedkeys('i', 'i') " sept into insert mode
  let g:term_input_buffer_nr[bufnr()] = a:term_buffer_nr
endf

fun! terminal#NewTerminal()
  if g:is_windows
    let g:started_term =  term_start('cmd')
  elseif g:is_macvim
    let g:started_term =  term_start('/bin/zsh')
  else
    let g:started_term =  term_start('/bin/bash')
  endif
endf

fun! terminal#FormatCMD(cmd_strings)
  "{{{
  let i = len(a:cmd_strings) - 1
  while i >= 0
    if a:cmd_strings[i] != ' '
      break
    endif
    let i -= 1
  endw
  if a:cmd_strings[:i] == ' '
    return ''
  endif
  return a:cmd_strings[:i]
  "}}}
endf

fun! s:AddNewCMD(cmd_list)
  "{{{
  let l:cmd_list = a:cmd_list

  """""""""""""""""""""
  "  shear end space  "
  """""""""""""""""""""
  let l:lens = len(a:cmd_list)
  let i = 0
  if i < l:lens
    let l:cmd_list[i] = terminal#FormatCMD(a:cmd_list[i])
    let i += 1
  endif

  let i = 0
  for item in g:terminal_last_cmd
    if item == l:cmd_list
      call remove(g:terminal_last_cmd, i)
      break
    endif
    let i += 1
  endfor

  call add(g:terminal_last_cmd, l:cmd_list)
  let g:terminal_current_cmd = a:cmd_list
  try
    doautocmd <nomodeline> EasyCompleteYou BufEnter
  catch 
  endtry
  let g:terminal_current_cmd = ''
  "}}}
endf

fun! terminal#StartTimer(term_nr)
  let timer = timer_start(1, function('terminal#InputCMD', [a:term_nr]))
endfunc

"""""""""""""""""""
"  return string  "
"""""""""""""""""""
fun! s:BuildCMD(buffer_content)
  "{{{
  let l:cmd = ''
  if len(a:buffer_content) > 1
    call writefile(a:buffer_content, s:bash_path, "b")
    let l:cmd = s:bash_path
  else
    let l:cmd = join(a:buffer_content, "\n")
  endif
  return l:cmd
  "}}}
endf

fun! terminal#EditLastCmd()
  "{{{
  let l:last = len(g:terminal_last_cmd)
  if l:last == 0
    return ''
  endif

  let l:content = g:terminal_last_cmd[l:last - 1]
  let l:lines = join(l:content, "\n")
  if mode() != 'i'
    let l:lines = 'i' . l:lines
  endif
  call feedkeys(printf('%s ', l:lines), 'i')
  return ''
  "}}}
endfunc

fun! terminal#DoCmd()
  "{{{
  if &filetype != 'ECY_terminal'
    return ''
  endif

  let l:content_list = getbufline(bufnr(),1, "$")
  if l:content_list == ['']
    return terminal#EditLastCmd()
  endif

  if mode() == 'i'
    call feedkeys("\<ESC>", 'i')
  endif

  let l:lines = join(l:content_list, "\n")
  call s:AddNewCMD(l:content_list)
  let l:cmd = s:BuildCMD(l:content_list)

  let l:current_buffer_nr = bufnr()
  execute 'q!'
  execute 'bd '. l:current_buffer_nr

  """""""""""
  "  do it  "
  """""""""""
  if has_key(g:term_input_buffer_nr, l:current_buffer_nr)
    call term_sendkeys(g:term_input_buffer_nr[l:current_buffer_nr], l:cmd . "\<CR>")
  else
    try
      execute 'terminal ' . l:cmd
    catch 
      call ECY#utility#ShowMsg("[ECY] Failed to do '" . l:lines ."'", 2)
    endtry
  endif
  return ''
  "}}}
endf
