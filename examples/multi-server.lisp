(in-package #:cl-battlesnake/examples)

(defun start-all-snakes (&key (port 8080))
  (cl-battlesnake:start-multi-snake-server
   '(("/random" . random-snake)
     ("/hungry" . hungry-snake)
     ("/cautious" . cautious-snake))
   :port port))
