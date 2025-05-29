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

(require 'generic-x)

(define-generic-mode
    'stanczyk-mode
  '("//")
  '("if" "if*" "case" "then" "else" "elif" "fi"
    "for" "do" "times" "leave" "let" "in" "end" "defer"
    "var" "const" "fn" "set" "get")
  '(("float"  . font-lock-type-face)
    ("uint"   . font-lock-type-face)
    ("bool"   . font-lock-type-face)
    ("int"    . font-lock-type-face)
    ("string" . font-lock-type-face)
    ("quote"  . font-lock-type-face)
    ("f64"    . font-lock-type-face)
    ("f32"    . font-lock-type-face)
    ("s64"    . font-lock-type-face)
    ("s32"    . font-lock-type-face)
    ("s16"    . font-lock-type-face)
    ("s8"     . font-lock-type-face)
    ("u64"    . font-lock-type-face)
    ("u32"    . font-lock-type-face)
    ("u16"    . font-lock-type-face)
    ("u8"     . font-lock-type-face))
  '("\\.sk$")
  nil
  "Stanczyk mode")

(provide 'stanczyk-mode)

;;; stanczyk-mode.el ends here
