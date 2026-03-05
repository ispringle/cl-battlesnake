(in-package #:cl-battlesnake/test)

(def-suite example-tests :in battlesnake-tests
  :description "Tests for the example snake strategies")

(in-suite example-tests)

;;; ─────────────────────────────────────────────────────────
;;; Scenario-based tests using ASCII diagrams
;;; ─────────────────────────────────────────────────────────

;; Load examples (they're in the main package)
;; Assumes examples.lisp has been loaded.

;;; --- Random snake ---

(test random-snake-avoids-walls
  "Random snake doesn't walk into walls from a corner."
  (let ((state (make-test-state :you-body '((0 0))
                                :board-height 11 :board-width 11)))
    ;; Only up and right are valid from (0,0)
    (assert-moves 'random-snake state (list +up+ +right+)
                  "Corner position")))

(test random-snake-returns-valid-direction
  "Always returns one of the four direction strings."
  (let ((state (make-test-state :you-body '((5 5)))))
    (let ((move (on-move (make-instance 'random-snake) state)))
      (is (member move (all-directions))))))

;;; --- Hungry snake ---

(test hungry-snake-moves-toward-food
  "Hungry snake moves toward nearest food."
  ;; Food is directly above, snake should go up
  (let ((state (make-test-state :you-body '((5 5) (5 4) (5 3))
                                :food '((5 8)))))
    (assert-move-is 'hungry-snake state +up+
                    "Should move toward food above")))

(test hungry-snake-avoids-walls
  "Hungry snake won't walk off the board even if food is that way."
  ;; Snake on right edge, food is further right (off board)
  ;; but we put food on the board at a reachable spot
  (let ((state (make-test-state :you-body '((10 5) (9 5) (8 5))
                                :food '((10 8))
                                :board-height 11 :board-width 11)))
    ;; Can't go right (wall). Food is above, so up is best safe move.
    (assert-move-not 'hungry-snake state +right+
                     "Should not walk into wall")))

(test hungry-snake-diagram-test
  "Hungry snake with an ASCII diagram scenario."
  ;; 5x5 board:
  ;;   . . . . .     y=4
  ;;   . . * . .     y=3  food at (2,3)
  ;;   . Y y . .     y=2  head at (1,2), body right
  ;;   . . y . .     y=1  body below
  ;;   . . . . .     y=0
  (let ((state (state-from-diagram
                '(". . . . ."
                  ". . * . ."
                  ". Y y . ."
                  ". . y . ."
                  ". . . . ."))))
    ;; Food is at (2,3), head at (1,2). Up goes to (1,3), right goes to (2,2)=body.
    ;; Best move toward food: up (distance 2) vs left (distance 3).
    (let ((move (on-move (make-instance 'hungry-snake) state)))
      ;; Should pick up or left (both safe), up is closer to food
      (is (member move (list +up+ +left+))))))

;;; --- Cautious snake ---

(test cautious-snake-avoids-dead-end
  "Cautious snake avoids a corridor that's too small."
  ;; 7x7 board with a narrow dead-end corridor on the right:
  ;;   . . . . . . .    y=6
  ;;   . . . . . . .    y=5
  ;;   . . . . a a .    y=4  enemy body blocking
  ;;   . Y y . . A .    y=3  head at (1,3)
  ;;   . . y . a a .    y=2  enemy body blocking
  ;;   . . . . . . .    y=1
  ;;   . . . . . . .    y=0
  ;;
  ;; Going right leads into a space blocked by enemy.
  ;; Going up/left leads to open space.
  (let ((state (state-from-diagram
                '(". . . . . . ."
                  ". . . . . . ."
                  ". . . . a a ."
                  ". Y y . . A ."
                  ". . y . a a ."
                  ". . . . . . ."
                  ". . . . . . ."))))
    (let ((move (on-move (make-instance 'cautious-snake) state)))
      ;; Should prefer the open area (up or left), not right into the bottleneck
      (is (member move (list +up+ +left+))
          "Should avoid moving toward cramped area"))))

(test cautious-snake-chases-food-when-hungry
  "Cautious snake prioritizes food when health is low."
  (let ((state (make-test-state
                :you-body '((5 5) (5 4) (5 3))
                :you-health 20  ; hungry!
                :food '((5 8)))))
    ;; Food is above, should go up when hungry
    (assert-move-is 'cautious-snake state +up+
                    "Should chase food when health is low")))

;;; --- Multi-turn survival ---

(test random-snake-survives-10-turns-open-board
  "Random snake survives at least 10 turns on an open 11x11 board."
  (let ((state (make-test-state :you-body '((5 5))
                                :food '((3 3) (7 7) (1 9) (9 1)))))
    (assert-survives-turns 'random-snake state 10
                           "Open board survival")))

(test hungry-snake-survives-20-turns
  "Hungry snake survives 20 turns with food available."
  (let ((state (make-test-state :you-body '((5 5) (5 4) (5 3))
                                :you-health 50
                                :food '((5 8) (3 3) (7 7) (1 1) (9 9)))))
    (assert-survives-turns 'hungry-snake state 20
                           "Hungry snake with food")))

;;; --- Builder / scenario sanity tests ---

(test diagram-parser-basic
  "ASCII diagram produces correct board dimensions and positions."
  (let ((state (state-from-diagram
                '(". . . . ."
                  ". Y y . ."
                  ". . . . ."
                  ". . * . ."
                  ". . . . ."))))
    (is (= 5 (board-height (game-state-board state))))
    (is (= 5 (board-width (game-state-board state))))
    (is (coord= (c 1 3) (snake-head (game-state-you state))))
    (is (= 2 (snake-length (game-state-you state))))
    (is (= 1 (length (board-food (game-state-board state)))))))

(test make-test-state-defaults
  "make-test-state produces valid structures with minimal input."
  (let ((state (make-test-state)))
    (is (not (null (game-state-game state))))
    (is (not (null (game-state-board state))))
    (is (not (null (game-state-you state))))
    (is (= 11 (board-height (game-state-board state))))
    (is (= 0 (game-state-turn state)))))
