(in-package #:cl-battlesnake)

;;; Parse Battlesnake JSON (hash-tables from jzon) into our structs.
;;; jzon parses JSON objects as hash-tables, arrays as vectors, strings
;;; as strings, numbers as numbers, booleans as :true/:false, null as :null.

(defun href (ht &rest keys)
  "Nested hash-table lookup."
  (reduce (lambda (table key)
            (when (hash-table-p table)
              (gethash key table)))
          keys :initial-value ht))

(defun parse-coord (ht)
  (when (hash-table-p ht)
    (make-coord (gethash "x" ht 0)
                (gethash "y" ht 0))))

(defun parse-coord-list (vec)
  (when vec
    (map 'list #'parse-coord vec)))

(defun parse-snake (ht)
  (when (hash-table-p ht)
    (make-snake
     :id      (gethash "id" ht "")
     :name    (gethash "name" ht "")
     :health  (gethash "health" ht 0)
     :body    (parse-coord-list (gethash "body" ht #()))
     :head    (parse-coord (gethash "head" ht))
     :length  (gethash "length" ht 0)
     :latency (let ((v (gethash "latency" ht "")))
                (if (stringp v) v (princ-to-string v)))
     :shout   (gethash "shout" ht "")
     :squad   (gethash "squad" ht ""))))

(defun parse-board (ht)
  (when (hash-table-p ht)
    (make-board
     :height  (gethash "height" ht 0)
     :width   (gethash "width" ht 0)
     :food    (parse-coord-list (gethash "food" ht #()))
     :hazards (parse-coord-list (gethash "hazards" ht #()))
     :snakes  (map 'list #'parse-snake (gethash "snakes" ht #())))))

(defun parse-game (ht)
  (when (hash-table-p ht)
    (make-game
     :id      (gethash "id" ht "")
     :ruleset (gethash "ruleset" ht)
     :timeout (gethash "timeout" ht 500)
     :source  (gethash "source" ht ""))))

(defun parse-game-state (ht)
  "Parse the full move request JSON (as a hash-table) into a game-state."
  (make-game-state
   :game  (parse-game (gethash "game" ht))
   :turn  (gethash "turn" ht 0)
   :board (parse-board (gethash "board" ht))
   :you   (parse-snake (gethash "you" ht))))

(defun read-json-body (env)
  "Read and parse JSON body from a Clack env."
  (let ((stream (getf env :raw-body))
        (len (getf env :content-length)))
    (when (and stream len (plusp len))
      (let ((buf (make-array len :element-type '(unsigned-byte 8))))
        (read-sequence buf stream)
        (com.inuoe.jzon:parse (sb-ext:octets-to-string buf :external-format :utf-8))))))
