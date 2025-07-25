;; Agricultural Sensor Deployment Contract
;; Uses sensors to monitor crop conditions and optimize farming

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-FIELD-NOT-FOUND (err u401))
(define-constant ERR-INVALID-DATA (err u402))
(define-constant ERR-CROP-CYCLE-ACTIVE (err u403))

;; Data Variables
(define-data-var next-field-id uint u1)
(define-data-var next-sensor-deployment-id uint u1)
(define-data-var total-farms uint u0)

;; Data Maps
(define-map agricultural-fields
  uint
  {
    farm-name: (string-ascii 100),
    field-size: uint,
    coordinates: {lat: int, lon: int},
    crop-type: (string-ascii 50),
    planting-date: uint,
    expected-harvest: uint,
    farmer: principal,
    soil-type: (string-ascii 30)
  }
)

(define-map sensor-deployments
  uint
  {
    field-id: uint,
    sensor-type: (string-ascii 30),
    location: {x: int, y: int},
    installation-date: uint,
    battery-level: uint,
    status: (string-ascii 20),
    calibration-date: uint
  }
)

(define-map soil-conditions
  {field-id: uint, timestamp: uint}
  {
    moisture-level: uint,
    ph-level: uint,
    nitrogen: uint,
    phosphorus: uint,
    potassium: uint,
    temperature: int,
    organic-matter: uint
  }
)

(define-map weather-data
  {field-id: uint, timestamp: uint}
  {
    temperature: int,
    humidity: uint,
    rainfall: uint,
    wind-speed: uint,
    solar-radiation: uint,
    pressure: uint
  }
)

(define-map crop-health
  {field-id: uint, timestamp: uint}
  {
    growth-stage: (string-ascii 30),
    health-score: uint,
    pest-detected: bool,
    disease-risk: uint,
    yield-prediction: uint,
    irrigation-needed: bool
  }
)

(define-map irrigation-schedules
  uint
  {
    field-id: uint,
    schedule-type: (string-ascii 20),
    frequency: uint,
    duration: uint,
    water-amount: uint,
    next-irrigation: uint,
    automated: bool
  }
)

(define-map fertilization-plans
  uint
  {
    field-id: uint,
    fertilizer-type: (string-ascii 30),
    application-rate: uint,
    application-date: uint,
    nutrients: {n: uint, p: uint, k: uint},
    cost-per-hectare: uint
  }
)

(define-map authorized-farmers
  principal
  {
    authorized: bool,
    farm-registration: (string-ascii 50),
    certification-level: uint,
    specialization: (string-ascii 50)
  }
)

;; Public Functions

;; Register agricultural field
(define-public (register-field (farm-name (string-ascii 100)) (field-size uint) (coordinates {lat: int, lon: int}) (crop-type (string-ascii 50)) (soil-type (string-ascii 30)))
  (let
    (
      (field-id (var-get next-field-id))
    )
    (asserts! (is-authorized-farmer tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> field-size u0) ERR-INVALID-DATA)

    (map-set agricultural-fields field-id
      {
        farm-name: farm-name,
        field-size: field-size,
        coordinates: coordinates,
        crop-type: crop-type,
        planting-date: block-height,
        expected-harvest: (+ block-height u8760),
        farmer: tx-sender,
        soil-type: soil-type
      }
    )

    (var-set next-field-id (+ field-id u1))
    (var-set total-farms (+ (var-get total-farms) u1))

    (ok field-id)
  )
)

;; Deploy sensor to field
(define-public (deploy-sensor (field-id uint) (sensor-type (string-ascii 30)) (location {x: int, y: int}))
  (let
    (
      (field (unwrap! (map-get? agricultural-fields field-id) ERR-FIELD-NOT-FOUND))
      (deployment-id (var-get next-sensor-deployment-id))
    )
    (asserts! (is-eq (get farmer field) tx-sender) ERR-NOT-AUTHORIZED)

    (map-set sensor-deployments deployment-id
      {
        field-id: field-id,
        sensor-type: sensor-type,
        location: location,
        installation-date: block-height,
        battery-level: u100,
        status: "active",
        calibration-date: block-height
      }
    )

    (var-set next-sensor-deployment-id (+ deployment-id u1))
    (ok deployment-id)
  )
)

;; Update soil conditions
(define-public (update-soil-conditions (field-id uint) (moisture uint) (ph uint) (nitrogen uint) (phosphorus uint) (potassium uint) (temperature int))
  (let
    (
      (field (unwrap! (map-get? agricultural-fields field-id) ERR-FIELD-NOT-FOUND))
    )
    (asserts! (is-eq (get farmer field) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (<= moisture u100) ERR-INVALID-DATA)
    (asserts! (<= ph u14) ERR-INVALID-DATA)

    (map-set soil-conditions
      {field-id: field-id, timestamp: block-height}
      {
        moisture-level: moisture,
        ph-level: ph,
        nitrogen: nitrogen,
        phosphorus: phosphorus,
        potassium: potassium,
        temperature: temperature,
        organic-matter: (calculate-organic-matter nitrogen phosphorus potassium)
      }
    )

    (ok true)
  )
)

;; Update weather data
(define-public (update-weather-data (field-id uint) (temperature int) (humidity uint) (rainfall uint) (wind-speed uint) (solar-radiation uint))
  (let
    (
      (field (unwrap! (map-get? agricultural-fields field-id) ERR-FIELD-NOT-FOUND))
    )
    (asserts! (is-eq (get farmer field) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (<= humidity u100) ERR-INVALID-DATA)

    (map-set weather-data
      {field-id: field-id, timestamp: block-height}
      {
        temperature: temperature,
        humidity: humidity,
        rainfall: rainfall,
        wind-speed: wind-speed,
        solar-radiation: solar-radiation,
        pressure: u1013
      }
    )

    (ok true)
  )
)

;; Update crop health assessment
(define-public (update-crop-health (field-id uint) (growth-stage (string-ascii 30)) (health-score uint) (pest-detected bool) (disease-risk uint))
  (let
    (
      (field (unwrap! (map-get? agricultural-fields field-id) ERR-FIELD-NOT-FOUND))
      (yield-prediction (calculate-yield-prediction health-score disease-risk (get field-size field)))
      (irrigation-needed (< health-score u70))
    )
    (asserts! (is-eq (get farmer field) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (<= health-score u100) ERR-INVALID-DATA)
    (asserts! (<= disease-risk u100) ERR-INVALID-DATA)

    (map-set crop-health
      {field-id: field-id, timestamp: block-height}
      {
        growth-stage: growth-stage,
        health-score: health-score,
        pest-detected: pest-detected,
        disease-risk: disease-risk,
        yield-prediction: yield-prediction,
        irrigation-needed: irrigation-needed
      }
    )

    (ok true)
  )
)

;; Create irrigation schedule
(define-public (create-irrigation-schedule (field-id uint) (schedule-type (string-ascii 20)) (frequency uint) (duration uint) (water-amount uint))
  (let
    (
      (field (unwrap! (map-get? agricultural-fields field-id) ERR-FIELD-NOT-FOUND))
      (schedule-id (+ field-id (* frequency u1000)))
    )
    (asserts! (is-eq (get farmer field) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> frequency u0) ERR-INVALID-DATA)

    (map-set irrigation-schedules schedule-id
      {
        field-id: field-id,
        schedule-type: schedule-type,
        frequency: frequency,
        duration: duration,
        water-amount: water-amount,
        next-irrigation: (+ block-height frequency),
        automated: true
      }
    )

    (ok schedule-id)
  )
)

;; Create fertilization plan
(define-public (create-fertilization-plan (field-id uint) (fertilizer-type (string-ascii 30)) (application-rate uint) (n uint) (p uint) (k uint))
  (let
    (
      (field (unwrap! (map-get? agricultural-fields field-id) ERR-FIELD-NOT-FOUND))
      (plan-id (+ field-id (* application-rate u100)))
      (cost (calculate-fertilizer-cost application-rate (get field-size field)))
    )
    (asserts! (is-eq (get farmer field) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> application-rate u0) ERR-INVALID-DATA)

    (map-set fertilization-plans plan-id
      {
        field-id: field-id,
        fertilizer-type: fertilizer-type,
        application-rate: application-rate,
        application-date: (+ block-height u168),
        nutrients: {n: n, p: p, k: k},
        cost-per-hectare: cost
      }
    )

    (ok plan-id)
  )
)

;; Authorize farmer
(define-public (authorize-farmer (farmer principal) (farm-registration (string-ascii 50)) (certification-level uint) (specialization (string-ascii 50)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= certification-level u5) ERR-INVALID-DATA)

    (map-set authorized-farmers farmer
      {
        authorized: true,
        farm-registration: farm-registration,
        certification-level: certification-level,
        specialization: specialization
      }
    )

    (ok true)
  )
)

;; Read-only Functions

;; Get field information
(define-read-only (get-field (field-id uint))
  (map-get? agricultural-fields field-id)
)

;; Get sensor deployment
(define-read-only (get-sensor-deployment (deployment-id uint))
  (map-get? sensor-deployments deployment-id)
)

;; Get soil conditions
(define-read-only (get-soil-conditions (field-id uint) (timestamp uint))
  (map-get? soil-conditions {field-id: field-id, timestamp: timestamp})
)

;; Get weather data
(define-read-only (get-weather-data (field-id uint) (timestamp uint))
  (map-get? weather-data {field-id: field-id, timestamp: timestamp})
)

;; Get crop health
(define-read-only (get-crop-health (field-id uint) (timestamp uint))
  (map-get? crop-health {field-id: field-id, timestamp: timestamp})
)

;; Get irrigation schedule
(define-read-only (get-irrigation-schedule (schedule-id uint))
  (map-get? irrigation-schedules schedule-id)
)

;; Get fertilization plan
(define-read-only (get-fertilization-plan (plan-id uint))
  (map-get? fertilization-plans plan-id)
)

;; Check if user is authorized farmer
(define-read-only (is-authorized-farmer (user principal))
  (match (map-get? authorized-farmers user)
    farmer-info (get authorized farmer-info)
    false
  )
)

;; Get total farms
(define-read-only (get-total-farms)
  (var-get total-farms)
)

;; Private Functions

;; Calculate organic matter percentage
(define-private (calculate-organic-matter (nitrogen uint) (phosphorus uint) (potassium uint))
  (let
    (
      (total-nutrients (+ nitrogen (+ phosphorus potassium)))
    )
    (if (> total-nutrients u0)
        (/ (* total-nutrients u100) u300)
        u0)
  )
)

;; Calculate yield prediction
(define-private (calculate-yield-prediction (health-score uint) (disease-risk uint) (field-size uint))
  (let
    (
      (base-yield (* field-size u1000))
      (health-factor (/ health-score u100))
      (disease-factor (/ (- u100 disease-risk) u100))
    )
    (* base-yield (* health-factor disease-factor))
  )
)

;; Calculate fertilizer cost
(define-private (calculate-fertilizer-cost (application-rate uint) (field-size uint))
  (let
    (
      (base-cost-per-hectare u50)
      (rate-multiplier (/ application-rate u100))
    )
    (* base-cost-per-hectare rate-multiplier)
  )
)
