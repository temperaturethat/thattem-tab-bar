;;; Tab-bar-special-items --- define special items  -*- lexical-binding: t; -*-

;; Author: That Temperature <2719023332@qq.com>
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

;; Tab-bar-special-items defines some special tab bar items (depending
;; on thattem-emacs-library).

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'nerd-icons)
(require 'thattem-tab-bar-faces)

;;; Executable and library path configurations

(eval-and-compile
  (defcustom thattem-tab-bar-thattem-library-path
    (expand-file-name
     "libthattem_emacs_library.so"
     (file-name-directory (locate-library "thattem-tab-bar")))
    "The path of thattem-emacs-library."
    :type 'string
    :group 'thattem-tab-bar)

  (module-load thattem-tab-bar-thattem-library-path))

;;; Special configurations

(defcustom thattem-tab-bar-timer-frequency 10
  "Timer update frequency that used in special items in \
thattem-tab-bar."
  :type '(integer
          :validate
          (lambda (widget)
            (unless (> (widget-value widget) 0)
              (widget-put
               widget :error
               "The frequency must positive"))))
  :group 'thattem-tab-bar)

;;; Helper macros

(defmacro thattem-tab-bar-start-timer (timervar)
  "Run timer and save the handle as TIMERVAR."
  (let* ((symbol-name (symbol-name timervar))
         (key (string-remove-prefix
               "thattem-tab-bar-"
               (string-remove-suffix
                "-timer" symbol-name)))
         (func-name (concat
                     "thattem-tab-bar-update-" key))
         (func (intern func-name)))
    `(unless (timerp ,timervar)
       (setq ,timervar
             (run-with-timer
              0
              (/ 1.0 thattem-tab-bar-timer-frequency)
              (function ,func))))))

(defmacro thattem-tab-bar-stop-timer (timervar)
  "Stop the timer and clear the handle TIMERVAR."
  `(when (timerp ,timervar)
     (cancel-timer ,timervar)
     (setq ,timervar nil)))

;;; Workspace control

(defun thattem-tab-bar-update-workspace ()
  "Update workspace information and save as frame parameter."
  (let ((old-workspace-count (frame-parameter nil 'workspace-count))
        (workspace-count (thattem-workspace-count))
        (old-workspace-active (frame-parameter nil 'workspace-active))
        (workspace-active (thattem-workspace-active)))
    (unless (and (equal old-workspace-count workspace-count)
                 (equal old-workspace-active workspace-active))
      (let ((previous (when (and workspace-count workspace-active)
                        (% (1- (+ workspace-count workspace-active))
                           workspace-count)))
            (next (when (and workspace-count workspace-active)
                    (% (1+ (+ workspace-count workspace-active))
                       workspace-count))))
        (set-frame-parameter nil 'workspace-count workspace-count)
        (set-frame-parameter nil 'workspace-active workspace-active)
        (set-frame-parameter nil 'workspace-previous previous)
        (set-frame-parameter nil 'workspace-next next)
        (force-mode-line-update t)))))

(defvar thattem-tab-bar-workspace-timer nil
  "The timer object to update workspace.")

(defun thattem-tab-bar--format-workspace (workspace)
  "Format WORKSPACE and return the result as a keymap."
  (let ((current-p (car workspace))
        (id (cdr workspace))
        (space (propertize
                " " 'face
                `(thattem-tab-bar/bright-thin
                  (:height ,thattem-tab-bar-small-font-height)))))
    (cond
     (current-p
      `((current-workspace
         menu-item
         ,(propertize
           (concat
            space
            (propertize
             (nerd-icons-mdicon
              (format "nf-md-numeric_%d_circle"
                      (1+ (% id 10)))
              :face `(thattem-tab-bar/bright-thin
                      (:height ,thattem-tab-bar-big-font-height)))
             'mouse-face 'thattem-tab-bar/bright-hover)
            space)
           'type 'workspace)
         ignore
         :help "Current workspace")))
     (t
      `((,(intern (format "workspace-%d" id))
         menu-item
         ,(propertize
           (concat
            space
            (propertize
             (nerd-icons-mdicon
              (format "nf-md-numeric_%d_circle_outline"
                      (1+ (% id 10)))
              :face `(thattem-tab-bar/bright-thin
                      (:height ,thattem-tab-bar-big-font-height)))
             'mouse-face 'thattem-tab-bar/bright-hover)
            space)
           'type 'workspace
           'id id)
         ignore
         :help "Click to change workspace"))))))

(defun thattem-tab-bar-format-workspaces ()
  "Produce workspace control items for the tab bar."
  (let* ((workspace-count (frame-parameter nil 'workspace-count))
         (workspace-active (frame-parameter nil 'workspace-active))
         (workspace-list
          (when (and workspace-count workspace-active)
            (cl-loop for i from 0 below workspace-count
                     collect (cons (= i workspace-active) i)))))
    (if workspace-list
        (mapcan
         #'thattem-tab-bar--format-workspace
         workspace-list)
      `((workspace-error
         menu-item
         ,(propertize
           "!"
           'face `(thattem-tab-bar/bright-highlight
                   (:height ,thattem-tab-bar-big-font-height)))
         ignore)))))

;;; System monitor

(defcustom thattem-tab-bar-threshold-high 80
  "The threshold of system monitor item in percentage.
If the (cpu/memory/swap) usage is greater than this,
that item will be shown with different face."
  :type 'integer
  :group 'thattem-tab-bar)

(defvar thattem-tab-bar-cpu-percentage-buffer nil
  "Buffer of system CPU usage percentage.")

(defvar thattem-tab-bar-cpu-percentage 0
  "The system CPU usage percentage.")

(defvar thattem-tab-bar-mem-percentage 0
  "The system memory usage percentage.")

(defvar thattem-tab-bar-swap-percentage 0
  "The system swap usage percentage.")

(defvar thattem-tab-bar-upload-speed-buffer nil
  "Buffer of system network upload speed.")

(defvar thattem-tab-bar-upload-speed ""
  "The system network upload speed.")

(defvar thattem-tab-bar-download-speed-buffer nil
  "Buffer of system network download speed.")

(defvar thattem-tab-bar-download-speed ""
  "The system network download speed.")

(defun thattem-tab-bar-update-system-monitor ()
  "Update system monitor data."
  (setq thattem-tab-bar-cpu-percentage-buffer
        (take thattem-tab-bar-timer-frequency
              (cons (thattem-cpu-usage)
                    thattem-tab-bar-cpu-percentage-buffer)))
  (setq thattem-tab-bar-cpu-percentage
        (round (* (/ (apply #'+ thattem-tab-bar-cpu-percentage-buffer)
                     thattem-tab-bar-timer-frequency)
                  100)))
  (setq thattem-tab-bar-mem-percentage
        (round (* (thattem-mem-usage) 100)))
  (setq thattem-tab-bar-swap-percentage
        (round (* (thattem-swap-usage) 100)))
  (let ((net (thattem-net-speed)))
    (setq thattem-tab-bar-download-speed-buffer
          (take thattem-tab-bar-timer-frequency
                (cons (car net)
                      thattem-tab-bar-download-speed-buffer)))
    (setq thattem-tab-bar-download-speed
          (file-size-human-readable
           (/ (apply #'+ thattem-tab-bar-download-speed-buffer)
              thattem-tab-bar-timer-frequency)
           'si nil "B"))
    (setq thattem-tab-bar-upload-speed-buffer
          (take thattem-tab-bar-timer-frequency
                (cons (cadr net)
                      thattem-tab-bar-upload-speed-buffer)))
    (setq thattem-tab-bar-upload-speed
          (file-size-human-readable
           (/ (apply #'+ thattem-tab-bar-upload-speed-buffer)
              thattem-tab-bar-timer-frequency)
           'si nil "B"))))

(defvar thattem-tab-bar-system-monitor-timer nil
  "The timer object to update system monitor.")

(defun thattem-tab-bar-format-system-monitor ()
  "Produce system monitor items for the tab bar."
  (append
   `((system-monitor-left-sep
      menu-item
      ,(nerd-icons-powerline
        "nf-ple-pixelated_squares_small_mirrored"
        :face `(thattem-tab-bar/bright-thin
                :height ,thattem-tab-bar-big-font-height))
      ignore :help ""))
   `((system-monitor-cpu
      menu-item
      ,(concat
        (nerd-icons-octicon
         "nf-oct-cpu"
         :face `(,(if (< thattem-tab-bar-cpu-percentage
                         thattem-tab-bar-threshold-high)
                      'thattem-tab-bar/dark-highlight
                    'thattem-tab-bar/dark-warning)
                 (:height ,thattem-tab-bar-middle-font-height)))
        (propertize
         (format "%3d%% " thattem-tab-bar-cpu-percentage)
         'face `(,(if (< thattem-tab-bar-cpu-percentage
                         thattem-tab-bar-threshold-high)
                      'thattem-tab-bar/dark-highlight
                    'thattem-tab-bar/dark-warning)
                 (:height ,thattem-tab-bar-middle-font-height))))
      ignore
      :help "CPU usage"))
   `((system-monitor-mem
      menu-item
      ,(concat
        (nerd-icons-faicon
         "nf-fa-memory"
         :face `(,(if (< thattem-tab-bar-mem-percentage
                         thattem-tab-bar-threshold-high)
                      'thattem-tab-bar/dark-highlight
                    'thattem-tab-bar/dark-warning)
                 (:height ,thattem-tab-bar-middle-font-height)))
        (propertize
         (format "%3d%% " thattem-tab-bar-mem-percentage)
         'face `(,(if (< thattem-tab-bar-mem-percentage
                         thattem-tab-bar-threshold-high)
                      'thattem-tab-bar/dark-highlight
                    'thattem-tab-bar/dark-warning)
                 (:height ,thattem-tab-bar-middle-font-height))))
      ignore
      :help "Memory usage"))
   `((system-monitor-swap
      menu-item
      ,(concat
        (nerd-icons-mdicon
         "nf-md-swap_horizontal_bold"
         :face `(,(if (< thattem-tab-bar-swap-percentage
                         thattem-tab-bar-threshold-high)
                      'thattem-tab-bar/dark-highlight
                    'thattem-tab-bar/dark-warning)
                 (:height ,thattem-tab-bar-middle-font-height)))
        (propertize
         (format "%3d%% " thattem-tab-bar-swap-percentage)
         'face `(,(if (< thattem-tab-bar-swap-percentage
                         thattem-tab-bar-threshold-high)
                      'thattem-tab-bar/dark-highlight
                    'thattem-tab-bar/dark-warning)
                 (:height ,thattem-tab-bar-middle-font-height))))
      ignore
      :help "Swap usage"))
   `((system-monitor-upload
      menu-item
      ,(concat
        (nerd-icons-mdicon
         "nf-md-upload"
         :face `(thattem-tab-bar/dark-highlight
                 (:height ,thattem-tab-bar-middle-font-height)))
        (propertize
         (format "%5s " thattem-tab-bar-upload-speed)
         'face `(thattem-tab-bar/dark-highlight
                 (:height ,thattem-tab-bar-middle-font-height))))
      ignore
      :help "Upload speed"))
   `((system-monitor-download
      menu-item
      ,(concat
        (nerd-icons-mdicon
         "nf-md-download"
         :face `(thattem-tab-bar/dark-highlight
                 (:height ,thattem-tab-bar-middle-font-height)))
        (propertize
         (format "%5s " thattem-tab-bar-download-speed)
         'face `(thattem-tab-bar/dark-highlight
                 (:height ,thattem-tab-bar-middle-font-height))))
      ignore
      :help "Download speed"))
   `((system-monitor-right-sep
      menu-item
      ,(nerd-icons-powerline
        "nf-ple-pixelated_squares_big"
        :face `(thattem-tab-bar/bright-thin
                :height ,thattem-tab-bar-big-font-height))
      ignore :help ""))))


(provide 'thattem-tab-bar-special-items)
;;; thattem-tab-bar-special-items.el ends here
