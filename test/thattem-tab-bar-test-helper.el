;;; thattem-tab-bar-test-helper.el --- Shared ERT fixtures -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Load the real package and native module.  Tests replace native sampling and
;; desktop actions only at explicit boundaries; no fallback module is supplied.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'thattem-tab-bar)

(defvar thattem-tab-bar-mode-on-hook nil
  "Hook isolated by lifecycle tests.")
(defvar thattem-tab-bar-mode-off-hook nil
  "Hook isolated by lifecycle tests.")

(defmacro thattem-tab-bar-test--with-frame (&rest body)
  "Run BODY with isolated workspace and tab parameters on the selected frame."
  (declare (indent 0) (debug t))
  `(let* ((frame (selected-frame))
          (parameters '(workspace-count workspace-active workspace-previous
                        workspace-next workspace-x-bound tabs))
          (saved (mapcar (lambda (key) (cons key (frame-parameter frame key)))
                         parameters)))
     (unwind-protect
         (progn
           (dolist (key parameters) (set-frame-parameter frame key nil))
           ,@body)
       (dolist (entry saved)
         (set-frame-parameter frame (car entry) (cdr entry))))))

(defmacro thattem-tab-bar-test--with-mode (&rest body)
  "Run BODY with isolated lifecycle state, real timers and real advice.
Core tab-bar activation is intercepted to avoid reconfiguring the user's frames."
  (declare (indent 0) (debug t))
  `(let ((thattem-tab-bar-mode nil)
         (global-minor-modes (copy-sequence global-minor-modes))
         (thattem-tab-bar--backup-flag nil)
         (thattem-tab-bar--new-tab-to-backup nil)
         (thattem-tab-bar--auto-width-backup nil)
         (thattem-tab-bar--tab-bar-format-backup nil)
         (thattem-tab-bar-workspace-timer nil)
         (thattem-tab-bar-system-monitor-timer nil)
         (thattem-tab-bar-timer-frequency 10)
         (thattem-tab-bar-mode-hook nil)
         (thattem-tab-bar-mode-on-hook nil)
         (thattem-tab-bar-mode-off-hook nil)
         (thattem-tab-bar-style 'thattem-tab-bar-format-default)
         (thattem-tab-bar-tab-name-style 'thattem-tab-bar-long-name)
         (tab-bar-new-tab-to 'leftmost)
         (tab-bar-auto-width t)
         (tab-bar-format '(tab-bar-format-tabs))
         (saved-mouse-handler (symbol-function 'tab-bar-mouse-1)))
     ;; Restore even pre-existing advice exactly, rather than removing advice
     ;; owned by an interactive session which may already have the mode enabled.
     (unwind-protect
         (cl-letf (((symbol-function 'tab-bar-mode) (lambda (&optional _arg) nil)))
           ,@body)
       (when (timerp thattem-tab-bar-workspace-timer)
         (cancel-timer thattem-tab-bar-workspace-timer))
       (when (timerp thattem-tab-bar-system-monitor-timer)
         (cancel-timer thattem-tab-bar-system-monitor-timer))
       (fset 'tab-bar-mouse-1 saved-mouse-handler))))

(defun thattem-tab-bar-test--event (type &optional text index x)
  "Construct a tab-bar callback event of TYPE at TEXT/INDEX and coordinate X."
  (list type (list (selected-frame) 'tab-bar (cons (or x 0) 0) 0
                   (and text (cons text (or index 0))))))

(defun thattem-tab-bar-test--caption (items key)
  "Return the rendered caption for KEY in menu ITEMS."
  (nth 2 (assq key items)))

(defun thattem-tab-bar-test--fresh-emacs (body)
  "Evaluate BODY in a fresh Emacs with this process's dependency paths.
Return (EXIT-STATUS . OUTPUT).  BODY is a test-authored Lisp form."
  (with-temp-buffer
    (let* ((program (expand-file-name invocation-name invocation-directory))
           (form `(progn
                    (setq load-path ',load-path)
                    (setq thattem-tab-bar-thattem-library-path
                          ,thattem-tab-bar-thattem-library-path)
                    ,body))
           (status (call-process program nil t nil "-Q" "--batch"
                                 "--eval" (prin1-to-string form))))
      (cons status (buffer-string)))))

(provide 'thattem-tab-bar-test-helper)
;;; thattem-tab-bar-test-helper.el ends here
