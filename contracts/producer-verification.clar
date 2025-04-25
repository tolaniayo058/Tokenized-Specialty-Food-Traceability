;; Producer Verification Contract
;; This contract validates authentic food sources

(define-data-var last-producer-id uint u0)
(define-data-var contract-owner principal tx-sender)

;; Map of producer IDs to producer information
(define-map producers
  { producer-id: uint }
  {
    name: (string-ascii 100),
    location: (string-ascii 100),
    verified: bool,
    registration-date: uint
  }
)

;; Map of producer addresses to producer IDs
(define-map producer-addresses
  { address: principal }
  { producer-id: uint }
)

;; Register a new producer
(define-public (register-producer (name (string-ascii 100)) (location (string-ascii 100)))
  (let
    (
      (new-id (+ (var-get last-producer-id) u1))
    )
    (asserts! (is-none (map-get? producer-addresses {address: tx-sender})) (err u1)) ;; Producer already registered
    (map-set producers
      {producer-id: new-id}
      {
        name: name,
        location: location,
        verified: false,
        registration-date: block-height
      }
    )
    (map-set producer-addresses {address: tx-sender} {producer-id: new-id})
    (var-set last-producer-id new-id)
    (ok new-id)
  )
)

;; Verify a producer (only contract owner can do this)
(define-public (verify-producer (producer-id uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u403)) ;; Only contract owner can verify
    (match (map-get? producers {producer-id: producer-id})
      producer-data (begin
        (map-set producers
          {producer-id: producer-id}
          (merge producer-data {verified: true})
        )
        (ok true)
      )
      (err u404) ;; Producer not found
    )
  )
)

;; Check if a producer is verified
(define-read-only (is-producer-verified (producer-id uint))
  (match (map-get? producers {producer-id: producer-id})
    producer-data (ok (get verified producer-data))
    (err u404) ;; Producer not found
  )
)

;; Get producer information
(define-read-only (get-producer-info (producer-id uint))
  (map-get? producers {producer-id: producer-id})
)

;; Get producer ID by address
(define-read-only (get-producer-id-by-address (address principal))
  (map-get? producer-addresses {address: address})
)

;; Transfer contract ownership
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u403))
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; Get contract owner
(define-read-only (get-contract-owner)
  (var-get contract-owner)
)
