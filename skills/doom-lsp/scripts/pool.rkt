#lang racket
; pool.rkt — Pure Racket clangd pool
;
; Primary mode: persistent daemon process (one per project for clangd reuse).
; Falls back to single-shot spawning if daemon can't start.
;
; Usage:
;   (require "pool.rkt")
;   (pool-ping "/path/to/project")
;   (pool-goto "/path/to/project" "src/file.c" 75 12)

(require json)

(provide pool-ping pool-goto pool-refs pool-sym pool-doc pool-hover
         pool-stop pool-stop-all pool-list pool-status)

;; Resolve clangd.rkt relative to this file, fallback to current-directory
(define CLANGD-SCRIPT
  (path->string
   (let ([dir (current-load-relative-directory)])
     (if dir
         (build-path (path-only (path->string dir)) "clangd.rkt")
         (build-path (current-directory) "clangd.rkt")))))

;; ─── Daemon pool ────────────────────────────────────────────────────────────────

(define pool-processes (make-hash))  ; dir → {out inp ctrl alive}

(define (spawn-daemon! dir)
  (define racket-bin (find-executable-path "racket"))
  (unless racket-bin (error 'pool "racket not found in PATH"))
  (define sp (process* (path->string racket-bin)
                       (list CLANGD-SCRIPT "-d" dir "DAEMONMODE")))
  (define dout  (car sp))    ; stdout from daemon
  (define dinp  (cadr sp))   ; stdin to daemon
  (define dstderr (caddr sp))
  (define dctrl (list-ref sp 4))
  ;; Drain stderr in a background thread to prevent clangd blocking on full stderr buffer
  (thread (lambda ()
            (let loop ()
              (define ln (read-line dstderr))
              (unless (eof-object? ln) (loop)))))
  ;; Wait for READY (with guard against EOF/timeout)
  (define first-line
    (sync/timeout 10
      (handle-evt (port->evt dout)
        (lambda (p)
          (with-handlers ([exn:fail? (lambda _ #f)])
            (read-line p))))))
  (unless first-line
    ((dctrl) 'kill)
    (close-output-port dinp)
    (close-input-port dout)
    (error 'pool "clangd daemon for ~a timed out waiting for READY" dir))
  (define trimmed (string-trim first-line))
  (unless (equal? trimmed "READY")
    ((dctrl) 'kill)
    (close-output-port dinp)
    (close-input-port dout)
    (error 'pool "clangd daemon for ~a failed to start: ~a" dir trimmed))
  (hash-set! pool-processes dir (hasheq 'out dout 'inp dinp 'ctrl dctrl 'alive #t))
  (fprintf (current-error-port) "[pool] daemon started for ~a\n" dir)
  (flush-output (current-error-port))
  (hasheq 'out dout 'inp dinp 'ctrl dctrl 'alive #t))

(define (ensure-daemon! dir)
  (define existing (hash-ref pool-processes dir #f))
  (cond
    [existing
     (define alive (hash-ref existing 'alive #f))
     (if alive existing
         (begin (hash-remove! pool-processes dir) (spawn-daemon! dir)))]
    [else (spawn-daemon! dir)]))

(define (send-command dir cmd-line)
  (define daemon (ensure-daemon! dir))
  (define inp (hash-ref daemon 'inp))
  (define out (hash-ref daemon 'out))
  (define ctrl (hash-ref daemon 'ctrl))
  (fprintf inp "~a\n" cmd-line)
  (flush-output inp)
  (define resp (read-line out))
  (cond
    [(eof-object? resp)
     ;; Daemon died — mark dead, retry once
     (hash-set! daemon 'alive #f)
     (define daemon2 (ensure-daemon! dir))
     (define inp2 (hash-ref daemon2 'inp))
     (define out2 (hash-ref daemon2 'out))
     (fprintf inp2 "~a\n" cmd-line)
     (flush-output inp2)
     (read-line out2)]
    [(string-prefix? (string-trim resp) "ERR:")
     (fprintf (current-error-port) "[pool] daemon error: ~a\n" resp)
     #f]
    [else resp]))

(define (send-json dir cmd-line)
  (define line (send-command dir cmd-line))
  (and line
       (> (string-length line) 0)
       (with-handlers ([exn:fail:read? (lambda _ #f)])
         (with-input-from-string line read-json))))

;; ─── Public API (pool) ─────────────────────────────────────────────────────────

(define (pool-ping dir)
  (define result (send-command dir "ping"))
  (and (string? result) (string=? (string-trim result) "pong")))

(define (pool-goto dir file line col)
  (send-json dir (format "def ~a ~a ~a" file line col)))

(define (pool-refs dir file line col)
  (send-json dir (format "refs ~a ~a ~a" file line col)))

(define (pool-sym dir query [file ""])
  (if (string=? file "")
      (send-json dir (format "sym ~a" query))
      (send-json dir (format "sym ~a ~a" query file))))

(define (pool-doc dir file)
  (send-json dir (format "doc ~a" file)))

(define (pool-hover dir file line col)
  (define r (send-json dir (format "hover ~a ~a ~a" file line col)))
  (cond [(string? r) r]
        [(hash? r) (hash-ref r 'result "none")]
        [else "none"]))

;; ─── Pool lifecycle ─────────────────────────────────────────────────────────────

(define (pool-stop dir)
  (define daemon (hash-ref pool-processes dir #f))
  (when daemon
    (define inp (hash-ref daemon 'inp))
    (fprintf inp "quit\n")
    (flush-output inp)
    (close-output-port inp)
    (close-input-port (hash-ref daemon 'out))
    (hash-remove! pool-processes dir)
    (fprintf (current-error-port) "[pool] daemon stopped for ~a\n" dir)))

(define (pool-stop-all)
  (for ([(dir _) (in-hash pool-processes)])
    (pool-stop dir)))

(define (pool-list)
  (hash-map pool-processes
    (lambda (dir daemon)
      (hasheq 'dir dir 'alive (hash-ref daemon 'alive #f)))))

(define (pool-status)
  (hasheq 'total (hash-count pool-processes)
          'projects (pool-list)))

(module+ main
  (displayln "pool.rkt — Racket clangd pool (daemon mode)")
  (displayln "Usage: (pool-ping \"/path/to/project\") etc.")
  (displayln "Pass project dir explicitly, or (current-directory) for a default."))
