;;; thattem-tab-bar-mode-tests.el --- Lifecycle regressions -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Exercise package activation without changing the user's core tab-bar frames.

;;; Code:

(require 'thattem-tab-bar-test-helper)

(ert-deftest thattem-tab-bar-test--load-preserves-external-settings ()
  "Requiring the package must not apply a style or start its timers."
  (let ((result
         (thattem-tab-bar-test--fresh-emacs
          '(progn
             (require 'nerd-icons)
             (setq tab-bar-new-tab-to 'leftmost tab-bar-auto-width t
                   tab-bar-format '(tab-bar-format-tabs))
             (let ((before (copy-tree (current-global-map))))
               (require 'thattem-tab-bar)
               (unless (and (eq tab-bar-new-tab-to 'leftmost)
                            tab-bar-auto-width
                            (equal tab-bar-format '(tab-bar-format-tabs))
                            (equal before (current-global-map))
                            (not thattem-tab-bar-mode)
                            (not thattem-tab-bar-workspace-timer)
                            (not thattem-tab-bar-system-monitor-timer)
                            (not (advice-member-p
                                  #'thattem-tab-bar--advice-around--tab-bar-mouse-1
                                  'tab-bar-mouse-1)))
                 (error "Load-time side effect")))))))
    (ert-info ((cdr result)) (should (equal (car result) 0)))))

(ert-deftest thattem-tab-bar-test--default-style-applies-on-enable ()
  "Enabling the default style installs its format and long names."
  (thattem-tab-bar-test--with-mode
    (thattem-tab-bar-mode 1)
    (should (equal tab-bar-format thattem-tab-bar-format-default))
    (should-not tab-bar-auto-width)
    (should (eq tab-bar-new-tab-to 'rightmost))
    (should (eq thattem-tab-bar-tab-name-style 'thattem-tab-bar-long-name))))

(ert-deftest thattem-tab-bar-test--modern-style-applies-on-enable ()
  "Enabling the modern style installs its format and short names."
  (thattem-tab-bar-test--with-mode
    (setq thattem-tab-bar-style 'thattem-tab-bar-format-modern)
    (thattem-tab-bar-mode 1)
    (should (equal tab-bar-format thattem-tab-bar-format-modern))
    (should (eq tab-bar-new-tab-to 'leftmost))
    (should (eq thattem-tab-bar-tab-name-style 'thattem-tab-bar-short-name))))

(ert-deftest thattem-tab-bar-test--disable-restores-nonnil-settings ()
  "Disabling restores all three external settings saved before activation."
  (thattem-tab-bar-test--with-mode
    (thattem-tab-bar-mode 1)
    (thattem-tab-bar-mode -1)
    (should (eq tab-bar-new-tab-to 'leftmost))
    (should tab-bar-auto-width)
    (should (equal tab-bar-format '(tab-bar-format-tabs)))))

(ert-deftest thattem-tab-bar-test--disable-restores-nil-settings ()
  "Nil original values remain distinguishable from an uncaptured backup."
  (thattem-tab-bar-test--with-mode
    (setq tab-bar-auto-width nil tab-bar-format nil)
    (thattem-tab-bar-mode 1)
    (thattem-tab-bar-mode 1)
    (thattem-tab-bar-mode -1)
    (should (eq tab-bar-new-tab-to 'leftmost))
    (should-not tab-bar-auto-width)
    (should-not tab-bar-format)))

(ert-deftest thattem-tab-bar-test--disable-before-enable-and-repeated-disable ()
  "Disabling without an owned backup leaves the current settings alone."
  (thattem-tab-bar-test--with-mode
    (thattem-tab-bar-mode -1)
    (should tab-bar-auto-width)
    (thattem-tab-bar-mode 1)
    (thattem-tab-bar-mode -1)
    (setq tab-bar-format '(tab-bar-format-history))
    (thattem-tab-bar-mode -1)
    (should (equal tab-bar-format '(tab-bar-format-history)))))

(ert-deftest thattem-tab-bar-test--reenable-captures-new-baseline ()
  "A new cycle saves external values changed while the mode was disabled."
  (thattem-tab-bar-test--with-mode
    (dolist (baseline '((tab-bar-format-history) (tab-bar-format-tabs)
                        (tab-bar-format-history tab-bar-format-tabs)))
      (setq tab-bar-format baseline tab-bar-new-tab-to 'right)
      (thattem-tab-bar-mode 1)
      (thattem-tab-bar-mode 1)
      (thattem-tab-bar-mode -1)
      (should (equal tab-bar-format baseline))
      (should (eq tab-bar-new-tab-to 'right)))))

(ert-deftest thattem-tab-bar-test--repeated-enable-keeps-timer-identity ()
  "Enabling twice does not replace the handles of still-running timers."
  (thattem-tab-bar-test--with-mode
    (thattem-tab-bar-mode 1)
    (let ((workspace thattem-tab-bar-workspace-timer)
          (monitor thattem-tab-bar-system-monitor-timer))
      (should (memq workspace timer-list))
      (should (memq monitor timer-list))
      (thattem-tab-bar-mode 1)
      (should (eq workspace thattem-tab-bar-workspace-timer))
      (should (eq monitor thattem-tab-bar-system-monitor-timer))
      (thattem-tab-bar-mode -1)
      (should-not (memq workspace timer-list))
      (should-not (memq monitor timer-list))
      (should-not thattem-tab-bar-workspace-timer)
      (should-not thattem-tab-bar-system-monitor-timer))))

(ert-deftest thattem-tab-bar-test--advice-added-once-and-removed ()
  "Repeated activation registers one workspace mouse advice and removes it."
  (thattem-tab-bar-test--with-mode
    (thattem-tab-bar-mode 1)
    (thattem-tab-bar-mode 1)
    (let ((count 0))
      (advice-mapc
       (lambda (function _properties)
         (when (eq function #'thattem-tab-bar--advice-around--tab-bar-mouse-1)
           (cl-incf count)))
       'tab-bar-mouse-1)
      (should (= count 1)))
    (thattem-tab-bar-mode -1)
    (should-not (advice-member-p
                 #'thattem-tab-bar--advice-around--tab-bar-mouse-1 'tab-bar-mouse-1))))

(ert-deftest thattem-tab-bar-test--keymap-lifecycle-preserves-global-map ()
  "The conventional minor-mode map is active without rewriting global keys."
  (thattem-tab-bar-test--with-mode
    (let ((before (copy-tree (current-global-map))))
      (should-not (memq thattem-tab-bar-mode-map (current-active-maps)))
      (thattem-tab-bar-mode 1)
      (should (memq thattem-tab-bar-mode-map (current-active-maps)))
      (should (eq (lookup-key thattem-tab-bar-mode-map [tab-bar wheel-up])
                  #'thattem-tab-bar-deal-mouse-wheel-up))
      (should (eq (lookup-key thattem-tab-bar-mode-map [tab-bar wheel-down])
                  #'thattem-tab-bar-deal-mouse-wheel-down))
      (should (eq (lookup-key thattem-tab-bar-mode-map [down-mouse-2])
                  #'thattem-tab-bar-deal-down-mouse-2))
      (thattem-tab-bar-mode -1)
      (should-not (memq thattem-tab-bar-mode-map (current-active-maps)))
      (should (equal before (current-global-map))))))

(ert-deftest thattem-tab-bar-test--fixture-cleans-up-on-error ()
  "A failed lifecycle body restores advice, registry and timers."
  (let ((registry global-minor-modes)
        (handler (symbol-function 'tab-bar-mouse-1))
        (timers (copy-sequence timer-list)))
    (should-error
     (thattem-tab-bar-test--with-mode
       (thattem-tab-bar-mode 1)
       (error "Injected failure")))
    (should (eq registry global-minor-modes))
    (should (eq handler (symbol-function 'tab-bar-mouse-1)))
    (should (equal timers timer-list))))

(ert-deftest thattem-tab-bar-test--fixture-preserves-initially-enabled-session ()
  "Nested lifecycle fixtures preserve an enabled session on normal/error exits."
  (thattem-tab-bar-test--with-mode
    (thattem-tab-bar-mode 1)
    (let ((workspace thattem-tab-bar-workspace-timer)
          (monitor thattem-tab-bar-system-monitor-timer)
          (handler (symbol-function 'tab-bar-mouse-1))
          (registry global-minor-modes)
          (timers (copy-sequence timer-list))
          (format tab-bar-format)
          (placement tab-bar-new-tab-to))
      (dolist (fail '(nil t))
        (if fail
            (should-error
             (thattem-tab-bar-test--with-mode
               (thattem-tab-bar-mode 1)
               (thattem-tab-bar-mode -1)
               (error "Injected nested failure")))
          (thattem-tab-bar-test--with-mode
            (thattem-tab-bar-mode 1)
            (thattem-tab-bar-mode -1)))
        (should thattem-tab-bar-mode)
        (should (eq workspace thattem-tab-bar-workspace-timer))
        (should (eq monitor thattem-tab-bar-system-monitor-timer))
        (should (eq handler (symbol-function 'tab-bar-mouse-1)))
        (should (eq registry global-minor-modes))
        (should (equal timers timer-list))
        (should (equal format tab-bar-format))
        (should (eq placement tab-bar-new-tab-to))
        (should thattem-tab-bar--backup-flag)))))

;;; thattem-tab-bar-mode-tests.el ends here
