if exists('g:loaded_djangoproject')
    finish
endif

if !exists('g:djangoproject#force_python_version')
    if !(has('python') || has('python3'))
        echoerr 'vim-djangoproject requires python or python3 feature to be enabled'
        finish
    endif
else
    let s:python = 'python'.((g:djangoproject#force_python_version != 3) ? '' : '3')
    if !has(s:python)
        echoerr 'vim-djangoproject requires the '.s:python.' feature to be enabled'
        finish
    endif
endif

let g:loaded_djangoproject = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

let g:djangoproject#directory =
    \ get(g:, 'djangoproject#directory', $HOME)
let g:djangoproject#discover_pattern =
    \ get(g:, 'djangoproject#discover_pattern', '*')
let g:djangoproject#auto_activate =
    \ get(g:, 'djangoproject#auto_activate', 1)
let g:djangoproject#auto_activate_everywhere =
    \ get(g:, 'djangoproject#auto_activate_everywhere', 0)
let g:djangoproject#update_pythonpath =
    \ get(g:, 'djangoproject#update_pythonpath', 1)
let g:djangoproject#import_settings =
    \ get(g:, 'djangoproject#import_settings', 1)
let g:djangoproject#cdproject_on_activate =
    \ get(g:, 'djangoproject#cdproject_on_activate', 1)
let g:djangoproject#return_on_deactivate =
    \ get(g:, 'djangoproject#return_on_deactivate', 1)
let g:djangoproject#virtualenv_support =
    \ get(g:, 'djangoproject#virtualenv_support', 0)
let g:djangoproject#statusline_format =
    \ get(g:, 'djangoproject#statusline_format', '%n')
let g:djangoproject#debug =
    \ get(g:, 'djangoproject#debug', 0)
let g:djangoproject#python_script =
    \ get(g:, 'djangoproject#python_script',
    \     expand('<sfile>:p:h:h').'/autoload/djangoproject/djangoproject.py')

augroup DjangoProjectAutoActivate
if g:djangoproject#auto_activate
    execute 'autocmd! BufFilePost,BufNewFile,BufRead '.
            \g:djangoproject#directory.'/* call djangoproject#activate()'
elseif g:djangoproject#auto_activate_everywhere
    autocmd! BufFilePost,BufNewFile,BufRead * call djangoproject#activate()
endif
augroup END

command! -nargs=? -bar -complete=dir DjangoProjectList
    \ call djangoproject#list(<f-args>)
command! -nargs=? -bar -complete=customlist,djangoproject#completion#do DjangoProjectActivate
    \ call djangoproject#activate(<f-args>)
command! -nargs=0 -bar DjangoProjectDeactivate
    \ call djangoproject#deactivate()

let &cpoptions = s:save_cpo
unlet s:save_cpo
