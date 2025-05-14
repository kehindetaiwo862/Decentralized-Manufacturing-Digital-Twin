;; facility-verification.clar
;; This contract validates production sites in a decentralized manufacturing network

(define-data-var admin principal tx-sender)

;; Facility status enum
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_REJECTED u2)

;; Facility data structure
(define-map facilities
  { facility-id: (string-ascii 32) }
  {
    owner: principal,
    name: (string-ascii 64),
    location: (string-ascii 128),
    certification-date: uint,
    status: uint,
    verification-hash: (buff 32)
  }
)

;; Facility verification requests
(define-map verification-requests
  { facility-id: (string-ascii 32) }
  {
    owner: principal,
    submission-date: uint,
    documents-hash: (buff 32)
  }
)

;; Public functions

;; Register a new facility for verification
(define-public (register-facility
    (facility-id (string-ascii 32))
    (name (string-ascii 64))
    (location (string-ascii 128))
    (documents-hash (buff 32)))
  (begin
    ;; Check if facility ID already exists - fixed to check for none
    (asserts! (is-none (map-get? facilities { facility-id: facility-id })) (err u1)) ;; Facility ID already exists

    ;; Create verification request
    (map-set verification-requests
      { facility-id: facility-id }
      {
        owner: tx-sender,
        submission-date: block-height,
        documents-hash: documents-hash
      }
    )

    ;; Initialize facility with pending status
    (map-set facilities
      { facility-id: facility-id }
      {
        owner: tx-sender,
        name: name,
        location: location,
        certification-date: u0,
        status: STATUS_PENDING,
        verification-hash: 0x0000000000000000000000000000000000000000000000000000000000000000
      }
    )

    (ok facility-id)
  )
)

;; Verify a facility (admin only)
(define-public (verify-facility
    (facility-id (string-ascii 32))
    (verification-hash (buff 32)))
  (let ((facility (unwrap! (map-get? facilities { facility-id: facility-id }) (err u2)))) ;; Facility not found
    (begin
      (asserts! (is-eq tx-sender (var-get admin)) (err u3)) ;; Not authorized
      (asserts! (is-eq (get status facility) STATUS_PENDING) (err u4)) ;; Not in pending status

      (map-set facilities
        { facility-id: facility-id }
        (merge facility {
          status: STATUS_VERIFIED,
          certification-date: block-height,
          verification-hash: verification-hash
        })
      )

      (ok true)
    )
  )
)

;; Reject a facility verification request (admin only)
(define-public (reject-facility (facility-id (string-ascii 32)))
  (let ((facility (unwrap! (map-get? facilities { facility-id: facility-id }) (err u2)))) ;; Facility not found
    (begin
      (asserts! (is-eq tx-sender (var-get admin)) (err u3)) ;; Not authorized
      (asserts! (is-eq (get status facility) STATUS_PENDING) (err u4)) ;; Not in pending status

      (map-set facilities
        { facility-id: facility-id }
        (merge facility {
          status: STATUS_REJECTED
        })
      )

      (ok true)
    )
  )
)

;; Read-only functions

;; Get facility details
(define-read-only (get-facility (facility-id (string-ascii 32)))
  (map-get? facilities { facility-id: facility-id })
)

;; Get verification request details
(define-read-only (get-verification-request (facility-id (string-ascii 32)))
  (map-get? verification-requests { facility-id: facility-id })
)

;; Check if facility is verified
(define-read-only (is-facility-verified (facility-id (string-ascii 32)))
  (match (map-get? facilities { facility-id: facility-id })
    facility (is-eq (get status facility) STATUS_VERIFIED)
    false
  )
)

;; Admin functions

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) (err u3)) ;; Not authorized
    (var-set admin new-admin)
    (ok true)
  )
)
