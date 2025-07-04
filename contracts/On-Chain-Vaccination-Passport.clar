(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_EXISTS (err u101))
(define-constant ERR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_VACCINE (err u103))
(define-constant ERR_INVALID_DATE (err u104))
(define-constant ERR_INVALID_DOSE (err u105))
(define-constant ERR_REMINDER_NOT_FOUND (err u106))
(define-constant ERR_REMINDER_ALREADY_SET (err u107))


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