let s:URI = vital#tempclone#import('Web.URI')
let s:SEP = has('win32') || has('win64') ? '\' : '/'

function! tempclone#parse_uri#parse_target(url) abort
    if a:url =~# '\.git$'
        return {'clone_url' : a:url, 'path' : ''}
    endif

    let target_url = a:url
    if target_url !~# '^\%(http\|https\)://'
        let target_url = 'https://github.com/' . target_url
    endif
    let url = s:URI.new(target_url)
    let host = url.host()

    " TODO:
    " if host ==# 'bitbucket.org'

    return s:parse_as_github_like(url)
endfunction

function! s:parse_as_github_like(url) abort
    let path = split(a:url.path(), '/')
    if len(path) < 2
        echohl ErrorMsg | echo 'user and/or repo name not found' | echohl None
        return {}
    endif

    let user = path[0]
    let repo = path[1]

    let ret = {
        \ 'clone_url' : printf("https://%s/%s/%s.git", a:url.host(), user, repo),
        \ 'name' : repo,
        \ }

    let path = path[2:]

    if len(path) >= 2
        let kind = path[0]

        if kind ==# 'blob' || kind ==# 'tree'
            if path[1] =~# '^\x\{30,}$'
                let kind = 'commit'
            else
                let kind = 'branch'
            endif
        endif

        if kind ==# 'branch'
            let ret.branch = path[1]
            let path = path[2:]
        elseif kind ==# 'commit'
            let ret.commit = path[1]
            let path = path[2:]
        endif
    endif

    let ret.path = join(path, s:SEP)

    let match = matchlist(a:url.fragment(), '^L\(\d\+\)\%(-L\d\+\)\=$')
    if len(match) >= 2 && match[1] !=# ''
        let ret.line = str2nr(match[1])
    endif

    return ret
endfunction
