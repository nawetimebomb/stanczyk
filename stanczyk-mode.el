;;; stanczyk-mode.el --- A major mode for the Stanczyk programming language -*- lexical-binding: t -*-

;; Version: 0.0.1
;; Author: nawetimebomb
;; Keywords: files, stanczyk
;; Package-Requires: ((emacs "24.3"))
;; Homepage: https://github.com/nawetimebomb/stanczyk

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; A major mode for the Stanczyk programming language.

;;; Code:

(defconst stanczyk-mode-syntax-table
  (with-syntax-table (copy-syntax-table)
    ;; C/C++ style comments
    (modify-syntax-entry ?/ ". 124b")
    (modify-syntax-entry ?* ". 23n")
    (modify-syntax-entry ?\n "> b")
    (modify-syntax-entry ?\^m "> b")
    ;; Chars are the same as strings
    (modify-syntax-entry ?' "\"")
    (syntax-table))
  "Syntax table for `stanczyk-mode'.")

(eval-and-compile
  (defconst stanczyk-constants
    '("true" "false")))

(eval-and-compile
  (defconst stanczyk-keywords
    '("if" "else" "fi" "do" "for" "for*" "loop" "proc" "const" "var" "type"
      "let" "in" "end" "as" "using" "foreign" "builtin" "inline" "local" "like"
      "get-byte" "set" "set*" "set-byte" "---" ".." "struct")))

(eval-and-compile
  (defconst stanczyk-types
    '("int" "float" "bool" "cstring" "string" "any" "byte")))

(defconst stanczyk-highlights
  `((,(regexp-opt stanczyk-keywords 'symbols) . font-lock-keyword-face)
    ("\\b[0-9]+[bfiou]?\\b" . font-lock-constant-face)
    (,(regexp-opt stanczyk-types 'symbols)    . font-lock-type-face)
    (,(regexp-opt stanczyk-constants 'symbols). font-lock-constant-face)))

;;;###autoload
(define-derived-mode stanczyk-mode prog-mode "Stańczyk"
  "Major Mode for editing Stanczyk source code."
  :syntax-table stanczyk-mode-syntax-table
  (setq font-lock-defaults '(stanczyk-highlights))
  (setq-local require-final-newline mode-require-final-newline)
  (setq-local parse-sexp-ignore-comments t)
  (setq-local comment-start-skip "\\(//+\\|/\\*+\\)\\s *")
  (setq-local comment-start "//")
  (setq-local comment-end ""))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.sk\\'" . stanczyk-mode))

(provide 'stanczyk-mode)

;;; stanczyk-mode.el ends here
