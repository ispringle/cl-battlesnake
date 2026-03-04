(in-package #:cl-battlesnake/test)

;;; Test helpers for building game states with minimal boilerplate

(defun c (x y)
  "Shorthand for make-coord."
  (make-coord x y))

(defun make-test-snake (&key (id "snake-1") (name "Test Snake")
                             (health 100) body (head nil)
                             (length nil) (latency "0") (shout "") (squad ""))
  "Build a snake. BODY is (x y) pairs or coords. HEAD and LENGTH default from BODY."
  (let* ((parsed-body (mapcar (lambda (b)
                                (etypecase b
                                  (coord b)
                                  (cons  (c (first b) (second b)))))
                              (or body '((0 0)))))
         (head (or head (first parsed-body)))
         (length (or length (length parsed-body))))
    (cl-battlesnake::make-snake
     :id id :name name :health health
     :body parsed-body :head head
     :length length :latency latency
     :shout shout :squad squad)))

(defun make-test-board (&key (height 11) (width 11)
                             food hazards snakes)
  "Build a board. FOOD and HAZARDS are (x y) pairs or coords."
  (flet ((parse-coords (lst)
           (mapcar (lambda (item)
                     (etypecase item
                       (coord item)
                       (cons  (c (first item) (second item)))))
                   lst)))
    (cl-battlesnake::make-board
     :height height :width width
     :food (parse-coords food)
     :hazards (parse-coords hazards)
     :snakes (or snakes '()))))

(defun make-test-state (&key (turn 0)
                             (you-id "you") (you-name "You") (you-health 100)
                             you-body
                             enemies
                             (board-height 11) (board-width 11)
                             food hazards
                             (game-id "test-game") (timeout 500))
  "Build a complete game-state. Specify what matters, rest uses defaults."
  (let* ((you (make-test-snake :id you-id :name you-name
                               :health you-health
                               :body (or you-body '((5 5)))))
         (all-snakes (cons you (or enemies '())))
         (board (make-test-board :height board-height :width board-width
                                :food food :hazards hazards
                                :snakes all-snakes))
         (game (cl-battlesnake::make-game
                :id game-id :timeout timeout)))
    (cl-battlesnake::make-game-state
     :game game :turn turn
     :board board :you you)))

(defun assert-move-is (snake-class state expected-direction
                       &optional (msg ""))
  "Assert SNAKE-CLASS chooses EXPECTED-DIRECTION."
  (let* ((instance (make-instance snake-class))
         (move (on-move instance state)))
    (is (string= expected-direction move)
        "~@[~A: ~]Expected ~A but got ~A" msg expected-direction move)))

(defun assert-move-not (snake-class state bad-direction
                        &optional (msg ""))
  "Assert SNAKE-CLASS does NOT choose BAD-DIRECTION."
  (let* ((instance (make-instance snake-class))
         (move (on-move instance state)))
    (is (not (string= bad-direction move))
        "~@[~A: ~]Expected anything but ~A, got ~A" msg bad-direction move)))

(defun assert-moves (snake-class state allowed-directions
                     &optional (msg ""))
  "Assert the snake's move is one of ALLOWED-DIRECTIONS."
  (let* ((instance (make-instance snake-class))
         (move (on-move instance state)))
    (is (member move allowed-directions :test #'string=)
        "~@[~A: ~]Expected one of ~A but got ~A"
        msg allowed-directions move)))

(defun simulate-turn (state direction)
  "Move 'you' in DIRECTION. Simplified: moves head, shifts body, decrements health.
Does NOT simulate other snakes or food spawning."
  (let* ((you (game-state-you state))
         (board (game-state-board state))
         (old-head (snake-head you))
         (new-head (move-coord old-head direction))
         (ate-food (coord-member new-head (board-food board)))
         (new-body (if ate-food
                       (cons new-head (snake-body you))
                       (cons new-head (butlast (snake-body you)))))
         (new-food (if ate-food
                       (remove-if (lambda (f) (coord= f new-head))
                                  (board-food board))
                       (board-food board)))
         (new-health (if ate-food 100 (1- (snake-health you))))
         (new-you (make-test-snake
                   :id (snake-id you) :name (snake-name you)
                   :health new-health :body new-body
                   :length (length new-body)))
         (new-board (make-test-board
                     :height (board-height board)
                     :width (board-width board)
                     :food new-food
                     :hazards (board-hazards board)
                     :snakes (cons new-you
                                   (remove-if
                                    (lambda (s) (string= (snake-id s)
                                                         (snake-id you)))
                                    (board-snakes board))))))
    (cl-battlesnake::make-game-state
     :game (game-state-game state)
     :turn (1+ (game-state-turn state))
     :board new-board
     :you new-you)))

(defun snake-alive-p (state)
  "Check if 'you' is still alive (in bounds, not self-colliding, health > 0)."
  (let* ((you   (game-state-you state))
         (board (game-state-board state))
         (head  (snake-head you))
         (body  (snake-body you)))
    (and (plusp (snake-health you))
         (in-bounds-p head board)
         ;; head doesn't overlap any body segment except itself at index 0
         (not (coord-member head (rest body))))))

(defun assert-survives-turns (snake-class state n
                              &optional (msg ""))
  "Simulate N turns of SNAKE-CLASS playing against STATE, assert survival."
  (let ((instance (make-instance snake-class))
        (current state))
    (dotimes (i n)
      (unless (snake-alive-p current)
        (fail "~@[~A: ~]Snake died on turn ~D" msg i)
        (return-from assert-survives-turns nil))
      (let ((move (on-move instance current)))
        (setf current (simulate-turn current move))))
    (is (snake-alive-p current)
        "~@[~A: ~]Snake died before completing ~D turns" msg n)))
