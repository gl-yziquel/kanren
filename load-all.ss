; Load everything (for interactive use)
; $Id: load-all.ss,v 1.8 2004/07/23 18:24:16 oleg Exp $

(load "lib/chez-specific.ss")
(load "lib/kanren.ss")
(load "examples/type-inference.scm")
(load "examples/typeclasses.scm")
(load "examples/zebra.scm")
(load "examples/mirror.scm")
(load "examples/mirror-equ.scm")
(load "examples/deduction.scm")
(load "examples/pure-bin-arithm.scm")
;(load "benchmarks/alg-complexity.scm") ; must be last