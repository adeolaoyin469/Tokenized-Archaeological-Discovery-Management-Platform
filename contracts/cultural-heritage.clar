;; Cultural Heritage Contract
;; Protects indigenous and historical rights

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u300))
(define-constant ERR_HERITAGE_NOT_FOUND (err u301))
(define-constant ERR_HERITAGE_EXISTS (err u302))
(define-constant ERR_INVALID_STATUS (err u303))
(define-constant ERR_INVALID_ACCESS_LEVEL (err u304))

;; Data Variables
(define-data-var heritage-counter uint u0)
(define-data-var repatriation-counter uint u0)

;; Data Maps
(define-map heritage-sites
  { heritage-id: uint }
  {
    name: (string-ascii 100),
    description: (string-ascii 500),
    cultural-group: (string-ascii 100),
    site-type: (string-ascii 50),
    significance-level: (string-ascii 20),
    access-restrictions: (string-ascii 50),
    sacred-status: bool,
    latitude: int,
    longitude: int,
    boundary-description: (string-ascii 300),
    protection-status: (string-ascii 30),
    registered-by: principal,
    cultural-representative: principal,
    created-at: uint,
    updated-at: uint
  }
)

(define-map cultural-rights
  { heritage-id: uint, stakeholder: principal }
  {
    rights-type: (string-ascii 50),
    permission-level: (string-ascii 30),
    granted-by: principal,
    cultural-authority: bool,
    consultation-required: bool,
    granted-at: uint,
    expires-at: (optional uint)
  }
)

(define-map repatriation-requests
  { request-id: uint }
  {
    heritage-id: uint,
    artifact-description: (string-ascii 300),
    requesting-group: (string-ascii 100),
    current-holder: principal,
    request-reason: (string-ascii 500),
    cultural-significance: (string-ascii 300),
    supporting-evidence: (string-ascii 500),
    request-status: (string-ascii 20),
    requested-by: principal,
    reviewed-by: (optional principal),
    created-at: uint,
    updated-at: uint
  }
)

(define-map cultural-protocols
  { heritage-id: uint, protocol-id: uint }
  {
    protocol-name: (string-ascii 100),
    description: (string-ascii 400),
    requirements: (string-ascii 300),
    violation-consequences: (string-ascii 200),
    established-by: principal,
    established-at: uint,
    active: bool
  }
)

(define-map protocol-counter
  { heritage-id: uint }
  { count: uint }
)

;; Private Functions
(define-private (has-cultural-authority (heritage-id uint) (user principal))
  (let ((heritage-data (map-get? heritage-sites { heritage-id: heritage-id })))
    (match heritage-data
      site (or
        (is-eq (get cultural-representative site) user)
        (is-eq CONTRACT_OWNER user)
        (match (map-get? cultural-rights { heritage-id: heritage-id, stakeholder: user })
          rights (get cultural-authority rights)
          false
        )
      )
      false
    )
  )
)

(define-private (is-valid-access-level (level (string-ascii 50)))
  (or
    (is-eq level "public")
    (is-eq level "restricted")
    (is-eq level "cultural-members-only")
    (is-eq level "sacred-prohibited")
    (is-eq level "consultation-required")
  )
)

;; Public Functions

;; Register a cultural heritage site
(define-public (register-heritage-site
  (name (string-ascii 100))
  (description (string-ascii 500))
  (cultural-group (string-ascii 100))
  (site-type (string-ascii 50))
  (significance-level (string-ascii 20))
  (access-restrictions (string-ascii 50))
  (sacred-status bool)
  (latitude int)
  (longitude int)
  (boundary-description (string-ascii 300))
  (cultural-representative principal)
)
  (let ((heritage-id (+ (var-get heritage-counter) u1)))
    (asserts! (is-valid-access-level access-restrictions) ERR_INVALID_ACCESS_LEVEL)

    (map-set heritage-sites
      { heritage-id: heritage-id }
      {
        name: name,
        description: description,
        cultural-group: cultural-group,
        site-type: site-type,
        significance-level: significance-level,
        access-restrictions: access-restrictions,
        sacred-status: sacred-status,
        latitude: latitude,
        longitude: longitude,
        boundary-description: boundary-description,
        protection-status: "registered",
        registered-by: tx-sender,
        cultural-representative: cultural-representative,
        created-at: block-height,
        updated-at: block-height
      }
    )

    (map-set protocol-counter { heritage-id: heritage-id } { count: u0 })
    (var-set heritage-counter heritage-id)
    (ok heritage-id)
  )
)

;; Grant cultural rights
(define-public (grant-cultural-rights
  (heritage-id uint)
  (stakeholder principal)
  (rights-type (string-ascii 50))
  (permission-level (string-ascii 30))
  (cultural-authority bool)
  (consultation-required bool)
  (expires-at (optional uint))
)
  (let ((heritage-data (unwrap! (map-get? heritage-sites { heritage-id: heritage-id }) ERR_HERITAGE_NOT_FOUND)))
    (asserts! (has-cultural-authority heritage-id tx-sender) ERR_UNAUTHORIZED)

    (map-set cultural-rights
      { heritage-id: heritage-id, stakeholder: stakeholder }
      {
        rights-type: rights-type,
        permission-level: permission-level,
        granted-by: tx-sender,
        cultural-authority: cultural-authority,
        consultation-required: consultation-required,
        granted-at: block-height,
        expires-at: expires-at
      }
    )
    (ok true)
  )
)

;; Submit repatriation request
(define-public (submit-repatriation-request
  (heritage-id uint)
  (artifact-description (string-ascii 300))
  (requesting-group (string-ascii 100))
  (current-holder principal)
  (request-reason (string-ascii 500))
  (cultural-significance (string-ascii 300))
  (supporting-evidence (string-ascii 500))
)
  (let ((request-id (+ (var-get repatriation-counter) u1)))
    (asserts! (is-some (map-get? heritage-sites { heritage-id: heritage-id })) ERR_HERITAGE_NOT_FOUND)

    (map-set repatriation-requests
      { request-id: request-id }
      {
        heritage-id: heritage-id,
        artifact-description: artifact-description,
        requesting-group: requesting-group,
        current-holder: current-holder,
        request-reason: request-reason,
        cultural-significance: cultural-significance,
        supporting-evidence: supporting-evidence,
        request-status: "submitted",
        requested-by: tx-sender,
        reviewed-by: none,
        created-at: block-height,
        updated-at: block-height
      }
    )

    (var-set repatriation-counter request-id)
    (ok request-id)
  )
)

;; Review repatriation request
(define-public (review-repatriation-request
  (request-id uint)
  (new-status (string-ascii 20))
)
  (let ((request-data (unwrap! (map-get? repatriation-requests { request-id: request-id }) ERR_HERITAGE_NOT_FOUND)))
    (asserts! (has-cultural-authority (get heritage-id request-data) tx-sender) ERR_UNAUTHORIZED)

    (map-set repatriation-requests
      { request-id: request-id }
      (merge request-data {
        request-status: new-status,
        reviewed-by: (some tx-sender),
        updated-at: block-height
      })
    )
    (ok true)
  )
)

;; Establish cultural protocol
(define-public (establish-protocol
  (heritage-id uint)
  (protocol-name (string-ascii 100))
  (description (string-ascii 400))
  (requirements (string-ascii 300))
  (violation-consequences (string-ascii 200))
)
  (let (
    (heritage-data (unwrap! (map-get? heritage-sites { heritage-id: heritage-id }) ERR_HERITAGE_NOT_FOUND))
    (counter-data (unwrap! (map-get? protocol-counter { heritage-id: heritage-id }) ERR_HERITAGE_NOT_FOUND))
    (protocol-id (+ (get count counter-data) u1))
  )
    (asserts! (has-cultural-authority heritage-id tx-sender) ERR_UNAUTHORIZED)

    (map-set cultural-protocols
      { heritage-id: heritage-id, protocol-id: protocol-id }
      {
        protocol-name: protocol-name,
        description: description,
        requirements: requirements,
        violation-consequences: violation-consequences,
        established-by: tx-sender,
        established-at: block-height,
        active: true
      }
    )

    (map-set protocol-counter { heritage-id: heritage-id } { count: protocol-id })
    (ok protocol-id)
  )
)

;; Update protection status
(define-public (update-protection-status
  (heritage-id uint)
  (new-status (string-ascii 30))
)
  (let ((heritage-data (unwrap! (map-get? heritage-sites { heritage-id: heritage-id }) ERR_HERITAGE_NOT_FOUND)))
    (asserts! (has-cultural-authority heritage-id tx-sender) ERR_UNAUTHORIZED)

    (map-set heritage-sites
      { heritage-id: heritage-id }
      (merge heritage-data {
        protection-status: new-status,
        updated-at: block-height
      })
    )
    (ok true)
  )
)

;; Read-only functions

;; Get heritage site information
(define-read-only (get-heritage-site (heritage-id uint))
  (map-get? heritage-sites { heritage-id: heritage-id })
)

;; Get cultural rights
(define-read-only (get-cultural-rights (heritage-id uint) (stakeholder principal))
  (map-get? cultural-rights { heritage-id: heritage-id, stakeholder: stakeholder })
)

;; Get repatriation request
(define-read-only (get-repatriation-request (request-id uint))
  (map-get? repatriation-requests { request-id: request-id })
)

;; Get cultural protocol
(define-read-only (get-cultural-protocol (heritage-id uint) (protocol-id uint))
  (map-get? cultural-protocols { heritage-id: heritage-id, protocol-id: protocol-id })
)

;; Get heritage site count
(define-read-only (get-heritage-count)
  (var-get heritage-counter)
)

;; Get repatriation request count
(define-read-only (get-repatriation-count)
  (var-get repatriation-counter)
)

;; Check cultural authority
(define-read-only (check-cultural-authority (heritage-id uint) (user principal))
  (has-cultural-authority heritage-id user)
)
