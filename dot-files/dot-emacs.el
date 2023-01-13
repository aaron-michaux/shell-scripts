
;;; ---------------------------------------------------------------- Setup MELPA

(require 'package)
(add-to-list 'package-archives '("gnu"   . "https://elpa.gnu.org/packages/") t)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
;; Comment/uncomment this line to enable MELPA Stable if desired.  See `package-archive-priorities`
;; and `package-pinned-packages`. Most users will not need or want to do this.
;;(add-to-list 'package-archives '("melpa-stable" . "https://stable.melpa.org/packages/") t)
(package-initialize)

; Bootstrap 'use-package'
(eval-after-load 'gnutls
  '(add-to-list 'gnutls-trustfiles "/etc/ssl/cert.pem"))
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))
(eval-when-compile
  (require 'use-package))
(require 'bind-key)
(setq use-package-always-ensure t)

;;; -------------------------------------------------------------------- Globals
 
;; Added by Package.el.  This must come before configurations of
;; installed packages.  Don't delete this line.  If you don't want it,
;; just comment it out by adding a semicolon to the start of the line.
;; You may delete these explanatory comments.

(setq confirm-kill-emacs 'y-or-n-p)
(setq w32-pass-lwindow-to-system nil)

;; Don't follow URLs when you click on them. (Shakes fist.)
(setq mouse-1-click-follows-link nil)

(setq text-scale-mode-step 1.1)

(setq-default indent-tabs-mode nil)

(setq gc-cons-threshold 100000)
(setq garbage-collection-messages t)

; (setq load-path (append load-path '("~/.emacs.d/")))
(add-to-list 'load-path (concat (getenv "HOME") "/.emacs.d/plugins"))

(setq visible-bell 1)

(menu-bar-mode -1)
(setq frame-title-format "%b")
(put 'narrow-to-region 'disabled nil)
(fset 'yes-or-no-p 'y-or-n-p)

;;; Fixes issues with color in the shell
(add-hook 'shell-mode-hook 'ansi-color-for-comint-mode-on)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(blink-cursor-mode nil)
 '(color-theme-is-global t)
 '(custom-safe-themes
   '("fc5fcb6f1f1c1bc01305694c59a1a861b008c534cae8d0e48e4d5e81ad718bc6" "1e7e097ec8cb1f8c3a912d7e1e0331caeed49fef6cff220be63bd2a6ba4cc365" default))
 '(display-time-mode t)
 '(fringe-mode 0 nil (fringe))
 '(global-font-lock-mode t)
 '(icomplete-mode t)
 '(inhibit-startup-echo-area-message nil)
 '(inhibit-startup-screen t)
 '(initial-frame-alist '((menu-bar-lines . 0) (tool-bar-lines . 0)))
 '(package-selected-packages
   '(bazel yaml-mode clang-format counsel-etags flycheck vertico-prescient php-mode protobuf-mode window-margin wc-mode bytecomp string-inflection visual-regexp-steroids visual-regexp origami projectile vertigo-prescient company-prescient vertigo-precient company-precient prescient which-key vertico vertigo lsp-ui lsp-mode company web-mode prettier-js))
 '(safe-local-variable-values '((TeX-master . "poster")))
 '(scroll-bar-mode nil)
 '(set-fill-column 80)
 '(show-paren-mode t)
 '(tool-bar-mode nil)
 '(tooltip-mode nil))

;;Get rid of tooltips
(setq whitespace-style '(face trailing))

(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(border ((t (:background "black" :width condensed))))
 '(fringe ((((class color) (background dark)) (:background "grey10" :weight thin :width condensed))))
 '(sh-heredoc ((t (:inherit 'font-lock-comment-face)))))

;; Ammend the auto-mode-alist with new aliases for appropriate modes
(setq auto-mode-alist
      (append '(("\\.sc$" . scheme-mode)
		("\\.html$" . html-mode)
		("\\.h$" . c++-mode)
		("\\.cppm$" . c++-mode)
		("\\.cc$" . c++-mode)
                ("\\.hppm$" . c++-mode)
                ("\\.ipp$" . c++-mode)
		("\\.pl$" . prolog-mode)
		("\\.notes$" . flyspell-mode)
                ("\\.text$" . flyspell-mode))
	      auto-mode-alist))

;;; Fix annoyance
(put 'downcase-region 'disabled nil)

;; Upcase is great =0
(put 'upcase-region 'disabled nil)

(set-keyboard-coding-system nil)

(set-fill-column 80)

;;; ---------------------------------------------------------------------- Theme

(add-to-list 'custom-theme-load-path
             (concat (getenv "HOME") "/.emacs.d/themes/"))

;;(load-theme 'zenburn t)
(load-theme 'darcula t)
;;(load-theme 'solarized-light t)
(load-theme 'vscode-dark-plus t)

;; Nice red cursor
(set-cursor-color "#ff0000")
(setq-default cursor-type 'box)

;; Face customization
(defun custom-markdown-colors ()
 (interactive)
 (set-face-foreground 'markdown-inline-code-face "#b50101")
 (set-face-background 'markdown-inline-code-face "gray95"))

(defun what-face (pos)
 (interactive "d")
 (let ((face (or (get-char-property (point) 'read-face-name)
		 (get-char-property (point) 'face))))
  (if face (message "Face: %s" face) (message "No face at %d" pos))))

(defun custom-sh-faces ()
 (interactive)
 (custom-theme-set-faces
  'user
  '(sh-heredoc ((t (:inherit 'font-lock-comment-face)))))
 (set-face-foreground 'sh-heredoc "#Fde17c"))

(add-hook 'shell-script-mode-hook 'custom-sh-faces)
(add-hook 'sh-mode-hook 'custom-sh-faces)

;;; -------------------------------------------------------------- Indent Guides

;(require 'highlight-indent-guides)

;;; --------------------------------------------------------------- Emacs server

;; So we can double-click on files and open in emacs. See "emacs+"
(server-start) 
;; So buffer opened by emacs-client can be cleanly killed
(remove-hook 'kill-buffer-query-functions 'server-kill-buffer-query-function)

;;; --------------------------------------------------- Auto-compile .emacs file

(require 'bytecomp)
(defun autocompile nil
  ;;  (interactive)
  (if (string= (buffer-file-name)
	       (expand-file-name (concat default-directory ".emacs")))
      (if (byte-compile-file (buffer-file-name))
	  (run-at-time 1 nil
		       (lambda () (delete-windows-on "*Compile-Log*"))))))
(add-hook 'after-save-hook 'autocompile)

;;; ------------------------------------------------------------ smarter-backups

(setq
   backup-by-copying t      ; don't clobber symlinks
   backup-directory-alist
    '(("." . "~/.emacs-backups"))    ; don't litter my filesytem
   delete-old-versions t
   kept-new-versions 6
   kept-old-versions 2
   version-control t)       ; use versioned backups

(setq create-lockfiles nil)

;;; -------------------------------------------------------------- Smooth-Scroll

(defun smooth-scroll (increment)
 ;; scroll smoothly by intercepting the mouse wheel and 
 ;; turning its signal into a signal which
 ;; moves the window one line at a time, and waits for 
 ;; a period of time between each move
  (scroll-up increment) (sit-for 0.05)
  (scroll-up increment) (sit-for 0.02)
  (scroll-up increment) (sit-for 0.02)
  (scroll-up increment) (sit-for 0.05)
  (scroll-up increment) (sit-for 0.06)
  (scroll-up increment))
(global-set-key [(mouse-5)] '(lambda () (interactive) (smooth-scroll 1)))
(global-set-key [(mouse-4)] '(lambda () (interactive) (smooth-scroll -1)))

(setq scroll-preserve-screen-position t) ;don't move the cursor when scrolling

;;; -------------------------------------------------------- Additional Commands

(defun what-face (pos)
 (interactive "d")
 (let ((face (or (get-char-property (point) 'read-face-name)
		 (get-char-property (point) 'face))))
  (if face (message "Face: %s" face) (message "No face at %d" pos))))

;;; ---------------------------------------------------------- Buffer Management

;;; Life gets easier when you don't have duplicate buffer names

(require 'uniquify)
(setq uniquify-buffer-name-style 'reverse)
(setq uniquify-separator "|")
(setq uniquify-after-kill-buffer-p t)
(setq uniquify-ignore-buffers-re "^\\*")
(setq column-number-mode t)
(defun save-all () (interactive) (save-some-buffers t))

(defun kill-other-buffers ()
    "Kill all other buffers."
    (interactive)
    (mapc 'kill-buffer 
          (delq (current-buffer) 
                (remove-if-not 'buffer-file-name (buffer-list)))))


;;; ----------------------------------------------------------------- Completion
;; ;;; Can't get by without it
;; (require 'ido)
;; (ido-mode t)
;; (setq ido-enable-flex-matching t)

;; Persist history over Emacs restarts. Vertico sorts by history position.
(use-package savehist
  :init
  (savehist-mode))

(use-package prescient)
(use-package company-prescient)
(use-package vertico-prescient)

;; Enable vertico
(use-package vertico
  :init
  (vertico-mode)
  (vertico-prescient-mode)
  ;; Different scroll margin
  ;; (setq vertico-scroll-margin 0)

  ;; Show more candidates
  ;; (setq vertico-count 20)

  ;; Grow and shrink the Vertico minibuffer
  ;; (setq vertico-resize t)

  ;; Optionally enable cycling for `vertico-next' and `vertico-previous'.
  (setq vertico-cycle t)
  )

;;; ------------------------------------------------------------------------ LSP

(defun setup-lsp ()
 (use-package lsp-mode
  :init
  ;; set prefix for lsp-command-keymap (few alternatives - "C-l", "C-c l")
  (setq lsp-keymap-prefix "C-c l")
  (setq lsp-dired-mode nil)
  (setq lsp-headerline-breadcrumb-enable nil)
  :hook (;; replace XXX-mode with concrete major-mode(e. g. python-mode)
         (c++-mode . lsp)
         (python-mode . lsp)
         ;; if you want which-key integration
         (lsp-mode . lsp-enable-which-key-integration))
  :commands lsp)

 (use-package lsp-ui :commands lsp-ui-mode)

 (add-hook 'c-mode-hook 'lsp)
 (add-hook 'c++-mode-hook 'lsp)

 ;; The lsp server is now really easy to restart
 (setq lsp-keep-workspace-alive nil)
 (setq lsp-idle-delay 0.1)
 (setq lsp-auto-guess-root t)

 (with-eval-after-load 'lsp-mode
  (add-hook 'lsp-mode-hook #'lsp-enable-which-key-integration)))

(when 'true (setup-lsp))

;;; ---------------------------------------------------------------------- Eglot
; eglot is an alternative to LSP, in case I get sick of LSP
; https://github.com/joaotavora/eglot

;;; ---------------------------------------------------------------- Integration

; Vertigo integration
(setq completion-in-region-function
      (lambda (&rest args)
       (apply (if vertico-mode
#'consult-completion-in-region
#'completion--in-region)
              args)))

;; clangd is fast
(setq gc-cons-threshold (* 100 1024 1024)
      read-process-output-max (* 1024 1024)
      company-idle-delay 0.0
      company-minimum-prefix-length 1)

;;; -------------------------------------------------------------- Counsel Etags

(use-package counsel-etags
  :ensure t
  :bind (("C-]" . counsel-etags-find-tag-at-point))
  :init
  (add-hook 'prog-mode-hook
        (lambda ()
          (add-hook 'after-save-hook
            'counsel-etags-virtual-update-tags 'append 'local)))
  :config
  (setq counsel-etags-update-interval 60)
  (push "build" counsel-etags-ignore-directories))

; Don't ask to reload tags file
(setq tags-revert-without-query 1)

;;; ------------------------------------------------------------------ Which Key

; Which-key intgration
(use-package which-key
    :config
    (which-key-mode))

;;; -------------------------------------------------------------------- Company

(use-package company)

;;; ------------------------------------------------------------------- Flycheck

(use-package flycheck)

;;; -------------------------------------------------------------------- Origami

(use-package origami)

;;; -------------------------------------------------------------- visual-regexp

(use-package visual-regexp)
(use-package visual-regexp-steroids)

;;; ---------------------------------------------------------- string-inflection

(use-package string-inflection)

(defun string-inflection-do-my-cycle-function (str)
 "foo_bar => FooBar => fooBar => foo-bar => foo_bar"
   (cond
   ((string-inflection-underscore-p str)
    (string-inflection-pascal-case-function str))
   ((string-inflection-pascal-case-p str)
    (string-inflection-camelcase-function str))
   ((string-inflection-camelcase-p str)
    (string-inflection-kebab-case-function str))
   (t
    (string-inflection-underscore-function str))))

(defun string-inflection-my-style-cycle ()
  "foo_bar => FooBar => fooBar => foo-bar => foo_bar"
  (interactive)
  (string-inflection-insert
   (string-inflection-do-my-cycle-function (string-inflection-get-current-word))))

;;; ----------------------------------------------------------------- Projectile

(use-package projectile)
(projectile-mode +1)

; sort files by recently active buffers and then recently opened files
(setq projectile-sort-order 'recently-active)

; Cache project index
;(setq projectile-enable-caching nil)

;;; ------------------------------------------------------------------ yaml mode

(use-package yaml-mode)

;;; ----------------------------------------------------------------- Word Count

(require 'wc-mode)

;;; ------------------------------------------------------------ mc-auto-encrypt

;; For .cpt files: http://ccrypt.sourceforge.net
(require 'ps-ccrypt)

;;; ------------------------------------------------------------------------ rst

(require 'rst)
(setq auto-mode-alist
      (append '(("\\.txt$" . rst-mode)
                ("\\.rst$" . rst-mode)
                ("\\.rest$" . rst-mode)) auto-mode-alist))

;;; --------------------------------------------------------------------- linum+

(global-display-line-numbers-mode)

;;; ----------------------------------------------------------------------- ebnf

(require 'bnf-mode)
(require 'ebnf-mode)

;;; ---------------------------------------------------------- Copy to Clipboard
;; http://hugoheden.wordpress.com/2009/03/08/copypaste-with-emacs-in-terminal/
;; I prefer using the "clipboard" selection (the one the
;; typically is used by c-c/c-v) before the primary selection
;; (that uses mouse-select/middle-button-click)
(setq x-select-enable-clipboard t)
;;
;; If emacs is run in a terminal, the clipboard- functions have no
;; effect. Instead, we use of xsel, see
;; http://www.vergenet.net/~conrad/software/xsel/ -- "a command-line
;; program for getting and setting the contents of the X selection"
(unless window-system
 (when (getenv "DISPLAY")
  ;; Callback for when user cuts
  (defun xsel-cut-function (text &optional push)
    ;; Insert text to temp-buffer, and "send" content to xsel stdin
    (with-temp-buffer
      (insert text)
      ;; I prefer using the "clipboard" selection (the one the
      ;; typically is used by c-c/c-v) before the primary selection
      ;; (that uses mouse-se;lect/middle-button-click)
      (call-process-region ;
       (point-min) (point-max) "xsel" nil 0 nil "--clipboard" "--input")))
  ;; Call back for when user pastes
  (defun xsel-paste-function()
    ;; Find out what is current selection by xsel. If it is different
    ;; from the top of the kill-ring (car kill-ring), then return
    ;; it. Else, nil is returned, so whatever is in the top of the
    ;; kill-ring will be used.
    (let ((xsel-output (shell-command-to-string "xsel --clipboard --output")))
      (unless (string= (car kill-ring) xsel-output)
	xsel-output )))
  ;; Attach callbacks to hooks
  (setq interprogram-cut-function 'xsel-cut-function)
  (setq interprogram-paste-function 'xsel-paste-function)
  ;; Idea from
  ;; http://shreevatsa.wordpress.com/2006/10/22/emacs-copypaste-and-x/
  ;; http://www.mail-archive.com/help-gnu-emacs@gnu.org/msg03577.html
 ))

;;; --------------------------------------------------------- revert-all-buffers

(defun revert-all-buffers ()
  "Refresh all open file buffers without confirmation.
Buffers in modified (not yet saved) state in emacs will not be reverted. They
will be reverted though if they were modified outside emacs.
Buffers visiting files which do not exist any more or are no longer readable
will be killed."
  (interactive)
  (dolist (buf (buffer-list))
    (let ((filename (buffer-file-name buf)))
      ;; Revert only buffers containing files, which are not modified;
      ;; do not try to revert non-file buffers like *Messages*.
      (when (and filename
                 (not (buffer-modified-p buf)))
        (if (file-readable-p filename)
            ;; If the file exists and is readable, revert the buffer.
            (with-current-buffer buf
              (revert-buffer :ignore-auto :noconfirm :preserve-modes))
          ;; Otherwise, kill the buffer.
          (let (kill-buffer-query-functions) ; No query done when killing buffer
            (kill-buffer buf)
            (message "Killed non-existing/unreadable file buffer: %s"
                     filename))))))
  (message "Finished reverting buffers containing unmodified files."))

;;; -------------------------------------------------- uniquify-all-lines-region

(defun uniquify-all-lines-region (start end)
 "Find duplicate lines in region START to END keeping first occurrence."
 (interactive "*r")
 (save-excursion
  (let ((end (copy-marker end)))
   (while
     (progn
      (goto-char start)
      (re-search-forward "^\\(.*\\)\n\\(\\(.*\n\\)*\\)\\1\n" end t))
    (replace-match "\\1\n\\2")))))

;;; ------------------------------------------------------------------ Debugging

;; Prevent GDB from stealing windows. Seriously emacs.
(defadvice gdb-inferior-filter
    (around gdb-inferior-filter-without-stealing)
  (with-current-buffer (gdb-get-buffer-create 'gdb-inferior-io)
    (comint-output-filter proc string)))
(ad-activate 'gdb-inferior-filter)

;;; --------------------------------------------------------- Window Margin Mode

(require 'window-margin)
(setq window-margin-width 100)
 
;;; ---------------------------------------------------------------------- Latex

(setq latex-run-command "pdflatex")
;(eval-after-load "tex" 
; '(add-to-list 'TeX-command-list '("Make" "make" TeX-run-command nil t))) 
;(add-hook 'LaTeX-mode-hook 'turn-on-flyspell)
(add-hook 'tex-mode-hook 'turn-on-flyspell)
(add-hook 'tex-mode-hook 
	  (lambda ()
	   (set-fill-column 80)
	   (window-margin-mode)
           (wc-mode)
	   (turn-on-flyspell)))

;;; ----------------------------------------------------------------- tads3 mode

;; Swapq-fill
(autoload 'starx-swap-quotes-fill "swapq-fill.el")
(global-set-key (kbd "<f8>") 'starx-swap-quotes-fill)

;; For tads mode
;(autoload 'tads-mode "tads-mode" "TADS 2 editing mode." t)
(autoload 'ctads-mode "ctads-mode" "Major mode for editing TADS3 code" t)

(setq ctads-prettify-multiline-strings t)

(setq auto-mode-alist
      (append (list (cons "\\.t$" 'ctads-mode))
              auto-mode-alist))
(add-hook 'ctads-mode-hook 
	  (lambda ()
	   (set-fill-column 80)
	   (longlines-mode)
	   (turn-on-flyspell)))

;;; ---------------------------------------------------------------------- C/C++

(require 'cc-mode)
(setq c-basic-indent 2)
(setq-default c-basic-offset 2)
(setq tab-width 2)
(setq indent-tabs-mode nil)

(require 'modern-cpp-font-lock)

(defun my-cpp-setup ()
   (interactive)
   (c-set-offset 'innamespace [0])
   (modern-c++-font-lock-global-mode t)
   (company-mode)
   (company-prescient-mode)
   ;(flycheck-mode)
   )
(add-hook 'c-mode-hook 'my-cpp-setup)
(add-hook 'c++-mode-hook 'my-cpp-setup)

(add-hook 'c-mode-hook #'lsp-deferred)
(add-hook 'c++-mode-hook #'lsp-deferred)

;;; --------------------------------------------------------------- clang format

(use-package clang-format)

;; (add-hook 'clang-format-buffer '(c-mode-hook c++-mode-hook))

(with-eval-after-load 'cc-mode
 (fset 'c-indent-region 'clang-format-region))

;; clang-format-on-save
(defun my-clang-format-before-save ()
  "Usage: (add-hook 'before-save-hook 'clang-format-before-save)."
  (interactive)
  (when (eq major-mode 'c++-mode) (clang-format-buffer))
  (when (eq major-mode 'c-mode) (clang-format-buffer)))

(add-hook 'before-save-hook 'my-clang-format-before-save)
 
;;; ----------------------------------------------------------- Protocol Buffers

(require 'protobuf-mode)
(defconst my-protobuf-style
 '((c-basic-offset . 2)
   (indent-tabs-mode . nil)))

(add-hook 'protobuf-mode-hook
          (lambda () (c-add-style "my-style" my-protobuf-style t)))
(setq auto-mode-alist
      (append (list (cons "\\.proto$" 'protobuf-mode))
              auto-mode-alist))

;;; -------------------------------------------------------------------- Haskell
 
(setq haskell-program-name "ghci")

;;; --------------------------------------------------- Working with Scheme/Lisp

(require 'scheme)

(setq scheme-program-name "csi")

(setq c-indent-level 1)
(setq c-continued-statement-offset 0)
(setq c-brace-offset 0)
(setq c-argdecl-indent 0)
(setq c-label-offset 0)
(setq lisp-body-indent 1)
(put 'when 'scheme-indent-function 1)
(put 'unless 'scheme-indent-function 1)
(put 'syntax-rules 'scheme-indent-function 1)
(put 'eval-when 'scheme-indent-function 1)
(put 'with-font 'scheme-indent-function 1)
(put 'call-with-postscript-file 'scheme-indent-function 1)
(put 'parallel-do 'scheme-indent-function 2)

(defun collapse-whitespace-sexp ()
 "Kill whitespace after sexp, remove newline if trailing closing
bracket is present"
 (interactive "*")
 (save-excursion
 (save-restriction
  (save-match-data
   (progn
    (re-search-backward "[^ \t\r\n]" nil t)
    (re-search-forward "[ \t\r\n]+" nil t)
    (if (and (< (+ (match-end 0) 1) (point-max))
             (char-equal ?\) (char-after (match-end 0))))
      (replace-match "" nil nil)
     (goto-char (match-beginning 0))
     (delete-blank-lines)))))))

(defun nuke-whitespace ()
 "Kill next block of whitespace"
 (interactive "*")
 (save-excursion
 (save-restriction
  (save-match-data
   (progn
    (re-search-forward "[ \t\r\n]+" nil t)
    (replace-match "" nil nil))))))

;;; ---------------------------------------------------------------------- bison

(require 'bison-mode)
(add-to-list 'auto-mode-alist '("\\.y$" . bison-mode))

;;; -------------------------------------------------------------- coffee-script

(require 'coffee-mode)
(add-to-list 'auto-mode-alist '("\\.coffee$" . coffee-mode))
(add-to-list 'auto-mode-alist '("Cakefile" . coffee-mode))

(require 'flymake-coffee)
(add-hook 'coffee-mode-hook 'flymake-coffee-load)
(defun coffee-custom ()
  "coffee-mode-hook"

  ;; Emacs key binding
  (setq tab-width 4)
  (define-key coffee-mode-map [(meta r)] 'coffee-compile-buffer))

(add-hook 'coffee-mode-hook '(lambda () (coffee-custom)))

;;; ------------------------------------------------------------------------ php
(use-package php-mode)
(require 'php-mode)
(setq auto-mode-alist
  (append '(("\\.php$" . php-mode)
            ("\\.module$" . php-mode))
              auto-mode-alist))

;;; ---------------------------------------------------------------------- ninja

(require 'ninja-mode)
(setq auto-mode-alist
  (append '(("\\.ninja$" . ninja-mode)
            ("\\.mobius$" . ninja-mode))
          auto-mode-alist))

;;; ----------------------------------------------------------------------- GLSL

(autoload 'glsl-mode "glsl-mode" nil t)
  (add-to-list 'auto-mode-alist '("\\.glsl\\'" . glsl-mode))
  (add-to-list 'auto-mode-alist '("\\.vert\\'" . glsl-mode))
  (add-to-list 'auto-mode-alist '("\\.frag\\'" . glsl-mode))
  (add-to-list 'auto-mode-alist '("\\.geom\\'" . glsl-mode))

;;; ------------------------------------------------------------------ cuda-mode

(require 'cuda-mode)

;;; ------------------------------------------------------------------- markdown

(use-package markdown-mode)

;; (autoload 'markdown-mode "markdown-mode"
;;    "Major mode for editing Markdown files" t)
(add-to-list 'auto-mode-alist '("\\.markdown\\'" . markdown-mode))
(add-to-list 'auto-mode-alist '("\\.md\\'" . markdown-mode))

;; (autoload 'gfm-mode "markdown-mode"
;;    "Major mode for editing GitHub Flavored Markdown files" t)
;; (add-to-list 'auto-mode-alist '("README\\.md\\'" . gfm-mode))

(add-hook 'markdown-mode-hook 'visual-line-mode)
(add-hook 'markdown-mode-hook 'flyspell-mode)

;;; ---------------------------------------------------------------------- Bazel

(use-package bazel)

(add-to-list 'auto-mode-alist '("BUILD" . bazel-build-mode))
(add-to-list 'auto-mode-alist '("WORKSPACE" . bazel-workspace-mode))
(add-to-list 'auto-mode-alist '("\\.bzl\\'" . bazel-starlark-mode))

;;; -------------------------------------------------------------- column-marker
;; http://www.emacswiki.org/emacs/fill-column-indicator.el
;;(require 'fill-column-indicator)
(defun column80 ()
 (interactive)
 (setq display-fill-column-indicator-column 80)
 (display-fill-column-indicator-mode))

(defun column90 ()
 (interactive)
 (setq display-fill-column-indicator-column 90)
 (display-fill-column-indicator-mode))

(defun column100 ()
 (interactive)
 (setq display-fill-column-indicator-column 100)
 (display-fill-column-indicator-mode))

(defun column0 ()
 (interactive)
 (setq display-fill-column-indicator-column 999999)
 (display-fill-column-indicator-mode))

;; (add-hook 'c-mode-hook 'fci-mode)
(add-hook 'c-mode-hook 'column100)
(add-hook 'c++-mode-hook 'column100)
(add-hook 'emacs-lisp-mode-hook 'column80)
(add-hook 'tex-mode-hook 'column0)
(add-hook 'python-mode-hook 'column0)

;;; --------------------------------------------------- adding words to flyspell

(eval-when-compile (require 'cl))

(defun append-aspell-word (new-word)
 (let ((header "personal_ws-1.1")
       (file-name (substitute-in-file-name "$HOME/.aspell.en.pws"))
       (read-words (lambda (file-name)
                    (let ((all-lines (with-temp-buffer
                                      (insert-file-contents file-name)
                                      (split-string (buffer-string) "\n" t))))
                     (if (null all-lines)
                       ""
                      (split-string (mapconcat 'identity (cdr all-lines) "\n")
                                    nil 
                                    t))))))
  (when (file-readable-p file-name)
   (let* ((cur-words (eval (list read-words file-name)))
          (all-words (delq header (cons new-word cur-words)))
          (words (delq nil (remove-duplicates all-words :test 'string=))))
    (with-temp-file file-name     
     (insert (concat header 
                     " en "
                     (number-to-string (length words))
                     "\n"
                     (mapconcat 'identity (sort words #'string<) "\n"))))))
  (unless (file-readable-p file-name)
   (with-temp-file file-name
    (insert (concat header " en 1\n" new-word "\n")))))
 (ispell-kill-ispell t) ; restart ispell
 (flyspell-mode)
 (flyspell-mode))

(defun append-aspell-current ()
 "Add current word to aspell dictionary"
 (interactive)
 (append-aspell-word (thing-at-point 'word)))

;;; ------------------------------------------------------------------------ Mac

(setq mac-option-key-is-meta nil)
(setq mac-command-key-is-meta t)
(setq mac-command-modifier 'meta)
(setq mac-option-modifier 'super)

;; read in PATH from .bashrc
(if (not (getenv "TERM_PROGRAM"))
  (setenv "PATH"
	  (shell-command-to-string 
	   "source $HOME/.bashrc && printf '%s' \"$PATH\"")))

;; On mac
(setq ns-pop-up-frames nil)

;;; ------------------------------------------------------------------ Blake's-7

;; Special font-size on 'blakes-7
(when (string= system-name "blakes-7")
 (set-face-attribute 'default nil :height 200))
(when (string= system-name "cube")
 (set-face-attribute 'default nil :height 200))
(when (string= system-name "ares")
 (set-face-attribute 'default nil :height 120))
(when (string= system-name "hermes")
 (set-face-attribute 'default nil :height 132))
(when (string= system-name "epb-work")
 (set-face-attribute 'default nil :height 200))
(when (string= system-name "DWH7Y69M2G") ; broadcom mac laptop
 (set-face-attribute 'default nil :height 120)
 (setq clang-format-executable "/opt/homebrew/bin/clang-format"))


(when window-system
 (set-frame-position (selected-frame) -30 10)
 (set-frame-size (selected-frame) 180 46))

(global-set-key [(super w)] 'count-words)
(global-set-key [(super f)] 'flycheck-mode)
(global-set-key [(super k)] 'kill-this-buffer)
(global-set-key [(super K)] 'kill-some-buffers)
(global-set-key [(super v)] 'visual-line-mode)
(global-set-key [(super p)] 'highlight-indent-guides-mode)
(global-set-key (kbd "C-;") 'comment-region)
(global-set-key (kbd "C-:") 'uncomment-region)
(global-set-key (kbd "C-+") 'text-scale-adjust)
(global-set-key (kbd "C--") 'text-scale-adjust)
(global-set-key (kbd "C-0") 'text-scale-adjust)
(global-set-key (kbd "S-C-<left>") 'shrink-window-horizontally)
(global-set-key (kbd "S-C-<right>") 'enlarge-window-horizontally)
(global-set-key (kbd "S-C-<down>") 'shrink-window)
(global-set-key (kbd "S-C-<up>") 'enlarge-window)
(global-set-key [(super s)] 'shell)
(global-set-key [(super l)] 'save-all)            ; save-all, (super s) not work
(global-set-key [(super z)] 'undo)                ; undo. Press C-r to make redo
(global-set-key [(super x)] 'kill-region)         ; cut
(global-set-key [(super c)] 'copy-region-as-kill) ; copy
(global-set-key [(super v)] 'yank)                ; paste
(global-set-key (kbd "M-v") 'yank-pop)            ; paste previous
(global-set-key [(super %)] 'query-replace)       ; mac queryreplace alternative
(global-set-key [(super u)] 'string-inflection-my-style-cycle)

(global-set-key (kbd "s-i") 'append-aspell-current) ; aspell word at cursor

(global-set-key (kbd "C-c i") 'clang-format-region) ; clang-format
(global-set-key (kbd "C-c u") 'clang-format-buffer)
(global-set-key [C-M-tab] 'clang-format-region)

(global-set-key (kbd "C-]") 'counsel-etags-find-tag-at-point)

(define-key global-map (kbd "C-c o u") 'origami-undo) ; Origami
(define-key global-map (kbd "C-c o r") 'origami-redo)
(define-key global-map (kbd "C-c o t") 'origami-toggle-node)
(define-key global-map (kbd "C-c o o") 'origami-open-all-nodes)
(define-key global-map (kbd "C-c o q") 'origami-reset)

(define-key global-map (kbd "C-c r") 'vr/replace)     ; Visual regexp
(define-key global-map (kbd "C-c q") 'vr/query-replace)
(define-key global-map (kbd "C-s") 'isearch-forward-regexp)  ;; C-M-r
(define-key global-map (kbd "C-r") 'isearch-backward-regexp) ;; C-M-s

;; Projectile-map
(define-key projectile-mode-map (kbd "C-c p") 'projectile-command-map)
;;; Shortcuts
; C-c p f     => Find files in project
; C-c p d     => Find directory in project
; C-c p R     => Regenerate etags/gtags
; C-c p b     => Switch to project buffer
; C-c p g     => Grep the project
; C-c p j     => Find a tag in the project
; C-c p o     => Run multi-occur on project buffers

; C-c p k     => Kill all project buffers
; C-c p s     => Switch project

; C-u C-c p f => Invalidate project cache before finding files

;; Navigation, press [f1] to mark a point, and then M-f1 to jump back to it
(global-set-key [f1] (lambda ()(interactive) (point-to-register 1)))
(global-set-key [(super f1)] (lambda ()(interactive) (jump-to-register 1)))
(global-set-key [f2] (lambda ()(interactive) (point-to-register 2)))
(global-set-key [(super f2)] (lambda ()(interactive) (jump-to-register 2)))



(global-set-key (kbd "TAB") 'indent-for-tab-command)
(global-set-key [(super e)] 'eval-region)
(global-set-key (kbd "M-e") 'eval-region)

;; Shift+Arrow to move between buffers
(when (fboundp 'windmove-default-keybindings)
  (windmove-default-keybindings))

;; NOTE: use M-x view-lossage, to see the last few keystrokes. (RE: overwrite)

