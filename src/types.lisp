(in-package #:cl-battlesnake)

;;; --- Directions ---

(alexandria:define-constant +up+    "up" :test #'string=)
(alexandria:define-constant +down+  "down" :test #'string=)
(alexandria:define-constant +left+  "left" :test #'string=)
(alexandria:define-constant +right+ "right" :test #'string=)

(defun all-directions ()
  (list +up+ +down+ +left+ +right+))

;;; --- Coordinates ---

(defstruct (coord (:constructor make-coord (x y)))
  (x 0 :type fixnum)
  (y 0 :type fixnum))

(defmethod print-object ((c coord) stream)
  (print-unreadable-object (c stream :type t)
    (format stream "~D,~D" (coord-x c) (coord-y c))))

(defun coord= (a b)
  "Value equality for coordinates."
  (and (= (coord-x a) (coord-x b))
       (= (coord-y a) (coord-y b))))

;;; --- Snake ---

(defstruct snake
  (id       "" :type string)
  (name     "" :type string)
  (health   0  :type fixnum)
  (body     () :type list)        ; list of coord
  (head     nil)                  ; coord
  (length   0  :type fixnum)
  (latency  "" :type string)
  (shout    "" :type string)
  (squad    "" :type string))

;;; --- Board ---

(defstruct board
  (height  0  :type fixnum)
  (width   0  :type fixnum)
  (food    () :type list)         ; list of coord
  (hazards () :type list)         ; list of coord
  (snakes  () :type list))        ; list of snake

;;; --- Game ---

(defstruct game
  (id      "" :type string)
  (ruleset nil)                   ; alist
  (timeout 500 :type fixnum)
  (source  "" :type string))

;;; --- Game State (the full /move request) ---

(defstruct game-state
  (game nil)                      ; game
  (turn 0 :type fixnum)
  (board nil)                     ; board
  (you  nil))                     ; snake
