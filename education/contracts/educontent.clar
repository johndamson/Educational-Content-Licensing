;; Educational Content Licensing Smart Contract
;; Manages content creation, licensing, payments, and access control

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u103))
(define-constant ERR_EXPIRED_LICENSE (err u104))
(define-constant ERR_INVALID_DURATION (err u105))
(define-constant ERR_INVALID_INPUT (err u106))
(define-constant MAX_TITLE_LENGTH u100)
(define-constant MAX_DESC_LENGTH u500)
(define-constant MAX_CONTENT_ID u1000000)

;; Data Variables
(define-data-var next-content-id uint u1)
(define-data-var platform-fee uint u500) ;; 5% fee (500/10000)

;; Data Maps
(define-map content-registry
  { content-id: uint }
  {
    creator: principal,
    title: (string-utf8 100),
    description: (string-utf8 500),
    price-per-month: uint,
    created-at: uint,
    is-active: bool,
    total-earnings: uint
  }
)

(define-map user-licenses
  { user: principal, content-id: uint }
  {
    purchased-at: uint,
    expires-at: uint,
    duration-months: uint,
    amount-paid: uint
  }
)

(define-map creator-stats
  { creator: principal }
  {
    total-content: uint,
    total-earnings: uint,
    active-content: uint
  }
)

;; Private validation functions
(define-private (validate-string-input (input (string-utf8 500)) (max-len uint))
  (and (> (len input) u0) (<= (len input) max-len))
)

(define-private (validate-content-id (content-id uint))
  (and (> content-id u0) (< content-id MAX_CONTENT_ID))
)

(define-private (sanitize-title (title (string-utf8 100)))
  (if (validate-string-input title MAX_TITLE_LENGTH) title u"Invalid Title")
)

(define-private (sanitize-description (desc (string-utf8 500)))
  (if (validate-string-input desc MAX_DESC_LENGTH) desc u"Invalid Description")
)

;; Public Functions

;; Create new educational content
(define-public (create-content (title (string-utf8 100)) 
                              (description (string-utf8 500)) 
                              (price-per-month uint))
  (let ((content-id (var-get next-content-id))
        (clean-title (sanitize-title title))
        (clean-desc (sanitize-description description)))
    (begin
      (asserts! (validate-string-input title MAX_TITLE_LENGTH) ERR_INVALID_INPUT)
      (asserts! (validate-string-input description MAX_DESC_LENGTH) ERR_INVALID_INPUT)
      (asserts! (> price-per-month u0) ERR_INVALID_DURATION)
      (map-set content-registry
        { content-id: content-id }
        {
          creator: tx-sender,
          title: clean-title,
          description: clean-desc,
          price-per-month: price-per-month,
          created-at: burn-block-height,
          is-active: true,
          total-earnings: u0
        }
      )
      (update-creator-stats tx-sender u1 u0 u1)
      (var-set next-content-id (+ content-id u1))
      (ok content-id)
    )
  )
)

;; Purchase content license
(define-public (purchase-license (content-id uint) (duration-months uint))
  (let ((validated-id (if (validate-content-id content-id) content-id u0)))
    (let ((content-info (unwrap! (map-get? content-registry { content-id: validated-id }) ERR_NOT_FOUND))
          (total-cost (* (get price-per-month content-info) duration-months))
          (platform-fee-amount (/ (* total-cost (var-get platform-fee)) u10000))
          (creator-amount (- total-cost platform-fee-amount))
          (expires-at (+ burn-block-height (* duration-months u4320)))) ;; ~30 days per month
      (begin
        (asserts! (validate-content-id content-id) ERR_INVALID_INPUT)
        (asserts! (get is-active content-info) ERR_NOT_FOUND)
        (asserts! (and (>= duration-months u1) (<= duration-months u12)) ERR_INVALID_DURATION)
        (try! (stx-transfer? total-cost tx-sender (as-contract tx-sender)))
        (try! (as-contract (stx-transfer? creator-amount tx-sender (get creator content-info))))
        (map-set user-licenses
          { user: tx-sender, content-id: validated-id }
          {
            purchased-at: burn-block-height,
            expires-at: expires-at,
            duration-months: duration-months,
            amount-paid: total-cost
          }
        )
        (map-set content-registry
          { content-id: validated-id }
          (merge content-info { total-earnings: (+ (get total-earnings content-info) creator-amount) })
        )
        (update-creator-stats (get creator content-info) u0 creator-amount u0)
        (ok expires-at)
      )
    )
  )
)

;; Extend existing license
(define-public (extend-license (content-id uint) (additional-months uint))
  (let ((validated-id (if (validate-content-id content-id) content-id u0)))
    (let ((license-info (unwrap! (map-get? user-licenses { user: tx-sender, content-id: validated-id }) ERR_NOT_FOUND))
          (content-info (unwrap! (map-get? content-registry { content-id: validated-id }) ERR_NOT_FOUND))
          (extension-cost (* (get price-per-month content-info) additional-months))
          (platform-fee-amount (/ (* extension-cost (var-get platform-fee)) u10000))
          (creator-amount (- extension-cost platform-fee-amount))
          (new-expires-at (+ (get expires-at license-info) (* additional-months u4320))))
      (begin
        (asserts! (validate-content-id content-id) ERR_INVALID_INPUT)
        (asserts! (get is-active content-info) ERR_NOT_FOUND)
        (asserts! (and (>= additional-months u1) (<= additional-months u12)) ERR_INVALID_DURATION)
        (try! (stx-transfer? extension-cost tx-sender (as-contract tx-sender)))
        (try! (as-contract (stx-transfer? creator-amount tx-sender (get creator content-info))))
        (map-set user-licenses
          { user: tx-sender, content-id: validated-id }
          (merge license-info { expires-at: new-expires-at })
        )
        (map-set content-registry
          { content-id: validated-id }
          (merge content-info { total-earnings: (+ (get total-earnings content-info) creator-amount) })
        )
        (update-creator-stats (get creator content-info) u0 creator-amount u0)
        (ok new-expires-at)
      )
    )
  )
)

;; Update content details (creator only)
(define-public (update-content (content-id uint) 
                              (new-title (string-utf8 100)) 
                              (new-description (string-utf8 500)) 
                              (new-price uint))
  (let ((validated-id (if (validate-content-id content-id) content-id u0)))
    (let ((content-info (unwrap! (map-get? content-registry { content-id: validated-id }) ERR_NOT_FOUND))
          (clean-title (sanitize-title new-title))
          (clean-desc (sanitize-description new-description)))
      (begin
        (asserts! (validate-content-id content-id) ERR_INVALID_INPUT)
        (asserts! (validate-string-input new-title MAX_TITLE_LENGTH) ERR_INVALID_INPUT)
        (asserts! (validate-string-input new-description MAX_DESC_LENGTH) ERR_INVALID_INPUT)
        (asserts! (is-eq tx-sender (get creator content-info)) ERR_UNAUTHORIZED)
        (asserts! (> new-price u0) ERR_INVALID_DURATION)
        (map-set content-registry
          { content-id: validated-id }
          (merge content-info {
            title: clean-title,
            description: clean-desc,
            price-per-month: new-price
          })
        )
        (ok true)
      )
    )
  )
)

;; Toggle content active status (creator only)
(define-public (toggle-content-status (content-id uint))
  (let ((validated-id (if (validate-content-id content-id) content-id u0)))
    (let ((content-info (unwrap! (map-get? content-registry { content-id: validated-id }) ERR_NOT_FOUND)))
      (begin
        (asserts! (validate-content-id content-id) ERR_INVALID_INPUT)
        (asserts! (is-eq tx-sender (get creator content-info)) ERR_UNAUTHORIZED)
        (map-set content-registry
          { content-id: validated-id }
          (merge content-info { is-active: (not (get is-active content-info)) })
        )
        (ok (not (get is-active content-info)))
      )
    )
  )
)

;; Update platform fee (owner only)
(define-public (update-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-fee u2000) ERR_INVALID_DURATION) ;; Max 20% fee
    (var-set platform-fee new-fee)
    (ok true)
  )
)

;; Read-only Functions

;; Check if user has valid license
(define-read-only (has-valid-license (user principal) (content-id uint))
  (let ((validated-id (if (validate-content-id content-id) content-id u0)))
    (match (map-get? user-licenses { user: user, content-id: validated-id })
      license-info (> (get expires-at license-info) burn-block-height)
      false
    )
  )
)

;; Get content information
(define-read-only (get-content-info (content-id uint))
  (let ((validated-id (if (validate-content-id content-id) content-id u0)))
    (map-get? content-registry { content-id: validated-id })
  )
)

;; Get user license information
(define-read-only (get-license-info (user principal) (content-id uint))
  (let ((validated-id (if (validate-content-id content-id) content-id u0)))
    (map-get? user-licenses { user: user, content-id: validated-id })
  )
)

;; Get creator statistics
(define-read-only (get-creator-stats (creator principal))
  (default-to 
    { total-content: u0, total-earnings: u0, active-content: u0 }
    (map-get? creator-stats { creator: creator })
  )
)

;; Get platform fee
(define-read-only (get-platform-fee)
  (var-get platform-fee)
)

;; Get next content ID
(define-read-only (get-next-content-id)
  (var-get next-content-id)
)

;; Private Functions

;; Update creator statistics
(define-private (update-creator-stats (creator principal) 
                                     (content-delta uint) 
                                     (earnings-delta uint) 
                                     (active-delta uint))
  (let ((current-stats (default-to 
                         { total-content: u0, total-earnings: u0, active-content: u0 }
                         (map-get? creator-stats { creator: creator }))))
    (map-set creator-stats
      { creator: creator }
      {
        total-content: (+ (get total-content current-stats) content-delta),
        total-earnings: (+ (get total-earnings current-stats) earnings-delta),
        active-content: (+ (get active-content current-stats) active-delta)
      }
    )
  )
)