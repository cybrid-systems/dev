#lang racket
(require racket/system racket/port json)

(provide pool-ping pool-goto pool-refs pool-sym pool-doc
         pool-stop pool-stop-all pool-list pool-status pool-health
         pool-ping-async pool-goto-async pool-refs-async pool-sym-async pool-doc-async
         pool-set-rate-limit)

;; ─── Resolve clangd.rkt path ──────────────────────────────────────────────────

(define CLANGD-SCRIPT
  (let* ([here (or (current-load-relative-directory) (current-directory))]
         [dir (if (path? here) (path->string here) (path->string (current-directory)))]
         [cs (list (build-path (path-only (string->path dir)) "clangd.rkt")
                   (build-path (string->path dir) "clangd.rkt")
                   (build-path (current-directory) "clangd.rkt")
                   (build-path (current-directory) "scripts" "clangd.rkt"))])
    (path->string (let loop ([cs cs])
                   (if (or (null? cs) (file-exists? (car cs))) (car cs) (loop (cdr cs)))))))

;; ─── Structured JSON logging ────────────────────────────────────────────

(define (log-json level component msg)
  (define entry (hasheq 'time (current-seconds) 'level (format "~a" level)
                        'component (format "~a" component) 'msg msg))
  (fprintf (current-error-port) "~a\n" (jsexpr->string entry))
  (flush-output (current-error-port)))

;; ─── Rate limiter ──────────────────────────────────────────────────────

(define rate-limits (make-hash))

(define (pool-set-rate-limit dir n)
  (hash-set! rate-limits dir (make-semaphore n)))

(define (rate-acquire! dir)
  (define sem (hash-ref rate-limits dir #f))
  (when sem (semaphore-wait sem))
  sem)

;; ─── Daemon pool ───────────────────────────────────────────────────────

(define pool-processes (make-hash))

(define (spawn-daemon! dir)
  (define racket-bin (or (find-executable-path "racket") (error 'pool "racket not found")))
  (define sp (process* (path->string racket-bin) CLANGD-SCRIPT "-d" dir "DAEMONMODE"))
  (define dout (list-ref sp 0)) (define dinp (list-ref sp 1))
  (define dstderr (list-ref sp 3)) (define dctrl (list-ref sp 4))

  (thread (lambda () (let loop () (define ln (read-line dstderr)) (unless (eof-object? ln) (loop)))))

  (define ready-chan (make-channel))
  (thread (lambda () (channel-put ready-chan (with-handlers ([exn:fail? (lambda _ 'eof)]) (read-line dout)))))
  (define ready-line (sync/timeout 10 ready-chan))
  (unless (and (string? ready-line) (equal? (string-trim ready-line) "READY"))
    (dctrl 'kill) (close-output-port dinp) (close-input-port dout)
    (error 'pool "daemon for ~a failed" dir))

  ;; Reader thread: dispatches daemon stdout to waiting channels (FIFO)
  (define pending (box '()))
  (define pending-lock (make-semaphore 1))
  (define reader-stop (make-channel))
  (thread
    (lambda ()
      (let loop ()
        (unless (sync/timeout 0 reader-stop)
          (with-handlers ([exn:fail? (lambda (e) (sleep 0.05))])
            (define line (read-line dout))
            (cond
              [(eof-object? line)
               (call-with-semaphore pending-lock
                 (lambda () (for ([ch (in-list (unbox pending))]) (channel-put ch #f)) (set-box! pending '())))
               (channel-put reader-stop 'stop)]
              [else
               (call-with-semaphore pending-lock
                 (lambda () (when (pair? (unbox pending))
                         (define ch (car (unbox pending)))
                         (set-box! pending (cdr (unbox pending)))
                         (channel-put ch line))))
               (loop)]))))))

  (define entry (make-hasheq))
  (hash-set! entry 'daemon (list dout dinp dctrl reader-stop))
  (hash-set! entry 'pending pending) (hash-set! entry 'lock pending-lock)
  (hash-set! entry 'alive #t) (hash-set! entry 'start-time (current-seconds))
  (hash-set! pool-processes dir entry)
  (log-json 'info 'pool "daemon started")
  (list dout dinp dctrl reader-stop))

(define (ensure-daemon! dir)
  (define entry (hash-ref pool-processes dir #f))
  (cond [(and entry (hash-ref entry 'alive #f)) (hash-ref entry 'daemon)]
        [else (when entry (hash-remove! pool-processes dir)) (spawn-daemon! dir)]))

;; ─── Send command ──────────────────────────────────────────────────────

(define (send-command dir cmd-line [timeout 5])
  ;; Rate limit
  (define rate-sem (rate-acquire! dir))

  (define entry (hash-ref pool-processes dir #f))
  (define daemon (if (and entry (hash-ref entry 'alive #f)) (hash-ref entry 'daemon) (ensure-daemon! dir)))
  (set! entry (hash-ref pool-processes dir))

  (define resp-chan (make-channel))
  (call-with-semaphore (hash-ref entry 'lock)
    (lambda () (set-box! (hash-ref entry 'pending) (append (unbox (hash-ref entry 'pending)) (list resp-chan)))))
  (with-handlers ([exn? (lambda (e) #f)]) (fprintf (list-ref daemon 1) "~a\n" cmd-line) (flush-output (list-ref daemon 1)))

  (define resp (sync/timeout timeout resp-chan))
  (when rate-sem (semaphore-post rate-sem))

  (cond
    [(not resp)
     (hash-set! entry 'alive #f)
     (let retry ([attempt 1])
       (define daemon2 (ensure-daemon! dir))
       (define entry2 (hash-ref pool-processes dir))
       (define inp2 (list-ref daemon2 1))
       (define resp-chan2 (make-channel))
       (call-with-semaphore (hash-ref entry2 'lock)
         (lambda () (set-box! (hash-ref entry2 'pending) (append (unbox (hash-ref entry2 'pending)) (list resp-chan2)))))
       (with-handlers ([exn? (lambda (e) #f)]) (fprintf inp2 "~a\n" cmd-line) (flush-output inp2))
       (define resp2 (sync/timeout timeout resp-chan2))
       (cond [(not resp2)
              (if (< attempt 3)
                  (let ([e (hash-ref pool-processes dir #f)])
                    (sleep (* 0.5 attempt)) (when e (hash-set! e 'alive #f))
                    (retry (add1 attempt)))
                  (begin (log-json 'error 'pool "crash limit") #f))]
             [else resp2]))]
    [else resp]))

(define (send-json dir cmd-line [timeout 5])
  (define line (send-command dir cmd-line timeout))
  (and (string? line) (positive? (string-length line))
       (with-handlers ([exn:fail:read? (lambda _ #f)]) (with-input-from-string line read-json))))

;; ─── Public API ────────────────────────────────────────────────────────

(define HEAVY-TIMEOUT 20)

(define (pool-ping dir) (equal? (send-command dir "ping") "pong"))
(define (pool-goto dir file line col) (send-json dir (format "def ~a ~a ~a" file line col) HEAVY-TIMEOUT))
(define (pool-refs dir file line col) (or (send-json dir (format "refs ~a ~a ~a" file line col) HEAVY-TIMEOUT) '()))
(define (pool-sym dir query [file ""])
  (or (send-json dir (if (string=? file "") (format "sym ~a" query) (format "sym ~a ~a" query file))) '()))
(define (pool-doc dir file) (or (send-json dir (format "doc ~a" file) HEAVY-TIMEOUT) '()))

;; ─── Health probe ──────────────────────────────────────────────────────

(define (pool-health dir)
  (define entry (hash-ref pool-processes dir #f))
  (cond [(not entry) (hasheq 'dir dir 'alive #f 'reason "no entry")]
        [(not (hash-ref entry 'alive #f)) (hasheq 'dir dir 'alive #f 'reason "dead")]
        [else
         (define q (length (unbox (hash-ref entry 'pending))))
         (hasheq 'dir dir 'alive #t 'pending-queue q
                 'uptime-sec (- (current-seconds) (hash-ref entry 'start-time 0)))]))

;; ─── Async API (returns channel; use sync/timeout to collect) ──────────

(define (send-command-async dir cmd-line)
  (define entry (hash-ref pool-processes dir #f))
  (define daemon (if (and entry (hash-ref entry 'alive #f)) (hash-ref entry 'daemon) (ensure-daemon! dir)))
  (set! entry (hash-ref pool-processes dir))
  (define resp-chan (make-channel))
  (call-with-semaphore (hash-ref entry 'lock)
    (lambda () (set-box! (hash-ref entry 'pending) (append (unbox (hash-ref entry 'pending)) (list resp-chan)))))
  (with-handlers ([exn? (lambda (e) #f)]) (fprintf (list-ref daemon 1) "~a\n" cmd-line) (flush-output (list-ref daemon 1)))
  resp-chan)

(define (pool-ping-async dir) (send-command-async dir "ping"))
(define (pool-goto-async dir file line col) (send-command-async dir (format "def ~a ~a ~a" file line col)))
(define (pool-refs-async dir file line col) (send-command-async dir (format "refs ~a ~a ~a" file line col)))
(define (pool-sym-async dir query [file ""])
  (send-command-async dir (if (string=? file "") (format "sym ~a" query) (format "sym ~a ~a" query file))))
(define (pool-doc-async dir file) (send-command-async dir (format "doc ~a" file)))

;; ─── Lifecycle ─────────────────────────────────────────────────────────

(define (pool-stop dir)
  (define entry (hash-ref pool-processes dir #f))
  (when entry
    ;; Release all pending waiters before closing (prevents hung channels)
    (define pending (hash-ref entry 'pending))
    (for ([ch (in-list (unbox pending))]) (channel-put ch #f))
    (set-box! pending '())
    (define dm (hash-ref entry 'daemon))
    (fprintf (list-ref dm 1) "quit\n") (flush-output (list-ref dm 1))
    (close-output-port (list-ref dm 1)) (close-input-port (list-ref dm 0))
    (hash-remove! pool-processes dir)
    (log-json 'info 'pool "daemon stopped")))

(define (pool-stop-all) (for ([(dir _) (in-hash pool-processes)]) (pool-stop dir)))

(define (pool-list)
  (hash-map pool-processes (lambda (dir e) (hasheq 'dir dir 'alive (hash-ref e 'alive #f)))))

(define (pool-status) (hasheq 'total (hash-count pool-processes) 'projects (pool-list)))

(module+ main
  (displayln "pool.rkt — Racket clangd pool"))
