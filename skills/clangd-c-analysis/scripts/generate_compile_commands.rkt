#lang racket

;; generate_compile_commands.rkt
;; Auto-detects build system and generates compile_commands.json for clangd

(require racket/system racket/file racket/string)

;; ─── Detect build system ────────────────────────────────────────────────────────

(define (detect-build-system root)
  (cond
    [(file-exists? (build-path root "CMakeLists.txt")) 'cmake]
    [(file-exists? (build-path root "Makefile")) 'make]
    [(file-exists? (build-path root "makefile")) 'make]
    [(file-exists? (build-path root "build.ninja")) 'ninja]
    [else 'unknown]))

;; ─── Run command ────────────────────────────────────────────────────────────────

(define (run-cmd cmd dir)
  (define p (process* "/bin/sh" "-c" (format "~a 2>&1" cmd)))
  (define out (car p))
  (define inp (cadr p))
  (close-output-port inp)
  (define lines '())
  (let loop ()
    (define ln (read-line out))
    (if (eof-object? ln)
        (begin (close-input-port out) lines)
        (begin (set! lines (cons ln lines)) (loop)))))

;; ─── CMake path ────────────────────────────────────────────────────────────────

(define (generate-cmake root)
  (define build-dir (build-path root "build"))
  (make-directory* build-dir)
  (define ninja-bin (file-exists? "/usr/bin/ninja"))
  (define gen (if ninja-bin "Ninja" "Unix Makefiles"))
  (define cmake-cmd
    (format "cmake -S ~a -B ~a -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -G ~a"
            root build-dir gen))
  (printf "[cmake] ~a\n" cmake-cmd)
  (define out (run-cmd cmake-cmd root))
  (for ([ln (in-list out)]) (displayln ln))
  (when ninja-bin
    (define ninja-cmd (format "ninja -C ~a -j4" build-dir))
    (printf "[ninja] ~a\n" ninja-cmd)
    (define out2 (run-cmd ninja-cmd root))
    (for ([ln (in-list out2)]) (displayln ln)))
  (define cc-file (build-path build-dir "compile_commands.json"))
  (define dest-cc (build-path root "compile_commands.json"))
  (cond
    [(file-exists? cc-file)
     (copy-file cc-file dest-cc #t)
     (printf "[OK] compile_commands.json → ~a\n" dest-cc)
     #t]
    [else
     (printf "[ERROR] compile_commands.json not found in ~a\n" build-dir)
     #f]))

;; ─── Make / Bear path ─────────────────────────────────────────────────────────

(define (generate-make root)
  (define bear-cmd (format "bear -- make -C ~a -j4" root))
  (printf "[bear] ~a\n" bear-cmd)
  (define out (run-cmd bear-cmd root))
  (for ([ln (in-list out)]) (displayln ln))
  (define cc (build-path root "compile_commands.json"))
  (cond
    [(file-exists? cc)
     (printf "[OK] compile_commands.json → ~a\n" cc)
     #t]
    [else
     (printf "[ERROR] bear failed to produce compile_commands.json\n")
     #f]))

;; ─── Main ────────────────────────────────────────────────────────────────────────

(define (main)
  (define args (current-command-line-arguments))
  (when (null? args)
    (displayln "Usage: racket generate_compile_commands.rkt <project-root> [--build-system cmake|make|auto]")
    (exit 1))
  (define root (cadr args))
  (define bs
    (let loop ([a (cddr args)])
      (cond
        [(null? a) 'auto]
        [(string=? "--build-system" (car a))
         (if (null? (cdr a))
             (begin (displayln "Error: --build-system needs an argument") (exit 1))
             (string->symbol (cadr a)))]
        [else (loop (cdr a))])))
  (define cc-dest (build-path root "compile_commands.json"))
  (when (file-exists? cc-dest)
    (printf "[INFO] compile_commands.json already exists at ~a\n" cc-dest)
    (exit 0))
  (define detected (if (eq? bs 'auto) (detect-build-system root) bs))
  (printf "[INFO] Build system: ~a\n" detected)
  (define success
    (case detected
      [(cmake) (generate-cmake root)]
      [(make)  (generate-make root)]
      [else
       (displayln "[ERROR] Unknown build system.")
       (displayln "Create CMakeLists.txt or Makefile, then run:")
       (displayln "  mkdir build && cd build")
       (displayln "  cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON ..")
       #f]))
  (unless success (exit 1)))

(module+ main
  (main))
