;;; thattem-tab-bar-actions-tests.el --- Mouse regressions -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Callback tests, not graphical delivery.  Character-first replay and the
;; unavailable workspace indicator absorbing wheels are intentional behavior.

;;; Code:

(require 'thattem-tab-bar-test-helper)

(ert-deftest thattem-tab-bar-test--nil-string-mouse-event-delegates ()
  "A console-style event without text reaches the original handler unchanged."
  (let ((event '(mouse-1 (nil tab-bar (0 . 0) 0 nil))) calls)
    (thattem-tab-bar--advice-around--tab-bar-mouse-1
     (lambda (received) (push received calls)) event)
    (should (equal calls (list event)))))

(ert-deftest thattem-tab-bar-test--ordinary-caption-delegates ()
  "Captions without workspace metadata use the original mouse behavior."
  (dolist (text (list "Tab" (propertize "Other" 'type 'other)))
    (let ((event (thattem-tab-bar-test--event 'mouse-1 text)) called)
      (thattem-tab-bar--advice-around--tab-bar-mouse-1
       (lambda (received) (setq called received)) event)
      (should (eq called event)))))

(ert-deftest thattem-tab-bar-test--workspace-click-including-zero ()
  "Workspace zero is a valid target, not a missing value."
  (dolist (id '(0 3))
    (let* ((text (propertize "WS" 'type 'workspace 'id id))
           (event (thattem-tab-bar-test--event 'mouse-1 text 1))
           switched)
      (cl-letf (((symbol-function 'thattem-workspace-switch)
                 (lambda (value) (setq switched value))))
        (thattem-tab-bar--advice-around--tab-bar-mouse-1
         (lambda (_) (ert-fail "Workspace click delegated")) event))
      (should (equal switched id)))))

(ert-deftest thattem-tab-bar-test--current-workspace-click-is-inert ()
  "The current workspace caption carries no target and triggers no switch."
  (cl-letf (((symbol-function 'thattem-workspace-switch)
             (lambda (_) (ert-fail "Current workspace switched"))))
    (thattem-tab-bar--advice-around--tab-bar-mouse-1
     (lambda (_) (ert-fail "Current workspace delegated"))
     (thattem-tab-bar-test--event 'mouse-1 (propertize "WS" 'type 'workspace)))))

(ert-deftest thattem-tab-bar-test--wheel-hitbox-boundaries ()
  "The workspace interval includes its left edge and excludes its right edge."
  (thattem-tab-bar-test--with-frame
    (set-frame-parameter nil 'workspace-x-bound '(10 . 20))
    (set-frame-parameter nil 'workspace-previous 0)
    (set-frame-parameter nil 'workspace-next 2)
    (dolist (x '(9 10 19 20))
      (dolist (direction '(up down))
        (let (workspace tab)
          (cl-letf (((symbol-function 'thattem-workspace-switch)
                     (lambda (id) (setq workspace id)))
                    ((symbol-function 'tab-previous) (lambda (&rest _) (setq tab 'previous)))
                    ((symbol-function 'tab-next) (lambda (&rest _) (setq tab 'next))))
            (funcall (if (eq direction 'up)
                         #'thattem-tab-bar-deal-mouse-wheel-up
                       #'thattem-tab-bar-deal-mouse-wheel-down)
                     (thattem-tab-bar-test--event 'wheel-down nil nil x)))
          (if (memq x '(10 19))
              (progn
                (should (equal workspace (if (eq direction 'up) 0 2)))
                (should-not tab))
            (should-not workspace)
            (should (eq tab (if (eq direction 'up) 'previous 'next)))))))))

(ert-deftest thattem-tab-bar-test--wheel-without-hitbox-switches-tabs ()
  "When workspace controls are absent, wheel events navigate tabs."
  (thattem-tab-bar-test--with-frame
    (let (calls)
      (cl-letf (((symbol-function 'tab-previous) (lambda (&rest _) (push 'previous calls)))
                ((symbol-function 'tab-next) (lambda (&rest _) (push 'next calls))))
        (thattem-tab-bar-deal-mouse-wheel-up (thattem-tab-bar-test--event 'wheel-up))
        (thattem-tab-bar-deal-mouse-wheel-down (thattem-tab-bar-test--event 'wheel-down)))
      (should (equal (nreverse calls) '(previous next))))))

(ert-deftest thattem-tab-bar-test--workspace-error-wheel-is-intentionally-absorbed ()
  "The visible unavailable-workspace indicator consumes both wheel directions."
  (thattem-tab-bar-test--with-frame
    (set-frame-parameter nil 'workspace-x-bound '(0 . 1))
    (cl-letf (((symbol-function 'tab-previous) (lambda (&rest _) (ert-fail "Previous tab")))
              ((symbol-function 'tab-next) (lambda (&rest _) (ert-fail "Next tab")))
              ((symbol-function 'thattem-workspace-switch) (lambda (_) (ert-fail "Workspace"))))
      (thattem-tab-bar-deal-mouse-wheel-up (thattem-tab-bar-test--event 'wheel-up))
      (thattem-tab-bar-deal-mouse-wheel-down (thattem-tab-bar-test--event 'wheel-down)))))

(ert-deftest thattem-tab-bar-test--release-without-wheel-is-replayed ()
  "A plain middle click returns its release, preserving duplicate events."
  (dolist (type '(mouse-2 double-mouse-2 triple-mouse-2 drag-mouse-2))
    (let* ((release (thattem-tab-bar-test--event type))
           (unread-command-events (list release)))
      (cl-letf (((symbol-function 'read-event) (lambda (&rest _) release)))
        (thattem-tab-bar-deal-down-mouse-2
         (thattem-tab-bar-test--event 'down-mouse-2)))
      (should (equal unread-command-events (list release release))))))

(ert-deftest thattem-tab-bar-test--wheel-gesture-consumes-release ()
  "Wheel movement switches tabs and suppresses the following middle release."
  (dolist (type '(wheel-up double-wheel-up triple-wheel-up
                  wheel-down double-wheel-down triple-wheel-down))
    (let* ((events (list (thattem-tab-bar-test--event type)
                         (thattem-tab-bar-test--event 'mouse-2)))
           (unread-command-events nil)
           calls)
      (cl-letf (((symbol-function 'read-event)
                 (lambda (&rest _) (or (pop events) (ert-fail "Read past release"))))
                ((symbol-function 'tab-previous) (lambda (&rest _) (push 'previous calls)))
                ((symbol-function 'tab-next) (lambda (&rest _) (push 'next calls))))
        (thattem-tab-bar-deal-down-mouse-2 (thattem-tab-bar-test--event 'down-mouse-2)))
      (should (equal calls (list (if (memq type '(wheel-up double-wheel-up triple-wheel-up))
                                     'previous 'next))))
      (should-not unread-command-events))))

(ert-deftest thattem-tab-bar-test--character-first-replay-preserves-duplicates ()
  "An unrelated character is dispatched before re-arming the mouse handler."
  (let* ((event (thattem-tab-bar-test--event 'down-mouse-2))
         (unread-command-events (list ?a event)))
    (cl-letf (((symbol-function 'read-event) (lambda (&rest _) ?a)))
      (thattem-tab-bar-deal-down-mouse-2 event))
    (should (equal unread-command-events (list ?a event ?a event)))))

(ert-deftest thattem-tab-bar-test--characters-can-rearm-until-release ()
  "Repeated callback replay delivers each typed character before eventual release."
  (let ((event (thattem-tab-bar-test--event 'down-mouse-2))
        (release (thattem-tab-bar-test--event 'mouse-2))
        (unread-command-events nil)
        delivered)
    ;; Model command-loop consumption explicitly, without claiming GUI dispatch.
    (dolist (character '(?a ?a ?中))
      (cl-letf (((symbol-function 'read-event) (lambda (&rest _) character)))
        (thattem-tab-bar-deal-down-mouse-2 event))
      (push (pop unread-command-events) delivered)
      (should (equal (pop unread-command-events) event)))
    (cl-letf (((symbol-function 'read-event) (lambda (&rest _) release)))
      (thattem-tab-bar-deal-down-mouse-2 event))
    (should (equal (nreverse delivered) '(?a ?a ?中)))
    (should (equal unread-command-events (list release)))))

;;; thattem-tab-bar-actions-tests.el ends here
