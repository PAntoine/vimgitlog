" ---------------------------------------------------------------------------------
"     file: gitlog (syntax file)
"     desc: This file holds the syntax highlighting for the gitlog plugin.
" 
"   author: Peter Antoine
"     date: 11/12/2012 14:29:38
" ---------------------------------------------------------------------------------
"                      Copyright (c) 2012 Peter Antoine
"                             All rights Reserved.
"                     Released Under the Artistic Licence
" ---------------------------------------------------------------------------------

" Quit when a syntax file was already loaded
if exists("b:current_syntax")
	finish
endif

let b:current_syntax = "gl"

"highlight the branch window
syn region	glBranchLine		start="^  [a-zA-Z]" start="^[>\*] [a-zA-Z]" end="$"		contains=glCruft,glCurrentBranchName,glSelectBranchName,glNormalBranchName,glBranchHash,glLogMessage,@NoSpell keepend 
syn match	glCurrentBranchName	"^\* [0-9A-Za-z\/\._\-#]\+\s\+"hs=s+2	contained containedin=glBranchLine nextgroup=glBranchHash
syn match	glSelectBranchName	"^> [0-9A-Za-z\/\._\-#]\+\s\+"hs=s+2	contained containedin=glBranchLine nextgroup=glBranchHash
syn match	glNormalBranchName	"^  [0-9A-Za-z\/\._\-#]\+\s\+"hs=s+2	contained containedin=glBranchLine nextgroup=glBranchHash
syn match	glBranchHash		"\x\+"						contained contains=@NoSpell containedin=glBranchLine nextgroup=glBranchMessage

hi link glBranchHash		Character
hi link glCurrentBranchName	Identifier
hi link glSelectBranchName	WarningMsg
hi link glNormalBranchName	Comment
hi link glBranchLine		String

" highlighting for for the search window
syn region	glSearch			start="^\x\+:" end="$"			keepend contains=glSearchHash,@NoSpell
syn match	glSearchHash		"\x\+"							contained nextgroup=glSearchFileName contains=@NoSpell containedin=glSearch
syn match	glSearchFileName	":[0-9A-Za-z\/\._\-]\+"hs=s+1	contained nextgroup=glSearchLineNumber contains=@NoSpell containedin=glSearch
syn match	glSearchLineNumber	":[0-9]\+"hs=s+1				contained nextgroup=glSearchMessage containedin=glSearch
syn match	glSearchMessage		":.\+$"hs=s+1					contained containedin=glSearch

" highlights
hi link glSearchHash			Character
hi link glSearchFileName        Directory
hi link glSearchLineNumber		LineNr
hi link glSearchMessage			Comment

"highlight the log window
syn region	glLog				start="^[| ]*\*[| ]* \x\+\s\+.\+" end="$"	contains=glGraph,@NoSpell keepend
syn match	glGraph				"^[| ]*\*[| ]*\s"							contained containedin=glLog nextgroup=glLogHash
syn match	glLogHash			"\x\+\s"									contained nextgroup=glBranchMessage
syn match	glBranchMessage		".\+$"										contained

syn region	glBranchHeader		start="^branch:" start="^file:" end="$"		keepend contains=glBranch,glFile,glBranchName
syn keyword	glBranch			contained branch
syn keyword	glFile				contained file
syn match	glBranchName		": [0-9A-Za-z\/\._\-#]\+"			contained containedin=glBranchHeader

hi link glLog				Normal
hi link glCruft				Normal
hi link glLogHash			Character
hi link glBranch			Identifier
hi link glFile				Identifier
hi link glBranchName		Special
hi link glBranchMessage		Comment

" Tree Window
syn region	glTreeHeader	start="^commit:" end="$"		keepend contains=glHCommit,glBranchName,glLogHash
syn keyword	glHCommit		contained commit

hi link glHCommit			Identifier

syn region	glDirLine		start="^\s*[▸▾>v] " end="$"		keepend contains=glMarker,@NoSpell
syn match	glMarker		"▸ "							contained containedin=glDirLine nextgroup=glDirName
syn match	glMarker		"▾ "							contained containedin=glDirLine nextgroup=glDirName
syn match	glMarker		"> "							contained containedin=glDirLine nextgroup=glDirName
syn match	glMarker		"v "							contained containedin=glDirLine nextgroup=glDirName
syn match	glDirName		"[0-9A-Za-z\._#\-\+]\+"			contained containedin=glDirLine nextgroup=glStateModule,glStateSubGit,glStateSubRepo,glStateLink,glStateBadLink,glStateNew,glStateDeleted,glStateChanged contains=@NoSpell
syn match 	glStateSubRepo	" [r]"							contained containedin=glDirLine nextgroup=glStateNew,glStateDeleted,glStateChanged contains=@NoSpell
syn match 	glStateSubGit	" [g]"							contained containedin=glDirLine nextgroup=glStateNew,glStateDeleted,glStateChanged contains=@NoSpell
syn match 	glStateModule	" [m]"							contained containedin=glDirLine nextgroup=glStateNew,glStateDeleted,glStateChanged contains=@NoSpell
syn match 	glStateLink		" [l]"							contained containedin=glDirLine nextgroup=glStateNew,glStateDeleted,glStateChanged contains=@NoSpell
syn match 	glStateBadLink	" [łB]"							contained containedin=glDirLine nextgroup=glStateNew,glStateDeleted,glStateChanged contains=@NoSpell

syn region	glTreeLine		start="^\s*[✓+✗x±~ ] [0-9A-Za-z\._#\-:]\+$" end="$"	keepend contains=glMarker,glFileName,@NoSpell
syn match 	glStateNew		"[+]"					contained containedin=glTreeLine,glDirLine nextgroup=glFileName
syn match 	glStateDeleted	"[✗x]"					contained containedin=glTreeLine,glDirLine nextgroup=glFileName
syn match 	glStateChanged	"[±~]"					contained containedin=glTreeLine,glDirLine nextgroup=glFileName
syn match	glFileName		"[0-9A-Za-z\._#\-]\+$"	contained containedin=glTreeLine contains=@NoSpell

hi link glDirLine			Normal
hi link glTreeLine			Normal
hi link glMarker			Normal
hi link	glDirName			String
hi link	glFileName			Normal
hi 		glStateNew			term=bold ctermfg=Green		guifg=Green
hi 		glStateDeleted		term=bold ctermfg=Red		guifg=Red
hi 		glStateChanged		term=bold ctermfg=Yellow	guifg=Yellow
hi 		glStateAdded		term=bold ctermfg=Green		guifg=Green
hi 		glStateLink			term=bold ctermfg=Yellow	guifg=Yellow
hi 		glStateBadLink		term=bold ctermfg=Red		guifg=Red
hi link	glStateModule		Comment
hi link	glStateSubGit		Comment
hi link	glStateSubRepo		Comment
hi link	glStateSame			String

" vim: ts=4 tw=4 fdm=marker :
