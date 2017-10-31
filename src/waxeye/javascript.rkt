;; Waxeye Parser Generator
;; www.waxeye.org
;; Copyright (C) 2008-2010 Orlando Hill
;; Licensed under the MIT license. See 'LICENSE' for details.

#lang racket/base
(require (only-in racket/list add-between)
         waxeye/ast
         waxeye/fa
         "code.rkt" "dfa.rkt" "gen.rkt")
(provide gen-javascript gen-javascript-parser
         gen-typescript gen-typescript-parser)


(define (javascript-comment lines)
  (comment-bookend "/*" " *" " */" lines))

(define typescript (make-parameter #f))

(define (gen-typescript grammar path)
  (indent-unit! 2)
  (let ((file-path (string-append path (if *name-prefix*
                                           (string-append (string-downcase *name-prefix*) "_parser.ts")
                                           "parser.ts"))))
    (dump-string (gen-typescript-parser grammar) file-path)
    (list file-path)))

(define (gen-javascript grammar path)
  (indent-unit! 4)
  (let ((file-path (string-append path (if *name-prefix*
                                           (string-append (string-downcase *name-prefix*) "_parser.js")
                                           "parser.js"))))
    (dump-string (gen-javascript-parser grammar) file-path)
    (list file-path)))

(define (gen-char t)
  (format "'~a~a'"
          (if (escape-for-java-char? t) "\\" "")
          (cond
           ((equal? t #\") "\\\"")
           ((equal? t #\linefeed) "\\n")
           ((equal? t #\tab) "\\t")
           ((equal? t #\return) "\\r")
           (else t))))

(define (gen-char-class a)
  (define (gen-char-class-item a)
    (if (char? a)
        (format "0x~x"
                (char->integer a))
        (format "[0x~x, 0x~x]"
                (char->integer (car a))
                (char->integer (cdr a)))))
  (cond
   ((symbol? a) "-1") ;; use -1 for wild card
   ((list? a) (gen-array gen-char-class-item a))
   ((char? a) (gen-char-class-item a))
   (else a)))

(define exp-id-map
  (make-hash '(
    ("NT" . 1)
    ("ALT" . 2)
    ("SEQ" . 3)
    ("PLUS" . 4)
    ("STAR" . 5)
    ("OPT" . 6)
    ("AND" . 7)
    ("NOT" . 8)
    ("VOID" . 9)
    ("ANY_CHAR" . 10)
    ("CHAR" . 11)
    ("CHAR_CLASS" . 12)
  )))

(define (gen-exp a)
  (let-values ([(name args)
    (case (ast-t a)
      [(identifier)
        (values "NT"
          (format "name: '~a'" (list->string (ast-c a))))]
      [(literal) (if (<= (length (ast-c a)) 1)
        (values "CHAR"
          (format "char: ~a" (gen-char (car (ast-c a)))))
        (values "SEQ"
          (format "exprs: ~a"
            (gen-array gen-exp
              (map (lambda (b) (ast 'literal (cons b '()) '()))
                   (ast-c a))))))]
      [(charClass)
        (values "CHAR_CLASS"
          (format "codepoints: ~a" (gen-char-class (ast-c a))))]
      [(void)
        (values "VOID"
          (format "expr: ~a" (gen-exp (car (ast-c a)))))]
      [(and)
        (values "AND"
          (format "expr: ~a" (gen-exp (car (ast-c a)))))]
      [(not)
        (values "NOT"
          (format "expr: ~a" (gen-exp (car (ast-c a)))))]
      [(optional)
        (values "OPT"
          (format "expr: ~a" (gen-exp (car (ast-c a)))))]
      [(closure)
        (values "STAR"
          (format "expr: ~a" (gen-exp (car (ast-c a)))))]
      [(plus)
        (values "PLUS"
          (format "expr: ~a" (gen-exp (car (ast-c a)))))]
      [(alternation)
        (values "ALT"
          (format "exprs: ~a" (gen-array gen-exp (ast-c a))))]
      [(sequence)
        (values "SEQ"
          (format "exprs: ~a" (gen-array gen-exp (ast-c a))))]
      [(wildCard) (values "ANY_CHAR" "")]
      [else (format "unknown:~a" (ast-t a))]
    )])
    (define args-str
      (if (= 0 (string-length args))
          ""
          (format ", ~a" args)))
    (if (typescript)
        (format "{ type: ExprType.~a~a }" name args-str)
        (format "{ type: ~a /* ~a */~a }" (hash-ref exp-id-map name) name args-str))))

(define nonterminal-mode-map
  (make-hash '(
    ("NORMAL" . 1)
    ("PRUNING" . 2)
    ("VOIDING" . 3)
  )))

(define (gen-def a)
  (let ([mode-name (case (ast-t (list-ref (ast-c a) 1))
                         ((voidArrow) "VOIDING")
                         ((pruneArrow) "PRUNING")
                         ((leftArrow) "NORMAL"))]
        [nt-name (list->string (ast-c (list-ref (ast-c a) 0)))]
        [exp (gen-exp (list-ref (ast-c a) 2))])
    (if (typescript)
      (format "'~a': { mode: NonTerminalMode.~a, exp: ~a }"
        nt-name mode-name exp)
      (format "'~a': { mode: ~a /* ~a */, exp: ~a }"
        nt-name (hash-ref nonterminal-mode-map mode-name) mode-name exp))))

(define (gen-defs a)
  (gen-map gen-def (ast-c a)))

(define (gen-map fn data)
    (format "{~a}"
            (indent (if (null? data)
                        ""
                        (string-append (fn (car data))
                                       (apply string-append (map (lambda (a)
                                                             (string-append ",\n" (ind) (fn a)))
                                                           (cdr data))))))))
(define (gen-array fn data)
    (format "[~a]"
            (indent (if (null? data)
                        ""
                        ; Simulate string-join with string-append . add-between,
                        ; because racketscript cannot handle racket/string.
                        (apply string-append (add-between (map fn data) ", "))))))


(define (gen-typescript-parser grammar)
  (let ((parser-name (if *name-prefix*
                         (string-append (camel-case-upper *name-prefix*) "Parser")
                         "Parser")))
    (format "~a
import { ExprType, NonTerminalMode, ParserConfig, WaxeyeParser } from 'waxeye';

const parserConfig: ParserConfig =
 ~a~a~a;
const start = '~a';

export class ~a extends WaxeyeParser {
  public constructor() {
    super(parserConfig, start);
  }
}
"
            (if *file-header*
              (javascript-comment *file-header*)
              (javascript-comment *default-header*))
            (ind) (ind) (parameterize ([typescript #t]) (gen-defs grammar))
            *start-name*
            parser-name)))


(define (gen-javascript-parser grammar)
  (let ((parser-name (if *name-prefix*
                         (string-append (camel-case-upper *name-prefix*) "Parser")
                         "Parser")))
    (define (gen-parser-class)
      (format "
function ~a() {}
~a.prototype = new waxeye.WaxeyeParser(
~a~a~a
~a, '~a');
"
              parser-name parser-name
              (ind) (ind) (parameterize ([typescript #f]) (gen-defs grammar))
              (ind) *start-name*))


    (define (gen-nodejs-imports)
      (indent (format "
var waxeye = waxeye;
if (typeof module !== 'undefined') {
~a// require from module system
~awaxeye = require('waxeye');
}
" (ind) (ind))))


    (define (gen-nodejs-exports)
      (indent (format "
// Add to module system
if (typeof module !== 'undefined') {
~amodule.exports.~a = ~a;
}
" (ind) parser-name parser-name)))

    (format "~a~a~a~a"
      (if *file-header*
          (javascript-comment *file-header*)
          (javascript-comment *default-header*))
      (gen-nodejs-imports)
      (gen-parser-class)
      (gen-nodejs-exports))))
