(load "book-cb.scm")

(define errorf
  (lambda (tag . args)
    (printf "Failed: ~s: ~%" tag)
    (apply printf args)))


(define once
  (lambda (g)
    (condu
      [g]
      [else fail])))

(define-syntax trace-vars
  (syntax-rules ()
    [(_ name (id* ...))
      (lambda (n s a o)
	(pretty-print (list name (reify id* s) ...))
	(succeed n s a o))]))

(define tex #f)

(define-syntax test-check
  (syntax-rules ()
    ((_ title tested-expression expected-result)
     (test-check title tested-expression expected-result #t))
    ((_ title tested-expression expected-result show-flag)
     (begin
       (let* ((expected expected-result)
              (produced tested-expression))
         (if (equal? expected produced)
             (if tex
                 (if show-flag
                     (generate-tex 'tested-expression produced)
                     (void))
                 (cout title " works!" nl))
             (errorf 'test-check
                     "Failed ~s: ~a~%Expected: ~a~%Computed: ~a~%"
                     title 'tested-expression expected produced)))))))

(define generate-tex
  (lambda (exp result)
    (printf "\\twocol{\\smallskip~n\\i1 \\begin{schemebox}~n")
    (pretty-print exp)
    (printf "\\end{schemebox}}~n{\\begin{schemeresponsebox}~n")
    (pretty-print (tex-data result))
    (printf "\\end{schemeresponsebox}}\n\n")))

(define tex-data
  (lambda (x)
    (cond
      ((pair? x) (cons (tex-data (car x)) (tex-data (cdr x))))
      ((symbol? x)
       (cond
         ((var-symbol? x) (translate-to-tex x))
         (else x)))
      (else x))))

(define var-symbol?
  (lambda (x)
    (memq #\. (string->list (symbol->string x)))))

(define reify-id-tex
  (lambda (id index)
    (string->symbol
      (string-append
        (symbol->string id)
        "$_{_{"
        (number->string index)
        "}}$"))))

(define translate-to-tex
  (lambda (x)
    (reify-id-tex
      (string->symbol (list->string (prefix-id (string->list (symbol->string x)))))
      (string->number (list->string (cdr (var-symbol? x)))))))

(define prefix-id
  (lambda (x)
    (cond
     ((eq? (car x) #\.) '())
     (else (cons (car x) (prefix-id (cdr x)))))))

; Initial tests

(test-check "conde extensive 0"
  (run* (x)
    (conde
      ((conde 
	 ((== x 1))
	 ((== x 11))))
      ((conde 
	 ((== x 2))
	 ((== x 3)))
	(trace-vars 21 (x))
	(conde
	  ((trace-vars 22 (x)) fail)
	  ((trace-vars 23 (x)) fail)
	  ((trace-vars 24 (x)) fail)
	  (succeed)))))
  '(1 11 2 3))

(test-check "conde extensive"
  (run* (x)
    (fresh (y)
      (conde 
        ((conde 
           ((== y 1))
           ((== y 11))))
        ((conde 
           ((== y 2))
           (fail)
           ((== y 3)))))
      (conde
        ((== x y))
        ((== x 100)))))
  '(1 100 11 100 2 100 3 100))

(test-check "condi extensive"
  (run* (x)
    (fresh (y)
      (condi 
        ((condi 
           ((== y 1))
           ((== y 11))))
        ((condi 
           ((== y 2))
           (fail)
           ((== y 3)))))
      (condi
        ((== x y))
        ((== x 100)))))
  '(1 100 2 100 11 100 3 100))

(test-check "alli"
  (run* (x)
    (fresh (y)
      (alli
       (condi 
         ((condi 
            ((== y 1))
            ((== y 11))))
         ((condi 
            ((== y 2))
            (fail)
            ((== y 3)))))
       (condi
         ((== x y))
         ((== x 100))))))
  '(1 2 100 11 100 3 100 100))

; conda, condu tests
'(test-check "conda-1"
  (run 3 (q)
       (conda
          ((conde ((== q 3)) ((== q 4))) succeed)
          ((conde ((== q 5)) ((== q 6))) succeed)
          (else fail)))    
  '(3 4))

'(test-check "conda-2"
  (run 3 (q)
       (conda
    	 ((conde ((== q 3)) ((== q 4))) (== q 4))
	     (else fail)))    
  '(4))


'(test-check "conda-3"
  (run 3 (q)
       (conda
    	 ((conde ((== q 3)) ((== q 4))) (== q 3))
	     (else fail)))    
  '(3))


'(test-check "condu-1"
  (run 3 (q)
       (condu
    	 ((conde ((== q 3)) ((== q 4))) (== q 3))
	     (else fail)))    
  '(3))

'(test-check "condu-2"
  (run 3 (q)
       (condu
    	 ((conde ((== q 3)) ((== q 4))) (== q 4))
	     (else fail)))    
  '())



; infinitary relations

(define always
   (conde (succeed) (else always)))

(test-check "always-1"
  (run 10 (q) always)   
  '(_.0 _.0 _.0 _.0 _.0 _.0 _.0 _.0 _.0 _.0))

(test-check "always-2"
  (run 10 (q) (conde (always) (else (== q 10))))   
  '(_.0 _.0 _.0 _.0 _.0 _.0 _.0 _.0 _.0 _.0))

(test-check "always-3"
  (run 10 (q) (condi (always) (else (== q 10))))   
  '(_.0 10 _.0 _.0 _.0 _.0 _.0 _.0 _.0 _.0))


(test-check "always-4"
  (run 10 (q) (conde ((== q 10)) (else (== q 11))) always)   
  '(10 10 10 10 10 10 10 10 10 10))

(test-check "always-5"
  (run 10 (q) (alli (conde ((== q 10)) (else (== q 11))) always))   
  '(10 11 10 11 10 11 10 11 10 11))


(test-check "always-fail-1"
  (run 2 (q) (condi ((conde ((== q 10)) (else (== q 11))))
	                  (always fail)))
  '(10 11))

(test-check "always-fail-1"
  (run 2 (q) (alli (condi ((conde ((== q 10)) (else (== q 11))))
	                  (always fail))))
  '(10 11))

(test-check "always-fail-2"
  (run 2 (q) (condi (always fail)
	       ((conde ((== q 10)) (else (== q 11))))
	           ))
  '(10 11))

; with no limit on depth...
(test-check "always-fail-3"
  (run 3 (q) (condi ((conde ((== q 10)) (else (== q 11))))
	       (always fail)))
  '(10 11))
	         

(test-check "just always-fail"
  (run 3 (q) always fail)
  '())

(test-check "X=1,repeat,X=2"
  (run 3 (q) (== q 1) always (== q 2))
  '())


(define insidious 
  (lambda (x)
    (fresh ()
      (condi
	((== x 1) (trace-vars 1 (x)))
	(else (insidious x)))
      (conde
	(fail)
	(else succeed)))))

(test-check "insidious recursion"
  (run 4 (q) (insidious q))
  '(1 1 1 1))


(define build
  (lambda (n)
    (cond
      ((zero? n) '())
      (else (cons (if (even? n) 0 1) (build (quotient n 2)))))))

(define trans
  (lambda (n)
    (cond
      ((null? n) 0)
      (else (+ (car n) (* 2 (trans (cdr n))))))))

(define c==
  (lambda (x)
    (lambda (y)
      (== x y))))

(define poso
  (lambda (n)
    (fresh (_ __)
      (== `(,_ . ,__) n))))

(define >1o
  (lambda (n)
    (fresh (_ __)
      (== `(,_ . ,__) n)
      (poso __))))

'(define half-adder
 (lambda (x y r c-out)
   (all
     (bit-xor x y r)
     (bit-and x y c-out))))

(define bop-maker
  (lambda (table)
    (lambda (x y r)
      (for@ (c== `(,x ,y ,r)) table))))

(define bit-and
  (bop-maker '((0 0 0) (1 0 0) (0 1 0) (1 1 1))))

(define nullo
  (lambda (x)
    (== '() x)))

(define caro
  (lambda (x a)
    (fresh (_)
      (== `(,a . ,_) x))))

(define cdro
  (lambda (x d)
    (fresh (_)
      (== `(,_ . ,d) x))))

(define foro
  (lambda (f l)
    (fresh (x)
      (cond
        ((caro l x)
         (f x))
        (else
          (cdro l x)
          (foro f x))))))

;; Examples of foro usage;  (run* (q) (foro (lambda (f) (f (build 9) q)) `(,caro ,cdro)))
; (1 (0 0 1))

; (run (q)
;  (foro
;    (lambda (x) (caro x q))
;    `(,(build 0)
;      ,(build 1)
;      ,(build 2)
;      ,(build 3)
;      ,(build 4)
;      ,(build 5)))))

; > (prefix (run (q) (foro (lambda (x) (all (poso x) (== x q))) (map build '(0 1 2 3 4 5)))))
; ((1) (0 1) (1 1) (0 0 1) (1 0 1))
; > (prefix (run (q) (foro (lambda (x) (all (>1o x) (== x q))) (map build '(0 1 2 3 4 5)))))
; ((0 1) (1 1) (0 0 1) (1 0 1))

; oddnes and evenness for positive numbers
; > (prefix (run (q) (foro (lambda (x) (caro x q)) (map build '(0 1 2 3 4 5)))))
; (1 0 1 0 1)


(define pairo
  (lambda (ls)
    (fresh (_ __)
      (== `(,_ . ,__) ls))))


(define half-adder
  (lambda (x y r c)
    (foro
      (c== `(,x ,y ,r ,c))
      '((0 0 0 0) (1 0 1 0) (0 1 1 0) (1 1 0 1)))))

'(define full-adder
  (lambda (b x y r c)
    (fresh (w xy wz)
      (half-adder x y w xy)
      (half-adder w b r wz)
      (bit-xor xy wz c))))

(define bit-or
  (lambda (x y r)
    (foro
      (c== `(,x ,y ,r))
      '((0 0 0) (1 0 1) (0 1 1) (1 1 1)))))

(define bit-xor
  (lambda (x y r)
    (foro
      (c== `(,x ,y ,r))
      '((0 0 0) (1 0 1) (0 1 1) (1 1 0)))))

(define build-bit
  (lambda (b k)
    (conde
      ((== 0 b) (== '() k))
      ((== 1 b) (== '(1) k))
      (else fail))))

(define full-adder
  (lambda (a b c d e)
    (conde
      ((== a 0) (== b 0) (== c 0) (== d 0) (== e 0))
      ((== a 1) (== b 0) (== c 0) (== d 1) (== e 0))
      ((== a 0) (== b 1) (== c 0) (== d 1) (== e 0))
      ((== a 1) (== b 1) (== c 0) (== d 0) (== e 1))
      ((== a 0) (== b 0) (== c 1) (== d 1) (== e 0))
      ((== a 1) (== b 0) (== c 1) (== d 0) (== e 1))
      ((== a 0) (== b 1) (== c 1) (== d 0) (== e 1))
      ((== a 1) (== b 1) (== c 1) (== d 1) (== e 1))
      (else fail))))

; There is the third way of doing the addition, using
; all-interleave and any-interleave.
; Note that the code below is almost identical to the very first,
; non-recursively enumerating full-adder, only
; extend-relation is replaced with extend-relation-interleave
; and all is replaced with all-interleave in two places.
; The results are amazing, as the tests below show.
; For example, the test "print a few numbers that are greater than 4"
; shows that the numbers are generated _in sequence_, despite
; our addition being binary (and so one would expect the numbers
; being generated in Gray code or so).
; tests multiplication-all-3 and multiplication-all-4
; show that (**o (build 3) y z) and (**o y (build 3) z)
; generates the _same_ answerlist, and in that answerlist, 'y' appears
; in sequence: 0,1,2....
(define adder
  (lambda (d)
    (lambda (n m r)
      (condi
        ((== 0 d) (== '() m) (== n r))  ; 0 + n + 0 = n
        ((== 0 d) (== '() n) (== m r) (poso m)) ; 0 + 0 + m = m
        ((== 1 d) (== '() m) ((adder 0) n '(1) r)) ; 1 + n + 0 = 0 + n + 1
        ((== 1 d) (== '() n) (poso m) ((adder 0) '(1) m r)) ; 1 + 0 + m = 0 + 1 + m
    ; The following three relations are needed
    ; to make all numbers well-formed by construction,
    ; that is, to make sure the higher-order bit is one.
        ((== '(1) n) (== '(1) m) ; c + 1 + 1 >= 2
         (fresh (a c)
           (== `(,a ,c) r)
           (full-adder d 1 1 a c)))
    ; d + 1 + (2*y + b) = (2*z + rb) where y > 0 and so is z > 0
        ((== '(1) n) ((gen-adder d) n m r))
    ; symmetric case for the above
        ((== '(1) m)
         (>1o n)
         (>1o r)
         ((adder d) '(1) n r))
    ; d + (2*x + a) + (2*y + b) 
    ; = (d + a + b) (mod 2)
    ; + 2*(x + y + (d + a + b)/2)
    ; The cases of x= 0 or y = 0 have already been handled.
    ; So, now we require x >0 and y>0. That implies that z>0.
        ((>1o n) ((gen-adder d) n m r))
        (else fail)))))

(define gen-adder
  (lambda (d)
    (lambda (n m r)
      (fresh (a b c e x y z)
        (== `(,a . ,x) n)
        (== `(,b . ,y) m)
        (poso y)       
        (== `(,c . ,z) r)
        (poso z)
        (fresh (e)
          (alli
           (full-adder d a b c e)
           ((adder e) x y z)))))))

(define +o
  (lambda (n m r)
    ((adder 0) n m r)))

;; infinite loops in both Kanren and mini-Kanren
;;
;; (prefix 1 (run (q) (fresh (x y) (xo '(1 1) `(1 ,x . ,y) `(,x . ,y)))))
;; (prefix 1 (run (q) (fresh (r) (xo `(1 . ,r) `(1 1) `(1 . ,r)))))



(define xo
  (lambda (n m p)
    (condi
      ((== '() n) (== p '()))       
      ((poso n) (== '() m) (== p '()))  
      ((== n '(1)) (poso m) (== m p))   
      ((>1o n) (== '(1) m) (== n p))
      ((>1o m)
       (fresh (x z)      
         (== `(0 . ,x) n) (poso x)
         (== `(0 . ,z) p) (poso z)
         (xo x m z)))
      ((fresh (x y)
         (== `(1 . ,x) n) (poso x)
         (== `(0 . ,y) m) (poso y)
         (xo m n p))
       succeed)
      (else
        (fresh (x y)
          (== `(1 . ,x) n) (poso x)          
          (== `(1 . ,y) m) (poso y)
          ((odd-xo x) n m p))))))

(define odd-xo
  (lambda (x)
    (lambda (n m p)
      (fresh (q)
        (boundx q p n m)
        (xo x m q)
        (+o `(0 . ,q) m p)))))






(define xo
  (lambda (n m p)
    (condi
      ((== '() n) (== p '()))       
      ((poso n) (== '() m) (== p '()))  
      ((== n '(1)) (poso m) (== m p))   
      ((>1o n) (== '(1) m) (== n p))
      ((fresh (x z)
         (== `(0 . ,x) n) (poso x)
         (== `(0 . ,z) p) (poso z)
         (>1o m)
         (xo x m z)))
      ((fresh (x y)
         (== `(1 . ,x) n) (poso x)
         (== `(0 . ,y) m) (poso y)
         (xo m n p))
       succeed)
      (else
        (fresh (x y)
          (== `(1 . ,x) n) (poso x)          
          (== `(1 . ,y) m) (poso y)
          ((odd-xo x) n m p))))))

(define odd-xo
  (lambda (x)
    (lambda (n m p)
      (fresh (z q)
        (== `(1 . ,z) p)
        (boundx q p n m)
        (xo x m q)
        (+o `(0 . ,q) m p)))))




(define odd-xo
  (lambda (x)
    (lambda (n m p)
      (fresh (z q)
;        (== `(1 . ,z) p)
        (boundx q p n m)
        (xo x m q)
        (+o `(0 . ,q) m p)))))













      ; n, m are both > 1
      ; n = 2x
      ; nm = (2x)m = 2(xm) = 2z
      ; so xm = z
      ; p = nm
      ; x > 0, otherwise the number is ill-formed
(define even/?/even
  (lambda (n m p)
    (all
      (fresh (_ __ ___)
        (== `(,_ ,__ . ,___) m))
    (fresh (x z)      
      ;(>1o m)
      (== n `(0 . ,x))
      (poso x)
      (== p `(0 . ,z))
      (poso z)
      (xo x m z)))))

      ; n, m are both > 1
      ; n = 2x + 1
      ; m = 2y
      ; mn = (2y)n = 2(yn) = 2z
      ; yn = z
      ; p = nm
(define odd/even/even
  (lambda (n m p)
    (all
      (fresh (_ __)
        (== n `(1 ,_ . ,__)))
    (fresh (y z _ __)
      (== m `(0 . ,y))
      (poso y)
      (== p `(0 . ,z))
      (poso z)
      (xo y n z)))))

      ; n, m are both > 1
      ; n = 2x + 1
      ; m is odd
      ; nm = (2x + 1)m = 2(xm) + m = 2q + m = p
      ; so q = xm
      ; x>0 for well-formedness
      ; the result is certainly greater than 1.
      ; we note that m > 0 and so 2*(x*m) < 2*(x*m) + m
      ; and (floor (log2 (x*m))) < (floor (log2 (2*(x*m) + m)))
(define odd/odd/odd
  (lambda (n m p)
    (all
      (fresh (_ __)
        (== m `(1 ,_ . ,__)))
    (fresh (y _ z q)
      (== n `(1 . ,y))
      (poso y)
      (== `(,_ . ,z) p) (poso z)
      (boundx q p n m)
      (xo y m q)
      (+o `(0 . ,q) m p)))))

(define -o
  (lambda (n m k)
    (+o m k n)))

(define =o ;;; hardly necessary.
  (lambda (n m)
    (== n m)))

(define <o  ; n < m iff exists x >0 such that n + x = m
  (lambda (n m)
    (fresh (x)
      (poso x)
      (+o n x m))))


;; Here is the better defn from Snowbird
(define <o  ; n < m iff exists x >0 such that n + x = m
  (lambda (n m)
    (condi
      ((<ol n m))
      (else
         (=ol n m)
         (fresh (x)
           (poso x)
           (+o n x m))))))

;; Cleaner definition!
(define <o
  (lambda (n m)
    (condi
      ((<ol n m) succeed)
      ((=ol n m)
       (fresh (x)
         (poso x)
         (+o n x m))))))



'(define <o
  (lambda (n m)
    (condi
      ((<ol n m) (trace-vars 1 (n m)) succeed)
      ((conde ((== n '(1)) (== m '(1))) ((fresh (x y) (== n (list x 1)) (== m (list y 1))))) ;(=ol n m)
       (fresh (x)
         (poso x)
	(fresh (z) (== z (list n x m)) (trace-vars 2 (z)))
         (+o n x m) (trace-vars 3 (n m)) )))))

'(define <o
  (lambda (n m)
    (condi
      ((<ol n m) (trace-vars 1 (n m)) succeed)
      ((=ol n m)
       (fresh (x)
         (poso x)
	(fresh (z) (== z (list n x m)) (trace-vars 2 (z)))
         (+o n x m) (trace-vars 3 (n m)) )))))

; (<ol3 q p n m) holds iff
; q = '() and (poso p) or
; width(q) < (min width(p), width(n) + width(m) + 1)
; The way that n is counted down is subtle.  When
; it hits 0, m takes the role of n, since it may have some
; bits left.  When n and m are both 0, both cases fail.
; q and p are counted down naturally.

(define boundx
  (lambda (q p n m)
    (conde
      ((== '() q) (poso p))
      (else
        (fresh (x y z _ __ ___)
          (== `(,_ . ,x) q)
          (== `(,__ . ,y) p)
          (condi
            ((== '() n)
             (== `(,___ . ,z) m)
             (boundx x y z '()))
            (else
              (== `(,___ . ,z) n) 
              (boundx x y z m))))))))





(define boundx
  (lambda (q p n m)
    (conde
      ((nullo q) (pairo p))
      (else
        (fresh (x y z)
          (cdro q x)
          (cdro p y)
          (condi
            ((nullo n)
             (cdro m z)
             (boundx x y z '()))
            (else
              (cdro n z) 
              (boundx x y z m))))))))





; Compare the length of two numerals.  (<ol a b) holds holds if a=0
; and b>0, or if (floor (log2 a)) < (floor (log2 b)) That is, we
; compare the length (logarithms) of two numerals For a positive
; numeral, its bitlength = (floor (log2 n)) + 1

(define <ol
  (lambda (n m)
    (conde
      ((== '() n) (poso m))
      ((== '(1) n) 
       (fresh (_ y)
         (== `(,_ . ,y) m) (poso y)))
      (else
        (fresh (x y _ __)
          (== `(,_ . ,x) n) (poso x)
          (== `(,__ . ,y) m) (poso y)
          (<ol x y))))))

; holds if both a and b are zero
; or if (floor (log2 a)) = (floor (log2 b))

(define =ol
  (lambda (n m)
    (conde
      ((== '() n) (== '() m))
      (else (=ol^ n m)))))

'(define =ol
  (lambda (n m)
    (conde
      ((== '() n) (== '() m))
      (else (trace-vars 55 ()) fail))))

(define =ol^
  (lambda (n m)
    (conde
      ((== '(1) n) (== '(1) m))
      (else
        (fresh (x y _ __)
          (== `(,_ . ,x) n) (poso x)
          (== `(,__ . ,y) m) (poso y)
          (=ol^ x y))))))

;; divide 8 by 7
;; (0 0 0 1) by (1 1 1)

'(define split
  (lambda (n r nl nh)
    (conde
      ((== '() n) (== '() nl) (== '() nh))
      ((== `(0 . ,nh) n) (poso nh) 
       (== '() r) (== '() nl))
      ((== `(1 . ,nh) n) 
       (== '() r) (== '(1) nl))
      (else
        (fresh (_ x s)
          (== `(,_ . ,s) r)
          (conde
            ((== `(0 . ,x) n) (poso x)
             (== '() nl)
             (split x s '() nh))
            ((== `(1 . ,x) n)
             (== '(1) nl)
             (split x s '() nh))
            (else
              (fresh (b y)
                (== `(,b . ,x) n)
                (== `(,b . ,y) nl) (poso y) 
                (split x s y nh)))))))))


;;; Will's split
(define split
  (lambda (n r nl nh)    
    (fresh (tmp)
      (min-ol `(1 . ,r) n tmp)
      (append@ tmp nh n)
      (remove-leading-zeros tmp nl))))

(define min-ol
  (lambda (a b m)
    (conde
      [(<ol a b) (safe=ol a m)]
      [(<ol b a) (safe=ol b m)]
      [(safe=ol a b) (=ol b m)])))

(define safe=ol
  (lambda (l m)
    (conde
      [(nullo l) (nullo m)]
      [else 
        (fresh (d res)
          (cdro l d)
          (cdro m res)
          (safe=ol d res))])))

(define remove-leading-zeros
  (lambda (ls out)
    (fresh (sl tuo)
      (reverse@ ls sl)
      (remove-leading-zeros-aux sl tuo)
      (reverse@ tuo out))))

(define remove-leading-zeros-aux
  (lambda (sl tuo)
    (fresh (d)
      (conde
        [(nullo sl) (nullo tuo)]
        [(== `(0 . ,d) sl) (remove-leading-zeros-aux d tuo)]
        [(== `(1 . ,d) sl) (== tuo sl)]))))

(define reverse@
  (lambda (ls out)
    (conde
      [(nullo ls) (== '() out)]
      [(fresh (a d)
         (== `(,a . ,d) ls)
         (fresh (tmp)
           (reverse@ d tmp)
           (append@ tmp `(,a) out)))])))

(define eqo
  (lambda (x y)
    (== x y)))

(define eq-caro
  (lambda (lat x)
    (fresh (a)
      (caro lat a)
      (eqo a x))))

(define cdro
  (lambda (ls d)
    (fresh (_)
      (== (cons _ d) ls))))

(define caro
  (lambda (ls a)
    (fresh (_)
      (== (cons a _) ls))))

(define append@
  (lambda (l1 l2 out)
    (conde
      ((nullo l1) (== l2 out))
      (else 
        (fresh (a d res)
          (conso a d l1)
          (append@ d l2 res)
          (conso a res out))))))

(define nullo
  (lambda (x)
    (== '() x)))

(define conso
  (lambda (a d ls)
    (== (cons a d) ls)))



(define divo
  (lambda (n m q r)
    (condi
      [(== r n) (== '() q) (<o n m)] 
                     ; m has more digits than n: q=0,n=r
      [(<ol m n) (<o r m)     ; n has more digits than m
		                      ; q is not zero, n>0, so q*m <= n,
       (fresh (res)           ; definitely q*m < 2*n
         (<ol res `(0 . ,n))
         (+o res r n)
         (xo m q res))]
          ; (width m) = (width n); r < m, q = 1.
      [(=ol m n) (<o r m) (== q '(1)) (-o n m r)]
          ; (width m) = (width n); n < m, q = 0, r = n
      [(== '() q) (=ol m n) (== r n) (<o n m)])))

(define divo
  (lambda (n m q r)
    (condi
      [(== r n) (== '() q) (<o n m)]
      [(== '(1) q) (=ol n m) (+o r m n) (<o r m)]
      [(<ol m n) (<o r m)
       (fresh (res)
         (<ol res `(0 . ,n))
         (+o res r n)
         (xo m q res))])))

(define divo
  (lambda (n m q r)
    (condi
      [(== n r) (== '() q) (<o r m)]
      [(== '() r) (== '(1) q) (<o r m) (== n m)]      
      [(<o m n) (<o r m)
       (fresh (res)
         (<ol res `(0 . ,n))
         (+o res r n)
         (xo m q res))])))


(define divo
  (lambda (n m q r)
    (condi
      [(== r n) (== '() q) (<o n m)]
      [(== n m) (== '() r) (== '(1) q) (<o r m)]      
      [(<o m n) (<o r m)
       (fresh (res)
         (<ol res `(0 . ,n))
         (+o res r n)
         (xo m q res))])))


(define divo
  (lambda (n m q r)
    (condi
      [(== r n) (== '() q) (<o n m)]
      [(== n m) (== '() r) (== '(1) q) (<o r m)]      
      [(<o m n) (<o r m)
       (fresh (mq)
         (<ol mq `(0 . ,n))
         (xo m q mq)
         (+o mq r n))])))


(define divo
  (lambda (n m q r)
    (condi
      [(== r n) (== '() q) (<o n m)]
      [(== n m) (== '() r) (== '(1) q) (<o r m)]      
      [(<o m n) (<o r m)
       (fresh (mq)
         (<=ol mq n)
         (xo m q mq)
         (+o mq r n))])))




'(define divo
  (lambda (n m q r)
    (condi
      ((== r n) (== '() q) (<o n m))
      ((== '(1) q) (=ol n m) (+o r m n)
       (<o r m))
      ((<ol m n) (<o r m) (poso q) 
       (fresh (nl nh ql qh mql)
         (split n r nl nh)
         (split q r ql qh)
         (xo m ql mql)
         (conde
           ((== '() nh) (== '() qh)
            (+o mql r nl)) 
           (else
             (fresh (mqlpr rr rh)
               (poso nh) 
               (xo m ql mql) 
               (+o mql r mqlpr) 
               (-o mqlpr nl rr)  
               (split rr r '() rh) 
               (divo nh m qh rh)))))))))




'(define divo
  (lambda (n m q r)
    (condi
      ((== '(1) m) (== n q) (== '() r))
      ((>1o m) (== r n) (== '() q) (<o n m))
      ((>1o m) (== '(1) q) (=ol n m) (+o r m n)
       (<o r m))
      ((>1o m) (<ol m n) (<o r m) (poso q) 
       (fresh (nl nh ql qh mql)
         (split n r nl nh)
         (split q r ql qh)
         (xo m ql mql)
         (conde
           ((== '() nh) (== '() qh)
            (+o mql r nl)) 
           (else
             (fresh (mqlpr rr rh)
               (poso nh) 
               (xo m ql mql) 
               (+o mql r mqlpr) 
               (-o mqlpr nl rr)  
               (split rr r '() rh) 
               (divo nh m qh rh)))))))))


'(define divo
  (lambda (n m q r)
    (condi
      ((== '(1) m) (== n q) (== '() r))
      ((>1o m) (== m n) (== '(1) q) (== '() r))      
      ((>1o m) (== r n) (== '() q) (<o n m))
      ((>1o m) (== '(1) q) (=ol n m) (poso r) (+o r m n)
       (<o r m))
      ((>1o m) (<ol m n) (<o r m) (poso q) 
       (fresh (nl nh ql qh mql)
         (split n r nl nh)
         (split q r ql qh)
         (xo m ql mql)
         (conde
           ((== '() nh) (== '() qh)
            (+o mql r nl)) 
           (else
             (fresh (mqlpr rr rh)
               (poso nh) 
               (xo m ql mql) 
               (+o mql r mqlpr) 
               (-o mqlpr nl rr)  
               (split rr r '() rh) 
               (divo nh m qh rh)))))))))

(define interesting?
  (lambda (x)
    (cond
      [(var? x) #t]
      [(pair? x) (interesting? (cdr x))]
      [else #f])))

(define theorem?
  (lambda (ls)
    (cond
      [(null? ls) #f]
      [(pair? ls) (or (interesting? (car ls)) (theorem? (cdr ls)))]
      [else #f])))




(define theoremo
  (lambda (ls)
    (condu
      [(nullo ls) fail]
      [(pairo ls)
       (condu
         [(fresh (a)
            (caro ls a)
            (interestingo a))
          succeed]
         [(fresh (d)
            (cdro ls d)
            (theoremo d))
          succeed])]
      [else fail])))

(define interestingo
  (lambda (x)
    (condu
      [(== (gensym) x) fail]
      [(pairo x)
       (fresh (d)
         (cdro x d)
         (interestingo d))]
      [else fail])))





(define <=ol
  (lambda (n m)
    (condi
      [(=ol n m) succeed]
      [(<ol n m) succeed])))

'(define divo
  (lambda (n m q r)
    (condi
      [(== '() q) (== n r) (<o n m)]
      [(== '(1) q) (== '() r) (== n m) (<o r m)]      
      [(<o m n) (<o r m)
       (fresh (mq)
         (<=ol mq n)
         (xo m q mq)
         (+o mq r n))])))

(define divo
  (lambda (n m q r)
    (condi
	; m has more digits than n: q=0,n=r
      [(== r n) (== q '()) (<o n m)] ; if n < m, then q=0, n=r
      ; n is at least m and has the same number of digits than m
      [(== q '(1)) (=ol n m) (+o r m n) (<o r m)]
      [else
        (alli
          (<ol m n)			; n has more digits than m
          (<o r m)			; r is L-instantiated
          (poso q)     	    ; q must be positive then
          (fresh (nh nl qh ql qlm qlmr rr rh)
            (alli
              (split n r nl nh)
              (split q r ql qh)
              (conde
                [(== nh '())
		         (== qh '())
		         (-o nl r qlm)
		         (xo ql m qlm)]
                [(alli (poso nh)
		           (xo ql m qlm)
		           (+o qlm r qlmr)
		           (-o qlmr nl rr)		; rr = ql*m + r - nl
		           (split rr r '() rh)		; rh = rr/2^(l+1), evenly
		           (divo nh m qh rh))]))))])))

; split n r n1 n2
; holds if n = 2^(l+1)*n1 + n2 where l = bitlength(r)
; This relation makes sense to use only when 'r' is L-instantiated
; (see the Prolog code file for the definition of L-instantiated).
; In that case, the relation has only the finite number of answers, in
; all of which n2 is L-instatantiated.
; We take trouble to assure that we produce only well-formed numbers:
; the major bit must be one.

(define split
  (lambda (n r nl nh)
    (condi
      [(== '() n) (== '() nh) (== '() nl)]
      [(fresh (b n^)
         (== `(0 ,b . ,n^) n)
         (== '() r)
         (== `(,b . ,n^) nh)
         (== '() nl))]
      [(fresh (n^)
         (==  `(1 . ,n^) n)
         (== '() r)
         (== n^ nh)
         (== '(1) nl))]
      [(fresh (b n^ r^ _)
         (== `(0 ,b . ,n^) n)
         (== `(,_ . ,r^) r)
         (== '() nl)
         (split `(,b . ,n^) r^ '() nh))]
      [(fresh (n^ r^ _)
         (== `(1 . ,n^) n)
         (== `(,_ . ,r^) r)
         (== '(1) nl)
         (split n^ r^ '() nh))]
      [(fresh (b n^ r^ nl^ _)
         (== `(,b . ,n^) n)
         (== `(,_ . ,r^) r)
         (== `(,b . ,nl^) nl)
         (poso nl^)
         (split n^ r^ nl^ nh))])))

(define split
  (lambda (n r l h)
    (condi
      ((== '() n) (== '() h) (== '() l))
      ((fresh (b n^)
         (== `(0 ,b . ,n^) n)
         (== '() r)
         (== `(,b . ,n^) h)
         (== '() l)))
      ((fresh (n^)
         (==  `(1 . ,n^) n)
         (== '() r)
         (== n^ h)
         (== '(1) l)))
      ((fresh (b n^ r^ _)
         (== `(0 ,b . ,n^) n)
         (== `(,_ . ,r^) r)
         (== '() l)
         (split `(,b . ,n^) r^ '() h)))
      ((fresh (n^ r^ _)
         (== `(1 . ,n^) n)
         (== `(,_ . ,r^) r)
         (== '(1) l)
         (split n^ r^ '() h)))
      ((fresh (b n^ r^ l^ _)
         (== `(,b . ,n^) n)
         (== `(,_ . ,r^) r)
         (== `(,b . ,l^) l)
         (poso l^)
         (split n^ r^ l^ h))))))


(define count-up
  (lambda (i n)
    (conde
      ((== i n) succeed)
      (else (count-up (+ i 1) n)))))


(display "------- testing split -------")
(newline)

(test-check 'split-1
  (run 5 (q) (fresh (x y) (split (build 4) '() x y) (== `(,x ,y) q)))   
  '((() (0 1))))
(test-check 'split-2
  (run 5 (q) (fresh (x y) (split (build 4) '(1) x y) (== `(,x ,y) q)))   
  '((() (1))))
(test-check 'split-3
  (run 5 (q) (fresh (x y) (split (build 4) '(1 1) x y) (== `(,x ,y) q)))   
  '(((0 0 1) ())))
(test-check 'split-4
  (run 5 (q) (fresh (x y) (split (build 4) '(1 1 1) x y) (== `(,x ,y) q)))   
  '(((0 0 1) ())))
(test-check 'split-5
  (run 5 (q) (fresh (x y) (split (build 5) '(1) x y) (== `(,x ,y) q)))   
  '(((1) (1))))
(test-check 'split-6
  (run 5 (q) (split q (build 5) '(1) '()))   
  '((1)))
(test-check 'split-7
  (run 5 (q) (split q '(0 0 0) '(1) '()))   
  '((1)))

;;;  Losers!!!!!

(display "------- testing losers -------")
(newline)

;; get (1 6) and (6 1) before infinite loop.
(test-check "multiplication-all-1"
  (map (lambda (e) (map trans e))
  (run 10 (x)
      (fresh (y z)
        (xo y z (build 6))
	(== (list y z) x))))
  '((1 6) (6 1) (2 3) (3 2)))


; Takes too long, but works
'(test-check "multiplication-all-2"
  (map (lambda (e) (map trans e))
  (run 10 (x)
      (fresh (y z)
        (xo y z (build 24))
         (== (list y z) x))))    
  '((1 24) (24 1) (2 12) (3 8) (4 6) (6 4) (8 3) (12 2)))
#!eof
(cout "Testing strong commutativity with 1" nl)
(pretty-print
  (run 6 (q)
      (fresh (a b c t)
       (alli
          (+o '(1) a t)
          (+o t b c)
          (== `(,a ,b ,c) q)
         ;(trace-vars 1 (a b c))
           (fresh (x y z t)
             (alli (+o x '(1) t)
               (+o t y z))
             (== x b)
             (== y a)
             (== z c))))))

; (pretty-print
;   (run 2 (q)
;       (fresh (a b c t)
;        (alli
;           (+o '(1) a t)
;           (+o t b c)
;           (== `(,a ,b ,c) q)
;          (trace-vars 1 (a b c))
;          (begin ;once
;            (fresh (x y z t)
;              (alli (+o x '(1) t)
;                (+o t y z))
; 	     (trace-vars 2 (y x z))
;              (== x b)
;              (== y a)
;              (== z c))))))    )

; (pretty-print
;   (run 10 (q)
;       (fresh (a b c t)
;        (alli
;           (+o '(1) a t)
;           (+o t b c)
;           (== `(,a ,b ,c) q)
;          ;(trace-vars 1 (a b c))
; 	 )
;          (begin ; once
;            (fresh (x y z t)
;              (alli (+o x '(1) t)
;                (+o t y z))
; 	   (trace-vars 2 (y x z))
;              (== x b)
;              (== y a)
;              (== z c)))))    )

; (pretty-print
;   (run 20 (q)
;       (fresh (a b c t)
;        (alli
;           (+o '(1) a t)
;           (+o t b c)
;           (== `(,a ,b ,c) q)))))

; '((() () (1))
;  ((1) () (0 1))
;  (() (1) (0 1))
;  ((0 _.0 . _.1) () (1 _.0 . _.1))
;  (() (0 _.0 . _.1) (1 _.0 . _.1))
;  ((1) (1) (1 1))
;  (() (1 1) (0 0 1))
;  ((1 1) () (0 0 1))
;  (() (1 0 _.0 . _.1) (0 1 _.0 . _.1))
;  ((1) (0 1) (0 0 1)))

; ; The following test should give at least one 5, if everything is to work
; (run 5 (q) (condi (always) 
; 	     (else (condi (fail) (fail) (fail) (else (== q 5))))))

(define compositeo
  (lambda (n)
    (fresh (x y)
      (>1o n)
      (>1o x)
      (>1o y)
      (xo x y n))))

(define bump
  (lambda (n x)
    (conde
      ((== n x) succeed)
      (else
        (fresh (m)
          (-o n '(1) m)
          (bump m x))))))


;; Generate all composite numbers up to 20.
(test-check "compositeo"
  (run* (q)
    (bump (build 20) q)
    (once (compositeo q)))
  '((0 0 1 0 1)
    (0 1 0 0 1)
    (0 0 0 0 1)
    (1 1 1 1)
    (0 1 1 1)
    (0 0 1 1)
    (0 1 0 1)
    (1 0 0 1)
    (0 0 0 1)
    (0 1 1)
    (0 0 1)))

(define any*
  (lambda (a)
    (conde
      (a succeed)
      (else (any* a)))))

(define always (any* succeed))

'(run 1 (q)
    (all
      (conde
        ((== 0 q) succeed)
        ((== 1 q) succeed))
      always)
    (== 1 q))  

;;; Winners!!


(display "**** testing winners *****")
(newline)


(display "testing div-even")
(newline)

(test-check "div-even"  ;; this loops indefinitely.
  (run 5 (w)
      (fresh (y z r)
        (divo `(0 . ,y) (build 2) z r)
        (== `((0 . ,y) ,(build 2) ,z ,r) w)))    
  '(((0 1) (0 1) (1) ())
    ((0 0 1) (0 1) (0 1) ())
    ((0 1 1) (0 1) (1 1) ())
    ((0 0 0 1) (0 1) (0 0 1) ())
    ((0 1 0 0 1) (0 1) (1 0 0 1) ())))

;; infinite loop(run 1 (q) (fresh (y z r) (divo `(0 0 . ,y) (build 2) z r))) 

;; infinite loop(run 1 (q) (fresh (y r) (divo `(0 0 . ,y) '(0 1) '(0 1) r))) 

;; this works(run 1 (q) (fresh (y r) (divo `(0 0 . ,y) '(0 1) q '()))) 

;; this works(run 1 (q) (divo `(0 0 . ,q) '(0 1) '(0 1) '())) 

;;; winners

(cout "Testing strong commutativity" nl)
(pretty-print
  (run 50 (q)
      (fresh (a b c)
        (+o a b c)
          (== `(,a ,b ,c) q)
          (once
            (fresh (x y z)
              (+o x y z)
              (== x b)
              (== y a)
              (== z c)))))    )


(test-check "addition"
  (run 1 (q)
      (fresh (x)
        (+o (build 29) (build 3) x)
        (project (x) (== (trans x) q))))    
  '(32))

(test-check "addition2"
  (run 1 (q)
      (fresh (x)
        (+o (build 3) x (build 29))
        (project (x)
          (== (trans x) q))))    
  '(26))

(test-check "all numbers that sum to 4"
  (run 10 (w)
    (fresh (y z)
      (+o y z (build 4))
      (project (y z) 
        (== `(,(trans y) ,(trans z)) w))))    
 '((4 0) (0 4) (1 3) (3 1) (2 2)))
 
(test-check "print a few numbers such as X + 1 = Y"
  (run 5 (w)
      (fresh (x y)
        (+o x (build 1) y) (== `(,x ,y) w)))    
  '((() (1))
    ((1) (0 1))
    ((0 _.0 . _.1) (1 _.0 . _.1))
    ((1 1) (0 0 1))
    ((1 0 _.0 . _.1) (0 1 _.0 . _.1)))
  ) ; 1 added to an odd is an even.

(test-check "subtraction-1"
  (run 1 (q)
      (fresh (x)
        (-o (build 29) (build 3) x)
        (project (x)
          (== (trans x) q))))    
  '(26))

(test-check "subtraction-2"
  (run 1 (q)
      (fresh (x)
        (-o (build 29) x (build 3))
        (project (x)
          (== (trans x) q))))    
  '(26))

(test-check "subtraction-3"
  (run 1 (q)
      (fresh (x)
        (-o x (build 3) (build 26))
        (project (x)
          (== (trans x) q))))    
  '(29))

(test-check "subtraction-4"
  (run 1 (q)
      (fresh (x)
        (-o (build 29) (build 29) x)
        (project (x)
          (== (trans x) q))))    
  '(0))

(test-check "subtraction-5"
  (run 1 (q)
      (fresh (x)
        (-o (build 29) (build 29) x)
        (project (x)
          (== (trans x) q))))    
  '(0))

(test-check "subtraction-6"
  (run 1 (q)
      (fresh (x)
        (-o (build 29) (build 30) x)
        (project (x)
          (== (trans x) q))))    
  ())

(test-check "print a few numbers such as y - z = 4"
  (run 15 (w)
      (fresh (x y)
        (-o x y (build 4))
        (== `(,x ,y) w)))    
  '(((0 0 1) ())
    ((1 0 1) (1))
    ((0 1 1) (0 1))
    ((1 1 1) (1 1))
    ((0 0 0 1) (0 0 1))
    ((1 0 0 1) (1 0 1))
    ((0 1 0 1) (0 1 1))
    ((1 1 0 1) (1 1 1))
    ((0 0 1 _.0 . _.1) (0 0 0 _.0 . _.1))
    ((1 0 1 _.0 . _.1) (1 0 0 _.0 . _.1))
    ((0 1 1 _.0 . _.1) (0 1 0 _.0 . _.1))
    ((1 1 1 _.0 . _.1) (1 1 0 _.0 . _.1))
    ((0 0 0 0 1) (0 0 1 1))
    ((1 0 0 0 1) (1 0 1 1))
    ((0 1 0 0 1) (0 1 1 1))))

(test-check "print a few numbers such as x - y = z"
  (run 15 (w)
      (fresh (x y z)
        (-o x y z)
        (== `(,x ,y ,z) w)))    
  '((_.0 _.0 ())
   ((_.0 . _.1) () (_.0 . _.1))
   ((0 1) (1) (1))
   ((1 _.0 . _.1) (1) (0 _.0 . _.1))
   ((1 _.0 . _.1) (0 _.0 . _.1) (1))
   ((0 0 1) (1) (1 1))
   ((0 0 1) (0 1) (0 1))
   ((0 1 _.0 . _.1) (1) (1 0 _.0 . _.1))
   ((0 0 1) (1 1) (1))
   ((0 0 0 1) (1) (1 1 1))
   ((1 0 1) (1 1) (0 1))
   ((0 0 1 _.0 . _.1) (1) (1 1 0 _.0 . _.1))
   ((0 1 _.0 . _.1) (1 0 _.0 . _.1) (1))
   ((0 0 0 0 1) (1) (1 1 1 1))
   ((0 1 _.0 . _.1) (0 1) (0 0 _.0 . _.1))))

(newline)




(test-check "division-7"
  (run 1 (q)
      (fresh (x _)
        (divo x (build 3) (build 11) _)
        (project (x)
          (== (trans x) q))))    
  '(33))






(test-check "times-0-0"
  (run* (q) (xo (build 0) (build 0) q))
  '(()))

(test-check "times-1-1"
  (run* (q) (xo (build 1) (build 1) q))
  '((1)))

(test-check "times-2-2"
  (run* (q) (xo (build 2) (build 2) q))
  '((0 0 1)))

(test-check "times-0-1"
  (run* (q) (xo (build 0) (build 1) q))
  '(()))

(test-check "times-1-2"
  (run* (q) (xo (build 1) (build 2) q))
  '((0 1)))

(test-check "times-2-3"
  (run* (q) (xo (build 2) (build 3) q))
  '((0 1 1)))

(test-check "times-3-3"
  (run* (q) (xo (build 3) (build 3) q))
  '((1 0 0 1)))

(test-check "gt1test1"
  (run* (q) (>1o q))
  '((_.0 _.1 . _.2)))

(test-check "postest1"
  (run* (q) (poso q))
  '((_.0 . _.1)))

;;;  alli is not in the book yet
'(cout "Test recursive enumerability of alli" nl)
'(let ((n 7))
  (do ((i 0 (+ 1 i))) ((> i n))
    (do ((j 0 (+ 1 j))) ((> j n))
      (test-check
        (string-append "alli enumerability: " (number->string i)
          " " (number->string j))
        (run 1 (q)
            (fresh (x y)
              (alli (count-up 0 x) (count-up 0 y))
              (== x i)
              (== y j)
              (== `(,x ,y) q)))          
        `((,i ,j))
        ()))))

(cout "testing 3 * q = 6\n")
(pretty-print 
  (run 1 (q) (xo (build 3) q (build 6)))    )

(test-check "comparison-1"
  (run 1 (q)
      (fresh (x)
        (<o x (build 4))
        (project (x)
          (== (trans x) q))))    
  '(0))

(test-check "comparison-2"
  (run 1 (q)
      (fresh (x)
        (== x (build 3))
        (<o x (build 4))
        (project (x)
          (== (trans x) q))))    
  '(3))

(test-check "comparison-3"
  (run 1 (q)
      (fresh (x)
        (== x (build 4))
        (<o x (build 3))
        (project (x)
          (== (trans x) q))))    
  ())

;#!eof
;(run 1 (q) (fresh (x y) (<o q q)))
;;; (test-check "comparison-4"   ())

(test-check "comparison-5"
  (run 10 (q) (fresh (x y) (<o x y) (== `(,x ,y) q)))   
  '((() (_.0 . _.1))
    ((0 1) (1 1))
    ((1) (_.0 _.1 . _.2))
    ((0 _.0 1) (1 _.0 1))
    ((_.0 1) (_.1 _.2 _.3 . _.4))
    ((0 0 1) (0 1 1))
    ((_.0 _.1 1) (_.2 _.3 _.4 _.5 . _.6))
    ((1 0 1) (0 1 1))
    ((_.0 _.1 _.2 1) (_.3 _.4 _.5 _.6 _.7 . _.8))
    ((1 0 1) (1 1 1))))

(test-check "comparison-6"
  (run 10 (q) (fresh (x y) (<o `(0 . ,x) `(1 . ,y)) (== `(,x ,y) q)))   
  '(((1) (_.0 _.1 . _.2))
    ((1) (1))
    ((_.0 1) (_.1 _.2 _.3 . _.4))
    ((_.0 1) (_.0 1))
    ((_.0 _.1 1) (_.2 _.3 _.4 _.5 . _.6))
    ((0 1) (1 1))
    ((_.0 _.1 _.2 1) (_.3 _.4 _.5 _.6 _.7 . _.8))
    ((_.0 _.1 1) (_.0 _.1 1))
    ((_.0 _.1 _.2 _.3 1) (_.4 _.5 _.6 _.7 _.8 _.9 . _.10))
    ((0 _.0 1) (1 _.0 1))))

(test-check "comparison-7"
  (run 10 (q) (fresh (x y) (<o `(1 . ,x) `(1 . ,y)) (== `(,x ,y) q)))    
  '((() (_.0 . _.1))
    ((0 1) (1 1))
    ((1) (_.0 _.1 . _.2))
    ((0 _.0 1) (1 _.0 1))
    ((_.0 1) (_.1 _.2 _.3 . _.4))
    ((0 0 1) (0 1 1))
    ((_.0 _.1 1) (_.2 _.3 _.4 _.5 . _.6))
    ((1 0 1) (0 1 1))
    ((_.0 _.1 _.2 1) (_.3 _.4 _.5 _.6 _.7 . _.8))
    ((1 0 1) (1 1 1))))

(define inf-loop-again
  (lambda ()
    (run 10 (q) (fresh (x y) (<o `(0 . ,q) `(1 . ,q))))      ))

(define inf-loop-again
  (lambda ()
    (run 1 (q) (fresh (x y) (<ol q q)))      ))

(test-check "comparison-10"
  (run 10 (q)
      (fresh (x y) (<ol x y) (== `(,x ,y) q)))    
  '((() (_.0 . _.1))
    ((1) (_.0 _.1 . _.2))
    ((_.0 1) (_.1 _.2 _.3 . _.4))
    ((_.0 _.1 1) (_.2 _.3 _.4 _.5 . _.6))
    ((_.0 _.1 _.2 1) (_.3 _.4 _.5 _.6 _.7 . _.8))
    ((_.0 _.1 _.2 _.3 1) (_.4 _.5 _.6 _.7 _.8 _.9 . _.10))
    ((_.0 _.1 _.2 _.3 _.4 1) (_.5 _.6 _.7 _.8 _.9 _.10 _.11 . _.12))
    ((_.0 _.1 _.2 _.3 _.4 _.5 1) (_.6 _.7 _.8 _.9 _.10 _.11 _.12 _.13 . _.14))
    ((_.0 _.1 _.2 _.3 _.4 _.5 _.6 1)
     (_.7 _.8 _.9 _.10 _.11 _.12 _.13 _.14 _.15 . _.16))
    ((_.0 _.1 _.2 _.3 _.4 _.5 _.6 _.7 1)
     (_.8 _.9 _.10 _.11 _.12 _.13 _.14 _.15 _.16 _.17 . _.18))))

(test-check "comparison-12"
  (run 10 (q) (fresh (x y) (<ol `(1 . ,x) `(1 . ,y)) (== `(,x ,y) q)))    
  '((() (_.0 . _.1))
    ((1) (_.0 _.1 . _.2))
    ((_.0 1) (_.1 _.2 _.3 . _.4))
    ((_.0 _.1 1) (_.2 _.3 _.4 _.5 . _.6))
    ((_.0 _.1 _.2 1) (_.3 _.4 _.5 _.6 _.7 . _.8))
    ((_.0 _.1 _.2 _.3 1) (_.4 _.5 _.6 _.7 _.8 _.9 . _.10)) 
    ((_.0 _.1 _.2 _.3 _.4 1) (_.5 _.6 _.7 _.8 _.9 _.10 _.11 . _.12))
    ((_.0 _.1 _.2 _.3 _.4 _.5 1) (_.6 _.7 _.8 _.9 _.10 _.11 _.12 _.13 . _.14))
    ((_.0 _.1 _.2 _.3 _.4 _.5 _.6 1)
     (_.7 _.8 _.9 _.10 _.11 _.12 _.13 _.14 _.15 . _.16))
    ((_.0 _.1 _.2 _.3 _.4 _.5 _.6 _.7 1) 
     (_.8 _.9 _.10 _.11 _.12 _.13 _.14 _.15 _.16 _.17 . _.18))))

(define infinite-loop-again
  (lambda ()
    (run 1 (q)
        (fresh (x y)
          (<ol `(0 . ,q) `(1 . ,q))))      ))

(test-check "print some numbers x that are less than y"
  (run 9 (q) (fresh (x y) (<o x y) (== `(,x ,y) q)))   
  '((() (_.0 . _.1))
    ((0 1) (1 1))
    ((1) (_.0 _.1 . _.2))
    ((0 _.0 1) (1 _.0 1))
    ((_.0 1) (_.1 _.2 _.3 . _.4))
    ((0 0 1) (0 1 1))
    ((_.0 _.1 1) (_.2 _.3 _.4 _.5 . _.6))
    ((1 0 1) (0 1 1))
    ((_.0 _.1 _.2 1) (_.3 _.4 _.5 _.6 _.7 . _.8))))

(test-check "infinite loop for addition?"
  (run 1 (q)
      (fresh (_ __)
        (+o q `(1 0 ,_ . ,__) `(1 1 ,_ . ,__))))    
  '((0 1)))

(test-check "print all numbers less than 6"
  (run 10 (x) (<o x (build 6)))   
  '(() (1 0 1) (1) (0 0 1) (_.0 1)))

(test-check "print a few numbers that are greater than 4"
  (run 10 (x)
      (<o (build 4) x)) 
   '((_.0 _.1 _.2 _.3 . _.4) (1 0 1) (0 1 1) (1 1 1)))

(if (not tex)
  (begin
    (display "Test recursive enumerability")
    (newline)))

(let ((n 7))
  (do ((i 0 (+ 1 i))) ((> i n))
    (do ((j 0 (+ 1 j))) ((> j n))
      (let ((p (* i j)))
            (test-check
              (string-append "enumerability: " (number->string i)
                "*" (number->string j) "=" (number->string p))
            (run 1 (q) 
                (fresh (x y z) 
                  (xo x y z)
                  (== (build i) x)
                  (== (build j) y)
                  (== (build p) z)
                  (== `(,x ,y ,z) q)))              
            `((,(build i) ,(build j) ,(build p))))))))

(define sad-to-see-this-go
  '((__.0 __.1 _.0 _.1 . __.2) (1 0 1) (__.0 1 1)))

(test-check "multiplication-1"
  (run 1 (q)
      (fresh (x)
        (xo (build 2) (build 3) x)
        (project (x)
          (== (trans x) q))))    
  '(6))

(test-check "multiplication-2"
  (run 1 (q)
      (fresh (x)
        (xo (build 3) x (build 12))
        (project (x)
          (== (trans x) q))))    
  '(4))

(test-check "multiplication-3"
  (run 1 (q)
      (fresh (x)
        (xo x (build 3) (build 12))
        (project (x)
          (== (trans x) q))))    
  '(4))

(test-check "multiplication-4"
  (run 1 (q)
      (fresh (x)
        (xo x (build 5) (build 12))))    
  ())

(test-check "multiplication-5"
  (run 1 (q)
      (fresh (x)
        (== x (build 2))
        (xo x (build 2) (build 4))
        (project (x)
          (== (trans x) q))))    
  '(2))

(test-check "multiplication-6"
  (run 1 (q)
      (fresh (w x y z)
        (xo `(0 ,x ,y . ,z) `(,w 1) `(1 ,x ,y . ,z))))    
  ())

(test-check "multiplication-fail-1"
  (run 1 (q)
      (fresh (x)
        (== x (build 3))
        (xo x (build 2) (build 4))
        (project (x)
          (== (trans x) q))))    
  ())

(test-check "multiplication-all-3"
  (run 7 (x)        
      (fresh (y z)
        (xo (build 3) y z)
        (project (y z)
          (== `(,(trans y) ,(trans z)) x))))    
  '((0 0) (1 3) (2 6) (3 9) (4 12) (5 15) (6 18)))

(test-check "multiplication-all-4"
  (run 5 (x)        
      (fresh (y z)
        (xo y (build 3) z)
        (project (y z)
          (== `(,(trans y) ,(trans z)) x))))    
  '((0 0) (1 3) (2 6) (3 9) (4 12)))

(test-check "multiplication-all-5"
  (run 26 (q)        
      (fresh (x y z)
        (xo x y z)
        (== `(,x ,y ,z) q)))    
  '((() _.0 ())
    ((_.0 . _.1) () ())
    ((1) (_.0 . _.1) (_.0 . _.1))
    ((_.0 _.1 . _.2) (1) (_.0 _.1 . _.2))
    ((0 1) (_.0 _.1 . _.2) (0 _.0 _.1 . _.2))
    ((1 _.0 . _.1) (0 1) (0 1 _.0 . _.1))
    ((0 0 1) (_.0 _.1 . _.2) (0 0 _.0 _.1 . _.2))
    ((1 1) (1 1) (1 0 0 1))
    ((0 1 _.0 . _.1) (0 1) (0 0 1 _.0 . _.1))
    ((1 _.0 . _.1) (0 0 1) (0 0 1 _.0 . _.1))
    ((0 0 0 1) (_.0 _.1 . _.2) (0 0 0 _.0 _.1 . _.2))
    ((1 1) (1 0 1) (1 1 1 1))
    ((0 1 1) (1 1) (0 1 0 0 1))
    ((1 1) (0 1 1) (0 1 0 0 1))
    ((0 0 1 _.0 . _.1) (0 1) (0 0 0 1 _.0 . _.1))
    ((1 1) (1 1 1) (1 0 1 0 1))
    ((0 1 _.0 . _.1) (0 0 1) (0 0 0 1 _.0 . _.1))
    ((1 _.0 . _.1) (0 0 0 1) (0 0 0 1 _.0 . _.1)) 
    ((0 0 0 0 1) (_.0 _.1 . _.2) (0 0 0 0 _.0 _.1 . _.2))
    ((1 0 1) (1 1) (1 1 1 1))
    ((0 1 1) (1 0 1) (0 1 1 1 1))
    ((1 0 1) (0 1 1) (0 1 1 1 1))
    ((0 0 1 1) (1 1) (0 0 1 0 0 1))
    ((1 1) (1 0 0 1) (1 1 0 1 1)) 
    ((0 1 1) (0 1 1) (0 0 1 0 0 1))
    ((1 1) (0 0 1 1) (0 0 1 0 0 1))))

(test-check "multiplication-even-1"
  (run* (q)        
    (fresh (y z)
      (xo (build 2) y z)
      (== `(,y ,z) q)))
  '((() ()) ((1) (0 1)) ((_.0 _.1 . _.2) (0 _.0 _.1 . _.2))))

(test-check "division-1"
  (run 1 (q)
      (fresh (x _)
        (divo (build 4) (build 2) x _)
        (project (x)
          (== (trans x) q))))    
  '(2))

(test-check "division-fail-1"
  (run 1 (q)
      (fresh (x _)
        (divo (build 4) (build 0) x _)
        (project (x)
          (== (trans x) q))))    
  ())

(test-check "division-2"
  (run 1 (q)
      (fresh (x _)
        (all
          (divo (build 4) (build 3) x _)
          (project (x)
            (== (trans x) q)))))    
  '(1))

(test-check "division-3"
  (run 1 (q)
      (fresh (x _)
        (divo (build 4) (build 4) x _)
        (project (x)
          (== (trans x) q))))    
  '(1))

(test-check "division-4"
  (run 1 (q)
      (fresh (x _)
        (divo (build 4) (build 5) x _)
        (project (x)
          (== (trans x) q))))    
  '(0))

(test-check "division-5"
  (run 1 (q)
      (fresh (x _)
        (divo (build 33) (build 3) x _)
        (project (x)
          (== (trans x) q))))    
  '(11))

(test-check "remainder-4"
  (run 1 (q)
      (fresh (x _)
        (divo (build 4) (build 5) _ x)
        (project (x)
          (== (trans x) q))))    
  '(4))

(test-check "division-5"
  (run 1 (q)
      (fresh (x _)
        (divo (build 33) (build 3) x _)
        (project (x)
          (== (trans x) q))))    
  '(11))

(test-check "division-6"
  (run 1 (q)
      (fresh (x _)
        (divo (build 33) x (build 11) _)
        (project (x)
          (== (trans x) q))))    
  '(3))


(test-check "division-8"
  (run 1 (q)
      (fresh (x _)
        (divo x (build 5) _ (build 4))
        (project (x)
          (== (trans x) q))))    
  '(4))

(test-check "division-9"
  (run 1 (q)
      (fresh (x _)
        (divo x (build 5) (build 3) (build 4))
        (project (x)
          (== (trans x) q))))    
  '(19))

(test-check "division-10"
  (run 1 (q)
      (fresh (x _)
        (divo x _ (build 3) (build 4))
        (project (x)
          (== (trans x) q))))    
  '(19))

(test-check "division-fail-2"
  (run 1 (q)
      (fresh (x _)
        (divo (build 5) x (build 7) _)
        (project (x)
          (== (trans x) q))))    
  ())

(test-check "division-11"
  (run 1 (q)
      (fresh (x _)
        (divo (build 33) (build 5) x _)
        (project (x)
           (== (trans x) q))))    
  '(6))

(test-check "all numbers such as 5/Z = 1"
  (run 5 (q)        
      (fresh (z _)
        (divo (build 5) z (build 1) _)
        (project (z)
          (== (trans z) q))))    
  '(5 3 4))
;; Should not have any duplicates!


(cout "Testing strong multiplicative commutativity" nl)
(pretty-print
  (run 30 (q)
      (fresh (a b c)
        (xo a b c)
          (== `(,a ,b ,c) q)
          (once
            (fresh (x y z)
              (xo x y z)
              (== x b)
              (== y a)
              (== z c)))))    )


(test-check "div-all-3"
  (run 12 (w)
      (fresh (x y z r)
        (divo x y z r)
        (== `(,x ,y ,z ,r) w)))    
  '((() (_.0 . _.1) () ())
    ((1) (1) (1) ())
    ((0 1) (1 1) () (0 1))
    ((0 1) (1) (0 1) ())
    ((1) (_.0 _.1 . _.2) () (1))
    ((_.0 1) (_.0 1) (1) ())
    ((0 _.0 1) (1 _.0 1) () (0 _.0 1))
    ((0 _.0 1) (_.0 1) (0 1) ())
    ((_.0 1) (_.1 _.2 _.3 . _.4) () (_.0 1))
    ((1 1) (0 1) (1) (1))
    ((0 0 1) (0 1 1) () (0 0 1))
    ((1 1) (1) (1 1) ())))

(define old-div-all-3
  (lambda ()
  '((() (_.0 . __.0) () ())
    ((_.0 1) (1) (_.0 1) ())
    ((1) (_.0 _.1 . __.0) () (1))
    ((1) (1) (1) ())
    ((_.0 1) (__.0 _.1 _.2 . __.1) () (_.0 1))
    ((_.0 _.1 1) (1) (_.0 _.1 1) ())
    ((_.0 _.1 1) (__.0 __.1 _.2 _.3 . __.2) () (_.0 _.1 1))
    ((0 1) (1 1) () (0 1))
    ((_.0 _.1 _.2 1) (__.0 __.1 __.2 _.3 _.4 . __.3) () (_.0 _.1 _.2 1))
    ((_.0 _.1 _.2 1) (1) (_.0 _.1 _.2 1) ())
    ((_.0 _.1 _.2 _.3 1) (__.0 __.1 __.2 __.3 _.4 _.5 . __.4) () (_.0 _.1 _.2 _.3 1))
    ((__.0 1) (__.0 1) (1) ()))))

;    ((1 __.0 1) (0 __.0 1) (1) (1))    
;    ((1 __.0 c.0 1) (0 __.0 c.0 1) (1) (1))
;    ((1 __.0 c.0 _.0 1) (0 __.0 c.0 _.0 1) (1) (1))





(define 4ref
  '(((0 1) (0 1) ())
    ((1) (1) ())
    ((1 1) (1 1) ())
    ((0 _.0 1) (0 _.0 1) ())
    ((1 _.0 1) (1 _.0 1) ())))

(define 4ref
  '(((1) (1) ()) ((_.0 __.0 . ___.0) (_.0 __.0 . ___.0) ())))

(test-check "mul-even"
  (run 10 (q)
      (fresh (x y)
        (xo x (build 2) `(0 . ,y))
        (== `(,x ,y) q)))    
  '(((1) (1))
    ((0 1) (0 1))
    ((1 _.0 . _.1) (1 _.0 . _.1)) 
    ((0 0 1) (0 0 1))
    ((0 1 _.0 . _.1) (0 1 _.0 . _.1))
    ((0 0 0 1) (0 0 0 1))
    ((0 0 1 _.0 . _.1) (0 0 1 _.0 . _.1))
    ((0 0 0 0 1) (0 0 0 0 1))
    ((0 0 0 1 _.0 . _.1) (0 0 0 1 _.0 . _.1))
    ((0 0 0 0 0 1) (0 0 0 0 0 1))))

(pretty-print
 (run 10 (q)
     (fresh (x y z r)
       (divo x y z r)
       (== `(,x ,y ,z ,r) q)
        (project (q)
          (cond
            ((ground? q) succeed)
            (else fail))))))

(pretty-print
  (run 10 (q)
      (fresh (x y z r)
        (divo x y z r)
        (== `(,x ,y ,z ,r) q)
        (project (q)
          (cond
            ((ground? q) fail)
            (else succeed))))))


(define gen&test
   (lambda (op)
     (lambda (i j k)
       (once
         (fresh (x y z)
           (op x y z)
           (== i x)
           (== j y)
           (== k z))))))

(define enumerate
  (lambda (op)
    (lambda (r n)
      (fresh (i j k)
        (bump n i)
        (bump n j)
        (op i j k)
        ((gen&test op) i j k)
        (== `(,i ,j ,k) r)))))

(define test-enumerate
  (lambda (n)
    (run (expt (+ n 1) 2) (q)
         ((enumerate +o) q (build n)))))

(define test-enumerate
  (lambda (n op)
    (run (expt (+ n 1) 2) (q)
         ((enumerate op) q (build n)))))
      


;; Not so great--- (primeo v) always fails if v is a variable.
(define primeo
  (lambda (n)
    (fails (compositeo n))))

'(define x-always-0
  (lambda (x)
    (any
      (== 0 x)
      (x-always-0 x))))

(define x-always-0
  (lambda (x)
    (conde
      ((== 0 x))
      (else (x-always-0 x)))))


(cout "Test recursive enumerability (slow version) of addition" nl)
(let ((n 7))
  (do ((i 0 (+ 1 i))) ((> i n))
    (do ((j 0 (+ 1 j))) ((> j n))
      (let ((p (+ i j)))
        (test-check
          (string-append "enumerability: " (number->string i)
            "+" (number->string j) "=" (number->string p))
          (run 1 (q)
              (fresh (x y z) 
                (all
                  (+o x y z)
                  (== x (build i))
                  (== y (build j))
                  (== z (build p))
                  (== q (list x y z)))))            
          `((,(build i) ,(build j) ,(build p)))
          ())))))


(test-check "all inexact factorizations of 12"
  (run* (w)
    (fresh (m q r n)
      (== (build 12) n)
      (conde
        ((<o m n) succeed)
        (else (== m n)))
      (divo n m q r)
      (project (n m q r)
        (== `(,(trans n) ,(trans m) ,(trans q) ,(trans r)) w))))
  '((12 11 1 1)
    (12 1 12 0)
    (12 10 1 2)
    (12 3 4 0)
    (12 2 6 0)
    (12 9 1 3)
    (12 6 2 0)
    (12 5 2 2)
    (12 4 3 0)
    (12 7 1 5)
    (12 8 1 4)
    (12 12 1 0)))

'(cout "Test recursive enumerability of division" nl)
'(let ((n 4))
  (do ((m 1 (+ 1 m))) ((> m n))
    (do ((q 0 (+ 1 q))) ((> q n))
      (do ((r 0 (+ 1 r))) ((>= r m))
	(let ((n (+ (* m q) r)))
	 (test-check
       (string-append "enumerability: " (number->string n)
	    "=" (number->string m) "*" (number->string q)
	    "+" (number->string r))
	  (run 1 (ans)
          (fresh (n1 m1 q1 r1) 
            (divo n1 m1 q1 r1)
            (== n1 (build n)) 
            (== m1 (build m))
	        (== q1 (build q))
            (== r1 (build r))
            (== `(,n1 ,m1 ,q1 ,r1) ans)))        
      `((,(build n) ,(build m) ,(build q) ,(build r)))
       ()))))))

(define toggle
  (let ((tex (lambda (index)
               (string->symbol
                (string-append
                 "_$_{_{"
                 (number->string index)
                 "}}$"))))
        (no-tex (lambda (index)
                  (string->symbol
                   (string-append "_" (string #\.) (number->string index)))))
        (switch #t))
    (lambda ()
      (if switch
          (begin (set! switch (not switch)) (set! reify-id tex))
          (begin (set! switch (not switch)) (set! reify-id no-tex))))))

; Exponentiation and discrete logarithm
; n = b^q + r, where 0 <= r and q is the largest such integer
;
; From the above condition we obtain the upper bound on r:
; n >= b^q, n < b^(q+1) = b^q * b = (n-r)* b 
; r*b < n*(b-1)
;
; We can also obtain the bounds on q:
; if |b| is the bitwidth of b and |n| is the bitwidth of n,
; we have, by the definition of the bitwidth:
;  (1) 2^(|b|-1) <= b < 2^|b|
;  (2) 2^(|n|-1) <= n < 2^|n|
; Raising (1) to the power of q:
;      2^((|b|-1)*q) <= b^q
; OTH, b^q <= n, and n < 2^|n|. So we obtain
;  (3)   (|b|-1)*q < |n|
; which defines the upper bound on |q|.
; OTH, raising (1) to the power of (q+1):
;    b^(q+1) < 2^(|b|*(q+1))
; But n < b^(q+1) by definition of exponentiation, and keeping in mind (1)
; (4) |n|-1 < |b|*(q+1)
; which is the lower bound on q.

; When b = 2, exponentiation and discrete logarithm are easier to obtain
; n = 2^q + r, 0<= 2*r < n
; Here, we just relate n and q.
;    exp2 n b q
; holds if: n = (|b|+1)^q + r, q is the largest such number, and
; (|b|+1) is a power of two.
; Side condition: (|b|+1) is a power of two and b is L-instantiated.
; To obtain the binary exp/log relation, invoke the relation as
;  (exp2 n () q)
; Properties: if n is L-instantiated, one answer, q is fully instantiated.
; If q is fully instantiated: one answer, n is L-instantiated.
; In any event, q is always fully instantiated in any answer
; and n is L-instantiated.
; We depend on the properties of split.

(define append@
  (lambda (l1 l2 out)
    (conde
      ((nullo l1) (== l2 out))
      (else 
        (fresh (a d res)
          (conso a d l1)
          (append@ d l2 res)
          (conso a res out))))))

(define exp2
  (lambda (n b q)
    (condi
      [(== '(1) n) (== () q)]           ; 1 = b^0
      [(>1o n) (== '(1) q) (fresh (_) (split n b _ '(1)))]
      [(fresh (q1 b2)			; n = (2^k)^(2*q) + r
	     (alli                 ;   = (2^(2*k))^q + r
	       (== `(0 . ,q1) q)
	       (poso q1)
	       (<ol b n)
	       (append@ b `(1 . ,b) b2)
	       (exp2 n b2 q1)))
       succeed]
      [else 
        (fresh (q1 nh b2 _)		; n = (2^k)^(2*q+1) + r
	      (alli 		; n/(2^k) = (2^(2*k))^q + r'
	        (== `(1 . ,q1) q)
	        (poso q1)
	        (poso nh)
	        (split n b _ nh)
	        (append@ b `(1 . ,b) b2)
	        (exp2 nh b2 q1)))])))

(define exp2
  (lambda (n b q)
    (condi
      ((== '(1) n) (== () q))
      ((>1o n) (== '(1) q)
       (fresh (_)
         (split n b _ '(1))))
      ((fresh (q1 b2)                        
         (alli                 
           (== `(0 . ,q1) q)
           (poso q1)
           (<ol b n)
           (append@ b `(1 . ,b) b2)
           (exp2 n b2 q1)))
       succeed)
      (else
        (fresh (q1 nh b2 _)                
          (alli
            (== `(1 . ,q1) q)
            (poso q1)
            (poso nh)
            (split n b _ nh)
            (append@ b `(1 . ,b) b2)
            (exp2 nh b2 q1)))))))

; nq = n^q where n is L-instantiated and q is fully instantiated

(define repeated-mul
  (lambda (n q nq)
    (conde
      [(poso n) (== () q) (== '(1) nq)]
      [(== '(1) q) (== n nq)]
      [(>1o q)
       (fresh (q1 nq1)
         (+o q1 '(1) q)
         (repeated-mul n q1 nq1)
         (xo nq1 n nq))])))

(define expo ;;; This is the new one.
  (lambda (n b q r)
    (condi
      [(== '(1) n) (poso b) (== '() q) (== '() r)] ; 1 = b^0 + 0, b >0
      ; in the rest, b > 1
      [(== '() q)  (<o n b)  (+o r '(1) n)] ; n = b^0 + (n-1)
      [(== '(1) q) (=ol n b) (+o r b n)] ; n = b + r, n and b the same sz
      ; in the rest, n is longer than b
      [(== b '(0 1))		; b = 2
       (fresh (n1 _ __)
	     (poso n1)
	     (== `(,_ ,__ . ,n1) n)	; n is at least 4
	     (exp2 n '() q)		; that will L-instantiate n and n1
	     (fresh (_) (split n n1 r _)))]
      ; the general case
      [(fresh (_ __ ___ ____)
         (any (== '(1 1) b) (== `(,_ ,__ ,___ . ,____) b))) ; b >= 3
       (<ol b n)			; b becomes L-instantiated
	; If b was L-instantiated, the previous
	; ant had only *one* answer
       (fresh (bw nw nw1 bw1 ql1 ql qh qdh qd bql bqd bq bq1 _ __)
   	       (exp2 b '() bw1)
	       (+o bw1 '(1) bw)
	       (<ol q n)			; A _very_ lose bound, but makes
	    ; sure q will be L-instatiated
	    ; Now, we can use b and q to bound n
	    ; |n|-1 < |b|*(q+1)
	       (fresh (q1 bwq1)
	          (+o q '(1) q1)
	          (xo bw q1 bwq1)	; |b|*(q+1)
	          (<o nw1 bwq1))
	       (exp2 n '() nw1)		; n becomes L-instantiated
	    ; Now we have only finite number of ans
	       (+o nw1 '(1) nw)
	       (divo nw bw ql1 _)		; low boundary on q:
	       (+o ql '(1) ql1)		; |n| = |b|(ql+1) + c
	       (any (== q ql) (<ol ql q))	; Tighten the estimate for q
	       (repeated-mul b ql bql)	; bql = b^ql
	       (divo nw bw1 qh __)		; upper boundary on q-1
	       (+o ql qdh qh)
	       (+o ql qd q)
	       (any (== qd qdh) (<o qd qdh)) ; qd is bounded
	       (repeated-mul b qd bqd)	; b^qd
	       (xo bql bqd bq)		; b^q
	       (xo b   bq  bq1)		; b^(q+1)
	       (+o bq r n)
	       (<o n bq1))])))			; check the r condition

(define expo
  (lambda (n b q r)
    (condi
      [(== '(1) n) (poso b) (== '() q) (== '() r)]
      [(== '() q)  (<o n b)  (+o r '(1) n)]
      [(== '(1) q) (=ol n b) (+o r b n)]
      [(== b '(0 1))
       (fresh (n1 _ __)
	     (poso n1)
	     (== `(,_ ,__ . ,n1) n)
	     (exp2 n '() q)
	     (fresh (_) (split n n1 r _)))]
      [(fresh (_ __ ___ ____)
         (any (== '(1 1) b) (== `(,_ ,__ ,___ . ,____) b)))
       (<ol b n)
       (fresh (bw1 bw nw nw1 ql1 ql _)
   	       (exp2 b '() bw1)
	       (+o bw1 '(1) bw)
	       (<ol q n)
	       (fresh (q1 bwq1)
	          (+o q '(1) q1)
	          (xo bw q1 bwq1)	
	          (<o nw1 bwq1))
	       (exp2 n '() nw1)		
	       (+o nw1 '(1) nw)
	       (divo nw bw ql1 _)
	       (+o ql '(1) ql1)		
	       (any (== q ql) (<ol ql q))	
           (fresh (bql qh __ qdh qd)
  	         (repeated-mul b ql bql)	
	         (divo nw bw1 qh __)		
	         (+o ql qdh qh)
	         (+o ql qd q)
	         (any (== qd qdh) (<o qd qdh)) 
             (fresh (bqd bq1 bq)
 	           (repeated-mul b qd bqd)	
	           (xo bql bqd bq)		
	           (xo b   bq  bq1)		
	           (+o bq r n)
	           (<o n bq1))))])))

(define expo
  (lambda (n b q r)
    (condi
      ((== '(1) n) (poso b) (== '() q) (== '() r))
      ((== '() q)  (<o n b)  (+o r '(1) n))
      ((== '(1) q) (=ol n b) (+o r b n))
      ((== b '(0 1))
       (fresh (n1 _ __)
	     (poso n1)
	     (== `(,_ ,__ . ,n1) n)
	     (exp2 n '() q)
	     (fresh (_) (split n n1 r _))))
      ((fresh (_ __ ___ ____)
         (conde
           ((== '(1 1) b) succeed)
           (else (== `(,_ ,__ ,___ . ,____) b))))
       (<ol b n)
       (fresh (bw1 bw nw nw1 ql1 ql _)
   	       (exp2 b '() bw1)
	       (+o bw1 '(1) bw)
	       (<ol q n)
	       (fresh (q1 bwq1)
	          (+o q '(1) q1)
	          (xo bw q1 bwq1)	
	          (<o nw1 bwq1))
	       (exp2 n '() nw1)		
	       (+o nw1 '(1) nw)
	       (divo nw bw ql1 _)
	       (+o ql '(1) ql1)
           (conde
             ((== q ql) succeed)
             (else (<ol ql q)))
           (fresh (bql qh __ qdh qd)
  	         (repeated-mul b ql bql)	
	         (divo nw bw1 qh __)		
	         (+o ql qdh qh)
	         (+o ql qd q)
             (conde
               ((== qd qdh) succeed)
               (else (<o qd qdh)))
             (fresh (bqd bq1 bq)
 	           (repeated-mul b qd bqd)	
	           (xo bql bqd bq)		
	           (xo b   bq  bq1)		
	           (+o bq r n)
	           (<o n bq1))))))))

(test-check 'exp2-0
  (run 10 (q) (exp2 '(0 0 0 0 1) '() q))   
  '((0 0 1)))

(test-check 'exp2-1
  (run 10 (q) (exp2 '(1 1 1 1) '() q))   
  '((1 1)))

(test-check 'exp2-2
  (run 10 (q) (exp2 '(1 0 1 1 1) '()  q))   
  '((0 0 1)))

; These are all answers!
(test-check 'exp2-3
  (run 100 (n) (exp2 n '() '(1 0 1)))   
  '((0 0 0 0 0 1) 
    (1 0 0 0 0 1)
    (0 1 0 0 0 1)
    (1 1 0 0 0 1)
    (0 _.0 1 0 0 1)
    (1 _.0 1 0 0 1)
    (0 _.0 _.1 1 0 1)
    (1 _.0 _.1 1 0 1)
    (0 _.0 _.1 _.2 1 1)
    (1 _.0 _.1 _.2 1 1)))


(test-check 'exp2-4
  (run 5 (r) (fresh (n q) (exp2 n '() q) (== `(,n ,q) r)))   
  '(((1) ())
    ((0 1) (1))
    ((0 0 1) (0 1))
    ((1 1) (1))
    ((0 0 0 1) (1 1))))

(test-check 'expo-15-1
   (run 10 (z)
      (fresh (q r)
        (expo (build 15) (build 2) q r)
        (== `(,q ,r) z)))    
  '(((1 1) (1 1 1))))

(test-check 'expo-15-3
   (run 10 (z)
      (fresh (q r)
        (expo (build 15) (build 3) q r)
        (== `(,q ,r) z)))    
  '(((0 1) (0 1 1))))

(test-check 'expo-15-4
  (run 10 (z)
      (fresh (q r)
        (expo (build 15) (build 4) q r)
        (== `(,q ,r) z)))    
  '(((1) (1 1 0 1))))


(test-check 'expo-15-5
  (run 10 (z)
      (fresh (q r)
        (expo (build 15) (build 5) q r)
        (== `(,q ,r) z)))    
  '(((1) (0 1 0 1))))

(test-check 'expo-15-15
  (run 10 (z)
      (fresh (q r)
        (expo (build 15) (build 15) q r)
        (== `(,q ,r) z)))    
  '(((1) ())))

(test-check 'expo-15-16
  (run 10 (z)
      (fresh (q r)
        (expo (build 15) (build 16) q r)
        (== `(,q ,r) z)))    
  '((() (0 1 1 1))))

(test-check 'expo-15--3
  (run 10 (z)
      (fresh (b r)
        (expo (build 15) b (build 3) r)
        (== `(,b ,r) z)))    
  '(((0 1) (1 1 1))))

(test-check 'expo-32--4
  (run 10 (z)
      (fresh (b r)
        (expo (build 32) b (build 4) r)
        (== `(,b ,r) z)))    
  '())

;;; Why was the quote there?
(test-check 'expo-2-5
  (run 10 (n) (expo n (build 2) (build 5) '(1)))   
  '((1 0 0 0 0 1)))

;;; Why was the quote there: it takes too much time.
(test-check 'expo-3-2
  (run 10 (n) (expo n (build 3) (build 2) '(1)))    
  '((0 1 0 1)))

(test-check 'expo-3-3
  (run 10 (n) (expo n (build 3) (build 3) '(1)))   
  '((0 0 1 1 1)))

(test-check 'powers-of-3
   (run 10 (z)
      (fresh (x q r)
        (expo x (build 3) q r)
        (== `(,x ,q ,r) z)))    
  '(((1) () ())
    ((0 1) () (1))
    ((1 1) (1) ())
	((1) () ())
	((0 0 1) (1) (1))
	((0 0 0 1) (1) (1 0 1))
	((1 0 1) (1) (0 1))
	((1 1 1) (1) (0 0 1))
	((0 1 1) (1) (1 1))
	((0 0 0 0 1) (0 1) (1 1 1))))

(test-check 'powers-of-exp-3
  (run 3 (z)
      (fresh (n b r)
        (expo n b (build 3) r)
        (== `(,n ,b ,r) z)))    
  '(((0 0 0 1) (0 1) ())
    ((1 1 0 1 1) (1 1) ())
    ((1 0 0 1) (0 1) (1))))

(define logo
  (lambda (n b q r)
    (condi
      ((== n '(1)) (poso b) (== q '()) (== r '())) ; 1 = b^0 + 0, b >0
      ((== q '())  (<o n b)  (+o r '(1) n)) ; n = b^0 + (n-1)
	; n = b + r, n and b the same sz
      ((== q '(1)) (>1o b) (=ol n b) (+o r b n))
      ((== b '(1)) (poso q) (+o r '(1) n))  ; n = 1^q + (n-1), q>0
      ((== b '()) (poso q) (== r n))        ; n = 0^q + n, q>0
      ((== b '(0 1))
       (fresh (n1 _ __)
         (poso n1)
         (== `(,_ ,__ . ,n1) n)
         (exp2 n '() q)
         (fresh (_)
           (split n n1 r _))))
      ((fresh (_ __ ___ ____)
         (conde
           ((== '(1 1) b) succeed)
           (else (== `(,_ ,__ ,___ . ,____) b))))
       (<ol b n)
       (fresh (bw1 bw nw nw1 ql1 ql _)
         (exp2 b '() bw1)
         (+o bw1 '(1) bw)
         (<ol q n)
         (fresh (q1 bwq1)
           (+o q '(1) q1)
           (xo bw q1 bwq1)        
           (<o nw1 bwq1))
           (exp2 n '() nw1)                
           (+o nw1 '(1) nw)
           (divo nw bw ql1 _)
           (+o ql '(1) ql1)
         (conde
           ((== q ql) succeed)
           (else (<ol ql q)))
         (fresh (bql qh __ qdh qd)
           (repeated-mul b ql bql)        
           (divo nw bw1 qh __)                
           (+o ql qdh qh)
           (+o ql qd q)
           (conde
             ((== qd qdh) succeed)
             (else (<o qd qdh)))
           (fresh (bqd bq1 bq)
             (repeated-mul b qd bqd)        
             (xo bql bqd bq)                
             (xo b bq bq1)                
             (+o bq r n)
             (<o n bq1))))))))

'(time
  (run 10 (z)
      (fresh (b r)
        (logo (build 37) b r (build 1))
        (== `(,b ,r) z)))    )

(test-check 'expo-33--5
  (run 10 (z)
      (fresh (b r)
        (logo (build 33) b (build 5) r)
        (== `(,b ,r) z)))    
  '(((1) (0 0 0 0 0 1)) (() (1 0 0 0 0 1)) ((0 1) (1))))


(pretty-print
  (run 10 (q)
      (fresh (x y z r)
        (logo x y z r)
        (== `(,x ,y ,z ,r) q)))    )

(define expo
  (lambda (b q n)
    (logo n b q '())))

(test-check 'expo--1-6
  (run 10 (q) (expo '(1) '(0 1) q))   
  '((1)))

;;;; limited-lambda

(define append_1
  (lambda-limited 5 (x y z)
     (conde
      ((== '() x) (== y z))
      (else (fresh (a xs zs)                                                  
              (== `(,a . ,xs) x)                                              
              (== `(,a . ,zs) z)                                              
              (append_1 xs y zs))))))

'(define append_1
  (lambda (x y z)
    (goal-limited 5                                           
    (conde                                                                    
      ((== '() x) (== y z))   
      (else (fresh (a xs zs)                                                  
              (== `(,a . ,xs) x)                                              
              (== `(,a . ,zs) z)                                              
              (append_1 xs y zs)))))))

(pretty-print
  (run 10 (q) (fresh (a b c) (append_1 a b c) (== `(,a ,b ,c) q))))

; A few advanced tests...

(define append_2
  (lambda-limited 3 (x y z)                                              
    (conde
      (fail)
      (succeed                                                                
        (fresh (a xs zs)                                                      
          (== `(,a . ,xs) x)                                                  
          (== `(,a . ,zs) z)                                                  
          (append_2 xs y zs)))                                                
      ((== '() x) (== y z)))))

(pretty-print  ;;; in prolog this should diverge
  (run 10 (q) (fresh (a b c) (append_2 a b c) (== `(,a ,b ,c) q))))

; Emulation of lambda-limited...
(define-syntax condii
  (syntax-rules ()
    ((_ c ...) (c@i interleave c ...))))

(define-syntax c@i
  (syntax-rules (else)
    ((_ combine) fail)
    ((_ combine (else g ...)) (incomplete (all g ...)))
    ((_ combine (g ...) c ...)
     (let ((g^ (all g ...)))
       (lambdag@ (s) (incomplete 
		       (combine (g^ s) 
			 (lambdaf@ () ((c@ combine c ...) s)))))))))

(define swappende
  (lambda (l1 l2 out)
    (condii
      (succeed
        (fresh (a d res)
          (conso a d l1)
          (conso a res out)
          (swappende d l2 res)))
      (else (nullo l1) (== l2 out)))))

(pretty-print
  (run 3 (q)
    (fresh (x y)
      (swappende x y q))))


; additional tests from Dan Friedman and Will Byrd
(define lengtho
   (lambda (ls out)
     (conde
       ((== '() ls) (== '() out))
       ((fresh (d res)
          (cdro ls d)
	  (+o '(1) res out)
	  (lengtho d res))))))


(test-check "lengtho-1"
   (run 2 (q)
     (lengtho '(a b c) q))
  '((1 1)))


(test-check "lengtho-2"
   (run 2 (q)
     (lengtho q '(1 1)))
   '((_.0 _.1 _.2)))

; swapping the two last lines...
(define lengtho
   (lambda (ls out)
     (conde
       ((== '() ls) (== '() out))
       ((fresh (d res)
          (cdro ls d)
	  (lengtho d res)
	  (+o '(1) res out))))))

(test-check "lengtho-3"
   (run 2 (q)
     (lengtho '(a b c) q))
  '((1 1)))


(test-check "lengtho-4"
   (run 2 (q)
     (lengtho q '(1 1)))
   '((_.0 _.1 _.2)))
