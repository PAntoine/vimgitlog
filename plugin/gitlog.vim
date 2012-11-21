" vim: ts=4 tw=4 fdm=marker :
" ---------------------------------------------------------------------------------
"  Name   : gitlog
"  Desc   : This plugin is a tool for looking at the GIT history of a file.
"			
"			The simplest way to use this plugin is to map the GITLOG_ToggleWindows
"			function to the key of your choice (I use <F7>) and it will create
"			the log window on creation and will delete all the windows (including
"			the diffs that have been created) when it toggles off.
"
"			In the log window the two following commands work.
"			  o   - will open the file.
"			 <cr> - will open the revision for diff'ing.
"
"			In the branch window it will use the following commands:
"			 <cr> - will swap the GIT_LOG view of the branch - does not effect th
"					actual branch that is being used.
"
"			It is that simple.
" 
"  Author : peterantoine
"  version: 1.1.1
"  Date   : 29/09/2012 14:42:03
" ---------------------------------------------------------------------------------
"					   Copyright (c) 2012 Peter Antoine
"							  All rights Reserved.
"					  Released Under the Artistic Licence
" ---------------------------------------------------------------------------------
"{{{ Revision History
"    Version   Author Date        Changes
"    -------   ------ ----------  -------------------------------------------------
"    1.0.0     PA     10.10.2012  Initial revision
"    1.1.0     PA     27.10.2012  Added functionality to the Branch window.
"    1.1.1     PA     21.11.2012  Fixed issue with not finding history if the
"                                 editor was not launched in the repository tree.
"																				}}}
" PUBLIC FUNCTIONS
" FUNCTION: GITLOG_GetHistory(filename)										"{{{
"
" This function will open the log window and load the history for the given file.
" If the file does not exist within the given branch then then function will 
" produce a message that states that and then it will do nothing. It will used 
" the current value od s:gitlog_current_branch as the branch to search on.
" 
" vars:
"	filename	the filename to search for history for.
"
function! GITLOG_GetHistory(filename)
		" have to get the files that it uses first
	let s:repository_root = s:GITLOG_FindRespositoryRoot(a:filename)

	if (s:repository_root == "")
		return 0
	else
		if (a:filename == "")
			echohl WarningMsg
			echomsg "No file in the buffer, can't get history"
			echohl Normal
			return 0
		else
			let s:revision_path = substitute(a:filename,s:repository_root,"","")
			let s:original_window = bufwinnr("%")
			
			silent execute "!git --git-dir=" . s:repository_root . ".git cat-file -e " . "HEAD:" . s:revision_path
			if v:shell_error
				echohl WarningMsg
				echomsg "File " . s:gitlog_current_branch . ":" . s:revision_path . " is not tracked"
				echohl Normal
				return 0
			else
				call s:GITLOG_OpenLogWindow(a:filename)
				call s:GITLOG_OpenBranchWindow()
				return 1
			endif
		endif
	endif
endfunction																		"}}}
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

	if (commit != "")
		silent execute "!git --git-dir=" . s:repository_root . ".git cat-file -e " . commit . ":" . s:revision_path 
		if v:shell_error
			echohl Normal
			echomsg "The repository does not have this file"
			echohl WarningMsg
		else
			call s:GITLOG_OpenDiffWindow(commit,s:revision_path)
		endif
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

	if (commit != "")
	  silent execute "!git --git-dir=" . s:repository_root . ".git cat-file -e " . commit . ":" . s:revision_path 
	  if v:shell_error
		  echohl Normal
		  echomsg "The repository does not have this file"
		  echohl WarningMsg
	  else
		  call s:GITLOG_OpenCodeWindow(commit,s:revision_path)
	  endif
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
"	node
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
"	node
"
" returns:
"	nothing
"
function!	GITLOG_ToggleWindows()

	if !exists("s:gitlog_loaded")
		let s:gitlog_current_branch = GITLOG_GetBranch()
		let s:revision_file = expand('%:p')

		if (GITLOG_GetHistory(s:revision_file))
			let s:gitlog_loaded = 1
		endif
	else
		unlet s:gitlog_loaded
		call GITLOG_CloseWindows()
	endif
endfunction																		"}}}
" FUNCTION: GITLOG_SwitchLocalBranch()											{{{
"
" This function will set the s:gitlog_current_branch to the name of the
" branch that is under the cursor in the branch window.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! GITLOG_SwitchLocalBranch()
	let new_branch = s:GITLOG_GetBranchName()
	
	if (new_branch != "")
		let s:gitlog_current_branch = new_branch

		if (!GITLOG_GetHistory(expand(s:revision_file)))
			echohl WarningMsg
			echomsg "The branch " . s:gitlog_current_branch . " does not have this file"
			echohl Normal
		endif
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
" FUNCITON: GITLOG_GetBranchName												{{{
" 
" This function will search for the branch name on the current line of the buffer. The name
" starts 2 characters into the line and goes until the first whitespace character is found.
"
" vars:
"	none
"
" returns:
"	the 7 hex digits of the commit hash, else the empty string.
"
function! s:GITLOG_GetBranchName()
	let x =  getline(".")
	
	let branch_name = substitute(x,"^..\\(\\S\\+\\) .\\+$","\\1","")

	return branch_name
endfunction																		"}}}
" FUNCTION: GITLOG_FindRespositoryRoot(filename)								{{{
"
" This function will search the tree UPWARDS and downwards to find the git 
" repository that the file belongs to. If it cannot find the repository then it
" will generate an error and then return an empty string. It will use the given
" filename to start the search from.
"
" vars:
"	filename	The file to get the repository root from.
"
" returns:
"	If there is a .git directory in the tree, it returns the directory that the .git
"	repository is in, else it returns the empty string.
"
function! s:GITLOG_FindRespositoryRoot(filename)
	let root = finddir(".git",fnamemodify(a:filename,':h'). "," . fnamemodify(a:filename,':p:h') . ";" . $HOME)
	
	if (root == "")
		echohl WarningMsg
		echomsg "This does not look to be a git repository as can't find a .git dir"
		echohl Normal
	elseif (root == '.git')
		let root = getcwd() . '/'
	else
		let root = substitute(fnamemodify(root,':p'),"\\.git/","","")
	endif

	return root
endfunction																	"}}}
" FUNCTION: GITLOG_MapLogBufferKeys()										{{{
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
function! s:GITLOG_MapLogBufferKeys()
	map <buffer> <silent> <cr> :call GITLOG_DiffRevision()<cr>
	map <buffer> <silent> o	  :call GITLOG_OpenRevision()<cr>
endfunction																	"}}}
" FUNCTION: GITLOG_OpenLogWindow()											{{{
" 
" This function will open the log window if it is not already open. It will
" fill it with the output of git rev list window.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:GITLOG_OpenLogWindow(file_name)
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
	
	"need to change the window
	setlocal modifiable

	" now get the file history for the window
	" rev-list does not support the --git-dir flag, so have to cd into the directory.
	exec 'cd' fnameescape(s:repository_root)
	redir => gitdiff_history
	silent execute "!git --git-dir=" . s:repository_root . ".git rev-list " . s:gitlog_current_branch . " --oneline --graph -- " . a:file_name
	redir END
	cd -

	let git_array = split(substitute(gitdiff_history,'[\x00]',"","g"),"\x0d")
	call remove(git_array,0)
	call setline(1,[ 'branch: ' . s:gitlog_current_branch] + git_array)
	
	" set the keys on the Log window
	call s:GITLOG_MapLogBufferKeys()

	setlocal nomodifiable
endfunction																"}}}
" FUNCTION: GITLOG_MapBranchBufferKeys()								{{{
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
function! s:GITLOG_MapBranchBufferKeys()
	map <buffer> <silent> <cr> :call GITLOG_SwitchLocalBranch()<cr>
endfunction																"}}}
" FUNCTION: GITLOG_OpenBranchWindow()									{{{
"
" This function will open the branch window.
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

	"need to change the window
	setlocal modifiable
	
	" now get the list of branches
	redir => gitbranch_history
	silent execute "!git --git-dir=" . s:repository_root . ".git branch -v"
	redir END
	let git_array = split(substitute(gitbranch_history,'[\x00]',"","g"),"\x0d")
	call remove(git_array,0)
	call setline(1,git_array)
	
	" set the keys on the branch window
	call s:GITLOG_MapBranchBufferKeys()
	
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
		silent execute "!git --git-dir=" . s:repository_root . ".git --no-pager show " . revision
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
		silent execute "!git --git-dir=" . s:repository_root . ".git --no-pager show " . revision
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
	let branch = system("git --git-dir=" . s:repository_root . ".git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* //'")
	if branch != ''
		return substitute(branch, '\n', '', 'g')
	else
		return ''
	endif
endfunction																	"}}}

