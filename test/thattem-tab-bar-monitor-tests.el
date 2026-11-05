;;; thattem-tab-bar-monitor-tests.el --- Sampling regressions -*- lexical-binding: t; -*-

;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Feed deterministic values through the real sampling and formatting functions.
;; Native module loading remains required, but no test changes the desktop.

;;; Code:

(require 'thattem-tab-bar-test-helper)

(defmacro thattem-tab-bar-test--with-monitor (&rest body)
  "Run BODY with empty sample histories and fixed native sample inputs."
  (declare (indent 0) (debug t))
  `(let ((thattem-tab-bar-timer-frequency 4)
         (thattem-tab-bar-cpu-percentage-buffer nil)
         (thattem-tab-bar-download-speed-buffer nil)
         (thattem-tab-bar-upload-speed-buffer nil)
         (thattem-tab-bar-cpu-percentage 0)
         (thattem-tab-bar-mem-percentage 0)
         (thattem-tab-bar-swap-percentage 0)
         (thattem-tab-bar-download-speed "")
         (thattem-tab-bar-upload-speed ""))
     (cl-letf (((symbol-function 'thattem-cpu-usage) (lambda () 0.5))
               ((symbol-function 'thattem-mem-usage) (lambda () 0.25))
               ((symbol-function 'thattem-swap-usage) (lambda () 0.0))
               ((symbol-function 'thattem-net-speed) (lambda () '(1000.0 2000.0))))
       ,@body)))

(ert-deftest thattem-tab-bar-test--monitor-full-window-converges ()
  "A full sample window reports constant CPU/network rates without startup bias."
  (thattem-tab-bar-test--with-monitor
    (dotimes (_ 4) (thattem-tab-bar-update-system-monitor))
    (should (= thattem-tab-bar-cpu-percentage 50))
    (should (= thattem-tab-bar-mem-percentage 25))
    (should (= thattem-tab-bar-swap-percentage 0))
    (should (equal thattem-tab-bar-download-speed
                   (file-size-human-readable 1000.0 'si nil "B")))
    (should (equal thattem-tab-bar-upload-speed
                   (file-size-human-readable 2000.0 'si nil "B")))))

(ert-deftest thattem-tab-bar-test--monitor-sample-histories-are-bounded ()
  "Old samples are evicted once each CPU/network window reaches capacity."
  (thattem-tab-bar-test--with-monitor
    (setq thattem-tab-bar-cpu-percentage-buffer '(0.0 0.0 0.0 1.0)
          thattem-tab-bar-download-speed-buffer '(0.0 0.0 0.0 999999.0)
          thattem-tab-bar-upload-speed-buffer '(0.0 0.0 0.0 999999.0))
    (thattem-tab-bar-update-system-monitor)
    (should (equal thattem-tab-bar-cpu-percentage-buffer '(0.5 0.0 0.0 0.0)))
    (should (equal thattem-tab-bar-download-speed-buffer '(1000.0 0.0 0.0 0.0)))
    (should (equal thattem-tab-bar-upload-speed-buffer '(2000.0 0.0 0.0 0.0)))))

(ert-deftest thattem-tab-bar-test--monitor-one-sample-window ()
  "Frequency one uses the current sample directly without a history delay."
  (thattem-tab-bar-test--with-monitor
    (setq thattem-tab-bar-timer-frequency 1)
    (thattem-tab-bar-update-system-monitor)
    (should (= thattem-tab-bar-cpu-percentage 50))
    (should (equal thattem-tab-bar-cpu-percentage-buffer '(0.5)))))

(ert-deftest thattem-tab-bar-test--monitor-zero-traffic-is-renderable ()
  "Idle CPU, no swap usage and zero network rates produce valid captions."
  (thattem-tab-bar-test--with-monitor
    (cl-letf (((symbol-function 'thattem-cpu-usage) (lambda () 0.0))
              ((symbol-function 'thattem-net-speed) (lambda () '(0.0 0.0))))
      (thattem-tab-bar-update-system-monitor))
    (should (= thattem-tab-bar-cpu-percentage 0))
    (should (= thattem-tab-bar-swap-percentage 0))
    (dolist (item (thattem-tab-bar-format-system-monitor))
      (should (stringp (nth 2 item))))))

(ert-deftest thattem-tab-bar-test--monitor-warning-at-threshold ()
  "The threshold itself uses the warning face; the value below does not."
  (dolist (value '(79 80 81))
    (let* ((thattem-tab-bar-threshold-high 80)
           (thattem-tab-bar-cpu-percentage value)
           (thattem-tab-bar-mem-percentage value)
           (thattem-tab-bar-swap-percentage value)
           (items (thattem-tab-bar-format-system-monitor)))
      (dolist (key '(system-monitor-cpu system-monitor-mem system-monitor-swap))
        (let ((caption (thattem-tab-bar-test--caption items key)))
          (should (string-match-p (format "%d%%" value) caption))
          ;; Inspect the percentage text, not icon-specific face internals.
          (let ((position (string-match (format "%d%%" value) caption)))
            (should (eq (car (get-text-property position 'face caption))
                        (if (< value 80) 'thattem-tab-bar/dark-highlight
                          'thattem-tab-bar/dark-warning)))))))))

(ert-deftest thattem-tab-bar-test--monitor-upload-and-download-not-swapped ()
  "The upload and download captions display their corresponding cached strings."
  (let* ((thattem-tab-bar-upload-speed "UP")
         (thattem-tab-bar-download-speed "DOWN")
         (items (thattem-tab-bar-format-system-monitor)))
    (should (string-match-p "UP" (thattem-tab-bar-test--caption items 'system-monitor-upload)))
    (should (string-match-p "DOWN" (thattem-tab-bar-test--caption items 'system-monitor-download)))))

;;; thattem-tab-bar-monitor-tests.el ends here
