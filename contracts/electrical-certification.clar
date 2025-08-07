;; Electrical Contractor Certification Contract
;; Manages licenses for electricians and electrical installation companies

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-CERTIFICATION-NOT-FOUND (err u404))
(define-constant ERR-CERTIFICATION-EXPIRED (err u300))
(define-constant ERR-INVALID-INPUT (err u100))
(define-constant ERR-CERTIFICATION-ALREADY-EXISTS (err u301))
(define-constant ERR-INVALID-CERTIFICATION-LEVEL (err u302))

;; Data Variables
(define-data-var certification-counter uint u0)
(define-data-var certification-fee uint u1200000) ;; 1.2 STX in microSTX

;; Data Maps
(define-map certifications
  { certification-id: uint }
  {
    electrician: principal,
    name: (string-ascii 100),
    certification-level: (string-ascii 30),
    specialty: (string-ascii 50),
    issue-date: uint,
    expiry-date: uint,
    status: (string-ascii 20),
    continuing-education-hours: uint,
    renewal-count: uint
  }
)

(define-map electrician-certifications
  { electrician: principal }
  { certification-id: uint }
)

(define-map authorized-certifiers
  { certifier: principal }
  { authorized: bool }
)

(define-map valid-certification-levels
  { level: (string-ascii 30) }
  { valid: bool }
)

;; Initialize valid certification levels
(map-set valid-certification-levels { level: "apprentice" } { valid: true })
(map-set valid-certification-levels { level: "journeyman" } { valid: true })
(map-set valid-certification-levels { level: "master" } { valid: true })
(map-set valid-certification-levels { level: "contractor" } { valid: true })

;; Initialize contract owner as authorized certifier
(map-set authorized-certifiers { certifier: CONTRACT-OWNER } { authorized: true })

;; Public Functions

;; Issue a new certification
(define-public (issue-certification
  (electrician principal)
  (name (string-ascii 100))
  (certification-level (string-ascii 30))
  (specialty (string-ascii 50))
  (validity-days uint)
  (ce-hours uint))
  (let
    (
      (certification-id (+ (var-get certification-counter) u1))
      (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u500)))
      (expiry-date (+ current-time (* validity-days u86400)))
    )
    (asserts! (is-authorized-certifier tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> (len name) u0) ERR-INVALID-INPUT)
    (asserts! (is-valid-certification-level certification-level) ERR-INVALID-CERTIFICATION-LEVEL)
    (asserts! (> validity-days u0) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? electrician-certifications { electrician: electrician })) ERR-CERTIFICATION-ALREADY-EXISTS)

    (map-set certifications
      { certification-id: certification-id }
      {
        electrician: electrician,
        name: name,
        certification-level: certification-level,
        specialty: specialty,
        issue-date: current-time,
        expiry-date: expiry-date,
        status: "active",
        continuing-education-hours: ce-hours,
        renewal-count: u0
      }
    )

    (map-set electrician-certifications
      { electrician: electrician }
      { certification-id: certification-id }
    )

    (var-set certification-counter certification-id)
    (ok certification-id)
  )
)

;; Renew an existing certification
(define-public (renew-certification (certification-id uint) (validity-days uint) (additional-ce-hours uint))
  (let
    (
      (cert-data (unwrap! (map-get? certifications { certification-id: certification-id }) ERR-CERTIFICATION-NOT-FOUND))
      (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u500)))
      (new-expiry (+ current-time (* validity-days u86400)))
      (total-ce-hours (+ (get continuing-education-hours cert-data) additional-ce-hours))
    )
    (asserts! (is-authorized-certifier tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> validity-days u0) ERR-INVALID-INPUT)

    (map-set certifications
      { certification-id: certification-id }
      (merge cert-data {
        expiry-date: new-expiry,
        status: "active",
        continuing-education-hours: total-ce-hours,
        renewal-count: (+ (get renewal-count cert-data) u1)
      })
    )

    (ok true)
  )
)

;; Upgrade certification level
(define-public (upgrade-certification (certification-id uint) (new-level (string-ascii 30)))
  (let
    (
      (cert-data (unwrap! (map-get? certifications { certification-id: certification-id }) ERR-CERTIFICATION-NOT-FOUND))
    )
    (asserts! (is-authorized-certifier tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-certification-level new-level) ERR-INVALID-CERTIFICATION-LEVEL)
    (asserts! (is-eq (get status cert-data) "active") (err u303))

    (map-set certifications
      { certification-id: certification-id }
      (merge cert-data { certification-level: new-level })
    )

    (ok true)
  )
)

;; Suspend a certification
(define-public (suspend-certification (certification-id uint))
  (let
    (
      (cert-data (unwrap! (map-get? certifications { certification-id: certification-id }) ERR-CERTIFICATION-NOT-FOUND))
    )
    (asserts! (is-authorized-certifier tx-sender) ERR-NOT-AUTHORIZED)

    (map-set certifications
      { certification-id: certification-id }
      (merge cert-data { status: "suspended" })
    )

    (ok true)
  )
)

;; Reinstate a suspended certification
(define-public (reinstate-certification (certification-id uint))
  (let
    (
      (cert-data (unwrap! (map-get? certifications { certification-id: certification-id }) ERR-CERTIFICATION-NOT-FOUND))
      (current-time (unwrap! (get-block-info? time (- block-height u1)) (err u500)))
    )
    (asserts! (is-authorized-certifier tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status cert-data) "suspended") (err u304))
    (asserts! (> (get expiry-date cert-data) current-time) ERR-CERTIFICATION-EXPIRED)

    (map-set certifications
      { certification-id: certification-id }
      (merge cert-data { status: "active" })
    )

    (ok true)
  )
)

;; Add authorized certifier
(define-public (add-authorized-certifier (certifier principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set authorized-certifiers { certifier: certifier } { authorized: true })
    (ok true)
  )
)

;; Remove authorized certifier
(define-public (remove-authorized-certifier (certifier principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set authorized-certifiers { certifier: certifier } { authorized: false })
    (ok true)
  )
)

;; Update certification fee
(define-public (update-certification-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> new-fee u0) ERR-INVALID-INPUT)
    (var-set certification-fee new-fee)
    (ok true)
  )
)

;; Read-only Functions

;; Get certification details
(define-read-only (get-certification (certification-id uint))
  (map-get? certifications { certification-id: certification-id })
)

;; Get electrician's certification ID
(define-read-only (get-electrician-certification (electrician principal))
  (map-get? electrician-certifications { electrician: electrician })
)

;; Check if certification is valid
(define-read-only (is-certification-valid (certification-id uint))
  (match (map-get? certifications { certification-id: certification-id })
    cert-data
    (let
      (
        (current-time (unwrap! (get-block-info? time (- block-height u1)) false))
      )
      (and
        (is-eq (get status cert-data) "active")
        (> (get expiry-date cert-data) current-time)
      )
    )
    false
  )
)

;; Check if electrician has valid certification
(define-read-only (is-electrician-certified (electrician principal))
  (match (map-get? electrician-certifications { electrician: electrician })
    cert-ref
    (is-certification-valid (get certification-id cert-ref))
    false
  )
)

;; Check if certification level is valid
(define-read-only (is-valid-certification-level (level (string-ascii 30)))
  (default-to false (get valid (map-get? valid-certification-levels { level: level })))
)

;; Check if user is authorized certifier
(define-read-only (is-authorized-certifier (certifier principal))
  (default-to false (get authorized (map-get? authorized-certifiers { certifier: certifier })))
)

;; Get current certification fee
(define-read-only (get-certification-fee)
  (var-get certification-fee)
)

;; Get total certifications issued
(define-read-only (get-certification-counter)
  (var-get certification-counter)
)
