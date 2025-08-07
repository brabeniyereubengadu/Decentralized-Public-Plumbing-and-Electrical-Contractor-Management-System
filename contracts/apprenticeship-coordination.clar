;; Apprenticeship Program Coordination Contract
;; Manages training programs for new plumbers and electricians

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-APPRENTICE-NOT-FOUND (err u404))
(define-constant ERR-PROGRAM-NOT-FOUND (err u405))
(define-constant ERR-INVALID-INPUT (err u100))
(define-constant ERR-APPRENTICE-ALREADY-ENROLLED (err u301))
(define-constant ERR-PROGRAM-FULL (err u302))
(define-constant ERR-INVALID-PROGRESS (err u303))

;; Data Variables
(define-data-var apprentice-counter uint u0)
(define-data-var program-counter uint u0)

;; Data Maps
(define-map apprentices
  { apprentice-id: uint }
  {
    apprentice: principal,
    name: (string-ascii 100),
    program-id: uint,
    mentor: principal,
    start-date: uint,
    expected-completion: uint,
    actual-completion: (optional uint),
    status: (string-ascii 20),
    hours-completed: uint,
    hours-required: uint,
    current-phase: (string-ascii 50),
    performance-rating: uint
  }
)

(define-map programs
  { program-id: uint }
  {
    name: (string-ascii 100),
    trade: (string-ascii 30),
    duration-months: uint,
    max-apprentices: uint,
    current-enrollment: uint,
    coordinator: principal,
    active: bool,
    requirements: (string-ascii 300),
    phases: (list 10 (string-ascii 50))
  }
)

(define-map apprentice-progress
  { apprentice-id: uint, phase: (string-ascii 50) }
  {
    completed: bool,
    completion-date: (optional uint),
    mentor-approval: bool,
    notes: (string-ascii 200)
  }
)

(define-map mentors
  { mentor: principal }
  {
    name: (string-ascii 100),
    trade: (string-ascii 30),
    license-id: uint,
    active: bool,
    max-apprentices: uint,
    current-apprentices: uint,
    rating: uint
  }
)

(define-map authorized-coordinators
  { coordinator: principal }
  { authorized: bool }
)

;; Initialize contract owner as authorized coordinator
(map-set authorized-coordinators { coordinator: CONTRACT-OWNER } { authorized: true })

;; Public Functions

;; Create a new apprenticeship program
(define-public (create-program
  (name (string-ascii 100))
  (trade (string-ascii 30))
  (duration-months uint)
  (max-apprentices uint)
  (requirements (string-ascii 300))
  (phases (list 10 (string-ascii 50))))
  (let
    (
      (program-id (+ (var-get program-counter) u1))
    )
    (asserts! (is-authorized-coordinator tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> duration-months u0) ERR-INVALID-INPUT)
    (asserts! (> max-apprentices u0) ERR-INVALID-INPUT)

    (map-set programs
      { program-id: program-id }
      {
        name: name,
        trade: trade,
        duration-months: duration-months,
        max-apprentices: max-apprentices,
        current-enrollment: u0,
        coordinator: tx-sender,
        active: true,
        requirements: requirements,
        phases: phases
      }
    )

    (var-set program-counter program-id)
    (ok program-id)
  )
)

;; Register a mentor
(define-public (register-mentor
  (mentor principal)
  (name (string-ascii 100))
  (trade (string-ascii 30))
  (license-id uint)
  (max-apprentices uint))
  (begin
    (asserts! (is-authorized-coordinator tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (> max-apprentices u0) ERR-INVALID-INPUT)

    (map-set mentors
      { mentor: mentor }
      {
        name: name,
        trade: trade,
        license-id: license-id,
        active: true,
        max-apprentices: max-apprentices,
        current-apprentices: u0,
        rating: u5
      }
    )

    (ok true)
  )
)

;; Enroll an apprentice
(define-public (enroll-apprentice
  (apprentice principal)
  (name (string-ascii 100))
  (program-id uint)
  (mentor principal))
  (let
    (
      (apprentice-id (+ (var-get apprentice-counter) u1))
      (program-data (unwrap! (map-get? programs { program-id: program-id }) ERR-PROGRAM-NOT-FOUND))
      (mentor-data (unwrap! (map-get? mentors { mentor: mentor }) (err u404)))
      (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u500)))
      (completion-time (+ current-time (* (get duration-months program-data) u2629746))) ;; ~30.44 days per month
    )
    (asserts! (is-authorized-coordinator tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (get active program-data) ERR-PROGRAM-NOT-FOUND)
    (asserts! (get active mentor-data) (err u404))
    (asserts! (< (get current-enrollment program-data) (get max-apprentices program-data)) ERR-PROGRAM-FULL)
    (asserts! (< (get current-apprentices mentor-data) (get max-apprentices mentor-data)) (err u305))

    (map-set apprentices
      { apprentice-id: apprentice-id }
      {
        apprentice: apprentice,
        name: name,
        program-id: program-id,
        mentor: mentor,
        start-date: current-time,
        expected-completion: completion-time,
        actual-completion: none,
        status: "active",
        hours-completed: u0,
        hours-required: (* (get duration-months program-data) u160), ;; ~40 hours/week * 4 weeks/month
        current-phase: "orientation",
        performance-rating: u3
      }
    )

    ;; Update program enrollment
    (map-set programs
      { program-id: program-id }
      (merge program-data {
        current-enrollment: (+ (get current-enrollment program-data) u1)
      })
    )

    ;; Update mentor apprentice count
    (map-set mentors
      { mentor: mentor }
      (merge mentor-data {
        current-apprentices: (+ (get current-apprentices mentor-data) u1)
      })
    )

    (var-set apprentice-counter apprentice-id)
    (ok apprentice-id)
  )
)

;; Update apprentice progress
(define-public (update-progress
  (apprentice-id uint)
  (phase (string-ascii 50))
  (hours-completed uint)
  (notes (string-ascii 200)))
  (let
    (
      (apprentice-data (unwrap! (map-get? apprentices { apprentice-id: apprentice-id }) ERR-APPRENTICE-NOT-FOUND))
      (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u500)))
    )
    (asserts! (is-eq tx-sender (get mentor apprentice-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status apprentice-data) "active") ERR-INVALID-PROGRESS)
    (asserts! (<= hours-completed (get hours-required apprentice-data)) ERR-INVALID-INPUT)

    ;; Update apprentice record
    (map-set apprentices
      { apprentice-id: apprentice-id }
      (merge apprentice-data {
        hours-completed: hours-completed,
        current-phase: phase
      })
    )

    ;; Update phase progress
    (map-set apprentice-progress
      { apprentice-id: apprentice-id, phase: phase }
      {
        completed: true,
        completion-date: (some current-time),
        mentor-approval: true,
        notes: notes
      }
    )

    (ok true)
  )
)

;; Complete apprenticeship
(define-public (complete-apprenticeship (apprentice-id uint))
  (let
    (
      (apprentice-data (unwrap! (map-get? apprentices { apprentice-id: apprentice-id }) ERR-APPRENTICE-NOT-FOUND))
      (program-data (unwrap! (map-get? programs { program-id: (get program-id apprentice-data) }) ERR-PROGRAM-NOT-FOUND))
      (mentor-data (unwrap! (map-get? mentors { mentor: (get mentor apprentice-data) }) (err u404)))
      (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u500)))
    )
    (asserts! (is-authorized-coordinator tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status apprentice-data) "active") ERR-INVALID-PROGRESS)
    (asserts! (>= (get hours-completed apprentice-data) (get hours-required apprentice-data)) ERR-INVALID-PROGRESS)

    ;; Update apprentice status
    (map-set apprentices
      { apprentice-id: apprentice-id }
      (merge apprentice-data {
        status: "completed",
        actual-completion: (some current-time)
      })
    )

    ;; Update program enrollment
    (map-set programs
      { program-id: (get program-id apprentice-data) }
      (merge program-data {
        current-enrollment: (- (get current-enrollment program-data) u1)
      })
    )

    ;; Update mentor apprentice count
    (map-set mentors
      { mentor: (get mentor apprentice-data) }
      (merge mentor-data {
        current-apprentices: (- (get current-apprentices mentor-data) u1)
      })
    )

    (ok true)
  )
)

;; Rate apprentice performance
(define-public (rate-apprentice (apprentice-id uint) (rating uint))
  (let
    (
      (apprentice-data (unwrap! (map-get? apprentices { apprentice-id: apprentice-id }) ERR-APPRENTICE-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get mentor apprentice-data)) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= rating u1) (<= rating u5)) ERR-INVALID-INPUT)

    (map-set apprentices
      { apprentice-id: apprentice-id }
      (merge apprentice-data { performance-rating: rating })
    )

    (ok true)
  )
)

;; Deactivate program
(define-public (deactivate-program (program-id uint))
  (let
    (
      (program-data (unwrap! (map-get? programs { program-id: program-id }) ERR-PROGRAM-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get coordinator program-data)) ERR-NOT-AUTHORIZED)

    (map-set programs
      { program-id: program-id }
      (merge program-data { active: false })
    )

    (ok true)
  )
)

;; Add authorized coordinator
(define-public (add-authorized-coordinator (coordinator principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set authorized-coordinators { coordinator: coordinator } { authorized: true })
    (ok true)
  )
)

;; Read-only Functions

;; Get apprentice details
(define-read-only (get-apprentice (apprentice-id uint))
  (map-get? apprentices { apprentice-id: apprentice-id })
)

;; Get program details
(define-read-only (get-program (program-id uint))
  (map-get? programs { program-id: program-id })
)

;; Get mentor details
(define-read-only (get-mentor (mentor principal))
  (map-get? mentors { mentor: mentor })
)

;; Get apprentice progress for a phase
(define-read-only (get-apprentice-progress (apprentice-id uint) (phase (string-ascii 50)))
  (map-get? apprentice-progress { apprentice-id: apprentice-id, phase: phase })
)

;; Check if user is authorized coordinator
(define-read-only (is-authorized-coordinator (coordinator principal))
  (default-to false (get authorized (map-get? authorized-coordinators { coordinator: coordinator })))
)

;; Get total apprentices
(define-read-only (get-apprentice-counter)
  (var-get apprentice-counter)
)

;; Get total programs
(define-read-only (get-program-counter)
  (var-get program-counter)
)

;; Calculate apprentice completion percentage
(define-read-only (get-completion-percentage (apprentice-id uint))
  (match (map-get? apprentices { apprentice-id: apprentice-id })
    apprentice-data
    (if (> (get hours-required apprentice-data) u0)
      (/ (* (get hours-completed apprentice-data) u100) (get hours-required apprentice-data))
      u0
    )
    u0
  )
)
