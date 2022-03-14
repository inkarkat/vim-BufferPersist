" BufferPersist.vim: Save certain buffers somewhere when quitting them.
"
" DEPENDENCIES:
"   - ingo-library.vim plugin
"
" Copyright: (C) 2012-2022 Ingo Karkat
"   The VIM LICENSE applies to this script; see ':help copyright'.
"
" Maintainer:	Ingo Karkat <ingo@karkat.de>
let s:save_cpo = &cpo
set cpo&vim

function! s:IsBufferEmpty( range )
    return (empty(a:range) || a:range ==# '%' ?
    \   ingo#buffer#IsEmpty() :
    \   (ingo#range#Get(a:range) =~# '^\n*$')
    \)
endfunction

function! s:CheckBuffer( range, whenRangeNoMatch ) abort
    let l:range = a:range
    try
	let l:isBufferEmpty = s:IsBufferEmpty(l:range)
    catch /^Vim\%((\a\+)\)\=:/
	if a:whenRangeNoMatch ==# 'error'
	    throw 'BufferPersist: Failed to capture buffer: ' . ingo#msg#MsgFromVimException()
	elseif a:whenRangeNoMatch ==# 'ignore'
	    " This will remove any existing a:pendingBufferFilespec below and
	    " not persist the current buffer.
	    let l:isBufferEmpty = 1
	elseif a:whenRangeNoMatch ==# 'all'
	    " Persist the entire buffer instead.
	    let l:range = ''
	    " Unless the entire buffer is empty, too.
	    let l:isBufferEmpty = s:IsBufferEmpty(l:range)
	else
	    throw 'ASSERT: Invalid value for a:whenRangeNoMatch: ' . string(a:whenRangeNoMatch)
	endif
    endtry
    return [l:range, l:isBufferEmpty]
endfunction

function! BufferPersist#WriteBuffer( BufferStoreFuncref, range, passedRange, whenRangeNoMatch ) abort
    try
	" The a:passedRange from the custom command overrides the default range.
	let [l:range, l:isBufferEmpty] = s:CheckBuffer((empty(a:passedRange) ? a:range : a:passedRange), a:whenRangeNoMatch)

	if l:isBufferEmpty
	    call ingo#err#Set('BufferPersist: No contents to write')
	    return 0
	endif

	let l:bufferFilespec = call(a:BufferStoreFuncref, [bufnr('')])
	execute 'silent keepalt' ingo#compat#commands#keeppatterns() l:range . 'write!' ingo#compat#fnameescape(l:bufferFilespec)

	if empty(a:passedRange)
	    " Do not persist the buffer contents again after editing is done
	    " unless there have been further changes.
	    let b:BufferPersist_WriteTick = b:changedtick
	endif

	return 1
    catch /^Vim\%((\a\+)\)\=:/
	call ingo#err#Set(printf('BufferPersist: Failed to write buffer to %s: %s', l:bufferFilespec, ingo#msg#MsgFromVimException()))
	return 0
    catch /^BufferPersist:/
	call ingo#err#Set(v:exception)
	return 0
    endtry
endfunction

function! BufferPersist#RecordBuffer( range, whenRangeNoMatch, pendingBufferFilespec )
    try
	let [l:range, l:isBufferEmpty] = s:CheckBuffer(a:range, a:whenRangeNoMatch)

	if l:isBufferEmpty || (exists('b:BufferPersist_WriteTick') && b:BufferPersist_WriteTick == b:changedtick)
	    " Do not record effectively empty buffer contents; this would just
	    " clutter the store and provides no value on recalls.
	    if filereadable(a:pendingBufferFilespec)
		if delete(a:pendingBufferFilespec) != 0
		    call ingo#err#Set('BufferPersist: Failed to delete temporary recorded buffer')
		    return 0
		endif
	    endif
	else
	    execute 'silent keepalt' ingo#compat#commands#keeppatterns() l:range . 'write!' ingo#compat#fnameescape(a:pendingBufferFilespec)
	endif
	return 1
    catch /^Vim\%((\a\+)\)\=:/
	call ingo#err#Set('BufferPersist: Failed to record buffer: ' . ingo#msg#MsgFromVimException())
	return 0
    catch /^BufferPersist:/
	call ingo#err#Set(v:exception)
	return 0
    endtry
endfunction

function! BufferPersist#OnUnload( range, whenRangeNoMatch, pendingBufferFilespec )
    " The BufLeave event isn't invoked when :quitting Vim from the current
    " buffer. We catch this from the BufUnload event. Since it is not allowed to
    " switch buffer in there, we cannot in general use this for persisting. But
    " in this special case, we only need to persist when inside the
    " to-be-unloaded buffer.
    if expand('<abuf>') == bufnr('')
	if ! BufferPersist#RecordBuffer(a:range, a:whenRangeNoMatch, a:pendingBufferFilespec)
	    call ingo#msg#ErrorMsg(ingo#err#Get())
	endif
    endif
endfunction

function! BufferPersist#PersistBuffer( pendingBufferFilespec, BufferStoreFuncref, bufNr )
    if ! filereadable(a:pendingBufferFilespec)
	return 1
    endif

    let l:bufferFilespec = call(a:BufferStoreFuncref, [a:bufNr])
"****D echomsg '**** rename' string(a:pendingBufferFilespec) string(l:bufferFilespec)
    if rename(a:pendingBufferFilespec, l:bufferFilespec) == 0
	unlet! s:pendingBufferFilespecs[a:pendingBufferFilespec]
    else
	call ingo#err#Set('BufferPersist: Failed to persist buffer to ' . l:bufferFilespec)
	return 0
    endif
    return 1
endfunction

function! BufferPersist#OnLeave( BufferStoreFuncref )
    for [l:filespec, l:bufNr] in items(s:pendingBufferFilespecs)
	if ! BufferPersist#PersistBuffer(l:filespec, a:BufferStoreFuncref, l:bufNr)
	    call ingo#msg#ErrorMsg(ingo#err#Get())
	endif
    endfor
endfunction

let s:pendingBufferFilespecs = {}
function! BufferPersist#Setup( BufferStoreFuncref, ... )
"******************************************************************************
"* PURPOSE:
"   Set up autocmds for the current buffer to automatically persist the buffer
"   contents when Vim is done editing the buffer (both when is was saved to a
"   file and also when it was discarded, e.g. via :bdelete!)
"* ASSUMPTIONS / PRECONDITIONS:
"   None.
"* EFFECTS / POSTCONDITIONS:
"   Writes buffer contents to the file returned by a:BufferStoreFuncref.
"* INPUTS:
"   a:BufferStoreFuncref    A Funcref that takes the buffer number as an
"			    argument and returns the filespec where the buffer
"			    contents should be persisted to.
"   a:options.range         A |:range| expression limiting the lines of the
"			    buffer that should be persisted. This can be used to
"			    filter away some content. Default is "", which
"			    includes the entire buffer.
"   a:options.whenRangeNoMatch  Specifies the behavior when a:options.range
"				doesn't match. One of:
"				"error": an error message is printed and the
"				buffer contents are not persisted
"				"ignore": the buffer contents silently are not
"				persisted
"				"all": the entire buffer is persisted instead
"				Default is "error"
"   a:options.writeCommandName  The plugin defines a buffer-local command with
"                               that name that persists the current buffer
"                               contents (or just the passed :[range]). If the
"                               buffer is changed after that, it will again be
"                               persisted when editing is done. This enables the
"                               user to store intermediate snapshots of the
"                               buffer.
"* RETURN VALUES:
"   None.
"******************************************************************************
    let l:options = (a:0 ? a:1 : {})
    let l:range = get(l:options, 'range', '')
    let l:whenRangeNoMatch = get(l:options, 'whenRangeNoMatch', 'error')
    let l:writeCommandName = get(l:options, 'writeCommandName', '')

    let l:pendingBufferFilespec = tempname()
    let s:pendingBufferFilespecs[l:pendingBufferFilespec] = bufnr('')

    augroup BufferPersist
	autocmd! * <buffer>
	execute printf('autocmd BufLeave  <buffer> if ! BufferPersist#RecordBuffer(%s, %s, %s) | call ingo#msg#ErrorMsg(ingo#err#Get()) | endif',
	\   string(l:range), string(l:whenRangeNoMatch), string(l:pendingBufferFilespec)
	\)
	execute printf('autocmd BufUnload <buffer> call BufferPersist#OnUnload(%s, %s, %s)',
	\   string(l:range), string(l:whenRangeNoMatch), string(l:pendingBufferFilespec)
	\)
	execute printf('autocmd BufDelete <buffer> if ! BufferPersist#PersistBuffer(%s, %s, %d) | call ingo#msg#ErrorMsg(ingo#err#Get()) | endif',
	\   string(l:pendingBufferFilespec), string(a:BufferStoreFuncref), bufnr('')
	\)

	" This should be added only once per a:BufferStoreFuncref(). However,
	" since subsequent invocations will no-op on an empty
	" s:pendingBufferFilespecs, this does no harm, just adds a minimal
	" linear performance impact, and we don't expect many persisted buffers
	" in a single Vim session, anyway.
	execute printf('autocmd VimLeavePre * call BufferPersist#OnLeave(%s)', string(a:BufferStoreFuncref))
    augroup END

    if ! empty(l:writeCommandName)
	execute printf('command! -buffer -bar -range=-1 %s if ! BufferPersist#WriteBuffer(%s, %s, (<count> == -1 ? "" : <line1> . "," . <line2>), %s) | echoerr ingo#err#Get() | endif',
	\   l:writeCommandName, string(a:BufferStoreFuncref), string(l:range), string(l:whenRangeNoMatch)
	\)
    endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
" vim: set ts=8 sts=4 sw=4 noexpandtab ff=unix fdm=syntax :
