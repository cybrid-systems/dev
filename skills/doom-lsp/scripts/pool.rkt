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

(provide pool-ping pool-goto pool-refs pool-sym pool-doc
         pool-stop pool-stop-all pool-list pool-status)

;; Resolve clangd.rkt relative to pool.rkt's own directory.
;; Search: same dir, scripts/ subdir, or explicit path from load-relative.
(define CLANGD-SCRIPT
  (path->string
   (let* ([here (or (current-load-relative-directory)
                    (current-directory))]
          [maybe-dir (cond
                      [(path? here) (path->string here)]
                      [(string? here) here]
                      [else (path->string (current-directory))])]
          [candidates (list
                       (build-path (path-only (string->path maybe-dir)) "clangd.rkt")
                       (build-path (string->path maybe-dir) "clangd.rkt")
                       (build-path (current-directory) "clangd.rkt")
                       (build-path (current-directory) "scripts" "clangd.rkt"))])
     (let loop ([cs candidates])
       (cond [(null? cs) (car candidates)]
             [(file-exists? (car cs)) (car cs)]
             [else (loop (cdr cs))])))))

;; ─── Daemon pool ────────────────────────────────────────────────────────────────

(define pool-processes (make-hash))  ; dir → {out inp ctrl alive}

(define (spawn-daemon! dir)
  (define racket-bin (find-executable-path "racket"))
  (unless racket-bin (error 'pool "racket not found in PATH"))
  ; process* returns (list stdout-input stdin-output pid stderr-input control).
  ; Use absolute path for racket to avoid PATH resolution issues in subprocess.
  (define sp (process* (path->string racket-bin) CLANGD-SCRIPT "-d" dir "DAEMONMODE"))
  (define dout (list-ref sp 0))    ; stdout from daemon (input-port)
  (define dinp (list-ref sp 1))    ; stdin to daemon (output-port)
  (define dpid (list-ref sp 2))
  (define dstderr (list-ref sp 3))
  (define dctrl-raw (list-ref sp 4))
  ; process* returns a 1-arg control proc; wrap to match process convention ((dctrl) 'kill)
  (define dctrl (lambda () dctrl-raw))
  ;; Drain stderr in a background thread to prevent clangd blocking on full stderr buffer
  (thread (lambda ()
            (let loop ()
              (define ln (read-line dstderr))
              (unless (eof-object? ln) (loop)))))
  ;; Wait for READY (with guard against EOF/timeout)
  ;; Use a thread + channel since port->evt is not available in Racket CS
  (define ready-chan (make-channel))
  (define ready-thread
    (thread (lambda ()
      (define first-line
        (with-handlers ([exn:fail? (lambda _ 'eof)])
          (read-line dout)))
      (channel-put ready-chan (or first-line 'eof)))))
  (define ready-line (sync/timeout 10 ready-chan))
  (unless ready-line
    ((dctrl) 'kill)
    (close-output-port dinp)
    (close-input-port dout)
    (error 'pool "clangd daemon for ~a timed out waiting for READY" dir))
  (define trimmed (string-trim (if (eof-object? ready-line) "" (if (string? ready-line) ready-line ""))))
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

;; Max retries for daemon restart before giving up
(define MAX-RESTART-RETRIES 3)

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
     ;; Daemon died — mark dead and retry with backoff
     (hash-set! daemon 'alive #f)
     (let retry ([attempt 1])
       (define daemon2 (ensure-daemon! dir))
       (define inp2 (hash-ref daemon2 'inp))
       (define out2 (hash-ref daemon2 'out))
       (fprintf inp2 "~a\n" cmd-line)
       (flush-output inp2)
       (define resp2 (read-line out2))
       (cond
         [(eof-object? resp2)
          (if (< attempt MAX-RESTART-RETRIES)
              (begin (sleep (* 0.5 attempt)) ; backoff: 0.5, 1.0, 1.5s
                     (hash-set! daemon2 'alive #f)
                     (retry (add1 attempt)))
              (begin (fprintf (current-error-port)
                      "[pool] daemon for ~a crashed ~a times, giving up\n" dir MAX-RESTART-RETRIES)
                     #f))]
         [else resp2]))]
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
