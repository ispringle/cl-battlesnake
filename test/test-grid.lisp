(in-package #:cl-battlesnake/test)

(def-suite grid-tests :in battlesnake-tests
  :description "Tests for grid utilities")

(in-suite grid-tests)

;;; --- Movement ---

(test move-coord-directions
  "move-coord correctly shifts coordinates."
  (let ((origin (c 5 5)))
    (is (coord= (c 5 6) (move-coord origin +up+)))
    (is (coord= (c 5 4) (move-coord origin +down+)))
    (is (coord= (c 4 5) (move-coord origin +left+)))
    (is (coord= (c 6 5) (move-coord origin +right+)))))

(test move-coord-negative
  "move-coord handles coordinates going negative."
  (let ((origin (c 0 0)))
    (is (coord= (c 0 -1) (move-coord origin +down+)))
    (is (coord= (c -1 0) (move-coord origin +left+)))))

(test neighbors-count
  "neighbors always returns 4 entries."
  (is (= 4 (length (neighbors (c 5 5))))))

;;; --- Bounds ---

(test in-bounds-basic
  "in-bounds-p respects board dimensions."
  (let ((board (make-test-board :height 11 :width 11)))
    (is (in-bounds-p (c 0 0) board))
    (is (in-bounds-p (c 10 10) board))
    (is (not (in-bounds-p (c -1 0) board)))
    (is (not (in-bounds-p (c 0 -1) board)))
    (is (not (in-bounds-p (c 11 0) board)))
    (is (not (in-bounds-p (c 0 11) board)))))

(test in-bounds-corners
  "All four corners of an 11x11 board are in bounds."
  (let ((board (make-test-board :height 11 :width 11)))
    (is (in-bounds-p (c 0 0)   board))
    (is (in-bounds-p (c 10 0)  board))
    (is (in-bounds-p (c 0 10)  board))
    (is (in-bounds-p (c 10 10) board))))

;;; --- Safe moves ---

(test safe-moves-open-board
  "In the center of an empty board, all 4 moves are safe."
  (let ((state (make-test-state :you-body '((5 5))
                                :board-height 11 :board-width 11)))
    (is (= 4 (length (safe-moves state))))))

(test safe-moves-corner
  "In bottom-left corner, only up and right are safe."
  (let ((state (make-test-state :you-body '((0 0))
                                :board-height 11 :board-width 11)))
    (let ((moves (safe-moves state)))
      (is (= 2 (length moves)))
      (is (member +up+ moves :test #'string=))
      (is (member +right+ moves :test #'string=)))))

(test safe-moves-avoids-self
  "Won't move into own body."
  ;; Snake at (5,5) with body going down
  (let ((state (make-test-state :you-body '((5 5) (5 4) (5 3)))))
    (let ((moves (safe-moves state)))
      ;; Down would hit body at (5,4)
      (is (not (member +down+ moves :test #'string=))))))

(test safe-moves-avoids-enemy
  "Won't move into enemy body."
  (let* ((enemy (make-test-snake :id "enemy"
                                 :body '((6 5) (7 5) (8 5))))
         (state (make-test-state :you-body '((5 5))
                                 :enemies (list enemy))))
    (let ((moves (safe-moves state)))
      ;; Right would hit enemy at (6,5)
      (is (not (member +right+ moves :test #'string=))))))

(test safe-moves-avoiding-heads-filters-bigger
  "Avoids cells adjacent to bigger enemy heads."
  (let* (;; Enemy head at (7,5), length 5 — bigger than us
         (enemy (make-test-snake :id "enemy"
                                 :body '((7 5) (7 4) (7 3) (7 2) (7 1))))
         ;; We're at (5,5), length 3
         (state (make-test-state :you-body '((5 5) (5 4) (5 3))
                                 :enemies (list enemy))))
    (let ((cautious (safe-moves-avoiding-heads state)))
      ;; (6,5) is adjacent to enemy head (7,5), so right should be excluded
      (is (not (member +right+ cautious :test #'string=))))))

;;; --- Distance ---

(test manhattan-distance-basic
  (is (= 0 (manhattan-distance (c 5 5) (c 5 5))))
  (is (= 1 (manhattan-distance (c 5 5) (c 5 6))))
  (is (= 10 (manhattan-distance (c 0 0) (c 5 5)))))

(test nearest-food-finds-closest
  (let ((board (make-test-board :food '((2 2) (8 8) (5 6)))))
    (let ((nearest (nearest-food (c 5 5) board)))
      (is (coord= (c 5 6) nearest)))))

(test nearest-food-empty
  (let ((board (make-test-board :food '())))
    (is (null (nearest-food (c 5 5) board)))))

(test direction-toward-basic
  (is (string= +right+ (direction-toward (c 0 0) (c 5 0))))
  (is (string= +up+    (direction-toward (c 0 0) (c 0 5))))
  (is (string= +left+  (direction-toward (c 5 0) (c 0 0))))
  (is (string= +down+  (direction-toward (c 0 5) (c 0 0)))))

;;; --- Flood fill ---

(test flood-fill-empty-board
  "Flood fill on an empty 5x5 board from center reaches all 25 cells."
  (let ((board (make-test-board :height 5 :width 5)))
    (is (= 25 (flood-fill (c 2 2) board)))))

(test flood-fill-with-wall
  "Snake body acts as a wall for flood fill."
  ;; 5x5 board, snake body forms a wall across the middle
  (let* ((wall-snake (make-test-snake
                      :id "wall"
                      :body '((0 2) (1 2) (2 2) (3 2) (4 2))))
         (board (make-test-board :height 5 :width 5
                                 :snakes (list wall-snake))))
    ;; From (0,0), only bottom 2 rows reachable = 10 cells
    (let ((area (flood-fill (c 0 0) board)))
      (is (= 10 area)))))

(test flood-fill-ignore-snakes
  "With :ignore-snakes, fill reaches entire board."
  (let* ((wall-snake (make-test-snake
                      :id "wall"
                      :body '((0 2) (1 2) (2 2) (3 2) (4 2))))
         (board (make-test-board :height 5 :width 5
                                 :snakes (list wall-snake))))
    (is (= 25 (flood-fill (c 0 0) board :ignore-snakes t)))))

;;; --- Higher-level ---

(test enemy-snakes-filters-self
  (let* ((enemy (make-test-snake :id "enemy" :body '((8 5))))
         (state (make-test-state :enemies (list enemy))))
    (let ((enemies (enemy-snakes state)))
      (is (= 1 (length enemies)))
      (is (string= "enemy" (snake-id (first enemies)))))))

(test tail-coord-returns-last
  (let ((s (make-test-snake :body '((5 5) (5 4) (5 3)))))
    (is (coord= (c 5 3) (tail-coord s)))))
