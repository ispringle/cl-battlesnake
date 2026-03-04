(in-package #:cl-battlesnake/examples)

(defsnake hungry-snake
  (:name "Hungry Hank" :color "#00cc44" :head "fang" :tail "bolt"
   :author "Ian S Pringle")
  (:move (state)
    (let* ((me    (game-state-you state))
           (board (game-state-board state))
           (head  (snake-head me))
           (safe  (safe-moves state))
           (food  (nearest-food head board)))
      (cond
        ((null safe) +up+)
        ((null food) (nth (random (length safe)) safe))
        (t (first (sort (copy-list safe) #'<
                        :key (lambda (dir)
                               (manhattan-distance
                                (move-coord head dir) food)))))))))
