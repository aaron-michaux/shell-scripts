;;; swapq-fill.el --- Hack for filling single quote strings in TADS and similar

;; Copyright (c) by Philip Swartzleonard 2001 May

;; Author: Philip Swartzleonard <starx@pacbell.net>
;; Created: 13 May 2001
;; Version: 0.8
;; Keywords: tools convenience c

;; Developed with GNU Emacs 20.7.1 under Windows 98

;; swap-quotes-fill is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 2, or (at
;; your option) any later version.
;;
;; swap-quotes-fill is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;;; Commentary:

;; This is a function that arose out of a need to properly wrap
;; single quoted strings in TADS, due to setting a property to a
;; method such as "prop = {me.xsay('A long single quoted
;; string');}". Running alt-q on such a string caused the string to be
;; merged with the previous and next properties and generally make a
;; huge mess. This circumvents the messiness by swapping the single
;; quotes for double quotes and calling the standard fill function.

;; It is at version .8 because it doesn't work properly if the point
;; isn't within a proper string for it to work with, and it will make
;; a mess if used as such. It doesn't use a very robust method of
;; telling if it's in a string. It also uses a hack to remember the end
;; of the string for when after fill-para's done with it. But it does
;; do its job when used properly <g>.

;; To use, just place it in the load path and put 
;;
;; (autoload 'starx-swap-quotes-fill "swapq-fill.el")
;;
;; in a convenient place such as your .emacs file. That's the most
;; friendly way to do it. Also, you can add a command like
;;
;; (global-bind-key [f8] 'starx-swap-quotes-fill)
;;
;; to be able to use the function as a keyboard command

;; You can change the value of starx-swap-sentinel, if you like, to
;; change the transient character string that the function uses to
;; remember where the closing is, but as it is set to something that is
;; highly unlikely to appear just before a quote mark, there shouldn't be
;; a problem.

;; Feel free to cannibalize this to your heart's content.

;;; Variables:
;;    starx-swap-sentinel
;;; Functions:
;;    starx-swap-quotes-fill
;;    starx-forward-quote
;;    starx-backward-quote

;;; Code:

(provide 'starx-swap-quotes-fill)
(provide 'starx-forward-quote)
(provide 'starx-backward-quote)

(defvar starx-swap-sentinel "x#y%z!"
	"The string that is used as a  sentinel in `starx-swap-quotes-fill'.
It should be fine to leave it as it is unless your string have some
weird characters in them.")




(defun starx-swap-quotes-fill ()
  "Fills a single quoted string in a TADS or similar source file.
Fills the string around point by doing some hack work, calling
fill-paragraph, and undoing its hacks. Designed to get around a
problem with filling single quoted strings normally. You can change
`starx-swap-sentinel' if you need to use wierd characters at the end
of the string and it's interfering. Uses sub-functions
`starx-forward-quote' and `starx-backward-quote'."
  (interactive)
  (let (beg end)
  (save-excursion
    (starx-backward-quote)
    (setq beg (point))
    (delete-char 1)
    (insert "\"")
    (starx-forward-quote)
    (delete-char -1)
    (insert (concat starx-swap-sentinel "\"")))

  ;;Remove save excursion
  ;;to make point sure to be in string
  ;;Plus fill is expected to put the point after
  
  (fill-paragraph nil)
  (goto-char beg)
  (delete-char 1)
  (insert "'")
  (search-forward (concat starx-swap-sentinel "\""))
  (delete-char (- -1 (length starx-swap-sentinel)))
  (insert "'")  ))


(defun starx-backward-quote (&optional quote)
  "Sets point to the previous non-escape quote character.
Uses single quotes by default, if a variable is not passed to it. It
is essentially the opposite of it's sister `starx-forward-quote'."
  (or quote (setq quote "'"))
  (let ((go t))
    (if (not (equal
	      quote
	      (char-to-string (char-before (1+ (point)))) ))
	(while go
	  (re-search-backward quote nil t)
	  (if (not (equal "\\" (char-to-string (char-before  (point))) ) ) 
	      (setq go nil) ) ))))

(defun starx-forward-quote (&optional quote)
  "Sets point to just after the next non-escape quote character.
Uses single quotes by default, if a variable is not passed to it. It
is essentially the opposite of it's sister `starx-backward-quote'."
  (or quote (setq quote "'"))
  (let ((go t))
    (if (not (equal
	      quote
	      (char-to-string (char-before (1+ (point)))) ))
	(while go
	  (re-search-forward quote nil t)
	  (if (not (equal "\\" (char-to-string
				(char-before 
				 (1- (point)) )))) 
	      (setq go nil) )))))

;;; swap1-fill.el ends here
