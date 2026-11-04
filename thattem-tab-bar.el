;;; Thattem-tab-bar --- a simple tab bar  -*- lexical-binding: t; -*-

;; Author: That Temperature <2719023332@qq.com>
;; Package-Requires: ((nerd-icons "0.1.0"))
;; URL: https://github.com/thattemperature/thattem-tab-bar

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

;; Thattem-tab-bar is a package that change the appearance of the
;; default tab bar.  It DO NOT change the items used in tab bar,
;; like "tab-bar-format-tabs".  Instead, it defines replacement
;; for the items, like "thattem-tab-bar-format-tabs".
;;
;; The package will set "tab-bar-format" to use those replacement
;; as default.  You can also customize this variable.

;;; Code:

(defgroup thattem-tab-bar nil
  "Modified tab bar."
  :group 'convenience
  :group 'thattem)

(require 'thattem-tab-bar-common-items)
(require 'thattem-tab-bar-advices)

;;; Define formats

(defcustom thattem-tab-bar-format-default
  '(thattem-tab-bar-format-position-helper
    thattem-tab-bar-format-history
    thattem-tab-bar-format-tabs
    thattem-tab-bar-format-add-tab
    thattem-tab-bar-format-align-right
    thattem-tab-bar-format-global)
  "New value for `tab-bar-format'."
  :type '(repeat symbol)
  :group 'thattem-tab-bar)

(defcustom thattem-tab-bar-format-modern
  '(thattem-tab-bar-format-position-helper
    thattem-tab-bar-format-workspaces
    thattem-tab-bar-format-align-middle
    thattem-tab-bar-format-add-tab
    thattem-tab-bar-format-system-monitor
    thattem-tab-bar-format-history
    thattem-tab-bar-format-tabs
    thattem-tab-bar-format-align-right
    thattem-tab-bar-format-global)
  "A modern `tab-bar-format' replacement."
  :type '(repeat symbol)
  :group 'thattem-tab-bar)

(defcustom thattem-tab-bar-style
  'thattem-tab-bar-format-default
  "Style of tab bar."
  :type '(choice (const thattem-tab-bar-format-default)
                 (const thattem-tab-bar-format-modern))
  :set (lambda (symbol value)
         (set-default-toplevel-value symbol value)
         (cond ((eq value 'thattem-tab-bar-format-default)
                (setopt tab-bar-new-tab-to 'rightmost)
                (setopt thattem-tab-bar-tab-name-style
                        'thattem-tab-bar-long-name))
               ((eq value 'thattem-tab-bar-format-modern)
                (setopt tab-bar-new-tab-to 'leftmost)
                (setopt thattem-tab-bar-tab-name-style
                        'thattem-tab-bar-short-name))))
  :group 'thattem-tab-bar)

;;; Define backup variable

(defvar thattem-tab-bar--backup-flag
  nil
  "Non-nil means the original tab bar settings are backed up.")

(defvar thattem-tab-bar--auto-width-backup
  nil
  "Backup the original tab bar auto width.")

(defvar thattem-tab-bar--tab-bar-format-backup
  nil
  "Backup the original tab bar format.")

;;; Define keymap

(defvar thattem-tab-bar-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map [tab-bar wheel-up]
                #'thattem-tab-bar-deal-mouse-wheel-up)
    (define-key map [tab-bar wheel-down]
                #'thattem-tab-bar-deal-mouse-wheel-down)
    (define-key map [down-mouse-2]
                #'thattem-tab-bar-deal-down-mouse-2)
    map)
  "Keymap used by `thattem-tab-bar-mode'.")

;;; Define minor mode

(define-minor-mode thattem-tab-bar-mode
  "Toggle thattem tab bar mode."
  :global t

  (when thattem-tab-bar-mode
    ;; Add advice
    (unless (advice-member-p
             #'thattem-tab-bar--advice-around--tab-bar-mouse-1
             'tab-bar-mouse-1)
      (advice-add 'tab-bar-mouse-1 :around
                  #'thattem-tab-bar--advice-around--tab-bar-mouse-1))
    ;; Start timer
    (thattem-tab-bar-start-timer
     thattem-tab-bar-workspace-timer)
    (thattem-tab-bar-start-timer
     thattem-tab-bar-system-monitor-timer)
    ;; Set variable
    (unless thattem-tab-bar--backup-flag
      (setq thattem-tab-bar--auto-width-backup
            tab-bar-auto-width)
      (setq thattem-tab-bar--tab-bar-format-backup
            tab-bar-format))
    (setopt tab-bar-auto-width nil)
    (setopt tab-bar-format (symbol-value thattem-tab-bar-style))
    ;; Set backup flag
    (setq thattem-tab-bar--backup-flag t))

  (unless thattem-tab-bar-mode
    ;; Remove advice
    (advice-remove 'tab-bar-mouse-1
                   #'thattem-tab-bar--advice-around--tab-bar-mouse-1)
    ;; Stop timer
    (thattem-tab-bar-stop-timer
     thattem-tab-bar-workspace-timer)
    (thattem-tab-bar-stop-timer
     thattem-tab-bar-system-monitor-timer)
    ;; Restore variable
    (when thattem-tab-bar--backup-flag
      (setopt tab-bar-auto-width thattem-tab-bar--auto-width-backup)
      (setopt tab-bar-format thattem-tab-bar--tab-bar-format-backup))
    ;; Set backup flag
    (setq thattem-tab-bar--backup-flag nil))

  (when thattem-tab-bar-mode
    (tab-bar-mode)))


(provide 'thattem-tab-bar)
;;; thattem-tab-bar.el ends here
