(newline)
(display "Structural Inductive proof with equational theory: mirror") (newline)

; $Id: mirror-equ.scm,v 1.3 2004/03/19 21:32:30 oleg Exp $

; See mirror.scm for preliminaries

(define btree
  (lambda (kb)
    (extend-relation (t)
      (fact (val) `(btree (leaf ,val)))
      (relation (t1 t2)
	(to-show `(btree (root ,t1 ,t2)))
	(all
	  (trace-vars 'btree (t1 t2))
	  (kb `(btree ,t1))
	  (kb `(btree ,t2)))))))

(define myeq-axioms
  (lambda (kb)
    (extend-relation (t)
      (fact (val) `(myeq ,val ,val)) ; reflexivity
      (relation (a b)
	(to-show `(myeq ,a ,b))		; symmetry
	(all
	  (trace-vars 'symmetry (a b))
	  (kb `(myeq ,b ,a))))
      (relation (a b)			; transitivity
	(to-show `(myeq ,a ,b))
	(exists (c)
	  (all
	    (kb `(myeq ,a ,c))
	    (kb `(myeq ,c ,b)))))
      )))

(define myeq-axioms-trees		; equational theory of trees
  (lambda (kb)				; equality commutes with root
    (relation (a b c d)
      (to-show `(myeq (root ,a ,b) (root ,c ,d)))
      (all
	(trace-vars 'trees (a b))
	(kb `(myeq ,a ,c))
	(kb `(myeq ,b ,d))))))
  
; equality on leaves follows from the reflexivity of equality

(define myeq-axioms-mirror		; equational theory of mirror
  (lambda (kb)				; equality commutes with root
    (extend-relation (t)
      (relation (a b)
	(to-show `(myeq (mirror ,a) ,b))
	(all
	  (trace-vars 'mirror (a b))
	  (exists (c)
	    (all (kb `(myeq ,b (mirror ,c)))
	         (kb `(myeq ,a ,c)))))))))

; Axioms of mirror
; In Prolog
; myeq(leaf(X),mirror(leaf(X))).

(define mirror-axiom-eq-1
  (lambda (kb)
    (fact (val) `(myeq (leaf ,val) (mirror (leaf ,val))))))

'(define mirror-axiom-eq-1
  (lambda (kb)
    (relation (val)
      (to-show `(myeq (leaf ,val) (mirror (leaf ,val))))
      (trace-vars 'mirror-axiom-eq-1 (val)))))

; The second axiom
; In Athena:
; (define mirror-axiom-eq-2
;   (forall ?t1 ?t2
;     (= (mirror (root ?t1 ?t2))
;       (root (mirror ?t2) (mirror ?t1)))))


(define mirror-axiom-eq-2
  (lambda (kb)
    (fact (t1 t2) `(myeq (root ,t1 ,t2) (root (mirror ,t2) (mirror ,t1))))))

(define mirror-axiom-eq-2
  (lambda (kb)
    (relation (t1 t2) 
      (to-show `(myeq (mirror (root ,t1 ,t2)) (root (mirror ,t2) (mirror ,t1))))
      (trace-vars 'mirror-ax2 (t1 t2)))))

; Define the goal
; In Athena:
;  (define (goal t)
;     (= (mirror (mirror t)) t))

(define goal
  (lambda (t)
    (list 
      `(btree ,t)
      `(myeq (mirror (mirror ,t)) ,t))))

(define goal-fwd
  (lambda (kb)
    (relation (t)
      (to-show `(goal ,t))
      (all
	(kb `(btree ,t))
	(kb `(myeq (mirror (mirror ,t)) ,t))))))

(define goal-rev
  (lambda (kb)
    (extend-relation (t)
      (relation (t)			; (goal t) => (btree t)
	(to-show `(btree ,t))
	(kb `(goal ,t)))
      (relation (t)		; (goal t) => (myeq (mirror (mirror t)) t)
	(to-show `(myeq (mirror (mirror ,t)) ,t))
	(kb `(goal ,t))))))

; (by-induction-on ?t (goal ?t)
;   ((leaf x) (!pf (goal (leaf x)) [mirror-axiom-1]))
;   ((root t1 t2) 
;     (!pf (goal (root t1 t2)) [(goal t1) (goal t2)  mirror-axiom-2])))


; The initial assumptions: just the btree
;(define init-kb (Y btree))
(define init-kb-coll
  (lambda (kb)
    (lambda (t)
      (with-depth 5
	(any
	  ((btree kb) t)
	  ((myeq-axioms kb) t)
	  ((myeq-axioms-mirror kb) t)
	  ((myeq-axioms-trees kb) t)
	)))))

(printf "~%First check the base case, using goal-fwd ~s~%"
  (query
    (let ((kb0
	    (Y (lambda (kb)
		 (extend-relation (t) 
		   (mirror-axiom-eq-1 kb)
		   (init-kb-coll kb))))))
      (let ((kb1
	      (extend-relation (t) (goal-fwd kb0) kb0)))
	(kb1 '(goal (leaf x))))))) ; note, x is an eigenvariable!


(printf "~%Some preliminary checks, using goal-rev ~s~%"
; (goal t2) => (btree t2)
  (query
    (let ((kb
	    (Y
	      (lambda (kb)
		(extend-relation (t)
		  (init-kb-coll kb)
		  (goal-rev kb)
		  (fact () '(goal t1))
		  (fact () '(goal t2)))))))
      (kb '(btree t2)))))

(printf "~%Another check, using goal-rev ~s~%"
  (query
	;(goal t1), (goal t2) => (btree (root t1 t2))
    (let ((kb
	    (Y
	      (lambda (kb)
		(extend-relation (t)
		  (init-kb-coll kb)
		  (goal-rev kb)
		  (mirror-axiom-eq-2 kb)
		  (fact () '(goal t1))
		  (fact () '(goal t2)))))))
      (kb '(btree (root t1 t2))))))

'(printf "~%Check particulars of the inductive case, using goal-rev, goal-fwd ~s~%"
  (let ((kb
          (Y
            (lambda (kb)
              (extend-relation (t)
                (init-kb-coll kb)
                (fact () '(goal t1))
                (fact () '(goal t2))
                (mirror-axiom-eq-2 kb)
                (goal-rev kb)
                )))))
    (list
      ;(solve 1 (x) (kb `(myeq (root t1 t2)  (mirror ,x))))
      (solve 1 (x) (kb `(myeq ,x (mirror (root t1 t2)))))
      )))

(test-check "Check the inductive case, using goal-rev, goal-fwd"
 (let ((result
	 (concretize
	   (query
	     (let ((kb
		     (Y
		       (lambda (kb)
			 (extend-relation (t)
			   (init-kb-coll kb)
			   (fact () '(goal t1))
			   (fact () '(goal t2))
			   (mirror-axiom-eq-2 kb)
			   (goal-rev kb))))))
	       (let ((kb1 (goal-fwd kb)))
		 (kb1 '(goal (root t1 t2)))))))))
   (display result) (newline)
   (not (null? result)))
  #t)
