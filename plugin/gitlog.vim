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
"			  s   - will search the selected revisions.
"			 <cr> - will open the revision for diff'ing.
"
"			In the tree window \_\_gitlog\_\_ the following commands work:
"			
"			  l	  - opens the local version of the file, if it exists.
"             d	  -	diff's the tree view of the file against the local version.
"            <cr> -	opens the respository version of the file, if it exists.
"           
"			In the branch window it will use the following commands:
"			 <cr> - will swap the GIT_LOG view of the branch - does not effect th
"					actual branch that is being used.
"
"           In Search Window the following keys are to be used:
"             o   - will open a revision
"            <cr> - will open the revision for diff'ing.
"
"           also when selected from the search window, the file line will be selected.
"
"			It is that simple.
" 
"  Author : peterantoine
"  version: 2.0.0
"  Date   : 29/09/2012 14:42:03
" ---------------------------------------------------------------------------------
"					   Copyright (c) 2012 Peter Antoine
"							  All rights Reserved.
"					  Released Under the Artistic Licence
" ---------------------------------------------------------------------------------
"
" GLOBAL INITIALISERS
"																				{{{
let s:tree_root = 0
let s:current_root = 0
let s:directory_list = [[]]
let s:gitlog_current_commit = 'HEAD'
let s:revision_file = ''
let s:last_diff_path = ''
let s:diff_buffer_list = []

" simbols used in the list window
if !exists("g:GITLOG_DontUseUnicode") || g:GITLOG_DontUseUnicode == 0
	let s:GITLOG_Added		= '✓ '
	let s:GITLOG_Deleted	= '✗ '
	let s:GITLOG_Changed	= '• '
	let s:GITLOG_Same		= '  '
	let s:GITLOG_Closed		= '▸ '
	let s:GITLOG_Open		= '▾ '
else
	let s:GITLOG_Added		= '+ '
	let s:GITLOG_Deleted	= 'x '
	let s:GITLOG_Changed	= '- '
	let s:GITLOG_Same		= '  '
	let s:GITLOG_Closed		= '> '
	let s:GITLOG_Open		= 'v '
endif

if !exists("g:GITLOG_default_mode")
	let g:GITLOG_default_mode = 1
endif
"
"																				}}}
" PUBLIC FUNCTIONS
" FUNCTION: GITLOG_GetHistory(filename)											{{{
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
	if (s:repository_root == "")
		return 0
	else
		let s:revision_path = substitute(a:filename,s:repository_root,"","")
		let s:original_window = bufwinnr("%")

		if (a:filename == "")
			return s:GITLOG_OpenTreeWindow()
		else
			"TODO: check for valid version should be here

			silent execute "!git --git-dir=" . s:repository_root . ".git cat-file -e " . "HEAD:" . s:revision_path
			if v:shell_error
				let result = s:GITLOG_OpenTreeWindow()
				echohl WarningMsg
				echomsg "File " . s:gitlog_current_branch . ":" . s:revision_path . " is not tracked (test:" . a:filename . ")"
				echohl Normal
				return result
			else
				call s:GITLOG_OpenLogWindow(a:filename)
				call s:GITLOG_OpenBranchWindow()
				return 1
			endif
		endif
	endif
endfunction																		"}}}
" FUNCITON:	GITLOG_DiffRevision()												{{{
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
	let commit = s:GITLOG_GetCommitHash(line('.'))

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
" FUNCITON:	GITLOG_OpenSearchRevision(mode)										{{{
"
" This function will open a revision for diff'ing. 
" It will create a new window and diff the new window/buffer against the original
" buffer that was used to launch gitlog.
"
" vars:
"	mode	0 for diff, 1 for code
"
" returns:
"	nothing
"
function! GITLOG_OpenSearchRevision(open_mode)
	" get file and location
	let current_line	= getline(line('.'))
	let commit			= substitute(current_line,"^\\(\\x\\x\\x\\x\\x\\x\\x\\):.\\+$","\\1","")
	let revision_path	= substitute(current_line,"^\\x\\x\\x\\x\\x\\x\\x:\\(\\f\\+\\):.\\+$","\\1","")
	let revision_line	= substitute(current_line,"^\\x\\x\\x\\x\\x\\x\\x:\\f\\+:\\(\\d\\+\\).\\+$","\\1","")

	if (commit != "")
		silent execute "!git --git-dir=" . s:repository_root . ".git cat-file -e " . commit . ":" . revision_path 
		if v:shell_error
			echohl Normal
			echomsg "The repository does not have this file"
			echohl WarningMsg
		else
			if a:open_mode == 0
				" switch back to the original window before creating the new window
				exe bufwinnr(bufnr(s:revision_file)) . "wincmd w"
				let head_commit = substitute(system("git --git-dir=" . s:repository_root . ".git rev-parse --short HEAD"),'[\x00]',"","g")
				let head_name	= head_commit . ':' . fnamemodify(revision_path,":t")
				let s:buf_number = bufnr(head_name,1)

				if filereadable(s:repository_root . revision_path)
					" Ok, the file exists in the current tree - just open it
					silent exe "edit " . s:repository_root . revision_path
					call s:GITLOG_OpenDiffWindow(commit,revision_path,s:repository_root . revision_path)
				else
					" open it as a revision file 
					silent exe "buffer " . s:buf_number
					let temp = @"
					exe "% delete"
					let @" = temp

					call s:GITLOG_LoadRevisionFile(head_commit . ':' . revision_path)
					call s:GITLOG_OpenDiffWindow(commit,revision_path,head_name)
				endif

			elseif a:open_mode == 1
				call s:GITLOG_OpenCodeWindow(commit,revision_path)
				call setpos(".",[0,revision_line,1,-1])
			endif
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
	let commit = s:GITLOG_GetCommitHash(line('.'))

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
" FUNCITON:	GITLOG_OpenRevisionTree()											{{{
"
" This function will open the revision tree for this commit. 
" It will set the current commit to the commit that has been extracted from the
" log window, then toggle the window to the tree.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! GITLOG_OpenRevisionTree()
	let commit = s:GITLOG_GetCommitHash(line('.'))

	if (commit != "")
		call GITLOG_ToggleWindows(2)
	endif
endfunction																		"}}}
" FUNCTION: GITLOG_CloseWindows()												{{{
"
" This function closes all the GitLog windows. It will search through all the
" windows looking for the known named buffers (__gitbranch__, __gitsearch__ and
" __gitlog__) also for windows with the __XXXXXXX:<some_text>__ pattern and 
" close them all. It will also call diffoff! to make tidy up.
"
" vars:
"	node
"
" returns:
"	nothing
"
function! GITLOG_CloseWindows()
	"close the search window
	if bufwinnr(bufnr("__gitsearch__")) != -1
		exe "bwipeout __gitsearch__"
	endif

	" close the log window
	if bufwinnr(bufnr("__gitlog__")) != -1
		exe "bwipeout __gitlog__"
	endif

	"close the branch window
	if bufwinnr(bufnr("__gitbranch__")) != -1
		exe "bwipeout __gitbranch__"
	endif

	" close all the diff windows
	call s:GITLOG_CloseDiffBuffers()

	" catch any stragglers
	for found_buf in range(1, bufnr('$'))
		if (bufexists(found_buf))
			if (substitute(bufname(found_buf),"\\x\\x\\x\\x\\x\\x\\x:.\\+$","correct_buffer_to_close","") == "correct_buffer_to_close")
				exe "bwipeout " . bufname(found_buf)
			endif
		endif
	endfor


	diffoff!

endfunction																		"}}}
" FUNCTION: GITLOG_FlipWindows()												{{{
"
" This function flips the __gitlog__ window from log view to tree view. This will
" also initially load the window in the previous state.
"
" vars:
"	node
"
" returns:
"	nothing
"
function!	GITLOG_FlipWindows()
	if !exists("s:gitlog_loaded")
		" load it on
		call GITLOG_ToggleWindows(g:GITLOG_default_mode)
	elseif s:gitlog_loaded == 1
		call GITLOG_ToggleWindows(2)
	else
		call GITLOG_ToggleWindows(1)
	endif
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
function!	GITLOG_ToggleWindows(...)
	if !exists("s:gitlog_loaded") || (a:0 == 1 && a:1 != s:gitlog_loaded)
		augroup GITLOG
		
		let s:repository_root = s:GITLOG_FindRespositoryRoot(s:revision_file)
		let fend = expand('%:t')

		if 	(fend != "__gitlog__" && fend != "__gitbranch__" && fend != "__gitsearch__")
		\   && substitute(expand('%:p'),"\\x\\x\\x\\x\\x\\x\\x:.\\+$\\|[0-9A-Za-z\/\._#]\\+:.\\+$","correct_buffer_to_close","") != "correct_buffer_to_close"
			" don't remember it if it is the log window (we could be toggling)
			let s:revision_file = expand('%:p')
			let s:gitlog_current_branch = GITLOG_GetBranch()
		endif

		let s:gitlog_branch_line = 0
		let s:starting_window = bufwinnr("%")

		if a:0 == 0 || a:1 == 1
			if GITLOG_GetHistory(s:revision_file)
				let s:gitlog_loaded = 1
			endif
		else
			if s:GITLOG_OpenTreeWindow()
				let s:gitlog_loaded = 2
			endif
		endif
	else
		unlet s:gitlog_loaded
		call GITLOG_CloseWindows()
		au! GITLOG
		augroup! GITLOG
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
	let new_branch = s:GITLOG_GetBranchName(getline("."))
	
	if new_branch != ""
		let s:gitlog_current_branch = new_branch
		let s:gitlog_current_commit = new_branch

		if s:gitlog_loaded == 1
			" we have the log window loaded so refresh that
			if (!GITLOG_GetHistory(expand(s:revision_file)))
				echohl WarningMsg
				echomsg "The branch " . s:gitlog_current_branch . " does not have this file"
				echohl Normal
			endif
		else
			" the tree is loaded, so reload that...
			let s:directory_list = [[]]
			call s:GITLOG_OpenTreeWindow()
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
function! s:GITLOG_GetCommitHash(required_line)
	let x = getline(a:required_line)

	if (stridx(x,"*") >= 0)
		let commit = substitute(x,"^[* |]\\+\\s\\+\\(\\x\\x\\x\\x\\x\\x\\x\\) .\\+$","\\1","")
	else
		let commit = ""
	endif

	if commit != ""
		let s:gitlog_current_commit = commit
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
function! s:GITLOG_GetBranchName(line)
	
	let s:gitlog_branch_line = line('.') - 1
	let branch_name = substitute(a:line,"^..\\(\\S\\+\\) .\\+$","\\1","")

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
	mapclear <buffer>
	map <buffer> <silent> <cr> :call GITLOG_DiffRevision()<cr>
	map <buffer> <silent> s	  :call GITLOG_SearchCommits()<cr>
	map <buffer> <silent> o	  :call GITLOG_OpenRevision()<cr>
	map <buffer> <silent> t	  :call GITLOG_OpenRevisionTree()<cr>

	au GITLOG BufLeave <buffer> call s:GITLOG_LeaveBuffer()
endfunction																	"}}}
" FUNCTION: GITLOG_OpenTreeToFile()								{{{
" 
" If the tree window is open, this function will open the tree
" for the path that is passed into it. It will fill the directories
" that it needs to on the way.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:GITLOG_OpenTreeToFile(file_path)
	let components = split(a:file_path,"/")
	let curent_directory = s:tree_root
	let found_item = {}

	if (len(components) == 1 && components[0] == a:file_path)
		let components = split(a:file_path,"\\")
	endif

	if (len(components) > 1)
		let new_path = '.'
		for component in components
			let found = 0
			let new_path = new_path . "/" . component
			
			" open the sub-directory if we need too
			if found_item != {} && curent_directory == 0 && found_item.type == 'tree'
				let found_item.child = GITLOG_MakeDirectory(new_path, found_item.parent)
				let curent_directory = found_item.child

				if curent_directory == 0
					break
				endif
			endif

			" now search the directory
			for item in s:directory_list[curent_directory]
				if item.name ==# component
					" found it
					let found_item = item
					let curent_directory = item.child
					let found = 1

					if found_item.type == 'tree'
						let item.status = 'open'
					endif

					break
				endif
			endfor

			" did we find it?
			if found == 0
				break
			endif
		endfor
	endif
	
	return found_item

endfunction																"}}}
" FUNCTION: GITLOG_OpenTreeWindow()										{{{
" 
" This function will open the tree window if it is not already open. It will
" use the __gitlog__ window, as this will effectively cause the windows to
" toggle. It will open the window for the current selected version and branch.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:GITLOG_OpenTreeWindow()
	let found_item = {}

	if bufwinnr(bufnr("__gitlog__")) != -1
		" window already open - just go to it
		silent exe bufwinnr(bufnr("__gitlog__")) . "wincmd w"
		setlocal modifiable
		let temp = @"
		silent exe "% delete"
		let @" = temp
	else
		" window not open need to create it
		let s:buf_number = bufnr("__gitlog__",1)
		silent topleft 40 vsplit
		set winfixwidth
		set winwidth=40
		set winminwidth=40
		silent exe "buffer " . s:buf_number
		setlocal syntax=gitlog
		setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap
	endif
	
	"need to change the window
	setlocal modifiable

	" update the tree window
	if len(s:directory_list) == 1
		let s:tree_root = GITLOG_MakeDirectory(s:repository_root,0)
		let s:current_root = s:tree_root
	endif

	" do we need to open a directory
	if s:revision_path != ''
		let found_item = s:GITLOG_OpenTreeToFile(s:revision_path)
	endif

	" now update the window
	call setline(1,s:GITLOG_UpdateTreeWindow([ 'commit: ' . s:gitlog_current_commit ], s:repository_root,s:current_root,''))

	if found_item != {}
		call setpos('.',[0,found_item.lnum,0,0])
	endif

	" set the keys on the tree window
	mapclear <buffer>
	map <buffer> <silent> <cr> :call GITLOG_ActionListWindow(2)<cr>		" revision version of the file
	map <buffer> <silent> l    :call GITLOG_ActionListWindow(0)<cr>		" open local version of the file
	map <buffer> <silent> d    :call GITLOG_ActionListWindow(1)<cr>		" diff the local with the repository

	setlocal nomodifiable

	call s:GITLOG_OpenBranchWindow()


	return 1
endfunction																"}}}
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
		let temp = @"
		silent exe "% delete"
		let @" = temp
	else
		" window not open need to create it
		let s:buf_number = bufnr("__gitlog__",1)
		silent topleft 40 vsplit
		set winfixwidth
		set winwidth=40
		set winminwidth=40
		silent exe "buffer " . s:buf_number
		setlocal syntax=gitlog
		setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap
	endif
	
	"need to change the window
	setlocal modifiable

	" now get the file history for the window
	" rev-list does not support the --git-dir flag, so have to cd into the directory.
	exec 'cd' fnameescape(s:repository_root)
    let run_command = 'git --git-dir=' . s:repository_root . ".git --no-pager rev-list " . s:gitlog_current_branch . " --oneline --graph -- " . a:file_name
	let gitdiff_history = system(run_command)
	cd -

	let git_array = split(gitdiff_history,'[\x00]')
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
		setlocal syntax=gitlog
		setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap
	endif

	"need to change the window
	setlocal modifiable
	
	" now get the list of branches
    let run_command = "git --git-dir=" . s:repository_root . ".git --no-pager branch -v"
	let gitbranch_history = system(run_command)

	let git_array = split(gitbranch_history,'[\x00]')

	" set the current branch marker if it is not current real branch
	if s:gitlog_branch_line != 0
		if strpart(git_array[s:gitlog_branch_line],0,1) != '*'
			let temp = '>' . strpart(git_array[s:gitlog_branch_line],1,strlen(git_array[s:gitlog_branch_line])-1)
			let git_array[s:gitlog_branch_line] = temp
		endif
	elseif s:gitlog_current_branch != ''
		let line_no = 0
		for branch_line in git_array
			if s:gitlog_current_branch == s:GITLOG_GetBranchName(branch_line)
				if branch_line[0] != '*'
					let git_array[line_no]= '>' . branch_line[1:]
					let s:gitlog_branch_line = line_no
				endif
				break
			endif
			let line_no = line_no + 1
		endfor
	endif

	call setline(1,git_array)
	
	" set the keys on the branch window
	call s:GITLOG_MapBranchBufferKeys()
	
	setlocal nomodifiable

	" want to be in the log window - as the branch window is not important
	silent exe bufwinnr(bufnr("__gitlog__")) . "wincmd w"
endfunction																"}}}
" FUNCTION:	GITLOG_LoadRevisionFile(revision)							{{{
"
" This function will open the specified revision in the current window. It
" will get the revision from Git and then load it into the current window.
"
" vars:
"	commit			the commit number to diff against
"	file_path		the file path to diff.
"
" returns:
"	nothing
"
function! s:GITLOG_LoadRevisionFile(revision)
    let run_command = 'git --git-dir=" . s:repository_root . ".git --no-pager show " . a:revision
	let gitlog_file = system(run_command)

	" now write the captured text to the a new buffer - after removing
	" the \x00's from the text and splitting into an array.
	let git_array = split(gitlog_file,'[\x00]')
	call setline(1,git_array)
	setlocal buftype=nofile bufhidden=wipe nobuflisted nomodifiable noswapfile nowrap

	" we can't (don't want to) change the historical commit
	setlocal nomodifiable
endfunction																"}}}
" FUNCTION:	GITLOG_CloseDiffBuffers()									{{{
"
" This function will close the buffers that have been opened by the calls
" to the diff open function.
"
" vars:
"	<none>
"
" returns:
"	nothing
"
function! s:GITLOG_CloseDiffBuffers()

	" pull down all the windows open for the diff
	for diff_buffer in s:diff_buffer_list
		if bufnr(diff_buffer) != -1
			" delete the buffer (and the window if it has one)
			silent exe "bwipe " . diff_buffer
		endif
	endfor

	" empty the list
	let s:diff_buffer_list = []

	silent diffoff!
endfunction																"}}}
" FUNCTION:	GITLOG_OpenDiffWindow(commit,file_path,...)					{{{
"
" This function will open the specified revision as a diff, and diff it 
" against the file in the current buffer. The revision is a diff spec of
" the type that can be passed to the git show, expecting XXXXXXX:<name>
" the XXXXXXX is the commit hash for the revision that is required and the
" <name> is the file name. This names needs to be from the root of the 
" git repository or it wont be found.
"
" vars:
"	commit			the commit number to diff against
"	file_path		the file path to diff.
"	...             the optional parameter for the buffer name to diff against
"
" returns:
"	nothing
"
function! s:GITLOG_OpenDiffWindow(commit,file_path,...)
	let revision = escape(a:commit . ":" . a:file_path,"#")
	let buffname = escape(a:commit . ":" . fnamemodify(a:file_path,":t"),"#")

	" has the main diff file changed?
	if s:last_diff_path !=# a:file_path
		call s:GITLOG_CloseDiffBuffers()
	endif

	if bufwinnr(bufnr(buffname)) != -1
		" window already open - just go to it
		exe bufwinnr(bufnr(buffname)) . "wincmd w"
		setlocal modifiable
		diffthis
	else
		" window not open need to create it
		if a:0 == 0
			exe bufwinnr(bufnr(s:revision_file)) . "wincmd w"
		else
			exe bufwinnr(bufnr(a:1)) . "wincmd w"
		endif

		let file_type = &filetype
		diffthis
		exe "silent rightbelow vnew " . buffname

		" add the new buffer to the list of buffers in this diff
		call add(s:diff_buffer_list,buffname)

        let run_command = "git --git-dir=" . s:repository_root . ".git --no-pager show " . revision
        let gitlog_file = system(run_command)

		" now write the captured text to the a new buffer - after removing
		" the \x00's from the text and splitting into an array.
	    let git_array = split(gitlog_file,'[\x00]')
		call setline(1,git_array)
		setlocal buftype=nofile bufhidden=wipe nobuflisted nomodifiable noswapfile nowrap
		diffthis
		exe "setlocal filetype=" . file_type

		" we can't (don't want to) change the historical commit
		setlocal nomodifiable
	endif
  
	if s:last_diff_path !=# a:file_path && s:last_diff_path != ''
		if winnr("$") > 2 && bufwinnr(bufnr(s:last_diff_path)) != -1
			" close the window with the other file.
			exe bufwinnr(bufnr(s:last_diff_path)) . "wincmd c"
			let s:last_diff_path = ''
		endif
	endif
		
	let s:last_diff_path = a:file_path

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
		exe bufwinnr(bufnr(s:revision_file)) . "wincmd w"

		let file_type = &filetype
		exe "silent rightbelow vnew " . buffname

        let run_command = "git --git-dir=" . s:repository_root . ".git --no-pager show " . revision
        let gitlog_file = system(run_command)
	
		" now write the captured text to the a new buffer - after removing
		" the \x00's from the text and splitting into an array.
	    let git_array = split(gitlog_file,'[\x00]')
		call setline(1,git_array)
		setlocal buftype=nofile bufhidden=wipe nobuflisted nomodifiable noswapfile nowrap
		exe "setlocal filetype=" . file_type

		" we can't (don't want to) change the historical commit
		setlocal nomodifiable
	endif
endfunction																	"}}}
" FUNCTION: GITLOG_MapSearchBufferKeys()									{{{
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
function! s:GITLOG_MapSearchBufferKeys()
	map <buffer> <silent> <cr>	:call GITLOG_OpenSearchRevision(0)<cr>
	map <buffer> <silent> o		:call GITLOG_OpenSearchRevision(1)<cr>
endfunction																	"}}}
" FUNCTION: GITLOG_OpenSearchWindow()										{{{
"
" This function will open the search results window.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:GITLOG_OpenSearchWindow()
	if !empty(s:selected_commits)
		let search_string = input("Search String: ","")

		if !empty(search_string)
	        let run_command = "git --git-dir=" . s:repository_root . ".git --no-pager grep -n -F " . search_string . s:selected_commits
    	    let search_result = system(run_command)
	
			if v:shell_error
			  echohl WarningMsg
			  echomsg "The string could not be found"
			  echohl Normal
	  		else
				" ok, we found some stuff - open the window
	    		let search_result_list = split(search_result,'[\x00]')

				if !empty(search_result_list)
					if bufwinnr(bufnr("__gitsearch__")) != -1
						" window already open - just go to it
						silent exe bufwinnr(bufnr("__gitsearch__")) . "wincmd w"
					else
						" window not open need to create it
						let s:buf_number = bufnr("__gitsearch__",1)
						exe bufwinnr(bufnr(s:revision_file)) . "wincmd w"
						bel 10 split
						set winfixwidth
						set winwidth=40
						set winminwidth=40
						silent exe "buffer " . s:buf_number
						setlocal syntax=gitlog
						setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap
					endif

					"need to change the window
					setlocal modifiable

					" delete the contents then add the search results
					let temp = @"
					silent exe "% delete"
					let @" = temp
					call remove(search_result_list,0)
					call setline(1,search_result_list)

					" Map the keys
					call s:GITLOG_MapSearchBufferKeys()

					" we can't (don't want to) change the historical commit
					setlocal nomodifiable
				endif
			endif
		endif
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
" FUNCTION: GITLOG_GetCommits()												{{{
"
" This function will get the list of commits that was/are selected in the commit
" window.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:GITLOG_GetCommits(line_first,line_last)

	if (line('.') == a:line_first)
		let start_line = a:line_first
		let s:selected_commits = ''

		while start_line <= a:line_last
			let s:selected_commits = s:selected_commits . ' ' . s:GITLOG_GetCommitHash(start_line)
			let start_line += 1
		endwhile
	endif

endfunction																	"}}}
" FUNCTION: GITLOG_SearchCommits()											{{{
"
" This function will handle the search from the LOG window.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! GITLOG_SearchCommits()
	
	if (line('.') == a:firstline)
		call s:GITLOG_GetCommits(a:firstline,a:lastline)
		call s:GITLOG_OpenSearchWindow()
	endif
endfunction																	"}}}
" FUNCTION: GITLOG_MakeDirectory(path_name,parent_id)				{{{
"
" This function will take the commit number and the path to the root of the
" directory and will create an array with all the parsed data in it. It will
" add the directory to the dir_list and return the index_id for the new entry.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! GITLOG_MakeDirectory(path_name, parent_id)
		let run_command = "git --git-dir=" . s:repository_root . ".git --no-pager ls-tree " . s:gitlog_current_commit . " " . a:path_name . " --abbrev"
    let search_result = system(run_command)

	if v:shell_error
		" could not be found, it will now just use the local files.
		let search_result = ''
	endif

	" get the current state of the working directory
	let current_dir = split(expand(a:path_name . '*'))
	call map(current_dir,'fnamemodify(fnameescape(v:val),":t")')

	" ok, we have a string with the contents of the directory
    let search_result_list = split(search_result,'[\x00]')
	let new_directory = []
	
	" add the files from the repository
	for item in search_result_list
		let item_parts = split(item)

		let new_item = {	'name'	: fnamemodify(fnameescape(item_parts[3]),":t"),
						\	'status': 'closed',
						\	'commit': item_parts[2],
						\	'type'	: item_parts[1],
						\	'parent': a:parent_id,
						\	'child'	: 0 }
		
		" see if the file exists in the current repo
		if (glob(fnameescape(item_parts[3]))) == ''
			let new_item.state = 'repo'
		else
			let new_item.state = 'both'
		endif

		call add(new_directory,new_item)

		" now remove the files in the index that are also in the current tree
		let idx = index(current_dir,new_item.name)
		if idx != -1
			call remove(current_dir,idx)
		endif
	endfor

	" now add the files that are not in the revision
	for item in current_dir
		if item[0] != '.' || s:show_local_dot_files == 1
			" do we have a directory
			if isdirectory(a:path_name . item)
				let type = 'tree'
			else
				let type = 'blob'
			endif

			let new_item = {	'name'	: fnameescape(item),
							\	'status': 'closed',
							\   'state' : 'local',
							\	'commit': '0',
							\	'type'	: type,
							\	'parent': a:parent_id,
							\	'child'	: 0 }
		
			call add(new_directory,new_item)
		endif
	endfor

	call add(s:directory_list,new_directory)
	let result = len(s:directory_list) - 1

	return result
endfunction																	"}}}
" FUNCTION: GITLOG_UpdateTreeWindow()										{{{
"
" This function will output the information for the current tree window.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:GITLOG_UpdateTreeWindow(output, directory, id, level)
"	call sort(s:directory_list[one],"NameCompare")
	for item in s:directory_list[a:id]
		if item.type == 'tree'
			if (item.status == 'closed')
				let marker = s:GITLOG_Closed
			else
				let marker = s:GITLOG_Open
			endif
			
			call add(a:output,a:level . marker . item.name)
			let item.lnum = len(a:output)

			if (item.status == 'open')
				call s:GITLOG_UpdateTreeWindow(a:output, a:directory . item.name . '/', item.child, a:level . '  ')
			endif
		endif
	endfor

	for item in s:directory_list[a:id]
		if item.type != 'tree'
			if item.state == 'local'
				let marker = s:GITLOG_Added

			elseif item.state == 'repo'
				let marker = s:GITLOG_Deleted

			else
				" Ok, file exists so need to check it's status
					let run_command = "git --no-pager diff --quiet " . s:gitlog_current_commit . " -- " . a:directory . item.name
				call system(run_command)

				if v:shell_error
					" Ok, the file is different from the working tree
					let marker = s:GITLOG_Changed
				else
					let marker = s:GITLOG_Same
				endif
			endif
			
			let item.marker = marker
			call add(a:output,a:level . marker . item.name)
				
			let item.lnum = len(a:output)
		endif
	endfor

	return a:output
endfunction																	"}}}
" FUNCTION: GITLOG_FindListItem()			`								{{{
" 
" This function will recursively walk down the tree of items.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:GITLOG_FindListItem(current_id,line_number)
	let result = {}

	for item in s:directory_list[a:current_id]
		if item.lnum == a:line_number
			let result = item
			break

		elseif item.status == 'open'
			let result = s:GITLOG_FindListItem(item.child,a:line_number)

			if (result != {})
				let s:found_path = item.name . '/' . s:found_path
				break
			endif
		endif
	endfor

	return result
endfunction																    "}}}
" FUNCTION: GITLOG_ActionListWindow()										{{{
" 
" This function will take action on a line in the buffer.
" If the line is a directory, it will toggle the state of the directory. If
" the directory has not been opened before it will call the create directory
" to create then directory.
"
" If the item is a file the version of the file from the tree will be opened
" this will work in the same was as the list window.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! GITLOG_ActionListWindow(command)
	let update_window = 0
	let s:found_path = ''
	let found_item = s:GITLOG_FindListItem(s:current_root,line("."))

	if (found_item != {})
		if found_item.type == 'tree'
			if found_item.status == 'open'
				let found_item.status = 'closed'
			else
				let found_item.status = 'open'

				if found_item.child == 0
					if s:found_path == ''
						let new_path = found_item.name . '/'
					else
						let new_path = s:found_path . found_item.name . '/'
					endif

					let found_item.child = GITLOG_MakeDirectory(new_path, found_item.parent)
				endif
			endif

			let update_window = 1
		else
			" get the local filename
			let file_name = s:found_path . found_item.name
	
			if a:command != 1 && found_item.marker != s:GITLOG_Deleted
				" Ok, open the local version of the file
				if winnr("$") == 1
					" only the log window open, so create a new window
					exe "silent rightbelow vsplit " . file_name

				elseif bufwinnr(bufnr(file_name)) != -1
					" Ok, it's currently in a window
					exe bufwinnr(bufnr(file_name)) . "wincmd w"
				
				else
					" need to load the file, in the last window used
					exe "silent " . winnr("$") . "wincmd w"
					silent exe "edit " . file_name

				endif

			elseif a:command == 1
				" Ok, diff the local version against the tree version
				if winnr("$") == 1
					" only the log window open, so create a new window
					exe "silent rightbelow vsplit " . file_name
				elseif bufwinnr(bufnr(file_name)) != -1
					" Ok, it's currently in a window
					exe bufwinnr(bufnr(file_name)) . "wincmd w"
				else
					" need to load the file, in the last window used
					exe "silent " . winnr("$") . "wincmd w"
					silent exe "edit " . file_name
				endif

				call s:GITLOG_OpenDiffWindow(s:gitlog_current_commit,file_name,file_name)
			else
				" Ok, open the version in the repository
					let buffer_name = s:gitlog_current_commit . ':' . file_name

				if bufwinnr(bufnr(buffer_name)) != -1
					" Ok, it's currently in a window
					exe bufwinnr(bufnr(buffer_name)) . "wincmd w"
				else
					if winnr("$") == 1
						exe "silent rightbelow vsplit " . buffer_name
					else
						exe "silent " . winnr("$") . "wincmd w"
					endif

					if (bufnr(buffer_name) != -1)
						" there exists a buffer with stuff in
						silent exe "buffer " . s:buf_number
					else
						" create a new buffer - and make sure it is empty
						let s:buf_number = bufnr(buffer_name,1)
						silent exe "buffer " . s:buf_number
						let temp = @"
						silent exe "% delete"
						let @" = temp

						" now open the code window
						let run_command = "git --git-dir=" . s:repository_root . ".git --no-pager show " . s:gitlog_current_commit . ':' . file_name
						let gitlog_file = system(run_command)
				
						" now write the captured text to the a new buffer - after removing
						" the \x00's from the text and splitting into an array.
						let git_array = split(gitlog_file,'[\x00]')
						call setline(1,git_array)
						setlocal buftype=nofile bufhidden=hide buflisted nomodifiable noswapfile nowrap
					endif
				endif
			endif
		endif
	endif

	" update the window
	if update_window == 1
		"need to change the window
		setlocal modifiable
		let temp = @"
		silent exe "% delete"
		let @" = temp
		call setline(1,s:GITLOG_UpdateTreeWindow([ 'commit: ' . s:gitlog_current_commit ], s:repository_root,s:current_root,''))
		call setpos('.',[0,found_item.lnum,0,0])
		setlocal nomodifiable
	endif

endfunction																    "}}}
" AUTOCMD FUNCTIONS
" FUNCTION: GITLOG_LeaveBuffer()											{{{
"
" On leaving the buffer, get the commits that have been selected. This will
" allow for the external search to be able to search the correct lines.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:GITLOG_LeaveBuffer()

	call s:GITLOG_GetCommits(a:firstline,a:lastline)

endfunction																	"}}}

