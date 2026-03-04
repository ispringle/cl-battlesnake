# cl-battlesnake

Common Lisp framework for [Battlesnake](https://play.battlesnake.com/) AIs.

Distilled from my own Battlesnake code into a reusable framework.

## Quick Start

```lisp
(ql:quickload "cl-battlesnake")

(bs:defsnake my-snake
  (:name "My Snake" :color "#ff0000")
  (:move (state)
    (first (bs:safe-moves state))))  ; pick any safe move

(bs:start-server 'my-snake :port 8080)
;; → http://localhost:8080
```

## Core Concepts

```lisp
;; Movement: directions are constants
bs:+up+ bs:+down+ bs:+left+ bs:+right+

;; Coords: (x y) pairs
(bs:move-coord '(5 5) bs:+right+)  ; → (6 5)
(bs:neighbors '(5 5))               ; → ((up . (5 6)) (down . (5 4)) ...)

;; Safety checks
(bs:safe-moves state)                    ; → (up right) — non-lethal moves
(bs:safe-moves-avoiding-heads state)     ; → (up) — also dodges bigger snakes

;; Pathfinding
(bs:nearest-food '(5 5) board)           ; → (3 8)
(bs:direction-toward '(5 5) '(3 8))      ; → left
(bs:manhattan-distance '(5 5) '(3 8))    ; → 5

;; Flood fill: count reachable space
(bs:reachable-area '(5 5) board)         ; → 42

;; Game state accessors
(state-you state)       ; → your snake struct
(state-board state)     ; → board struct
(state-turn state)      ; → turn number
```

## defsnake

```lisp
(bs:defsnake hungry-snake
  (:name "Hungry" :color "#00ff00" :author "you")

  (:move (state)
    ;; Required. Return direction constant.
    (let* ((my-head (snake-head (state-you state)))
           (food (bs:nearest-food my-head (state-board state)))
           (safe (bs:safe-moves state)))
      (if (and food (< (snake-health (state-you state)) 30))
          (or (find (bs:direction-toward my-head food) safe)
              (first safe))
          (first safe))))

  (:start (state)
    ;; Optional. Called once at game start.
    (format t "Game ~a started~%" (game-id (state-game state))))

  (:end (state)
    ;; Optional. Called once at game end.
    nil))

;; With shout (second return value)
(:move (state)
  (values bs:+up+ "Going up!"))
```


## Examples

### Random: pick any safe move
```lisp
(bs:defsnake random-snake
  (:name "Random Randy" :color "#888888")
  (:move (state)
    (let ((safe (bs:safe-moves state)))
      (nth (random (length safe)) safe))))
```

### Food-seeking: chase nearest food when hungry
```lisp
(bs:defsnake hungry-snake
  (:name "Hungry Hank" :color "#00ff00")
  (:move (state)
    (let* ((my-head (snake-head (state-you state)))
           (food (bs:nearest-food my-head (state-board state)))
           (safe (bs:safe-moves-avoiding-heads state)))
      (if (and food (< (snake-health (state-you state)) 40))
          (or (find (bs:direction-toward my-head food) safe)
              (first safe))
          (first safe)))))
```

### Cautious: use flood fill to avoid traps
```lisp
(bs:defsnake cautious-snake
  (:name "Cautious Carl" :color "#0000ff")
  (:move (state)
    (let* ((my-head (snake-head (state-you state)))
           (board (state-board state))
           (safe (bs:safe-moves-avoiding-heads state)))
      ;; Pick move with most reachable space
      (first
       (sort (copy-list safe) #'>
             :key (lambda (dir)
                    (bs:reachable-area
                     (bs:move-coord my-head dir)
                     board)))))))
```

### Direct CLOS (skip macro)
```lisp
(defclass pro-snake (bs:battlesnake) ()
  (:default-initargs :name "Pro" :color "#000000"))

(defmethod bs:on-move ((snake pro-snake) state)
  bs:+up+)  ; full CLOS: slots, inheritance, etc.
```

## Testing

```lisp
(ql:quickload "cl-battlesnake/test")
(cl-battlesnake/test:run-tests)
```

### Unit tests: build minimal states
```lisp
(test my-snake-avoids-walls
  (let ((state (make-test-state :you-body '((0 0)))))
    (assert-moves 'my-snake state (list +up+ +right+))))

(test my-snake-chases-food
  (let ((state (make-test-state :you-body '((5 5) (5 4))
                                :food '((5 8)))))
    (assert-move-is 'my-snake state +up+)))
```

### ASCII diagrams: visual debugging
```lisp
(test escape-trap
  (let ((state (state-from-diagram
                '(". . . . . ."   ; y=5 (top)
                  ". a a a a ."
                  ". A . . a ."
                  ". Y y . a ."   ; Y = your head
                  ". . y . a ."
                  ". . . . . .")))) ; y=0 (bottom)
    (assert-move-is 'my-snake state +left+)))

;; Legend: . = empty, * = food, # = hazard
;;         Y/y = your head/body, A/a B/b C/c = enemy head/body
```

### Multi-turn simulation
```lisp
(test survives-50-turns
  (let ((state (make-test-state
                :you-body '((5 5) (5 4))
                :food '((3 3) (7 7)))))
    (assert-survives-turns 'my-snake state 50)))
```

### HTTP integration
```lisp
(test server-responds
  (with-test-server (my-snake :port 19999)
    (multiple-value-bind (response status)
        (post-json "/move" (sample-move-json))
      (is (= 200 status))
      (is (member (gethash "move" response)
                  '("up" "down" "left" "right") :test #'string=)))))
```

## Play Against the Examples

Challenge the live example snakes: [cl-battlesnake profile](https://play.battlesnake.com/profile/cl-battlesnake)

---

**Dependencies:** hunchentoot, com.inuoe.jzon, alexandria (all via Quicklisp)
**License:** 0BSD
