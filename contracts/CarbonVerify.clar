;; CarbonVerify - Carbon credit verification and environmental impact tracking system
(define-map carbon-credits uint {
  project-developer: principal,
  project-name: (string-utf8 64),
  methodology-details: (string-utf8 256),
  credit-vintage: uint,
  project-location: (string-utf8 64),
  verified: bool
})

(define-map developer-projects principal (list 100 uint))
(define-map carbon-auditors principal bool)
(define-data-var credit-id-sequence uint u0)

;; Error codes
(define-constant err-unauthorized-developer (err u1100))
(define-constant err-unauthorized-auditor (err u1101))
(define-constant err-credit-not-found (err u1102))
(define-constant err-permission-denied (err u403))
(define-constant err-project-limit-exceeded (err u1104))
(define-constant err-invalid-auditor-principal (err u1105))
(define-constant err-invalid-project-name (err u1106))
(define-constant err-invalid-methodology-details (err u1107))
(define-constant err-invalid-credit-vintage (err u1108))
(define-constant err-invalid-project-location (err u1109))
(define-constant err-invalid-credit-id (err u1110))

;; Environmental authority for carbon verification
(define-constant environmental-authority tx-sender)

;; Register carbon auditor
(define-public (register-carbon-auditor (auditor principal))
  (begin
    ;; Verify sender is environmental authority
    (asserts! (is-eq tx-sender environmental-authority) err-permission-denied)
    
    ;; Validate auditor principal
    (asserts! (not (is-eq auditor 'SP000000000000000000002Q6VF78)) err-invalid-auditor-principal)
    
    ;; Register auditor in system
    (ok (map-set carbon-auditors auditor true))
  )
)

;; Register carbon credit project
(define-public (register-carbon-credit 
  (project-name (string-utf8 64)) 
  (methodology-details (string-utf8 256)) 
  (credit-vintage uint) 
  (project-location (string-utf8 64)))
  (let
    ((credit-id (var-get credit-id-sequence))
     (project-developer tx-sender)
     (current-projects (default-to (list) (map-get? developer-projects project-developer))))
    
    ;; Validate input parameters
    (asserts! (> (len project-name) u0) err-invalid-project-name)
    (asserts! (> (len methodology-details) u0) err-invalid-methodology-details)
    (asserts! (> credit-vintage u2020) err-invalid-credit-vintage)
    (asserts! (> (len project-location) u0) err-invalid-project-location)
    
    ;; Check project capacity
    (asserts! (< (len current-projects) u100) err-project-limit-exceeded)
    
    ;; Store carbon credit information
    (map-set carbon-credits credit-id {
      project-developer: project-developer,
      project-name: project-name,
      methodology-details: methodology-details,
      credit-vintage: credit-vintage,
      project-location: project-location,
      verified: false
    })
    
    ;; Update developer projects
    (let 
      ((updated-projects (unwrap-panic (as-max-len? (concat (list credit-id) current-projects) u100))))
      (map-set developer-projects project-developer updated-projects)
    )
    
    ;; Increment credit ID sequence
    (var-set credit-id-sequence (+ credit-id u1))
    
    (ok credit-id)))

;; Verify carbon credit
(define-public (verify-carbon-credit (credit-id uint))
  (begin
    ;; Validate credit ID
    (asserts! (< credit-id (var-get credit-id-sequence)) err-invalid-credit-id)
    
    (let
      ((credit (unwrap! (map-get? carbon-credits credit-id) err-credit-not-found)))
      
      ;; Check if sender is authorized auditor
      (asserts! (default-to false (map-get? carbon-auditors tx-sender)) err-unauthorized-auditor)
      
      ;; Update verification status
      (ok (map-set carbon-credits credit-id (merge credit {verified: true})))
    )
  )
)

;; Get carbon credit details
(define-read-only (get-carbon-credit (credit-id uint))
  (map-get? carbon-credits credit-id))

;; Get developer projects
(define-read-only (get-developer-projects (developer principal))
  (default-to (list) (map-get? developer-projects developer)))

;; Check auditor authorization
(define-read-only (is-carbon-auditor (address principal))
  (default-to false (map-get? carbon-auditors address)))