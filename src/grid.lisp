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

(defun make-occupancy-grid (board)
  "Build a 2D bit-array marking all snake-occupied cells."
  (let* ((w (board-width board))
         (h (board-height board))
         (grid (make-array (list w h) :element-type 'bit :initial-element 0)))
    (dolist (snake (board-snakes board) grid)
      (dolist (seg (snake-body snake))
        (let ((x (coord-x seg)) (y (coord-y seg)))
          (when (and (>= x 0) (< x w) (>= y 0) (< y h))
            (setf (aref grid x y) 1)))))))

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
  "Return a 4-bit vector indicating safe directions.
Avoids: out of bounds, self-collision, other snake bodies.
Uses a bit-array occupancy grid for O(1) collision checks."
  (let* ((head  (snake-head (game-state-you state)))
         (board (game-state-board state))
<<<<<<< HEAD
         (occ   (make-occupancy-grid board))
         (bv    (make-safe-moves)))
    (declare (dynamic-extent occ))
    (dolist (dir (all-directions) bv)
      (let ((dest (move-coord head dir)))
        (unless (and (in-bounds-p dest board)
                     (zerop (aref occ (coord-x dest) (coord-y dest))))
          (mark-unsafe bv dir))))))

(defun safe-moves-avoiding-heads (state)
  "Like SAFE-MOVES but also avoids cells adjacent to longer/equal enemy heads.
Returns a 4-bit vector. Uses occupancy grid and danger grid for O(1) checks."
  (let* ((me     (game-state-you state))
         (board  (game-state-board state))
         (my-len (snake-length me))
         (w      (board-width board))
         (h      (board-height board))
         (bv     (safe-moves state))
         (head   (snake-head me))
         ;; Build a danger grid for cells adjacent to bigger/equal enemy heads
         (danger (make-array (list w h) :element-type 'bit :initial-element 0)))
    (dolist (s (board-snakes board))
      (unless (string= (snake-id s) (snake-id me))
        (when (>= (snake-length s) my-len)
          (dolist (pair (neighbors (snake-head s)))
            (let* ((c (cdr pair))
                   (cx (coord-x c))
                   (cy (coord-y c)))
              (when (and (>= cx 0) (< cx w) (>= cy 0) (< cy h))
                (setf (aref danger cx cy) 1)))))))
    (dolist (dir (all-directions) bv)
      (when (and (safe-move-p bv dir)
                 (let ((dest (move-coord head dir)))
                   (and (in-bounds-p dest board)
                        (= 1 (aref danger (coord-x dest) (coord-y dest))))))
        (mark-unsafe bv dir)))))

;;; --- Distance ---

(defun manhattan-distance (a b)
  "Manhattan distance between two coordinates."
  (+ (abs (- (coord-x a) (coord-x b)))
     (abs (- (coord-y a) (coord-y b)))))

(defun nearest-food (coord board)
  "Return the nearest food coordinate (by Manhattan distance), or NIL.
Iterates without sorting or copying for zero allocation."
  (let ((foods (board-food board))
        (best nil)
        (best-dist most-positive-fixnum))
    (dolist (f foods best)
      (let ((d (manhattan-distance coord f)))
        (when (< d best-dist)
          (setf best f best-dist d))))))

(defun food-coords-array (board)
  "Return food as a simple-vector of coords for cache-friendly iteration."
  (coerce (board-food board) 'simple-vector))

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
  "BFS flood fill from START. Returns (values count visited-bit-array).
Uses bit-arrays and a flat queue for zero cons-cell allocation."
  (let* ((w (board-width board))
         (h (board-height board))
         (visited (make-array (list w h) :element-type 'bit :initial-element 0))
         (occupied (make-array (list w h) :element-type 'bit :initial-element 0))
         (max-cells (* w h))
         (qx (make-array max-cells :element-type 'fixnum))
         (qy (make-array max-cells :element-type 'fixnum))
         (qhead 0)
         (qtail 0)
         (count 0))
    (declare (type fixnum w h qhead qtail count max-cells)
             (type (simple-array bit (* *)) visited occupied)
             (type (simple-array fixnum (*)) qx qy)
             (dynamic-extent qx qy occupied))
    ;; Precompute occupancy grid from snake bodies
    (unless ignore-snakes
      (dolist (snake (board-snakes board))
        (dolist (seg (snake-body snake))
          (let ((sx (coord-x seg)) (sy (coord-y seg)))
            (when (and (>= sx 0) (< sx w) (>= sy 0) (< sy h))
              (setf (aref occupied sx sy) 1))))))
    ;; Seed the start position
    (let ((sx (coord-x start)) (sy (coord-y start)))
      (setf (aref visited sx sy) 1
            (aref qx qtail) sx
            (aref qy qtail) sy)
      (incf qtail)
      (incf count))
    ;; BFS with inlined neighbor checks
    (loop while (< qhead qtail) do
      (let ((cx (aref qx qhead)) (cy (aref qy qhead)))
        (declare (type fixnum cx cy))
        (incf qhead)
        (macrolet ((try-neighbor (nx-form ny-form)
                     `(let ((nx ,nx-form) (ny ,ny-form))
                        (declare (type fixnum nx ny))
                        (when (and (>= nx 0) (< nx w)
                                   (>= ny 0) (< ny h)
                                   (zerop (aref visited nx ny))
                                   (zerop (aref occupied nx ny)))
                          (setf (aref visited nx ny) 1
                                (aref qx qtail) nx
                                (aref qy qtail) ny)
                          (incf qtail)
                          (incf count)))))
          (try-neighbor (1+ cx) cy)
          (try-neighbor (1- cx) cy)
          (try-neighbor cx (1+ cy))
          (try-neighbor cx (1- cy)))))
    (values count visited)))

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
