vimgitlog
=========

Version: 5.0.0

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
    s            starts a search and opens the search window.
    t            open the tree view at the current commit (only works in the main repository tree).
	T            Go back to the tree view.
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
    A    		open the whole tree.
    x    		close the current tree or the parent of the current tree.
    X    		close the whole tree.
    C    		toggle 'only changes only' and rebuild the tree.
    <cr>    	opens the local version of the file, if it exists.
    <c-d>    	pull down all the diff windows.
    <c-h>    	reset the current commit to HEAD and current working branch.
    <c-l>    	reset the current commit to lastest on current branch.

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

The defult configuration is one that supports backward compatibility, this is really to not mess up the
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

Obviously, choose the suffixes of your choice. As I mostly write c for day job and python for projects
these are suffixes that I have chosen.

Major Changes
-------------

REPO Support

This now supports Google REPO which is a release management system built on-top of git. It essentially
has a load of git repositories strung together.

Nested Git Repositories

These basically comes with REPO support as this is required for the above.

Tree Build re-write

As the above are HUGE repositories gigabytes in size, the old way of building the tree was simply not
fast enough (for example a Kernel tree 18mins). This is too usable, so the thing has been re-written
levering the in-built knowledge that git keeps in the index about the state of the file system to really
speed up the tree build. The current build takes under 2 mins to build a full REPO tree (that has more
than one kernel in it).

Re-jiggs to the commands

The commands have been rejigged, that is slightly improved so that they done fail and lie. But mostly
to be a bit more sensible. They should not be any changes that break workflow, the main commands will
work the same, but some new ones should aid navigation.

New commands for using the full tree walk. Things like open all and close all. These work well will
the show changes option.

Random Fixes

Some code got broken and some changes in the way that git behaves (or the fact that I was misusing some
of the git commands) means that some of the features were not working. I think they all are.

Usability Changes

The major change is to fix the history of sub-items. This allows for the tree not to be broken by going
to a commit that only exists in either a sub-module or sub-git tree. This is a departure from the
previous way of working.

Issues
------

- Following bugs are known, and there fixes that will be released when they are tested. One is new
(the missing dot files) but the rest are old, and only became known when testing the new features.
Fixes have been done but are tied up with the code to speed up the full walk, which is blocking the
main new feature (the reason for all this work). Sorry for any problems caused with the current change
sets.

- KNOWN BUG: If object type is different repo vs local does not add two items.
- KNOWN BUG: Local dot files are missing.
- KNOWN BUG: Empty directories now get a rubbish file added.
- KNOWN BUG: Toggle resets branch state.

- There is a minor problem with GitLog getting confused when diff's on different files are done one after
another. I would simply suggest pulling down GitLog and then either opening another file, or toggle the
git log windows. C-d will pull down existing diffs in the code/tree window.

- submodule branches. Yup, not really supported. (not going to be either).

- repo branches. You can guess this one, not supported. (not going to be either).


Licence and Copyright
---------------------
                    Copyright (c) 2012-2015 Peter Antoine
                             All rights Reserved.
                     Released Under the Artistic Licence
