vimgitlog
=========

Version: 4.0.1

Git Tree, Log and Diff plugin for vim. 

Introduction
------------

This is a simple Vim plugin that will bring up the history of a given file. It will list the history
in the window-pane on the left of the screen. If you hit enter it will diff that commit against the
current revision loaded.

In the log window \_\_gitlog\_\_ the following commands work:

    o            opens the file. This will simply open the file in a new window.
    s            starts a search and opens the search window.
    t            open the tree view at the current commit.
    d            This will open the file and diff it against the window that was active when it was lauched.
    <cr>         This will open the file and diff it against the window that was active when it was lauched.
    <c-d>        Close all the open diff's.
    <c-h>        reset the current commit to HEAD.

In the tree window \_\_gitlog\_\_ the following commands work:

    l            opens the local version of the file, if it exists.
    d            diff's the tree view of the file against the local version.
    r            refreshes the tree element that it is on.
    R            refeshes the root directory.
    h            show the history of the current file.
    p            open the respository version of the file.
    x            close the parent of the tree node.
    C            toggle 'only changes only' and rebuild the tree.
    <cr>         opens the local version of the file, if it exists.
    <c-d>        pull down all the diff windows.
    <c-h>        reset the current commit to HEAD.

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
    map <silent> <c-f7> :call GITLOG_FlipWindows()<cr>

And the should be it.

<F7> will load the default window type, pressing again will switch between Log and Tree view. Pressing
<c-F7> will pull down the windows.

Major Changes
-------------

Bug Fix Release.

A Couple of new features have slipped in, but purely as side-effects of fixing bugs.
- Fixed symlink looping issue.
  Code now detects when a symlink causes a loop. This is not highlighted with a 'B' next to the
  directory name. This is marked as `no_follow` and the link cannot be opened. Also links are
  now highlighted as we 

- Fixed issue with vim loaded in sub-directory not correctly routing.
  This fix is only possible as git has added "-C" to the command line and commands can be re-routed
  in git and the parts are now correctly formatted. Otherwise using "--work-dir" does not do what
  you think it does, if you are in a sub-directory of the tree then it will return relative paths.
  With the '-C' option it returns paths from the root, this are predictable and no expensive and
  complicated processing is required.

- Fixed Documentation and syntax highlighting problems.

Honourable Mentions
-------------------

Should really mention NerdTree at this point as now this plugin has a tree view, that more and more 
commands that are the same a NerdTree are starting to appear. Mostly as a NerdTree user I am starting
to have GITLOG open more of my day so don't want to have to change plugins.

Issues
------

- There is a minor problem with GitLog getting confused when diff's on different files are done one after
another. I would simply suggest pulling down GitLog and then either opening another file, or toggle the
git log windows. C-d will pull down existing diffs in the code/tree window.

- The "tree" view will use the current commit to walk the tree. If you move away from the HEAD
commit then this will show the files as new, unlikely the files will exist in commits in other
trees. Reset the HEAD if this is confusing. This only noticeable when picking a history in a sub-module.

- submodule branches. Yup, not really supported. It is possible if I store the current branch for the
tree elements. But, I am not sure of the side-effects of this. Also, this has enough support for what I
need it to do. Will fix the bugs in this release before making more major changes.

TODO
----

- Performance.
  It is not good, need to do some things to make this a bit go-now on the larger trees. Time to prune
  some of those pesky search paths.

- REPO support.
  These are subtly and annoyingly different from sub-modules. 


Licence and Copyright
---------------------
                    Copyright (c) 2012-2013 Peter Antoine
                             All rights Reserved.
                     Released Under the Artistic Licence
