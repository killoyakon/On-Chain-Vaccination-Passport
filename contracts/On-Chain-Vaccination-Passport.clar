(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_EXISTS (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_VACCINE (err u103))
(define-constant ERR_INVALID_DATE (err u104))
(define-constant ERR_INVALID_DOSE (err u105))
(define-constant ERR_REMINDER_NOT_FOUND (err u106))
(define-constant ERR_REMINDER_ALREADY_SET (err u107))

(define-constant ERR_CERTIFICATE_EXISTS (err u108))
(define-constant ERR_CERTIFICATE_NOT_FOUND (err u109))
(define-constant ERR_INVALID_CERTIFICATE (err u110))

(define-constant ERR_BADGE_NOT_FOUND (err u111))
(define-constant ERR_BADGE_ALREADY_EARNED (err u112))

(define-constant BADGE_FIRST_DOSE u1)
(define-constant BADGE_FULLY_VACCINATED u2)
(define-constant BADGE_MULTI_VACCINE u3)
(define-constant BADGE_EARLY_ADOPTER u4)
(define-constant BADGE_BOOSTER_CHAMPION u5)

(define-constant ERR_PERMISSION_DENIED (err u113))
(define-constant ERR_PERMISSION_EXPIRED (err u114))
(define-constant ERR_PERMISSION_NOT_FOUND (err u115))


(define-data-var contract-owner principal CONTRACT_OWNER)

(define-map authorized-providers principal bool)

(define-map vaccination-records 
    {patient: principal, vaccine-id: uint} 
    {
        vaccine-name: (string-ascii 50),
        manufacturer: (string-ascii 50),
        batch-number: (string-ascii 20),
        dose-number: uint,
        total-doses: uint,
        vaccination-date: uint,
        provider: principal,
        location: (string-ascii 100),
        is-valid: bool
    }
)

(define-map patient-vaccine-count principal uint)

(define-map vaccine-registry 
    uint 
    {
        name: (string-ascii 50),
        manufacturer: (string-ascii 50),
        required-doses: uint,
        is-approved: bool
    }
)

(define-data-var next-vaccine-id uint u1)
(define-data-var next-record-id uint u1)

(define-read-only (get-contract-owner)
    (var-get contract-owner)
)

(define-read-only (is-authorized-provider (provider principal))
    (default-to false (map-get? authorized-providers provider))
)

(define-read-only (get-vaccination-record (patient principal) (vaccine-id uint))
    (map-get? vaccination-records {patient: patient, vaccine-id: vaccine-id})
)

(define-read-only (get-patient-vaccine-count (patient principal))
    (default-to u0 (map-get? patient-vaccine-count patient))
)

(define-read-only (get-vaccine-info (vaccine-id uint))
    (map-get? vaccine-registry vaccine-id)
)

(define-read-only (is-fully-vaccinated (patient principal) (vaccine-id uint))
    (let (
        (vaccine-info (unwrap! (get-vaccine-info vaccine-id) false))
        (required-doses (get required-doses vaccine-info))
        (patient-doses (get-patient-doses-for-vaccine patient vaccine-id))
    )
    (>= patient-doses required-doses))
)

(define-read-only (get-patient-doses-for-vaccine (patient principal) (vaccine-id uint))
    (let (
        (record (get-vaccination-record patient vaccine-id))
    )
    (match record
        some-record (if (get is-valid some-record) (get dose-number some-record) u0)
        u0
    ))
)

(define-read-only (verify-vaccination-status (patient principal) (vaccine-id uint))
    (let (
        (record (get-vaccination-record patient vaccine-id))
    )
    (match record
        some-record {
            exists: true,
            is-valid: (get is-valid some-record),
            dose-number: (get dose-number some-record),
            total-doses: (get total-doses some-record),
            vaccination-date: (get vaccination-date some-record),
            provider: (get provider some-record),
            fully-vaccinated: (is-fully-vaccinated patient vaccine-id)
        }
        {
            exists: false,
            is-valid: false,
            dose-number: u0,
            total-doses: u0,
            vaccination-date: u0,
            provider: CONTRACT_OWNER,
            fully-vaccinated: false
        }
    ))
)

(define-public (add-authorized-provider (provider principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (ok (map-set authorized-providers provider true))
    )
)

(define-public (remove-authorized-provider (provider principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (ok (map-delete authorized-providers provider))
    )
)

(define-public (register-vaccine 
    (name (string-ascii 50))
    (manufacturer (string-ascii 50))
    (required-doses uint)
)
    (let (
        (vaccine-id (var-get next-vaccine-id))
    )
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (> required-doses u0) ERR_INVALID_DOSE)
    (map-set vaccine-registry vaccine-id {
        name: name,
        manufacturer: manufacturer,
        required-doses: required-doses,
        is-approved: true
    })
    (var-set next-vaccine-id (+ vaccine-id u1))
    (ok vaccine-id))
)

(define-public (record-vaccination
    (patient principal)
    (vaccine-id uint)
    (vaccine-name (string-ascii 50))
    (manufacturer (string-ascii 50))
    (batch-number (string-ascii 20))
    (dose-number uint)
    (total-doses uint)
    (vaccination-date uint)
    (location (string-ascii 100))
)
    (let (
        (current-count (get-patient-vaccine-count patient))
        (vaccine-info (unwrap! (get-vaccine-info vaccine-id) ERR_NOT_FOUND))
    )
    (asserts! (is-authorized-provider tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> dose-number u0) ERR_INVALID_DOSE)
    (asserts! (> total-doses u0) ERR_INVALID_DOSE)
    (asserts! (<= dose-number total-doses) ERR_INVALID_DOSE)
    (asserts! (> vaccination-date u0) ERR_INVALID_DATE)
    (asserts! (get is-approved vaccine-info) ERR_INVALID_VACCINE)
    
    (map-set vaccination-records 
        {patient: patient, vaccine-id: vaccine-id}
        {
            vaccine-name: vaccine-name,
            manufacturer: manufacturer,
            batch-number: batch-number,
            dose-number: dose-number,
            total-doses: total-doses,
            vaccination-date: vaccination-date,
            provider: tx-sender,
            location: location,
            is-valid: true
        }
    )
    (map-set patient-vaccine-count patient (+ current-count u1))
    (ok true))
)

(define-public (invalidate-vaccination-record (patient principal) (vaccine-id uint))
    (let (
        (existing-record (unwrap! (get-vaccination-record patient vaccine-id) ERR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (map-set vaccination-records 
        {patient: patient, vaccine-id: vaccine-id}
        (merge existing-record {is-valid: false})
    )
    (ok true))
)

(define-public (transfer-ownership (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
        (var-set contract-owner new-owner)
        (ok true)
    )
)

(define-public (update-vaccination-record
    (patient principal)
    (vaccine-id uint)
    (new-dose-number uint)
    (new-vaccination-date uint)
    (new-location (string-ascii 100))
)
    (let (
        (existing-record (unwrap! (get-vaccination-record patient vaccine-id) ERR_NOT_FOUND))
    )
    (asserts! (is-authorized-provider tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> new-dose-number u0) ERR_INVALID_DOSE)
    (asserts! (> new-vaccination-date u0) ERR_INVALID_DATE)
    (asserts! (<= new-dose-number (get total-doses existing-record)) ERR_INVALID_DOSE)
    
    (map-set vaccination-records 
        {patient: patient, vaccine-id: vaccine-id}
        (merge existing-record {
            dose-number: new-dose-number,
            vaccination-date: new-vaccination-date,
            location: new-location,
            provider: tx-sender
        })
    )
    (ok true))
)

(define-read-only (get-next-vaccine-id)
    (var-get next-vaccine-id)
)

(define-read-only (get-all-patient-info (patient principal))
    {
        total-vaccines: (get-patient-vaccine-count patient),
        patient-address: patient
    }
)


(define-map vaccination-reminders
    {patient: principal, vaccine-id: uint}
    {
        next-dose-due: uint,
        next-dose-number: uint,
        reminder-interval: uint,
        is-active: bool
    }
)

(define-read-only (get-vaccination-reminder (patient principal) (vaccine-id uint))
    (map-get? vaccination-reminders {patient: patient, vaccine-id: vaccine-id})
)

(define-read-only (is-vaccination-due (patient principal) (vaccine-id uint) (current-time uint))
    (let (
        (reminder (get-vaccination-reminder patient vaccine-id))
    )
    (match reminder
        some-reminder (and 
            (get is-active some-reminder)
            (<= (get next-dose-due some-reminder) current-time)
        )
        false
    ))
)

(define-read-only (get-days-until-due (patient principal) (vaccine-id uint) (current-time uint))
    (let (
        (reminder (get-vaccination-reminder patient vaccine-id))
    )
    (match reminder
        some-reminder (if (get is-active some-reminder)
            (if (>= current-time (get next-dose-due some-reminder))
                u0
                (- (get next-dose-due some-reminder) current-time)
            )
            u0
        )
        u0
    ))
)

(define-public (set-vaccination-reminder
    (patient principal)
    (vaccine-id uint)
    (next-dose-due uint)
    (reminder-interval uint)
)
    (let (
        (existing-reminder (get-vaccination-reminder patient vaccine-id))
        (vaccine-info (unwrap! (get-vaccine-info vaccine-id) ERR_NOT_FOUND))
        (current-doses (get-patient-doses-for-vaccine patient vaccine-id))
        (required-doses (get required-doses vaccine-info))
    )
    (asserts! (is-authorized-provider tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> next-dose-due u0) ERR_INVALID_DATE)
    (asserts! (> reminder-interval u0) ERR_INVALID_DATE)
    (asserts! (< current-doses required-doses) ERR_INVALID_DOSE)
    (asserts! (is-none existing-reminder) ERR_REMINDER_ALREADY_SET)
    
    (map-set vaccination-reminders 
        {patient: patient, vaccine-id: vaccine-id}
        {
            next-dose-due: next-dose-due,
            next-dose-number: (+ current-doses u1),
            reminder-interval: reminder-interval,
            is-active: true
        }
    )
    (ok true))
)

(define-public (complete-vaccination-reminder (patient principal) (vaccine-id uint))
    (let (
        (existing-reminder (unwrap! (get-vaccination-reminder patient vaccine-id) ERR_REMINDER_NOT_FOUND))
        (vaccine-info (unwrap! (get-vaccine-info vaccine-id) ERR_NOT_FOUND))
        (current-doses (get-patient-doses-for-vaccine patient vaccine-id))
        (required-doses (get required-doses vaccine-info))
        (next-dose-due (+ (get next-dose-due existing-reminder) (get reminder-interval existing-reminder)))
        (next-dose-number (+ (get next-dose-number existing-reminder) u1))
    )
    (asserts! (is-authorized-provider tx-sender) ERR_UNAUTHORIZED)
    
    (if (<= next-dose-number required-doses)
        (map-set vaccination-reminders 
            {patient: patient, vaccine-id: vaccine-id}
            (merge existing-reminder {
                next-dose-due: next-dose-due,
                next-dose-number: next-dose-number
            })
        )
        (map-set vaccination-reminders 
            {patient: patient, vaccine-id: vaccine-id}
            (merge existing-reminder {is-active: false})
        )
    )
    (ok true))
)


(define-map vaccination-certificates
    (buff 32)
    {
        patient: principal,
        vaccine-id: uint,
        certificate-hash: (buff 32),
        issue-date: uint,
        expiry-date: uint,
        issuer: principal,
        certificate-type: (string-ascii 20),
        is-valid: bool
    }
)

(define-map patient-certificates principal (list 10 (buff 32)))

(define-data-var certificate-nonce uint u0)

(define-read-only (get-certificate (cert-id (buff 32)))
    (map-get? vaccination-certificates cert-id)
)

(define-read-only (get-patient-certificates (patient principal))
    (default-to (list) (map-get? patient-certificates patient))
)

(define-read-only (verify-certificate-hash (cert-id (buff 32)) (provided-hash (buff 32)))
    (let (
        (certificate (get-certificate cert-id))
    )
    (match certificate
        some-cert (and 
            (get is-valid some-cert)
            (is-eq (get certificate-hash some-cert) provided-hash)
        )
        false
    ))
)

(define-public (generate-vaccination-certificate
    (patient principal)
    (vaccine-id uint)
    (certificate-type (string-ascii 20))
    (validity-days uint)
)
    (let (
        (vaccination-record (unwrap! (get-vaccination-record patient vaccine-id) ERR_NOT_FOUND))
        (current-time (+ stacks-block-height u1))
        (expiry-date (+ current-time validity-days))
        (nonce (var-get certificate-nonce))
        (cert-data (concat (unwrap-panic (to-consensus-buff? patient))
                          (concat (unwrap-panic (to-consensus-buff? vaccine-id))
                                 (unwrap-panic (to-consensus-buff? nonce)))))
        (cert-id (keccak256 cert-data))
        (cert-hash (keccak256 (concat cert-data (unwrap-panic (to-consensus-buff? current-time)))))
        (patient-certs (get-patient-certificates patient))
    )
    (asserts! (is-authorized-provider tx-sender) ERR_UNAUTHORIZED)
    (asserts! (get is-valid vaccination-record) ERR_INVALID_VACCINE)
    (asserts! (> validity-days u0) ERR_INVALID_DATE)
    (asserts! (is-none (get-certificate cert-id)) ERR_CERTIFICATE_EXISTS)
    
    (map-set vaccination-certificates cert-id {
        patient: patient,
        vaccine-id: vaccine-id,
        certificate-hash: cert-hash,
        issue-date: current-time,
        expiry-date: expiry-date,
        issuer: tx-sender,
        certificate-type: certificate-type,
        is-valid: true
    })
    
    (map-set patient-certificates patient (unwrap-panic (as-max-len? (append patient-certs cert-id) u10)))
    (var-set certificate-nonce (+ nonce u1))
    (ok {certificate-id: cert-id, certificate-hash: cert-hash}))
)

(define-public (revoke-certificate (cert-id (buff 32)))
    (let (
        (certificate (unwrap! (get-certificate cert-id) ERR_CERTIFICATE_NOT_FOUND))
    )
    (asserts! (or (is-eq tx-sender (var-get contract-owner))
                  (is-eq tx-sender (get issuer certificate))) ERR_UNAUTHORIZED)
    
    (map-set vaccination-certificates cert-id 
        (merge certificate {is-valid: false}))
    (ok true))
)


(define-map badge-registry
    uint
    {
        name: (string-ascii 30),
        description: (string-ascii 100),
        criteria-type: (string-ascii 20),
        criteria-value: uint,
        icon: (string-ascii 50)
    }
)

(define-map patient-badges
    {patient: principal, badge-id: uint}
    {
        earned-date: uint,
        vaccine-id: uint,
        milestone-data: uint
    }
)

(define-map patient-badge-count principal uint)

(define-data-var badge-system-initialized bool false)

(define-read-only (get-badge-info (badge-id uint))
    (map-get? badge-registry badge-id)
)

(define-read-only (has-badge (patient principal) (badge-id uint))
    (is-some (map-get? patient-badges {patient: patient, badge-id: badge-id}))
)

(define-read-only (get-patient-badge-count (patient principal))
    (default-to u0 (map-get? patient-badge-count patient))
)

(define-read-only (get-badge-achievement (patient principal) (badge-id uint))
    (map-get? patient-badges {patient: patient, badge-id: badge-id})
)

(define-private (initialize-badge-system)
    (begin
        (map-set badge-registry BADGE_FIRST_DOSE {
            name: "First Dose Hero",
            description: "Received your first vaccination dose",
            criteria-type: "dose_count",
            criteria-value: u1,
            icon: "GOLD"
        })
        (map-set badge-registry BADGE_FULLY_VACCINATED {
            name: "Fully Protected", 
            description: "Completed full vaccination series",
            criteria-type: "fully_vaccinated",
            criteria-value: u1,
            icon: "SHIELD"
        })
        (map-set badge-registry BADGE_MULTI_VACCINE {
            name: "Multi-Vaccine Champion",
            description: "Vaccinated against 3+ different diseases", 
            criteria-type: "vaccine_types",
            criteria-value: u3,
            icon: "TROPHY"
        })
        (var-set badge-system-initialized true)
    )
)

(define-private (award-badge (patient principal) (badge-id uint) (vaccine-id uint) (milestone-data uint))
    (let (
        (current-badge-count (get-patient-badge-count patient))
    )
    (if (not (has-badge patient badge-id))
        (begin
            (map-set patient-badges 
                {patient: patient, badge-id: badge-id}
                {
                    earned-date: stacks-block-height,
                    vaccine-id: vaccine-id,
                    milestone-data: milestone-data
                }
            )
            (map-set patient-badge-count patient (+ current-badge-count u1))
            true
        )
        false
    ))
)

(define-private (check-and-award-badges (patient principal) (vaccine-id uint))
    (let (
        (patient-vaccine-total (get-patient-vaccine-count patient))
        (is-fully-vaxxed (is-fully-vaccinated patient vaccine-id))
    )
    (if (not (var-get badge-system-initialized)) (initialize-badge-system) true)
    
    (if (is-eq patient-vaccine-total u1)
        (award-badge patient BADGE_FIRST_DOSE vaccine-id patient-vaccine-total)
        true
    )
    
    (if is-fully-vaxxed
        (award-badge patient BADGE_FULLY_VACCINATED vaccine-id u1)
        true
    )
    
    (if (>= patient-vaccine-total u3)
        (award-badge patient BADGE_MULTI_VACCINE vaccine-id patient-vaccine-total)
        true
    )
    )
)


(define-map vaccination-access-permissions
    {patient: principal, accessor: principal, vaccine-id: uint}
    {
        granted-at: uint,
        expires-at: uint,
        can-view-details: bool,
        can-verify-status: bool,
        is-active: bool,
        purpose: (string-ascii 50)
    }
)

(define-map patient-active-permissions principal (list 20 principal))

(define-read-only (get-access-permission (patient principal) (accessor principal) (vaccine-id uint))
    (map-get? vaccination-access-permissions {patient: patient, accessor: accessor, vaccine-id: vaccine-id})
)

(define-read-only (has-valid-permission (patient principal) (accessor principal) (vaccine-id uint) (current-time uint))
    (let (
        (permission (get-access-permission patient accessor vaccine-id))
    )
    (match permission
        some-perm (and
            (get is-active some-perm)
            (>= (get expires-at some-perm) current-time)
        )
        false
    ))
)

(define-public (grant-vaccination-access
    (accessor principal)
    (vaccine-id uint)
    (duration uint)
    (can-view-details bool)
    (can-verify-status bool)
    (purpose (string-ascii 50))
)
    (let (
        (current-time stacks-block-height)
        (expiry-time (+ current-time duration))
        (patient tx-sender)
        (current-accessors (default-to (list) (map-get? patient-active-permissions patient)))
    )
    (asserts! (> duration u0) ERR_INVALID_DATE)
    (asserts! (is-some (get-vaccination-record patient vaccine-id)) ERR_NOT_FOUND)
    
    (map-set vaccination-access-permissions
        {patient: patient, accessor: accessor, vaccine-id: vaccine-id}
        {
            granted-at: current-time,
            expires-at: expiry-time,
            can-view-details: can-view-details,
            can-verify-status: can-verify-status,
            is-active: true,
            purpose: purpose
        }
    )
    (map-set patient-active-permissions patient 
        (unwrap-panic (as-max-len? (append current-accessors accessor) u20)))
    (ok true))
)

(define-public (revoke-vaccination-access (accessor principal) (vaccine-id uint))
    (let (
        (patient tx-sender)
        (permission (unwrap! (get-access-permission patient accessor vaccine-id) ERR_PERMISSION_NOT_FOUND))
    )
    (map-set vaccination-access-permissions
        {patient: patient, accessor: accessor, vaccine-id: vaccine-id}
        (merge permission {is-active: false})
    )
    (ok true))
)