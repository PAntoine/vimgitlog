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
"           see the documentation for usage.
"
"  Author : peterantoine
"  Date   : 29/09/2012 14:42:03
" ---------------------------------------------------------------------------------
"					   Copyright (c) 2012 Peter Antoine
"							  All rights Reserved.
"					  Released Under the Artistic Licence
" ---------------------------------------------------------------------------------
"

" GLOBAL INITIALISERS
"																				{{{
" Version checking
let version_str = system("git --version")
if v:shell_error
	fini
else
	let version_list = split(version_str)
	if version_list[2] >= '1.8.5'
		" --work-dir does not work if you are in the repository tree as it uses
		" relative pathing and that is blahhh!!! But -C works as expected and
		" will work. But it arrived in 1.8.5 so we will fall back to the bad ways
		" in older gits. Some features wont work as expected but no regressions.
		let s:use_big_c = 1
	endif
	unlet version_list
endif
unlet version_str

" Version of the plugin
let g:GITLOG_version = "5.1.0 alpha"

" set up variables
let s:help = 0
let s:tree_root = 0
let s:current_root = 0
let s:directory_list = [[]]
let s:gitlog_current_commit = 'HEAD'		" The current base commit for the tree
let s:gitlog_current_ref    = 'HEAD'		" The current reference
let s:gitlog_current_branch = ''			" The current base branch
let s:gitlog_current_time = 0				" The current base date to check changes against
let s:revision_file = ''
let s:last_diff_path = ''
let s:diff_buffer_list = []
let s:user_selected_scrolloff = &scrolloff
let s:is_repo = 0
let s:git_history = []
let s:history_title = ''
let s:gitlog_window_names = ['__gitlog__', '__gitbranch__', '__gitsearch__']
let s:search_object = {}

if !(exists("g:GITLOG_default_mode"))
	let g:GITLOG_default_mode = 1
endif

if !(exists("g:GITLOG_walk_full_tree"))
	let g:GITLOG_walk_full_tree = 0
endif

if !(exists("g:GITLOG_directory_default"))
	let g:GITLOG_directory_default = 'closed'
endif

if !(exists("g:GITLOG_check_file_deferences"))
	let g:GITLOG_check_file_deferences = 1
endif

if !(exists("g:GITLOG_show_only_changes"))
	let g:GITLOG_show_only_changes = 0
endif

if !(exists("g:GITLOG_ignore_suffixes"))
	let g:GITLOG_ignore_suffixes = []
endif

if !(exists("g:GITLOG_ignore_directories"))
	let g:GITLOG_ignore_directories = []
endif

if !(exists("g:GITLOG_support_repo"))
	let g:GITLOG_support_sub_git = 1
	let g:GITLOG_support_repo = 1
endif

if !(exists("g:GITLOG_support_sub_git"))
	let g:GITLOG_support_sub_git = 1
endif

if !(exists("g:GITLOG_show_hidden_files"))
	let g:GITLOG_show_hidden_files = 0
endif

if !(exists("g:GITLOG_show_branch_window"))
	let g:GITLOG_show_branch_window = 1
endif

if !(exists("g:GITLOG_open_sub_on_search"))
	let g:GITLOG_open_sub_on_search = 1
endif

let s:gitlog_last_state = g:GITLOG_default_mode

" So that the 'A' toggle has the correct state.
if g:GITLOG_walk_full_tree == 1 && s:GITLOG_directory_default == 'open'
	let s:tree_all_opened = 1
else
	let s:tree_all_opened = 0
endif

" The list of all the directories that are repository roots (inc. sub-modules).
let s:root_list = [[]]

" symbols used in the list window
let s:GITLOG_Any = '*'		" not really a symbol but used in the searches

if !exists("g:GITLOG_DontUseUnicode") || g:GITLOG_DontUseUnicode == 0
	let s:GITLOG_Added		= '+ '
	let s:GITLOG_Deleted	= '✗ '
	let s:GITLOG_Changed	= '± '
	let s:GITLOG_Same		= '  '
	let s:GITLOG_Closed		= '▸ '
	let s:GITLOG_Open		= '▾ '
	let s:GITLOG_Unknown	= '? '
	let s:GITLOG_SubModule	= 'm'
	let s:GITLOG_SubGit		= 'g'
	let s:GITLOG_SubRepo	= 'r'
	let s:GITLOG_Link		= 'l'
	let s:GITLOG_BadLink	= 'ł'
else
	let s:GITLOG_Added		= '+ '
	let s:GITLOG_Deleted	= 'x '
	let s:GITLOG_Changed	= '~ '
	let s:GITLOG_Same		= '  '
	let s:GITLOG_Closed		= '> '
	let s:GITLOG_Open		= 'v '
	let s:GITLOG_Unknown	= '? '
	let s:GITLOG_SubModule	= 'm'
	let s:GITLOG_SubGit		= 'g'
	let s:GITLOG_SubRepo	= 'r'
	let s:GITLOG_Link		= 'l'
	let s:GITLOG_BadLink	= 'B'
endif

" walk directions.
let g:GITLOG_WALK_FORWARDS	= 1
let g:GITLOG_WALK_BACKWARDS	= -1

let s:log_help = [	 "Log Window Keys (? to remove) ",
					\"o     opens the file. This will simply open the file in a new window.",
					\"s     starts a search and opens the search window.",
					\"t     open the tree view at the current commit.",
					\"d     This will open the file and diff it against the window that was active when it was launched.",
					\"T		go back to the tree view.",
					\"<cr>  This will open the file and diff it against the window that was active when it was launched.",
					\"<c-d> Close all the open diff's.",
					\"<c-h> reset the current commit to HEAD.",
					\""]

let s:tree_help = [	 "Tree Window Keys (? to remove) ",
					\"l			opens the local version of the file, if it exists.",
					\"d			diff's the tree view of the file against the local version.",
					\"r			refreshes the tree element that it is on.",
					\"R			refreshes the root directory.",
					\"h			show the history of the current file.",
					\"p			show the previous version of the file.",
					\"a			open the current item and all it's children.",
					\"A			open the whole tree (toggles).",
					\"x			close the current tree or the parent of the current tree.",
					\"X			close the whole tree.",
					\"C			toggle 'only changes only' and rebuild the tree.",
					\"T			go back to the log view.",
					\"b			Toggle branch window.",
					\"s			Toggle Secret (hidden) files.",
					\"<cr>		opens the local version of the file, if it exists.",
					\"<c-d>		pull down all the diff windows.",
					\"<c-h>		reset the current commit to HEAD and current working branch.",
					\"<c-l>		reset the current commit to latest on current branch.",
					\"]c		goto next changed item.",
					\"[c		goto previous changed item.",
					\"]a		goto next changed/added/deleted item.",
					\"[a		goto previous changed/added/deleted item.",
					\""]

"
"																				}}}
" PUBLIC FUNCTIONS
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
		let path = substitute(s:repository_root . s:history_file, s:root_list[s:history_root].root_dir, '', '')
		let search_result = s:GITLOG_ExecuteGitCommand(s:history_root, "cat-file -t " . s:GITLOG_MakeRevision(commit, path))

		if search_result[:3] != 'blob'
			echohl Normal
			echomsg "The repository does not have this file"
			echohl WarningMsg
		else
			call s:GITLOG_OpenDiffWindow(commit, path, s:history_item)
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
	let commit			= substitute(current_line,"^\\(\\x\\+\\):.\\+$","\\1","")
	let revision_path	= substitute(current_line,"^\\x\\+:\\(\\f\\+\\):.\\+$","\\1","")
	let revision_line	= substitute(current_line,"^\\x\\+:\\f\\+:\\(\\d\\+\\).\\+$","\\1","")

	if (commit != "")
		if a:open_mode == 0
			call s:GITLOG_OpenDiffWindow(commit, revision_path, s:history_item)

		elseif a:open_mode == 1
			call s:GITLOG_OpenCodeWindow(commit,revision_path, s:history_item)
			call setpos(".",[0,revision_line,1,-1])
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
		let path = substitute(s:repository_root . s:history_file, s:root_list[s:history_root].root_dir, '', '')
		let search_result = s:GITLOG_ExecuteGitCommand(s:history_root, "cat-file -t " . s:GITLOG_MakeRevision(commit, path))

		if search_result[:3] != 'blob'
			echohl Normal
			echomsg "The repository does not have this file"
			echohl WarningMsg
		else
			call s:GITLOG_OpenCodeWindow(commit, s:history_file, s:history_item)
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
	if s:history_root == 1
		let commit = s:GITLOG_GetCommitHash(line('.'))

		if (commit != "")
			let s:gitlog_current_commit = commit
			let s:gitlog_current_ref    = commit

			" Blow away all the things and the tree will be rebuilt. This is not
			" quick for full trees - but it has to be done.
			let s:directory_list = [[]]
			call GITLOG_ToggleWindows(2)
		endif
	else
	 	echohl WarningMsg
		echomsg "Not in the root tree - not showing tree for that revision"
		echohl Normal
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
	" close all the diff windows
	call GITLOG_CloseDiffBuffers()

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

	" catch any stragglers
	for found_buf in range(1, bufnr('$'))
		if (bufexists(found_buf))
			if (substitute(bufname(found_buf),"\\x\\+:.\\+$","correct_buffer_to_close","") == "correct_buffer_to_close")
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
		call GITLOG_ToggleWindows(s:gitlog_last_state)
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

		let s:repository_root = fnamemodify(s:GITLOG_FindRespositoryRoot(s:revision_file), ':p')

		if len(s:root_list) == 1
			call add(s:root_list,{'git_dir':s:repository_root . '.git', 'root_dir': s:repository_root})
		endif

		let fend = expand('%:t')

		if 	(fend != "__gitlog__" && fend != "__gitbranch__" && fend != "__gitsearch__")
		\   && substitute(expand('%:p'),"\\x\\+:.\\+$\\|[0-9A-Za-z\/\._#]\\+:.\\+$","correct_buffer_to_close","") != "correct_buffer_to_close"
			" don't remember it if it is the log window (we could be toggling)
			let s:revision_file = expand('%:p')
		endif

		let s:gitlog_branch_line = 0
		let s:starting_window = bufwinnr("%")

		if s:revision_file != ""
			let s:revision_path = substitute(s:revision_file,s:repository_root,"","")
		else
			let s:revision_path = ''
		endif

		if s:gitlog_current_branch == ''
			call s:GITLOG_ChangeBranch(1, 'HEAD')
		endif

		if (a:0 == 0 && g:GITLOG_default_mode == 1) || ( a:0 == 1 && a:1 == 1 )
			call s:GITLOG_OpenLogWindow(0)
		else
			call s:GITLOG_OpenTreeWindow()
		endif

		if exists("s:gitlog_loaded")
			let s:gitlog_last_state = s:gitlog_loaded
		else
			let s:gitlog_last_state = g:GITLOG_default_mode
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
		call s:GITLOG_ChangeBranch(s:current_root, new_branch)

		if s:gitlog_loaded == 1
			" we have the log window loaded so refresh that
			call s:GITLOG_OpenLogWindow(expand(s:revision_file))
		else
			" the tree is loaded, so reload that...
			call GITLOG_ActionRefreshRootDirectory()
			call s:GITLOG_OpenBranchWindow()
		endif
	endif
endfunction																		"}}}
" INTERNAL FUNCTIONS BELOW --- Do not call directly
" FUNCITON: GITLOG_FindUsefulWindow												{{{
"
" Ok, we need a useful window to be able open our new file/output in. I can't
" use the open file name as the user may have changed it. Also there may not
" have been a file that was opened if we went directly into gitlog (which is
" likely now as the tree view is prominent). So we need to search the current
" windows to see if one is a likely candidate (basically any file that is not
" one of gitlogs). Also, will avoid windows if possible that start with "__"
" or are help windows.
"
" It scores each window and selects the one with the highest score.
"
" vars:
"	none
"
" returns:
"	The window number that is our victim.
"
function! s:GITLOG_FindUsefulWindow()
	redir @">
	silent buffers!
	redir END

	let result = -1
	let current_score = 0

	for line in split(@", '\n')
		let score = 0
		let name = line[10:stridx(line, '"', 11)-1]

		"  0-2 = buffer_number
		"  3   = u unlisted
		"  4   = % current, # alternate
		"  5   = a active, h hidden
		"  6   = - modifiable off, = read only
		"  7   = + modified, x read error

		if index(s:gitlog_window_names, name) == -1 && line[5] != 'h'
			let score = 3

			if name[0:1] == '__'
				let score = score - 1
			endif

			if line[3] == 'u'
				let score = score - 2
			endif

			if line[7] == 'x'
				let score = score + 1
			endif

			if line[7] == '+'
				let score = score - 1
			endif

			if line[6] != ' '
				let score = score + 1
			endif

			if name == '[No Name]'
				let score = score + 4
			endif
		endif

		if current_score < score
			let current_score = score
			let result = bufwinnr(str2nr(line[0:2]))
		endif
	endfor

	return result
endfunction																		"}}}
" FUNCITON: GITLOG_OpenWindowWithContents										{{{
"
" This function will open a file window with the contents given. It will try
" and reposition the file in the correct place with the window layout. It cant
" do all the things as the user can move the windows around and all bets are
" off.
"
" vars:
"	none
"
" returns:
"	The result of the git command or and empty string.
"
function! s:GITLOG_OpenWindowWithContents(buffname, contents)

	if winnr("$") == 1
		" only the log window open, so create a new window
		exe "silent rightbelow vsplit " . a:buffname

	elseif bufwinnr(bufnr(a:buffname)) != -1
		" Ok, it's currently in a window
		exe bufwinnr(bufnr(a:buffname)) . "wincmd w"
	else
		let select_window = s:GITLOG_FindUsefulWindow()

		if select_window == -1
			" Opps, no window found - lets goto the __gitlog__ window and
			" then go left - is this does not work then users issue. :)
			exe bufwinnr(bufnr('__gitlog__')) . "wincmd w"
			exe "silent rightbelow vsplit " . a:buffname

		else
			" Ok, goto the selected window
			let buf_number = bufnr(a:buffname, 1)
			exe select_window . "wincmd w"
			silent exe "buffer " . buf_number

		endif

		let file_type = &filetype

		" now write the captured text to the a new buffer - after removing
		" the \x00's from the text and splitting into an array.
		setlocal modifiable
		call setline(1,a:contents)
		exe "setlocal filetype=" . file_type
		setlocal buftype=nofile bufhidden=wipe nobuflisted nomodifiable noswapfile nowrap
	endif
endfunction																		"}}}
" FUNCITON: GITLOG_OpenWindowWithFile											{{{
"
" This function will open a file window with the filename given. It will try
" and reposition the file in the correct place with the window layout. It cant
" do all the things as the user can move the windows around and all bets are
" off.
"
" vars:
"	none
"
" returns:
"	The result of the git command or and empty string.
"
function! s:GITLOG_OpenWindowWithFile(file_path)
	if winnr("$") == 1
		" only the log window open, so create a new window
		exe "silent rightbelow vsplit " . a:file_path
		let s:revision_path = a:file_path

	elseif bufwinnr(bufnr(a:file_path)) != -1
		" Ok, it's currently in a window
		exe "silent " . bufwinnr(bufnr(a:file_path)) . "wincmd w"
	else
		let select_window = s:GITLOG_FindUsefulWindow()

		if select_window == -1
			" Opps, no window found - lets goto the __gitlog__ window and
			" then go left - is this does not work then users issue. :)
			exe "silent " . bufwinnr(bufnr('__gitlog__')) . "wincmd w"
			exe "silent rightbelow vsplit"

		else
			" Ok, goto the selected window
			exe "silent " . select_window . "wincmd w"
		endif

		silent exe "edit " . a:file_path
		let s:revision_path = a:file_path
	endif
endfunction																		"}}}
" FUNCITON: GITLOG_ExecuteGitCommand											{{{
"
" This function will execute a git command, It will return the result. If the
" function fails it will return an empty string.
"
" vars:
"	none
"
" returns:
"	The result of the git command or and empty string.
"
function! s:GITLOG_ExecuteGitCommand(root_id, git_command)
	if s:use_big_c
		let run_command = "git --git-dir=" . s:root_list[a:root_id].git_dir . " -C " . s:root_list[a:root_id].root_dir . " --no-pager " . a:git_command
	else
		let run_command = "git --git-dir=" . s:root_list[a:root_id].git_dir . " --work-dir=" . s:root_list[a:root_id].root_dir . " --no-pager " . a:git_command
	endif

	let result = system(run_command)

	if v:shell_error
		let result = ''
	endif

	return result
endfunction																		"}}}
" FUNCITON: GITLOG_GetCommitHash												{{{
"
" This function will search for the hash on the current line in the buffer. It is
" searching for a space then n hex digits then another space. If it does not find
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
		let commit = substitute(x,"^[* |]\\+\\s\\+\\(\\x\\+\\) .\\+$","\\1","")
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
	let root = finddir(".git",fnamemodify(a:filename,':p:h') . ";" . $HOME)

	if g:GITLOG_support_repo == 1
		let repo_root = finddir(".repo",fnamemodify(a:filename,':p:h') . ";" . $HOME)
	else
		let repo_root = ''
	endif

	if root == "" && repo_root == ""
		echohl WarningMsg
		echomsg "This does not look to be a repository."
		echohl Normal

	elseif repo_root == ""
		let root = substitute(fnamemodify(root,':p'),"\\.git/","","")
		let s:is_repo = 0

	elseif root == ""
		let root = substitute(fnamemodify(repo_root,':p'),"\\.repo/","","")
		let s:is_repo = 1

	elseif (stridx(fnamemodify(root, ':p:h:h'), fnamemodify(repo_root, ':p:h:h'))) == 0
		let root = substitute(fnamemodify(repo_root,':p'),"\\.repo/","","")
		let s:is_repo = 1
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
	map <buffer> <silent> <cr>	:call GITLOG_DiffRevision()<cr>
	map <buffer> <silent> d		:call GITLOG_DiffRevision()<cr>
	map <buffer> <silent> s		:call GITLOG_SearchCommits()<cr>
	map <buffer> <silent> o		:call GITLOG_OpenRevision()<cr>
	map <buffer> <silent> t		:call GITLOG_OpenRevisionTree()<cr>
	map <buffer> <silent> T		:call GITLOG_FlipWindows()<cr>
	map <buffer> <silent> ?		:call GITLOG_ToggleHelp()<cr>
	map <buffer> <silent> <c-d>	:call GITLOG_CloseDiffBuffers()<cr>
	map <buffer> <silent> <c-h>	:call GITLOG_ResetCommit()<cr>
	map <buffer> <silent> <c-l>	:call GITLOG_LastestCommit()<cr>

	au GITLOG BufLeave <buffer> call s:GITLOG_LeaveBuffer()
endfunction																	"}}}
" FUNCTION: GITLOG_GetSubModuleDir()										{{{
"
" This function will get the submodules git_dir from the .git file.

" vars:
"	none
"
" returns:
"	the git dir path.
"
function! s:GITLOG_GetSubModuleDir(file_path)
	let result = ''

	if file_readable(a:file_path)
		let module_file = readfile(a:file_path)
		let submodule_git_dir = ''

		" lets find the 'gitdir' line - can't expect the file to stay at one line
		for line in module_file
			if line[0:6] == 'gitdir:'
				if line[8:9] == '..'
					let result = fnamemodify(a:file_path[:-5] . line[8:],':p')
				else
					let result = line[8:]
				endif
				break
			endif
		endfor
	endif

	return result
endfunction																	"}}}
" FUNCTION: GITLOG_GetSubModuleDetails()									{{{
"
" This function will get the submodules details from a directory and add them
" to an item.
"
" vars:
"	file_path	The file path of the sub-module that is to be added.
"
" returns:
"	The new root_id for the sub-module, else 1 (the root root_id).
"
function! s:GITLOG_GetSubModuleDetails(file_path)
	let result = 1

	let root = s:GITLOG_GetSubModuleDir(a:file_path . ".git")

	if (root != '')
		let result = len(s:root_list)
		call add(s:root_list,{'git_dir': root, 'root_dir': s:repository_root . a:file_path})
	endif

	return result
endfunction																	"}}}
" FUNCTION: GITLOG_BuildFullTree()		 				 					{{{
"
" This function will build the whole tree. This will take a while as all the
" items in the tree will have to be navigated.
"
" It will take the path to the directory and then create the directory item
" and then enumerate the items in the directory. It will also look out for
" the SubModule transitions and keep track of those.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:GITLOG_BuildFullTree(path, parent_item, recursive, modules_tree)
	let result = s:GITLOG_Same

	if a:modules_tree != {} && a:modules_tree.items == {} && a:parent_item.type != 'root'
		let a:parent_item.type = 'commit'
		let a:parent_item.root_id = a:modules_tree.root_id
	endif

	let c_dir = s:GITLOG_MakeDirectoryQuick(a:path, a:parent_item, a:recursive)

	" now walk the new directory and build transverse the children
	for item in s:directory_list[c_dir]

		if item.type == 'tree' || item.type == 'commit' || item.type == 'link' || item.type == 'git'
			let new_path = a:path . item.name . '/'

			" Do we have a safe link or is it recursive?
			let full_path = fnamemodify(resolve(new_path),':p')
			let full_new = fnamemodify(new_path,':p')

			if item.type == 'link' && (stridx(full_new, full_path) == 0 || stridx(full_path, full_new) == 0)
				let check_item = 0
				let item.no_follow = 1
			else
				let check_item = 1
			endif

			if index(g:GITLOG_ignore_directories, item.name) == -1
				" Lets check for directory items
				let new_path = a:path . item.name . '/'

				" Is it part of the submodule path?
				if a:modules_tree != {} && has_key(a:modules_tree.items, item.name)
					let module_down = a:modules_tree.items[item.name]
				else
					let module_down = {}
				endif

				if a:recursive == 1
					" Do we need to check the files in the sub_directory.
					if check_item == 1
						let item.child = s:GITLOG_BuildFullTree(new_path, item, a:recursive, module_down)
					endif

					" If the sub is changed then we have changed (and the parent has changed).
					let item.status = g:GITLOG_directory_default
				endif

				" The state could be changed by build tree
				if item.marker != s:GITLOG_Same
					let result = s:GITLOG_Changed
				endif
			endif
		else
			" Lets handle file items
			if item.marker != s:GITLOG_Same
				let result = s:GITLOG_Changed
			endif
		endif
	endfor

	if a:parent_item.marker == s:GITLOG_Same
		let a:parent_item.marker = result
	endif

	return c_dir
endfunction																"}}}
" FUNCTION: GITLOG_OpenTreeToFile()		 				 					{{{
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
	let found_item = {'root_id':1, 'marker':s:GITLOG_Same, 'child':1, 'name':'root', 'type': 'root', 'status':g:GITLOG_directory_default , 'items':{}, 'lnum':-1}

	if (len(components) == 1 && components[0] == a:file_path)
		let components = split(a:file_path,"\\")
	endif

	if (len(components) > 1)
		let new_path = ''
		for component in components
			let found = 0

			" now search the directory
			for item in s:directory_list[curent_directory]
				if item.name ==# component
					" found it
					let found_item = item
					let curent_directory = item.child
					let found = 1

					if found_item.type == 'tree' || found_item.type == 'commit' || found_item.type == 'link' || found_item.type == 'git'
						let item.status = 'open'
					endif

					break
				endif
			endfor

			let new_path = new_path . component . "/"

			" open the sub-directory if we need too
			if found_item != {} && found_item.child == 0 && (found_item.type == 'tree' || found_item.type == 'commit' || found_item.type == 'link' || found_item.type == 'git')
				" now re-create the item
				let found_item.child = s:GITLOG_BuildFullTree(new_path, found_item, g:GITLOG_walk_full_tree, s:GITLOG_FindTreeElement(s:submodule_tree,new_path))

				if g:GITLOG_walk_full_tree == 0
					" Do the partial update of the directory only - for speed.
					call s:GITLOG_GitUpdateDirectory(new_path, found_item)

				else
					" Do the recursive item update
					call s:GITLOG_MapGitChanges(s:GITLOG_FindTreeElement(s:GITLOG_GetGitFullChangeTree(), new_path), found_item)
				endif

				let curent_directory = found_item.child

				if curent_directory == 0
					break
				endif
			endif

			" did we find it?
			if found == 0
				break
			endif
		endfor
	endif

	return found_item

endfunction																"}}}
" FUNCTION: GITLOG_DoTreeReBuild()										{{{
"
" This function will rebuild the tree and map the files and status from
" git to the tree.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:GITLOG_DoTreeReBuild()
	let root_item = {'root_id':1, 'marker':s:GITLOG_Same, 'child':1, 'name':'root', 'type': 'root', 'status':g:GITLOG_directory_default , 'items':{}, 'lnum':1}

	if g:GITLOG_walk_full_tree == 1
		echohl WarningMsg
		if s:is_repo
			echomsg "Walking full repo tree - this will take a while."
		else
			echomsg "Walking full tree - this might take a while."
		endif
		echohl Normal
	endif

	let s:submodule_tree = s:GITLOG_MapSubmodules()

	let s:tree_root = s:GITLOG_BuildFullTree(s:repository_root, root_item, g:GITLOG_walk_full_tree, s:submodule_tree)
	let root_item.root_id = s:tree_root

	if g:GITLOG_walk_full_tree == 0
		" Do the partial update of the directory only - for speed.
		call s:GITLOG_GitUpdateDirectory(s:repository_root, root_item)

	else
		" DO the full tree update
		let git_tree = s:GITLOG_GetGitFullChangeTree()
		call s:GITLOG_MapGitChanges(git_tree, root_item)
	endif
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

	" update the tree window - as it is empty
	if len(s:directory_list) == 1

		call s:GITLOG_DoTreeReBuild()

		let s:current_root = s:tree_root
	endif

	" do we need to open a directory
	if s:revision_path != ''
		let found_item = s:GITLOG_OpenTreeToFile(s:revision_path)
	endif

	" set the keys on the tree window
	mapclear <buffer>
	map <buffer> <silent> <cr>	:call GITLOG_ActionSelectCurrentItem()<cr>
	map <buffer> <silent> l		:call GITLOG_ActionOpenLocalFile()<cr>
	map <buffer> <silent> p	    :call GITLOG_ActionOpenHistoryItem()<cr>
	map <buffer> <silent> d		:call GITLOG_ActionOpenDiffFile()<cr>
	map <buffer> <silent> r		:call GITLOG_ActionRefreshCurrentNode()<cr>
	map <buffer> <silent> R		:call GITLOG_ActionRefreshRootDirectory()<cr>
	map <buffer> <silent> C		:call GITLOG_ActionToggleShowChanges()<cr>
	map <buffer> <silent> h		:call GITLOG_ActionShowItemHistory()<cr>
	map <buffer> <silent> a		:call GITLOG_ActionOpenTree()<cr>
	map <buffer> <silent> A		:call GITLOG_ActionOpenAllTree()<cr>
	map <buffer> <silent> x		:call GITLOG_ActionCloseTree()<cr>
	map <buffer> <silent> X		:call GITLOG_ActionCloseAllTree()<cr>
	map <buffer> <silent> T		:call GITLOG_FlipWindows()<cr>
	map <buffer> <silent> b		:call GITLOG_ActionToggleBranch()<cr>
	map <buffer> <silent> s		:call GITLOG_ActionToggleHidden()<cr>
	map <buffer> <silent> <c-d>	:call GITLOG_CloseDiffBuffers()<cr>
	map <buffer> <silent> <c-h>	:call GITLOG_ResetCommit()<cr>
	map <buffer> <silent> <c-l>	:call GITLOG_LastestCommit()<cr>
	map <buffer> <silent> ?		:call GITLOG_ToggleHelp()<cr>
	map <buffer> <silent> ]a	:call GITLOG_ActionGotoChange(1, g:GITLOG_WALK_FORWARDS)<cr>
	map <buffer> <silent> [a	:call GITLOG_ActionGotoChange(1, g:GITLOG_WALK_BACKWARDS)<cr>
	map <buffer> <silent> ]c	:call GITLOG_ActionGotoChange(0, g:GITLOG_WALK_FORWARDS)<cr>
	map <buffer> <silent> [c	:call GITLOG_ActionGotoChange(0, g:GITLOG_WALK_BACKWARDS)<cr>

	" now update the window
	if !has_key(found_item, "lnum")
		let found_item.lnum = 2
	endif

	call s:GITLOG_OpenBranchWindow()
	call s:GITLOG_RedrawTreeWindow(found_item.lnum)

	" if opening tree to file, we wont know the line number till after the redraw.
	call setpos('.',[0,found_item.lnum,0,0])

	let s:gitlog_loaded = 2

	return 1
endfunction																	"}}}
" FUNCTION: GITLOG_RedrawTreeWindow()										{{{
"
" This function will redraw the tree window.
" vars:
"	none
"
" returns:
"	nothing
"
function! s:GITLOG_RedrawTreeWindow(lnum)
	"need to change the window
	setlocal modifiable
	let temp = @"
	silent exe "% delete"
	let @" = temp

	if s:help == 0
		let title = [ 'commit: ' . s:gitlog_current_commit ]
	else
		let title = s:tree_help + [ 'commit: ' . s:gitlog_current_commit ]
	endif

	if a:lnum <= len(title)
		let line_num = len(title) + 1
	else
		let line_num = a:lnum
	endif

	setlocal modifiable
	call setline(1,s:GITLOG_UpdateTreeWindow(title, s:repository_root, s:current_root,''))
	call setpos('.',[0,line_num,0,0])
	setlocal nomodifiable

	echo ""
	redraw
endfunction																	"}}}
" FUNCTION: GITLOG_RedrawLogWindow()										{{{
"
" This function will redraw the log window.
" vars:
"	none
"
" returns:
"	nothing
"
function! s:GITLOG_RedrawLogWindow(lnum)
	"need to change the window
	setlocal modifiable
	let temp = @"
	silent exe "% delete"
	let @" = temp

	if s:git_history == []
		let s:git_history = ['no history found']
	endif

	if s:help == 0
		call setline(1,[ s:history_title ] + s:git_history)
		let line_num = a:lnum + 1
	else
		call setline(1,s:log_help  + [ s:history_title ] + s:git_history)
		if a:lnum > len(s:log_help) + 1
			let line_num = a:lnum + 1
		else
			let line_num = len(s:log_help) + 2
		endif
	endif

	call setpos('.',[0,line_num,0,0])
	setlocal nomodifiable

	echo ""
	redraw
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
function! s:GITLOG_OpenLogWindow(parameter)
	if bufwinnr(bufnr("__gitlog__")) != -1
		" window already open - just go to it
		silent exe bufwinnr(bufnr("__gitlog__")) . "wincmd w"
		setlocal modifiable
		let temp = @"
		silent exe "% delete"
		let @" = temp
		setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap
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

	if type(a:parameter) == type(0)
		" Numeric value, it is a line number - we have a tree item reference
		let s:found_path = ''
		let found_item = s:GITLOG_FindListItem(s:current_root, a:parameter)
		let s:history_item = found_item

		if found_item == {}
			let file_bit = ''
			let s:history_root = 1
			let s:history_title = 'branch: ' . s:gitlog_current_branch
			let s:history_file = ''

		else
			" root the item to the base of the directory root
			let file_bit = '-- ' . substitute(fnamemodify(s:found_path . found_item.name,':p'), s:root_list[found_item.root_id].root_dir,"","")
			let s:history_root = found_item.root_id
			let s:history_title = 'file: ' . found_item.name
			let s:history_file = s:found_path . found_item.name

		endif

	elseif type(a:parameter) == type("")
		" Its a string, so it is a file_path and we can open it.
		let s:history_title = 'file: ' . fnamemodify(a:parameter,':h')
		let file_bit = '-- ' . expand(a:parameter)
		let s:history_root = 1
		let s:history_item = {}
		let s:history_file = a:parameter
	endif

	" get the history
	let s:git_history = split(s:GITLOG_ExecuteGitCommand(s:history_root, "rev-list " . s:gitlog_current_ref . " --oneline --graph " . file_bit), '[\x00]')

	call s:GITLOG_RedrawLogWindow(1)

	" set the keys on the Log window
	call s:GITLOG_MapLogBufferKeys()
	call s:GITLOG_OpenBranchWindow()

	let s:gitlog_log_file = a:parameter
	let s:gitlog_loaded = 1

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
	if g:GITLOG_show_branch_window
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
		let gitbranch_history = s:GITLOG_ExecuteGitCommand(1, "branch -v")
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
	endif
endfunction																"}}}
" FUNCTION:	GITLOG_LoadRevisionFile(revision)							{{{
"
" This function will open the specified revision in the current window. It
" will get the revision from Git and then load it into the current window.
"
" vars:
"   git_dir		the git directory
"	commit		the commit number to diff against
"	file_name	the file path to diff.
"
" returns:
"	nothing
"
function! s:GITLOG_LoadRevisionFile(git_dir,commit,file_name)
	let gitlog_file = s:GITLOG_ExecuteGitCommand(1, "show " . s:GITLOG_MakeRevision(a:commit,a:file_name))

	" now write the captured text to the a new buffer - after removing
	" the \x00's from the text and splitting into an array.
	let git_array = split(gitlog_file,'[\x00]')
	call setline(1,git_array)
	setlocal buftype=nofile bufhidden=wipe nobuflisted nomodifiable noswapfile nowrap

	" we can't (don't want to) change the historical commit
	setlocal nomodifiable
endfunction																"}}}
" FUNCTION: GITLOG_LocateRespositoryRoot(filename)								{{{
"
" This function will search the tree UPWARDS and downwards to find the git
" repository that the file belongs to. If it cannot find the repository then it
" will generate an error and then return an empty string. It will use the given
" filename to start the search from. If the ".git" is a file and not a directory
" then it will assume that it is a submodule and return the "gitdir" line from
" within that file.
"
" vars:
"	filename	The file to get the repository root from.
"
" returns:
"	If there is a .git directory in the tree, it returns the directory that the .git
"	repository is in, else it returns the empty string.
"
function! s:GITLOG_LocateRespositoryRoot(filename)
	let root_file = findfile(".git",fnamemodify(a:filename,':p:h') . ";" . $HOME)

	if (root_file == '')
		let root = finddir(".git",fnamemodify(a:filename,':h'). "," . fnamemodify(a:filename,':p:h') . ";" . $HOME)
	else
		" Ok, we have a submodule - need to extract the git_dir root
		let root = s:GITLOG_GetSubModuleDir(root_file)
	endif

	return root
endfunction																	"}}}
" FUNCTION:	GITLOG_MakeRevision(commit,file_path)							{{{
"
" This function will make a revision string that can be passed to the git functions.
"
" vars:
"	commit			the commit number to diff against
"	file_path		the file path to diff.
"
" returns:
"	the revision string with a correct file path.
"
function! s:GITLOG_MakeRevision(commit,file_path)
	let git_dir = s:GITLOG_LocateRespositoryRoot(a:file_path)

	if git_dir[:-5] == ".git"
		let revision = escape(a:commit . ":" . fnamemodify(a:file_path,":p"),"#")
	else
		" Ok, get the root again, and remove the .git - then remove that from the path
		let here = findfile(".git",fnamemodify(a:file_path,':p:h') . ";" . $HOME)[:-5]

		if a:file_path[0] == '/' || a:file_path[0] == '\'
			let filename = substitute(a:file_path,fnamemodify(here,':p'),"","")
		else
			let filename = substitute(a:file_path,here,"","")
		endif
		let revision = escape(a:commit . ":" . filename,"#")
	endif

	return revision
endfunction																	"}}}
" FUNCTION:	GITLOG_OpenDiffWindow(commit,file_path,...)						{{{
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
"	found_item		the item that is too be opened.
"
" returns:
"	nothing
"
function! s:GITLOG_OpenDiffWindow(commit, file_path, found_item)
	let buffname = escape(a:commit . ":" . fnamemodify(a:file_path,":t"),"#")

	" has the main diff file changed?
	if s:last_diff_path !=# a:file_path
		call GITLOG_CloseDiffBuffers()
	endif

	if a:found_item == {}
		let file_root_path = s:repository_root . a:file_path
	else
		let file_root_path = s:root_list[a:found_item.root_id].root_dir . a:file_path
	endif

	if (a:found_item != {} && a:found_item.marker == s:GITLOG_Deleted) || glob(file_root_path) == ''
		echohl WarningMsg
		echomsg "File does not exist in the current filesystem - cannot diff" . " " . file_root_path
		echohl Normal
	else
		call s:GITLOG_OpenWindowWithFile(file_root_path)
		let file_type = &filetype
		diffthis

		" Create the new window and buffer (and remove any auto text from files)
		exe "silent rightbelow vnew"
		let buf_number = bufnr(buffname, 1)
		silent exe "buffer " . buf_number
		setlocal modifiable
		silent 0,$del

		" add the new buffer to the list of buffers in this diff
		call add(s:diff_buffer_list,buffname)

		" Do we know where we are?
		if a:found_item == {}
			let gitlog_file = s:GITLOG_ExecuteGitCommand(1, "show " . s:GITLOG_MakeRevision(a:commit,a:file_path))
		else
			let path = substitute(file_root_path, s:root_list[a:found_item.root_id].root_dir, '', '')
			let gitlog_file = s:GITLOG_ExecuteGitCommand(a:found_item.root_id, "show " . s:GITLOG_MakeRevision(a:commit,path))
		endif

		" now write the captured text to the a new buffer - after removing
		" the \x00's from the text and splitting into an array.
		let git_array = split(gitlog_file,'[\x00]')
		call setline(1,git_array)
		setlocal buftype=nofile bufhidden=wipe nobuflisted nomodifiable noswapfile nowrap
		diffthis
		exe "setlocal filetype=" . file_type

		" we can't (don't want to) change the historical commit
		setlocal nomodifiable

		" lets move back to the log_window - don't have to find the cursor (and lets me fix the wrap issue)
		silent exe bufwinnr(bufnr("__gitlog__")) . "wincmd w"
		setlocal buftype=nofile bufhidden=wipe nobuflisted nomodifiable noswapfile nowrap

		if s:last_diff_path !=# a:file_path && s:last_diff_path != ''
			if winnr("$") > 2 && bufwinnr(bufnr(s:last_diff_path)) != -1
				" close the window with the other file.
				exe bufwinnr(bufnr(s:last_diff_path)) . "wincmd c"
				let s:last_diff_path = ''
			endif
		endif

		let s:last_diff_path = a:file_path
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
function! s:GITLOG_OpenCodeWindow(commit,file_path,found_item)
	let buffname = a:commit . ":" . fnamemodify(a:file_path,":t")

	if bufwinnr(bufnr(buffname)) != -1
		" window already open - just go to it
		exe bufwinnr(bufnr(buffname)) . "wincmd w"
	else
		" Do we know where we are?
		if a:found_item == {}
			let gitlog_file = s:GITLOG_ExecuteGitCommand(1, "show " . s:GITLOG_MakeRevision(a:commit,a:file_path))
		else
			let path = substitute(fnamemodify(a:file_path, ':p'), s:root_list[a:found_item.root_id].root_dir, '', '')
			let gitlog_file = s:GITLOG_ExecuteGitCommand(a:found_item.root_id, "show " . s:GITLOG_MakeRevision(a:commit,path))
		endif

		call GITLOG_CloseDiffBuffers()
		call s:GITLOG_OpenWindowWithContents(buffname, split(gitlog_file,'[\x00]'))
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
			let search_result = s:GITLOG_ExecuteGitCommand(s:history_root,"grep -n -F '" . search_string . "'" . s:selected_commits)

			if search_result == ''
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
						let select_window = s:GITLOG_FindUsefulWindow()

						if select_window == -1
							" Opps, no window found - lets goto the __gitlog__ window and
							" then go left - is this does not work then users issue. :)
							exe "silent " . bufwinnr(bufnr('__gitlog__')) . "wincmd w"
							exe "silent rightbelow vsplit"
						else
							" Ok, goto the selected window
							exe "silent " . select_window . "wincmd w"
						endif

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
function! GITLOG_GetBranch(...)
	if a:0 == 0
		let use_branch = s:repository_root . ".git"
	else
		let use_branch = a:1
	endif

	let bname = ''
	let branches = s:GITLOG_ExecuteGitCommand(1,"branch")

	for branch in split(branches)
		if branch[0] == '*'
			" Found it

			let bname = branch[2:]

			" if on a detached head then use he commit hash as the branch number
			if bname == "(no branch)"
				let bname = s:GITLOG_ExecuteGitCommand(1, 'rev-list --branches -1 --abbrev-commit ' . s:gitlog_current_commit)
			endif

			break
		endif
	endfor

	return bname
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
" FUNCTION: GITLOG_AddDirectoryItem()										{{{
"
" This function will add and item to the directory structure.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:GITLOG_AddDirectoryItem(directory, marker, type, name, hash, parent_item)
	if a:type == 'blob'
		let add = index(g:GITLOG_ignore_suffixes, fnamemodify(a:name, ":e")) == -1
	else
		let add = index(g:GITLOG_ignore_directories, a:name) == -1
	endif

	if (add)
		let new_item = {	'name'		: a:name,
						\	'status'	: 'closed',
						\   'marker'	: a:marker,
						\	'type'		: a:type,
						\	'root_id'	: a:parent_item.root_id,
						\	'child'		: 0,
						\	'parent'	: a:parent_item}

		call add(a:directory,new_item)
	endif
endfunction																	"}}}
" FUNCTION: GITLOG_MakeDirectoryQuick(path_name,repository_root)			{{{
"
" This function does a quick directory generation it does not do any references
" against git and just build creates the directory. It assumes that non of the
" files have changed.
"
" vars:
"	path_name		The directory to add to the tree.
"	repository_root	The .git dir that the tree item belongs in.
"	parent_item		The item that this item belongs to.
"
" returns:
"	nothing
"
function! s:GITLOG_MakeDirectoryQuick(path_name, parent_item, recursive)
	" Get the dot files and remove '.' and '..'
	let dot_files = expand(a:path_name . '.*',1,1)[2:]

	let local_files = expand(a:path_name . '*',1,1)

	if len(local_files) == 1 && (local_files[0] == '\\\\\\\*' || local_files[0] == a:path_name . '*')
		let local_files = []
	endif

	let current_dir =  dot_files + local_files

	let new_directory = []

	for item in current_dir
			let name = fnamemodify(item,":t")

			if isdirectory(a:path_name . name)
				if getftype(a:path_name . name) == 'link'
					let local_type = 'link'

				elseif g:GITLOG_support_sub_git && name ==# '.git' && a:parent_item.type != 'root'
					let local_type = 'tree'

					" add the new root to the list
					let a:parent_item.type = 'git'
					let a:parent_item.root_id = len(s:root_list)
					call add(s:root_list,{'git_dir': fnamemodify(a:path_name . name . '/', ':p'), 'root_dir': fnamemodify(a:path_name, ':p')})
				else
					let local_type = 'tree'
				endif
			else
				let local_type = 'blob'
			endif

			call s:GITLOG_AddDirectoryItem(new_directory, s:GITLOG_Same, local_type, name, '0', a:parent_item)
	endfor

	call add(s:directory_list,new_directory)
	let result = len(s:directory_list) - 1

	return result
endfunction																	"}}}
" FUNCTION: GITLOG_AddSubmoduleItem()										{{{
"
" This function will add the submodule item to the current directory tree. It
" will mark a tree item as a sub-module if it finds one else it will add a
" new tree item and mark it as a sub-module.
"
" vars:
"   none
"
" returns:
"	nothing
"
function! s:GITLOG_AddSubmoduleItem(path_items, dir_item, submodule_path)
	let item_idx = 0

	while item_idx  < len(s:directory_list[a:dir_item.child])
		let item = s:directory_list[a:dir_item.child][item_idx]

		if item.name >=# a:path_items[0]
			" Ok, found the item.
			if item.name ==# a:path_items[0] && item.type == 'tree'
				" Ok, it is found and the correct type - make it a submodule
				if len(a:path_items) == 1
					let item.type = 'commit'
					let item.root_id = s:GITLOG_GetSubModuleDetails(a:submodule_path . '/')
				else
					call s:GITLOG_AddSubmoduleItem(a:path_items[1:], item, a:submodule_path)
				endif
			else
				" Need to insert a new-item.
				let new_item = {	'name'		: a:path_items[0],
								\	'status'	: 'closed',
								\   'marker'	: s:GITLOG_Added,
								\	'type'		: 'commit',
								\	'root_id'	: a:dir_item.root_id,
								\	'child'		: 0,
								\	'parent'	: a:dir_item}

				let item.root_id = s:GITLOG_GetSubModuleDetails(a:submodule_path . '/')
				call insert(s:directory_list[a:dir_tree.child], new_item, item_idx)
			endif

			break
		endif

		let item_idx = item_idx + 1
	endwhile

endfunction																	"}}}
" FUNCTION: GITLOG_FindTreeElement()										{{{
"
" This function will find an element in the tree.
"
" vars:
"   none
"
" returns:
"	The item if found, else returns an empty dictionary.
"
function! s:GITLOG_FindTreeElement(root_item, item_path)
	let result = a:root_item
	if result != {}
		let path_parts = split(a:item_path[:-2], '/')

		" walk down the tree to find element
		for part in path_parts
			if has_key(result.items, part)
				let result = result.items[part]
			else
				let result = {}
				break
			endif
		endfor
	endif

	return result
endfunction																	"}}}
" FUNCTION: GITLOG_AddElementToTree()										{{{
"
" This function will add an element to the tree.
"
" vars:
"   none
"
" returns:
"	nothing
"
function! s:GITLOG_AddElementToTree(root_item, status, item_path, root_id)
	let path_parts = split(a:item_path, '/')
	let last_dir = a:root_item

	" now add the element to the tree.
	if len(path_parts) > 1
		for part in path_parts[ : -2]
			if has_key(last_dir.items, part)
				let last_dir = last_dir.items[part]

				if last_dir.status == s:GITLOG_Added && a:status != s:GITLOG_Added
					let last_dir.status = s:GITLOG_Changed
				endif
			else
				let last_dir.items[part] = { 'type':'D' , 'status': a:status, 'items': {}, 'root_id': a:root_id }
				let last_dir = last_dir.items[part]
			endif
		endfor
	endif


	if isdirectory(s:repository_root . a:item_path)
		let last_dir.items[path_parts[-1]] = { 'type': 'D', 'status': a:status, 'items':{}, 'root_id': a:root_id  }
	else
		let last_dir.items[path_parts[-1]] = { 'type': 'b', 'status': a:status, 'items':{}, 'root_id': a:root_id  }
	endif
endfunction																	"}}}
" FUNCTION: GITLOG_MapSubmodules()											{{{
"
" This function gets the current submodules from the git index and maps these
" onto the directory tree.
"
" vars:
"   none
"
" returns:
"	nothing
"
function! s:GITLOG_MapSubmodules()
	let submodule_list = split(s:GITLOG_ExecuteGitCommand(1,"submodule status"), '\n')
	let root_item = {'root_id':1, 'marker':s:GITLOG_Same, 'child':1, 'name':'root', 'type': 'root', 'status':g:GITLOG_directory_default , 'items':{}, 'lnum':-1}

	for submodule in submodule_list
		let parts = split(submodule)
		let root_id = s:GITLOG_GetSubModuleDetails(parts[1] . '/')

		if root_id > 1
			" Only add it if we found an actual new root
			call s:GITLOG_AddElementToTree(root_item, s:GITLOG_Same, parts[1], root_id)
		endif
	endfor

	return root_item
endfunction																	"}}}
" FUNCTION: GITLOG_GetGitFullChangeTree()									{{{
"
" This function gets the change tree for the all the directories and submodule
" directories that have been found.
"
" vars:
"   none
"
" returns:
"	nothing
"
function! s:GITLOG_GetGitFullChangeTree()
	let dir_id = 1
	let root_item = {'type':"root", 'status': s:GITLOG_Same, 'items': {}}

	while dir_id < len(s:root_list)
		" If repo - the root[1] == the .repo root and is not a .git directory.
		if s:is_repo == 0 || dir_id != 1
			let root_item.root_id = dir_id
			call s:GITLOG_GetGitChangeTree(dir_id, root_item)
		endif
		let dir_id = dir_id + 1
	endwhile

	return root_item
endfunction																	"}}}
" FUNCTION: GITLOG_HandleSame()												{{{
"
" This function will do the things are are required for the GitUpdateDirectory
" when it finds two items that are the same.
"
" vars:
"   none
"
" returns:
"	nothing
"
function! s:GITLOG_HandleSame(directory_status, path_offset, item_name, dir_item)
	" Ok, same file exists in both
	if len(a:directory_status) > 0
		if a:dir_item.type != 'blob'
			" For directories we have to search manually
			let name = a:path_offset . a:item_name . '/'

			for status_item in a:directory_status
				if name[:-2] == status_item || status_item[:len(name)-1] == name
					let a:dir_item.marker = s:GITLOG_Changed
					break
				endif
			endfor
		elseif index(a:directory_status, a:path_offset . a:item_name) != -1
			" For items let vim take the strain
			let a:dir_item.marker = s:GITLOG_Changed
		endif
	endif
endfunction																	"}}}
" FUNCTION: GITLOG_GitUpdateDirectory()										{{{
"
" This function will update the current item with the changes from the git
" directory.
"
" vars:
"   none
"
" returns:
"	nothing
"
function! s:GITLOG_GitUpdateDirectory(path, dir_item)
	let file_list = []
	let lookup = []

	if s:is_repo == 0 || a:dir_item.root_id != 1
		let path_offset = substitute( s:GITLOG_GetFilePath(a:dir_item) . '/', s:root_list[a:dir_item.root_id].root_dir, '', '')

		" Ok, we need to get what files git thinks is in the current directory
		if s:gitlog_current_commit == 'HEAD' || s:gitlog_current_commit != s:gitlog_current_branch
			let status = split(s:GITLOG_ExecuteGitCommand(a:dir_item.root_id, "ls-tree -t -l --abbrev " . s:gitlog_current_commit . ':' . path_offset), '\n')
		else
			let status = split(s:GITLOG_ExecuteGitCommand(a:dir_item.root_id, "ls-tree -t -l --abbrev refs/heads/" . s:gitlog_current_commit . ':' . path_offset), '\n')
		endif

		let git_files = []
		let git_types = []
		for item in status
			call add(git_files, item[strridx(item, "\t")+1 :])
			call add(git_types, item[7:11])
		endfor

		" Ok, let essentially do an insertion sort to handle the missing items.
		let git_id = 0
		let fs_id = 0
	
		let paths = join(map(copy(git_files), 'path_offset . v:val'))
		if s:gitlog_current_commit == 'HEAD' || s:gitlog_current_commit != s:gitlog_current_branch
			let directory_status = split(s:GITLOG_ExecuteGitCommand(a:dir_item.root_id, "diff-index --name-only --diff-filter=M " . s:gitlog_current_commit . " -- " . paths),'\n')
		else
			" avoid the "is it a tag or branch message"
			let directory_status = split(s:GITLOG_ExecuteGitCommand(a:dir_item.root_id, "diff-index --name-only --diff-filter=M refs/heads/" . s:gitlog_current_branch . " -- " . paths),'\n')
		endif

		while git_id < len(git_files) && fs_id < len(s:directory_list[a:dir_item.child])
			if git_files[git_id] ==# s:directory_list[a:dir_item.child][fs_id].name
				call s:GITLOG_HandleSame(directory_status, path_offset, git_files[git_id], s:directory_list[a:dir_item.child][fs_id])

				let git_id = git_id + 1
				let fs_id = fs_id + 1

			elseif git_files[git_id] ># s:directory_list[a:dir_item.child][fs_id].name
				" Not in the git repo - so mark as added.
				let item_idx = index(git_files, s:directory_list[a:dir_item.child][fs_id].name)
				if  item_idx != -1
					" The two trees are subtly in different sort orders, git has a length
					" factored in, so look in the other list to see if it exists. This should
					" be quicker that always sorting the list into the same sort order.
					call s:GITLOG_HandleSame(directory_status, path_offset, git_files[item_idx], s:directory_list[a:dir_item.child][fs_id])
					call remove(git_files, item_idx)
					let fs_id = fs_id + 1
				else
					let s:directory_list[a:dir_item.child][fs_id].marker = s:GITLOG_Added
					let fs_id = fs_id + 1
				endif
			else
				" Need to insert a new-item.
				let new_item = {	'name'		: git_files[git_id],
								\	'status'	: 'closed',
								\   'marker'	: s:GITLOG_Deleted,
								\	'type'		: git_types[git_id],
								\	'root_id'	: a:dir_item.root_id,
								\	'child'		: 0,
								\	'parent'	: a:dir_item}

				call insert(s:directory_list[a:dir_item.child], new_item, fs_id)

				let fs_id = fs_id + 1
				let git_id = git_id + 1
			endif
		endwhile

		while git_id < len(git_files)
			let new_item = {	'name'		: git_files[git_id],
							\	'status'	: 'closed',
							\   'marker'	: s:GITLOG_Deleted,
							\	'type'		: git_types[git_id],
							\	'root_id'	: a:dir_item.root_id,
							\	'child'		: 0,
							\	'parent'	: a:dir_item}

			call insert(s:directory_list[a:dir_item.child], new_item)

			let git_id = git_id + 1
		endwhile

		while fs_id < len(s:directory_list[a:dir_item.child])
			let s:directory_list[a:dir_item.child][fs_id].marker = s:GITLOG_Added
			let fs_id = fs_id + 1
		endwhile
	endif
endfunction																	"}}}
" FUNCTION: GITLOG_GetGitChangeTree()										{{{
"
" This function gets the current git status for the current device. It will
" then map the status to the current tree.
"
" vars:
"   none
"
" returns:
"	nothing
"
function! s:GITLOG_GetGitChangeTree(root_id, root_item)
	" Actually just change status to git-diff --name-status works with the current head.

	let status_report = split(s:GITLOG_ExecuteGitCommand(a:root_id, "ls-files -vmdo --full-name " . s:gitlog_current_commit . " " . s:root_list[a:root_id].root_dir), '\n')
	let path_offset = substitute(s:root_list[a:root_id].root_dir, s:repository_root, '', '')

	for item in status_report
		" What is the status of the item?
		if item[0] == 'C'
			let status = s:GITLOG_Changed
		elseif item[0] == 'R'
			let status = s:GITLOG_Deleted
		elseif item[0] == '?' || item[0] == 'A'
			let status = s:GITLOG_Added
		else
			let status = s:GITLOG_Unknown
		endif

		call s:GITLOG_AddElementToTree(a:root_item, status, path_offset . item[2:-1], a:root_id)
	endfor
endfunction																	"}}}
" FUNCTION: GITLOG_MapGitChanges()											{{{
"
" This function gets the current git status for the current device. It will
" then map the status to the current tree.
"
" vars:
"   none
"
" returns:
"	nothing
"
function! s:GITLOG_MapGitChanges(git_change_tree, parent_item)
	for item in keys(a:git_change_tree.items)
		let found = 0
		let item_id = 0

		while item_id < len(s:directory_list[a:parent_item.child])
			let entry = s:directory_list[a:parent_item.child][item_id]
			if entry.name ==# item
				" If it is the leaf, carry on the search
				if a:git_change_tree.items[item].type == 'D'
					call s:GITLOG_MapGitChanges(a:git_change_tree.items[item], entry)
					if (entry.marker == s:GITLOG_Same && a:git_change_tree.items[item].status == s:GITLOG_Added)
						let entry.marker = s:GITLOG_Added
					else
						let entry.marker = s:GITLOG_Changed
					endif
				else
					let entry.marker = a:git_change_tree.items[item].status
				endif
	
				let entry.root_id = a:git_change_tree.items[item].root_id
				let found = 1
				break

			elseif item <# entry.name
				" Ok, we have gone past where it should be in the test. Lets add it in.
				if (a:git_change_tree.items[item].type != 'D' && index(g:GITLOG_ignore_suffixes, fnamemodify(item,':e')) == -1) ||
				\  (a:git_change_tree.items[item].type == 'D' && index(g:GITLOG_ignore_directories, item) == -1)
					let new_item = {	'name'		: item,
									\	'status'	: g:GITLOG_directory_default,
									\   'marker'	: a:git_change_tree.items[item].status,
									\	'type'		: 'tree',
									\	'root_id'	: a:git_change_tree.items[item].root_id,
									\	'child'		: 0,
									\	'parent'	: a:parent_item}

					call insert(s:directory_list[a:parent_item.child], new_item, item_id)

					if index(g:GITLOG_ignore_suffixes, fnamemodify(item,':e')) != -1
						echomsg "Found:" . a:git_change_tree.items[item].status
					endif

					if a:git_change_tree.items[item].type == 'D'
						call add(s:directory_list, [])
						let new_item.child = len(s:directory_list) - 1
						call s:GITLOG_MapGitChanges(a:git_change_tree.items[item], new_item)
					else
						let new_item.type = 'blob'
					endif
				endif

				let found = 1
				break
			endif

			let item_id = item_id + 1
		endwhile

		if found == 0
			if (a:git_change_tree.items[item].type != 'D' && index(g:GITLOG_ignore_suffixes, fnamemodify(item,':e')) == -1) ||
			\  (a:git_change_tree.items[item].type == 'D' && index(g:GITLOG_ignore_directories, item) == -1)
				let new_item = {	'name'		: item,
								\	'status'	: g:GITLOG_directory_default,
								\   'marker'	: a:git_change_tree.items[item].status,
								\	'type'		: 'tree',
								\	'root_id'	: a:git_change_tree.items[item].root_id,
								\	'child'		: 0,
								\	'parent'	: a:parent_item}

				" item was not found - must have been deleted add it the list
				call add(s:directory_list[a:parent_item.child], new_item)
				if a:git_change_tree.items[item].type == 'D'
					call add(s:directory_list, [])
					let new_item.child = len(s:directory_list) - 1
					call s:GITLOG_MapGitChanges(a:git_change_tree.items[item], new_item)
				else
					let new_item.type = 'blob'
				endif
			endif
		endif
	endfor
endfunction																	"}}}
" FUNCTION: GITLOG_OpenAllTreeDirectories()									{{{
"
" This function will open the tree window items. It will respect the
" current settings of the g:GITLOG_show_only_changes, which will make this
" feature actually usable on large trees.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:GITLOG_OpenAllTreeDirectories(dir_id)
	for item in s:directory_list[a:dir_id]
		if item.type == 'tree' || item.type == 'commit' || item.type == 'link' || item.type == 'git'
			if g:GITLOG_show_only_changes == 0 || item.marker != s:GITLOG_Same
				let item.status = 'open'

				if item.type != 'link' || !has_key(item, 'no_follow') || item.no_follow == 0
					call s:GITLOG_OpenAllTreeDirectories(item.child)
				endif
			endif
		endif
	endfor
endfunction																	"}}}
" FUNCTION: GITLOG_CloseAllTreeDirectories()								{{{
"
" This function will close the tree recursively and stop when it reaches  the
" first directory that is close. So it wont actually close all directories this
" should give the right level of feature support. (I hope).
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:GITLOG_CloseAllTreeDirectories(dir_id)
	for item in s:directory_list[a:dir_id]
		if item.type == 'tree' || item.type == 'commit' || item.type == 'link' || item.type == 'git'
			if item.status == 'open'
				let item.status = 'closed'
				call s:GITLOG_CloseAllTreeDirectories(item.child)
			endif
		endif

		" This directory is closed, the lnum is -1
		let item.lnum = -1
	endfor
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
	for item in s:directory_list[a:id]
		if g:GITLOG_show_hidden_files == 1 || item.name[0] != '.'
			if item.type == 'tree' || item.type == 'commit' || item.type == 'link' || item.type == 'git'
				let s_marker = ''

				if (item.status == 'closed')
					let marker = s:GITLOG_Closed
				else
					let marker = s:GITLOG_Open
				endif

				if (item.type == 'commit')
					let e_marker = s:GITLOG_SubModule

				elseif (item.type == 'link')
					if has_key(item, 'no_follow') && item.no_follow == 1
						let e_marker = s:GITLOG_BadLink
					else
						let e_marker = s:GITLOG_Link
					endif

				elseif (item.type == 'git')
					let e_marker = s:GITLOG_SubGit

				else
					let e_marker = ''
				endif

				let s_marker = item.marker

				if g:GITLOG_show_only_changes == 0 || item.marker != s:GITLOG_Same
					call add(a:output,a:level . marker . item.name . ' ' . e_marker . s_marker)
					let item.lnum = len(a:output)

					if (item.status == 'open')
						call s:GITLOG_UpdateTreeWindow(a:output, a:directory . item.name . '/', item.child, a:level . '  ')
					endif
				else
					let item.lnum = -1
				endif
			endif
		else
			let item.lnum = -1
		endif
	endfor

	for item in s:directory_list[a:id]
		if g:GITLOG_show_hidden_files == 1 || item.name[0] != '.'
			if item.type != 'tree' && item.type != 'commit' && item.type != 'link' && item.type != 'git'
				let marker = item.marker

				if g:GITLOG_show_only_changes == 0 || item.marker != s:GITLOG_Same
					call add(a:output,a:level . marker . item.name)
					let item.lnum = len(a:output)
				else
					let item.lnum = -1
				endif
			endif
		else
			let item.lnum = -1
		endif
	endfor

	return a:output
endfunction																	"}}}
" FUNCTION: GITLOG_FindListItem()											{{{
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

		elseif item.status == 'open' && item.lnum != -1
			let s:last_open_dir = item
			let result = s:GITLOG_FindListItem(item.child,a:line_number)

			if (result != {})
				let s:found_path = item.name . '/' . s:found_path
				break
			endif
		endif
	endfor

	return result
endfunction																"}}}
" FUNCTION: GITLOG_OpenTreeToItem()											{{{
"
" Open all the  parents to the selected item.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:GITLOG_OpenTreeToItem(item)
	if a:item.parent.type != 'root' && a:item.parent.status == 'closed'
		let a:item.parent.status = 'open'
		call s:GITLOG_OpenTreeToItem(a:item.parent)
	endif
endfunction																    "}}}
" FUNCTION: GITLOG_GetFilePath()										{{{
"
" Get the file path for the item.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:GITLOG_GetFilePath(item)
	if a:item.type == 'root'
		let result = s:root_list[a:item.root_id].root_dir[:-2]
	elseif a:item.parent.type != 'root'
		let result = s:GITLOG_GetFilePath(a:item.parent) . '/' . a:item.name
	else
		let result = s:root_list[a:item.parent.root_id].root_dir . a:item.name
	endif

	return result
endfunction																    "}}}
" FUNCTION: GITLOG_WalkForward()											{{{
"
" This function will find the next item in the tree. If the go up flag
" is set then the walk function will walk up the tree, and will stop when
" it reaches a root node.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:GITLOG_WalkForward(search_object)
	let result = {}

	" TECH_DEBT:
	" The directories are not ordered dirs then files but are in some other
	" order. But they are displayed in dirs then files, so we have to make
	" two passes over the directory first looking for dirs then files. This
	" should really be fixed by changing the order, but that is too big a change.
	if a:search_object.found_item == s:directory_list[a:search_object.current_id][a:search_object.current_item]
		" Starting on the found item - lets skip it
		let a:search_object.current_item = a:search_object.current_item + 1
	endif

	while 1
		let current_item = a:search_object.current_item

		if current_item == len(s:directory_list[a:search_object.current_id])
			if a:search_object.doing_dirs == 1
				let a:search_object.doing_dirs = 0
				let a:search_object.current_item = 0

			else
				" At end of the directory need to go up a level.
				if len(a:search_object.stack) == 0
					break
				else
					" Go back up a level
					let stack_item = remove(a:search_object.stack, -1)
					let a:search_object.current_id = stack_item.current_id
					let a:search_object.current_item = stack_item.current_item + 1
					let a:search_object.doing_dirs = stack_item.doing_dirs
				endif
			endif

		else
			let item = s:directory_list[a:search_object.current_id][current_item]

			if a:search_object.doing_dirs == 1
				if g:GITLOG_show_hidden_files == 1 || item.name[0] != '.' && (item.type == 'tree' || item.type == 'git' || item.type == 'commit')
					" doing down a level
					let stack_item = {	'current_id'	: a:search_object.current_id,
									\	'current_item'	: current_item,
									\	'doing_dirs'	: a:search_object.doing_dirs }

					if item.child == 0 && g:GITLOG_open_sub_on_search == 1
						let file_path = s:GITLOG_GetFilePath(item) . '/'
						let item.child = s:GITLOG_BuildFullTree(file_path, item, 0, s:GITLOG_FindTreeElement(s:submodule_tree, file_path))
						call s:GITLOG_GitUpdateDirectory(file_path, item)
					endif

					let a:search_object.current_id = item.child
					let a:search_object.current_item = 0
					let a:search_object.doing_dirs = 1
					
					call add(a:search_object.stack, stack_item)
				else
					let a:search_object.current_item = current_item + 1
				endif
			else
				if g:GITLOG_show_hidden_files == 1 || item.name[0] != '.' && (item.type == 'blob' && (item.marker == a:search_object.marker || (a:search_object.marker == s:GITLOG_Any && item.marker != s:GITLOG_Same)))
					" We have found what we are looking for
					let result = item
					let a:search_object.found_item = item
					break
				else
					let a:search_object.current_item = current_item + 1
				endif
			endif
		endif
	endwhile

	return result
endfunction																    "}}}
" FUNCTION: GITLOG_WalkBackward()											{{{
"
" This function will find the previous item in the tree. If the "go up" flag
" is set then the walk function will walk up the tree, and will stop when
" it reaches a root node.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:GITLOG_WalkBackward(search_object)
	let result = {}

	" TECH_DEBT:
	" The directories are not ordered dirs then files but are in some other
	" order. But they are displayed in dirs then files, so we have to make
	" two passes over the directory first looking for dirs then files. This
	" should really be fixed by changing the order, but that is too big a change.
	if a:search_object.found_item == s:directory_list[a:search_object.current_id][a:search_object.current_item]
		" Starting on the found item - lets skip it
		let a:search_object.current_item = a:search_object.current_item - 1
	endif

	while 1
		let current_item = a:search_object.current_item

		if current_item == -1
			if a:search_object.doing_dirs == 0
				let a:search_object.doing_dirs = 1
				let a:search_object.current_item = len(s:directory_list[a:search_object.current_id]) - 1

			else
				" At end of the directory need to go up a level.
				if len(a:search_object.stack) == 0
					break
				else
					" Go back up a level
					let stack_item = remove(a:search_object.stack, -1)
					let a:search_object.current_id = stack_item.current_id
					let a:search_object.current_item = stack_item.current_item - 1
					let a:search_object.doing_dirs = stack_item.doing_dirs
				endif
			endif
		else
			let item = s:directory_list[a:search_object.current_id][current_item]

			if a:search_object.doing_dirs == 1
				if g:GITLOG_show_hidden_files == 1 || item.name[0] != '.' && (item.type == 'tree' || item.type == 'git' || item.type == 'commit')
					" doing down a level
					let stack_item = {	'current_id'	: a:search_object.current_id,
									\	'current_item'	: current_item,
									\	'doing_dirs'	: a:search_object.doing_dirs }

					if item.child == 0 && g:GITLOG_open_sub_on_search == 1
						let file_path = s:GITLOG_GetFilePath(item) . '/'
						let item.child = s:GITLOG_BuildFullTree(file_path, item, 0, s:GITLOG_FindTreeElement(s:submodule_tree, file_path))
						call s:GITLOG_GitUpdateDirectory(file_path, item)
					endif

					" start the search at the end of the directory with the files
					let a:search_object.current_id = item.child
					let a:search_object.current_item = len(s:directory_list[a:search_object.current_id]) - 1
					let a:search_object.doing_dirs = 0

					call add(a:search_object.stack, stack_item)
				else
					let a:search_object.current_item = current_item - 1
				endif
			else
				if g:GITLOG_show_hidden_files == 1 || item.name[0] != '.' && (item.type == 'blob' && (item.marker == a:search_object.marker || (a:search_object.marker == s:GITLOG_Any && item.marker != s:GITLOG_Same)))
					" We have found what we are looking for
					let result = item
					let a:search_object.found_item = item
					break
				else
					let a:search_object.current_item = current_item - 1
				endif
			endif
		endif
	endwhile

	return result
endfunction																    "}}}
" FUNCTION: GITLOG_DeleteTreeNode()											{{{
"
" This function will delete the tree node. It will also delete all the child
" nodes from the given node.
"
" vars:
"	id	The id of the tree node to be removed.
"
" returns:
"	nothing
"
function! s:GITLOG_DeleteTreeNode(id)
	for item in s:directory_list[a:id]
		if item.type == 'tree' || item.type == 'commit'
			call s:GITLOG_DeleteTreeNode(item.child)
		endif
	endfor

	" now delete the reference
	let s:directory_list[a:id] = []

endfunction																    "}}}
" FUNCTION: GITLOG_ChangeBranch()							 				{{{
"
" This function will set the current branch.
" When changing the branch it will update the current commit to the head of
" the new branch.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! s:GITLOG_ChangeBranch(root_id, new_branch)
	let s:gitlog_current_commit = a:new_branch
	let s:gitlog_current_branch = a:new_branch

	if a:new_branch == 'HEAD'
		let g:gitlog_current_ref = 'HEAD'
	else
		let s:gitlog_current_ref = 'refs/heads/' . a:new_branch
	endif
endfunction																	"}}}
" Mapped Functions
" FUNCTION: GITLOG_ToggleHelp()								 				{{{
"
" This toggles the help.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! GITLOG_ToggleHelp()
	if s:help == 1
		let s:help = 0
	else
		let s:help = 1
	endif

	if s:gitlog_loaded == 2
		" update the tree window
		call s:GITLOG_RedrawTreeWindow(line('.'))
	else
		" update the log window
		call s:GITLOG_RedrawLogWindow(line('.'))
	endif
endfunction																	"}}}
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
function! GITLOG_CloseDiffBuffers()

	" pull down all the windows open for the diff
	for diff_buffer in s:diff_buffer_list
		if bufnr(diff_buffer) != -1
			" delete the buffer (and the window if it has one)
			silent exe "bwipe " . diff_buffer
		endif
	endfor

	" empty the list
	let s:diff_buffer_list = []
	let s:last_diff_path = ''

	silent diffoff!

	" fix bug when diff windows go away log window goes wordwrap
	silent exe bufwinnr(bufnr("__gitlog__")) . "wincmd w"
	setlocal buftype=nofile bufhidden=wipe nobuflisted nomodifiable noswapfile nowrap

endfunction																"}}}
" FUNCTION: GITLOG_ResetCommit()											{{{
"
" This resets the current commit to the head commit. (also forces a redraw).
"
" vars:
"	none
"
" returns:
"	nothing
"
function! GITLOG_ResetCommit()
	if s:gitlog_current_commit != "HEAD"
		let s:current_root = 1

		call s:GITLOG_ChangeBranch(s:current_root, 'HEAD')

		if s:gitlog_loaded == 2
			" update the log window
			call GITLOG_ActionRefreshRootDirectory()
		else
			call s:GITLOG_OpenLogWindow(s:gitlog_log_file)
		endif

		let s:gitlog_branch_line = 0
		call s:GITLOG_OpenBranchWindow()
	endif
endfunction																	"}}}
" FUNCTION: GITLOG_ActionRefreshRootDirectory()								{{{
"
" This function will refresh the root directory.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! GITLOG_ActionRefreshRootDirectory()
	if bufwinnr(bufnr("__gitlog__")) != -1
		" window already open - just go to it
		silent exe bufwinnr(bufnr("__gitlog__")) . "wincmd w"
		setlocal modifiable
		let temp = @"
		silent exe "% delete"
		let @" = temp

		" refresh the root directory - just throw everything away
		let s:directory_list = [[]]

		call s:GITLOG_DoTreeReBuild()

		let s:current_root = s:tree_root

		call s:GITLOG_RedrawTreeWindow(1)
	endif
endfunction																	"}}}
" FUNCTION: GITLOG_ActionRefreshCurrentNode()								{{{
"
" This function will refresh the node under the cursor.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! GITLOG_ActionRefreshCurrentNode()
	let s:found_path = ''
	let found_item = s:GITLOG_FindListItem(s:current_root,line("."))

	if found_item != {}
		if (found_item.type == 'tree' || found_item.type == 'commit' || found_item.type == 'link')
			let item = found_item
			let path = s:found_path . item.name . '/'
		else
			let item = found_item.parent
			let path = s:found_path
		endif

		let old_state = item.status
		" first remove all the items currently in the node down
		call s:GITLOG_DeleteTreeNode(item.child)

		" now re-create the item
		let item.child = s:GITLOG_BuildFullTree(path, item, g:GITLOG_walk_full_tree, s:GITLOG_FindTreeElement(s:submodule_tree,path))

		if g:GITLOG_walk_full_tree == 0
			" Do the partial update of the directory only - for speed.
			call s:GITLOG_GitUpdateDirectory(path, item)

		else
			" Do the recursive item update
			call s:GITLOG_MapGitChanges(s:GITLOG_FindTreeElement(s:GITLOG_GetGitFullChangeTree(), path), item)
		endif

		" set the state for the item
		let item.status = old_state

		" Redraw the window
		call s:GITLOG_RedrawTreeWindow(item.lnum)
	endif
endfunction																	"}}}
" FUNCTION: GITLOG_ActionOpenLocalFile()									{{{
"
" This function will open or select the already opened file in a file window.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! GITLOG_ActionOpenLocalFile()
	let s:found_path = ''
	let found_item = s:GITLOG_FindListItem(s:current_root,line("."))

	if found_item != {}
		if found_item.type == 'blob' && found_item.marker != s:GITLOG_Deleted
			let file_name = s:GITLOG_GetFilePath(found_item)

			if winnr("$") == 1
				" only the log window open, so create a new window
				exe "silent rightbelow vsplit " . file_name

			elseif bufwinnr(bufnr("^" . file_name . "$")) != -1
				" Ok, it's currently in a window
				exe bufwinnr(bufnr(file_name)) . "wincmd w"

			else
				" need to load the file, in the last window used
				exe "silent " . winnr("$") . "wincmd w"
				setlocal modifiable
				silent exe "edit " . file_name
			endif
		endif
	endif
endfunction																	"}}}
" FUNCTION: GITLOG_ActionOpenDiffFile()										{{{
"
" This function will open a diff of the selected file.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! GITLOG_ActionOpenDiffFile()
	let s:found_path = ''
	let found_item = s:GITLOG_FindListItem(s:current_root,line("."))

	if found_item != {}
		if found_item.type == 'blob' && found_item.marker != s:GITLOG_Deleted && found_item.marker != s:GITLOG_Added
			let file_name = substitute(s:repository_root . s:found_path . found_item.name, s:root_list[found_item.root_id].root_dir, '', '')

			call s:GITLOG_OpenDiffWindow(s:gitlog_current_commit,file_name,found_item)
		endif
	endif
endfunction																	"}}}
" FUNCTION: GITLOG_ActionSelectCurrentItem()								{{{
"
" This function will toggle the current dir to open/close or if the item is
" a file then it will open it in the source window.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! GITLOG_ActionSelectCurrentItem()
	let s:found_path = ''
	let found_item = s:GITLOG_FindListItem(s:current_root,line("."))

	if found_item != {} && (!has_key(found_item, 'no_follow') || found_item.no_follow == 0)
		if (found_item.type == 'tree' || found_item.type == 'commit' || found_item.type == 'link' || found_item.type == 'git')
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
		
					let found_item.child = s:GITLOG_BuildFullTree(s:repository_root . new_path, found_item, g:GITLOG_walk_full_tree, s:GITLOG_FindTreeElement(s:submodule_tree,new_path))
					call s:GITLOG_GitUpdateDirectory(new_path, found_item)
				endif
			endif

			call s:GITLOG_RedrawTreeWindow(found_item.lnum)
		else
			if found_item.marker == s:GITLOG_Deleted
				call GITLOG_ActionOpenHistoryItem()
			else
				" We have a file.
				call GITLOG_ActionOpenLocalFile()
			endif
		endif
	endif
endfunction																	"}}}
" FUNCTION: GITLOG_ActionOpenHistoryItem()									{{{
"
" This function will open an item from the repos history.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! GITLOG_ActionOpenHistoryItem()
	let s:found_path = ''
	let found_item = s:GITLOG_FindListItem(s:current_root,line("."))

	if found_item != {}
		if found_item.type == 'blob' && found_item.marker != s:GITLOG_Added
			let file_name = s:found_path . found_item.name

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
					silent exe "buffer " . bufnr(buffer_name)
				else
					" create a new buffer - and make sure it is empty
					let s:buf_number = bufnr(buffer_name,1)
					silent exe "buffer " . s:buf_number
					let temp = @"
					silent exe "% delete"
					let @" = temp

					" now open the code window
					if found_item.root_id > 1
						let file_name = substitute(s:repository_root . file_name,s:root_list[found_item.root_id].root_dir,"","")
					endif

					let gitlog_file = s:GITLOG_ExecuteGitCommand(found_item.root_id, "--no-pager show " . s:gitlog_current_commit . ':' . file_name)

					" now write the captured text to the a new buffer - after removing
					" the \x00's from the text and splitting into an array.
					let git_array = split(gitlog_file,'[\x00]')
					call setline(1,git_array)
					setlocal buftype=nofile bufhidden=hide buflisted nomodifiable noswapfile nowrap
				endif
			endif
		endif
	endif
endfunction																	"}}}
" FUNCTION: GITLOG_ActionShowItemHistory()									{{{
"
" This function will show the history of the current selected item.
" vars:
"	none
"
" returns:
"	nothing
"
function! GITLOG_ActionShowItemHistory()
	call s:GITLOG_OpenLogWindow(line("."))
endfunction																	"}}}
" FUNCTION: GITLOG_ActionToggleShowChanges()								{{{
"
" This function will toggle the show changes only. This function will force
" the tree mode into full walk or the show changes mode is pointless. So this
" will be done silently - meh!!
"
" vars:
"	none
"
" returns:
"	nothing
"
function! GITLOG_ActionToggleShowChanges()
	let need_refresh = 0

	if g:GITLOG_show_only_changes == 0
		let g:GITLOG_show_only_changes = 1

		if g:GITLOG_walk_full_tree == 0
			let g:GITLOG_walk_full_tree = 1
			let need_refresh = 1
		endif
	else
		let g:GITLOG_show_only_changes = 0
	endif

	if need_refresh == 1
		call GITLOG_ActionRefreshRootDirectory()
	else
		call s:GITLOG_RedrawTreeWindow(1)
	endif
endfunction																	"}}}
" FUNCTION: GITLOG_ActionOpenTree()											{{{
"
" This function will open all the tree for the current directory.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! GITLOG_ActionOpenTree()
	let s:found_path = ''
	let found_item = s:GITLOG_FindListItem(s:current_root,line("."))

	if found_item != {} && (!has_key(found_item, 'no_follow') || found_item.no_follow == 0)
		if (found_item.type == 'tree' || found_item.type == 'commit' || found_item.type == 'link' || found_item.type == 'git')
			" Need to set the defaults so that the walk can happen.
			let hold = g:GITLOG_walk_full_tree
			let g:GITLOG_walk_full_tree = 1

			let found_item.status = 'open'

			if found_item.child == 0
				let file_path = s:found_path . found_item.name . '/'
				let found_item.child = s:GITLOG_BuildFullTree(file_path, found_item, g:GITLOG_walk_full_tree, s:GITLOG_FindTreeElement(s:submodule_tree,file_path))
				call s:GITLOG_GitUpdateDirectory(file_path, found_item)
			endif

			let old_default = g:GITLOG_directory_default
			let g:GITLOG_directory_default = 'open'
			call s:GITLOG_OpenAllTreeDirectories(found_item.child)
			let g:GITLOG_directory_default = old_default

			call s:GITLOG_RedrawTreeWindow(found_item.lnum)

			let g:GITLOG_walk_full_tree = hold
		endif
	endif
endfunction																	"}}}
" FUNCTION: GITLOG_ActionOpenAllTree()										{{{
"
" This function will open all the tree.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! GITLOG_ActionOpenAllTree()
	if s:tree_all_opened
		call GITLOG_ActionCloseAllTree()
		let s:tree_all_opened = 0
	else
		if g:GITLOG_walk_full_tree == 0
			" Ok, you want to open all, then you need the full tree walked, here
			" we go... (change the defaults as this makes logical sense if you
			" do a refresh on any part of the tree - after an open all).
			let hold_def  = g:GITLOG_directory_default
			let g:GITLOG_walk_full_tree = 1
			let g:GITLOG_directory_default = 'open'

			call GITLOG_ActionRefreshRootDirectory()

			let g:GITLOG_walk_full_tree = 0
			let g:GITLOG_directory_default = hold_def
		else
			call s:GITLOG_OpenAllTreeDirectories(s:tree_root)
		endif

		let s:tree_all_opened = 1
	endif

	call s:GITLOG_RedrawTreeWindow(1)
endfunction																	"}}}
" FUNCTION: GITLOG_ActionCloseTree()										{{{
"
" This function will close all the tree for the current directory.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! GITLOG_ActionCloseTree()
	let s:found_path = ''
	let line_num = line(".")
	let found_item = s:GITLOG_FindListItem(s:current_root,line_num)

	" Ok, do we have a directory
	if found_item != {}
		" If closed already, close the parent - else close it if it is a directory
		if found_item.status != 'closed' && (found_item.type == 'tree' || found_item.type == 'commit' || found_item.type == 'link' || found_item.type == 'git')
			if (!has_key(found_item, 'no_follow') || found_item.no_follow == 0)
				let found_item.status = 'closed'
				let line_num = found_item.lnum
				call s:GITLOG_CloseAllTreeDirectories(found_item.child)
			endif

		elseif found_item.parent != {}
			" If not a tree item then close the parent and then all the sub-items
			let found_item.parent.status = 'closed'
			let line_num = found_item.parent.lnum
			call s:GITLOG_CloseAllTreeDirectories(found_item.parent.child)
		endif

		call s:GITLOG_RedrawTreeWindow(line_num)
	endif
endfunction																	"}}}
" FUNCTION: GITLOG_ActionCloseAllTree()										{{{
"
" This function will close all the tree.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! GITLOG_ActionCloseAllTree()
	let g:GITLOG_directory_default = 'closed'
	call s:GITLOG_CloseAllTreeDirectories(s:tree_root)

	call s:GITLOG_RedrawTreeWindow(1)
endfunction																	"}}}
" FUNCTION: GITLOG_ActionToggleBranch()										{{{
"
" The function will toggle showing the branch window.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! GITLOG_ActionToggleBranch()
	if g:GITLOG_show_branch_window
		let g:GITLOG_show_branch_window = 0

		if bufwinnr(bufnr("__gitbranch__")) != -1
			" window already open - just close it
			silent exe bufwinnr(bufnr("__gitbranch__")) . "wincmd w"
			silent wincmd c
		endif
	else
		let g:GITLOG_show_branch_window = 1
		call s:GITLOG_OpenBranchWindow()
	endif
endfunction																	"}}}
" FUNCTION: GITLOG_ActionToggleHidden()										{{{
"
" The function will toggle showing the hidden dot files.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! GITLOG_ActionToggleHidden()
	if g:GITLOG_show_hidden_files
		let g:GITLOG_show_hidden_files = 0
	else
		let g:GITLOG_show_hidden_files = 1
	endif

	call s:GITLOG_RedrawTreeWindow(line("."))
endfunction																	"}}}
" FUNCTION: GITLOG_ActionGotoChange()										{{{
"
" This function search for as change. If the any flag is set then goto
" any change or addition, deletion or change in the tree. Else goto the
" same type as the item selected.
"
" vars:
"	none
"
" returns:
"	nothing
"
function! GITLOG_ActionGotoChange(any, direction)
	let s:found_path = ''
	let looking = 1
	let found_item = s:GITLOG_FindListItem(s:current_root, line("."))

	if found_item != {}
		if found_item.type == 'tree'
			let do_dirs = 1
		else
			let do_dirs = 0
		endif

		if found_item.marker == s:GITLOG_Changed && found_item.type != 'tree'
			let next = index(s:directory_list[found_item.parent.child], found_item) + a:direction
		else
			let next = index(s:directory_list[found_item.parent.child], found_item)
		endif
	
		if a:any == 1
			let looking_for = s:GITLOG_Any
		else
			let looking_for = s:GITLOG_Changed
		endif

		if s:search_object == {}
			let s:search_object = {	'current_id'	: found_item.parent.child,
								\	'current_item'	: next,
								\	'level'			: 0,
								\	'doing_dirs'	: do_dirs,
								\	'marker'		: looking_for,
								\	'stack'			: [],
								\	'found_item'	: {} }
		endif

		if a:direction == g:GITLOG_WALK_FORWARDS
			let found = s:GITLOG_WalkForward(s:search_object)
		else
			let found = s:GITLOG_WalkBackward(s:search_object)
		endif

		if found != {}
			" Ok, we found the next item.
			call s:GITLOG_OpenTreeToItem(found)
			call s:GITLOG_RedrawTreeWindow(0)
			
			call setpos('.',[0,found.lnum,0,0])
		else
			" Not found end of search
			echohl WarningMsg
			echomsg "End of search. No more changes."
			echohl Normal
			let s:search_object = {}
		endif
	endif
endfunction																	"}}}
" AUTOCMD FUNCTIONS
" FUNCTION: GITLOG_LeaveBuffer()											{{{
"
" On leaving the buffer, get the commits that have been selected. This will
" allow for the external search to be able to search the correct lines. Also
" set the scrolloff back to what the user was using before entering the
" buffer
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
