#!/usr/bin/guile3.0 \
--no-auto-compile
!#

;;; guile-ram-mon

;; MIT License

;; Copyright (c) 2023 Daniil Arkhangelsky (Kiky Tokamuro)

;; Permission is hereby granted, free of charge, to any person obtaining a copy
;; of this software and associated documentation files (the "Software"), to deal
;; in the Software without restriction, including without limitation the rights
;; to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;; copies of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:

;; The above copyright notice and this permission notice shall be included in all
;; copies or substantial portions of the Software.

;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;; IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;; FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;; AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;; LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;; OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

(use-modules
 (ice-9 textual-ports)
 (ice-9 threads)
 (web server)
 (web request)
 (web response)
 (web uri)
 (webview)
 (json))

(define (floor-to-two-decimal-places num)
  "Floor number to two decimal places after comma"
  (/ (floor (* num 100)) 100.0))

(define (kb-str->mb-number str)
  "Convert KB string to MB number"
  (floor-to-two-decimal-places (/ (string->number str) 1024.0)))

(define (get-memory-statistics)
  "Get memory statistics"
  (let* ((meminfo-file "/proc/meminfo")
         (meminfo-contents (string-trim-right (call-with-input-file meminfo-file get-string-all) #\newline)))
    (if (not (eof-object? meminfo-contents))
        (let* ((meminfo-lines (string-split meminfo-contents #\newline))
               (meminfo-values (map (lambda (line)
                                      (let* ((tokens (string-tokenize line))
                                             (name (car tokens))
                                             (value (kb-str->mb-number (cadr tokens))))
                                        (cons name value)))
                                    meminfo-lines))
               (total-ram (cdr (assoc "MemTotal:" meminfo-values)))
               (free-ram (cdr (assoc "MemFree:" meminfo-values)))
               (cached (cdr (assoc "Cached:" meminfo-values)))
               (swap-total (cdr (assoc "SwapTotal:" meminfo-values)))
               (swap-free (cdr (assoc "SwapFree:" meminfo-values))))
          (list
           (cons 'ram-total total-ram)
           (cons 'ram-free (floor-to-two-decimal-places (+ free-ram cached)))
	   (cons 'ram-used (floor-to-two-decimal-places (- total-ram (+ free-ram cached))))
           (cons 'swap-total swap-total)
           (cons 'swap-free swap-free)
	   (cons 'swap-used (floor-to-two-decimal-places (- swap-total swap-free)))))
        '())))

(define (wv-get-memory-statistics seq req arg)
  "get-memory-statistics bind for webview javascript"
  (webview-return wv seq 0 (scm->json-string (get-memory-statistics))))

(define (get-static-file-content file)
  "Folder with static files"
  (let ((file-path (string-append (dirname (current-filename)) "/static/" file)))
    (call-with-input-file file-path get-string-all)))

(define (not-found request)
  "Not found response"
  (values (build-response #:code 404)
          (string-append "Resource not found: "
                         (uri->string (request-uri request)))))

(define (handle-request request request-body)
  "Handler server requests"
  (let ((path (uri-path (request-uri request))))
    (cond
      ((string=? path "/")
       (values '((content-type . (text/html))) (get-static-file-content "index.html")))
      ((string=? path "/liner-bar.css")
       (values '((content-type . (text/css))) (get-static-file-content "liner-bar.css")))
      ((string=? path "/liner-bar.js")
       (values '((content-type . (text/javascript))) (get-static-file-content "liner-bar.js")))
      ((string=? path "/script.js")
       (values '((content-type . (text/javascript))) (get-static-file-content "script.js")))
      (else (not-found request)))))

;; Run server
(make-thread
 (lambda ()
   (run-server handle-request 'http '(#:port 8080))))

;; Setup WebView
(define wv (webview-create 0 (make-webview-t)))
(webview-set-title wv "Guile-Ram-Mon")
(webview-navigate wv "http://localhost:8080/")
(webview-set-size wv 700 230 (ffi-webview-symbol-val 'WEBVIEW-HINT-FIXED))
(webview-bind wv "getMemoryStats" wv-get-memory-statistics 0)
(webview-run wv)
