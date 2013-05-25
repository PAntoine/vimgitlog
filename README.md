vimgitlog
=========

Version: 3.0.0

Git log and diff plugin for vim.

Introduction
------------

This is a simple Vim plugin that will bring up the history of a given file. It will list the history
in the window-pane on the left of the screen. If you hit enter it will diff that commit against the
current revision loaded.

In the log window \_\_gitlog\_\_ the following commands work:

    o			opens the file. This will simply open the file in a new window.
    s			starts a search and opens the search window.
	t           open the tree view at the current commit.
	d			This will open the file and diff it against the window that was active when it was lauched.
	<cr>		This will open the file and diff it against the window that was active when it was lauched.
	<c-d>		Close all the open diff's.
	<c-h>		reset the current commit to HEAD.

In the tree window \_\_gitlog\_\_ the following commands work:

    l			opens the local version of the file, if it exists.
    d			diff's the tree view of the file against the local version.
	r			refreshes the tree element that it is on.
	R			refeshes the root directory.
	h			show the history of the current file.
	<cr>		opens the respository version of the file, if it exists.
	<c-d>		pull down all the diff windows.
	<c-h>		reset the current commit to HEAD.

In the search window \_\_gitsearch\_\_ the two following commands work:

    o			opens the file. This will simply open the file in a new window.
	<cr>		This will open the file and diff it against the window that was active when it was lauched.

In the Branch window:

    <cr>        This will change the log window to the branch selected. It does not change the current
	            branch of the given repository.

The see the help during uses, type '?' in the log/tree window.

Installation
------------

Simply copy the contents of the plugin directory to the plugin directory in your git installation.

You will need to map the toggle function to use it.

	let g:GITLOG_default_mode = 2
	map <silent> <f7> :call GITLOG_ToggleWindows()<cr>
	map <silent> <c-f7> :call GITLOG_FlipWindows()<cr>

And the should be it.

<F7> will load the default window type, pressing again will switch between Log and Tree view. Pressing
<c-F7> will pull down the windows.

Major Changes
-------------

Added support for submodules. 

Issues
------

- There is a minor problem with GitLog getting confused when diff's on different files are done one after
another. I would simply suggest pulling down GitLog and then either opening another file, or toggle the
git log windows. The solution is to add a function to pull down the diff, but working out how to keep the
screen layout when this is done.

- The "tree" view will use the current commit to walk the tree. If you move away from the HEAD
commit then this will show the files as new, unlikely the files will exist in commits in other
trees. Reset the HEAD if this is confusing.

- submodule branches. Yup, not really supported. It is possible if I store the current branch for the
tree elements. But, I am not sure of the side-effects of this. Also, this has enough support for what I
need it todo. Will fix the bugs in this release before making more major changes.


Licence and Copyright
---------------------
                    Copyright (c) 2012-2013 Peter Antoine
                             All rights Reserved.
                     Released Under the Artistic Licence
