" ---------------------------------------------------------------------------------
"  Name  : gitlog
"  Desc  : This plugin is a tool for looking at the GIT history of a file.
" 
"  Author: peterantoine
"  Date  : 29/09/2012 14:42:03
" ---------------------------------------------------------------------------------
"                      Copyright (c) 2012 Peter Antoine
"                             All rights Reserved.
"                     Released Under the Artistic Licence
" ---------------------------------------------------------------------------------

function! GITLOG_GetHistory(branch, filename)  "{{{
		" have to get the files that it uses first
	let s:repository_root = GITLOG_FindRespositoryRoot()
	let s:revision_file = expand('%:p')
	let s:revision_path = substitute(s:revision_file,s:repository_root,"","")
	let s:original_window = bufwinnr("%")

	silent execute "!git cat-file -e " . a:branch . ":" . s:revision_path
	if v:shell_error
		echohl WarningMsg
		echomsg "File " . a:branch . ":" . s:revision_path . " is not tracked"
		echohl Normal
	else
		call GITLOG_OpenWindow()
		redir => gitdiff_history
		silent execute "!git rev-list HEAD --oneline --graph -- " . s:revision_path
		redir END
		let git_array = split(substitute(gitdiff_history,'[\x00]',"","g"),"\x0d")
		call remove(git_array,0)
		call setline(1,git_array)
		unlet git_array
		unlet gitdiff_history

		call GITLOG_MapBufferKeys()
		setlocal nomodifiable
	endif
endfunction                                     "}}}
  
function! GITLOG_GetCommitHash()				"{{{
	let x =  getline(".")

	if (stridx(x,"*") >= 0)
		let commit = substitute(x,"^.*\\*\\s\\+\\(\\x\\x\\x\\x\\x\\x\\x\\) .\\+$","\\1","")
	else
		let commit = ""
	endif

	return commit
endfunction										"}}}

function! GITLOG_FindRespositoryRoot()
	let root = finddir(".git",expand('%:h'). "," . $PWD . ";" . $HOME)
	
	if (root == '.git')
		let root = expand('%:p:h') . '/'
	else
		let root = substitute(root,"\\.git","","")
	endif

	return root
endfunction

function! GITLOG_MapBufferKeys()
	map <buffer> <cr> :call GITLOG_OpenRevision()<cr>
	map <buffer> d	  :call GITLOG_DiffRevision()<cr>
endfunction

function! GITLOG_OpenWindow()                  "{{{
	if bufwinnr(bufnr("_gitlog__")) != -1
		" window already open - just go to it
		exe bufwinnr(bufnr("_gitlog__")) . "wincmd w"
		setlocal modifiable
	else
		" window not open need to create it
		let s:buf_number = bufnr("_gitlog__",1)
		topleft 40 vsplit
		set winfixwidth
		set winwidth=40
		set winminwidth=40
		exe "buffer " . s:buf_number
		setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap
  endif
endfunction                                     "}}}

function! GITLOG_OpenDiffWindow(revision)              "{{{
	if bufwinnr(bufnr("__" . a:revision . "__")) != -1
		" window already open - just go to it
		exe bufwinnr(bufnr("__" . a:revision . "__")) . "wincmd w"
		setlocal modifiable
	else
		" window not open need to create it
		let s:buf_number = bufnr("__" . a:revision . "__",1)
		exe bufwinnr(bufnr(s:revision_file)) . "wincmd w"
		let file_type = &filetype
		diffthis
		botright vsplit
		exe "buffer " . s:buf_number

		redir => gitdiff_history
		silent execute "!git --no-pager show " . a:revision
		redir END
	
		let git_array = split(substitute(gitdiff_history,'[\x00]',"","g"),"\x0d")
		call remove(git_array,0)
		call setline(1,git_array)
		setlocal buftype=nofile bufhidden=wipe nobuflisted nomodifiable noswapfile nowrap
		diffthis
		exe "setlocal filetype=" . file_type


  endif

endfunction                                     "}}}

"Git branch
function! GITLOG_GetBranch()
    let branch = system("git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* //'")
    if branch != ''
        return substitute(branch, '\n', '', 'g')
	else
	    return ''
	endif
endfunction

function! GITLOG_OpenRevision()
	let commit = GITLOG_GetCommitHash()

	silent execute "!git cat-file -e " . commit . ":" . s:revision_path 
	if v:shell_error
		echohl Normal
		echomsg "The repository does not have this file"
		echohl WarningMsg
	else
		call GITLOG_OpenDiffWindow(commit . ":" . s:revision_path)
	endif
	
endfunction

" this is bad -- need to remove.
map <f7> :call GITLOG_GetHistory(GITLOG_GetBranch(),expand('%'))<cr>

