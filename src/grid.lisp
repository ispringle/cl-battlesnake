(in-package #:cl-battlesnake)

;;; --- Movement ---

(defun move-coord (coord direction)
  "Return the coordinate resulting from moving COORD in DIRECTION."
  (let ((x (coord-x coord))
        (y (coord-y coord)))
    (ecase direction
      (:up    (make-coord x (1+ y)))
      (:down  (make-coord x (1- y)))
      (:left  (make-coord (1- x) y))
      (:right (make-coord (1+ x) y)))))

(defun neighbors (coord)
  "Return an alist of (direction . coord) for all four neighbors."
  (mapcar (lambda (dir) (cons dir (move-coord coord dir)))
          (all-directions)))

;;; --- Bounds checking ---

(defun in-bounds-p (coord board)
  "Is COORD within the board boundaries?"
  (let ((x (coord-x coord))
        (y (coord-y coord)))
    (and (>= x 0) (< x (board-width board))
         (>= y 0) (< y (board-height board)))))

;;; --- Occupancy ---

(defun all-snake-cells (board)
  "Return a list of all coordinates occupied by any snake body."
  (loop for s in (board-snakes board)
        nconc (copy-list (snake-body s))))

(defun coord-member (coord coord-list)
  "Is COORD present in COORD-LIST? (value equality)"
  (member coord coord-list :test #'coord=))

(defun occupied-p (coord board)
  "Is COORD occupied by any snake body segment?"
  (coord-member coord (all-snake-cells board)))

(defun hazard-p (coord board)
  "Is COORD a hazard cell?"
  (coord-member coord (board-hazards board)))

;;; --- Safe moves ---

(defun safe-moves (state)
  "Return a list of directions that don't immediately kill us.
Avoids: out of bounds, self-collision, other snake bodies."
  (let* ((head  (snake-head (game-state-you state)))
         (board (game-state-board state))
         (bodies (all-snake-cells board)))
    (loop for dir in (all-directions)
          for dest = (move-coord head dir)
          when (and (in-bounds-p dest board)
                    (not (coord-member dest bodies)))
            collect dir)))

(defun safe-moves-avoiding-heads (state)
  "Like SAFE-MOVES but also avoids cells adjacent to longer/equal enemy heads."
  (let* ((me     (game-state-you state))
         (board  (game-state-board state))
         (my-len (snake-length me))
         ;; cells next to enemy heads that are at least as long
         (danger (loop for s in (board-snakes board)
                       unless (string= (snake-id s) (snake-id me))
                         when (>= (snake-length s) my-len)
                           nconc (mapcar #'cdr (neighbors (snake-head s))))))
    (remove-if (lambda (dir)
                 (coord-member (move-coord (snake-head me) dir) danger))
               (safe-moves state))))

;;; --- Distance ---

(defun manhattan-distance (a b)
  "Manhattan distance between two coordinates."
  (+ (abs (- (coord-x a) (coord-x b)))
     (abs (- (coord-y a) (coord-y b)))))

(defun nearest-food (coord board)
  "Return the nearest food coordinate (by Manhattan distance), or NIL."
  (let ((foods (board-food board)))
    (when foods
      (first (sort (copy-list foods)
                   #'< :key (lambda (f) (manhattan-distance coord f)))))))

(defun direction-toward (from to)
  "Return the direction that moves FROM closer to TO.
Prefers the axis with the larger delta."
  (let ((dx (- (coord-x to) (coord-x from)))
        (dy (- (coord-y to) (coord-y from))))
    (if (>= (abs dx) (abs dy))
        (if (plusp dx) +right+ +left+)
        (if (plusp dy) +up+ +down+))))

;;; --- Flood fill ---

(defun flood-fill (start board &key (ignore-snakes nil))
  "BFS flood fill from START, returning the set of reachable coordinates.
Respects board bounds and snake bodies (unless IGNORE-SNAKES)."
  (let ((visited (make-hash-table :test 'equal))
        (queue   (list start))
        (bodies  (unless ignore-snakes (all-snake-cells board))))
    (flet ((coord-key (c) (cons (coord-x c) (coord-y c))))
      (setf (gethash (coord-key start) visited) t)
      (loop while queue
            for current = (pop queue)
            do (loop for (nil . neighbor) in (neighbors current)
                     for key = (coord-key neighbor)
                     when (and (in-bounds-p neighbor board)
                               (not (gethash key visited))
                               (or ignore-snakes
                                   (not (coord-member neighbor bodies))))
                       do (setf (gethash key visited) t)
                          (push neighbor queue)))
      ;; Return count and hash-table
      (values (hash-table-count visited) visited))))

(defun reachable-area (coord board)
  "Number of cells reachable from COORD via flood fill."
  (flood-fill coord board))

;;; --- Higher-level helpers ---

(defun enemy-snakes (state)
  "Return a list of all snakes that aren't us."
  (let ((my-id (snake-id (game-state-you state))))
    (remove-if (lambda (s) (string= (snake-id s) my-id))
               (board-snakes (game-state-board state)))))

(defun closest-enemy-head (state)
  "Return the nearest enemy snake's head coord, or NIL."
  (let ((head (snake-head (game-state-you state)))
        (enemies (enemy-snakes state)))
    (when enemies
      (snake-head
       (first (sort (copy-list enemies) #'<
                    :key (lambda (s)
                           (manhattan-distance head (snake-head s)))))))))

(defun tail-coord (snake)
  "Return the tail (last body segment) of SNAKE."
  (car (last (snake-body snake))))
