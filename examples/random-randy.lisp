(in-package #:cl-battlesnake/examples)

(defsnake random-snake
  (:name "Random Randy" :color "#ff6600" :head "silly" :tail "small-rattle"
   :author "Ian S Pringle")
  (:move (state)
    (let* ((bv (safe-moves state))
           (moves (safe-moves-list bv)))
      (if (plusp (safe-moves-count bv))
          (nth (random (length moves)) moves)
          +up+))))
