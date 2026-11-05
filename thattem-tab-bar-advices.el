;;; Tab-bar-advices --- define some advice functions to existing functions  -*- lexical-binding: t; -*-

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

;; Tab-bar-advices defines every advice to existing functions.
;; Also defines functions used for keybinding.

;;; Code:

(require 'thattem-tab-bar-special-items)

;;; Advices

(defun thattem-tab-bar-switch-workspace-by-mouse (&optional event)
  "Switch to workspace.
Target workspace id is specified by the property `id'
of the string under the EVENT."
  (interactive "e")
  (let* ((event-start (event-start event))
         (posn-string (posn-string event-start))
         (id (get-text-property
              (cdr posn-string) 'id (car posn-string))))
    (when id (thattem-workspace-switch id))))

(defun thattem-tab-bar--advice-around--tab-bar-mouse-1 (func event)
  "Add workspace switch function to `tab-bar-mouse-1'.
FUNC is the original function and EVENT is its parameter."
  (if-let* ((event-start (event-start event))
            (posn-string (posn-string event-start))
            (type (get-text-property
                   (cdr posn-string) 'type (car posn-string))))
      (cond ((eq type 'workspace)
             (thattem-tab-bar-switch-workspace-by-mouse event))
            (t
             (funcall func event)))
    (funcall func event)))

;;; Keybindings

(defun thattem-tab-bar-deal-mouse-wheel-up (&optional event)
  "Switch to previous workspace, or switch to previous tab.
Target workspace id is specified by the frame parameter
`previous-workspace-id' under the EVENT."
  (interactive "e")
  (let* ((event-start (event-start event))
         (x (car (posn-x-y event-start)))
         (frame (posn-window event-start))
         (x-bound (frame-parameter frame 'workspace-x-bound))
         (id (frame-parameter frame 'workspace-previous)))
    (cond ((and x-bound
                (<= (car x-bound) x)
                (< x (cdr x-bound)))
           (when id (thattem-workspace-switch id)))
          (t
           (tab-previous)))))

(defun thattem-tab-bar-deal-mouse-wheel-down (&optional event)
  "Switch to next workspace, or switch to next tab.
Target workspace id is specified by the frame parameter
`next-workspace-id' under the EVENT."
  (interactive "e")
  (let* ((event-start (event-start event))
         (x (car (posn-x-y event-start)))
         (frame (posn-window event-start))
         (x-bound (frame-parameter frame 'workspace-x-bound))
         (id (frame-parameter frame 'workspace-next)))
    (cond ((and x-bound
                (<= (car x-bound) x)
                (< x (cdr x-bound)))
           (when id (thattem-workspace-switch id)))
          (t
           (tab-next)))))

(defun thattem-tab-bar-deal-down-mouse-2 (&optional event)
  "Dispatch events after the EVENT <down mouse 2>.
It allows you to switch tab by pressing and scroll mouse wheel."
  (interactive "e")
  (let ((go-on t)
        (shadow nil))
    (while go-on
      (let ((next-event (read-event)))
        (cond ((memq (car-safe next-event)
                     '(wheel-down
                       double-wheel-down
                       triple-wheel-down))
               (setq shadow t)
               (tab-next))
              ((memq (car-safe next-event)
                     '(wheel-up
                       double-wheel-up
                       triple-wheel-up))
               (setq shadow t)
               (tab-previous))
              ((memq (car-safe next-event)
                     '(mouse-2
                       double-mouse-2
                       triple-mouse-2
                       drag-mouse-2
                       double-drag-mouse-2
                       triple-drag-mouse-2))
               (setq go-on nil)
               (unless shadow
                 (add-to-list 'unread-command-events next-event)))
              (t
               (setq go-on nil)
               (add-to-list 'unread-command-events event)
               (add-to-list 'unread-command-events next-event)))))))


(provide 'thattem-tab-bar-advices)
;;; thattem-tab-bar-advices.el ends here
