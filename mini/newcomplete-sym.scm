;;; This file was generated by writeminikanren.pl
;;; Generated at 2006-01-29 15:28:03

;;; Chapter 9 functions (remain as they were):

(define-syntax rhs
  (syntax-rules ()
    ((_ x) (cdr x))))

(define-syntax lhs
  (syntax-rules ()
    ((_ x) (car x))))

(define-syntax size-s
  (syntax-rules ()
    ((_ x) (length x))))

(define-syntax var
  (syntax-rules ()
    ((_ x) (vector x))))

(define-syntax var?
  (syntax-rules ()
    ((_ x) (vector? x))))

(define empty-s '())

(define walk
  (lambda (v s)
    (cond
      ((var? v)
       (let ((a (assq v s)))
         (cond
           (a (walk (rhs a) s))
           (else v))))
      (else v))))

(define ext-s
  (lambda (x v s)
    (cons `(,x . ,v) s)))

(define unify-unchecked
  (lambda (v w s)
    (let ((v (walk v s))
          (w (walk w s)))
      (cond
        ((eq? v w) s)
        ((var? v) (ext-s v w s))
        ((var? w) (ext-s w v s))
        ((and (pair? v) (pair? w))
         (let ((s (unify-unchecked (car v) (car w) s)))
           (and s (unify-unchecked (cdr v) (cdr w) s))))
        ((equal? v w) s)
        (else #f)))))

(define ext-s-check
  (lambda (x v s)
    (cond
      ((occurs-check x v s) #f)
      (else (ext-s x v s)))))

(define occurs-check
  (lambda (x v s)
    (let ((v (walk v s)))
      (cond
        ((var? v) (eq? v x))
        ((pair? v)
         (or
           (occurs-check x (car v) s)
           (occurs-check x (cdr v) s)))
        (else #f)))))

(define unify
  (lambda (v w s)
    (let ((v (walk v s))
          (w (walk w s)))
      (cond
        ((eq? v w) s)
        ((var? v) (ext-s-check v w s))
        ((var? w) (ext-s-check w v s))
        ((and (pair? v) (pair? w))
         (let ((s (unify (car v) (car w) s)))
           (and s (unify (cdr v) (cdr w) s))))
        ((equal? v w) s)
        (else #f)))))

(define walk*
  (lambda (v s)
    (let ((v (walk v s)))
      (cond
        ((var? v) v)
        ((pair? v)
         (cons
           (walk* (car v) s)
           (walk* (cdr v) s)))
        (else v)))))

(define reify-s
  (lambda (v s)
    (let ((v (walk v s)))
      (cond
        ((var? v)
         (ext-s v (reify-name (size-s s)) s))
        ((pair? v) (reify-s (cdr v)
                     (reify-s (car v) s)))
        (else s)))))

(define reify-name
  (lambda (n)
    (string->symbol
      (string-append "_" "." (number->string n)))))

(define walk*
  (lambda (v s)
    (let ((v (walk v s)))
      (cond
        ((var? v) v)
        ((pair? v)
         (cons
           (walk* (car v) s)
           (walk* (cdr v) s)))
        (else v)))))

(define reify
  (lambda (v s)
    (let ((v (walk* v s)))
      (walk* v (reify-s v empty-s)))))

;;; End of chapter 9 functions

; goal: Subst -> Stream
(define-syntax lambdag@
  (syntax-rules ()
    ((_ (s) e) (lambda (s) e))))

; a general-purpose thunk, to delay computations
(define-syntax lambdae@
  (syntax-rules ()
    ((_ () e) (lambda () e))))

; We define the stream of values, our monad, as follows
; data Stream a = Fail | Unit a | Incomplete (Cont a) |
;               | Choice a (Cont a)
; type Cont a = (a,a -> Stream a)
; Thus continuation (Cont a) is a pair whose first component is a partial
; answer (substitution computed so far).
; In Scheme, we represent (Cont a) as a two-component vector.

(define-syntax mzero
  (syntax-rules ()
    ((_) #f)))

(define-syntax unit
  (syntax-rules ()
    ((_ a) a)))

(define-syntax choice
  (syntax-rules ()
    ((_ a f) (cons a f))))

(define-syntax lambdac@
  (syntax-rules ()
    ((_ s0 (s) e) (vector s0 (lambda (s) e)))))

(define-syntax map-cont			; see its use in bind, for example
  (syntax-rules ()
    ((_ cont (f s) e)
      (let* ((c cont) (f (vector-ref c 1)))
	(lambdac@ (vector-ref c 0) (s) e)))))


(define (force-c cont) 			; continue the cont
  ((vector-ref cont 1) (vector-ref cont 0)))

; deconstructor of stream

(define-syntax case-inf
  (syntax-rules ()
    ((_ e on-zero ((a^) on-one) ((a f) on-choice) ((i) on-incomplete))
     (let ((r e))
       (cond
         ((not r) on-zero)
         ((vector? r) (let ((i r)) on-incomplete))
         ((and (pair? r) (vector? (cdr r)))
          (let ((a (car r)) (f (cdr r)))
            on-choice))
         (else (let ((a^ r)) on-one)))))))

(define-syntax run
  (syntax-rules ()
    ((_ n (x) g^ g ...) (take n (go (x) g^ g ...)))))

(define-syntax run*
  (syntax-rules ()
    ((_ (x) g ...) (run #f (x) g ...))))

(define take
  (lambda (n e)
    (cond
      ((and n (zero? n)) '())
      (else
        (let ((p (e)))
          (if p
            (cons (car p)
              (take (and n (- n 1)) (cdr p)))
            '()))))))

(define-syntax go  
  (syntax-rules ()
    ((_ (x) g^ g ...)
     (let ((x (var 'x)))
       (map-inf (lambda (s) (reify x s))
         (lambdac@ empty-s (s) ((all g^ g ...) s)))))))

(define map-inf
  (lambda (p f)
    (lambdae@ ()
      (case-inf (force-c f)
        #f
        ((s) (cons (p s) (lambdae@ () #f)))
        ((s f) (cons (p s) (map-inf p f)))
        ((i) ((map-inf p i)))))))

(define succeed (lambdag@ (s) (unit s)))

(define fail (lambdag@ (s) (mzero)))

(define-syntax fresh
  (syntax-rules ()
    ((_ (x ...) g^ g ...)
     (lambdag@ (s)
       (let ((x (var 'x)) ...)
         ((all g^ g ...) s))))))

(define-syntax all
  (syntax-rules ()
    ((_) succeed)
    ((_ g) g)
    ((_ g^ g g* ...)
     (all (let ((g0 g^)) (lambdag@ (s) (bind (g0 s) g))) g* ...))))

; symmetric all
(define-syntax allw
  (syntax-rules ()
    ((_) succeed)
    ((_ g) g)
    ((_ g ...)
      (lambdag@ (s)
	(par-and 
	  (list
	    (lambdac@ s (s) (g s)) ...))))))

; Compute parallel conjunction
; The argument is the list of (Cont Subst)
; It should contain at least two elements
(define (par-and jqueue)
  (let inner ((hj (force-c (car jqueue))) (jqueue (cdr jqueue)))
    (define (suspend jqueue)
      (map-cont (car jqueue) (f s) (inner (f s) (cdr jqueue))))
    ;(cout nl "inner: " hj nl jqueue nl)
    (case-inf hj
      (mzero)			; first failure finishes it
      ((s)			; one conjunct is finished deterministically
	(cond
	  ((null? jqueue) (unit s))
	  ((null? (cdr jqueue)) (restart s (car jqueue)))
	  (else
	    (inner (restart s (car jqueue)) (cdr jqueue)))))
      ((s f)			; A conjunct is finished with choice
	(mplus 
	  (inner (unit s) jqueue)
	  (suspend (append jqueue (list f)))))
      ((i) (suspend (append jqueue (list i)))))))

; Given a substitution s and a continuation (which too contains the
; partial substitution) reconcile the two substitutions and
; pass it to the continuation
(define (restart s cont)
  (let ((merged-s (merge-subst s (vector-ref cont 0))))
    ;(cout "restart: merged " merged-s nl)
    (if merged-s ((vector-ref cont 1) merged-s) (mzero))))

; Merge (unify) two substitutions.
; Currently we do it in a grossly inefficient (but obviously correct)
; way: unifying each binding of one substitution with respect to the other.
(define (merge-subst s0 s1)
  (define (merge s-short s-long)
    (cond
      ((null? s-short) s-long)
      (else
	(let ((bi (car s-short)) (s-short (cdr s-short)))
	  (cond
	    ((memq bi s-long) s-long) ; encountered common prefix of two subst
	    ((unify (lhs bi) (rhs bi) s-long) =>
	      (lambda (s) (merge s-short s)))
	    (else #f))))))
  (if (> (size-s s0) (size-s s1))
    (merge s1 s0)
    (merge s0 s1)))

; Find the common part of two substitutions extracted from the continuations
; Yet another very inefficient algorithm, albeit correct
(define (meet c0 c1)
  (define (check s-short s-long)
    (cond
      ((null? s-short) s-short)
      ((memq (car s-short) s-long) => (lambda (x) x))
      (else (check (cdr s-short) s-long))))
  (let ((s0 (vector-ref c0 0)) (s1 (vector-ref c1 0)))
    (if (> (size-s s0) (size-s s1))
      (check s1 s0)
      (check s0 s1))))


      
;; (define anyo
;;   (lambda (g)
;;     (conde
;;       (g succeed)
;;       (else (anyo g)))))

;; (define nevero (anyo fail))
;; (define alwayso (anyo succeed))

;; (run 1 (q) alwayso fail)
;; ; diverges

;; (run 1 (q) fail alwayso)
;; ; ()

;; (run 1 (q) (allw fail alwayso))
;; ; ()

;; (run 1 (q) (allw alwayso fail))

(define ==
  (lambda (v w)
    (lambdag@ (s)
      (unify v w s))))

(define ==-unchecked
  (lambda (v w)
    (lambdag@ (s)
      (unify-unchecked v w s))))

(define-syntax conde
  (syntax-rules (else)
    ((_) fail)
    ((_ (else g0 g ...)) (all g0 g ...))
    ((_ (g0 g ...) c ...)
     (lambdag@ (s)
       (mplus
         (lambdac@ s (s) ((all g0 g ...) s))
         (lambdac@ s (s) ((conde c ...) s)))))))

(define bind
  (lambda (s-inf g)
    (case-inf s-inf
      (mzero)
      ((s) (g s))
      ((s f) (mplus (g s) 
	       (map-cont f (f s) (bind (f s) g))))
      ((i) (map-cont i (f s) (bind (f s) g))))))

;;; This seems a lot simpler, but may have type problems
(define mplus
  (lambda (s-inf f)
    (let loop ((s-inf s-inf) (f f) (b #t))
      (case-inf s-inf
        f
        ((s) (choice s f))
        ((s f^) (choice s 
		  (lambdac@ (meet f f^) (s)
		    (loop (restart s f) (lambdac@ s (s) (restart s f^)) #t))))
        ((i) 
	  (lambdac@ (meet i f) (s)
	    (if b
	      (loop (restart s i) (lambdac@ s (s) (restart s f)) #f)
	      (loop (restart s f) (lambdac@ s (s) (restart s i)) #t))))))))
                            
(define-syntax project
  (syntax-rules ()
    ((_ (x ...) g^ g ...)
     (lambdag@ (s)
       (let ((x (walk* x s)) ...)
         ((all g^ g ...) s))))))

(define-syntax conda
  (syntax-rules (else)
    ((_) fail)
    ((_ (else g ...)) (all g ...))
    ((_ (g0 g ...) c ...) (ifa g0 (all g ...) (conda c ...)))))

(define-syntax condu
  (syntax-rules (else)
    ((_) fail)
    ((_ (else g ...)) (all g ...))
    ((_ (g0 g ...) c ...) (ifu g0 (all g ...) (condu c ...)))))

(define-syntax ifa
  (syntax-rules ()
    ((_ g0 g1 g2)
     (lambdag@ (s)
       (let loop ((s-inf (g0 s)))
         (case-inf s-inf
           (g2 s)
           ((s) (g1 s))
           ((s f) (bind s-inf g1))
           ((i) (map-cont i (i s) (loop (i s))))))))))

(define-syntax ifu
  (syntax-rules ()
    ((_ g0 g1 g2)
     (lambdag@ (s)
       (let loop ((s-inf (g0 s)))
         (case-inf s-inf
           (g2 s)
           ((s) (g1 s))
           ((s f) (g1 s))
           ((i) (map-cont i (i s) (loop (i s))))))))))


;;; For backward compatibility.
; Just the lambda...
(define-syntax lambda-limited
  (syntax-rules ()
    ((_ n formals g) (lambda formals g))))

(define-syntax alli
  (syntax-rules ()
    ((_ args ...) (all args ...))))

(define-syntax condi
  (syntax-rules ()
    ((_ args ...) (conde args ...))))

(define-syntax condw
  (syntax-rules ()
    ((_ args ...) (conde args ...))))

; Making the symmetric conjunction the default
(define-syntax all
  (syntax-rules ()
    ((_ args ...) (allw args ...))))

