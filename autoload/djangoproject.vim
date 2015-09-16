function! djangoproject#init()
    let g:djangoproject#directory = s:normpath(fnamemodify(g:djangoproject#directory, ':p'))

    if !isdirectory(g:djangoproject#directory)
        call s:Error(string(g:djangoproject#directory).' is not a directory')
        return 1
    endif

    if exists('g:djangoproject#force_python_version') &&
     \ (index([2,3], g:djangoproject#force_python_version) == -1)
        call s:Error('invalid value for g:djangoproject#force_python_version: '.
                     \string(g:djangoproject#force_python_version))
        return 1
    endif

    let s:state = {}
endfunction

function! djangoproject#activate(...)
    if (a:0)
        let l:name = s:normpath(a:1)
        if empty(l:name)
            call s:Error('empty project name')
            return 1
        endif

        let l:cached = djangoproject#completion#get(l:name)
        if !empty(l:cached)
            return djangoproject#deactivate() || djangoproject#force_activate(l:cached)
        endif

        let l:djangoproject_path = [g:djangoproject#directory, getcwd(), '/']
        for l:directory in l:djangoproject_path
            let l:projects = djangoproject#find(l:directory, l:name)
            if !empty(l:projects)
                let [l:target; l:rest] = l:projects
                let l:target = s:normpath(l:target)
                if !empty(l:rest)
                    call s:Warning('multiple projects under the name '.
                                   \l:name.' were found in '.l:directory)
                    call s:Warning('processing '.l:target)
                elseif (l:directory ==# g:djangoproject#directory) && (l:name !~# '/')
                    call djangoproject#completion#refresh()
                endif
                return djangoproject#deactivate() || djangoproject#force_activate(l:target)
            endif
        endfor

        call s:Warning('project '.l:name.' was not found in '.string(l:djangoproject_path))
        return 1
    else
        let l:current_file_directory = expand('%:p:h')
        let l:target = djangoproject#origin(l:current_file_directory)

        if !empty(l:target)
            if has_key(s:state, 'djangoproject_directory') &&
             \ (l:target ==# s:state['djangoproject_directory'])
                call s:Warning('project '.l:target.' is already active')
                return
            else
                if empty($DJANGO_SETTINGS_MODULE) ||
                 \ (has_key(s:state, 'djangoproject_settings') &&
                 \  ($DJANGO_SETTINGS_MODULE ==# s:state['djangoproject_settings']))
                    " if either $DJANGO_SETTINGS_MODULE is not set, or it is set
                    " and equals to the value of s:state['djangoproject_settings'],
                    " then deactivate the current project first
                    return djangoproject#deactivate() || djangoproject#force_activate(l:target)
                else
                    " otherwise it is an externally activated project
                    return djangoproject#force_activate(l:target, $DJANGO_SETTINGS_MODULE)
                endif
            endif
        else
            call s:Warning('project of the current file was not found')
            return
        endif
    endif
endfunction

function! djangoproject#force_activate(target, ...)
    if !s:isproject(a:target)
        call s:Error(a:target.' is not a valid project')
        return 1
    endif

    let s:state['djangoproject_directory'] = a:target
    let s:state['djangoproject_return_dir'] = getcwd()
    let s:state['djangoproject_name'] = fnamemodify(a:target, ':t')
    let s:state['djangoproject_settings'] =
        \ !(a:0) ? s:state['djangoproject_name'].'.settings' : a:1

    if g:djangoproject#virtualenv_support
        let l:virtualenv = virtualenv#origin(s:state['djangoproject_directory'])
        if !empty(l:virtualenv)
            call virtualenv#activate(l:virtualenv)
        endif
    endif

    let l:pyversion = djangoproject#supported(a:target)
    if !(l:pyversion)
        call s:Error(a:target.' is not supported')
        return 1
    endif
    let s:state['python_version'] = l:pyversion

    try
        call s:execute_python_command(
            \ 'DjangoProjectPlugin.activate',
            \ s:state['djangoproject_directory'],
            \ s:state['djangoproject_settings'],
            \ g:djangoproject#update_pythonpath,
            \ g:djangoproject#import_settings)
    catch
        unlet! s:state['djangoproject_settings']
        unlet! s:state['djangoproject_name']
        unlet! s:state['djangoproject_return_dir']
        unlet! s:state['djangoproject_directory']
        unlet! s:state['python_version']

        call s:Error(v:throwpoint)
        call s:Error(v:exception)

        return 1
    endtry

    command! -nargs=0 -bar DjangoProjectCD call djangoproject#cdproject()

    if g:djangoproject#cdproject_on_activate &&
     \ !s:issubdir(s:state['djangoproject_return_dir'], s:state['djangoproject_directory'])
        call djangoproject#cdproject()
    endif
endfunction

function! djangoproject#deactivate()
    if !has_key(s:state, 'djangoproject_name')
        call s:Warning('deactivation is not possible')
        return
    endif
    return djangoproject#force_deactivate()
endfunction

function! djangoproject#force_deactivate()
    if g:djangoproject#return_on_deactivate && has_key(s:state, 'djangoproject_return_dir')
        execute 'cd' fnameescape(s:state['djangoproject_return_dir'])
    endif

    delcommand DjangoProjectCD

    try
        call s:execute_python_command('DjangoProjectPlugin.deactivate()')
    catch
        return 1
    endtry

    unlet! s:state['djangoproject_settings']
    unlet! s:state['djangoproject_name']
    unlet! s:state['djangoproject_return_dir']
    unlet! s:state['djangoproject_directory']
    unlet! s:state['python_version']

    if g:djangoproject#virtualenv_support
        call virtualenv#deactivate()
    endif
endfunction

function! djangoproject#cdproject()
    if has_key(s:state, 'djangoproject_directory')
        execute 'cd' fnameescape(s:state['djangoproject_directory'])
    endif
endfunction

function! djangoproject#list(...)
    let l:directory = !(a:0) ? g:djangoproject#directory : a:1
    for l:project in djangoproject#find(l:directory)
        echo l:project
    endfor
endfunction

function! djangoproject#statusline()
    return has_key(s:state, 'djangoproject_name') ?
         \ substitute(g:djangoproject#statusline_format, '\C%n', s:state['djangoproject_name'], 'g') :
         \ ''
endfunction

" helper functions
function! djangoproject#find(directory, ...)
    let l:projects = []
    let l:pattern = (a:0) ? a:1 : g:djangoproject#discover_pattern
    let l:tail = matchstr(l:pattern, '[/]\+$')
    for [l:suffix, l:modifier] in [['settings.py', ':h'],
                                  \['settings/__init__.py', ':h:h']]
        let l:pattern_ = s:joinpath(l:pattern, l:suffix)
        for l:target in globpath(a:directory, l:pattern_, 0, 1)
            call add(l:projects, fnamemodify(l:target, l:modifier).l:tail)
        endfor
    endfor
    return l:projects
endfunction

function! djangoproject#supported(target)
    if !exists('g:djangoproject#force_python_version')
        let [l:python_major_version] =
            \ s:execute_system_python_command(
            \     'import sys; print(sys.version_info[0])')
    else
        let l:python_major_version = g:djangoproject#force_python_version
        call s:Warning('Python version for '.a:target.' is set to '.
                       \g:djangoproject#force_python_version)
    endif
    if !s:python_available(l:python_major_version)
        call s:Error(a:target.' requires python'.l:python_major_version)
        return
    endif
    return l:python_major_version
endfunction

function! djangoproject#origin(path)
    if s:issubdir(a:path, g:djangoproject#directory)
        let l:target = g:djangoproject#directory
        let l:tail = substitute(a:path, '^'.g:djangoproject#directory.'/', '', '')
    else
        let l:target = '/'
        let l:tail = fnamemodify(a:path, ':p')
    endif
    for l:part in split(l:tail, '/')
        let l:target = s:joinpath(l:target, l:part)
        if s:isproject(l:target)
            return l:target
        endif
    endfor
    return ''
endfunction

function! djangoproject#state(...)
    function! s:Query(key)
        echo a:key.' = '.get(s:state, a:key, '__undefined__')
    endfunction

    if (a:0)
        call s:Query(a:1)
    else
        for l:key in keys(s:state)
            call s:Query(l:key)
        endfor
    endif
endfunction

" misc functions
function! s:isproject(target)
    return isdirectory(a:target) &&
         \ (filereadable(s:joinpath(a:target, 'settings.py')) ||
         \  filereadable(s:joinpath(a:target, 'settings/__init__.py')))
endfunction

" debug functions
function! s:Error(message)
    echohl ErrorMsg | echo 'vim-djangoproject: '.a:message | echohl None
endfunction

function! s:Warning(message)
    if g:djangoproject#debug
        echohl WarningMsg | echo 'vim-djangoproject: '.a:message | echohl None
    endif
endfunction

" paths machinery
function! s:issubdir(subdirectory, directory)
    let l:directory = s:normpath(a:subdirectory)
    let l:pattern = '^'.s:normpath(a:directory).'/'
    return (l:directory =~# fnameescape(l:pattern))
endfunction

function! s:joinpath(first, last)
    if (a:first !~# '^$')
        let l:prefix = substitute(a:first, '[/]\+$', '', '')
        let l:suffix = substitute(a:last, '^[/]\+', '', '')
        return l:prefix.'/'.l:suffix
    else
        return a:last
    endif
endfunction

function! s:normpath(path)
    let l:path = a:path
    if !empty(l:path)
        if (l:path =~# '^\~')
            let l:user = matchstr(l:path, '^\~[^/]*')
            let l:home_directory = fnamemodify(l:user, ':p:h')
            let l:path = substitute(l:path, '^\'.l:user, l:home_directory, '')
        endif
        let l:path = simplify(l:path)
        let l:path = substitute(l:path, '^[/]\+', '/', '')
        let l:path = substitute(l:path, '[/]\+$', '', '')
        return l:path
    else
        return ''
    endif
endfunction

" python machinery
function! s:python_available(version)
    if !has_key(s:state, 'python'.a:version.'_available')
        try
            let l:command = (a:version != 3) ? 'pyfile' : 'py3file'
            execute l:command fnameescape(g:djangoproject#python_script)
            execute 'let s:state[''python'.a:version.'_available''] = 1'
        catch
            execute 'let s:state[''python'.a:version.'_available''] = 0'
        endtry
    endif
    execute 'return s:state[''python'.a:version.'_available'']'
endfunction

function! s:execute_system_python_command(command)
    return systemlist('python -c '.string(a:command))
endfunction

function! s:execute_python_command(command, ...)
    let l:interpreter = (s:state['python_version'] != 3) ? 'python' : 'python3'
    let l:command = a:command.((a:0) ? s:construct_arguments(a:0, a:000) : '')
    redir => l:output
        silent execute l:interpreter l:command
    redir END
    return split(l:output, '\n')
endfunction

function! s:construct_arguments(number, list)
    let l:arguments = '('
    if (a:number)
        let l:first_arguments = (a:number > 1) ? a:list[:(a:number - 2)] : []
        for l:argument in l:first_arguments
            let l:arguments .= s:process_argument(l:argument).', '
        endfor
        let l:last_argument = a:list[(a:number - 1)]
        if (type(l:last_argument) != type({}))
            let l:arguments .= s:process_argument(l:last_argument)
        else
            for [l:key, l:value] in items(l:last_argument)
                let l:arguments .= l:key.'='.s:process_argument(l:value).', '
            endfor
        endif
    endif
    let l:arguments .= ')'
    return l:arguments
endfunction

function! s:process_argument(argument)
    if (type(a:argument) == type(0)) || (type(a:argument) == type(0.0))
        return a:argument
    elseif (type(a:argument) == type(''))
        return '"""'.a:argument.'"""'
    else
        return string(a:argument)
    endif
endfunction

call djangoproject#init()
