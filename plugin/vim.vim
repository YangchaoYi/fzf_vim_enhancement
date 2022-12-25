function! s:delete_buffers(lines)
  let blist = map(a:lines, 'matchstr(v:val, "\\[\\zs[0-9]*\\ze\\]")')
  if len(blist) == 0
    return
  endif
  execute 'bwipeout!' join(blist)
endfunction

function! s:action_for(key, ...)
  let default = a:0 ? a:1 : ''
  let Cmd = get(get(g:, 'fzf_action', {}), a:key, default)
  return type(Cmd) == s:TYPE.string ? Cmd : default
endfunction

function! s:buffer_ops(lines)
  let b = matchstr(a:lines[1], '\[\zs[0-9]*\ze\]')
  let cmd = s:action_for(a:lines[0])
  let blist = map(a:lines[1:], 'matchstr(v:val, "\\[\\zs[0-9]*\\ze\\]")')
  if !empty(cmd)
    execute 'silent' cmd join(blist)
  else
    execute 'buffer' b
  endif
endfunction

command! -bang -nargs=* Rg call fzf#vim#grep(
      \ "rg --column --line-number --no-heading --color=always --smart-case --pcre2 --multiline ".shellescape(<q-args>), 
      \ 1,
      \ s:p(<bang>0, {'options': ["--keep-right", "--multi", "--bind=ctrl-f:page-down,ctrl-b:page-up,ctrl-h:toggle", "--delimiter", ":", '--nth', '4..']}),
      \ <bang>0)

function! FilesContainWords(args, bang)
  " Print the arguments passed to the command
  let word_list = split(a:args, ' ')
  let query = '^(?<!\n)'
  for word in word_list
    let query = query. '(?=[\s\S]*' .word.')'
  endfor
  let query = query.'[\s\S]*$(?!\n)'
  " echom query
  call fzf#vim#grep("rg --column --line-number --no-heading --color=always --smart-case --pcre2 --multiline ".shellescape(query), 1,
      \   fzf#vim#with_preview({'options': '--delimiter : --nth 4..'}), a:bang)
endfunction

command! -nargs=+ Contains call FilesContainWords(<q-args>, <bang>0)

function! RipgrepFzf(query, fullscreen)
  let command_fmt = 'rg --column --line-number --no-heading --color=always --smart-case --pcre2 --multiline -- %s || true'
  let initial_command = printf(command_fmt, shellescape(a:query))
  let reload_command = printf(command_fmt, '{q}')
  let spec = {'options': ['--phony', '--query', a:query, '--bind', 'change:reload:'.reload_command]}
  call fzf#vim#grep(initial_command, 1, fzf#vim#with_preview(spec), a:fullscreen)
endfunction

command! -nargs=* -bang Regex call RipgrepFzf(<q-args>, <bang>0)

command! -bang -nargs=? -complete=dir Files call fzf#vim#files(
      \ <q-args>,
      \ s:p(<bang>0, {'options': ["--keep-right", "--multi", "--bind=ctrl-f:page-down,ctrl-b:page-up,ctrl-h:toggle"]}),
      \ <bang>0
      \)

function! s:history(arg, extra, bang)
  let bang = a:bang || a:arg[len(a:arg)-1] == '!'
  if a:arg[0] == ':'
    call fzf#vim#command_history(bang)
  elseif a:arg[0] == '/'
    call fzf#vim#search_history(bang)
  else
    call fzf#vim#history(a:extra, bang)
  endif
endfunction

function! s:p(bang, ...)
  " get preview_window settings: where to open preview window, e.g. 'up',
  " 'right'...
  let preview_window = get(g:, 'fzf_preview_window', a:bang && &columns >= 80 || &columns >= 120 ? 'right': '')
  if len(preview_window)
    return call('fzf#vim#with_preview', add(copy(a:000), preview_window))
  endif
  return {}
endfunction

command! -bang -nargs=* History call s:history(
      \ <q-args>,
      \ s:p(<bang>0, {'options': ['--multi', '--keep-right', '--bind=ctrl-f:page-down,ctrl-b:page-up,ctrl-h:toggle']}),
      \ <bang>0
      \ )

command! -bar -bang -nargs=? -complete=buffer Buffers  call fzf#vim#buffers(
      \ <q-args>,
      \ s:p(<bang>0,
      \ { "placeholder": "{1}", "options": ["-d", "\t", "--keep-right", "--bind=ctrl-f:page-down,ctrl-b:page-up"]}),
      \ <bang>0
      \ )

let s:TYPE = {'dict': type({}), 'funcref': type(function('call')), 'string': type(''), 'list': type([])}
function! s:wrap(name, opts, bang)
  " fzf#wrap does not append --expect if sink or sink* is found
  let opts = copy(a:opts)
  let options = ''
  if has_key(opts, 'options')
    let options = type(opts.options) == s:TYPE.list ? join(opts.options) : opts.options
  endif
  if options !~ '--expect' && has_key(opts, 'sink*')
    let Sink = remove(opts, 'sink*')
    let wrapped = fzf#wrap(a:name, opts, a:bang)
    let wrapped['sink*'] = Sink
  else
    let wrapped = fzf#wrap(a:name, opts, a:bang)
  endif
  return wrapped
endfunction

" function! s:buffers(...)
"   let [query, args] = (a:0 && type(a:1) == type('')) ?
"         \ [a:1, a:000[1:]] : ['', a:000]
"   let sorted = fzf#vim#_buflisted_sorted()
"   let header_lines = '--header-lines=' . (bufnr('') == get(sorted, 0, 0) ? 1 : 0)
"   let tabstop = len(max(sorted)) >= 4 ? 9 : 8
"   return fzf#run(s:wrap('buffers', extend({
"       \ 'source': map(fzf#vim#_buflisted_sorted(), 'fzf#vim#_format_buffer(v:val)'),
"       \ 'sink*': { lines -> s:buffer_ops(lines) }},
"       \ s:p(0, {"placeholder": "{1}", 'options': ['+m', '-x', '--tiebreak=index', header_lines, '--preview-window', '+{2}-/2', "--multi", "--keep-right", "--bind=ctrl-f:page-down,ctrl-b:page-up,ctrl-h:toggle", '--ansi', '-d', '\t', '--with-nth', '3..', '-n', '2,1..2', '--prompt', 'Buf> ', '--query', query, '--tabstop', tabstop]}),
"       \ ), 0))
" endfunction

" command! -bar -bang -nargs=? -complete=buffer BufferOps  call s:buffers(
"       \ <q-args>,
"       \ {},
"       \ <bang>0
"       \ )

command! -bar -bang -nargs=? -complete=buffer BufferOps call fzf#run(s:wrap('buffers', extend({
      \ 'source': map(fzf#vim#_buflisted_sorted(), 'fzf#vim#_format_buffer(v:val)'),
      \ 'sink*': { lines -> s:buffer_ops(lines) }},
      \ s:p(<bang>0, {"placeholder": "{1}", 'options': ['--preview-window', '+{2}-/2', "--multi", "--keep-right", "--bind=ctrl-f:page-down,ctrl-b:page-up,ctrl-h:toggle", '--ansi', '-d', '\t', '--with-nth', '3..', '-n', '2,1..2', '--prompt', 'Buf> ']}),
      \), 0))

command! -bar -bang -nargs=? -complete=buffer Lines  call fzf#vim#lines(
      \ <q-args>,
      \ <bang>0
      \ )

command! BD call fzf#run(fzf#wrap(extend({
      \ 'source': map(fzf#vim#_buflisted_sorted(), 'fzf#vim#_format_buffer(v:val)'),
      \ 'sink*': { lines -> s:delete_buffers(lines) }},
      \ s:p(<bang>0, {"placeholder": "{1}", 'options': ['--preview-window', '+{2}-/2', "--multi", "--keep-right", "--bind=ctrl-f:page-down,ctrl-b:page-up,ctrl-h:toggle", '--ansi', '-d', '\t', '--with-nth', '2..', '-n', '2,1..2', '--prompt', 'BufDel> ']}),
      \)))

command! -bar -bang Marks call fzf#vim#marks({
      \'options': [
        \   '--bind=ctrl-f:page-down,ctrl-b:page-up,ctrl-h:toggle',
        \   '--preview-window', 'up', '--keep-right',
        \   '--preview', 'original={4}; file_path="$(readlink -f ${original})"; lines=$((${LINES} / 2)) ; cat -n "${file_path}" |   egrep --color=always -C "${lines}" ^[[:space:]]*{2}[[:space:]]']
        \ })
