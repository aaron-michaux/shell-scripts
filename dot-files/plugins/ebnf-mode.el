;;; ebnf-mode.el --- ebnf-mode is simple mode for Extended Backus-Naur Form
;; 
;; Filename: ebnf-mode.el
;; Description: ebnf-mode is simple mode for Extended Backus-Naur Form.
;; Author: Tomáš Frýda
;; Maintainer: Tomáš Frýda
;; Copyright (C) 2012, Tomáš Frýda, all rights reserved.
;; Created: Sat Sep 29 12:04:06 2012 (UTC)
;; Version: 0.0.1
;; Last-Updated:  
;;           By: 
;;     Update #: 0
;; URL: 
;; Keywords: 
;; Compatibility: 
;; 
;; Features that might be required by this library:
;;
;;   None
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 
;;; Commentary: 
;; 
;; 
;; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 
;;; Change log: 
;; 
;; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;; 
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;; 
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.
;; 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 
;;; Code:

(define-derived-mode ebnf-mode
  fundamental-mode
  "ebnf-mode"
  "ebnf-mode is simple mode for Extended Backus-Naur Form."
  (set (make-local-variable 'font-lock-defaults) '((("^\\([^=\n]*\\\)=" 1 font-lock-keyword-face)
						    ("\\?[^\\?]+\\?" . font-lock-constant-face))))
  (set (make-local-variable 'comment-start) "(*")
  (set (make-local-variable 'comment-end)   "*)")
  (set (make-local-variable 'indent-line-function) 'ebnf-indent-line) 
  (modify-syntax-entry ?' "|")
  (modify-syntax-entry ?\( ". 1")
  (modify-syntax-entry ?\) ". 4")
  (modify-syntax-entry ?* ". 23"))

(defun ebnf-indent-line ()
  "Indent current line as EBNF"
  (interactive)
  (save-excursion
  (beginning-of-line)
  (if (bobp)
      (indent-line-to 0)
    (let ((indentation (save-excursion (forward-line -1)
				       (current-indentation)))
	  (byeq nil))
      (if (zerop indentation) 
	  (save-excursion (forward-line -1)
			  (beginning-of-line)
			  (search-forward "=" nil t)
			  (setq byeq t)
			  (setq indentation (- (point) (line-beginning-position) 1))))

      (if (looking-at "^[ \t]*|")
	  (indent-line-to indentation)
	(and (save-excursion
	       (forward-line -1)
	       (end-of-line)
	       (looking-back ",[ \t]*\\((\\*.*\\*)\\)?$"))
	     (indent-line-to (+ indentation (if byeq 2 0)))))))))
  
      


(add-to-list 'auto-mode-alist '("\\.ebnf\\'" . ebnf-mode))

(provide 'ebnf-mode)  
  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; ebnf-mode.el ends here

