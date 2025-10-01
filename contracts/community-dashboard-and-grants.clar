;; Community Dashboard and Grants Smart Contract
;; Manages public data access and micro-grant distribution for air quality improvements

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_GRANT_NOT_FOUND (err u401))
(define-constant ERR_INSUFFICIENT_FUNDS (err u402))
(define-constant ERR_INVALID_AMOUNT (err u403))
(define-constant ERR_GRANT_ALREADY_FUNDED (err u404))
(define-constant ERR_GRANT_EXPIRED (err u405))
(define-constant ERR_INVALID_PROPOSAL (err u406))
(define-constant MIN_GRANT_AMOUNT u100000) ;; Minimum 0.1 STX
(define-constant MAX_GRANT_AMOUNT u10000000) ;; Maximum 10 STX
(define-constant GRANT_DURATION_BLOCKS u43200) ;; ~30 days
(define-constant VOTING_PERIOD_BLOCKS u14400) ;; ~10 days
(define-constant MIN_VOTERS u3)

;; Data Variables
(define-data-var next-grant-id uint u1)
(define-data-var total-grants uint u0)
(define-data-var total-funded-amount uint u0)
(define-data-var community-fund uint u0)

;; Data Maps
(define-map grant-proposals
  { grant-id: uint }
  {
    proposer: principal,
    location-hash: (buff 32),
    title: (string-ascii 100),
    description: (string-ascii 500),
    requested-amount: uint,
    category: (string-ascii 50),
    proposal-timestamp: uint,
    deadline: uint,
    status: (string-ascii 20),
    votes-for: uint,
    votes-against: uint,
    total-voters: uint,
    funded-amount: uint,
    completion-proof: (optional (string-ascii 200))
  }
)

(define-map grant-votes
  { grant-id: uint, voter: principal }
  {
    vote: bool, ;; true for yes, false for no
    voting-power: uint,
    timestamp: uint,
    rationale: (optional (string-ascii 200))
  }
)

(define-map dashboard-permissions
  { location-hash: (buff 32) }
  {
    public-access: bool,
    authorized-viewers: (list 50 principal),
    data-retention-blocks: uint,
    privacy-level: uint,
    administrator: principal
  }
)

(define-map community-metrics
  { location-hash: (buff 32) }
  {
    total-grants-received: uint,
    total-funding-amount: uint,
    active-grants: uint,
    completed-projects: uint,
    average-air-quality-score: uint,
    community-engagement-score: uint,
    last-updated: uint
  }
)

(define-map public-data-feeds
  { location-hash: (buff 32), feed-type: (string-ascii 30) }
  {
    data-points: (list 100 uint),
    timestamps: (list 100 uint),
    aggregation-method: (string-ascii 20),
    update-frequency: uint,
    last-update: uint,
    data-quality-score: uint
  }
)

(define-map grant-categories
  { category: (string-ascii 50) }
  {
    total-proposals: uint,
    funded-proposals: uint,
    total-funding: uint,
    success-rate: uint,
    average-amount: uint
  }
)

(define-map community-contributors
  { contributor: principal }
  {
    total-contributions: uint,
    grants-supported: uint,
    reputation-score: uint,
    active-since: uint,
    contribution-categories: (list 10 (string-ascii 50))
  }
)

;; Private Functions
(define-private (is-grant-active (grant-id uint))
  (match (map-get? grant-proposals { grant-id: grant-id })
    grant-data
    (and (is-eq (get status grant-data) "active")
    (< stacks-block-height (get deadline grant-data))
    false
  )
)

(define-private (calculate-voting-power (voter principal))
  (match (map-get? community-contributors { contributor: voter })
    contributor-data
    (+ u1 (/ (get reputation-score contributor-data) u10))
    u1
  )
)

(define-private (is-authorized-viewer (location-hash (buff 32)) (viewer principal))
  (match (map-get? dashboard-permissions { location-hash: location-hash })
    permissions
    (or (get public-access permissions)
        (is-some (index-of (get authorized-viewers permissions) viewer))
        (is-eq (get administrator permissions) viewer))
    false
  )
)

(define-private (update-community-metrics (location-hash (buff 32)) (grant-amount uint) (completed bool))
  (let ((current-metrics (map-get? community-metrics { location-hash: location-hash })))
    (match current-metrics
      metrics
      (map-set community-metrics
        { location-hash: location-hash }
        {
          total-grants-received: (+ (get total-grants-received metrics) u1),
          total-funding-amount: (+ (get total-funding-amount metrics) grant-amount),
          active-grants: (if completed
                           (- (get active-grants metrics) u1)
                           (+ (get active-grants metrics) u1)),
          completed-projects: (if completed
                               (+ (get completed-projects metrics) u1)
                               (get completed-projects metrics)),
          average-air-quality-score: (get average-air-quality-score metrics),
          community-engagement-score: (if (> (+ (get community-engagement-score metrics) u5) u100) u100 (+ (get community-engagement-score metrics) u5)),
          last-updated: stacks-block-height
        }
      )
      (map-set community-metrics
        { location-hash: location-hash }
        {
          total-grants-received: u1,
          total-funding-amount: grant-amount,
          active-grants: (if completed u0 u1),
          completed-projects: (if completed u1 u0),
          average-air-quality-score: u50,
          community-engagement-score: u10,
          last-updated: stacks-block-height
        }
      )
    )
  )
)

(define-private (update-category-stats (category (string-ascii 50)) (amount uint) (funded bool))
  (let ((current-stats (map-get? grant-categories { category: category })))
    (match current-stats
      stats
      (let ((new-total-proposals (+ (get total-proposals stats) u1))
            (new-funded (if funded (+ (get funded-proposals stats) u1) (get funded-proposals stats)))
            (new-total-funding (if funded (+ (get total-funding stats) amount) (get total-funding stats))))
        (map-set grant-categories
          { category: category }
          {
            total-proposals: new-total-proposals,
            funded-proposals: new-funded,
            total-funding: new-total-funding,
            success-rate: (if (> new-total-proposals u0) (/ (* new-funded u100) new-total-proposals) u0),
            average-amount: (if (> new-funded u0) (/ new-total-funding new-funded) u0)
          }
        )
      )
      (map-set grant-categories
        { category: category }
        {
          total-proposals: u1,
          funded-proposals: (if funded u1 u0),
          total-funding: (if funded amount u0),
          success-rate: (if funded u100 u0),
          average-amount: (if funded amount u0)
        }
      )
    )
  )
)

;; Public Functions

;; Submit grant proposal
(define-public (submit-grant-proposal
  (location-hash (buff 32))
  (title (string-ascii 100))
  (description (string-ascii 500))
  (requested-amount uint)
  (category (string-ascii 50))
)
  (let ((grant-id (var-get next-grant-id)))
    (asserts! (and (>= requested-amount MIN_GRANT_AMOUNT) (<= requested-amount MAX_GRANT_AMOUNT)) ERR_INVALID_AMOUNT)
    (asserts! (> (len title) u0) ERR_INVALID_PROPOSAL)
    (asserts! (> (len description) u10) ERR_INVALID_PROPOSAL)
    
    (map-set grant-proposals
      { grant-id: grant-id }
      {
        proposer: tx-sender,
        location-hash: location-hash,
        title: title,
        description: description,
        requested-amount: requested-amount,
        category: category,
        proposal-timestamp: stacks-block-height,
        deadline: (+ stacks-block-height GRANT_DURATION_BLOCKS),
        status: "active",
        votes-for: u0,
        votes-against: u0,
        total-voters: u0,
        funded-amount: u0,
        completion-proof: none
      }
    )
    
    (update-category-stats category requested-amount false)
    (var-set next-grant-id (+ grant-id u1))
    (var-set total-grants (+ (var-get total-grants) u1))
    (ok grant-id)
  )
)

;; Vote on grant proposal
(define-public (vote-on-grant (grant-id uint) (support bool) (rationale (optional (string-ascii 200))))
  (let ((grant-data (unwrap! (map-get? grant-proposals { grant-id: grant-id }) ERR_GRANT_NOT_FOUND))
        (voting-power (calculate-voting-power tx-sender)))
    
    (asserts! (is-grant-active grant-id) ERR_GRANT_EXPIRED)
    (asserts! (is-none (map-get? grant-votes { grant-id: grant-id, voter: tx-sender })) ERR_UNAUTHORIZED)
    
    (map-set grant-votes
      { grant-id: grant-id, voter: tx-sender }
      {
        vote: support,
        voting-power: voting-power,
        timestamp: stacks-block-height,
        rationale: rationale
      }
    )
    
    (map-set grant-proposals
      { grant-id: grant-id }
      (merge grant-data
        {
          votes-for: (if support (+ (get votes-for grant-data) voting-power) (get votes-for grant-data)),
          votes-against: (if support (get votes-against grant-data) (+ (get votes-against grant-data) voting-power)),
          total-voters: (+ (get total-voters grant-data) u1)
        }
      )
    )
    
    ;; Update contributor reputation
    (update-contributor-reputation tx-sender)
    
    (ok true)
  )
)

;; Fund approved grant
(define-public (fund-grant (grant-id uint))
  (let ((grant-data (unwrap! (map-get? grant-proposals { grant-id: grant-id }) ERR_GRANT_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status grant-data) "active") ERR_GRANT_ALREADY_FUNDED)
    (asserts! (>= (get total-voters grant-data) MIN_VOTERS) ERR_UNAUTHORIZED)
    (asserts! (> (get votes-for grant-data) (get votes-against grant-data)) ERR_UNAUTHORIZED)
    
    (let ((funding-amount (get requested-amount grant-data)))
      (asserts! (>= (stx-get-balance (as-contract tx-sender)) funding-amount) ERR_INSUFFICIENT_FUNDS)
      
      (try! (as-contract (stx-transfer? funding-amount tx-sender (get proposer grant-data))))
      
      (map-set grant-proposals
        { grant-id: grant-id }
        (merge grant-data
          {
            status: "funded",
            funded-amount: funding-amount
          }
        )
      )
      
      (update-community-metrics (get location-hash grant-data) funding-amount false)
      (update-category-stats (get category grant-data) funding-amount true)
      (var-set total-funded-amount (+ (var-get total-funded-amount) funding-amount))
      
      (ok funding-amount)
    )
  )
)

;; Submit completion proof
(define-public (submit-completion-proof (grant-id uint) (proof (string-ascii 200)))
  (let ((grant-data (unwrap! (map-get? grant-proposals { grant-id: grant-id }) ERR_GRANT_NOT_FOUND)))
    (asserts! (is-eq (get proposer grant-data) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status grant-data) "funded") ERR_UNAUTHORIZED)
    
    (map-set grant-proposals
      { grant-id: grant-id }
      (merge grant-data
        {
          status: "completed",
          completion-proof: (some proof)
        }
      )
    )
    
    (update-community-metrics (get location-hash grant-data) u0 true)
    (ok true)
  )
)

;; Configure dashboard permissions
(define-public (configure-dashboard
  (location-hash (buff 32))
  (public-access bool)
  (authorized-viewers (list 50 principal))
  (data-retention-blocks uint)
  (privacy-level uint)
)
  (begin
    (asserts! (<= privacy-level u5) ERR_INVALID_PROPOSAL)
    
    (map-set dashboard-permissions
      { location-hash: location-hash }
      {
        public-access: public-access,
        authorized-viewers: authorized-viewers,
        data-retention-blocks: data-retention-blocks,
        privacy-level: privacy-level,
        administrator: tx-sender
      }
    )
    
    (ok true)
  )
)

;; Update public data feed
(define-public (update-data-feed
  (location-hash (buff 32))
  (feed-type (string-ascii 30))
  (new-data-point uint)
  (aggregation-method (string-ascii 20))
  (data-quality-score uint)
)
  (let ((current-feed (map-get? public-data-feeds { location-hash: location-hash, feed-type: feed-type })))
    (asserts! (is-authorized-viewer location-hash tx-sender) ERR_UNAUTHORIZED)
    (asserts! (<= data-quality-score u100) ERR_INVALID_AMOUNT)
    
    (match current-feed
      feed
      (let ((current-data (get data-points feed))
            (current-timestamps (get timestamps feed)))
        (map-set public-data-feeds
          { location-hash: location-hash, feed-type: feed-type }
          {
            data-points: (unwrap! (as-max-len? (append current-data new-data-point) u100) ERR_INVALID_AMOUNT),
            timestamps: (unwrap! (as-max-len? (append current-timestamps block-height) u100) ERR_INVALID_AMOUNT),
            aggregation-method: aggregation-method,
            update-frequency: (- block-height (get last-update feed)),
            last-update: block-height,
            data-quality-score: data-quality-score
          }
        )
      )
      (map-set public-data-feeds
        { location-hash: location-hash, feed-type: feed-type }
        {
          data-points: (list new-data-point),
          timestamps: (list block-height),
          aggregation-method: aggregation-method,
          update-frequency: u0,
          last-update: block-height,
          data-quality-score: data-quality-score
        }
      )
    )
    
    (ok true)
  )
)

;; Contribute to community fund
(define-public (contribute-to-fund (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set community-fund (+ (var-get community-fund) amount))
    (update-contributor-reputation tx-sender)
    (ok amount)
  )
)

;; Private function to update contributor reputation
(define-private (update-contributor-reputation (contributor principal))
  (let ((current-data (map-get? community-contributors { contributor: contributor })))
    (match current-data
      data
      (map-set community-contributors
        { contributor: contributor }
        (merge data
          {
            total-contributions: (+ (get total-contributions data) u1),
            reputation-score: (min (+ (get reputation-score data) u1) u100)
          }
        )
      )
      (map-set community-contributors
        { contributor: contributor }
        {
          total-contributions: u1,
          grants-supported: u0,
          reputation-score: u1,
          active-since: block-height,
          contribution-categories: (list)
        }
      )
    )
  )
)

;; Read-only Functions

;; Get grant proposal details
(define-read-only (get-grant-proposal (grant-id uint))
  (map-get? grant-proposals { grant-id: grant-id })
)

;; Get voting information
(define-read-only (get-vote (grant-id uint) (voter principal))
  (map-get? grant-votes { grant-id: grant-id, voter: voter })
)

;; Get dashboard permissions
(define-read-only (get-dashboard-permissions (location-hash (buff 32)))
  (map-get? dashboard-permissions { location-hash: location-hash })
)

;; Get community metrics
(define-read-only (get-community-metrics (location-hash (buff 32)))
  (map-get? community-metrics { location-hash: location-hash })
)

;; Get public data feed
(define-read-only (get-data-feed (location-hash (buff 32)) (feed-type (string-ascii 30)))
  (if (is-authorized-viewer location-hash tx-sender)
    (map-get? public-data-feeds { location-hash: location-hash, feed-type: feed-type })
    none
  )
)

;; Get category statistics
(define-read-only (get-category-stats (category (string-ascii 50)))
  (map-get? grant-categories { category: category })
)

;; Get contributor information
(define-read-only (get-contributor-info (contributor principal))
  (map-get? community-contributors { contributor: contributor })
)

;; Get grant system statistics
(define-read-only (get-grant-stats)
  {
    total-grants: (var-get total-grants),
    total-funded-amount: (var-get total-funded-amount),
    community-fund: (var-get community-fund),
    next-grant-id: (var-get next-grant-id)
  }
)

;; title: community-dashboard-and-grants
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

