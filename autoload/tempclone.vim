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
    throw printf("Could not find command to open: '%s' Please set g:%s in your vimrc.", c, a:var)
endfunction

function! tempclone#open(repo) abort
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

    let should_setup_gc = empty(s:repos) && !get(g:, 'tempclone_permanent_temp_dir', 0)
    let s:repos[a:repo.clone_url] = a:repo
    if should_setup_gc
        augroup plugin-tempclone-gc
            autocmd!
            autocmd VimLeave * call tempclone#gc()
        augroup END
    endif
endfunction

function! tempclone#get_and_open(url) abort
    let parsed = tempclone#parse_uri#parse_target(a:url)
    if parsed == {}
        return
    endif

    if has_key(s:repos, parsed.clone_url)
        call tempclone#open(s:repos[parsed.clone_url])
        return
    endif

    call tempclone#clone#start(parsed, function('tempclone#open'))
endfunction

function! s:remove_repo(repo) abort
    unlet! s:repos[repo.clone_url]
    if empty(s:repos)
        silent! autocmd! plugin-tempclone-gc
    endif
    if !isdirectory(repo.clone_dir)
        return
    endif
    call s:F.rmdir(repo.clone_dir, 'r')
    echom 'tempclone: Removed temporary directory: ' . repo.clone_dir
endfunction

function! tempclone#gc(all, ...) abort
    if a:all
        for repo in values(s:repos)
            call s:remove_repo(repo)
        endfor
        return
    endif

    if a:0 == 0
        let current = expand('%:p')
        for repo in values(s:repos)
            if stridx(current, repo.clone_dir) == 0
                call s:remove_repo(repo)
                return
            endif
        endfor
        echom 'tempclone: No temporary directory for current buffer was found'
        return
    endif

    let target = tempclone#parse_uri#parse_target(a:1)

    for clone_url in keys(s:repos)
        if target.clone_url ==# clone_url
            let repo = s:repos[clone_url]
            call s:remove_repo(repo)
            return
        endif
    endfor

    echom 'tempclone: No temporary directory to delete was found'
endfunction
