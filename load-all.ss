; Load everything (for interactive use)
; $Id: load-all.ss,v 1.9 2005/02/03 03:30:39 oleg Exp $

(load "lib/chez-specific.ss")
(load "lib/term.scm")
(load "lib/kanren.ss")
(load "examples/type-inference.scm")
(load "examples/typeclasses.scm")
(load "examples/zebra.scm")
(load "examples/mirror.scm")
(load "examples/mirror-equ.scm")
(load "examples/deduction.scm")
(load "examples/pure-bin-arithm.scm")
;(load "benchmarks/alg-complexity.scm") ; must be last