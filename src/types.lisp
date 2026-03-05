(in-package #:cl-battlesnake)

;;; --- Directions ---

(defconstant +up+    :up)
(defconstant +down+  :down)
(defconstant +left+  :left)
(defconstant +right+ :right)

(defun direction-string (dir)
  "Convert a direction keyword to its JSON string representation."
  (ecase dir
    (:up "up")
    (:down "down")
    (:left "left")
    (:right "right")))

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

;;; --- Bitvector safe-moves representation ---

(defconstant +dir-up+    0)
(defconstant +dir-down+  1)
(defconstant +dir-left+  2)
(defconstant +dir-right+ 3)

(defun direction-index (dir)
  "Return the bit index for a direction keyword."
  (ecase dir (:up 0) (:down 1) (:left 2) (:right 3)))

(defun index-direction (idx)
  "Return the direction keyword for a bit index."
  (ecase idx (0 :up) (1 :down) (2 :left) (3 :right)))

(defun make-safe-moves ()
  "Return a fresh 4-bit vector with all moves safe."
  (make-array 4 :element-type 'bit :initial-element 1))

(defun safe-move-p (bv dir)
  "Is DIR safe in bitvector BV?"
  (= 1 (sbit bv (direction-index dir))))

(defun mark-unsafe (bv dir)
  "Mark DIR as unsafe in bitvector BV."
  (setf (sbit bv (direction-index dir)) 0)
  bv)

(defun safe-moves-list (bv)
  "Convert a safe-moves bitvector to a list of direction keywords."
  (loop for i below 4 when (= 1 (sbit bv i)) collect (index-direction i)))

(defun safe-moves-count (bv)
  "Count of safe moves in bitvector."
  (count 1 bv))
