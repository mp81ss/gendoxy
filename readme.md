# gendoxy

## An emacs package to generate doxygen documentation from C code
This plugin generates [doxygen](http://doxygen.org ) documentation from C source code\
It generates a doxygen documentation skeleton for the most common C constructs

## Features
* Dedicated command for module documentation (author, file, date, copyright, etc)
* Support for _macros_, _functions_, _variables_, _struct_, _enum_ and _typedef_
* Return tag added on non-void functions
* Function parameters have particular features:
  * Added only if a name is specified, ignored if type only is present
  * Direction is inferred by type (in, out, inout)
  * Documentation can be guessed by name (` * @param buffer_len The length of buffer`)
* Support for [groups](#groups)

## Installation
Put file _gendoxy.el_ in a path accessible to emacs (add-to-list 'load-path ...)\
Load it in your init file `(load "gendoxy.el")`

## Configuration
Once the package is loaded, there are four variables that control documentation generation:
* `gendoxy-backslash`: if not _nil_, will use backslash instead of ampersat
* `gendoxy-default-text`: Default string used in generated documentation
* `gendoxy-skip-details`: If not _nil_, will omit details in header and functions
* `gendoxy-details-empty-line`: If not _nil_, will use an empty line instead of
the details tag to add details. Note that this has effect **only** if _gendoxy-skip-details_ is _nil_

<a name="groups"></a>
## Groups
To to document a group of items (typically macros or variables), you can use the command:\
M-x `gendoxy-group`\
To document a group __but not__ the single items, use the command:\
`M-x gendoxy-group-header`\
Since sometimes may not be easy to guess start and end of group, two explicit commands have been added:\
`gendoxy-group-start` and `gendoxy-group-end`.

Example:\
Assume you have these 4 macros. To properly identify a group, newlines must be present before and after

```C
line 1:
line 2: #define M1 1
line 3: #define M2 2
line 4: #define M3 3
line 5: #define M4 4
line 6:
```

Now put your cursor on line 2: If you run command `gendoxy-group`, this will be the result:
```C
/**
 * @name Group title
 * Description
 * @{
 */
#define M1 1 /**< Description */
#define M2 2 /**< Description */
#define M3 3 /**< Description */
#define M4 4 /**< Description */
/**
 * @}
 */
```

If gendoxy fails detecting your group, you can split the prologue and epilogue documentation with commands:\
`gendoxy-group-start` and `gendoxy-group-end`

## Usage
The first command is `gendoxy-header`, that generate documentation for current file\
Then start documenting declarations with command `gendoxy-tag`:\
Put the cursor on the **first** line of a declaration to document, (not necessarily
at the beginning of line) and run `M-x gendoxy-tag`\
This will document your declaration and all its sub-items (on structs/enums) if any\
If you want to document a declaration, **but not** its subitems, then use command `M-x gendoxy-tag-header`

## Notes
The gendoxy package doesn't define a new mode, just offers some commands to use\
For a more productive environment, just [bind](https://www.gnu.org/software/emacs/manual/html_node/emacs/Key-Bindings.html) your favorite key to
`gendoxy-tag` and/or `gendoxy-tag-header` commands.\
Additionally, you can set up your details/tag char configuration.\
Once your setup is done, open a header file, add the header if missing and go with comments!

## Special
gendoxy is written in **purely functional** _elisp_ (no setq or equivalent)\
gendoxy **does not have** any external dependency, even _cl-lib_ is never called!
