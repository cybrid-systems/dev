#lang racket
(require racket/port
         racket/string
         racket/function
         json)

;; ─── URI helpers ────────────────────────────────────────────────────────────────

(define (uri-encode str)
  "Percent-encode per RFC 3986 for file URIs. Encodes anything except unreserved chars."
  (define (hex-byte b)
    (string->bytes/utf-8 (string-append "%" (string-upcase (~r b #:base 16 #:min-width 2 #:pad-string "0")))))
  (define (unreserved? b)
    (or (and (>= b 65) (<= b 90))   ; A-Z
        (and (>= b 97) (<= b 122))  ; a-z
        (and (>= b 48) (<= b 57))   ; 0-9
        (memv b (list (char->integer #\-) (char->integer #\_)
                  (char->integer #\.) (char->integer #\~)
                  (char->integer #\/) (char->integer #\:))))) ; allowed in file URI path
  (bytes->string/utf-8
   (apply bytes-append
          (for/list ([b (in-bytes (string->bytes/utf-8 str))])
            (if (unreserved? b)
                (bytes b)
                (hex-byte b))))))

(define (path->uri path)
  (string-append "file://" (uri-encode (path->string path))))

(define (uri-decode uri-path)
  "Percent-decode a file URI path back to filesystem path."
  (define (hex-val b)
    (cond [(char<=? #\0 (integer->char b) #\9) (- b 48)]
          [(char<=? #\a (integer->char b) #\f) (- b 87)]
          [(char<=? #\A (integer->char b) #\F) (- b 55)]
          [else 0]))
  (bytes->string/utf-8
   (let loop ([bs (string->bytes/utf-8 uri-path)] [i 0] [acc '()])
     (cond
       [(>= i (bytes-length bs)) (list->bytes (reverse acc))]
       [(and (char=? (integer->char (bytes-ref bs i)) #\%)
             (< (+ i 2) (bytes-length bs)))
        (define hi (bytes-ref bs (add1 i)))
        (define lo (bytes-ref bs (+ i 2)))
        (define val (+ (* (hex-val hi) 16) (hex-val lo)))
        (loop bs (+ i 3) (cons val acc))]
       [else (loop bs (add1 i) (cons (bytes-ref bs i) acc))]))))

;; ─── Language ID detection ──────────────────────────────────────────────────────

(define (language-id file-path)
  (define ext (filename-extension file-path))
  (match ext
    ["c"    "c"]
    ["cpp"  "cpp"]
    ["cc"   "cpp"]
    ["cxx"  "cpp"]
    ["c++"  "cpp"]
    ["h"    "c"]
    ["hpp"  "cpp"]
    ["hxx"  "cpp"]
    ["hh"   "cpp"]
    ["h++"  "cpp"]
    ["cu"   "cuda"]
    ["cuh"  "cuda"]
    ["m"    "objective-c"]
    ["mm"   "objective-c"]
    [_      "c"]))

;; ─── Header / JSON IPC ──────────────────────────────────────────────────────────

(define (find-char s c)
  (let ([len (string-length s)])
    (let loop ([i 0])
      (cond [(= i len) #f]
            [(char=? (string-ref s i) c) i]
            [else (loop (add1 i))]))))

(define (read-headers in-port)
  (let loop ([headers (make-hash)])
    (let ([line (read-line in-port 'return-linefeed)])
      (if (or (eof-object? line) (equal? (string-trim line) ""))
          headers
          (let ([colon-pos (find-char line #\:)])
            (if colon-pos
                (let* ([key (string-trim (substring line 0 colon-pos))]
                       [val (string-trim (substring line (add1 colon-pos)))])
                  (hash-set! headers key val)
                  (loop headers))
                (loop headers)))))))

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

;; ─── Request / response ─────────────────────────────────────────────────────────

(define pending-responses (make-hash))           ; id → channel
(define pending-lock (make-semaphore 1))        ; thread safety for pending-responses
(define reader-stop-channel (make-channel))      ; sentinel to stop reader thread

(define (start-reader out-port)
  (thread
   (lambda ()
     (let loop ()
       ;; Check for stop signal before each iteration
       (define stop? (sync/timeout 0 reader-stop-channel))
       (when stop?
         (void))  ; exit gracefully
       (with-handlers ([exn:fail? (lambda (e)
                                    (fprintf (current-error-port) "[reader] ~a\n" (exn-message e))
                                    ;; brief sleep to avoid busy-loop on persistent errors
                                    (sleep 0.05))])
         (define msg (read-json-message out-port))
         (cond
           [(and (hash? msg) (hash-ref msg 'id #f))
            => (lambda (rid)
                 (call-with-semaphore pending-lock
                   (lambda ()
                     (define ch (hash-ref pending-responses rid #f))
                     (when ch
                       (hash-remove! pending-responses rid)
                       (channel-put ch msg)))))])
         (loop))))))

(define (stop-reader!)
  (channel-put reader-stop-channel 'stop))

(define REQUEST-TIMEOUT-SEC 20)

(define (send-request inp id method params)
  (define resp-chan (make-channel))
  (call-with-semaphore pending-lock
    (lambda () (hash-set! pending-responses id resp-chan)))
  (lsp-request! inp id method params)
  (define resp (sync/timeout REQUEST-TIMEOUT-SEC resp-chan))
  ;; Always clean up the channel regardless of outcome (fix #5)
  (call-with-semaphore pending-lock
    (lambda () (hash-remove! pending-responses id)))
  (cond
    [(not resp) (error 'clangd "timeout id=~a after ~a s" id REQUEST-TIMEOUT-SEC)]
    [(hash-has-key? resp 'error) (error 'clangd "~a" (hash-ref resp 'error))]
    [(hash-has-key? resp 'result) (hash-ref resp 'result)]
    [else resp]))

(define (lsp-request! out-port id method params)
  (write-json-message out-port (hasheq 'jsonrpc "2.0" 'id id 'method method 'params params)))

;; ─── Connection lifecycle ───────────────────────────────────────────────────────

(define (connect root-path)
  (define clangd-path (find-executable-path "clangd"))
  (unless clangd-path (error 'clangd "clangd not found in PATH"))
  ;; Use --background-index for background indexing and performance tuning flags
  (define proc-result (process* clangd-path
                       "--compile-commands-dir" root-path
                       "--background-index"
                       "--header-insertion=never"
                       "--clang-tidy=false"))
  (define clangd-stdout (list-ref proc-result 0))
  (define clangd-stdin  (list-ref proc-result 1))
  (define clangd-ctrl   (list-ref proc-result 4))
  (list clangd-stdout clangd-stdin clangd-ctrl))

(define (disconnect! clangd)
  (stop-reader!)
  ((caddr clangd) 'kill)
  (close-input-port (car clangd))
  (close-output-port (cadr clangd)))

;; ─── Initialize ─────────────────────────────────────────────────────────────────

(define (initialize! clangd root-path)
  (define inp (cadr clangd))
  (start-reader (car clangd))
  (send-request inp 1 "initialize"
    (hasheq 'processId #f    ; null for non-editor clients
            'rootUri (path->uri (string->path root-path))
            'capabilities (hasheq)))
  (write-json-notification inp "initialized" (hasheq)))

;; ─── Document management ────────────────────────────────────────────────────────

(define opened-documents (make-hash))  ; uri → timestamp (order for LRU eviction)
(define opened-order '())              ; list of uri, most-recently-used first

;; Delay after didOpen for clangd to parse (seconds). Configurable via parameter.
(define OPEN_DOCUMENT_DELAY (make-parameter 0.1))

;; Max open documents before LRU eviction prevents unbounded memory growth.
(define MAX_OPEN_DOCUMENTS (make-parameter 500))

(define (resolve-path* file base-dir)
  (if (string-prefix? file "/")
      file
      (path->string
       (build-path (simplify-path (string->path base-dir)) (string->path file)))))

(define (document-close! inp uri)
  (write-json-notification inp "textDocument/didClose"
    (hasheq 'textDocument (hasheq 'uri uri)))
  (hash-remove! opened-documents uri)
  (set! opened-order (remove uri opened-order equal?)))

(define (document-touch! uri)
  ;; Move uri to front of opened-order
  (set! opened-order (cons uri (remove uri opened-order equal?))))

(define (enforce-document-limit! inp)
  (let ([limit (MAX_OPEN_DOCUMENTS)])
    (when (and (> limit 0) (> (hash-count opened-documents) limit))
      ;; Close LRU (last element in opened-order)
      (define lru (last opened-order))
      (document-close! inp lru))))

(define (ensure-document! inp file base-dir)
  (define abs-file (resolve-path* file base-dir))
  (define uri (path->uri (string->path abs-file)))
  (unless (hash-has-key? opened-documents uri)
    (define text (with-handlers ([exn? (lambda (_) "")])
                   (file->string abs-file)))
    (write-json-notification inp "textDocument/didOpen"
      (hasheq 'textDocument
              (hasheq 'uri uri
                      'languageId (language-id abs-file)
                      'text text)))
    (hash-set! opened-documents uri (current-inexact-milliseconds))
    (document-touch! uri)
    (enforce-document-limit! inp)
    ;; TODO: ideally wait for textDocument/publishDiagnostics instead of a fixed sleep
    (sleep (OPEN_DOCUMENT_DELAY)))
  ;; Even if already open, touch it so LRU reflects recent use
  (document-touch! uri)
  (void))

;; ─── LSP operations ─────────────────────────────────────────────────────────────

(define (parse-location loc)
  (and (hash? loc)
       (let* ([rng (hash-ref loc 'range)]
              [start (hash-ref rng 'start)]
              [file-uri (hash-ref loc 'uri)]
              [path (if (string-prefix? file-uri "file://")
                        (uri-decode (substring file-uri 7))
                        file-uri)])
         (hasheq 'file path 'line (add1 (hash-ref start 'line))))))

(define (goto-definition! inp file line col base-dir)
  (define abs-file (resolve-path* file base-dir))
  (define uri (path->uri (string->path abs-file)))
  (define result (send-request inp 2 "textDocument/definition"
    (hasheq 'textDocument (hasheq 'uri uri)
            'position (hasheq 'line line 'character col))))
  (cond
    [(list? result) (or (and (not (null? result)) (parse-location (car result)))
                        (hasheq 'file "" 'line 0))]
    [(hash? result) (or (parse-location result) (hasheq 'file "" 'line 0))]
    [else (hasheq 'file "" 'line 0)]))

(define (find-references! inp file line col base-dir)
  (define abs-file (resolve-path* file base-dir))
  (define uri (path->uri (string->path abs-file)))
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
    (define path (if (string-prefix? uri "file://") (uri-decode (substring uri 7)) uri))
    (hasheq 'name (hash-ref item 'name) 'file path 'line (add1 (hash-ref start 'line)))))

(define (document-symbols! inp file base-dir)
  (define abs-file (resolve-path* file base-dir))
  (define uri (path->uri (string->path abs-file)))
  (define items (or (send-request inp 5 "textDocument/documentSymbol"
    (hasheq 'textDocument (hasheq 'uri uri))) '()))
  (define (parse-item item)
    (cond
      [(hash-has-key? item 'selectionRange)
       (define sel-range (hash-ref item 'selectionRange))
       (define start (hash-ref sel-range 'start))
       (define rng (hash-ref item 'range))
       (define rng-start (hash-ref rng 'start))
       (define name (hash-ref item 'name))
       (define kind (hash-ref item 'kind))
       (hasheq 'name name 'kind kind 'file abs-file
               'line (add1 (hash-ref start 'line))
               'detail (hash-ref item 'detail #f)
               'containerLine (add1 (hash-ref rng-start 'line)))]
      [(hash-has-key? item 'location)
       (define loc (hash-ref item 'location))
       (define rng (hash-ref loc 'range))
       (define start (hash-ref rng 'start))
       (define name (hash-ref item 'name))
       (define kind (hash-ref item 'kind))
       (define loc-uri (hash-ref loc 'uri))
       (define path (if (string-prefix? loc-uri "file://") (uri-decode (substring loc-uri 7)) loc-uri))
       (hasheq 'name name 'kind kind 'file path
               'line (add1 (hash-ref start 'line))
               'detail (hash-ref item 'detail #f)
               'containerName (hash-ref item 'containerName #f))]
      (else (hasheq 'name "?" 'kind 0 'file abs-file 'line 0))))
  (map parse-item items))

;; ─── Command dispatch (shared by CLI and daemon) ────────────────────────────────

(define (parse-def-args args)
  (values
   (if (< 0 (length args)) (car args) "")
   (if (< 1 (length args)) (string->number (cadr args)) 0)
   (if (< 2 (length args)) (string->number (caddr args)) 0)))

(define (dispatch-command! inp cmd args base-dir)
  (match cmd
    ['def
      (define-values (file line col) (parse-def-args args))
      (when (> (string-length file) 0)
        (ensure-document! inp file base-dir))
      (jsexpr->string (goto-definition! inp file line col base-dir))]
    ['refs
      (define-values (file line col) (parse-def-args args))
      (when (> (string-length file) 0)
        (ensure-document! inp file base-dir))
      (jsexpr->string (find-references! inp file line col base-dir))]
    ['sym
      (define query (if (< 0 (length args)) (car args) ""))
      (define src-file (if (< 1 (length args)) (cadr args) ""))
      (cond
        [(> (string-length src-file) 0)
         ;; File-specific: ensure it's open, then search workspace
         (ensure-document! inp src-file base-dir)
         (define results (workspace-symbol! inp query))
         (if (null? results)
             ;; Fallback: search this file's symbols directly
             (jsexpr->string (document-symbols! inp src-file base-dir))
             (jsexpr->string results))]
        [else
         ;; Workspace-wide: try workspace/symbol first
         (define results (workspace-symbol! inp query))
         (if (null? results)
             ;; Fallback: search all opened documents for matching symbols
             (let ([match (lambda (sym)
                            (and (hash? sym)
                                 (let ([n (hash-ref sym 'name "")])
                                   (and (>= (string-length n) (string-length query))
                                        (not (not (regexp-match (string-append "(?i:" (regexp-quote query) ")") n)))))))]
                   [all '()])
               (for ([(uri _) (in-hash opened-documents)])
                 (define abs-path (uri-decode (substring uri 7)))
                 (define entries (with-handlers ([exn? (lambda _ '())])
                                   (document-symbols! inp abs-path base-dir)))
                 (set! all (append all (filter match entries))))
               (jsexpr->string all))
             (jsexpr->string results))])]
    ['doc
      (define file (if (< 0 (length args)) (car args) ""))
      (when (> (string-length file) 0)
        (ensure-document! inp file base-dir))
      (jsexpr->string (document-symbols! inp file base-dir))]
    ['close
      ;; Close all open documents (useful before quitting or to reset state)
      (for ([(uri _) (in-hash opened-documents)])
        (document-close! inp uri))
      "ok"]
    ['doc-limit
      ;; Set max open documents at runtime
      (when (pair? args)
        (MAX_OPEN_DOCUMENTS (string->number (car args))))
      (format "~a" (MAX_OPEN_DOCUMENTS))]
    ['doc-delay
      ;; Set open document delay at runtime (seconds)
      (when (pair? args)
        (OPEN_DOCUMENT_DELAY (string->number (car args))))
      (format "~a" (OPEN_DOCUMENT_DELAY))]
    ['ping "pong"]
    ['help "Commands: def|refs|sym|doc|close|doc-limit|doc-delay|ping|quit"]
    [else (format "unknown: ~a" cmd)]))

;; ─── Daemon mode ────────────────────────────────────────────────────────────────

(define (handle-command! clangd args base-dir)
  (define inp (cadr clangd))
  (define cmd-str (if (null? args) "help" (car args)))
  (define cmd (string->symbol cmd-str))
  (define cmd-args (if (null? (cdr args)) '() (cdr args)))
  (define result (dispatch-command! inp cmd cmd-args base-dir))
  (displayln result)
  (flush-output)  ; flush each response since stdout may be pipe-buffered
  (when (eq? cmd 'quit)
    (disconnect! clangd)
    (exit 0)))

;; Warm up clangd by opening a project file to kick-start background indexing.
;; After this, workspace/symbol will return results immediately.
(define (warmup-index! inp dir)
  ;; Open key source files to jump-start clangd index.
  ;; Multiple files ensures more symbols are available for workspace/symbol.
  (define candidates
    (list "src/server.c" "src/main.c" "src/sds.c"
          "src/ae.c" "src/networking.c" "src/db.c"
          "redis.c" "main.c" "server.c" "app.js" "app.py"))
  (define (open* files)
    (for ([f (in-list files)])
      (define p (build-path dir f))
      (when (file-exists? p)
        (ensure-document! inp f dir)
        (fprintf (current-error-port) "[warmup] opened ~a\n" f))))
  ;; Try specific candidates first
  (open* candidates)
  ;; Auto-discover up to 3 .c/.h files under src/ or project root
  (define (find-and-open roots [limit 3])
    (let ([count 0])
      (for ([root (in-list roots)])
        (when (directory-exists? root)
          (for ([e (in-list (directory-list root))])
            (when (< count limit)
              (define name (path->string e))
              (when (or (string-suffix? name ".c") (string-suffix? name ".h")
                        (string-suffix? name ".cpp") (string-suffix? name ".hpp"))
                (define rel (if (equal? root dir) name
                                (path->string (build-path (path->string (last (explode-path root))) e))))
                (unless (hash-has-key? opened-documents (path->uri (string->path (resolve-path* rel dir))))
                  (ensure-document! inp rel dir)
                  (fprintf (current-error-port) "[warmup] opened ~a\n" rel)
                  (set! count (add1 count))))))))))
  (find-and-open (list dir (build-path dir "src") (build-path dir "app") (build-path dir "lib"))))

(define (run-daemon! dir)
  (define clangd (connect dir))
  (define inp (cadr clangd))
  (initialize! clangd dir)
  ;; Warm up: open a project file so workspace/symbol works immediately
  (warmup-index! inp dir)
  (fprintf (current-error-port) "[daemon] ready at ~a\n" dir)
  (fprintf (current-output-port) "READY\n")
  (flush-output (current-error-port))
  (flush-output (current-output-port))
  (let loop ()
    (define line (read-line))
    (cond
      ((eof-object? line)
       (fprintf (current-error-port) "[daemon] EOF\n"))
      (else
       (with-handlers ([exn:fail? (lambda (e)
                                    (fprintf (current-error-port) "[error] ~a\n" (exn-message e))
                                    (displayln (format "ERR: ~a" (exn-message e)))
                                    (flush-output))])
         (define args (string-split line))
         (when (not (null? args))
           (handle-command! clangd args dir)))
       (loop))))
  (disconnect! clangd))

;; ─── CLI (single-shot) ─────────────────────────────────────────────────────────

(define (main)
  (define raw-args (vector->list (current-command-line-arguments)))
  (define daemon-requested (member "DAEMONMODE" raw-args string=?))
  (define opts (make-hash))
  (define positional '())
  (define args-to-parse (if daemon-requested (remove "DAEMONMODE" raw-args string=?) raw-args))
  (let loop ([args args-to-parse])
    (cond
      [(null? args) (set! positional (reverse positional))]
      [(string=? (car args) "-d")
       (hash-set! opts 'dir (cadr args))
       (loop (cddr args))]
      [(string-prefix? (car args) "-")
       (hash-set! opts (string->symbol (car args)) #t)
       (loop (cdr args))]
      [else (set! positional (cons (car args) positional)) (loop (cdr args))]))

  (define dir (path->string (simplify-path (string->path (or (hash-ref opts 'dir #f) (path->string (current-directory)))))))
  (define cmd (if (null? positional) 'help (string->symbol (car positional))))
  (define cmd-args (if (or (null? positional) (null? (cdr positional))) '() (cdr positional)))

  (when daemon-requested
    (run-daemon! dir)
    (exit 0))

  (define clangd (connect dir))
  (initialize! clangd dir)
  (define result (dispatch-command! (cadr clangd) cmd cmd-args dir))
  (displayln result)
  (disconnect! clangd))

(module+ main
  (main))
