;;; stanczyk-mode.el --- A major mode for the Stanczyk programming language -*- lexical-binding: t -*-

;; Version: 0.0.1
;; Author: nawetimebomb
;; Keywords: files, porth
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

(defvar stanczyk-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?/ ". 124b" table)
    (modify-syntax-entry ?* ". 23" table)
    (modify-syntax-entry ?\n "> b" table)
    (modify-syntax-entry ?\' "\"" table)
    (modify-syntax-entry ?\" "\"" table)

    (modify-syntax-entry ?@ "w" table)
    (modify-syntax-entry ?\) "w" table)
    (modify-syntax-entry ?\( "w" table)
    (modify-syntax-entry ?? "w" table)
    (modify-syntax-entry ?! "w" table)
    (modify-syntax-entry ?= "w" table)
    (modify-syntax-entry ?+ "w" table)
    (modify-syntax-entry ?- "w" table)
    (modify-syntax-entry ?> "w" table)
    (modify-syntax-entry ?< "w" table)
    table))

(defvar stanczyk-keywords
  '("if" "times" "let" "peek" "---"))


(defvar stanczyk-types
  '("float" "uint" "bool" "int" "string" "quote"
    "f64" "f32" "s64" "s32" "s16" "s8" "u64" "u32" "u16" "u8"))


(setq stanczyk-builtins
  '("println" "print" "=" ">" "<" ">=" "<=" "!=" "or" "and" "dup" "swap" "drop"))

(defvar stanczyk-constants
  '("nil" "true" "false"))

(defvar stanczyk-font-lock-keywords
  `((,(regexp-opt stanczyk-types 'words) . font-lock-type-face)
    (,(regexp-opt stanczyk-keywords 'words) . font-lock-keyword-face)
    (,(regexp-opt stanczyk-builtins 'words) . font-lock-builtin-face)
    (,(regexp-opt stanczyk-constants 'words) . font-lock-constant-face)))

;;;###autoload
(define-derived-mode stanczyk-mode prog-mode "Stańczyk"
  "A major mode for the Stanczyk programming language."
  :syntax-table stanczyk-mode-syntax-table
  (setq-local font-lock-defaults '(stanczyk-font-lock-keywords))
  (setq-local comment-start "// ")
  (setq-local comment-end ""))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.sk\\'" . stanczyk-mode))

(provide 'stanczyk-mode)

;;; stanczyk-mode.el ends here
