let s:SEP = has('win32') || has('win64') ? '\' : '/'

function! s:git_cmd(repo) abort
    let cmd = [get(g:, 'tempclone_git_cmd', 'git'), 'clone', a:repo.clone_url]
    if !has_key(a:repo, 'commit')
        let cmd += ['--depth', '1']
    endif
    let cmd += ['--single-branch']
    if has_key(a:repo, 'branch')
        let cmd += ['-b', a:repo.branch]
    endif
    let cmd += [a:repo.clone_dir]
    return join(cmd, ' ')
endfunction

function! s:cloning_message(repo) abort
    let msg = printf("Cloning %s into %s...", a:repo.clone_url, a:repo.clone_dir)
    if has_key(a:repo, 'commit')
        let msg .= printf(" (sha1: %s)", a:repo.commit)
    endif
    if has_key(a:repo, 'branch')
        let msg .= printf(" (branch: %s)", a:repo.branch)
    endif
    return msg
endfunction

function! s:clone_vim8(cmd, repo, callback) abort
    let cb = {
        \   'repo' : a:repo,
        \   'callback' : a:callback,
        \   'cmd' : a:cmd,
        \ }

    function! cb.closed(ch) dict abort
        " Call exit_cb to populate self.exit_status
        call job_status(self.job)

        if self.exit_status != 0
            return
        endif

        call call(self.callback, [self.repo])
    endfunction

    function! cb.exited(ch, status) dict abort
        if has_key(self, 'exit_status')
            return
        endif
        let self.exit_status = a:status
        if a:status == 0
            return
        endif
        let err = ''
        while ch_status(a:ch, {'part' : 'err'}) ==# 'buffered'
            let err .= ch_read(a:ch, {'part' : 'err'})
        endwhile
        let msg = printf("Command failed with exit status %d: %s", a:status, self.cmd)
        if err !=# ''
            let msg .= ': ' . err
        endif
        echohl ErrorMsg | echomsg msg | echohl None
    endfunction

    let cb.job = job_start(a:cmd, { 'close_cb' : cb.closed, 'exit_cb' : cb.exited, 'out_io' : 'null'})
endfunction

function! s:clone_nvim(cmd, repo, callback) abort
    " TODO
    call s:clone_fallback(a:cmd, a:repo, a:callback)
endfunction

function! s:clone_fallback(cmd, repo, callback) abort
    let out = system(a:cmd)
    if v:shell_error
        echohl ErrorMsg | echomsg printf("Command failed: %s: %s", a:cmd, out)
        return
    endif
    call call(a:callback, a:repo)
endfunction

function! tempclone#clone#start(repo, callback) abort
    let tmp_dir = fnamemodify(get(g:, 'tempclone_temp_dir', tempname()), ':p')
    if !isdirectory(tmp_dir)
        call mkdir(tmp_dir, 'p')
    endif
    let a:repo.clone_dir = tmp_dir . s:SEP . a:repo.name
    echo s:cloning_message(a:repo)
    let cmd = s:git_cmd(a:repo)
    if has('job')
        call s:clone_vim8(cmd, a:repo, a:callback)
        return
    endif
    if has('nvim')
        call s:clone_nvim(cmd, a:repo, a:callback)
        return
    endif
    call s:clone_fallback(cmd, a:repo, a:callback)
endfunction
