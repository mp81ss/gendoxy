;;; gendoxy.el --- Generate doxygen documentation from C declarations
;;
;; Copyright (C) 2018-2020, Michele Pes, All rights reserved
;;
;; Author:    Michele Pes <mp81ss@rambler.ru>
;; Created:   08 Aug 2020
;; Keywords:  gendoxy, docs, doxygen
;; Version:   1.0.10
;; Homepage:  https://github.com/mp81ss/gendoxy
;;
;;
;; This file is not part of GNU Emacs.
;;
;; Redistribution and use in source and binary forms, with or without
;; modification, are permitted (subject to the limitations in the
;; disclaimer below) provided that the following conditions are met:
;;
;;  * Redistributions of source code must retain the above copyright
;;    notice, this list of conditions and the following disclaimer.
;;
;;  * Redistributions in binary form must reproduce the above copyright
;;    notice, this list of conditions and the following disclaimer in the
;;    documentation and/or other materials provided with the
;;    distribution.
;;
;;  * Neither the name of <Owner Organization> nor the names of its
;;    contributors may be used to endorse or promote products derived
;;    from this software without specific prior written permission.
;;
;; NO EXPRESS OR IMPLIED LICENSES TO ANY PARTY'S PATENT RIGHTS ARE
;; GRANTED BY THIS LICENSE.  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT
;; HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
;; WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
;; MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
;; DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
;; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
;; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
;; SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
;; BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
;; WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
;; OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
;; IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
;;
;;
;;; Commentary:
;;
;; This package provides some commands to generate doxygen documentation.
;; The main command is: 'gendoxy-tag'. It generates the documentation for
;; a C declaration (typedef, variable, struct, enum or function). Moreover, it
;; documents all its items (in struct or enum) too.
;; If you want to document a declaration but NOT its sub-items, just use the
;; command 'gendoxy-tag-header'.
;; Sometimes, you want to document a group of declarations (typically macros
;; or variables. In this case, just use the command 'gendoxy-group'. The same
;; as tag command, using 'gendoxy-group-header', will not comment single items.
;; For groups, since may not be easy to guess start and end of group, two
;; explicit commands have been added: 'gendoxy-group-start' and
;; 'gendoxy-group-end'.
;; The last command is 'gendoxy-header', that will generate the documentation
;; for current file at top of it.
;; There are four variables that can change the gendoxy commands behavior:
;; gendoxy-backslash: if not nil, will use backslash instead of asperand.
;; gendoxy-default-text: Default string used in generated documentation.
;; gendoxy-skip-details: If not nil, will omit details in header and functions
;; gendoxy-details-empty-line: If not nil, will use an empty line instead of the
;; details tag. Note that this has effect if gendoxy-skip-details is nil ONLY.
;;
;;; Change log:
;;
;;  1.0.11 (2021-04-10)
;;  Fixed horrible documentation on parameters without underline
;;  Fixed header generation
;;  Removed non M-d friendly patterns
;;  Removed bad name of non-conformant function
;;  Added support for DLL prototypes
;;  Improved comment for param/return in case of function pointer
;;  If first parameter is out, it will be always inout
;;  Added '()' on documented functions message
;;  Improved documentation
;;
;;  1.0.10 (2020-08-08)
;;  Replaced non-standard alias with core function (thanks to John DeRoo) 
;;  Improved function/var detection
;;  Removed parameter documentation if name is missing
;;  Added/improved tests
;;  Fixed user message
;;
;;  1.0.9 (2020-03-09)
;;  Improved macro documentation
;;  Improved general automatic parameter documentation
;;  Improved internal code
;;  Added various tests
;;  Estethic code changes
;;
;;  1.0.8 (2019-05-30)
;;  Bugfix on backslash handling
;;  Improved some internal functions
;;  Added newline before documentation blocks if missing
;;  Using pseudo-automatic tests
;;
;;  1.0.7 (2018-12-11)
;;  Bugfix on void functions
;;
;;  1.0.6 (2018-12-07)
;;  Improved automatic parameter documentation
;;  Improved internal code
;;
;;  1.0.5 (2018-11-06)
;;  Bugfix on typedef items
;;  Optimized items documentation
;;  Uniformed error messages
;;
;;  1.0.4 (2018-07-04)
;;  Fixed some global variable statement
;;  Fixed some typedef declarations statement
;;  Improved items documentation
;;
;;  1.0.3 (2018-06-21)
;;  Fixed enum/struct documentation
;;
;;  1.0.2 (2018-06-19)
;;  Critical bugfix on invalid C code invocation (due to regex backtracking)
;;  Improved other regex
;;
;;  1.0.1 (2018-06-12)
;;  Fixed bug on structures
;;  Optimized custom parameter documentation generation
;;  Added alignement on items documentation
;;
;;  1.0 (2018-06-04)
;;  Initial version
;;
;;; Code:


(defvar gendoxy-backslash nil
  "If not nil, backslash will be used instead of asperand")

(defvar gendoxy-default-text "Description" "Default documentation text")

(defvar gendoxy-skip-details nil
  "If not nil, will add detail section to header and functions")

(defvar gendoxy-details-empty-line nil
  "If not nil, will add an empty line instead of the details tag for details. \
   Effective if gendoxy-skip-details is nil only")


(defconst gendoxy-nl (string ?\n) "The newline string")

(defconst gendoxy-space-regex "[ \t\v\r\f\n]" "All blanks")

(defconst gendoxy-space-ptr-regex "[ \t\v\r\f\n\\*]" "All blanks plus pointer")

(defconst gendoxy-c-id-regex "[[:alpha:]_][[:alnum:]_]\\{0,30\\}"
  "C identifier regex")

(defconst gendoxy-macro-regexp
  (concat "^[[:space:]]*#[[:space:]]*define[[:space:]]+"
          "\\(" gendoxy-c-id-regex "\\)")
 "Regular expression for #define ... macros returning new defined symbol")

(defconst gendoxy-function-pointer-name-regex
  (concat gendoxy-space-regex "*\\(" gendoxy-c-id-regex gendoxy-space-ptr-regex
          "*\\)+(" gendoxy-space-regex "*\\*" gendoxy-space-regex "*\\("
          gendoxy-c-id-regex "\\)" gendoxy-space-regex "*[()]")
  "Regular expression that searches the name in a function pointer")

(defconst gendoxy-parameters-map
  '("The number of ? to ?"
    "^\\(n$\\|[Cc]ount$\\|[Ll]en\\(gth\\)?\\)$"
    ()

    "The name of the ?"
    "^\\([Nn]ame\\)$"
    ()

    "The name of *"
    "^[Nn]ame_\\(\\([A-Z]\\|[a-z]\\)[a-z]\\{2,\\}\\)$"
    (1)

    "The size of *"
    "^\\(\\([A-Z]\\|[a-z]\\)[a-z]\\{2,\\}\\)_?[Ss]i?ze?$"
    (1)

    "Pointer to buffer to ?"
    "^\\([Bb]uf\\(fer\\)?\\)$"
    ()

    "The number of * to ?"
    "^[Nn]um\\(ber\\)?_?\\(\\([A-Z]\\|[a-z]\\)[a-z]\\{2,\\}\\)$"
    (2)

    "The number of * to ?"
    "^\\(\\([A-Z]\\|[a-z]\\)[a-z]\\{2,\\}\\)_?[Nn]um\\(ber\\)?$"
    (1)

    "The length of *"
    "^[Ll]en\\(gth\\)?_?\\(\\([A-Z]\\|[a-z]\\)[a-z]\\{2,\\}\\)$"
    (2)

    "The length of *"
    "^\\(\\([A-Z]\\|[a-z]\\)[a-z]\\{2,\\}\\)_?[Ll]en\\(gth\\)?$"
    (1)

    "The size of *"
    "^[Ss]i?ze?_?\\(\\([A-Z]\\|[a-z]\\)[a-z]\\{2,\\}\\)$"
    (1)

    "The size of *"
    "^\\(\\([A-Z]\\|[a-z]\\)[a-z]\\{2,\\}\\)_?[Ss]i?ze?$"
    (1)

    "Pointer to *"
    "^[Pp]tr_?\\(\\([A-Z]\\|[a-z]\\)[a-z]\\{2,\\}\\)$"
    (1)

    "Pointer to *"
    "^\\(\\([A-Z]\\|[a-z]\\)[a-z]\\{2,\\}\\)_?[Pp]tr$"
    (1)

    "Pointer to *"
    "^p_\\(\\([A-Z]\\|[a-z]\\)[a-z]\\{2,\\}\\)$"
    (1)

    "The * of *"
    "^\\(\\([A-Z]\\|[a-z]\\)[a-z]\\{2,\\}\\)_\\(\\([A-Z]\\|[a-z]\\)[a-z]\\{2,\\}\\)$"
    (3 1))

  "Parameters comment based on parameter name map")

(defun gendoxy-tag-string ()
  "Return thr tag character as string"
  (if gendoxy-backslash (string ?\\) (string ?@)))

(defun gendoxy-get-typedef-regex (name)
  "Return The regular expression of typedef $name { ... } name ;"
  (concat gendoxy-space-regex "*typedef" gendoxy-space-regex "*" name
          gendoxy-space-regex "*[^{]*{[^}]*}" gendoxy-space-regex
          "*\\(" gendoxy-c-id-regex "\\)[^;]*;"))

(defun gendoxy-get-tag (tag &optional additional-spaces)
  "Return a string that is a doxygen tag, if additional-spaces default to one"
  (let ( (str (concat (gendoxy-tag-string) tag))
         (spaces-number (if additional-spaces additional-spaces 1)) )
    (concat str (make-string spaces-number ?\s))))

(defun gendoxy-get-current-line ()
  "Return the current line without trailing newline"
  (let ((current-line (thing-at-point 'line t)))
    (substring current-line 0 (string-match "\n" current-line))))

(defun gendoxy-get-first-token (current-line)
  "Return the first token if line contains at least 2 tokens or nil"
  (if (string-match (concat "^[[:space:]]*\\([^[:space:]]+\\)"
                            "[[:space:]]+[^[:space:]]+")
                    current-line)
      (match-string 1 current-line)
    nil))

(defun gendoxy-ltrim (str)
  "Remove leading whitespaces from string"
  (if (string-match (concat "^" gendoxy-space-regex "*\\(.*\\)") str)
      (match-string 1 str)
    str))

(defun gendoxy-rtrim (str)
  "Remove trailing whitespaces from string"
  (if (string-match (concat gendoxy-space-regex "$") str)
      (gendoxy-rtrim (substring str 0 (1- (length str))))
    str))

(defun gendoxy-trim (str)
  "Remove leading and trailing spaces from str"
  (gendoxy-ltrim (gendoxy-rtrim str)))

(defun gendoxy-get-statement ()
  "Return current statement as string or nil if no semicolon or open brace \
   or equal char is found as delimiter."
  (move-beginning-of-line 1)
  (if (re-search-forward "\\([^=;{]\\{3,\\}[=;{]\\)" nil t)
      (let* ( (tempnl (match-string 1))
              (temp (replace-regexp-in-string gendoxy-nl " " tempnl)) )
        (gendoxy-trim temp))
    nil))

(defun gendoxy-count-parenthesis-rec (str pattern count)
  "Core recursive function for count-parenthesis"
  (let ((index (string-match pattern str)))
    (if index
        (gendoxy-count-parenthesis-rec (substring str (1+ index))
                                       pattern
                                       (1+ count))
      count)))

(defun gendoxy-count-parenthesis (str)
  "Return (x,y) where x is count of '(' and y is count of ')'"
  (list (gendoxy-count-parenthesis-rec str "(" 0)
        (gendoxy-count-parenthesis-rec str ")" 0)))

(defun gendoxy-add-details (&optional str spaces)
  "Add details according to global variables. Assume starting from newline"
  (unless gendoxy-skip-details
    (progn
      (if gendoxy-details-empty-line
          (insert (concat " *" gendoxy-nl " * "))
        (insert (concat " * " (gendoxy-get-tag "details" spaces))))
      (insert (concat (if str str gendoxy-default-text) gendoxy-nl)))))

(defun gendoxy-add-line-before ()
  "Add an empty line if previous line is not empty"
  (when (= (forward-line -1) 0)
    (if (string-match "^[[:space:]]*[^[:space:]]+" (gendoxy-get-current-line))
        (progn
          (forward-line 1)
          (move-beginning-of-line 1)
          (insert gendoxy-nl))
      (forward-line 1))))

(defun gendoxy-put-macro (macro-name)
  "Document given macro name"
  (gendoxy-add-line-before)
  (move-beginning-of-line 1)
  (insert (concat "/**" gendoxy-nl " * " (gendoxy-get-tag "def")))
  (insert (concat macro-name gendoxy-nl " * " gendoxy-default-text gendoxy-nl
                  " */" gendoxy-nl))
  (message "gendoxy: Macro %s documented" macro-name))

(defun gendoxy-is-doc-line (current-line)
  "Return t if line must end with documentation or nil"
  (and (string-match gendoxy-c-id-regex current-line)
       (string-match (concat "[^{}]" gendoxy-space-regex "*$")
                          current-line)))

(defun gendoxy-get-items-alignement (start index)
  "Calculate alignement of items documentation"
  (if (> (point) start)
      (let* ( (current-line (gendoxy-get-current-line))
              (cur-col (current-column))
              (must-doc-line (gendoxy-is-doc-line current-line)) )
        (if (> (line-number-at-pos)
               (prog2 (forward-line -1) (line-number-at-pos)))
            (move-end-of-line 1)
          (move-beginning-of-line 1))
        (let ((new-index (if must-doc-line (max index cur-col) index)))
          (gendoxy-get-items-alignement start new-index)))
    index))

(defun gendoxy-document-items (start end)
  "Try to document items of a data-structure"
  (goto-char start)
  (let ((real-start (search-forward "{")))
    (goto-char end)
    (forward-line -1)
    (move-end-of-line 1)
    (let ((alignement (gendoxy-get-items-alignement real-start 0)))
      (goto-char end)
      (forward-line -1)
      (move-end-of-line 1)
      (while (> (point) real-start)
        (let ((current-line (gendoxy-get-current-line)))
          (when (gendoxy-is-doc-line current-line)
            (progn
              (move-end-of-line 1)
              (when (> alignement 0)
                (insert (make-string (- alignement (current-column)) ?\s)))
              (insert (concat " /**< " gendoxy-default-text " */")))))
        (if (> (line-number-at-pos)
               (prog2 (forward-line -1) (line-number-at-pos)))
            (move-end-of-line 1)
          (move-beginning-of-line 1))))))

(defun gendoxy-handle-enum-struct (tag-name full)
  "Parse and document an 'enum/struct X { a[,;] b[,;], ... [,;] c };' statement"
  (move-beginning-of-line 1)
  (let ( (org (point)) (terminator (search-forward "}" nil t)) )
    (goto-char org)
    (if (re-search-forward
         (concat "^" gendoxy-space-regex "*" tag-name gendoxy-space-regex
                 "*\\(" gendoxy-c-id-regex "\\)" gendoxy-space-regex "*{"
                 gendoxy-space-regex "*" gendoxy-c-id-regex "[^}]*}")
         terminator
         t)
        (let ((type-name (match-string 1)))
          (when full
            (gendoxy-document-items org (1- (point))))
          (goto-char org)
          (gendoxy-add-line-before)
          (insert (concat "/**" gendoxy-nl " * " (gendoxy-get-tag tag-name)
                          type-name gendoxy-nl " * " gendoxy-default-text
                          gendoxy-nl " */" gendoxy-nl))
          (message "gendoxy: %s %s documented" tag-name type-name))
      (message "gendoxy: Invalid %s was not documented" tag-name))))

(defun gendoxy-handle-typedef-enum-struct (name is-full)
  "Handle typedef enum... or typedef struct... \
   The variable name can be enum or struct.    \
   The variable is-full controls whether its items must be documented"
  (let ((type-name (match-string 1)))
    (gendoxy-add-line-before)
    (insert (concat "/**" gendoxy-nl " * " (gendoxy-get-tag name) type-name
                    gendoxy-nl " * " gendoxy-default-text gendoxy-nl " */"
                    gendoxy-nl))
    (when is-full
      (gendoxy-document-items (point) (search-forward "}" nil t)))
    (message "gendoxy: typedef %s %s documented" name type-name)))

(defun gendoxy-handle-typedef-generic ()
  "Handle generic typedef constructs"
  (let ( (org (point)) (statement (gendoxy-get-statement)) )
    (goto-char org)
    (if statement ; search for a typedef of a function pointer
        (if (string-match (concat "^" gendoxy-space-regex "*typedef"
                                  gendoxy-space-regex "+" gendoxy-c-id-regex
                                  "[^(]*(" gendoxy-space-regex "*\\*"
                                  gendoxy-space-regex "*\\("
                                  gendoxy-c-id-regex "\\)"
                                  gendoxy-space-regex "*[()][^;]+;")
                          statement)
            (let ((name (match-string 1 statement)))
              (gendoxy-add-line-before)
              (insert (concat "/**" gendoxy-nl " * " (gendoxy-get-tag "typedef")
                              name gendoxy-nl))
              (insert (concat " * " gendoxy-default-text gendoxy-nl " */"
                              gendoxy-nl))
              (message "gendoxy: typedef %s documented"
                       (match-string 1 statement)))
          (if (and
               (string-match ; typedef a b c d ... name;
                (concat "^" gendoxy-space-regex "*typedef" gendoxy-space-regex
                        "+\\(" gendoxy-c-id-regex gendoxy-space-ptr-regex
                        "*\\)+" gendoxy-c-id-regex gendoxy-space-regex "*;")
                statement)
               (string-match (concat "\\(" gendoxy-c-id-regex "\\)"
                                     gendoxy-space-regex "*;$")
                             statement))
              (let ((name (match-string 1 statement)))
                (gendoxy-add-line-before)
                (insert (concat "/**" gendoxy-nl " * "
                                (gendoxy-get-tag "typedef") name gendoxy-nl))
                (insert (concat " * " gendoxy-default-text gendoxy-nl " */"
                                gendoxy-nl))
                (message "gendoxy: typedef %s documented" name))
            (message "gendoxy: Invalid typedef was not documented")))
      (message "gendoxy: Fix your code"))))

(defun gendoxy-get-typedef-enum-struct-terminator ()
    "Get terminator for typedef enum/struct, return nil on error"
  (re-search-forward "[{;]" nil t)
  (let ((c (match-string 0)))
    (if c
        (if (string-equal c ";")
            (point)
          (if (and (re-search-forward "}" nil t)
                   (re-search-forward ";" nil t))
              (point)
            nil))
      nil)))

(defun gendoxy-handle-typedef (is-full)
  "Handle typedef constructs"
  (let ( (org (point))
         (terminator (gendoxy-get-typedef-enum-struct-terminator)) )
    (if terminator
        (progn
         (goto-char org)
         (if (re-search-forward (gendoxy-get-typedef-regex "enum") terminator t)
             (progn
               (goto-char org)
               (gendoxy-handle-typedef-enum-struct "enum" is-full))
           (progn
             (goto-char org)
             (if (re-search-forward (gendoxy-get-typedef-regex "struct")
                                    terminator
                                    t)
                 (progn (goto-char org)
                        (gendoxy-handle-typedef-enum-struct "struct" is-full))
               (progn
                 (goto-char org)
                 (gendoxy-handle-typedef-generic))))))
       (message "gendoxy: Fix your code"))))

(defun gendoxy-try-var (statement)
  "Check if statement is a valid variable declaration and if yes document it. \
   Return nil if statement is not a valid variable declaration"
  (if (or (string-match "=" statement) (not (string-match "(" statement)))
      (let ((stm (gendoxy-trim
                  (substring
                   statement 0 (string-match "[\\[=;]" statement)))))
        (if (and (string-match (concat "^\\(" gendoxy-c-id-regex
                                       gendoxy-space-ptr-regex "+\\)+"
                                       gendoxy-c-id-regex "$")
                               stm)
                 (string-match (concat "\\(" gendoxy-c-id-regex "\\)$") stm))
            (let ((name (match-string 1 stm)))
              (gendoxy-add-line-before)
              (insert (concat "/**" gendoxy-nl " * " (gendoxy-get-tag "var")
                              name gendoxy-nl " * " (gendoxy-get-tag "brief")
                              gendoxy-default-text gendoxy-nl " */" gendoxy-nl))
              (message "gendoxy: Variable %s documented" name)
              t)
          (prog2
              (message "gendoxy: Invalid statement was not documented")
              t)))
    nil))

(defun gendoxy-have-return (str)
  "Return nil on error, 0 for void, 1 if not void, 2 for function pointer"
  (if (string-match gendoxy-c-id-regex str)
      (if (or (not (string-match "void" str))
              (string-match "\\*" str)
              (string-match "(" str))
          (let ( (pc (car (gendoxy-count-parenthesis str))))
            (if (>= pc 2) 2 1))
          0)
    nil))

(defun gendoxy-get-direction (parameter)
  "Return t for in or nil for out"
  (let ( (ptr-index (string-match "\\*" parameter))
         (sq-index (string-match "\\[" parameter))
         (const-index (string-match "const" parameter))
         (opener (string-match "(" parameter)) )
    (if (or opener
            (not (or sq-index ptr-index))
            (and sq-index (not ptr-index) const-index)
            (and (not sq-index) ptr-index const-index
                 (< const-index ptr-index))
            (and sq-index ptr-index const-index
                 (< ptr-index const-index)))
        t
      nil)))

(defun gendoxy-dump-parameters (parameters lap)
  "Insert passed parameters into buffer"
  (when parameters
    (progn
      (insert (concat " * " (gendoxy-get-tag "param" 0)))
      (insert (if (and (eq lap 0) (not (cadr parameters))) "[inout]"
                (if (cadr parameters) "[in]" "[out]")))
      (insert (concat " " (car parameters) " " (car (cddr parameters))
                      gendoxy-nl))
      (gendoxy-dump-parameters (seq-drop parameters 3) (1+ lap)))))

(defun gendoxy-find-last (str pattern &optional index)
  "Find last occurrence of pattern in str. Pattern must be one character"
  (let ((found (string-match pattern str (if index (1+ index) 0))))
    (if found (gendoxy-find-last str pattern found) index)))

(defun gendoxy-get-parameters-array-rec (str parameters &optional index)
  "Return a list of parameters as strings implementation"
  (let ((terminator (string-match "," str index)))
    (if terminator
        (let ( (token (substring str 0 terminator))
               (parenthesis (gendoxy-count-parenthesis
                             (substring str 0 terminator))) )
          (if (eq (car parenthesis) (cadr parenthesis))
              (cons token (gendoxy-get-parameters-array-rec
                           (substring str (1+ terminator)) parameters))
            (gendoxy-get-parameters-array-rec str parameters (1+ terminator))))
      (cons str parameters))))

(defun gendoxy-get-parameters-array (str)
  "Return a list of parameters as strings"
  (gendoxy-get-parameters-array-rec str '()))


; This function is correct, but emacs stack does not tolerate it, so I rewrote
; an equivalent, more efficent, less recursive version
; This is recursive on characters, the other is recursive on parenthesis only

;; (defun gendoxy-get-matching-block-rec (str level index)
;;   "Return the string of last parenthesized block implementation"
;;   (if (>= index 0)
;;       (let ((c (elt str index)) (new-index (1- index)))
;;         (if (or (char-equal c ?\() (char-equal c ?\)))
;;             (if (char-equal c ?\()
;;                 (if (eq level 0)
;;                     (substring str index)
;;                   (gendoxy-get-matching-block-rec str (1- level) new-index))
;;               (gendoxy-get-matching-block-rec str (1+ level) new-index))
;;           (gendoxy-get-matching-block-rec str level new-index)))
;;     nil))

(defun gendoxy-get-matching-block-rec (str level index)
  "Return the string of last parenthesized block implementation"
  (let* ( (temp (substring str 0 (1+ index)))
          (last-parenthesis (gendoxy-find-last temp "[()]")) )
    (if (char-equal (elt temp last-parenthesis) ?\))
        (gendoxy-get-matching-block-rec str (1+ level) (1- last-parenthesis))
      (if (eq level 0)
          (substring str last-parenthesis)
        (gendoxy-get-matching-block-rec str (1- level)
                                        (1- last-parenthesis))))))

(defun gendoxy-get-matching-block (str)
  "Return the string of last parenthesized block"
  (let ((parenthesis (gendoxy-count-parenthesis str)))
    (if (> (car parenthesis) 0)
        (gendoxy-get-matching-block-rec str 0 (1- (gendoxy-find-last str ")")))
      nil)))

(defun gendoxy-get-complex-name (str)
  "Return the function name from a prototype without parameters block"
  (if (string-match "(" str)
      (prog2
          (string-match gendoxy-function-pointer-name-regex str)
          (match-string 2 str))
    (prog2
        (string-match (concat "\\(" gendoxy-c-id-regex "\\)"
                              gendoxy-space-regex "*$")
                      str)
        (match-string 1 str))))

(defun gendoxy-get-parameter-patterns (doc regx name indexes)
  "Return the parameter documentation after all substitutions"
  (if (null indexes)
      doc
    (let* ( (index (string-match "\\*" doc))
            (matches (string-match regx name))
            (pattern (downcase (match-string (car indexes) name)))
            (new-doc (concat (substring doc 0 index)
                             pattern
                             (substring doc (1+ index)))) )
      (gendoxy-get-parameter-patterns new-doc regx name (cdr-safe indexes)))))

(defun gendoxy-get-parameter-text-rec (name index)
  "Return a triple of corresponding parameter documentation or nil"
  (if (< index (length gendoxy-parameters-map))
      (let ((ender (+ index 3)))
        (if (string-match (seq-elt gendoxy-parameters-map (1+ index)) name)
            (seq-subseq gendoxy-parameters-map index ender)
          (gendoxy-get-parameter-text-rec name ender)))
    nil))

(defun gendoxy-get-parameter-text (name org-name)
  "Return a custom parameter description or gendoxy-default-text"
  (let ((pc (gendoxy-count-parenthesis org-name)))
    (if (> (car pc) 0) "A pointer to function"
      (let ((lst (gendoxy-get-parameter-text-rec name 0)))
        (if lst
            (let ( (doc (car lst)) (regx (cadr lst)) (indexes (car (cddr lst))))
              (message "<%s>" doc)
              (gendoxy-get-parameter-patterns doc regx name indexes))
          gendoxy-default-text)))))

(defun gendoxy-get-parameters (parameters)
  "Take a list of comma-separated of (complex?) parameters. Return a list of \
   triples (name, 0 for in or 1 for out, txt). Return nil if no parameters"
  (if (or (not parameters) (and (eq (length parameters) 1)
                                (string-equal (gendoxy-trim (car parameters))
                                              "void")))
      nil
    (let* ( (parameter-original (car parameters))
            (direction (gendoxy-get-direction parameter-original))
            (parameter (gendoxy-rtrim (substring parameter-original 0
                                                 (string-match "\\["
                                                       parameter-original))))
            (others (gendoxy-get-parameters (cdr parameters)))
            (param-name (gendoxy-get-complex-name parameter))
            (splitted (split-string parameter-original gendoxy-space-regex t)) )
      (if (and param-name (cdr (split-string parameter-original
                                             gendoxy-space-ptr-regex
                                             t)))
          (cons param-name
                (cons direction
                      (cons (gendoxy-get-parameter-text param-name
                                                        parameter-original)
                            others)))
        others))))

(defun gendoxy-dump-function (name return-code parameters)
  "Dump the function documentation"
  (gendoxy-add-line-before)
  (insert (concat "/**" gendoxy-nl " * " (gendoxy-get-tag "brief")
                  "Summary" gendoxy-nl))
  (gendoxy-add-details)
  (gendoxy-dump-parameters parameters 0)
  (when (>= return-code 1)
    (insert (concat " * " (gendoxy-get-tag "return")
                    (if (eq return-code 2) "A pointer to a function"
                      gendoxy-default-text) gendoxy-nl)))
  (insert (concat " */" gendoxy-nl)))

(defun gendoxy-handle-complex-function (statement)
  "Handle a prototype to a function with some function's pointer"
  (let ((parameters-string (gendoxy-get-matching-block statement)))
    (if parameters-string
        (let* ( (parameters-str (substring parameters-string 1
                                           (gendoxy-find-last parameters-string
                                                              ")")))
                (name-and-ret (substring statement 0
                                         (- (length statement)
                                            (length parameters-string))))
                (have-return (gendoxy-have-return name-and-ret))
                (func-name (gendoxy-get-complex-name name-and-ret))
                (parameters-array (gendoxy-get-parameters-array
                                   parameters-str))
                (parameters (gendoxy-get-parameters parameters-array)) )
          (if (and parameters-string parameters-str func-name have-return)
              (progn
                (gendoxy-dump-function func-name have-return parameters)
                (message "gendoxy: Function %s() documented" func-name))
            (message "gendoxy: Invalid complex function was not documented")))
      (message "gendoxy: Invalid complex function was not documented"))))

(defun gendoxy-handle-simple-function (statement)
  "Document a standard function"
  (let* ( (open-index (string-match "(" statement))
          (close-index (string-match ")" statement))
          (ret-and-name (substring statement 0 open-index))
          (name-index (string-match (concat "\\(" gendoxy-c-id-regex "\\)$")
                                    (gendoxy-rtrim ret-and-name))) )
    (if name-index
        (let* ( (func-name (match-string 1 ret-and-name))
                (return-type (gendoxy-rtrim (substring ret-and-name
                                                       0
                                                       name-index)))
                (have-return (gendoxy-have-return return-type))
                (parameter-tokens (split-string (substring statement
                                                           (1+ open-index)
                                                           close-index)
                                                "," t))
                (parameters (gendoxy-get-parameters parameter-tokens)) )
          (if have-return
              (progn
                (gendoxy-dump-function func-name have-return parameters)
                (message "gendoxy: Function %s() documented" func-name))
            (message "gendoxy: Invalid function was not documented")))
      (message "gendoxy: Invalid function was not documented"))))

(defun gendoxy-handle-func-or-var ()
  "Handle prototypes, (simple or complex (involving function pointers)) and \
   variables"
  (let ( (org (point))
         (statement (replace-regexp-in-string
                     (concat gendoxy-space-regex "*__declspec"
                             gendoxy-space-regex "*\\([^)]+)\\)") " "
                             (gendoxy-get-statement))))
    (goto-char org)
    (if statement
        (unless (gendoxy-try-var statement) ; try to document a variable
          (let ((parenthesis (gendoxy-count-parenthesis statement)))
            (if (eq (car parenthesis) (cadr parenthesis))
                (if (eq (car parenthesis) 1)
                    (gendoxy-handle-simple-function statement)
                  (gendoxy-handle-complex-function statement))
              (message "gendoxy: Fix your code"))))
      (message "gendoxy: Fix your code"))))

(defun gendoxy-tag-core (is-full)
    "Generate general template for source item in current line. \
     The variable is-full controls whether single items must be documented"
    (let ((current-line (gendoxy-get-current-line)))
      (move-beginning-of-line 1)
      (cond
       ((string-match gendoxy-macro-regexp current-line)
        (gendoxy-put-macro (match-string 1 current-line)))
       ((string-match "^[[:space:]]*typedef" current-line)
        (gendoxy-handle-typedef is-full))
       ((string-match "^[[:space:]]*enum" current-line)
        (gendoxy-handle-enum-struct "enum" is-full))
       ((string-match "^[[:space:]]*struct" current-line)
        (gendoxy-handle-enum-struct "struct" is-full))
      (t (gendoxy-handle-func-or-var)))))

(defun gendoxy-header ()
    "Generate generic template header for current file"
    (interactive)
    (goto-char (point-min))
    (insert (concat "/**" gendoxy-nl))
    (insert (concat " * " (gendoxy-get-tag "file" 6) (buffer-name) gendoxy-nl))
    (insert (concat " * " (gendoxy-get-tag "brief" 5) "Header of"
                    gendoxy-nl))
    (insert (concat " * " (gendoxy-get-tag "date" 6) (current-time-string)
                    gendoxy-nl))
    (insert (concat " * " (gendoxy-get-tag "author" 4)
                    (if (string= "" user-full-name)
                        user-real-login-name
                      user-full-name) gendoxy-nl))
    (insert (concat " * " (gendoxy-get-tag "copyright" 1) "BSD-3-Clause"
                    gendoxy-nl))
    (unless gendoxy-skip-details
      (insert (concat " * " gendoxy-nl " * This module" gendoxy-nl)))
    (insert (concat " */" gendoxy-nl gendoxy-nl))
    (message "gendoxy: Header documented in file %s" (buffer-name)))

(defun gendoxy-group-start ()
  "Generate general template for the beginning of a block of items"
  (interactive)
  (gendoxy-add-line-before)
  (move-beginning-of-line nil)
  (insert (concat "/**" gendoxy-nl " * " (gendoxy-get-tag "name")
                  "Group title" gendoxy-nl " * " gendoxy-default-text
                  gendoxy-nl " * " (gendoxy-get-tag "{" 0)
                  gendoxy-nl " */" gendoxy-nl)))

(defun gendoxy-group-end ()
  "Generate general template for the beginning of a block of items"
  (interactive)
  (move-beginning-of-line 1)
  (insert (concat "/**" gendoxy-nl " * " (gendoxy-get-tag "}" 0) gendoxy-nl
                  " */" gendoxy-nl)))

(defun gendoxy-group-core (is-full)
  "Generate general template for a block of items and its items if requested"
  (move-beginning-of-line 1)
  (gendoxy-group-start)
  (let ((first-token (gendoxy-get-first-token (gendoxy-get-current-line))))
    (if first-token
        (progn
          (when is-full
            (progn (move-end-of-line 1) (insert " /**< Description */")))
        (while (and (< (line-number-at-pos) (prog2 (forward-line)
                                                (line-number-at-pos)))
                    (string= first-token (gendoxy-get-first-token
                                          (gendoxy-get-current-line))))
          (when is-full
            (progn (move-end-of-line 1) (insert " /**< Description */"))))
        (unless (char-after)
          (insert gendoxy-nl))
        (gendoxy-group-end)
        (message "gendoxy: Group documented"))
      (message "gendoxy: Parser error"))))

(defun gendoxy-group ()
  "Generate general template for a block of items and its items if requested"
  (interactive)
  (gendoxy-group-core t))

(defun gendoxy-group-header ()
  "Generate general template for a block of items"
  (interactive)
  (gendoxy-group-core nil))

(defun gendoxy-tag ()
    "Generate general template for source item in current line and its items"
    (interactive)
    (gendoxy-tag-core t))

(defun gendoxy-tag-header ()
    "Generate general template for source item in current line"
    (interactive)
    (gendoxy-tag-core nil))


(provide 'gendoxy-header)
(provide 'gendoxy-tag)
(provide 'gendoxy-tag-header)
(provide 'gendoxy-group)
(provide 'gendoxy-group-header)
(provide 'gendoxy-group-start)
(provide 'gendoxy-group-end)


;;; filename ends here
