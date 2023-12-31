;;; vsc-edit-mode.el --- Implement editing experience like VSCode  -*- lexical-binding: t; -*-

;; Copyright (C) 2022-2023  Shen, Jen-Chieh

;; Author: Shen, Jen-Chieh <jcs090218@gmail.com>
;; Maintainer: Shen, Jen-Chieh <jcs090218@gmail.com>
;; URL: https://github.com/emacs-vs/vsc-edit-mode
;; Version: 0.1.0
;; Package-Requires: ((emacs "26.1") (indent-control "0.1.0") (company "0.8.12") (yasnippet "0.8.0") (msgu "0.1.0") (mwim "0.4"))
;; Keywords: convenience editing vs

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; Implement editing experience like VSCode.
;;

;;; Code:

(require 'elec-pair)

(require 'msgu)
(require 'indent-control)
(require 'mwim)
(require 'company)
(require 'yasnippet)

(defgroup vsc-edit nil
  "Implement editing experience like VSCode."
  :prefix "vsc-edit-mode-"
  :group 'tool
  :link '(url-link :tag "Repository" "https://github.com/emacs-vs/vsc-edit-mode"))

(defcustom vsc-edit-prog-modes
  '( actionscript-mode haxe-mode nxml-mode yaml-mode)
  "List of extra `prog-mode'."
  :type 'list
  :group 'vsc-edit)

(defcustom vsc-edit-insert-tab-on-tab nil
  "Insert a tab when tab key instead of the local command."
  :type 'boolean
  :group 'vsc-edit)

;;
;; (@* "Entry" )
;;

(defvar vsc-edit-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "<backspace>") #'vsc-edit-backspace)
    (define-key map (kbd "S-<backspace>") #'vsc-edit-real-backspace)
    (define-key map (kbd "<delete>") #'vsc-edit-delete)
    (define-key map (kbd "S-<delete>") #'vsc-edit-real-delete)
    (define-key map (kbd "SPC") #'vsc-edit-space)
    (define-key map (kbd "S-SPC") #'vsc-edit-real-space)
    (define-key map (kbd "C-v") #'vsc-edit-yank)
    (define-key map [tab] #'vsc-edit-tab)
    (define-key map (kbd "TAB") #'vsc-edit-tab)
    (define-key map [S-tab] #'vsc-edit-shift-tab)
    (define-key map [backtab] #'vsc-edit-shift-tab)
    map)
  "Keymap for `execrun-mode'.")

;;;###autoload
(define-minor-mode vsc-edit-mode
  "Minor mode `vsc-edit'."
  :lighter " VSC-Edit"
  :group vsc-edit
  :keymap vsc-edit-mode-map)

(defun vsc-edit-mode--turn-on ()
  "Turn on the `vsc-edit'."
  (vsc-edit-mode 1))

;;;###autoload
(define-globalized-minor-mode global-vsc-edit-mode
  vsc-edit-mode vsc-edit-mode--turn-on
  :require 'vsc-edit)

;;
;; (@* "Externals" )
;;

(declare-function lsp-format-region "ext:lsp-mode.el")

;;
;; (@* "Util" )
;;

(defmacro vsc-edit--handle-lsp-indent (&rest body)
  "Execute BODY without the `lsp-mode' indent interfering."
  (declare (indent 0) (debug t))
  `(progn
     (remove-function (local 'indent-region-function) #'lsp-format-region)
     ,@body
     (add-function :override (local 'indent-region-function) #'lsp-format-region)))

(defun vsc-edit-delete-region ()
  "Delete region by default value."
  (when (use-region-p) (delete-region (region-beginning) (region-end))))

(defun vsc-edit--in-comment-or-string-p ()
  "Return non-nil if inside comment or string."
  (or (nth 4 (syntax-ppss)) (nth 8 (syntax-ppss))))

(defun vsc-edit--before-first-char-at-line-p (&optional pt)
  "Return non-nil if there is nothing infront of the right from the PT."
  (save-excursion
    (when pt (goto-char pt))
    (null (re-search-backward "[^ \t]" (line-beginning-position) t))))

(defun vsc-edit--current-line-empty-p ()
  "Current line empty, but accept spaces/tabs in there.  (not absolute)."
  (save-excursion (beginning-of-line) (looking-at "[[:space:]\t]*$")))

(defun vsc-edit--first-char-in-line-column ()
  "Return column in first character in line."
  (save-excursion (back-to-indentation) (current-column)))

(defun vsc-edit--get-current-char-string ()
  "Get the current character as the `string''."
  (if (char-before) (string (char-before)) ""))

(defun vsc-edit--current-char-equal-p (c)
  "Check the current character equal to C, C can be a list of character."
  (cond ((and (stringp c) (stringp (vsc-edit--get-current-char-string)))
         (string= (vsc-edit--get-current-char-string) c))
        ((listp c) (member (vsc-edit--get-current-char-string) c))))

(defun vsc-edit--current-whitespace-p ()
  "Check if current character a whitespace character."
  (vsc-edit--current-char-equal-p " "))

(defun vsc-edit-prog-mode-p ()
  "Return non-nil if current buffer is programming mode."
  (or (derived-mode-p 'prog-mode)
      (memq major-mode vsc-edit-prog-modes)))

;;
;; (@* "Backspace" )
;;

(defun vsc-edit-real-backspace ()
  "Just backspace a char."
  (interactive)
  (call-interactively (key-binding (kbd "\177"))))

(defun vsc-edit-smart-backspace ()
  "Smart backspace."
  (interactive)
  (or (and (vsc-edit--before-first-char-at-line-p) (not (bolp))
           (not (use-region-p))
           (vsc-edit--backward-delete-spaces-by-indent-level))
      (vsc-edit-real-backspace)))

;;;###autoload
(defun vsc-edit-backspace ()
  "Backspace."
  (interactive)
  (cond ((use-region-p)
         (delete-region (region-beginning) (region-end)))
        ((vsc-edit-prog-mode-p)
         (vsc-edit-smart-backspace))
        (t
         (vsc-edit-real-backspace))))

;;
;; (@* "Indentation" )
;;

(defun vsc-edit--insert-spaces-by-indent-level ()
  "Insert spaces depends on indentation level configuration."
  (interactive)
  (let* ((count 0)
         (indent-lvl (indent-control-get-indent-level-by-mode))
         (remainder (% (current-column) indent-lvl))
         (target-width (if (= remainder 0) indent-lvl (- indent-lvl remainder))))
    (while (< count target-width)
      (insert " ")
      (cl-incf count))))

(defun vsc-edit--backward-delete-spaces-by-indent-level ()
  "Backward delete spaces using indentation level."
  (interactive)
  (let* ((count 0)
         (indent-lvl (indent-control-get-indent-level-by-mode))
         (remainder (% (current-column) indent-lvl))
         (target-width (if (= remainder 0) indent-lvl remainder))
         success)
    (while (and (< count target-width)
                (not (bolp))
                (vsc-edit--current-whitespace-p))
      (backward-delete-char 1)
      (setq success t)
      (cl-incf count))
    success))

(defun vsc-edit--forward-delete-spaces-by-indent-level ()
  "Forward delete spaces using indentation level."
  (interactive)
  (let* ((count 0)
         (indent-lvl (indent-control-get-indent-level-by-mode))
         (remainder (% (vsc-edit--first-char-in-line-column) indent-lvl))
         (target-width (if (= remainder 0) indent-lvl remainder))
         success)
    (while (and (< count target-width) (not (eolp)))
      (let (is-valid)
        (save-excursion
          (forward-char 1)
          (when (vsc-edit--current-whitespace-p) (setq is-valid t)))
        (when is-valid (backward-delete-char -1) (setq success t)))
      (cl-incf count))
    success))

;;
;; (@* "Delete" )
;;

(defun vsc-edit-real-delete ()
  "Just delete a char."
  (interactive)
  (call-interactively (key-binding (kbd "<deletechar>"))))

(defun vsc-edit-smart-delete ()
  "Smart backspace."
  (interactive)
  (or (and (not (eobp))
           (vsc-edit--before-first-char-at-line-p (1+ (point)))
           (vsc-edit--forward-delete-spaces-by-indent-level))
      (vsc-edit-real-delete)))

;;;###autoload
(defun vsc-edit-delete ()
  "Delete."
  (interactive)
  (cond ((use-region-p)
         (delete-region (region-beginning) (region-end)))
        ((vsc-edit-prog-mode-p)
         (vsc-edit-smart-delete))
        (t
         (vsc-edit-real-delete))))

;;
;; (@* "Space" )
;;

(defun vsc-edit-real-space ()
  "Just insert a space."
  (interactive)
  (insert " "))

(defun vsc-edit-smart-space ()
  "Smart way of inserting space."
  (interactive)
  (if (vsc-edit--current-line-empty-p)
      (let ((pt (point)))
        (ignore-errors (indent-for-tab-command))
        (when (= pt (point)) (vsc-edit-real-space)))
    (if (and (or (vsc-edit--before-first-char-at-line-p) (bolp))
             (not (vsc-edit--in-comment-or-string-p)))
        (vsc-edit--insert-spaces-by-indent-level)
      (vsc-edit-real-space))))

;;;###autoload
(defun vsc-edit-space ()
  "Space."
  (interactive)
  (vsc-edit-delete-region)
  (if (vsc-edit-prog-mode-p)
      (vsc-edit-smart-space)
    (vsc-edit-real-space)))

;;
;; (@* "Yank" )
;;

(defun vsc-edit-yank-indent ()
  "Yank and indent."
  (interactive)
  (let ((reg-beg (point)))
    (call-interactively #'yank)
    (vsc-edit--handle-lsp-indent
      (ignore-errors (indent-region reg-beg (point))))))

(defcustom vsc-edit-yank-ignore-modes
  '( fasm-mode masm-mode nasm-mode
     llvm-mode llvm-mir-mode tablegen-mode
     makefile-mode
     makefile-automake-mode makefile-gmake-mode makefile-bsdmake-mode
     makefile-makepp-mode makefile-imake-mode
     mermaid-mode
     python-mode
     yaml-mode)
  "List of major-modes ignore indent after `yank' command."
  :type 'list
  :group 'vsc-edit)

;;;###autoload
(defun vsc-edit-yank ()
  "Yank and then indent region."
  (interactive)
  (msgu-silent
    (vsc-edit-delete-region)
    (if (or (not (vsc-edit-prog-mode-p))
            (memq major-mode vsc-edit-yank-ignore-modes))
        (call-interactively #'yank)
      (call-interactively #'vsc-edit-yank-indent))))

;;
;; (@* "Backspace" )
;;

(defmacro vsc-edit--with-select-region (&rest body)
  "Execute BODY and save region state."
  (declare (indent 0) (debug t))
  `(let* ((beg (region-beginning)) (end (region-end))
          (at-beg (= (point) beg))
          (ov (make-overlay beg end)))
     (ignore-errors ,@body)
     (goto-char (if at-beg (overlay-end ov) (overlay-start ov)))
     (setq deactivate-mark nil)
     (goto-char (if at-beg (overlay-start ov) (overlay-end ov)))
     (delete-overlay ov)))

(defun vsc-edit--lines-in-region (fnc &optional beg end)
  "Execute FNC each line in region BEG to END."
  (setq beg (or beg (region-beginning))
        end (or end (region-end)))
  (vsc-edit--with-select-region
    (goto-char beg)
    (while (and (<= (line-beginning-position) end) (not (eobp)))
      (let ((delta (line-end-position)))
        (funcall-interactively fnc)
        (setq delta (- (line-end-position) delta)
              end (+ end delta)))
      (forward-line 1))))

(defun vsc-edit-smart-tab ()
  "`prog-mode' tab."
  (interactive)
  (if (use-region-p)
      (vsc-edit--lines-in-region
       (lambda ()
         (back-to-indentation)
         (vsc-edit--insert-spaces-by-indent-level)))
    (unless (ignore-errors (call-interactively #'yas-expand))
      (if (company--active-p)
          (call-interactively #'company-complete-selection)
        (if (vsc-edit--current-line-empty-p)
            (let ((pt (point)))
              (indent-for-tab-command)
              (when (= pt (point)) (vsc-edit--insert-spaces-by-indent-level)))
          (vsc-edit--insert-spaces-by-indent-level))))))

;;;###autoload
(defun vsc-edit-tab ()
  "Global TAB key."
  (interactive)
  (if (or (vsc-edit-prog-mode-p) vsc-edit-insert-tab-on-tab)
      (vsc-edit-smart-tab)
    (funcall-interactively (local-key-binding (kbd "TAB")))))

(defun vsc-edit-smart-shift-tab ()
  "`prog-mode' shift tab."
  (interactive)
  (if (use-region-p)
      (vsc-edit--lines-in-region
       (lambda ()
         (back-to-indentation)
         (let (delete-active-region)
           (vsc-edit--backward-delete-spaces-by-indent-level))))
    (unless (ignore-errors (call-interactively #'yas-expand))
      (if (company--active-p)
          (call-interactively #'company-complete-selection)
        (if (vsc-edit--current-line-empty-p)
            (let ((pt (point)))
              (indent-for-tab-command)
              (when (= pt (point)) (vsc-edit--backward-delete-spaces-by-indent-level)))
          (vsc-edit--backward-delete-spaces-by-indent-level))))))

;;;###autoload
(defun vsc-edit-shift-tab ()
  "Global Shift+TAB key."
  (interactive)
  (if (vsc-edit-prog-mode-p)
      (vsc-edit-smart-shift-tab)
    (funcall-interactively (local-key-binding [S-tab]))))

;;
;; (@* "BOL and EOL" )
;;

;;;###autoload
(defun vsc-edit-beginning-of-visual-line ()
  "Goto the beginning of visual line."
  (interactive)
  (let ((visual-line-column -1) first-line-in-non-truncate-line)
    ;; First, record down the beginning of visual line point
    (save-excursion
      (call-interactively #'beginning-of-visual-line)
      (setq visual-line-column (current-column)))

    ;; Check if is the first line of non-truncate line mode
    (when (= visual-line-column 0)
      (setq first-line-in-non-truncate-line t))

    (if first-line-in-non-truncate-line
        (call-interactively #'mwim-beginning-of-code-or-line)
      (let ((before-pt (point)))
        (call-interactively #'beginning-of-visual-line)

        ;; If before point is the same as the current point ; We call regaulr
        ;; `beginning-of-line' function.
        (when (= before-pt (point))
          (call-interactively #'mwim-beginning-of-code-or-line))))))

;;;###autoload
(defun vsc-edit-end-of-visual-line ()
  "Goto the end of visual line."
  (interactive)
  (let ((before-pt (point)))
    (call-interactively #'end-of-visual-line)
    ;; If before point is the same as the current point; we call regaulr
    ;; `end-of-line' function.
    (when (= before-pt (point)) (call-interactively #'mwim-end-of-line-or-code))))

;;;###autoload
(defun vsc-edit-beginning-of-line ()
  "Goto the beginning of line."
  (interactive)
  (call-interactively (if truncate-lines #'mwim-beginning-of-code-or-line
                        #'vsc-edit-beginning-of-visual-line)))

;;;###autoload
(defun vsc-edit-end-of-line ()
  "Goto the end of line."
  (interactive)
  (call-interactively (if truncate-lines #'mwim-end-of-line-or-code #'vsc-edit-end-of-visual-line)))

(provide 'vsc-edit-mode)
;;; vsc-edit-mode.el ends here
