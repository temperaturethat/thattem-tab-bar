;;; Tab-bar-common-items --- define common items  -*- lexical-binding: t; -*-

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

;; Tab-bar-common-items defines every common items used tab bar (not
;; using thattem-emacs-library).

;;; Code:

(require 'cl-lib)
(require 'nerd-icons)
(require 'thattem-tab-bar-faces)


(defun thattem-tab-bar-format-history ()
  "Produce back and forward buttons for the tab bar.
These buttons will be shown when `tab-bar-history-mode' is enabled.
You can hide these buttons by customizing `tab-bar-format' and
removing `tab-bar-format-history' from it."
  (when tab-bar-history-mode
    `((history-back
       menu-item
       ,(propertize
         (nerd-icons-faicon
          "nf-fa-caret_left"
          :face `(thattem-tab-bar/bright
                  (:height ,thattem-tab-bar-big-font-height)))
         'mouse-face
         'thattem-tab-bar/bright-hover)
       tab-bar-history-back
       :help "Click to go back in tab history")
      (history-forward
       menu-item
       ,(propertize
         (nerd-icons-faicon
          "nf-fa-caret_right"
          :face `(thattem-tab-bar/bright
                  (:height ,thattem-tab-bar-big-font-height)))
         'mouse-face
         'thattem-tab-bar/bright-hover)
       tab-bar-history-forward
       :help "Click to go forward in tab history"))))


(defcustom thattem-tab-bar-tab-name-style
  'thattem-tab-bar-long-name
  "Style of tab bar tabs' name."
  :type '(choice (const thattem-tab-bar-long-name)
                 (const thattem-tab-bar-short-name))
  :group 'thattem-tab-bar)

(defun thattem-tab-bar-name-format (tab i)
  "Return the formatted tab name to display in the tab bar.
TAB is the tab item and I is the index."
  (let* ((long-name (eq thattem-tab-bar-tab-name-style
                        'thattem-tab-bar-long-name))
         (current-p (eq (car tab) 'current-tab))
         (face (if current-p
                   `(thattem-tab-bar/dark-highlight
                     (:height ,thattem-tab-bar-big-font-height))
                 `(thattem-tab-bar/dark
                   (:height ,thattem-tab-bar-small-font-height))))
         (icon-function
          (lambda (buffer-name)
            (propertize
             (if-let* ((buffer (get-buffer buffer-name)))
                 (nerd-icons-icon-for-mode
                  (with-current-buffer buffer major-mode)
                  :face face)
               (nerd-icons-codicon
                "nf-cod-question"
                :face face))
             'mouse-face 'thattem-tab-bar/dark-hover))))
    (concat (propertize
             (if tab-bar-tab-hints (format "%d " i) "")
             'face face
             'mouse-face 'thattem-tab-bar/dark-hover)
            (funcall icon-function (alist-get 'name tab))
            (when long-name
              (propertize
               (let ((name (alist-get 'name tab)))
                 (if (> (length name) 6)
                     (concat
                      (propertize (substring name 0 5) 'face face)
                      (nerd-icons-faicon
                       "nf-fa-ellipsis_v" :face face))
                   (propertize name 'face face)))
               'mouse-face 'thattem-tab-bar/dark-hover))
            (mapconcat
             (lambda (buffer)
               (funcall icon-function buffer))
             (cdr (delete-dups (cons
                                (if current-p
                                    (current-buffer)
                                  (alist-get 'name tab))
                                (window-state-buffers
                                 (if current-p
                                     (window-state-get)
                                   (alist-get 'ws tab))))))
             (when long-name
               (propertize
                " "
                'face face
                'mouse-face 'thattem-tab-bar/dark-hover)))
            (propertize
             " " 'face face)
            (when (and tab-bar-close-button-show
                       (not (eq tab-bar-close-button-show
                                (if current-p 'non-selected
                                  'selected))))
              (propertize
               (nerd-icons-codicon
                "nf-cod-close"
                :face `(thattem-tab-bar/dark
                        (:height ,thattem-tab-bar-small-font-height)))
               'close-tab t
               'help-echo "Click to close tab"
               'mouse-face 'thattem-tab-bar/dark-hover)))))

(defun thattem-tab-bar--format-tab (tab i)
  "Format TAB using its index I and return the result as a keymap."
  (append
   `((,(intern (format "left-sep-%i" i))
      menu-item
      ,(nerd-icons-powerline
        "nf-pl-left_hard_divider"
        :face `(thattem-tab-bar/dark-thin
                (:height ,thattem-tab-bar-big-font-height)))
      ignore :help ""))
   (cond
    ((eq (car tab) 'current-tab)
     `((current-tab
        menu-item
        ,(thattem-tab-bar-name-format tab i)
        ignore
        :help "Current tab")))
    (t
     `((,(intern (format "tab-%i" i))
        menu-item
        ,(thattem-tab-bar-name-format tab i)
        ,(alist-get 'binding tab)
        :help "Click to visit tab"))))
   `((,(intern (format "right-sep-%i" i))
      menu-item
      ,(nerd-icons-powerline
        "nf-pl-left_hard_divider"
        :face `(thattem-tab-bar/bright-thin
                (:height ,thattem-tab-bar-big-font-height)))
      ignore :help ""))
   (when (alist-get 'close-binding tab)
     `((,(if (eq (car tab) 'current-tab)
             'C-current-tab
           (intern (format "C-tab-%i" i)))
        menu-item ""
        ,(alist-get 'close-binding tab))))))

(defun thattem-tab-bar-format-tabs ()
  "Produce all the tabs for the tab bar."
  (cl-loop for tab in (funcall tab-bar-tabs-function)
           for index from 1
           nconc (thattem-tab-bar--format-tab tab index)))


(defun thattem-tab-bar-format-add-tab ()
  "Button to add a new tab."
  `((add-tab menu-item
             ,(propertize
               (nerd-icons-codicon
                "nf-cod-add"
                :face `(thattem-tab-bar/bright
                        (:height ,thattem-tab-bar-big-font-height)))
               'mouse-face 'thattem-tab-bar/bright-hover)
             tab-bar-new-tab
             :help "New tab")))


(defun thattem-tab-bar-format-global ()
  "Produce display of `global-mode-string' in the tab bar."
  `((global menu-item
            ,(propertize
              (format-mode-line
               global-mode-string
               `(thattem-tab-bar/bright
                 (:height ,thattem-tab-bar-big-font-height)))
              'mouse-face 'thattem-tab-bar/bright-hover)
            ignore)))


(defun thattem-tab-bar-format-align-right ()
  "Align the rest of tab bar items to the right."
  (let* ((symbol 'thattem-tab-bar-format-align-right)
         (rest (cdr (memq symbol tab-bar-format)))
         (not-eval-items
          '(thattem-tab-bar-format-position-helper))
         (rest (cl-set-difference rest not-eval-items))
         (rest (tab-bar-format-list rest))
         (rest (mapconcat (lambda (item) (nth 2 item)) rest ""))
         (hpos (string-pixel-width rest))
         (str (propertize " " 'display
                          (if (window-system)
                              `(space :align-to (- right (,hpos)))
                            `(space :align-to (,(- (frame-inner-width)
                                                   hpos))))
                          'face `(thattem-tab-bar/bright))))
    `((align-right menu-item ,str ignore))))

(defun thattem-tab-bar-format-align-middle ()
  "Align the rest of tab bar items to the middle.

It will keep items after `thattem-tab-bar-format-align-right'
align to the right.  And if the \"right part\" is long, the
\"middle part\" will be pushed to the left."
  (let* ((symbol 'thattem-tab-bar-format-align-middle)
         (middle (cdr (memq symbol tab-bar-format)))
         (not-eval-items
          '(thattem-tab-bar-format-position-helper))
         (middle (cl-set-difference
                  middle (memq 'thattem-tab-bar-format-align-right
                               tab-bar-format)))
         (middle (cl-set-difference middle not-eval-items))
         (middle (tab-bar-format-list middle))
         (middle (mapconcat (lambda (item) (nth 2 item)) middle ""))
         (hpos-middle (string-pixel-width middle))
         (right-symbol 'thattem-tab-bar-format-align-right)
         (rest (cdr (memq right-symbol
                          tab-bar-format)))
         (rest (cl-set-difference rest not-eval-items))
         (rest (tab-bar-format-list rest))
         (rest (mapconcat (lambda (item) (nth 2 item)) rest ""))
         (hpos-rest (string-pixel-width rest))
         (str (propertize " " 'display
                          `(space :align-to
                                  (,(min(/ (- (frame-inner-width)
                                              hpos-middle)
                                           2)
                                        (- (frame-inner-width)
                                           hpos-middle
                                           hpos-rest))))
                          'face `(thattem-tab-bar/bright))))
    `((align-right menu-item ,str ignore))))

;; Since mouse wheel event on tab bar cannot get the `posn-string`,
;; we cannot use text property to judge whether scroll tab or scroll
;; other things, so I save the X coordinate of the special item as
;; frame parameter and use it as the judgment.
(defun thattem-tab-bar-format-position-helper ()
  "A helper function to set special item's X coordinate as frame \
parameter."
  (cl-loop
   for (super parameter) on
   '(thattem-tab-bar-format-workspaces
     workspace-x-bound)
   by #'cddr
   do
   (if-let* ((rests (memq super tab-bar-format)))
       (let* ((before (cl-set-difference tab-bar-format rests))
              (not-eval-items
               '(thattem-tab-bar-format-position-helper))
              (before (cl-set-difference before not-eval-items))
              (before (tab-bar-format-list before))
              (before (mapconcat (lambda (item) (nth 2 item)) before ""))
              (before-width (string-pixel-width before))
              (super (tab-bar-format-list (list super)))
              (super (mapconcat (lambda (item) (nth 2 item)) super ""))
              (super-width (string-pixel-width super)))
         (set-frame-parameter nil parameter
                              (cons before-width
                                    (+ before-width super-width))))
     (set-frame-parameter nil parameter nil))))


(provide 'thattem-tab-bar-common-items)
;;; thattem-tab-bar-common-items.el ends here
