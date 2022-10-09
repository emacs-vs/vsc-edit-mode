;;; vsc-edit-mode.el --- Implement editing experience like VSCode  -*- lexical-binding: t; -*-

;; Copyright (C) 2022  Shen, Jen-Chieh

;; Author: Shen, Jen-Chieh <jcs090218@gmail.com>
;; Maintainer: Shen, Jen-Chieh <jcs090218@gmail.com>
;; URL: https://github.com/emacs-vs/vsc-edit-mode
;; Version: 0.1.0
;; Package-Requires: ((emacs "26.1") (indent-control "0.1.0"))
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

(require 'indent-control)

(defgroup vsc-edit-mode nil
  "Implement editing experience like VSCode."
  :prefix "vsc-edit-mode-"
  :group 'tool
  :link '(url-link :tag "Repository" "https://github.com/emacs-vs/vsc-edit-mode"))

;;
;; (@* "Entry" )
;;

(defvar vsc-edit-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "<backspace>") #'vsc-edit-mode-backspace)
    (define-key map (kbd "S-<backspace>") #'vsc-edit-mode-backspace)
    (define-key map (kbd "<delete>") #'execrun-previous)
    (define-key map (kbd "S-<delete>") #'execrun-next)
    map)
  "Keymap for `execrun-mode'.")

(defun vsc-edit-mode--enable ()
  "Enable `vsc-edit-mode'."
  )

(defun vsc-edit-mode--disable ()
  "Disable `vsc-edit-mode'."
  )

;;;###autoload
(define-minor-mode vsc-edit-mode
  "Minor mode `vsc-edit-mode'."
  :group vsc-edit-mode
  :lighter nil
  :keymap vsc-edit-mode-map
  (if vsc-edit-mode (vsc-edit-mode--enable) (vsc-edit-mode--disable)))

(defun vsc-edit-mode--turn-on ()
  "Turn on the `vsc-edit-mode'."
  (vsc-edit-mode 1))

;;;###autoload
(define-globalized-minor-mode global-vsc-edit-mode
  vsc-edit-mode vsc-edit-mode--turn-on
  :require 'vsc-edit-mode)

;;
;; (@* "Util" )
;;

(defun vsc-edit-mode--before-first-char-at-line-p (&optional pt)
  "Return non-nil if there is nothing infront of the right from the PT."
  (save-excursion
    (when pt (goto-char pt))
    (null (re-search-backward "[^ \t]" (line-beginning-position) t))))

;;
;; (@* "Backspace" )
;;

(defun vsc-edit-mode-real-backspace ()
  "Just backspace a char."
  (interactive)
  (call-interactively (if electric-pair-mode #'electric-pair-delete-pair
                        #'backward-delete-char-untabify)))

(defun vsc-edit-mode-smart-backspace ()
  "Smart backspace."
  (interactive)
  (or (and (vsc-edit-mode--before-first-char-at-line-p) (not (bolp))
           (not (use-region-p))
           (jcs-backward-delete-spaces-by-indent-level))
      (vsc-edit-mode-real-backspace)))

;;;###autoload
(defun vsc-edit-mode-backspace ()
  "Backspace."
  (interactive)
  (if (derived-mode-p 'prog-mode)
      (vsc-edit-mode-smart-backspace)
    (vsc-edit-mode-real-backspace)))

;;
;; (@* "Delete" )
;;

(defun vsc-edit-mode-real-delete ()
  "Just delete a char."
  (interactive)
  (jcs-electric-delete))

(defun vsc-edit-mode-smart-delete ()
  "Smart backspace."
  (interactive)
  (or (and (not (eobp))
           (vsc-edit-mode--before-first-char-at-line-p (1+ (point)))
           (jcs-forward-delete-spaces-by-indent-level))
      (vsc-edit-mode-real-delete)))

;;;###autoload
(defun vsc-edit-mode-delete ()
  "Delete."
  (interactive)
  (if (derived-mode-p 'prog-mode)
      (vsc-edit-mode-smart-delete)
    (vsc-edit-mode-real-delete)))

;;
;; (@* "Space" )
;;

(defun jcs-insert-spaces-by-indent-level ()
  "Insert spaces depends on indentation level configuration."
  (interactive)
  (let* ((tmp-count 0)
         (indent-lvl (indent-control-get-indent-level-by-mode))
         (remainder (% (current-column) indent-lvl))
         (target-width (if (= remainder 0) indent-lvl (- indent-lvl remainder))))
    (while (< tmp-count target-width)
      (insert " ")
      (setq tmp-count (1+ tmp-count)))))

(defun jcs-backward-delete-spaces-by-indent-level ()
  "Backward delete spaces using indentation level."
  (interactive)
  (let* ((tmp-count 0)
         (indent-lvl (indent-control-get-indent-level-by-mode))
         (remainder (% (current-column) indent-lvl))
         (target-width (if (= remainder 0) indent-lvl remainder))
         success)
    (while (and (< tmp-count target-width)
                (not (bolp))
                (jcs-current-whitespace-p))
      (backward-delete-char 1)
      (setq success t
            tmp-count (1+ tmp-count)))
    success))

(defun jcs-forward-delete-spaces-by-indent-level ()
  "Forward delete spaces using indentation level."
  (interactive)
  (let* ((tmp-count 0)
         (indent-lvl (indent-control-get-indent-level-by-mode))
         (remainder (% (jcs-first-char-in-line-column) indent-lvl))
         (target-width (if (= remainder 0) indent-lvl remainder))
         success)
    (while (and (< tmp-count target-width) (not (eolp)))
      (let ((is-valid nil))
        (save-excursion
          (forward-char 1)
          (when (jcs-current-whitespace-p) (setq is-valid t)))
        (when is-valid (backward-delete-char -1) (setq success t)))
      (setq tmp-count (1+ tmp-count)))
    success))

(provide 'vsc-edit-mode)
;;; vsc-edit-mode.el ends here
