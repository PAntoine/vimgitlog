vimgitlog
=========

Version: 2.0.0

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
	<cr>		This will open the file and diff it against the window that was active when it was lauched.

In the tree window \_\_gitlog\_\_ the following commands work:

    l			opens the local version of the file, if it exists.
    d			diff's the tree view of the file against the local version.
	<cr>		opens the respository version of the file, if it exists.

In the search window \_\_gitsearch\_\_ the two following commands work:

    o			opens the file. This will simply open the file in a new window.
	<cr>		This will open the file and diff it against the window that was active when it was lauched.

In the Branch window:

    <cr>        This will change the log window to the branch selected. It does not change the current
	            branch of the given repository.

Installation
------------

Simply copy the contents of the plugin directory to the plugin directory in your git installation.

You will need to map the toggle function to use it.

    map <silent> <f7>   :call GITLOG_FilpWindows()<cr>
    map <silent> <c-f7> :call GITLOG_ToggleWindows()<cr>

And the should be it.

<F7> will load the default window type, pressing again will switch between Log and Tree view. Pressing
<c-F7> will pull down the windows.

Issues
------

- There is a minor problem with GitLog getting confused when diff's on different files are done one after
another. I would simply suggest pulling down GitLog and then either opening another file, or toggle the
git log windows. The solution is to add a function to pull down the diff, but working out how to keep the
screen layout when this is done.

- Submodules.  

These are not handled at the moment. I am not sure how to handle these so for the moment they are just
being ignored. It is the same with repos within repos. These will be handled when I know what behaviour
I want GitLog to follow.

TODO
----

1. Add the ability to find when (what revision) a file was first added to the repository.

Licence and Copyright
---------------------
                    Copyright (c) 2012-2013 Peter Antoine
                             All rights Reserved.
                     Released Under the Artistic Licence
