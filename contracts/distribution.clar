;; Distribution Tracking Contract
;; Monitors movement through supply chain

(define-data-var last-product-id uint u0)
(define-data-var contract-owner principal tx-sender)

;; Map of product IDs to product information
(define-map products
  { product-id: uint }
  {
    name: (string-ascii 100),
    description: (string-ascii 500),
    producer-id: uint,
    current-owner: principal,
    creation-date: uint
  }
)

;; Map to track product transfer history
(define-map product-transfers
  { product-id: uint, transfer-index: uint }
  {
    from: principal,
    to: principal,
    timestamp: uint,
    location: (optional (string-ascii 100))
  }
)

;; Map to track the number of transfers for each product
(define-map product-transfer-count
  { product-id: uint }
  { count: uint }
)

;; Map of producer IDs to producer information (simplified for this contract)
(define-map producers
  { producer-id: uint }
  {
    address: principal,
    verified: bool
  }
)

;; Register a producer (simplified for this contract)
(define-public (register-producer (producer-id uint) (producer-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u403))
    (map-set producers
      {producer-id: producer-id}
      {
        address: producer-address,
        verified: true
      }
    )
    (ok true)
  )
)

;; Register a new product
(define-public (register-product (name (string-ascii 100)) (description (string-ascii 500)) (producer-id uint))
  (let
    (
      (new-id (+ (var-get last-product-id) u1))
      (producer-info (default-to {address: tx-sender, verified: false} (map-get? producers {producer-id: producer-id})))
    )
    ;; Verify the producer is registered and verified
    (asserts! (get verified producer-info) (err u403))

    ;; Verify the caller is the registered producer
    (asserts! (is-eq (get address producer-info) tx-sender) (err u403))

    ;; Create the product
    (map-set products
      {product-id: new-id}
      {
        name: name,
        description: description,
        producer-id: producer-id,
        current-owner: tx-sender,
        creation-date: block-height
      }
    )

    ;; Initialize transfer count
    (map-set product-transfer-count {product-id: new-id} {count: u0})

    (var-set last-product-id new-id)
    (ok new-id)
  )
)

;; Transfer a product to a new owner
(define-public (transfer-product (product-id uint) (to principal) (location (optional (string-ascii 100))))
  (let
    (
      (product-info (unwrap! (map-get? products {product-id: product-id}) (err u404)))
      (transfer-count (unwrap! (map-get? product-transfer-count {product-id: product-id}) (err u404)))
      (new-count (+ (get count transfer-count) u1))
    )
    ;; Verify the caller is the current owner
    (asserts! (is-eq (get current-owner product-info) tx-sender) (err u403))

    ;; Record the transfer
    (map-set product-transfers
      {product-id: product-id, transfer-index: (get count transfer-count)}
      {
        from: tx-sender,
        to: to,
        timestamp: block-height,
        location: location
      }
    )

    ;; Update the transfer count
    (map-set product-transfer-count {product-id: product-id} {count: new-count})

    ;; Update the current owner
    (map-set products
      {product-id: product-id}
      (merge product-info {current-owner: to})
    )

    (ok true)
  )
)

;; Get product information
(define-read-only (get-product-info (product-id uint))
  (map-get? products {product-id: product-id})
)

;; Get product transfer history
(define-read-only (get-product-transfer (product-id uint) (transfer-index uint))
  (map-get? product-transfers {product-id: product-id, transfer-index: transfer-index})
)

;; Get the number of transfers for a product
(define-read-only (get-product-transfer-count (product-id uint))
  (default-to {count: u0} (map-get? product-transfer-count {product-id: product-id}))
)

;; Check if a principal is the producer of a product
(define-read-only (is-product-producer (product-id uint) (producer principal))
  (match (map-get? products {product-id: product-id})
    product-info
      (match (map-get? producers {producer-id: (get producer-id product-info)})
        producer-data (is-eq (get address producer-data) producer)
        false
      )
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
