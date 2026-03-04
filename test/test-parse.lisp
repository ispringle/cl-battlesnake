(in-package #:cl-battlesnake/test)

(def-suite parse-tests :in battlesnake-tests
  :description "Tests for JSON parsing")

(in-suite parse-tests)

(defun sample-move-json ()
  "A realistic /move request body as a JSON string."
  "{
  \"game\": {
    \"id\": \"game-id-123\",
    \"ruleset\": {\"name\": \"standard\", \"version\": \"v1.2.3\"},
    \"timeout\": 500,
    \"source\": \"league\"
  },
  \"turn\": 42,
  \"board\": {
    \"height\": 11,
    \"width\": 11,
    \"food\": [{\"x\": 5, \"y\": 5}, {\"x\": 9, \"y\": 0}],
    \"hazards\": [{\"x\": 0, \"y\": 0}],
    \"snakes\": [
      {
        \"id\": \"snake-you\",
        \"name\": \"My Snake\",
        \"health\": 80,
        \"body\": [{\"x\": 3, \"y\": 3}, {\"x\": 3, \"y\": 2}, {\"x\": 3, \"y\": 1}],
        \"head\": {\"x\": 3, \"y\": 3},
        \"length\": 3,
        \"latency\": \"45\",
        \"shout\": \"hello\",
        \"squad\": \"\"
      },
      {
        \"id\": \"snake-enemy\",
        \"name\": \"Enemy\",
        \"health\": 90,
        \"body\": [{\"x\": 8, \"y\": 8}, {\"x\": 8, \"y\": 7}],
        \"head\": {\"x\": 8, \"y\": 8},
        \"length\": 2,
        \"latency\": \"30\",
        \"shout\": \"\",
        \"squad\": \"\"
      }
    ]
  },
  \"you\": {
    \"id\": \"snake-you\",
    \"name\": \"My Snake\",
    \"health\": 80,
    \"body\": [{\"x\": 3, \"y\": 3}, {\"x\": 3, \"y\": 2}, {\"x\": 3, \"y\": 1}],
    \"head\": {\"x\": 3, \"y\": 3},
    \"length\": 3,
    \"latency\": \"45\",
    \"shout\": \"hello\",
    \"squad\": \"\"
  }
}")

(test parse-full-move-request
  "Parsing a complete /move request produces correct struct tree."
  (let* ((ht (com.inuoe.jzon:parse (sample-move-json)))
         (state (cl-battlesnake::parse-game-state ht)))
    ;; Game
    (is (string= "game-id-123" (game-id (game-state-game state))))
    (is (= 500 (game-timeout (game-state-game state))))
    (is (string= "league" (game-source (game-state-game state))))
    ;; Turn
    (is (= 42 (game-state-turn state)))
    ;; Board dimensions
    (is (= 11 (board-height (game-state-board state))))
    (is (= 11 (board-width (game-state-board state))))
    ;; Food
    (is (= 2 (length (board-food (game-state-board state)))))
    (is (coord= (c 5 5) (first (board-food (game-state-board state)))))
    ;; Hazards
    (is (= 1 (length (board-hazards (game-state-board state)))))
    ;; Snakes
    (is (= 2 (length (board-snakes (game-state-board state)))))
    ;; You
    (let ((you (game-state-you state)))
      (is (string= "snake-you" (snake-id you)))
      (is (= 80 (snake-health you)))
      (is (= 3 (snake-length you)))
      (is (coord= (c 3 3) (snake-head you)))
      (is (= 3 (length (snake-body you))))
      (is (string= "45" (snake-latency you)))
      (is (string= "hello" (snake-shout you))))))

(test parse-coord-values
  "Individual coord parsing."
  (let ((ht (com.inuoe.jzon:parse "{\"x\": 7, \"y\": 3}")))
    (let ((coord (cl-battlesnake::parse-coord ht)))
      (is (= 7 (coord-x coord)))
      (is (= 3 (coord-y coord))))))

(test parse-handles-missing-fields
  "Missing fields get defaults."
  (let* ((ht (com.inuoe.jzon:parse "{\"id\": \"s1\"}"))
         (snake (cl-battlesnake::parse-snake ht)))
    (is (string= "s1" (snake-id snake)))
    (is (string= "" (snake-name snake)))
    (is (= 0 (snake-health snake)))
    (is (= 0 (snake-length snake)))))

(test parse-snake-latency-as-number
  "Some engines send latency as a number, not string."
  (let* ((ht (com.inuoe.jzon:parse
              "{\"id\": \"s1\", \"latency\": 123}"))
         (snake (cl-battlesnake::parse-snake ht)))
    (is (string= "123" (snake-latency snake)))))
