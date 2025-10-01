;; Exposure Notifications Smart Contract
;; Monitors air quality thresholds and manages notification system

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_THRESHOLD_NOT_FOUND (err u301))
(define-constant ERR_INVALID_THRESHOLD (err u302))
(define-constant ERR_NOTIFICATION_NOT_FOUND (err u303))
(define-constant ERR_SUBSCRIBER_NOT_FOUND (err u304))
(define-constant ERR_ALREADY_SUBSCRIBED (err u305))
(define-constant MAX_SUBSCRIBERS u100)
(define-constant NOTIFICATION_COOLDOWN_BLOCKS u720) ;; ~2.5 hours
(define-constant CRITICAL_CO2_THRESHOLD u2000) ;; 2000 ppm
(define-constant CRITICAL_PM25_THRESHOLD u75)  ;; 75 ug/m3
(define-constant HIGH_CO2_THRESHOLD u1200)     ;; 1200 ppm
(define-constant HIGH_PM25_THRESHOLD u50)      ;; 50 ug/m3

;; Data Variables
(define-data-var next-notification-id uint u1)
(define-data-var total-notifications uint u0)
(define-data-var active-subscribers uint u0)

;; Data Maps
(define-map exposure-thresholds
  { location-hash: (buff 32) }
  {
    co2-warning: uint,
    co2-critical: uint,
    pm25-warning: uint,
    pm25-critical: uint,
    voc-warning: uint,
    voc-critical: uint,
    humidity-min: uint,
    humidity-max: uint,
    temperature-min: uint,
    temperature-max: uint,
    administrator: principal
  }
)

(define-map notifications
  { notification-id: uint }
  {
    location-hash: (buff 32),
    severity: (string-ascii 20),
    alert-type: (string-ascii 30),
    message: (string-ascii 200),
    timestamp: uint,
    co2-level: uint,
    pm25-level: uint,
    voc-level: uint,
    affected-areas: (list 10 (string-ascii 50)),
    recommended-actions: (list 5 (string-ascii 100)),
    acknowledged: bool,
    resolver: (optional principal)
  }
)

(define-map subscribers
  { subscriber: principal, location-hash: (buff 32) }
  {
    subscription-type: (string-ascii 20),
    notification-methods: (list 5 (string-ascii 20)),
    severity-filter: uint,
    active: bool,
    last-notification: uint,
    total-notifications-received: uint
  }
)

(define-map location-subscribers
  { location-hash: (buff 32) }
  {
    subscriber-list: (list 100 principal),
    total-subscribers: uint
  }
)

(define-map exposure-history
  { location-hash: (buff 32), date-block: uint }
  {
    max-co2: uint,
    max-pm25: uint,
    max-voc: uint,
    duration-above-threshold: uint,
    total-notifications: uint,
    severity-breakdown: { critical: uint, high: uint, medium: uint, low: uint }
  }
)

(define-map notification-acknowledgments
  { notification-id: uint }
  {
    acknowledged-by: (list 20 principal),
    acknowledgment-time: uint,
    resolution-notes: (optional (string-ascii 500))
  }
)

;; Private Functions
(define-private (is-location-admin (location-hash (buff 32)) (sender principal))
  (match (map-get? exposure-thresholds { location-hash: location-hash })
    threshold-data
    (is-eq (get administrator threshold-data) sender)
    false
  )
)

(define-private (get-severity-level (co2 uint) (pm25 uint) (voc uint))
  (if (or (>= co2 CRITICAL_CO2_THRESHOLD) (>= pm25 CRITICAL_PM25_THRESHOLD) (>= voc u5000))
    u5 ;; Critical
    (if (or (>= co2 HIGH_CO2_THRESHOLD) (>= pm25 HIGH_PM25_THRESHOLD) (>= voc u3000))
      u4 ;; High
      (if (or (>= co2 u1000) (>= pm25 u35) (>= voc u1000))
        u3 ;; Medium
        (if (or (>= co2 u800) (>= pm25 u25) (>= voc u500))
          u2 ;; Low
          u1 ;; Normal
        )
      )
    )
  )
)

(define-private (generate-alert-message (severity uint) (co2 uint) (pm25 uint) (voc uint))
  (if (is-eq severity u5)
    "CRITICAL: Air quality severely compromised. Immediate evacuation recommended."
    (if (is-eq severity u4)
      "HIGH ALERT: Poor air quality detected. Increase ventilation immediately."
      (if (is-eq severity u3)
        "MEDIUM ALERT: Air quality below standards. Monitor and improve ventilation."
        "LOW ALERT: Air quality approaching threshold levels. Consider ventilation adjustment."
      )
    )
  )
)

(define-private (get-recommended-actions (severity uint))
  (if (is-eq severity u5)
    (list "Evacuate affected areas" "Contact emergency services" "Shut down HVAC if malfunctioning" "Open all windows and doors" "Do not re-enter until cleared")
    (if (is-eq severity u4)
      (list "Increase HVAC runtime" "Open windows for natural ventilation" "Reduce occupancy" "Check air filtration systems" "Monitor continuously")
      (if (is-eq severity u3)
        (list "Adjust HVAC settings" "Check for sources of pollution" "Increase air circulation" "Schedule maintenance review")
        (list "Monitor air quality trends" "Prepare for potential action")
      )
    )
  )
)

(define-private (should-send-notification (location-hash (buff 32)) (severity uint))
  (let ((last-notification-block (default-to u0 
                                   (get last-notification 
                                        (map-get? location-subscribers { location-hash: location-hash })))))
    (or (>= severity u4) ;; Always send high/critical alerts
        (> (- stacks-block-height last-notification-block) NOTIFICATION_COOLDOWN_BLOCKS))
  )
)

;; Public Functions

;; Set exposure thresholds for a location
(define-public (set-exposure-thresholds
  (location-hash (buff 32))
  (co2-warning uint)
  (co2-critical uint)
  (pm25-warning uint)
  (pm25-critical uint)
  (voc-warning uint)
  (voc-critical uint)
  (humidity-min uint)
  (humidity-max uint)
  (temperature-min uint)
  (temperature-max uint)
)
  (begin
    (asserts! (< co2-warning co2-critical) ERR_INVALID_THRESHOLD)
    (asserts! (< pm25-warning pm25-critical) ERR_INVALID_THRESHOLD)
    (asserts! (< voc-warning voc-critical) ERR_INVALID_THRESHOLD)
    (asserts! (< humidity-min humidity-max) ERR_INVALID_THRESHOLD)
    (asserts! (< temperature-min temperature-max) ERR_INVALID_THRESHOLD)
    
    (map-set exposure-thresholds
      { location-hash: location-hash }
      {
        co2-warning: co2-warning,
        co2-critical: co2-critical,
        pm25-warning: pm25-warning,
        pm25-critical: pm25-critical,
        voc-warning: voc-warning,
        voc-critical: voc-critical,
        humidity-min: humidity-min,
        humidity-max: humidity-max,
        temperature-min: temperature-min,
        temperature-max: temperature-max,
        administrator: tx-sender
      }
    )
    
    (ok true)
  )
)

;; Subscribe to notifications
(define-public (subscribe-to-notifications
  (location-hash (buff 32))
  (subscription-type (string-ascii 20))
  (notification-methods (list 5 (string-ascii 20)))
  (severity-filter uint)
)
  (let ((current-subscribers (map-get? location-subscribers { location-hash: location-hash })))
    (asserts! (is-none (map-get? subscribers { subscriber: tx-sender, location-hash: location-hash })) ERR_ALREADY_SUBSCRIBED)
    (asserts! (<= severity-filter u5) ERR_INVALID_THRESHOLD)
    
    (map-set subscribers
      { subscriber: tx-sender, location-hash: location-hash }
      {
        subscription-type: subscription-type,
        notification-methods: notification-methods,
        severity-filter: severity-filter,
        active: true,
        last-notification: u0,
        total-notifications-received: u0
      }
    )
    
    ;; Update location subscribers
    (let ((subscriber-list (default-to (list) (get subscriber-list current-subscribers)))
          (total-count (default-to u0 (get total-subscribers current-subscribers))))
      (map-set location-subscribers
        { location-hash: location-hash }
        {
          subscriber-list: (unwrap! (as-max-len? (append subscriber-list tx-sender) u100) ERR_INVALID_THRESHOLD),
          total-subscribers: (+ total-count u1)
        }
      )
    )
    
    (var-set active-subscribers (+ (var-get active-subscribers) u1))
    (ok true)
  )
)

;; Create exposure notification
(define-public (create-exposure-notification
  (location-hash (buff 32))
  (co2-level uint)
  (pm25-level uint)
  (voc-level uint)
  (affected-areas (list 10 (string-ascii 50)))
)
  (let ((notification-id (var-get next-notification-id))
        (severity-level (get-severity-level co2-level pm25-level voc-level))
        (alert-message (generate-alert-message severity-level co2-level pm25-level voc-level))
        (actions (get-recommended-actions severity-level)))
    
    (asserts! (should-send-notification location-hash severity-level) ERR_UNAUTHORIZED)
    
    (map-set notifications
      { notification-id: notification-id }
      {
        location-hash: location-hash,
        severity: (if (is-eq severity-level u5) "critical"
                   (if (is-eq severity-level u4) "high"
                    (if (is-eq severity-level u3) "medium" "low"))),
        alert-type: "exposure-threshold-exceeded",
        message: alert-message,
        timestamp: stacks-block-height,
        co2-level: co2-level,
        pm25-level: pm25-level,
        voc-level: voc-level,
        affected-areas: affected-areas,
        recommended-actions: actions,
        acknowledged: false,
        resolver: none
      }
    )
    
    ;; Update exposure history
    (update-exposure-history location-hash co2-level pm25-level voc-level severity-level)
    
    (var-set next-notification-id (+ notification-id u1))
    (var-set total-notifications (+ (var-get total-notifications) u1))
    (ok notification-id)
  )
)

;; Acknowledge notification
(define-public (acknowledge-notification
  (notification-id uint)
  (resolution-notes (optional (string-ascii 500)))
)
  (let ((notification-data (unwrap! (map-get? notifications { notification-id: notification-id }) ERR_NOTIFICATION_NOT_FOUND)))
    (map-set notifications
      { notification-id: notification-id }
      (merge notification-data 
        {
          acknowledged: true,
          resolver: (some tx-sender)
        })
    )
    
    (map-set notification-acknowledgments
      { notification-id: notification-id }
      {
        acknowledged-by: (list tx-sender),
        acknowledgment-time: stacks-block-height,
        resolution-notes: resolution-notes
      }
    )
    
    (ok true)
  )
)

;; Unsubscribe from notifications
(define-public (unsubscribe-from-notifications (location-hash (buff 32)))
  (let ((subscription (unwrap! (map-get? subscribers { subscriber: tx-sender, location-hash: location-hash }) ERR_SUBSCRIBER_NOT_FOUND)))
    (map-set subscribers
      { subscriber: tx-sender, location-hash: location-hash }
      (merge subscription { active: false })
    )
    
    (var-set active-subscribers (- (var-get active-subscribers) u1))
    (ok true)
  )
)

;; Private function to update exposure history
(define-private (update-exposure-history 
  (location-hash (buff 32))
  (co2 uint)
  (pm25 uint)
  (voc uint)
  (severity uint)
)
  (let ((date-block (/ stacks-block-height u144)) ;; Group by ~day
        (current-history (map-get? exposure-history { location-hash: location-hash, date-block: date-block })))
    
    (match current-history
      history
      (let ((current-breakdown (get severity-breakdown history)))
        (map-set exposure-history
          { location-hash: location-hash, date-block: date-block }
          {
            max-co2: (if (> co2 (get max-co2 history)) co2 (get max-co2 history)),
            max-pm25: (if (> pm25 (get max-pm25 history)) pm25 (get max-pm25 history)),
            max-voc: (if (> voc (get max-voc history)) voc (get max-voc history)),
            duration-above-threshold: (+ (get duration-above-threshold history) u1),
            total-notifications: (+ (get total-notifications history) u1),
            severity-breakdown: {
              critical: (if (is-eq severity u5) (+ (get critical current-breakdown) u1) (get critical current-breakdown)),
              high: (if (is-eq severity u4) (+ (get high current-breakdown) u1) (get high current-breakdown)),
              medium: (if (is-eq severity u3) (+ (get medium current-breakdown) u1) (get medium current-breakdown)),
              low: (if (is-eq severity u2) (+ (get low current-breakdown) u1) (get low current-breakdown))
            }
          }
        )
      )
      (map-set exposure-history
        { location-hash: location-hash, date-block: date-block }
        {
          max-co2: co2,
          max-pm25: pm25,
          max-voc: voc,
          duration-above-threshold: u1,
          total-notifications: u1,
          severity-breakdown: {
            critical: (if (is-eq severity u5) u1 u0),
            high: (if (is-eq severity u4) u1 u0),
            medium: (if (is-eq severity u3) u1 u0),
            low: (if (is-eq severity u2) u1 u0)
          }
        }
      )
    )
  )
)

;; Read-only Functions

;; Get exposure thresholds
(define-read-only (get-exposure-thresholds (location-hash (buff 32)))
  (map-get? exposure-thresholds { location-hash: location-hash })
)

;; Get notification details
(define-read-only (get-notification (notification-id uint))
  (map-get? notifications { notification-id: notification-id })
)

;; Get subscriber information
(define-read-only (get-subscription (subscriber principal) (location-hash (buff 32)))
  (map-get? subscribers { subscriber: subscriber, location-hash: location-hash })
)

;; Get location subscribers
(define-read-only (get-location-subscribers (location-hash (buff 32)))
  (map-get? location-subscribers { location-hash: location-hash })
)

;; Get exposure history
(define-read-only (get-exposure-history (location-hash (buff 32)) (date-block uint))
  (map-get? exposure-history { location-hash: location-hash, date-block: date-block })
)

;; Get notification acknowledgment
(define-read-only (get-acknowledgment (notification-id uint))
  (map-get? notification-acknowledgments { notification-id: notification-id })
)

;; Check if notification is due
(define-read-only (should-notify (location-hash (buff 32)) (severity uint))
  (should-send-notification location-hash severity)
)

;; Get notification statistics
(define-read-only (get-notification-stats)
  {
    total-notifications: (var-get total-notifications),
    active-subscribers: (var-get active-subscribers),
    next-notification-id: (var-get next-notification-id)
  }
)

;; title: exposure-notifications
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

