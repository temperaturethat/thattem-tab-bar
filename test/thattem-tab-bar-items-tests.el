;;; thattem-tab-bar-items-tests.el --- Common item regressions -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Assert labels, commands and text properties, not exact font glyphs or pixels.

;;; Code:

(require 'thattem-tab-bar-test-helper)

(ert-deftest thattem-tab-bar-test--history-disabled-produces-no-buttons ()
  "History controls are hidden when core history mode is disabled."
  (let ((tab-bar-history-mode nil))
    (should-not (thattem-tab-bar-format-history))))

(ert-deftest thattem-tab-bar-test--history-enabled-preserves-commands ()
  "History controls retain both core navigation commands."
  (let* ((tab-bar-history-mode t)
         (items (thattem-tab-bar-format-history)))
    (should (eq (nth 3 (assq 'history-back items)) 'tab-bar-history-back))
    (should (eq (nth 3 (assq 'history-forward items)) 'tab-bar-history-forward))
    (should (stringp (thattem-tab-bar-test--caption items 'history-back)))))

(ert-deftest thattem-tab-bar-test--add-tab-retains-core-command ()
  "The add-tab item uses the core new-tab command and a hover face."
  (let* ((item (car (thattem-tab-bar-format-add-tab)))
         (caption (nth 2 item)))
    (should (eq (car item) 'add-tab))
    (should (eq (nth 3 item) 'tab-bar-new-tab))
    (should (get-text-property 0 'mouse-face caption))))

(ert-deftest thattem-tab-bar-test--name-boundary-and-unicode ()
  "Long-name style keeps six characters and truncates longer names safely."
  (let ((thattem-tab-bar-tab-name-style 'thattem-tab-bar-long-name)
        (tab-bar-close-button-show nil)
        (tab-bar-tab-hints nil))
    (dolist (name '("" "abcdef" "abcdefg" "甲乙丙丁戊己庚" "100%"))
      (let* ((tab (list 'tab (cons 'name name) (cons 'ws nil)))
             (caption (thattem-tab-bar-name-format tab 1)))
        (should (stringp caption))
        (if (> (length name) 6)
            (progn
              (should (string-match-p (regexp-quote (substring name 0 5)) caption))
              (should-not (string-match-p (regexp-quote name) caption)))
          (should (string-match-p (regexp-quote name) caption)))))))

(ert-deftest thattem-tab-bar-test--short-name-style-omits-name-text ()
  "Short style retains the icon but omits the buffer/tab label."
  (let ((thattem-tab-bar-tab-name-style 'thattem-tab-bar-short-name)
        (tab-bar-close-button-show nil)
        (tab-bar-tab-hints nil))
    (let ((caption (thattem-tab-bar-name-format '(tab (name . "UniqueLabel") (ws)) 1)))
      (should (stringp caption))
      (should-not (string-match-p "Unique" caption)))))

(ert-deftest thattem-tab-bar-test--tab-hints-are-optional ()
  "The index hint is present only when requested."
  (dolist (enabled '(nil t))
    (let* ((tab-bar-tab-hints enabled)
           (thattem-tab-bar-tab-name-style 'thattem-tab-bar-short-name)
           (caption (thattem-tab-bar-name-format '(tab (name . "Unknown") (ws)) 42)))
      (should (eq (not (null (string-prefix-p "42 " caption))) enabled)))))

(ert-deftest thattem-tab-bar-test--close-button-selection-policy ()
  "Selected/nonselected policies control the close-tab text property."
  (dolist (policy '(nil t selected non-selected))
    (dolist (current '(nil t))
      (let* ((tab-bar-close-button-show policy)
             (tab (list (if current 'current-tab 'tab)
                        '(name . "Unknown") '(ws)))
             (caption (thattem-tab-bar-name-format tab 1))
             (visible (text-property-any 0 (length caption) 'close-tab t caption)))
        (should (eq (not (null visible))
                    (and policy (not (eq policy (if current 'non-selected 'selected))))))))))

(ert-deftest thattem-tab-bar-test--inactive-tab-keeps-binding-and-close-binding ()
  "An inactive tab preserves the commands attached by core tab-bar."
  (let* ((items (thattem-tab-bar--format-tab
                 '(tab (name . "Unknown") (ws)
                       (binding . next-buffer) (close-binding . kill-buffer)) 2)))
    (should (eq (nth 3 (assq 'tab-2 items)) 'next-buffer))
    (should (eq (nth 3 (assq 'C-tab-2 items)) 'kill-buffer))
    (should (assq 'left-sep-2 items))
    (should (assq 'right-sep-2 items))))

(ert-deftest thattem-tab-bar-test--tab-items-preserve-order ()
  "The configured tab provider determines tab order and current-tab identity."
  (let ((tab-bar-tabs-function
         (lambda () '((tab (name . "One") (ws) (binding . previous-buffer))
                      (current-tab (name . "Two"))
                      (tab (name . "Three") (ws) (binding . next-buffer))))))
    (let ((items (thattem-tab-bar-format-tabs)))
      (should (equal (mapcar #'car items)
                     '(left-sep-1 tab-1 right-sep-1
                       left-sep-2 current-tab right-sep-2
                       left-sep-3 tab-3 right-sep-3))))))

(ert-deftest thattem-tab-bar-test--empty-tab-provider-is-empty ()
  "An empty custom tab provider does not invent a placeholder tab."
  (let ((tab-bar-tabs-function (lambda () nil)))
    (should-not (thattem-tab-bar-format-tabs))))

(ert-deftest thattem-tab-bar-test--killed-buffer-name-uses-fallback-icon ()
  "A tab whose buffer was killed remains renderable."
  (let ((buffer (generate-new-buffer " *thattem-killed*")))
    (let ((name (buffer-name buffer)))
      (kill-buffer buffer)
      (should (stringp (thattem-tab-bar-name-format
                        (list 'tab (cons 'name name) '(ws)) 1))))))

(ert-deftest thattem-tab-bar-test--inactive-tab-uses-saved-window-state ()
  "Rendering an inactive tab reads its saved buffers, not the current windows."
  (save-window-excursion
    (let ((primary (generate-new-buffer " *thattem-primary*"))
          (secondary (generate-new-buffer " *thattem-secondary*"))
          (current (generate-new-buffer " *thattem-current*")))
      (unwind-protect
          (progn
            (delete-other-windows)
            (set-window-buffer (selected-window) primary)
            (set-window-buffer (split-window-right) secondary)
            (with-current-buffer primary (setq-local major-mode 'emacs-lisp-mode))
            (with-current-buffer secondary (setq-local major-mode 'lisp-interaction-mode))
            (with-current-buffer current (setq-local major-mode 'text-mode))
            (let* ((state (window-state-get (frame-root-window) 'writable))
                   (tab (list 'tab (cons 'name (buffer-name primary)) (cons 'ws state)))
                   seen)
              (delete-other-windows)
              (set-window-buffer (selected-window) current)
              (cl-letf (((symbol-function 'nerd-icons-icon-for-mode)
                         (lambda (mode &rest _) (push mode seen) "Icon")))
                (should (stringp (thattem-tab-bar-name-format tab 1))))
              (should (memq 'emacs-lisp-mode seen))
              ;; Only saved-state traversal can discover this secondary buffer.
              (should (memq 'lisp-interaction-mode seen))
              (should-not (memq 'text-mode seen))))
        (kill-buffer primary)
        (kill-buffer secondary)
        (kill-buffer current)))))

(ert-deftest thattem-tab-bar-test--alignment-excludes-position-helper ()
  "Measuring right-aligned content does not recursively invoke the hitbox helper."
  (let ((tab-bar-format '(thattem-tab-bar-format-align-right
                          thattem-tab-bar-format-position-helper
                          thattem-tab-bar-format-global)))
    (cl-letf (((symbol-function 'thattem-tab-bar-format-position-helper)
               (lambda () (ert-fail "Recursive position helper")))
              ((symbol-function 'thattem-tab-bar-format-global)
               (lambda () '((global menu-item "" ignore)))))
      (should (stringp (thattem-tab-bar-test--caption
                        (thattem-tab-bar-format-align-right) 'align-right))))))

(ert-deftest thattem-tab-bar-test--alignment-empty-tail-is-renderable ()
  "Right and middle alignment accept an empty following format."
  (let ((tab-bar-format '(thattem-tab-bar-format-align-right)))
    (should (stringp (thattem-tab-bar-test--caption
                      (thattem-tab-bar-format-align-right) 'align-right))))
  (let ((tab-bar-format '(thattem-tab-bar-format-align-middle)))
    (should (stringp (thattem-tab-bar-test--caption
                      (thattem-tab-bar-format-align-middle) 'align-right)))))

(ert-deftest thattem-tab-bar-test--semantic-faces-exist ()
  "All semantic faces referenced by built-in items are defined."
  (dolist (role '(bright dark bright-thin dark-thin bright-highlight
                  dark-highlight bright-hover dark-hover bright-warning dark-warning))
    (should (facep (intern (format "thattem-tab-bar/%s" role))))))

;;; thattem-tab-bar-items-tests.el ends here
