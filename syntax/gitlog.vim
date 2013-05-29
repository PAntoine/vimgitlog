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
syn region	glBranchLine		start="^  [a-zA-Z]" start="^[>\*] [a-zA-Z]" end="$"		contains=glCruft,glCurrentBranchName,glSelectBranchName,glBranchHash,glLogMessage,@NoSpell keepend 
syn match	glCurrentBranchName	"^\* [0-9A-Za-z\/\._\-#]\+\s\+"hs=s+2	contained containedin=glBranchLine nextgroup=glBranchHash
syn match	glSelectBranchName	"^> [0-9A-Za-z\/\._\-#]\+\s\+"hs=s+2	contained containedin=glBranchLine nextgroup=glBranchHash
syn match	glBranchName		"^  [0-9A-Za-z\/\._\-#]\+\s\+"hs=s+2	contained containedin=glBranchLine nextgroup=glBranchHash
syn match	glBranchHash		"\x\x\x\x\x\x\x"						contained contains=@NoSpell containedin=glBranchLine nextgroup=glBranchMessage

hi link glBranchHash		Character
hi link glCurrentBranchName	Identifier
hi link glSelectBranchName	WarningMsg
hi link glBranchName		Comment
hi link glBranchLine		String

" highlighting for for the search window
syn region	glSearch			start="^\x\x\x\x\x\x\x:" end="$"		keepend contains=glSearchHash,glSearchFileName,glSearchLineNumber,glSearchMessage,@NoSpell
syn match	glSearchHash		"\x\x\x\x\x\x\x"						contained nextgroup=glSearchFileName contains=@NoSpell containedin=glSearch
syn match	glSearchFileName	":[0-9A-Za-z\/\._\-]\+"hs=s+1			contained nextgroup=glSearchLineNumber contains=@NoSpell containedin=glSearch
syn match	glSearchLineNumber	":[0-9]\+"hs=s+1						contained nextgroup=glSearchMessage containedin=glSearch
syn match	glSearchMessage		":.\+$"hs=s+1							contained containedin=glSearch

" highlights
hi link glSearchHash			Character
hi link glSearchFileName        Directory
hi link glSearchLineNumber		LineNr
hi link glSearchMessage			Comment

"highlight the log window
syn region	glLog				start="^[| ]*\*[| ]* \x\x\x\x\x\x\x\s[0-9A-Za-z\/\._\-#@]" end="$"	contains=glLogHash,glCruft,glLogMessage,@NoSpell keepend
syn match	glBranchMessage		"\s[0-9A-Za-z\/\._\-#@]\+"			contained containedin=glLog,glBranchLine
syn match	glLogHash			" \x\x\x\x\x\x\x"					contained containedin=glLog nextgroup=glBranchMessage

syn region	glBranchHeader		start="^branch:" end="$"			keepend contains=glBranch,glBranchName
syn keyword	glBranch			contained branch
syn match	glBranchName		": [0-9A-Za-z\/\._\-#]\+"			contained containedin=glBranchHeader

hi link glLog				Normal
hi link glCruft				Normal
hi link glLogHash			Character
hi link glBranch			Identifier
hi link glBranchName		Special
hi link glBranchMessage		Comment

" Tree Window
syn region	glTreeHeader	start="^commit:" end="$"		keepend contains=glBranch,glBranchName,glLogHash

syn region	glDirLine		start="^\s*[▸▾>v] " end="$"		keepend contains=glMarker,glDirName,@NoSpell
syn match	glMarker		"▸ "							contained containedin=glDirLine nextgroup=glDirName
syn match	glMarker		"▾ "							contained containedin=glDirLine nextgroup=glDirName
syn match	glMarker		"> "							contained containedin=glDirLine nextgroup=glDirName
syn match	glMarker		"v "							contained containedin=glDirLine nextgroup=glDirName
syn match	glDirName		"[0-9A-Za-z\._#\-]\+"			contained containedin=glDirLine nextgroup=glStateRemoved,glStateAdded contains=@NoSpell
syn match 	glStateRemoved	" [✗x]"							contained containedin=glDirLine nextgroup=glStateModule
syn match 	glStateAdded	" [+]"							contained containedin=glDirLine nextgroup=glStateModule
syn match 	glStateModule	" [m]"							contained containedin=glDirLine contains=@NoSpell

syn region	glTreeLine		start="^\s*[✓+✗x±~ ]" end="$"	keepend contains=glMarker,glFileName,@NoSpell
syn match 	glStateNew		"[✓+]"					contained containedin=glTreeLine nextgroup=glFileName
syn match 	glStateDeleted	"[✗x]"					contained containedin=glTreeLine nextgroup=glFileName
syn match 	glStateChanged	"[±~]"					contained containedin=glTreeLine nextgroup=glFileName
syn match	glFileName		"[0-9A-Za-z\._#\-]\+"	contained containedin=glTreeLine contains=@NoSpell

hi link glDirLine			Normal
hi link glTreeLine			Normal
hi link glMarker			Normal
hi link	glDirName			String
hi link	glFileName			Normal
hi 		glStateNew			term=bold ctermfg=Green		guifg=Green
hi 		glStateDeleted		term=bold ctermfg=Red		guifg=Red
hi 		glStateChanged		term=bold ctermfg=Yellow	guifg=Yellow
hi 		glStateAdded		term=bold ctermfg=Green		guifg=Green
hi 		glStateRemoved		term=bold ctermfg=Red		guifg=Red
hi link	glStateModule		Comment
hi link	glStateSame			String

