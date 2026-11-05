;;; thattem-tab-bar-workspace-tests.el --- Workspace regressions -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Desktop queries are controlled; formatting uses real nerd-icons.

;;; Code:

(require 'thattem-tab-bar-test-helper)

(ert-deftest thattem-tab-bar-test--workspace-neighbors-wrap ()
  "Workspace neighbors wrap at both ends, including a single workspace."
  (thattem-tab-bar-test--with-frame
    (dolist (case '((4 0 3 1) (4 3 2 0) (1 0 0 0)))
      (cl-letf (((symbol-function 'thattem-workspace-count) (lambda () (nth 0 case)))
                ((symbol-function 'thattem-workspace-active) (lambda () (nth 1 case))))
        (thattem-tab-bar-update-workspace))
      (should (= (frame-parameter nil 'workspace-count) (nth 0 case)))
      (should (= (frame-parameter nil 'workspace-active) (nth 1 case)))
      (should (= (frame-parameter nil 'workspace-previous) (nth 2 case)))
      (should (= (frame-parameter nil 'workspace-next) (nth 3 case))))))

(ert-deftest thattem-tab-bar-test--workspace-query-failure-clears-neighbors ()
  "A failed desktop query does not retain a previously valid navigation target."
  (thattem-tab-bar-test--with-frame
    (set-frame-parameter nil 'workspace-count 4)
    (set-frame-parameter nil 'workspace-active 1)
    (set-frame-parameter nil 'workspace-previous 0)
    (set-frame-parameter nil 'workspace-next 2)
    (cl-letf (((symbol-function 'thattem-workspace-count) (lambda () nil))
              ((symbol-function 'thattem-workspace-active) (lambda () nil)))
      (thattem-tab-bar-update-workspace))
    (should-not (frame-parameter nil 'workspace-count))
    (should-not (frame-parameter nil 'workspace-active))
    (should-not (frame-parameter nil 'workspace-previous))
    (should-not (frame-parameter nil 'workspace-next))))

(ert-deftest thattem-tab-bar-test--workspace-items-targets-and-current-state ()
  "Each noncurrent caption targets its zero-based workspace; current is inert."
  (thattem-tab-bar-test--with-frame
    (set-frame-parameter nil 'workspace-count 3)
    (set-frame-parameter nil 'workspace-active 1)
    (let ((items (thattem-tab-bar-format-workspaces)))
      (should (= (length items) 3))
      (should (equal (mapcar #'car items) '(workspace-0 current-workspace workspace-2)))
      (dolist (item items)
        (let ((caption (nth 2 item)))
          (should (eq (get-text-property 0 'type caption) 'workspace))
          (should (eq (nth 3 item) 'ignore))))
      (should (= (get-text-property 0 'id (nth 2 (nth 0 items))) 0))
      (should-not (get-text-property 0 'id (nth 2 (nth 1 items))))
      (should (= (get-text-property 0 'id (nth 2 (nth 2 items))) 2)))))

(ert-deftest thattem-tab-bar-test--workspace-ids-beyond-single-digit-remain-distinct ()
  "Repeated icon digits do not truncate the actual workspace target."
  (dolist (id '(0 9 10 21))
    (let ((caption (nth 2 (car (thattem-tab-bar--format-workspace (cons nil id))))))
      (should (= (get-text-property 0 'id caption) id)))))

(ert-deftest thattem-tab-bar-test--unavailable-workspace-renders-indicator ()
  "Missing workspace information produces the intentional exclamation indicator."
  (thattem-tab-bar-test--with-frame
    (let* ((items (thattem-tab-bar-format-workspaces))
           (caption (thattem-tab-bar-test--caption items 'workspace-error)))
      (should (equal (substring-no-properties caption) "!"))
      (should-not (get-text-property 0 'id caption))
      (should (eq (nth 3 (car items)) 'ignore)))))

(ert-deftest thattem-tab-bar-test--position-helper-absent-widget-clears-hitbox ()
  "Removing workspace controls clears the old range without rendering them."
  (thattem-tab-bar-test--with-frame
    (let ((tab-bar-format thattem-tab-bar-format-default)
          (calls 0))
      (set-frame-parameter nil 'workspace-x-bound '(1 . 99))
      (cl-letf (((symbol-function 'thattem-tab-bar-format-workspaces)
                 (lambda () (cl-incf calls) nil)))
        (thattem-tab-bar-format-position-helper))
      (should (= calls 0))
      (should-not (frame-parameter nil 'workspace-x-bound)))))

(ert-deftest thattem-tab-bar-test--position-helper-measures-preceding-items ()
  "The workspace range starts after preceding captions, not at the frame origin."
  (thattem-tab-bar-test--with-frame
    (let ((tab-bar-format '(thattem-tab-bar-format-position-helper
                            thattem-tab-bar-format-history
                            thattem-tab-bar-format-workspaces)))
      ;; Geometry inputs are controlled; the position-helper algorithm is real.
      (cl-letf (((symbol-function 'thattem-tab-bar-format-history)
                 (lambda () '((history menu-item "123" ignore))))
                ((symbol-function 'thattem-tab-bar-format-workspaces)
                 (lambda () '((workspace menu-item "4567" ignore))))
                ((symbol-function 'string-pixel-width) #'length))
        (thattem-tab-bar-format-position-helper))
      (should (equal (frame-parameter nil 'workspace-x-bound) '(3 . 7))))))

(ert-deftest thattem-tab-bar-test--position-helper-keeps-visible-error-region ()
  "An unavailable indicator still has a range for intentionally absorbing wheels."
  (thattem-tab-bar-test--with-frame
    (let ((tab-bar-format '(thattem-tab-bar-format-position-helper
                            thattem-tab-bar-format-workspaces)))
      (cl-letf (((symbol-function 'string-pixel-width) #'length))
        (thattem-tab-bar-format-position-helper))
      (should (equal (frame-parameter nil 'workspace-x-bound) '(0 . 1))))))

;;; thattem-tab-bar-workspace-tests.el ends here
