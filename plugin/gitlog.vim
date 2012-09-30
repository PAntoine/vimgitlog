" vim: ts=4 tw=4 fdm=marker :
" ---------------------------------------------------------------------------------
"  Name   : gitlog
"  Desc   : This plugin is a tool for looking at the GIT history of a file.
"           
"           The simplest way to use this plugin is to map the GITLOG_ToggleWindows
"           function to the key of your choice (I use <F7>) and it will create
"           the log window on creation and will delete all the windows (including
"           the diffs that have been created) when it toggles off.
"
"           In the log window the two following commands work.
"             o   - will open the file.
"            <cr> - will open the revision for diff'ing.
"
"           It is that simple.
" 
"  Author : peterantoine
"  version: 1.0.0
"  Date   : 29/09/2012 14:42:03
" ---------------------------------------------------------------------------------
"                      Copyright (c) 2012 Peter Antoine
"                             All rights Reserved.
"                     Released Under the Artistic Licence
" ---------------------------------------------------------------------------------
"
" PUBLIC FUNCTIONS
" FUNCTION: GITLOG_GetHistory(branch, filename)  								"{{{
"
" This function will open the log window and load the history for the given file.
" If the file does not exist within the given branch then then function will 
" produce a message that states that and then it will do nothing.
" 
" vars:
"	branch 		the git branch to look for history on.
" 	filename	the filename to search for history for.
"
function! GITLOG_GetHistory(branch, filename)
		" have to get the files that it uses first
	let s:repository_root = s:GITLOG_FindRespositoryRoot()

	if (s:repository_root == "")
		return 0
	else
		let s:revision_file = expand('%:p')
		let s:revision_path = substitute(s:revision_file,s:repository_root,"","")
		let s:original_window = bufwinnr("%")
			
		silent execute "!git cat-file -e " . "HEAD:" . s:revision_path
		if v:shell_error
			echohl WarningMsg
			echomsg "File " . a:branch . ":" . s:revision_path . " is not tracked"
			echohl Normal
			return 0
		else
			call s:GITLOG_OpenLogWindow(expand('%'))
			call s:GITLOG_OpenBranchWindow()
			return 1
		endif
	endif
endfunction                                     								"}}}
" FUNCITON:	GITLOG_DiffRevision()											{{{
"
" This function will open a revision for diff'ing. 
" It will create a new window and diff the new window/buffer against the original
" buffer that was used to launch gitlog.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! GITLOG_DiffRevision()
	let commit = s:GITLOG_GetCommitHash()

	silent execute "!git cat-file -e " . commit . ":" . s:revision_path 
	if v:shell_error
		echohl Normal
		echomsg "The repository does not have this file"
		echohl WarningMsg
	else
		call s:GITLOG_OpenDiffWindow(commit,s:revision_path)
	endif
endfunction																		"}}}
" FUNCITON:	GITLOG_OpenRevision()												{{{
"
" This function will open a revision for viewing.
" It will create a new window and load the revision into that window.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! GITLOG_OpenRevision()
	let commit = s:GITLOG_GetCommitHash()

	silent execute "!git cat-file -e " . commit . ":" . s:revision_path 
	if v:shell_error
		echohl Normal
		echomsg "The repository does not have this file"
		echohl WarningMsg
	else
		call s:GITLOG_OpenCodeWindow(commit,s:revision_path)
	endif
endfunction																		"}}}
" FUNCTION: GITLOG_CloseWindows()												{{{
"
" This function closes all the GitLog windows. It will search through all the
" windows looking for the known named buffers (__gitbranch__ and __gitlog__) also
" for windows with the __XXXXXXX:<some_text>__ pattern and close them all. It will
" also call diffoff! to make tidy up.
"
" vars:
" 	node
"
" returns:
"	nothing
"
function! GITLOG_CloseWindows()
	" close the log window
	if bufwinnr(bufnr("__gitlog__")) != -1
		exe bufwinnr(bufnr("__gitlog__")) . "wincmd w"
		exe bufwinnr(bufnr("__gitlog__")) . "wincmd q"
	endif

	"close the branch window
	if bufwinnr(bufnr("__gitbranch__")) != -1
		exe bufwinnr(bufnr("__gitbranch__")) . "wincmd w"
		exe bufwinnr(bufnr("__gitbranch__")) . "wincmd q"
	endif

	" close all the diff windows
	for b in range(1, bufnr('$'))
		if (bufexists(b))
			if (substitute(bufname(b),"\\x\\x\\x\\x\\x\\x\\x:.\\+$","","") == "")
				exe bufwinnr(b) . "wincmd w"
				exe bufwinnr(b) . "wincmd q"
			endif
		endif
	endfor

	" and finally the original buffer
	exe bufwinnr(bufnr(s:revision_file)) . "wincmd w"
	diffoff

endfunction																		"}}}
" FUNCTION: GITLOG_ToggleWindows()												{{{
"
" This function toggles the gitlog windows. It will use the file in the current
" window to use for loading the log.
"
" vars:
" 	node
"
" returns:
"	nothing
"
function!	GITLOG_ToggleWindows()

	if !exists("s:gitlog_loaded")
		if (GITLOG_GetHistory(GITLOG_GetBranch(),expand('%')))
			let s:gitlog_loaded = 1
		endif
	else
		unlet s:gitlog_loaded
		call GITLOG_CloseWindows()
	endif
endfunction																		"}}}
"
" INTERNAL FUNCTIONS BELOW --- Do not call directly							
" FUNCITON: GITLOG_GetCommitHash												{{{
" 
" This function will search for the hash on the current line in the buffer. It is
" searching for a space then 7 hex digits then another space. If it does not find
" this pattern on the line then it will return an empty string.
"
" vars:
"	none
"
" returns:
"	the 7 hex digits of the commit hash, else the empty string.
"
function! s:GITLOG_GetCommitHash()
	let x =  getline(".")
	
	if (stridx(x,"*") >= 0)
		let commit = substitute(x,"^.*\\*\\s\\+\\(\\x\\x\\x\\x\\x\\x\\x\\) .\\+$","\\1","")
	else
		let commit = ""
	endif

	return commit
endfunction																		"}}}
" FUNCTION: GITLOG_FindRespositoryRoot()										{{{
"
" This function will search the tree UPWARDS to find the git repository that the 
" file belongs to. If it cannot find the repository then it will generate an error
" and then return an empty string.
"
" vars:
"	none
"
" returns:
"	If there is a .git directory in the tree, it returns the directory that the .git
"	repository is in, else it returns the empty string.
"
function! s:GITLOG_FindRespositoryRoot()
	let root = finddir(".git",expand('%:h'). "," . expand('%:p:h') . ";" . $HOME)
	
	if (root == "")
		echohl WarningMsg
		echomsg "This does not look to be a git repository as can't find a .git dir"
		echohl Normal
	elseif (root == '.git')
		let root = getcwd() . '/'
	else
		let root = substitute(root,"\\.git","","")
	endif

	return root
endfunction																	"}}}
" FUNCTION: GITLOG_MapBufferKeys()											{{{
"
" This function maps the keys that the buffer will respond to. All the keys are
" local to the buffer.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:GITLOG_MapBufferKeys()
	map <buffer> <cr> :call GITLOG_DiffRevision()<cr>
	map <buffer> o	  :call GITLOG_OpenRevision()<cr>
endfunction																	"}}}
" FUNCTION: GITLOG_OpenLogWindow()											{{{
" 
" This function will open the branch window if it is not already open. It will
" fill it with the output of git branch window.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:GITLOG_OpenLogWindow(revision)
	if bufwinnr(bufnr("__gitlog__")) != -1
		" window already open - just go to it
		silent exe bufwinnr(bufnr("__gitlog__")) . "wincmd w"
		setlocal modifiable
		exe "% delete"
	else
		" window not open need to create it
		let s:buf_number = bufnr("__gitlog__",1)
		silent topleft 40 vsplit
		set winfixwidth
		set winwidth=40
		set winminwidth=40
		silent exe "buffer " . s:buf_number
		setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap
	endif

	" now get the file history for the window
	redir => gitdiff_history
	silent execute "!git rev-list HEAD --oneline --graph -- " . a:revision
	redir END
	let git_array = split(substitute(gitdiff_history,'[\x00]',"","g"),"\x0d")
	call remove(git_array,0)
	call setline(1,git_array)
	setlocal nomodifiable
	
	" set the keys on the Log window
	call s:GITLOG_MapBufferKeys()
endfunction																"}}}
" FUNCTION: GITLOG_OpenBranchWindow()									{{{
"
" This function will open the log window. It will see if it is open already if
" so it will switch to that buffer. As the buffer is marked as nomodifiable this
" function will remove that as then history log will want to write to that.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:GITLOG_OpenBranchWindow()
	let current_window = bufwinnr(bufnr("%"))

	if bufwinnr(bufnr("__gitbranch__")) != -1
		" window already open - just go to it
		silent exe bufwinnr(bufnr("__gitbranch__")) . "wincmd w"
		setlocal modifiable
	else
		" window not open need to create it
		let s:buf_number = bufnr("__gitbranch__",1)
		bel 10 split
		set winfixwidth
		set winwidth=40
		set winminwidth=40
		silent exe "buffer " . s:buf_number
		setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap
	endif
	
	" now get the list of branches
	redir => gitbranch_history
	silent execute "!git branch -v"
	redir END
	let git_array = split(substitute(gitbranch_history,'[\x00]',"","g"),"\x0d")
	call remove(git_array,0)
	call setline(1,git_array)
	setlocal nomodifiable
	
	" want to be in the log window - as the branch window is not important
	exe current_window . "wincmd w"
endfunction																"}}}
" FUNCTION:	GITLOG_OpenDiffWindow(revision)								{{{
"
" This function will open the specified revision as a diff, and diff it 
" against the file in the current buffer. The revision is a diff spec of
" the type that can be passed to the git show, expecting XXXXXXX:<name>
" the XXXXXXX is the commit hash for the revision that is required and the
" <name> is the file name. This names needs to be from the root of the 
" git repository or it wont be found.
"
" vars:
"	revision	The XXXXXXX:<name> formatted revision to diff against.
"
" returns:
"	nothing
"
function! s:GITLOG_OpenDiffWindow(commit,file_path)
	let revision = a:commit . ":" . a:file_path
	let buffname = a:commit . ":" . fnamemodify(a:file_path,":t")

	if bufwinnr(bufnr(buffname)) != -1
		" window already open - just go to it
		exe bufwinnr(bufnr(buffname)) . "wincmd w"
		setlocal modifiable
		diffthis
	else
		" window not open need to create it
		let s:buf_number = bufnr(buffname,1)
		exe bufwinnr(bufnr(s:revision_file)) . "wincmd w"
		let file_type = &filetype
		diffthis
		silent botright vsplit
		exe "buffer " . s:buf_number

		redir => gitlog_file
		silent execute "!git --no-pager show " . revision
		redir END
	
		" now write the captured text to the a new buffer - after removing
		" the \x00's from the text and splitting into an array.
		let git_array = split(substitute(gitlog_file,'[\x00]',"","g"),"\x0d")
		call remove(git_array,0)
		call setline(1,git_array)
		setlocal buftype=nofile bufhidden=wipe nobuflisted nomodifiable noswapfile nowrap
		diffthis
		exe "setlocal filetype=" . file_type
  endif
endfunction																"}}}
" FUNCTION:	GITLOG_OpenCodeWindow(revision)								{{{
"
" This function will open the specified revision.
"
" vars:
"	revision	The XXXXXXX:<name> formatted revision to open.
"
" returns:
"	nothing
"
function! s:GITLOG_OpenCodeWindow(commit,file_path)
	let revision = a:commit . ":" . a:file_path
	let buffname = a:commit . ":" . fnamemodify(a:file_path,":t")

	if bufwinnr(bufnr(buffname)) != -1
		" window already open - just go to it
		exe bufwinnr(bufnr(buffname)) . "wincmd w"
		setlocal modifiable
		diffthis
	else
		" window not open need to create it
		let s:buf_number = bufnr(buffname,1)
		exe bufwinnr(bufnr(s:revision_file)) . "wincmd w"
		let file_type = &filetype
		silent botright vsplit
		exe "buffer " . s:buf_number

		redir => gitlog_file
		silent execute "!git --no-pager show " . revision
		redir END
	
		" now write the captured text to the a new buffer - after removing
		" the \x00's from the text and splitting into an array.
		let git_array = split(substitute(gitlog_file,'[\x00]',"","g"),"\x0d")
		call remove(git_array,0)
		call setline(1,git_array)
		setlocal buftype=nofile bufhidden=wipe nobuflisted nomodifiable noswapfile nowrap
		exe "setlocal filetype=" . file_type
  endif
endfunction																	"}}}
" FUNCTION: GITLOG_GetBranch()												{{{
"
" This function will get the current branch that the editor is in.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! GITLOG_GetBranch()
    let branch = system("git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* //'")
    if branch != ''
        return substitute(branch, '\n', '', 'g')
	else
	    return ''
	endif
endfunction																	"}}}

