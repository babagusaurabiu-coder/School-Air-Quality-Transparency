;; IAQ Sensor Network Smart Contract
;; Manages indoor air quality sensor registration, data collection, and calibration

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_SENSOR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_DATA (err u102))
(define-constant ERR_CALIBRATION_EXPIRED (err u103))
(define-constant ERR_SENSOR_ALREADY_EXISTS (err u104))
(define-constant CALIBRATION_VALIDITY_BLOCKS u144000) ;; ~30 days

;; Data Variables
(define-data-var next-sensor-id uint u1)
(define-data-var total-sensors uint u0)
(define-data-var total-readings uint u0)

;; Data Maps
(define-map sensors
  { sensor-id: uint }
  {
    owner: principal,
    location-hash: (buff 32),
    sensor-type: (string-ascii 20),
    installation-block: uint,
    last-calibration: uint,
    active: bool,
    total-readings: uint
  }
)

(define-map sensor-readings
  { sensor-id: uint, reading-id: uint }
  {
    timestamp: uint,
    co2-ppm: uint,
    pm25-ugm3: uint,
    voc-ppb: uint,
    humidity-percent: uint,
    temperature-celsius: uint,
    data-hash: (buff 32)
  }
)

(define-map calibration-data
  { sensor-id: uint }
  {
    calibration-block: uint,
    calibrator: principal,
    co2-offset: int,
    pm25-offset: int,
    voc-offset: int,
    humidity-offset: int,
    temperature-offset: int,
    certification-hash: (buff 32)
  }
)

(define-map sensor-owners
  { owner: principal }
  { sensor-count: uint }
)

(define-map location-sensors
  { location-hash: (buff 32) }
  { sensor-ids: (list 50 uint) }
)

;; Private Functions
(define-private (is-authorized (sender principal))
  (or (is-eq sender CONTRACT_OWNER)
      (is-some (map-get? sensors { sensor-id: u1 })))
)

(define-private (validate-reading-data (co2 uint) (pm25 uint) (voc uint) (humidity uint) (temp uint))
  (and
    (<= co2 u10000)    ;; Max 10,000 ppm CO2
    (<= pm25 u1000)    ;; Max 1,000 ug/m3 PM2.5
    (<= voc u10000)    ;; Max 10,000 ppb VOCs
    (<= humidity u100) ;; Max 100% humidity
    (and (>= temp u0) (<= temp u50)) ;; 0-50C range
  )
)

(define-private (is-calibration-valid (sensor-id uint))
  (match (map-get? calibration-data { sensor-id: sensor-id })
    calibration
    (>= (+ (get calibration-block calibration) CALIBRATION_VALIDITY_BLOCKS) stacks-block-height)
    false
  )
)

(define-private (update-sensor-count (owner principal) (increment bool))
  (let ((current-count (default-to u0 (get sensor-count (map-get? sensor-owners { owner: owner })))))
    (map-set sensor-owners
      { owner: owner }
      { sensor-count: (if increment (+ current-count u1) (- current-count u1)) }
    )
  )
)

(define-private (add-sensor-to-location (location-hash (buff 32)) (sensor-id uint))
  (let ((current-sensors (default-to (list) (get sensor-ids (map-get? location-sensors { location-hash: location-hash })))))
    (ok (map-set location-sensors
      { location-hash: location-hash }
      { sensor-ids: (unwrap! (as-max-len? (append current-sensors sensor-id) u50) ERR_INVALID_DATA) }
    ))
  )
)

;; Public Functions

;; Register a new sensor
(define-public (register-sensor (location-hash (buff 32)) (sensor-type (string-ascii 20)))
  (let ((sensor-id (var-get next-sensor-id)))
    (asserts! (is-none (map-get? sensors { sensor-id: sensor-id })) ERR_SENSOR_ALREADY_EXISTS)
    (try! (add-sensor-to-location location-hash sensor-id))
    
    (map-set sensors
      { sensor-id: sensor-id }
      {
        owner: tx-sender,
        location-hash: location-hash,
        sensor-type: sensor-type,
        installation-block: stacks-block-height,
        last-calibration: u0,
        active: true,
        total-readings: u0
      }
    )
    
    (update-sensor-count tx-sender true)
    (var-set next-sensor-id (+ sensor-id u1))
    (var-set total-sensors (+ (var-get total-sensors) u1))
    (ok sensor-id)
  )
)

;; Submit sensor reading
(define-public (submit-reading 
  (sensor-id uint)
  (co2-ppm uint)
  (pm25-ugm3 uint)
  (voc-ppb uint)
  (humidity-percent uint)
  (temperature-celsius uint)
  (data-hash (buff 32))
)
  (let ((sensor-data (unwrap! (map-get? sensors { sensor-id: sensor-id }) ERR_SENSOR_NOT_FOUND))
        (reading-id (get total-readings sensor-data)))
    
    (asserts! (is-eq (get owner sensor-data) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (get active sensor-data) ERR_INVALID_DATA)
    (asserts! (validate-reading-data co2-ppm pm25-ugm3 voc-ppb humidity-percent temperature-celsius) ERR_INVALID_DATA)
    
    (map-set sensor-readings
      { sensor-id: sensor-id, reading-id: (+ reading-id u1) }
      {
        timestamp: stacks-block-height,
        co2-ppm: co2-ppm,
        pm25-ugm3: pm25-ugm3,
        voc-ppb: voc-ppb,
        humidity-percent: humidity-percent,
        temperature-celsius: temperature-celsius,
        data-hash: data-hash
      }
    )
    
    (map-set sensors
      { sensor-id: sensor-id }
      (merge sensor-data { total-readings: (+ reading-id u1) })
    )
    
    (var-set total-readings (+ (var-get total-readings) u1))
    (ok (+ reading-id u1))
  )
)

;; Calibrate sensor
(define-public (calibrate-sensor
  (sensor-id uint)
  (co2-offset int)
  (pm25-offset int)
  (voc-offset int)
  (humidity-offset int)
  (temperature-offset int)
  (certification-hash (buff 32))
)
  (let ((sensor-data (unwrap! (map-get? sensors { sensor-id: sensor-id }) ERR_SENSOR_NOT_FOUND)))
    (asserts! (is-eq (get owner sensor-data) tx-sender) ERR_UNAUTHORIZED)
    
    (map-set calibration-data
      { sensor-id: sensor-id }
      {
        calibration-block: stacks-block-height,
        calibrator: tx-sender,
        co2-offset: co2-offset,
        pm25-offset: pm25-offset,
        voc-offset: voc-offset,
        humidity-offset: humidity-offset,
        temperature-offset: temperature-offset,
        certification-hash: certification-hash
      }
    )
    
    (map-set sensors
      { sensor-id: sensor-id }
      (merge sensor-data { last-calibration: stacks-block-height })
    )
    
    (ok true)
  )
)

;; Deactivate sensor
(define-public (deactivate-sensor (sensor-id uint))
  (let ((sensor-data (unwrap! (map-get? sensors { sensor-id: sensor-id }) ERR_SENSOR_NOT_FOUND)))
    (asserts! (is-eq (get owner sensor-data) tx-sender) ERR_UNAUTHORIZED)
    
    (map-set sensors
      { sensor-id: sensor-id }
      (merge sensor-data { active: false })
    )
    
    (ok true)
  )
)

;; Read-only Functions

;; Get sensor information
(define-read-only (get-sensor (sensor-id uint))
  (map-get? sensors { sensor-id: sensor-id })
)

;; Get sensor reading
(define-read-only (get-reading (sensor-id uint) (reading-id uint))
  (map-get? sensor-readings { sensor-id: sensor-id, reading-id: reading-id })
)

;; Get calibration data
(define-read-only (get-calibration (sensor-id uint))
  (map-get? calibration-data { sensor-id: sensor-id })
)

;; Check if calibration is valid
(define-read-only (check-calibration-status (sensor-id uint))
  {
    valid: (is-calibration-valid sensor-id),
    blocks-remaining: (match (map-get? calibration-data { sensor-id: sensor-id })
      calibration
      (if (>= (+ (get calibration-block calibration) CALIBRATION_VALIDITY_BLOCKS) stacks-block-height)
        (some (- (+ (get calibration-block calibration) CALIBRATION_VALIDITY_BLOCKS) stacks-block-height))
        (some u0)
      )
      none
    )
  }
)

;; Get sensors by location
(define-read-only (get-location-sensors (location-hash (buff 32)))
  (map-get? location-sensors { location-hash: location-hash })
)

;; Get owner sensor count
(define-read-only (get-owner-sensor-count (owner principal))
  (default-to u0 (get sensor-count (map-get? sensor-owners { owner: owner })))
)

;; Get network statistics
(define-read-only (get-network-stats)
  {
    total-sensors: (var-get total-sensors),
    total-readings: (var-get total-readings),
    next-sensor-id: (var-get next-sensor-id)
  }
)

;; title: iaq-sensor-network
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

