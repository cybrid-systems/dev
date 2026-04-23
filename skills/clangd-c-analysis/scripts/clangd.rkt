#lang racket
(require racket/port json)

(define (find-char s c)
  (let ([len (string-length s)])
    (let loop ([i 0])
      (cond [(= i len) #f]
            [(char=? (string-ref s i) c) i]
            [else (loop (add1 i))]))))

(define (get-my-pid)
  (let* ([p (process "echo $PPID")]
         [out (car p)]
         [inp (cadr p)])
    (close-output-port inp)
    (string->number (string-trim (read-line out)))))

(define (read-headers in-port)
  (let loop ([headers (make-hash)])
    (let ([line (read-line in-port 'return-linefeed)])
      (if (or (eof-object? line) (equal? (string-trim line) ""))
          headers
          (let* ([colon-pos (find-char line #\:)]
                 [key (string-trim (substring line 0 colon-pos))]
                 [val (string-trim (substring line (add1 colon-pos)))])
            (hash-set! headers key val)
            (loop headers))))))

(define (read-json-message in-port)
  (let* ([headers (read-headers in-port)]
         [cl (string->number (hash-ref headers "Content-Length" "0"))])
    (when (> cl 0)
      (let ([body-bs (read-bytes cl in-port)])
        (with-input-from-string (bytes->string/utf-8 body-bs) read-json)))))

(define (write-json-message out-port jsexpr)
  (define body (jsexpr->string jsexpr))
  (define bytes (string->bytes/utf-8 body))
  (define header (string-append "Content-Length: " (number->string (bytes-length bytes)) "\r\n\r\n"))
  (write-bytes (bytes-append (string->bytes/utf-8 header) bytes) out-port)
  (flush-output out-port))

(define (write-json-notification out-port method params)
  (write-json-message out-port (hasheq 'jsonrpc "2.0" 'method method 'params params))
  (flush-output out-port))

(define (lsp-request! out-port id method params)
  (write-json-message out-port (hasheq 'jsonrpc "2.0" 'id id 'method method 'params params)))

(define pending-responses (make-hash))

(define (start-reader out-port)
  (thread
   (lambda ()
     (let loop ()
       (with-handlers ([exn:fail? (lambda (e) (fprintf (current-error-port) "[reader] ~a\n" (exn-message e)) (loop))])
         (define msg (read-json-message out-port))
         (when msg
           (let ([rid (hash-ref msg 'id #f)])
             (cond
               [rid
                (let ([ch (hash-ref pending-responses rid #f)])
                  (when ch (channel-put ch msg) (hash-remove! pending-responses rid)))]
               [else (void)])))
         (loop))))))

(define (send-request inp id method params)
  (define resp-chan (make-channel))
  (hash-set! pending-responses id resp-chan)
  (lsp-request! inp id method params)
  (define resp (sync/timeout 20 resp-chan))
  (cond
    [(not resp) (error 'clangd "timeout id=~a" id)]
    [(hash-has-key? resp 'error) (error 'clangd "~a" (hash-ref resp 'error))]
    [(hash-has-key? resp 'result) (hash-ref resp 'result)]
    [else resp]))

(define (connect root-path)
  (define clangd-path (find-executable-path "clangd"))
  (unless clangd-path (error 'clangd "clangd not found in PATH"))
  (define proc-result (process* clangd-path "--compile-commands-dir" root-path))
  (define clangd-out (list-ref proc-result 0))
  (define clangd-in  (list-ref proc-result 1))
  (define clangd-ctrl (list-ref proc-result 4))
  (list clangd-out clangd-in clangd-ctrl))

(define (disconnect! clangd)
  ((caddr clangd) 'kill)
  (close-input-port (car clangd))
  (close-output-port (cadr clangd)))

(define (initialize! clangd root-path)
  (define inp (cadr clangd))
  (start-reader (car clangd))
  (send-request inp 1 "initialize"
    (hasheq 'processId (get-my-pid)
            'rootUri (string-append "file://" root-path)
            'capabilities (hasheq)))
  (write-json-notification inp "initialized" (hasheq)))

(define (open-document! inp file-path base-dir)
  (define abs-path (if (string-prefix? file-path "/")
                      file-path
                      (path->string (build-path base-dir (string->path file-path)))))
  (define uri (string-append "file://" abs-path))
  (define text (with-handlers ([exn? (lambda (_) "")]) (file->string file-path)))
  (write-json-notification inp "textDocument/didOpen"
    (hasheq 'textDocument (hasheq 'uri uri 'languageId "c" 'text text))))

(define opened-documents (make-hash)) ; uri → #t (cached so we don't re-send didOpen)


(define (resolve-path* file base-dir)
  (if (string-prefix? file "/") file (path->string (build-path base-dir (string->path file)))))
(define (ensure-document! inp file line col base-dir)
  (define abs-file (resolve-path* file base-dir))
  (define uri (string-append "file://" abs-file))
  (unless (hash-has-key? opened-documents uri)
    (define text (with-handlers ((exn? (lambda (_) ""))) (file->string file)))
    (write-json-notification inp "textDocument/didOpen"
      (hasheq 'textDocument (hasheq 'uri uri 'languageId "c" 'text text)))
    (hash-set! opened-documents uri #t)
    (sleep 0.3)) ; give clangd time to parse the file
  (void))

(define (parse-location loc)
  (and (hash? loc)
    (let* ([rng (hash-ref loc 'range)]
           [start (hash-ref rng 'start)]
           [file-uri (hash-ref loc 'uri)]
           [path (if (string-prefix? file-uri "file://") (substring file-uri 7) file-uri)])
      (hasheq 'file path 'line (add1 (hash-ref start 'line))))))

(define (goto-definition! inp file line col base-dir)
  (when (or (zero? (string-length file)) (not file))
    (error 'clangd "file cannot be empty"))
  (define abs-file (resolve-path* file base-dir))
  (define uri (string-append "file://" abs-file))
  (define result (send-request inp 2 "textDocument/definition"
    (hasheq 'textDocument (hasheq 'uri uri)
            'position (hasheq 'line line 'character col))))
  (cond
    [(list? result) (or (and (not (null? result)) (parse-location (car result))) (hasheq 'file "" 'line 0))]
    [(hash? result) (or (parse-location result) (hasheq 'file "" 'line 0))]
    [else (hasheq 'file "" 'line 0)]))

(define (find-references! inp file line col base-dir)
  (when (or (zero? (string-length file)) (not file))
    (error 'clangd "file cannot be empty"))
  (define abs-file (resolve-path* file base-dir))
  (define uri (string-append "file://" abs-file))
  (define result (send-request inp 3 "textDocument/references"
    (hasheq 'textDocument (hasheq 'uri uri)
            'position (hasheq 'line line 'character col)
            'context (hasheq 'includeDeclaration #t))))
  (filter-map parse-location (or result '())))

(define (workspace-symbol! inp query)
  (define items (or (send-request inp 4 "workspace/symbol" (hasheq 'query query)) '()))
  (for/list ([item (in-list items)])
    (define loc (hash-ref item 'location))
    (define rng (hash-ref loc 'range))
    (define start (hash-ref rng 'start))
    (define uri (hash-ref loc 'uri))
    (define path (if (string-prefix? uri "file://") (substring uri 7) uri))
    (hasheq 'name (hash-ref item 'name) 'file path 'line (add1 (hash-ref start 'line)))))

(define (document-symbols! inp file base-dir)
  (when (or (zero? (string-length file)) (not file))
    (error 'clangd "file cannot be empty"))
  (define abs-file (resolve-path* file base-dir))
  (define uri (string-append "file://" abs-file))
  (define items (or (send-request inp 5 "textDocument/documentSymbol"
    (hasheq 'textDocument (hasheq 'uri uri))) '()))
  (define (parse-item item)
    (cond
      ((hash-has-key? item 'selectionRange)
       (define sel-range (hash-ref item 'selectionRange))
       (define start (hash-ref sel-range 'start))
       (define rng (hash-ref item 'range))
       (define rng-start (hash-ref rng 'start))
       (define name (hash-ref item 'name))
       (define kind (hash-ref item 'kind))
       (hasheq 'name name 'kind kind 'file abs-file 'line (add1 (hash-ref start 'line))
               'detail (hash-ref item 'detail #f) 'containerLine (add1 (hash-ref rng-start 'line))))
      ((hash-has-key? item 'location)
       (define loc (hash-ref item 'location))
       (define rng (hash-ref loc 'range))
       (define start (hash-ref rng 'start))
       (define name (hash-ref item 'name))
       (define kind (hash-ref item 'kind))
       (define loc-uri (hash-ref loc 'uri))
       (define path (if (string-prefix? loc-uri "file://") (substring loc-uri 7) loc-uri))
       (hasheq 'name name 'kind kind 'file path 'line (add1 (hash-ref start 'line))
               'detail (hash-ref item 'detail #f) 'containerName (hash-ref item 'containerName #f)))
      (else (hasheq 'name "?" 'kind 0 'file abs-file 'line 0))))
  (map parse-item items))

(define (hover! inp file line col base-dir)
  (when (or (zero? (string-length file)) (not file))
    (error 'clangd "file cannot be empty"))
  (define abs-file (resolve-path* file base-dir))
  (define uri (string-append "file://" abs-file))
  (define result (send-request inp 6 "textDocument/hover"
    (hasheq 'textDocument (hasheq 'uri uri)
            'position (hasheq 'line line 'character col))))
  (cond
    [(eq? result 'null) #f]
    [(hash? result) (hash-ref result 'contents #f)]
    [else #f]))

;; ─── Daemon ────────────────────────────────────────────────────────────────────
(define (handle-command! clangd args base-dir)
  (define inp (cadr clangd))
  (define cmd-str (if (null? args) "help" (car args)))
  (define cmd-args (if (null? (cdr args)) '() (cdr args)))
  (define cmd (string->symbol cmd-str))
  (case cmd
    ((def)
     (define file (if (< 0 (length cmd-args)) (car cmd-args) ""))
     (define line (if (< 1 (length cmd-args)) (string->number (cadr cmd-args)) 0))
     (define col (if (< 2 (length cmd-args)) (string->number (caddr cmd-args)) 0))
     (when (> (string-length file) 0)
       (ensure-document! inp file line col base-dir))
     (define result (goto-definition! inp file line col base-dir))
     (displayln (jsexpr->string result)))
    ((refs)
     (define file (if (< 0 (length cmd-args)) (car cmd-args) ""))
     (define line (if (< 1 (length cmd-args)) (string->number (cadr cmd-args)) 0))
     (define col (if (< 2 (length cmd-args)) (string->number (caddr cmd-args)) 0))
     (when (> (string-length file) 0)
       (ensure-document! inp file line col base-dir))
     (define results (find-references! inp file line col base-dir))
     (displayln (jsexpr->string results)))
    ((sym)
     (define query (if (< 0 (length cmd-args)) (car cmd-args) ""))
     (define src-file (if (< 1 (length cmd-args)) (cadr cmd-args) ""))
     (when (> (string-length src-file) 0)
       (ensure-document! inp src-file 0 0 base-dir))
     (define results (workspace-symbol! inp query))
     (displayln (jsexpr->string results)))
    ((doc)
     (define file (if (< 0 (length cmd-args)) (car cmd-args) ""))
     (when (> (string-length file) 0)
       (ensure-document! inp file 0 0 base-dir))
     (define results (document-symbols! inp file base-dir))
     (displayln (jsexpr->string results)))
    ((hover)
     (define file (if (< 0 (length cmd-args)) (car cmd-args) ""))
     (define line (if (< 1 (length cmd-args)) (string->number (cadr cmd-args)) 0))
     (define col (if (< 2 (length cmd-args)) (string->number (caddr cmd-args)) 0))
     (when (> (string-length file) 0)
       (ensure-document! inp file line col base-dir))
     (define result (hover! inp file line col base-dir))
     (displayln (or result "")))
    ((ping) (displayln "pong"))
    ((quit) (displayln "bye") (exit 0))
    ((help) (displayln "Commands: def|refs|sym|doc|hover|ping|quit"))
    (else (displayln (format "unknown: ~a" cmd)))))

(define (run-daemon! dir)
  (define clangd (connect dir))
  (initialize! clangd dir)
  (fprintf (current-error-port) "[daemon] ready at ~a\n" dir)
  (fprintf (current-output-port) "READY\n")
  (flush-output (current-error-port))
  (flush-output (current-output-port))
  (let loop ()
    (define line (read-line))
    (cond
      ((eof-object? line) (fprintf (current-error-port) "[daemon] EOF\n"))
      (else
       (with-handlers ((exn:fail? (lambda (e) (fprintf (current-error-port) "[error] ~a\n" (exn-message e)))))
         (define args (string-split line))
         (when (not (null? args))
           (handle-command! clangd args dir)))
       (loop))))
  (disconnect! clangd))

;; ─── CLI ───────────────────────────────────────────────────────────────────────
(define (main)
  (define raw-args (vector->list (current-command-line-arguments)))
  (define daemon-requested (member "DAEMONMODE" raw-args))
  (define opts (make-hash))
  (define positional '())
  (define args-to-parse (if daemon-requested (remq 'DAEMONMODE raw-args) raw-args))
  (let loop ((args args-to-parse))
    (cond
      ((null? args) (set! positional (reverse positional)))
      ((string=? (car args) "-d")
       (hash-set! opts 'dir (cadr args))
       (loop (cddr args)))
      ((string-prefix? (car args) "-")
       (hash-set! opts (string->symbol (car args)) #t)
       (loop (cdr args)))
      (else (set! positional (cons (car args) positional)) (loop (cdr args)))))

  (define dir (or (hash-ref opts 'dir #f) (path->string (current-directory))))
  (define raw-cmd (if (null? positional) 'help (string->symbol (car positional))))
  (define args (if (null? (cdr positional)) '() (cdr positional)))

  (when daemon-requested
    (run-daemon! dir)
    (exit 0))

  (define clangd (connect dir))
  (initialize! clangd dir)

  (case raw-cmd
    ((def)
     (define file (if (< 0 (length args)) (car args) ""))
     (define line (if (< 1 (length args)) (string->number (cadr args)) 0))
     (define col (if (< 2 (length args)) (string->number (caddr args)) 0))
     (when (> (string-length file) 0)
       (ensure-document! (cadr clangd) file line col dir))
     (define result (goto-definition! (cadr clangd) file line col dir))
     (displayln (jsexpr->string result)))
    ((refs)
     (define file (if (< 0 (length args)) (car args) ""))
     (define line (if (< 1 (length args)) (string->number (cadr args)) 0))
     (define col (if (< 2 (length args)) (string->number (caddr args)) 0))
     (when (> (string-length file) 0)
       (ensure-document! (cadr clangd) file line col dir))
     (define results (find-references! (cadr clangd) file line col dir))
     (displayln (jsexpr->string results)))
    ((sym)
     (define query (if (< 0 (length args)) (car args) ""))
     (define src-file (if (< 1 (length args)) (cadr args) ""))
     (when (> (string-length src-file) 0)
       (ensure-document! (cadr clangd) src-file 0 0 dir))
     (unless (> (string-length src-file) 0)
       (when (file-exists? (build-path dir "src/anet.c"))
         (ensure-document! (cadr clangd) "src/anet.c" 0 0 dir)))
     (define results (workspace-symbol! (cadr clangd) query))
     (displayln (jsexpr->string results)))
    ((doc)
     (define file (if (< 0 (length args)) (car args) ""))
     (when (> (string-length file) 0)
       (ensure-document! (cadr clangd) file 0 0 dir))
     (define results (document-symbols! (cadr clangd) file dir))
     (displayln (jsexpr->string results)))
    ((hover)
     (define file (if (< 0 (length args)) (car args) ""))
     (define line (if (< 1 (length args)) (string->number (cadr args)) 0))
     (define col (if (< 2 (length args)) (string->number (caddr args)) 0))
     (when (> (string-length file) 0)
       (ensure-document! (cadr clangd) file line col dir))
     (define result (hover! (cadr clangd) file line col dir))
     (displayln (or result "")))
    ((ping) (displayln "pong"))
    ((help)
     (printf "clangd-c-analysis - C/C++ code analysis via clangd LSP\n\n")
     (printf "Usage:\n")
     (printf "  racket clangd.rkt [-d <dir>] <command> [args]\n")
     (printf "  ./clangd-daemon.sh <dir>  (daemon mode)\n\n")
     (printf "Commands: def|refs|sym|doc|hover|ping|help\n"))
    (else
     (printf "Unknown command: ~a\n" raw-cmd)
     (printf "Run 'racket clangd.rkt help'\n")))
  (disconnect! clangd))

(module+ main
  (main))