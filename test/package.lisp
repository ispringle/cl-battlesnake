(defpackage #:cl-battlesnake/test
  (:use #:cl #:fiveam #:cl-battlesnake)
  (:import-from #:cl-battlesnake/examples
                #:random-snake
                #:hungry-snake
                #:cautious-snake)
  (:export #:run-tests
           #:make-test-snake #:make-test-board #:make-test-state
           #:parse-board-diagram #:state-from-diagram
           #:assert-moves #:assert-move-is #:assert-move-not
           #:assert-survives-turns
           #:with-test-server))

(in-package #:cl-battlesnake/test)

(def-suite battlesnake-tests
  :description "All cl-battlesnake tests")

(defun run-tests ()
  "Run the full test suite. Returns T on success."
  (run! 'battlesnake-tests))
