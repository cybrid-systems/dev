#lang racket
(require racket/system json)

(define RACKET "/usr/local/bin/racket")

(define (path->uri p) (string-append "file://" (path->string (string->path p))))
(define (uri->path u) (path->string (string->path (string-trim u "file://"))))

;; ─── JSON-RPC ───────────────────────────────────────────────────────────────────

(define (send! out msg)
  (define body (with-output-to-string (lambda () (write-json msg))))
  (define enc (string->bytes/utf-8 body))
  (write-bytes (bytes-append (string->bytes/utf-8 (format "Content-Length: ~a\r\n\r\n" (bytes-length enc))) enc) out)
  (flush-output out))

(define (recv! in)
  (let loop ()
    (define raw (read-line in))
    (cond [(eof-object? raw) #f]
          [(equal? (string-trim raw "\r") "") (let ([m (read-json in)]) (if (hash-ref m (quote method) #f) (loop) m))]
          [else (loop)])))

;; ─── Connection lifecycle ───────────────────────────────────────────────────────

(define (connect dir)
  (define-values (proc outp inp errp)
    (parameterize ([current-directory dir])
      (subprocess #f #f #f RACKET "-l" "racket-langserver")))
  (list proc outp inp))  ; (proc, stdout(READ), stdin(WRITE))

(define (disconnect! conn)
  (subprocess-kill (car conn) #t))

(define inp-of cadr)
(define out-of caddr)

;; ─── Initialize ─────────────────────────────────────────────────────────────────

(define (initialize! conn dir)
  (define inp (inp-of conn))
  (define out (out-of conn))
  (send! out (hasheq 'jsonrpc "2.0" 'id 1 'method "initialize"
                     'params (hasheq 'processId (json-null) 'rootPath dir
                                    'rootUri (path->uri dir) 'capabilities (hasheq))))
  (let wait ([n 0])
    (define ready? (sync/timeout 0.3 inp))
    (cond [ready?
           (define raw (read-line inp))
           (cond [(eof-object? raw) #f]
                 [(equal? (string-trim raw "\r") "") (read-json inp) #t]
                 [else (wait n)])]
          [(< n 20) (wait (add1 n))]
          [else #f]))
  (send! out (hasheq 'jsonrpc "2.0" 'method "initialized" 'params (hasheq)))
  (sleep 0.3))

;; ─── Commands ───────────────────────────────────────────────────────────────────

(define (cmd-doc conn file dir)
  (define inp (inp-of conn)) (define out (out-of conn))
  (define uri (path->uri file))
  (define text (with-input-from-file file port->string))
  (send! out (hasheq 'jsonrpc "2.0" 'method "textDocument/didOpen"
                     'params (hasheq 'textDocument (hasheq 'uri uri 'languageId "racket" 'version 1 'text text))))
  (sleep 0.5)
  (send! out (hasheq 'jsonrpc "2.0" 'id 10 'method "textDocument/documentSymbol"
                     'params (hasheq 'textDocument (hasheq 'uri uri))))
  (define result (recv! inp))
  (for/list ([s (in-list (hash-ref result (quote result) null))])
    (define r (hash-ref s (quote range) (hash-ref s (quote selectionRange) (hasheq))))
    (define st (hash-ref r (quote start) (hasheq)))
    (hasheq 'name (hash-ref s (quote name) "") 'line (add1 (hash-ref st (quote line) 0)))))

(define (cmd-sym conn query)
  (define inp (inp-of conn)) (define out (out-of conn))
  (send! out (hasheq 'jsonrpc "2.0" 'id 11 'method "workspace/symbol" 'params (hasheq 'query query)))
  (define result (recv! inp))
  (for/list ([s (in-list (hash-ref result (quote result) null))])
    (hasheq 'name (hash-ref s (quote name) "") 'file (uri->path (hash-ref (hash-ref s (quote location) (hash-ref s (quote loc) (hasheq))) (quote uri) ""))
            'line (add1 (hash-ref (hash-ref (hash-ref s (quote location) (hash-ref s (quote loc) (hasheq))) (quote range) (hasheq)) (quote start) (hasheq)) (quote line) 0))))

(define (cmd-def conn file dir line col)
  (define inp (inp-of conn)) (define out (out-of conn))
  (define uri (path->uri file))
  (define text (with-input-from-file file port->string))
  (send! out (hasheq 'jsonrpc "2.0" 'method "textDocument/didOpen"
                     'params (hasheq 'textDocument (hasheq 'uri uri 'languageId "racket" 'version 1 'text text))))
  (sleep 0.5)
  (send! out (hasheq 'jsonrpc "2.0" 'id 12 'method "textDocument/definition"
                     'params (hasheq 'textDocument (hasheq 'uri uri) 'position (hasheq 'line (sub1 line) 'character (sub1 col)))))
  (define result (recv! inp))
  (match (hash-ref result (quote result) null)
    [(list (hash-table loc ...)) (hasheq 'file (uri->path (hash-ref loc (quote uri) ""))
                                         'line (add1 (hash-ref (hash-ref (hash-ref loc (quote range) (hasheq)) (quote start) (hasheq)) (quote line) 0)))]
    [_ (hasheq 'file "" 'line 0)]))

;; ─── Daemon mode ────────────────────────────────────────────────────────────────

(define (run-daemon! dir)
  (define conn (connect dir))
  (initialize! conn dir)
  (fprintf (current-error-port) "[racket-daemon] ready at ~a\n" dir)
  (displayln "READY")
  (flush-output)
  (let loop ()
    (define line (read-line))
    (cond [(eof-object? line) (fprintf (current-error-port) "[racket-daemon] EOF\n")]
          [else
           (with-handlers ([exn:fail? (lambda (e) (fprintf (current-error-port) "[error] ~a\n" (exn-message e)) (displayln (format "ERR: ~a" (exn-message e))) (flush-output))])
             (define args (string-split line))
             (when (not (null? args))
               (define cmd (car args))
               (case (string->symbol cmd)
                 [(ping) (displayln "pong")]
                 [(doc)
                  (define file (if (> (length args) 1) (list-ref args 1) ""))
                  (write-json (cmd-doc conn file dir)) (newline)]
                 [(sym)
                  (define query (if (> (length args) 1) (list-ref args 1) ""))
                  (write-json (cmd-sym conn query)) (newline)]
                 [(def)
                  (define file (if (> (length args) 1) (list-ref args 1) ""))
                  (define l (if (> (length args) 2) (string->number (list-ref args 2)) 1))
                  (define c (if (> (length args) 3) (string->number (list-ref args 3)) 1))
                  (write-json (cmd-def conn file dir l c)) (newline)]
                 [else (displayln "ERR: unknown command")]))
             (flush-output))
           (loop)]))
  (disconnect! conn))

;; ─── CLI ────────────────────────────────────────────────────────────────────────

(define raw-args (vector->list (current-command-line-arguments)))
(define daemon-mode (member "DAEMONMODE" raw-args string=?))

(if daemon-mode
    (let ([dir (car (remove "DAEMONMODE" raw-args))])
      (parameterize ([current-directory dir]) (run-daemon! dir)))
    (let ([dir (list-ref raw-args 0)]
          [cmd (string->symbol (list-ref raw-args 1))])
      (case cmd
        [(ping) (displayln "pong")]
        [(doc)
         (define _file (list-ref raw-args 2))
         (define file (string-append dir "/" _file))
         (define conn (connect dir))
         (initialize! conn dir)
         (write-json (cmd-doc conn file dir)) (newline)
         (disconnect! conn)]
        [(def)
         (define _file (list-ref raw-args 2))
         (define file (string-append dir "/" _file))
         (define line (string->number (list-ref raw-args 3 "1")))
         (define col (string->number (list-ref raw-args 4 "1")))
         (define conn (connect dir))
         (initialize! conn dir)
         (write-json (cmd-def conn file dir line col)) (newline)
         (disconnect! conn)]
        [(sym)
         (define query (list-ref raw-args 2))
         (define conn (connect dir))
         (initialize! conn dir)
         (write-json (cmd-sym conn query)) (newline)
         (disconnect! conn)]
        [else (displayln "unknown command")])))
