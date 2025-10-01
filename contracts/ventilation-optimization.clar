;; Ventilation Optimization Smart Contract
;; Provides HVAC runtime recommendations and maintenance scheduling

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_SYSTEM_NOT_FOUND (err u201))
(define-constant ERR_INVALID_CONFIG (err u202))
(define-constant ERR_MAINTENANCE_OVERDUE (err u203))
(define-constant ERR_INSUFFICIENT_DATA (err u204))
(define-constant MAINTENANCE_INTERVAL_BLOCKS u28800) ;; ~6 days
(define-constant FILTER_REPLACEMENT_BLOCKS u144000) ;; ~30 days
(define-constant CO2_THRESHOLD u1000) ;; 1000 ppm threshold
(define-constant PM25_THRESHOLD u35) ;; 35 ug/m3 threshold
(define-constant MIN_RUNTIME_MINUTES u10)
(define-constant MAX_RUNTIME_MINUTES u480) ;; 8 hours

;; Data Variables
(define-data-var next-system-id uint u1)
(define-data-var total-systems uint u0)
(define-data-var total-recommendations uint u0)

;; Data Maps
(define-map hvac-systems
  { system-id: uint }
  {
    owner: principal,
    location-hash: (buff 32),
    system-type: (string-ascii 30),
    capacity-cfm: uint,
    installation-block: uint,
    last-maintenance: uint,
    filter-install-date: uint,
    active: bool,
    efficiency-rating: uint
  }
)

(define-map optimization-recommendations
  { system-id: uint, recommendation-id: uint }
  {
    timestamp: uint,
    recommended-runtime: uint,
    target-co2: uint,
    target-pm25: uint,
    energy-efficiency-score: uint,
    priority-level: uint,
    implementation-status: (string-ascii 20),
    estimated-savings: uint
  }
)

(define-map maintenance-schedules
  { system-id: uint }
  {
    next-inspection: uint,
    next-filter-change: uint,
    maintenance-type: (string-ascii 30),
    estimated-cost: uint,
    technician-principal: (optional principal),
    completion-deadline: uint
  }
)

(define-map system-performance
  { system-id: uint }
  {
    average-runtime: uint,
    energy-consumption: uint,
    air-quality-improvement: uint,
    maintenance-score: uint,
    efficiency-trend: int,
    last-updated: uint
  }
)

(define-map runtime-logs
  { system-id: uint, log-id: uint }
  {
    start-time: uint,
    end-time: uint,
    runtime-minutes: uint,
    co2-before: uint,
    co2-after: uint,
    pm25-before: uint,
    pm25-after: uint,
    energy-used: uint
  }
)

;; Private Functions
(define-private (is-system-owner (system-id uint) (sender principal))
  (match (map-get? hvac-systems { system-id: system-id })
    system-data
    (is-eq (get owner system-data) sender)
    false
  )
)

(define-private (calculate-optimal-runtime (co2-level uint) (pm25-level uint))
  (let ((co2-factor (if (> co2-level CO2_THRESHOLD) u2 u1))
        (pm25-factor (if (> pm25-level PM25_THRESHOLD) u2 u1))
        (base-runtime u30))
    (if (< (* base-runtime (* co2-factor pm25-factor)) MIN_RUNTIME_MINUTES) 
        MIN_RUNTIME_MINUTES 
        (if (> (* base-runtime (* co2-factor pm25-factor)) MAX_RUNTIME_MINUTES)
            MAX_RUNTIME_MINUTES
            (* base-runtime (* co2-factor pm25-factor))))
  )
)

(define-private (calculate-efficiency-score (runtime uint) (co2-improvement uint) (energy-used uint))
  (if (and (> runtime u0) (> energy-used u0))
    (/ (* co2-improvement u100) (* runtime (/ energy-used u10)))
    u0
  )
)

(define-private (get-priority-level (co2-level uint) (pm25-level uint))
  (cond
    ((and (> co2-level (* CO2_THRESHOLD u2)) (> pm25-level (* PM25_THRESHOLD u2))) u5) ;; Critical
    ((or (> co2-level (* CO2_THRESHOLD u15 u10)) (> pm25-level (* PM25_THRESHOLD u15 u10))) u4) ;; High
    ((or (> co2-level CO2_THRESHOLD) (> pm25-level PM25_THRESHOLD)) u3) ;; Medium
    ((or (> co2-level (* CO2_THRESHOLD u8 u10)) (> pm25-level (* PM25_THRESHOLD u8 u10))) u2) ;; Low
    u1 ;; Normal
  )
)

(define-private (needs-maintenance (system-id uint))
  (match (map-get? hvac-systems { system-id: system-id })
    system-data
    (> (- stacks-block-height (get last-maintenance system-data)) MAINTENANCE_INTERVAL_BLOCKS)
    true
  )
)

(define-private (needs-filter-replacement (system-id uint))
  (match (map-get? hvac-systems { system-id: system-id })
    system-data
    (> (- stacks-block-height (get filter-install-date system-data)) FILTER_REPLACEMENT_BLOCKS)
    true
  )
)

;; Public Functions

;; Register HVAC system
(define-public (register-hvac-system 
  (location-hash (buff 32))
  (system-type (string-ascii 30))
  (capacity-cfm uint)
  (efficiency-rating uint)
)
  (let ((system-id (var-get next-system-id)))
    (asserts! (<= efficiency-rating u100) ERR_INVALID_CONFIG)
    (asserts! (> capacity-cfm u0) ERR_INVALID_CONFIG)
    
    (map-set hvac-systems
      { system-id: system-id }
      {
        owner: tx-sender,
        location-hash: location-hash,
        system-type: system-type,
        capacity-cfm: capacity-cfm,
        installation-block: stacks-block-height,
        last-maintenance: stacks-block-height,
        filter-install-date: stacks-block-height,
        active: true,
        efficiency-rating: efficiency-rating
      }
    )
    
    (var-set next-system-id (+ system-id u1))
    (var-set total-systems (+ (var-get total-systems) u1))
    (ok system-id)
  )
)

;; Generate optimization recommendation
(define-public (generate-recommendation
  (system-id uint)
  (current-co2 uint)
  (current-pm25 uint)
  (target-co2 uint)
  (target-pm25 uint)
)
  (let ((system-data (unwrap! (map-get? hvac-systems { system-id: system-id }) ERR_SYSTEM_NOT_FOUND))
        (performance-data (map-get? system-performance { system-id: system-id }))
        (recommendation-id (+ (var-get total-recommendations) u1))
        (optimal-runtime (calculate-optimal-runtime current-co2 current-pm25))
        (priority (get-priority-level current-co2 current-pm25))
        (efficiency-score (match performance-data 
          perf (get efficiency-trend perf) 
          (to-int (get efficiency-rating system-data))))
        (estimated-savings (/ (* optimal-runtime u5) u100)))
    
    (asserts! (is-system-owner system-id tx-sender) ERR_UNAUTHORIZED)
    (asserts! (get active system-data) ERR_SYSTEM_NOT_FOUND)
    
    (map-set optimization-recommendations
      { system-id: system-id, recommendation-id: recommendation-id }
      {
        timestamp: stacks-block-height,
        recommended-runtime: optimal-runtime,
        target-co2: target-co2,
        target-pm25: target-pm25,
        energy-efficiency-score: (if (> efficiency-score 0) (to-uint efficiency-score) u0),
        priority-level: priority,
        implementation-status: "pending",
        estimated-savings: estimated-savings
      }
    )
    
    (var-set total-recommendations recommendation-id)
    (ok recommendation-id)
  )
)

;; Log runtime data
(define-public (log-runtime
  (system-id uint)
  (log-id uint)
  (start-time uint)
  (end-time uint)
  (co2-before uint)
  (co2-after uint)
  (pm25-before uint)
  (pm25-after uint)
  (energy-used uint)
)
  (let ((system-data (unwrap! (map-get? hvac-systems { system-id: system-id }) ERR_SYSTEM_NOT_FOUND))
        (runtime-minutes (if (> end-time start-time) (- end-time start-time) u0)))
    
    (asserts! (is-system-owner system-id tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> runtime-minutes u0) ERR_INVALID_CONFIG)
    
    (map-set runtime-logs
      { system-id: system-id, log-id: log-id }
      {
        start-time: start-time,
        end-time: end-time,
        runtime-minutes: runtime-minutes,
        co2-before: co2-before,
        co2-after: co2-after,
        pm25-before: pm25-before,
        pm25-after: pm25-after,
        energy-used: energy-used
      }
    )
    
    ;; Update performance metrics
    (update-performance-metrics system-id runtime-minutes co2-before co2-after energy-used)
    
    (ok true)
  )
)

;; Schedule maintenance
(define-public (schedule-maintenance
  (system-id uint)
  (maintenance-type (string-ascii 30))
  (estimated-cost uint)
  (technician (optional principal))
)
  (let ((system-data (unwrap! (map-get? hvac-systems { system-id: system-id }) ERR_SYSTEM_NOT_FOUND)))
    (asserts! (is-system-owner system-id tx-sender) ERR_UNAUTHORIZED)
    
    (map-set maintenance-schedules
      { system-id: system-id }
      {
        next-inspection: (+ stacks-block-height MAINTENANCE_INTERVAL_BLOCKS),
        next-filter-change: (+ stacks-block-height FILTER_REPLACEMENT_BLOCKS),
        maintenance-type: maintenance-type,
        estimated-cost: estimated-cost,
        technician-principal: technician,
        completion-deadline: (+ stacks-block-height u14400) ;; ~3 days
      }
    )
    
    (ok true)
  )
)

;; Update maintenance completion
(define-public (complete-maintenance (system-id uint) (maintenance-type (string-ascii 30)))
  (let ((system-data (unwrap! (map-get? hvac-systems { system-id: system-id }) ERR_SYSTEM_NOT_FOUND)))
    (asserts! (is-system-owner system-id tx-sender) ERR_UNAUTHORIZED)
    
    (map-set hvac-systems
      { system-id: system-id }
      (merge system-data 
        { 
          last-maintenance: stacks-block-height,
          filter-install-date: (if (is-eq maintenance-type "filter-replacement")
                                stacks-block-height
                                (get filter-install-date system-data))
        })
    )
    
    (ok true)
  )
)

;; Private function to update performance metrics
(define-private (update-performance-metrics 
  (system-id uint)
  (runtime uint)
  (co2-before uint)
  (co2-after uint)
  (energy-used uint)
)
  (let ((current-perf (map-get? system-performance { system-id: system-id }))
        (co2-improvement (if (> co2-before co2-after) (- co2-before co2-after) u0))
        (efficiency (calculate-efficiency-score runtime co2-improvement energy-used)))
    
    (map-set system-performance
      { system-id: system-id }
      {
        average-runtime: (match current-perf 
          perf (/ (+ (get average-runtime perf) runtime) u2)
          runtime),
        energy-consumption: (match current-perf
          perf (+ (get energy-consumption perf) energy-used)
          energy-used),
        air-quality-improvement: co2-improvement,
        maintenance-score: (if (needs-maintenance system-id) u0 u100),
        efficiency-trend: (to-int efficiency),
        last-updated: stacks-block-height
      }
    )
  )
)

;; Read-only Functions

;; Get system information
(define-read-only (get-system (system-id uint))
  (map-get? hvac-systems { system-id: system-id })
)

;; Get recommendation
(define-read-only (get-recommendation (system-id uint) (recommendation-id uint))
  (map-get? optimization-recommendations { system-id: system-id, recommendation-id: recommendation-id })
)

;; Get maintenance schedule
(define-read-only (get-maintenance-schedule (system-id uint))
  (map-get? maintenance-schedules { system-id: system-id })
)

;; Get system performance
(define-read-only (get-performance (system-id uint))
  (map-get? system-performance { system-id: system-id })
)

;; Get runtime log
(define-read-only (get-runtime-log (system-id uint) (log-id uint))
  (map-get? runtime-logs { system-id: system-id, log-id: log-id })
)

;; Check maintenance status
(define-read-only (check-maintenance-status (system-id uint))
  {
    needs-maintenance: (needs-maintenance system-id),
    needs-filter-replacement: (needs-filter-replacement system-id),
    blocks-until-maintenance: (match (map-get? hvac-systems { system-id: system-id })
      system-data
        (let ((blocks-since-maintenance (- stacks-block-height (get last-maintenance system-data))))
        (if (< blocks-since-maintenance MAINTENANCE_INTERVAL_BLOCKS)
          (some (- MAINTENANCE_INTERVAL_BLOCKS blocks-since-maintenance))
          (some u0)
        )
      )
      none
    )
  }
)

;; Get optimization statistics
(define-read-only (get-optimization-stats)
  {
    total-systems: (var-get total-systems),
    total-recommendations: (var-get total-recommendations),
    next-system-id: (var-get next-system-id)
  }
)

;; title: ventilation-optimization
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

