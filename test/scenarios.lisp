(in-package #:cl-battlesnake/test)

;;;; ================================================================
;;;; ASCII Board Scenarios
;;;;
;;;; Parse ASCII art into game states. Much easier to reason about
;;;; than nested constructor calls.
;;;;
;;;; Legend:
;;;;   .  = empty cell
;;;;   *  = food
;;;;   #  = hazard
;;;;   Y  = your head
;;;;   y  = your body
;;;;   A  = enemy A head
;;;;   a  = enemy A body
;;;;   B  = enemy B head
;;;;   b  = enemy B body
;;;;   C  = enemy C head
;;;;   c  = enemy C body
;;;;
;;;; Example (5x5 board, you going right, enemy below):
;;;;
;;;;   ". . . . ."
;;;;   ". . Y y ."
;;;;   ". . . y ."
;;;;   ". * A a ."
;;;;   ". . a . ."
;;;;
;;;; NOTE: Origin (0,0) is bottom-left. The FIRST string in the list
;;;; is the TOP row (highest Y). This matches how you'd naturally
;;;; draw a board.
;;;; ================================================================

(defun parse-board-diagram (rows &key (you-health 100)
                                      (enemy-health 100))
  "Parse a list of strings into a board description.
Returns (values board you enemies food hazards).

Each string represents a row. Chars are space-separated.
Row 0 in the list = top of board (highest Y)."
  (let* ((height (length rows))
         (cells  (mapcar (lambda (row)
                           (remove-if (lambda (c) (char= c #\Space))
                                      (coerce row 'list)))
                         rows))
         (width  (length (first cells)))
         ;; Accumulators
         (you-cells  '())
         (enemy-map  (make-hash-table))  ; char → list of (x y)
         (food       '())
         (hazards    '()))
    ;; Walk the grid
    (loop for row in cells
          for visual-row from 0
          for y = (- height 1 visual-row)  ; flip so row 0 = bottom
          do (loop for ch in row
                   for x from 0
                   do (case ch
                        (#\. nil)  ; empty
                        (#\* (push (list x y) food))
                        (#\# (push (list x y) hazards))
                        (#\Y (push (cons :head (list x y)) you-cells))
                        (#\y (push (cons :body (list x y)) you-cells))
                        ;; Enemy heads
                        ((#\A #\B #\C)
                         (let ((key (char-downcase ch)))
                           (push (cons :head (list x y))
                                 (gethash key enemy-map '()))))
                        ;; Enemy bodies
                        ((#\a #\b #\c)
                         (push (cons :body (list x y))
                               (gethash ch enemy-map '()))))))
    ;; Build "you" body: head first, then body segments
    ;; For body ordering, we do a simple chain-walk from head
    (let* ((you-head-entry (find :head you-cells :key #'car))
           (you-body-entries (remove :head you-cells :key #'car))
           (you-body (when you-head-entry
                       (cons (cdr you-head-entry)
                             (order-body-chain
                              (cdr you-head-entry)
                              (mapcar #'cdr you-body-entries))))))
      ;; Build enemies
      (let ((enemies '()))
        (maphash
         (lambda (ch entries)
           (let* ((head-entry (find :head entries :key #'car))
                  (body-entries (remove :head entries :key #'car))
                  (ebody (when head-entry
                           (cons (cdr head-entry)
                                 (order-body-chain
                                  (cdr head-entry)
                                  (mapcar #'cdr body-entries))))))
             (when ebody
               (push (make-test-snake
                      :id (format nil "enemy-~A" ch)
                      :name (format nil "Enemy ~A" (char-upcase ch))
                      :health enemy-health
                      :body ebody)
                     enemies))))
         enemy-map)
        (values
         (make-test-board :height height :width width
                          :food food :hazards hazards
                          :snakes (if you-body
                                      (cons (make-test-snake
                                             :id "you" :name "You"
                                             :health you-health
                                             :body you-body)
                                            enemies)
                                      enemies))
         you-body
         enemies
         food
         hazards)))))

(defun order-body-chain (head-pos body-positions)
  "Given a head position and unordered body positions, order them into
a chain where each segment is adjacent to the previous.
Falls back to original order if chain can't be built."
  (when (null body-positions)
    (return-from order-body-chain '()))
  (let ((remaining (copy-list body-positions))
        (chain '())
        (current head-pos))
    (loop while remaining
          for next = (find-if (lambda (pos)
                                (= 1 (manhattan-distance
                                       (c (first current) (second current))
                                       (c (first pos) (second pos)))))
                              remaining)
          while next
          do (push next chain)
             (setf remaining (remove next remaining :test #'equal))
             (setf current next))
    ;; Append any remaining segments that couldn't be chained
    ;; (stacked segments, e.g., a freshly spawned snake)
    (append (nreverse chain) remaining)))

;;; --- High-level scenario constructor ---

(defun state-from-diagram (rows &key (turn 0) (you-health 100)
                                     (enemy-health 100)
                                     (timeout 500))
  "Parse an ASCII board diagram into a full game-state.

Usage:
  (state-from-diagram
    '(\". . . . .\"
      \". Y y . .\"
      \". . y * .\"
      \". . A a .\"
      \". . . . .\")
    :you-health 80)
"
  (multiple-value-bind (board you-body enemies)
      (parse-board-diagram rows :you-health you-health
                                :enemy-health enemy-health)
    (declare (ignore enemies))
    (let ((you (find-if (lambda (s) (string= "you" (snake-id s)))
                        (board-snakes board))))
      (cl-battlesnake::make-game-state
       :game (cl-battlesnake::make-game :id "test-game" :timeout timeout)
       :turn turn
       :board board
       :you (or you (make-test-snake :id "you" :body (or you-body '((0 0)))))))))
