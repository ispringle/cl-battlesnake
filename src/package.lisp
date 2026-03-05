(defpackage #:cl-battlesnake
  (:use #:cl)
  (:nicknames #:bs)
  (:export
   #:+up+ #:+down+ #:+left+ #:+right+
   #:all-directions
   #:direction-string
   #:coord #:make-coord #:coord-x #:coord-y #:coord=
   #:snake #:snake-id #:snake-name #:snake-health #:snake-body
   #:snake-head #:snake-length #:snake-latency #:snake-shout #:snake-squad
   #:board #:board-height #:board-width #:board-food #:board-hazards #:board-snakes
   #:game #:game-id #:game-ruleset #:game-timeout #:game-source
   #:game-state #:game-state-game #:game-state-turn #:game-state-board #:game-state-you
   #:move-coord #:neighbors #:in-bounds-p #:occupied-p #:coord-member
   #:manhattan-distance #:nearest-food #:direction-toward
   #:flood-fill #:reachable-area
   #:safe-moves #:safe-moves-avoiding-heads
   #:enemy-snakes #:closest-enemy-head #:tail-coord
   #:battlesnake #:snake-info #:on-start #:on-move #:on-end
   #:defsnake
   #:start-server #:start-multi-snake-server #:stop-server))
