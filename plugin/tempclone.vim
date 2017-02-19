if (exists('g:loaded_tempclone') && g:loaded_tempclone) || &cp
    finish
endif

command! -nargs=1 -bar Tempclone call tempclone#get_and_open(<q-args>)
command! -nargs=? -bar -bang TempcloneGC call tempclone#gc(<bang>0, <f-args>)

let g:loaded_tempclone = 1
