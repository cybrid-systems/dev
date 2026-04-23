#lang racket
; pool.rkt - Pure Racket clangd pool (no Python)
; Each command spawns a fresh clangd.rkt process (single-shot).
; Simpler and correct. Multi-project reuse via persistent pool not yet stable.

(require json)

(provide pool-ping pool-goto pool-refs pool-sym pool-doc pool-hover
         pool-stop pool-stop-all pool-list pool-status)

(define CLANGD-SCRIPT
  (path->string (build-path (current-directory) "clangd.rkt")))
(define REDIS-DIR "/home/dev/code/redis-7.0.15")

;; Run clangd.rkt single-shot, return first stdout line
(define (run! cmd project [args '()])
  (define sp (apply process* "/usr/bin/racket"
                    (list* CLANGD-SCRIPT "-d" project cmd args)))
  (define out (car sp))
  (define inp (cadr sp))
  (define line (read-line out))
  (with-handlers ([exn:fail? (lambda _ (void))])
    (close-output-port inp))
  (with-handlers ([exn:fail? (lambda _ (void))])
    (close-input-port out))
  line)

(define (run-json! cmd project [args '()])
  (define line (run! cmd project args))
  (and (> (string-length line) 0)
       (with-handlers ([exn:fail:read? (lambda _ #f)])
         (with-input-from-string line read-json))))

(define (pool-ping dir)
  (string=? (run! "ping" dir) "pong"))

(define (pool-goto dir file line col)
  (run-json! "def" dir (list file (~a line) (~a col))))

(define (pool-refs dir file line col)
  (run-json! "refs" dir (list file (~a line) (~a col))))

(define (pool-sym dir query)
  (run-json! "sym" dir (list query)))

(define (pool-doc dir file)
  (run-json! "doc" dir (list file)))

(define (pool-hover dir file line col)
  (define r (run-json! "hover" dir (list file (~a line) (~a col))))
  (cond [(string? r) r]
        [(hash? r) (hash-ref r 'result "none")]
        [else "none"]))

(define (pool-stop dir) (void))
(define (pool-stop-all) (void))
(define (pool-list) '())
(define (pool-status) (hasheq 'total 0))

(module+ main
  (displayln "pool.rkt - pure Racket, no Python")
  (define p (pool-ping REDIS-DIR))
  (write (format "ping: ~a\n" p))
  (write (format "def: ~a\n" (pool-goto REDIS-DIR (string-append REDIS-DIR "/src/anet.c") 75 12)))
  (write (format "sym: ~a\n" (pool-sym REDIS-DIR "anet")))
  (write (format "doc count: ~a\n" (length (pool-doc REDIS-DIR (string-append REDIS-DIR "/src/anet.c")))))
  (write (format "refs count: ~a\n" (length (pool-refs REDIS-DIR (string-append REDIS-DIR "/src/anet.c") 75 12))))
  (write (format "hover: ~a\n" (pool-hover REDIS-DIR (string-append REDIS-DIR "/src/anet.c") 75 12)))
  (write "done\n"))
