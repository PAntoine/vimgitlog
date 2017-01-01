vimgitlog
=========

Version: 5.1.1

Git Tree, Log and Diff plugin for vim. 

Introduction
------------

This is a simple Vim plugin that will bring up the history of a given file. It will list the history
in the window-pane on the left of the screen. If you hit enter it will diff that commit against the
current revision loaded.

The focus of this plugin has changed from what it was originally (looking at the git log) to be a tool
for looking at the git tree more than the history. It is what I need. The Google Repo support has been
added to make using that set of git repositories usable from within Vim.

In the log window \_\_gitlog\_\_ the following commands work:

    o            opens the file. This will simply open the file in a new window.
	p            views the patch for the commit.
    s            starts a search and opens the search window.
    t            open the tree view at the current commit (only works in the main repository tree).
	T            Go back to the tree view.
    r            revert: Open the selected file version as the currently file.
    d            This will open the file and diff it against the window that was active when it was lauched.
    <cr>         This will open the file and diff it against the window that was active when it was lauched.
    <c-d>        Close all the open diff's.
    <c-h>        reset the current commit to HEAD.

In the tree window \_\_gitlog\_\_ the following commands work:

    l    		opens the local version of the file, if it exists.
    d    		diff's the tree view of the file against the local version.
    r    		refreshes the tree element that it is on.
    R    		refreshes the root directory.
    h    		show the history of the current file.
    p    		show the previous version of the file.
    a    		open the current item and all it's children.
    A    		open the whole tree (toggles).
    x    		close the current tree or the parent of the current tree.
    X    		close the whole tree.
    C    		toggle 'only changes only' and rebuild the tree.
    T    		go back to the log view.
    b    		Toggle branch window.
    s    		Toggle Secret (hidden) files.
    <cr>    	opens the local version of the file, if it exists.
    <c-d>    	pull down all the diff windows.
    <c-h>    	reset the current commit to HEAD and current working branch.
    <c-l>    	reset the current commit to latest on current branch.
    ]c    	    goto next changed item.
    [c    	    goto previous changed item.
    ]a    	    goto next changed/added/deleted item.
    [a    	    goto previous changed/added/deleted item.
    fa          Add the current file to 'git', this does not commit.
    fd          Delete the current file. Does not effect git.
    fD          Delete the file from the file-system and git.
    fm          Move the file on the file system.
    fM          Move the file on the file system and git.
    fr          Revert the current working file to the current selected commit.


In the search window \_\_gitsearch\_\_ the two following commands work:

    o            opens the file. This will simply open the file in a new window.
    <cr>         This will open the file and diff it against the window that was active when it was lauched.

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
    map <silent> <f5> :call GITLOG_FlipWindows()<cr>

And the should be it.

<F7> will load the default window type, pressing again will switch between Log and Tree view. Pressing
<F5> will flip between the views.

Configuration
-------------

The default configuration is one that supports backward compatibility, this is really to not mess up the
workflow of people that currently use GITLOG. But, to make the new features usable I suggest that the
following configurations are used. Obviously your workflow use whatever configurations you want.

Small Git Trees:
When I say small git trees, I mean non-kernel (and especially non-repo trees) as these bad boys can run
upto 600k objects in the tree - un-built. This allows for the trees to be walked and all the new goodness
to be used.

```
    :let g:GITLOG_default_mode = 2
    :let g:GITLOG_walk_full_tree = 1
    :let g:GITLOG_show_hidden_files = 0
	:map <silent> <f7> :call GITLOG_ToggleWindows()<cr>
    :map <silent> <c-f7> :call GITLOG_FlipWindows()<cr>
    :let g:GITLOG_ignore_suffixes=['swp', 'swn', 'pyc', 'o']
    :let g:GITLOG_ignore_directories = ['.git', 'out']
```
The big one in there is `GITLOG_walk_full_tree` as this will cause the full tree to be walked and report
any changes to the root. This will also make the 'C' command from tree quite quick. This may take a couple
of seconds to walk the tree, but it is worth it.

Big Trees:
```
    :let g:GITLOG_default_mode = 2
    :let g:GITLOG_walk_full_tree = 0
    :let g:GITLOG_show_hidden_files = 0
	:map <silent> <f7> :call GITLOG_ToggleWindows()<cr>
    :map <silent> <c-f7> :call GITLOG_FlipWindows()<cr>
    :let g:GITLOG_ignore_suffixes=['swp', 'swn', 'pyc', 'o', 'zip', 'tgz', 'gz']
    :let g:GITLOG_ignore_directories = ['.git', 'out']
```
Essentially the same with walk turned off. It will take about 2-7 mins to build the tree for the full
Android source (including changes). If you don't mind that wait (I don't as the useful features that
you get will a full walk, are - well useful and this I do at start of day.

Very Big Trees (repo - say the Android Source Tree):
```
    :let g:GITLOG_default_mode = 2
    :let g:GITLOG_walk_full_tree = 0
    :let g:GITLOG_show_hidden_files = 0
	:let g:GITLOG_show_branch_window = 0
	:map <silent> <f7> :call GITLOG_ToggleWindows()<cr>
    :map <silent> <f9> let g:GITLOG_walk_full_tree = 1;call GITLOG_FlipWindows();<let g:GITLOG_walk_full_tree = 0;cr>
    :let g:GITLOG_ignore_suffixes=['swp', 'swn', 'pyc', 'o', 'zip', 'tgz', 'gz']
    :let g:GITLOG_ignore_directories = ['.git', 'out']
```
As for the big tree but not showing the branch window as that is pointless (esp. with repo). Also added
is `<f9>` as you can cd down to the sub-project that you are looking at and press that. It will then walk the
project and you can then pop-up the branch window if required. It works for me.


Obviously, choose the suffixes of your choice. As I mostly write c for day job and python for projects
these are suffixes that I have chosen.

Major Changes
-------------

## Bug Fixes and Tidy ups ##

This is mostly fixes for backwards compatibility. Have run this on git < 2 and on vim < 7.4, things had gotten
broken due to not doing backwards testing and not having to use older releases.

## Added File Commands ##

Simply as I user this as my main directory viewer it was getting annoying not to be able to do simple stuff
from the menu.

## View Commit Patch ##

Basically that's it. Working on another big code base and this is becoming an issue.

Issues
------

- submodule branches. Yup, not really supported. (not going to be either).

- repo branches. You can guess this one, not supported. (not going to be either).


Licence and Copyright
---------------------
                    Copyright (c) 2012-2017 Peter Antoine
                             All rights Reserved.
                     Released Under the Artistic Licence
