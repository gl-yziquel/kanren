; Load everything (for interactive use)
; $Id: load-all-bigloo.scm,v 1.1 2004/04/09 23:32:38 oleg Exp $
(module kanren
  (include "lib/bigloo-specific.scm")
  (include "lib/kanren.ss")

  (include "examples/type-inference.scm")
  (include "examples/typeclasses.scm")
  (include "examples/zebra.scm")
  (include "examples/mirror.scm")
  (include "examples/mirror-equ.scm")
  (include "examples/deduction.scm")
)
;(load "benchmarks/alg-complexity.scm") ; must be last