(in-package #:cl-battlesnake/examples)

(defsnake hungry-snake
  (:name "Hungry Hank" :color "#00cc44" :head "fang" :tail "bolt"
   :author "Ian S Pringle")
  (:move (state)
    (let* ((me    (game-state-you state))
           (board (game-state-board state))
           (head  (snake-head me))
           (bv    (safe-moves state))
           (safe  (safe-moves-list bv))
           (food  (nearest-food head board)))
      (cond
        ((zerop (safe-moves-count bv)) +up+)
        ((null food) (nth (random (length safe)) safe))
        (t (let ((sorted-safe (sort (copy-list safe) #'<
                                    :key (lambda (dir)
                                           (manhattan-distance
                                            (move-coord head dir) food)))))
             (declare (dynamic-extent sorted-safe))
             (first sorted-safe)))))))
