;; Production Method Contract
;; Records farming or processing techniques

(define-data-var last-method-id uint u0)
(define-data-var contract-owner principal tx-sender)

;; Map of method IDs to production method information
(define-map production-methods
  { method-id: uint }
  {
    name: (string-ascii 100),
    description: (string-ascii 500),
    created-by: principal,
    creation-date: uint
  }
)

;; Map of product IDs to production method IDs
(define-map product-methods
  { product-id: uint }
  { method-id: uint }
)

;; Register a new production method
(define-public (register-method (name (string-ascii 100)) (description (string-ascii 500)))
  (let
    (
      (new-id (+ (var-get last-method-id) u1))
    )
    (map-set production-methods
      {method-id: new-id}
      {
        name: name,
        description: description,
        created-by: tx-sender,
        creation-date: block-height
      }
    )
    (var-set last-method-id new-id)
    (ok new-id)
  )
)

;; Assign a production method to a product
(define-public (assign-method-to-product (product-id uint) (method-id uint))
  (begin
    ;; Verify the method exists
    (asserts! (is-some (map-get? production-methods {method-id: method-id})) (err u404))

    ;; Assign the method to the product
    (map-set product-methods {product-id: product-id} {method-id: method-id})
    (ok true)
  )
)

;; Get production method information
(define-read-only (get-method-info (method-id uint))
  (map-get? production-methods {method-id: method-id})
)

;; Get the production method for a product
(define-read-only (get-product-method (product-id uint))
  (map-get? product-methods {product-id: product-id})
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
