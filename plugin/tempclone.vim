if (exists('g:loaded_tempclone') && g:loaded_tempclone) || &cp
    finish
endif

command! -nargs=1 Tempclone call tempclone#get_and_open(<q-args>)
command! -nargs=? TempcloneGC call tempclone#gc(<f-args>)

let g:loaded_tempclone = 1
