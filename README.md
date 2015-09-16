vim-djangoproject
=================

This Vim plugin provides a simple way to activate and deactivate
[Django](https://www.djangoproject.com/) projects from a Vim session.

By default, `:python` and `:python3` commands have access only to the
system-wide Python environment. vim-djangoproject changes the Vim internal
Python `sys.path` and environment `$DJANGO_SETTINGS_MODULE` and `$PYTHONPATH`
variables so that they refer to the chosen Django project, i.e. activates it.

Usage examples
==============

List projects located inside `g:djangoproject#directory`:

    :DjangoProjectList

List projects located inside the '/foo/bar' directory:

    :DjangoProjectList /foo/bar

Activate the 'foo' project located inside `g:djangoproject#directory`:

    :DjangoProjectActivate foo

Activate the project located at '/foo/bar/baz':

    :DjangoProjectActivate /foo/bar/baz

Both `DjangoProjectActivate` and `DjangoProjectList` commands support `<Tab>`
completion.

Change the current directory to the currently active project directory:

    :DjangoProjectCD

Deactivate the currently active project:

    :DjangoProjectDeactivate

Name of the currently active project can be shown in the statusline via
`djangoproject#statusline()` function.

For a more detailed help see:

    :help djangoproject
