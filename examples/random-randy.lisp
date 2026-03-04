(in-package #:cl-battlesnake/examples)

(defsnake random-snake
  (:name "Random Randy" :color "#ff6600" :head "silly" :tail "small-rattle"
   :author "Ian S Pringle")
  (:move (state)
    (let ((moves (safe-moves state)))
      (if moves
          (nth (random (length moves)) moves)
          +up+))))
