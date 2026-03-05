(defsystem "cl-battlesnake"
  :description "A Common Lisp framework for building Battlesnake AIs"
  :author "Ian S Pringle <ian@dapringles.com>"
  :license "0BSD"
  :version "0.1.0"
  :homepage "https://github.com/ispringle/cl-battlesnake"
  :source-control (:git "https://github.com/ispringle/cl-battlesnake.git")
  :depends-on ("clack" "lack" "woo" "com.inuoe.jzon")
  :serial t
  :pathname "src/"
  :components ((:file "package")
               (:file "types")
               (:file "parse")
               (:file "grid")
               (:file "strategy")
               (:file "server"))
  :in-order-to ((test-op (test-op "cl-battlesnake/test"))))

(defsystem "cl-battlesnake/test"
  :description "Test suite for cl-battlesnake"
  :author "Ian S Pringle <ian@dapringles.com>"
  :license "0BSD"
  :depends-on ("cl-battlesnake" "cl-battlesnake/examples" "fiveam" "dexador")
  :serial t
  :pathname "test/"
  :components ((:file "package")
               (:file "builders")
               (:file "scenarios")
               (:file "test-grid")
               (:file "test-parse")
               (:file "test-server")
               (:file "test-examples"))
  :perform (test-op (o c) (symbol-call :cl-battlesnake/test :run-tests)))

(defsystem "cl-battlesnake/examples"
  :description "Example Battlesnake implementations"
  :author "Ian S Pringle <ian@dapringles.com>"
  :license "0BSD"
  :depends-on ("cl-battlesnake")
  :serial t
  :pathname "examples/"
  :components ((:file "package")
               (:file "random-randy")
               (:file "hungry-hank")
               (:file "cautious-carl")
               (:file "multi-server")))
