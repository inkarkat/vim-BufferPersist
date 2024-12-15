BUFFER PERSIST
===============================================================================
_by Ingo Karkat_

DESCRIPTION
------------------------------------------------------------------------------

This plugin automatically persists (parts of) certain buffers when Vim is done
editing the buffer, regardless of whether is was saved to a file or discarded.
In this way, this is related to the built-in persistent-undo functionality,
but rather meant for building a history of file contents to allow browsing and
recall, especially for things like commit messages, where Vim is invoked as
the editor from an external tool.

### SEE ALSO

This plugin is used by:
MessageRecall ([vimscript #4116](http://www.vim.org/scripts/script.php?script_id=4116)): Browse and re-insert previous (commit,
                                 status) messages.

USAGE
------------------------------------------------------------------------------

    The plugin is completely inactive until you set it up for a particular
    buffer through the following function; you'll find the details directly in the
    .vim/autoload/BufferPersist.vim implementation file.

    BufferPersist#Setup( BufferStoreFuncref, ... )

### EXAMPLE

Let's store the first three lines of each edited text file in the temp
directory, using the text file's filename prefixed with "preview-":

    function! BufferStore( bufNr )
        return $TEMP . '/preview-' . fnamemodify(bufname(a:bufNr), ':t')
    endfunction
    autocmd BufNew,BufRead *.txt call BufferPersist#Setup(
    \   function('BufferStore'),
    \   {'range': '1,3'}
    \)

INSTALLATION
------------------------------------------------------------------------------

The code is hosted in a Git repo at
    https://github.com/inkarkat/vim-BufferPersist
You can use your favorite plugin manager, or "git clone" into a directory used
for Vim packages. Releases are on the "stable" branch, the latest unstable
development snapshot on "master".

This script is also packaged as a vimball. If you have the "gunzip"
decompressor in your PATH, simply edit the \*.vmb.gz package in Vim; otherwise,
decompress the archive first, e.g. using WinZip. Inside Vim, install by
sourcing the vimball or via the :UseVimball command.

    vim BufferPersist*.vmb.gz
    :so %

To uninstall, use the :RmVimball command.

### DEPENDENCIES

- Requires Vim 7.0 or higher.
- Requires the ingo-library.vim plugin ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)), version 1.044 or
  higher.

TODO
------------------------------------------------------------------------------

- Add option to skip persisting when never modified in Vim or equal to the
  previous stored buffer persistence (which would need to be passed in).

### CONTRIBUTING

Report any bugs, send patches, or suggest features via the issue tracker at
https://github.com/inkarkat/vim-BufferPersist/issues or email (address below).

HISTORY
------------------------------------------------------------------------------

##### 1.11    RELEASEME
- ENH: Enable support for excluding Git message trailers (and similar):
  a:options.range can also be a List of range expressions; the first matching
  range will be used.

##### 1.10    03-Oct-2024
- ENH: Offer definition of a buffer-local command to persist the current
  buffer state on demand, via a:options.writeCommandName.
- Minor: Make substitute() robust against 'ignorecase'.
- Don't clobber the search history with the a:options.range (if given and
  using a /{pattern}/ address).
- Add dependency to ingo-library ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)).

__You need to separately
  install ingo-library ([vimscript #4433](http://www.vim.org/scripts/script.php?script_id=4433)) version 1.044 (or higher)!__

##### 1.00    25-Jun-2012
- First published version.

##### 0.01    09-Jun-2012
- Started development.

------------------------------------------------------------------------------
Copyright: (C) 2012-2024 Ingo Karkat -
The [VIM LICENSE](http://vimdoc.sourceforge.net/htmldoc/uganda.html#license) applies to this plugin.

Maintainer:     Ingo Karkat &lt;ingo@karkat.de&gt;
