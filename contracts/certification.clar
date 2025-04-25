;; Certification Contract
;; Validates organic or specialty designations

(define-data-var last-certification-id uint u0)
(define-data-var contract-owner principal tx-sender)

;; Map of certification IDs to certification information
(define-map certifications
  { certification-id: uint }
  {
    name: (string-ascii 100),
    issuer: principal,
    description: (string-ascii 500),
    valid-until: uint,
    creation-date: uint
  }
)

;; Map of product IDs to certification IDs
(define-map product-certifications
  { product-id: uint }
  { certification-ids: (list 10 uint) }
)

;; Map of authorized certification issuers
(define-map authorized-issuers
  { address: principal }
  { authorized: bool }
)

;; Register a new certification type
(define-public (register-certification (name (string-ascii 100)) (description (string-ascii 500)) (valid-days uint))
  (let
    (
      (new-id (+ (var-get last-certification-id) u1))
      (valid-until (+ block-height (* valid-days u144))) ;; Approximately blocks per day
    )
    ;; Only authorized issuers can register certifications
    (asserts! (is-authorized-issuer tx-sender) (err u403))

    (map-set certifications
      {certification-id: new-id}
      {
        name: name,
        issuer: tx-sender,
        description: description,
        valid-until: valid-until,
        creation-date: block-height
      }
    )
    (var-set last-certification-id new-id)
    (ok new-id)
  )
)

;; Certify a product
(define-public (certify-product (product-id uint) (certification-id uint))
  (let
    (
      (cert-info (unwrap! (map-get? certifications {certification-id: certification-id}) (err u404)))
      (existing-certs (default-to {certification-ids: (list)} (map-get? product-certifications {product-id: product-id})))
      (updated-certs (unwrap! (as-max-len? (append (get certification-ids existing-certs) certification-id) u10) (err u500)))
    )
    ;; Only the certification issuer can certify products
    (asserts! (is-eq (get issuer cert-info) tx-sender) (err u403))

    ;; Verify the certification is still valid
    (asserts! (< block-height (get valid-until cert-info)) (err u401))

    ;; Add certification to the product
    (map-set product-certifications {product-id: product-id} {certification-ids: updated-certs})
    (ok true)
  )
)

;; Authorize a new certification issuer (only contract owner can do this)
(define-public (authorize-issuer (issuer principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u403))
    (map-set authorized-issuers {address: issuer} {authorized: true})
    (ok true)
  )
)

;; Revoke authorization from a certification issuer
(define-public (revoke-issuer-authorization (issuer principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u403))
    (map-set authorized-issuers {address: issuer} {authorized: false})
    (ok true)
  )
)

;; Check if an address is an authorized certification issuer
(define-read-only (is-authorized-issuer (address principal))
  (default-to false (get authorized (map-get? authorized-issuers {address: address})))
)

;; Get certification information
(define-read-only (get-certification-info (certification-id uint))
  (map-get? certifications {certification-id: certification-id})
)

;; Get all certifications for a product
(define-read-only (get-product-certifications (product-id uint))
  (map-get? product-certifications {product-id: product-id})
)

;; Check if a certification is valid
(define-read-only (is-certification-valid (certification-id uint))
  (match (map-get? certifications {certification-id: certification-id})
    cert-info (< block-height (get valid-until cert-info))
    false
  )
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
