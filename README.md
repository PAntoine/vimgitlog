vimgitlog
=========

Git log and diff plugin for vim.

Introduction
------------

This is a simple Vim plugin that will bring up the history of a given file. It will list the history
in the window-pane on the left of the screen. If you hit enter it will diff that commit against the
current revision loaded.

In the log window \_\_gitlog\_\_ the two following commands work:

    __o__	opens the file. This will simply open the file in a new window.
	__\<cr\>__	This will open the file and diff it against the window that was active when it was lauched.

Installation
------------

Simply copy the contents of the plugin directory to the plugin directory in your git installation.

You will need to map the toggle function to use it.

    map <silent> <f7> :call GITLOG_ToggleWindows()

And the should be it.

TODO
----

1.  Also it works of the current branch, this will change to be selectable across branches as this
    is more usefull.

2.  It is not colour coded yet, it will.

Licence and Copyright
---------------------
                      Copyright (c) 2012 Peter Antoine
                             All rights Reserved.
                     Released Under the Artistic Licence
