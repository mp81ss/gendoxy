# gendoxy - An emacs package to generate doxygen documentation from C code
This plugin generates [doxygen](http://doxygen.org "dox") documentation from C source code. You can ignore the doxygen rules and parameters documentation may be partially guessed according to some parameters name pattern

# Installation
Put file _gendoxy.el_ in a path accessible to emacs (add-to-list 'load-path ...)   
Load it in your init file `(load "gendoxy.el")`

# Configuration
Once the package is loaded, there are four variables that control documentation generation:
* `gendoxy-backslash`: if not _nil_, will use backslash instead of asperand.
* `gendoxy-default-text`: Default string used in generated documentation.
* `gendoxy-skip-details`: If not _nil_, will omit details in header and functions
* `gendoxy-details-empty-line`: If not _nil_, will use an empty line instead of the details tag to add details. Note that this has effect if _gendoxy-skip-details_ is _nil_ ONLY.

# Usage
Put the curson on the first line of a declaration to document (not necessarely at the beginning of line), then run command:   
`M-x gendoxy-tag`   
This will document your declaration and all its sub-items if any.
If you want to document a declaration, __but not__ its subitems, then run the command:   
`M-x gendoxy-tag-header`

### Groups
To to document a group of items, you can use the command:   
M-x `gendoxy-group`   
To document a grouup __but not__ the single items, use the command:   
`M-x gendoxy-group-header`   
For groups, since may not be easy to guess start and end of group, two explicit commands have been added:   
`gendoxy-group-start` and `gendoxy-group-end`.   
The last command (but the first to use) is:   
`M-x gendoxy-header`   
that generates a header documentation for current file

# Notes
The gendoxy package doesn't define a new mode, just offers some commands to use.
