" BufferPersist.vim: Save certain buffers somewhere when quitting them.
"
" DEPENDENCIES:
"   - escapings.vim autoload script
"
" Copyright: (C) 2012 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
"
" REVISION	DATE		REMARKS
"	002	12-Jun-2012	Split off BufferPersist functionality from
"				the original MessageRecall plugin.
"	001	09-Jun-2012	file creation

function! BufferPersist#RecordBuffer( range, pendingBufferFilespec )
    try
	execute 'silent keepalt' a:range . 'write!' escapings#fnameescape(a:pendingBufferFilespec)
    catch /^Vim\%((\a\+)\)\=:E/
	" v:exception contains what is normally in v:errmsg, but with extra
	" exception source info prepended, which we cut away.
	let v:errmsg = substitute(v:exception, '^Vim\%((\a\+)\)\=:', '', '')
	echohl ErrorMsg
	echomsg v:errmsg
	echohl None
    endtry
endfunction

function! BufferPersist#OnUnload( range, pendingBufferFilespec )
    " The BufLeave event isn't invoked when :quitting Vim from the current
    " buffer. We catch this from the BufUnload event. Since it is not allowed to
    " switch buffer in there, we cannot in general use this for persisting. But
    " in this special case, we only need to persist when inside the
    " to-be-unloaded buffer.
    if expand('<abuf>') == bufnr('')
	call BufferPersist#RecordBuffer(a:range, a:pendingBufferFilespec)
    endif
endfunction

function! BufferPersist#PersistBuffer( pendingBufferFilespec, BufferStoreFuncref )
    let l:bufferFilespec = call(a:BufferStoreFuncref, [])
"****D echomsg '**** rename' string(a:pendingBufferFilespec) string(l:bufferFilespec)
    if rename(a:pendingBufferFilespec, l:bufferFilespec) == 0
	unlet! s:pendingBufferFilespecs[a:pendingBufferFilespec]
    else
	let v:errmsg = 'BufferPersist: Failed to persist buffer to ' . l:bufferFilespec
	echohl ErrorMsg
	echomsg v:errmsg
	echohl None
    endif
endfunction

function! BufferPersist#OnLeave( BufferStoreFuncref )
    for l:filespec in keys(s:pendingBufferFilespecs)
	call BufferPersist#PersistBuffer(l:filespec, a:BufferStoreFuncref)
    endfor
endfunction

let s:pendingBufferFilespecs = {}
function! BufferPersist#Setup( BufferStoreFuncref, range )
    let l:pendingBufferFilespec = tempname()
    let s:pendingBufferFilespecs[l:pendingBufferFilespec] = 1

    augroup BufferPersist
	autocmd! * <buffer>
	execute printf('autocmd BufLeave <buffer> call BufferPersist#RecordBuffer(%s, %s)', string(a:range), string(l:pendingBufferFilespec))
	execute printf('autocmd BufUnload <buffer> call BufferPersist#OnUnload(%s, %s)', string(a:range), string(l:pendingBufferFilespec))
	execute printf('autocmd BufDelete <buffer> call BufferPersist#PersistBuffer(%s, %s)', string(l:pendingBufferFilespec), string(a:BufferStoreFuncref))
	execute printf('autocmd VimLeavePre * call BufferPersist#OnLeave(%s)', string(a:BufferStoreFuncref))
    augroup END
endfunction

" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
