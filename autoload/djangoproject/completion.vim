function! djangoproject#completion#init()
    let s:cache = {}
    let l:projects = djangoproject#find(g:djangoproject#directory)
    for l:project in l:projects
        let l:relpath = substitute(l:project, '^'.g:djangoproject#directory.'/', '', '')
        let s:cache[l:relpath] = l:project
    endfor
endfunction

function! djangoproject#completion#refresh()
    unlet! s:cache
    return djangoproject#completion#init()
endfunction

function! djangoproject#completion#match(pattern)
    if !exists('s:cache')
        call djangoproject#completion#init()
    endif
    let l:matched = []
    for l:project in keys(s:cache)
        if (l:project =~# a:pattern)
            call add(l:matched, l:project)
        endif
    endfor
    return l:matched
endfunction

function! djangoproject#completion#get(project)
    if !exists('s:cache')
        call djangoproject#completion#init()
    endif
    return has_key(s:cache, a:project) ? s:cache[a:project] : ''
endfunction

function! djangoproject#completion#do(arglead, ...)
    let l:arglead = fnameescape(a:arglead)

    if (l:arglead !~# '/')
        " not a path was specified
        let l:pattern = l:arglead.'*'
        let l:directory = getcwd()
        " first search in the completion cache
        " clean project pattern
        let l:project = escape(l:arglead, '~')
        " match either project name, or tail of project path
        let l:projects =
            \ djangoproject#completion#match('^'.l:project.'[^/]*$') +
            \ s:relpathlist(djangoproject#completion#match('/'.l:project.'[^/]*$'),
            \               g:djangoproject#directory)
        " then search inside the current directory
        if (g:djangoproject#directory !=# l:directory)
            call s:appendcwdlist(l:projects, s:relprojectlist(l:directory, l:pattern))
        endif

        if !empty(l:projects)
            return s:fnameescapelist(l:projects)
        else
            " if no projects were found, then return a list of directories
            if (l:arglead !~# '^\~')
                let l:pattern .= '/'
                let l:globs = s:relgloblist(g:djangoproject#directory, l:pattern)
                if (g:djangoproject#directory !=# l:directory)
                    call s:appendcwdlist(l:globs, s:relgloblist(l:directory, l:pattern))
                endif
                return s:fnameescapelist(l:globs)
            else
                return [fnamemodify(l:arglead, ':p')]
            endif
        endif
    else
        " a path was specified
        if (l:arglead =~# '^[\.\~/]')
            " a path can be unambiguously expanded
            let l:pattern = fnamemodify(l:arglead, ':t').'*'
            let l:directory = fnamemodify(l:arglead, ':h')
            let l:projects = djangoproject#find(l:directory, l:pattern)
        else
            " a path without an unambiguous prefix was specified
            let l:pattern = l:arglead.'*'
            let l:directory = getcwd()
            " first search inside g:djangoproject#directory
            let l:projects = s:relprojectlist(g:djangoproject#directory, l:pattern)
            " then search inside the current directory
            if (g:djangoproject#directory !=# l:directory)
                call s:appendcwdlist(l:projects, s:relprojectlist(l:directory, l:pattern))
            endif
        endif

        if !empty(l:projects)
            return s:fnameescapelist(l:projects)
        else
            " if no projects were found, then return a list of directories
            let l:pattern .= '/'
            if (l:arglead =~# '^[\.\~/]')
                return s:fnameescapelist(globpath(l:directory, l:pattern, 0, 1))
            else
                let l:globs = s:relgloblist(g:djangoproject#directory, l:pattern)
                if (g:djangoproject#directory !=# l:directory)
                    call s:appendcwdlist(l:globs, s:relgloblist(l:directory, l:pattern))
                endif
                return s:fnameescapelist(l:globs)
            endif
        endif
    endif
endfunction

function! s:fnameescapelist(list)
    return map(a:list, 'fnameescape(v:val)')
endfunction

function! s:relpathlist(list, directory)
    return map(a:list, 'substitute(v:val, ''^'.a:directory.'/'', '''', '''')')
endfunction

function! s:relgloblist(directory, pattern)
    return s:relpathlist(globpath(a:directory, a:pattern, 0, 1), a:directory)
endfunction

function! s:relprojectlist(directory, pattern)
    return s:relpathlist(djangoproject#find(a:directory, a:pattern), a:directory)
endfunction

function! s:appendcwdlist(list, cwdlist)
    for l:entry in a:cwdlist
        if (index(a:list, l:entry) == -1)
            call add(a:list, l:entry)
        else
            call add(a:list, './'.l:entry)
        endif
    endfor
endfunction
