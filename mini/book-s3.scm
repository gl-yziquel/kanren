(load "minikanrensupport.scm")

; Stream implementation

; data Ans a = Zero | Unit a | Choice a (() -> Ans a)
; In (Choice a f): a is the current answer; (f) will give further answers

; Constructors
(define-syntax mzero
  (syntax-rules ()
    ((_) #f)))

(define-syntax unit                        ; just the identity
  (syntax-rules ()
    ((_ a) a)))

(define-syntax choice
  (syntax-rules ()
    ((_ a f) (cons a f))))

; Deconstructor
(define-syntax case-ans
  (syntax-rules ()
    ((_ e on-zero ((a^) on-one) ((a f) on-choice))
     (let ((r e))
       (cond
         ((not r) on-zero)
         ((and (pair? r) (procedure? (cdr r)))
          (let ((a (car r)) (f (cdr r)))
            on-choice))
         (else (let ((a^ r)) on-one)))))))


; constructor of a suspension: () -> Ans a
(define-syntax lambdaf@
  (syntax-rules ()
    ((_ () e) (lambda () e))))

; constructor of a goal: Subst -> Ans a
(define-syntax lambdag@
  (syntax-rules ()
    ((_ (s) e) (lambda (s) e))))

; bind r k = case r of
;              Zero -> Zero
;              Unit a -> k a
;              Choice a f -> mplus (k a) (\() -> bind (f ()) k)

(define bind
  (lambda (r k)
    (case-ans r
      (mzero)
      ((a) (k a))
      ((a f) (mplus (k a) (lambdaf@ () (bind (f) k)))))))

; mplus:: Ans a -> (() -> Ans a) -> Ans a
; mplus r f =
;     case r of
;              Zero -> f ()
;              Unit a -> Choice a f
;              Choice a f' -> Choice a (\() -> mplus (f' ()) f)
; The last step is the rotation of the tree

(define mplus
  (lambda (r f)
    (case-ans r
      (f)
      ((a) (choice a f))
      ((a f^) (choice a
                (lambdaf@ () (mplus (f^) f)))))))


; interleave :: Ans a -> (() -> Ans a) -> Ans a
; interleave r f =
;     case r of
;              Zero -> f ()
;              Unit a -> Choice a f
;              Choice a f' -> Choice a (\() -> interleave (f ()) f')
; The last step is the rotation of the tree

(define interleave
  (lambda (r f)
    (case-ans r
      (f)
      ((a) (choice a f))
      ((a f^) (choice a
                (lambdaf@ () (interleave (f) f^)))))))


; Kanren implementation
(define succeed (lambdag@ (s) (unit s)))
(define fail (lambdag@ (s) (mzero)))

(define-syntax run*
  (syntax-rules ()
    ((_ (x) g0 g ...)
     (let ((x (var 'x)))
       (runner prefix* x (all g0 g ...))))))

(define runner
  (lambda (fn x g)
    (fn (lambda () (rn x (g empty-s))))))

(define rn
  (lambda (x r)
    (case-ans r
      (quote ())
      ((s) (cons (reify x s)
             (lambda () (quote ()))))
      ((s f) (cons (reify x s)
               (lambda () (rn x (f))))))))


(define-syntax run
  (syntax-rules ()
    ((_ n (x) g0 g ...)
     (let ((x (var 'x)))
       (runner (prefix n) x (all g0 g ...))))))

(define-syntax all
  (syntax-rules ()
    ((_) succeed)
    ((_ g) g)
    ((_ g0 g ...)
     (let ((g^ g0))
       (lambdag@ (s) (bind (g^ s) (lambdag@ (s) ((all g ...) s))))))))

(define ==
  (lambda (v w)
    (lambdag@ (s)
      (cond
        ((unify v w s) => succeed)
        (else (fail s))))))

(define-syntax fresh
  (syntax-rules ()
    ((_ (x ...) g0 g ...)
     (lambdag@ (s)
       (let ((x (var 'x)) ...)
         ((all g0 g ...) s))))))

(define-syntax project
  (syntax-rules ()
    ((_ (x ...) g0 g ...)  
     (lambda (s)
       (let ((x (walk-strong x s)) ...)
         ((all g0 g ...) s))))))

(define-syntax cond@
  (syntax-rules ()
    ((_ c ...) (c@ mplus c ...))))

(define-syntax condi
  (syntax-rules ()
    ((_ c ...) (c@ interleave c ...))))

(define-syntax c@
  (syntax-rules (else)
    ((_ combine) fail)
    ((_ combine (else g ...)) (all g ...))
    ((_ combine (g ...) c ...)
     (let ((g^ (all g ...)))
       (lambdag@ (s) (combine (g^ s) (lambdaf@ () ((c@ combine c ...) s))))))))

(define-syntax chop1
  (syntax-rules ()
    ((chop1 r s) (succeed s))))

(define-syntax cond1
  (syntax-rules ()
    ((_ c ...) (c1 chop1 c ...))))

(define-syntax chopo
  (syntax-rules ()
    ((chopo r s) r)))

(define-syntax condo
  (syntax-rules ()
    ((_ c ...) (c1 chopo c ...))))

(define-syntax c1
  (syntax-rules (else)
    ((_ chop) fail)
    ((_ chop (else g ...)) (all g ...))
    ((_ chop (g0 g ...) c ...)
     (let ((g^ g0))
       (lambdag@ (s)
         (let ((r (g^ s)))
           (case-ans r
             ((c1 chop c ...) s)   ; g0 failed
             ((s) ((all g ...) s)) ; g0 is deterministic
             ((s f)                ; at least one answer from g0
              (bind (chop r s) (lambdag@ (s) ((all g ...) s)))))))))))

(define-syntax alli
  (syntax-rules ()
    ((_) succeed)
    ((_ g) g)
    ((_ g0 g ...)
     (let ((g^ g0))
       (lambdag@ (s) (bindi (g^ s) (lambdag@ (s) ((alli g ...) s))))))))

(define bindi
  (lambda (r k)
    (case-ans r
      (mzero)
      ((a) (k a))
      ((a f) (interleave (k a)
               (lambdaf@ () (bindi (f) k)))))))

(define-syntax lambda-limited
  (syntax-rules ()
    ((_ n formals g)                                          
     (let ((x (var 'x)))                                                      
       (lambda formals (ll n x g))))))

(define ll
  (lambda (n x g)
    (lambdag@ (s)
      (let ((v (walk x s)))
        (cond
          ((var? v) (g (ext-s x 1 s)))
          ((< v n)  (g (ext-s x (+ v 1) s)))
          (else (fail s)))))))

; Converting streams to lists

(define prefix*
  (lambda (f)
    (let ((p (f)))
      (cond
    	((null? p) (quote ()))
	    (else (cons (car p) (prefix* (cdr p))))))))

(define prefix
  (lambda (n)
    (lambda (f)
      (cond
        ((zero? n) (quote ()))
        (else
         (let ((p (f)))
           (cond
             ((null? p) (quote ()))
             (else (cons (car p) ((prefix (- n 1)) (cdr p)))))))))))
