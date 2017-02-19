let s:F = vital#tempclone#import('System.File')
let s:SEP = has('win32') || has('win64') ? '\' : '/'
let s:repos = {}

function! s:panic(msg) abort
    throw 'tempclone: FATAL: ' . a:msg
endfunction

function! s:find_open_cmd(var, default) abort
    let cmd = get(g:, a:var, a:default)
    let c = cmd
    if strlen(c) > 0 && c[0] !=# ':'
        let c = ':' . c
    endif
    if exists(c)
        return c
    endif
    echohl ErrorMsg | echomsg printf("Could not find command to open: '%s' Please set g:%s in your vimrc.", c, a:var) | echohl None
endfunction

function! s:open_repo(repo) abort
    if !isdirectory(a:repo.clone_dir)
        call s:panic('Directory not found: ' . a:repo.clone_dir)
    endif

    let open_path = a:repo.clone_dir . s:SEP . a:repo.path
    if isdirectory(open_path)
        execute s:find_open_cmd('tempclone_open_dir_cmd', 'Explore') open_path
        execute 'lcd' open_path
    elseif filereadable(open_path)
        execute s:find_open_cmd('tempclone_open_file_cmd', 'edit') open_path
        execute 'lcd' fnamemodify(open_path, ':h')
        if has_key(a:repo, 'line')
            execute a:repo.line
        endif
    else
        call s:panic('Open path does not exist: ' . open_path)
    endif

    if has_key(s:repos, a:repo.clone_url)
        return
    endif

    let should_setup_gc = empty(s:repos)
    let s:repos[a:repo.clone_url] = a:repo
    if should_setup_gc
        augroup plugin-tempclone-gc
            autocmd!
            autocmd VimLeave * call tempclone#gc()
        augroup END
    endif
endfunction

function! tempclone#get(url) abort
    let parsed = tempclone#parse_uri#parse_target(a:url)
    if parsed == {}
        return
    endif

    if has_key(s:repos, parsed.clone_url)
        call s:open_repo(s:repos[parsed.clone_url])
        return
    endif

    call tempclone#clone#start(parsed, function('s:open_repo'))
endfunction

function! tempclone#gc(...) abort
    if a:0 == 0
        for repo in values(s:repos)
            if isdirectory(repo.clone_dir)
                call s:F.rmdir(repo.clone_dir, 'r')
            endif
        endfor
        let s:repos = {}
        silent! autocmd! plugin-tempclone-gc
        return
    endif

    let target = tempclone#parse_uri#parse_target(a:1)

    for clone_url in keys(s:repos)
        if target.clone_url ==# clone_url
            let repo = s:repos[clone_url]
            if !isdirectory(repo.clone_dir)
                return
            endif
            call s:F.rmdir(repo.clone_dir, 'r')
            unlet! s:repos[repo.clone_url]
            echom 'tempclone: Removed temporary directory: ' . repo.clone_dir
            if empty(s:repos)
                silent! autocmd! plugin-tempclone-gc
            endif
            return
        endif
    endfor

    echom 'tempclone: No temporary directory to delete was found'
endfunction
