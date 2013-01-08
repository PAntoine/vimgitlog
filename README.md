vimgitlog
=========

Version: 1.3.0

Git log and diff plugin for vim.

Introduction
------------

This is a simple Vim plugin that will bring up the history of a given file. It will list the history
in the window-pane on the left of the screen. If you hit enter it will diff that commit against the
current revision loaded.

In the log window \_\_gitlog\_\_ the following commands work:

    o			opens the file. This will simply open the file in a new window.
    s			starts a search and opens the search window.
	<cr>		This will open the file and diff it against the window that was active when it was lauched.

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

    map <silent> <f7> :call GITLOG_ToggleWindows()

And the should be it.

TODO
----

1. Add the ability to find when a file was first added to the repository.

Licence and Copyright
---------------------
                      Copyright (c) 2012 Peter Antoine
                             All rights Reserved.
                     Released Under the Artistic Licence
