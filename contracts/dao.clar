;; Digital Council DAO Contract - Enhanced Version
;; Implements robust DAO functionality with additional safety features and improvements

;; Constants
(define-constant ADMIN tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-MOTION-NOT-FOUND (err u101))
(define-constant ERR-INVALID-BALLOT (err u102))
(define-constant ERR-DUPLICATE-VOTE (err u103))
(define-constant ERR-MOTION-EXPIRED (err u104))
(define-constant ERR-ALREADY-IMPLEMENTED (err u105))
(define-constant ERR-MOTION-DEFEATED (err u106))
(define-constant ERR-ZERO-STAKE (err u107))
(define-constant ERR-LOW-PARTICIPATION (err u108))
(define-constant ERR-INVALID-MOTION (err u109))
(define-constant ERR-MOTION-IN-PROGRESS (err u110))
(define-constant ERR-INVALID-SUBJECT (err u111))
(define-constant ERR-INVALID-GRACE-PERIOD (err u112))

;; Configuration
(define-constant DELIBERATION-PERIOD u144) ;; ~24 hours in blocks
(define-constant MIN-MOTION-THRESHOLD u100000) ;; Minimum tokens needed to create motion
(define-constant PARTICIPATION-THRESHOLD u300000) ;; Minimum total votes needed
(define-constant MIN_BRIEF_LENGTH u10)
(define-constant MAX_BRIEF_LENGTH u500)
(define-constant MIN_SUBJECT_LENGTH u4)
(define-constant MAX_SUBJECT_LENGTH u100)
(define-constant MIN_GRACE_PERIOD u12) ;; Minimum 2 hours in blocks
(define-constant MAX_GRACE_PERIOD u1440) ;; Maximum ~10 days in blocks
(define-constant MOTION_INTERVAL u72) ;; ~12 hours cooldown between motions

;; Data Variables
(define-data-var token-supply uint u1000000)
(define-data-var motion-count uint u0)
(define-data-var system-halted bool false)
(define-data-var last-motion-time uint u0)

;; Data Maps
(define-map motions
    uint
    {
        subject: (string-ascii 100),
        brief: (string-ascii 500),
        initiator: principal,
        start-block: uint,
        end-block: uint,
        affirmative-count: uint,
        negative-count: uint,
        implemented: bool,
        withdrawn: bool,
        grace-period: uint,
        total-ballots-cast: uint
    }
)

(define-map stakes principal uint)
(define-map ballots 
    {motion-id: uint, member: principal} 
    {stake-amount: uint, in-favor: bool}
)

;; Private validation functions
(define-private (validate-subject (subject (string-ascii 100)))
    (and 
        (>= (len subject) MIN_SUBJECT_LENGTH)
        (<= (len subject) MAX_SUBJECT_LENGTH)
    )
)

(define-private (validate-brief (brief (string-ascii 500)))
    (and 
        (>= (len brief) MIN_BRIEF_LENGTH)
        (<= (len brief) MAX_BRIEF_LENGTH)
    )
)

(define-private (validate-grace-period (grace-period uint))
    (and 
        (>= grace-period MIN_GRACE_PERIOD)
        (<= grace-period MAX_GRACE_PERIOD)
    )
)

;; Authorization check
(define-private (is-admin)
    (is-eq tx-sender ADMIN)
)

;; Emergency halt
(define-public (set-halt (halt bool))
    (begin
        (asserts! (is-admin) ERR-UNAUTHORIZED)
        (var-set system-halted halt)
        (ok true)
    )
)

;; Token transfer function with additional checks
(define-public (transfer-stake (amount uint) (recipient principal))
    (begin
        (asserts! (not (var-get system-halted)) ERR-UNAUTHORIZED)
        (asserts! (> amount u0) ERR-ZERO-STAKE)
        (asserts! (not (is-eq tx-sender recipient)) ERR-INVALID-BALLOT)
        
        (let ((sender-stake (default-to u0 (map-get? stakes tx-sender))))
            (asserts! (>= sender-stake amount) (err u1))
            
            (map-set stakes tx-sender (- sender-stake amount))
            (map-set stakes recipient (+ (default-to u0 (map-get? stakes recipient)) amount))
            (ok true)
        )
    )
)

;; Create new motion with enhanced validation
(define-public (propose-motion (subject (string-ascii 100)) (brief (string-ascii 500)) (grace-period uint))
    (begin
        (asserts! (not (var-get system-halted)) ERR-UNAUTHORIZED)
        (asserts! (validate-subject subject) ERR-INVALID-SUBJECT)
        (asserts! (validate-brief brief) ERR-INVALID-MOTION)
        (asserts! (validate-grace-period grace-period) ERR-INVALID-GRACE-PERIOD)
        (asserts! (>= (get-stake tx-sender) MIN-MOTION-THRESHOLD) ERR-UNAUTHORIZED)
        (asserts! (>= (- block-height (var-get last-motion-time)) MOTION_INTERVAL) ERR-MOTION-IN-PROGRESS)
        
        (let (
            (motion-id (var-get motion-count))
            (start-block block-height)
            (end-block (+ block-height DELIBERATION-PERIOD))
        )
            (map-set motions motion-id {
                subject: subject,
                brief: brief,
                initiator: tx-sender,
                start-block: start-block,
                end-block: end-block,
                affirmative-count: u0,
                negative-count: u0,
                implemented: false,
                withdrawn: false,
                grace-period: grace-period,
                total-ballots-cast: u0
            })
            (var-set motion-count (+ motion-id u1))
            (var-set last-motion-time block-height)
            (ok motion-id)
        )
    )
)

;; Enhanced voting function with vote tracking
(define-public (cast-ballot (motion-id uint) (in-favor bool))
    (begin
        (asserts! (not (var-get system-halted)) ERR-UNAUTHORIZED)
        
        (let (
            (motion (unwrap! (map-get? motions motion-id) ERR-MOTION-NOT-FOUND))
            (member-stake (default-to u0 (map-get? stakes tx-sender)))
        )
            (asserts! (>= block-height (get start-block motion)) ERR-INVALID-BALLOT)
            (asserts! (<= block-height (get end-block motion)) ERR-MOTION-EXPIRED)
            (asserts! (not (get withdrawn motion)) ERR-MOTION-EXPIRED)
            (asserts! (is-none (map-get? ballots {motion-id: motion-id, member: tx-sender})) ERR-DUPLICATE-VOTE)
            (asserts! (> member-stake u0) ERR-UNAUTHORIZED)
            
            (map-set ballots {motion-id: motion-id, member: tx-sender} 
                {stake-amount: member-stake, in-favor: in-favor})
                
            (map-set motions motion-id 
                (merge motion {
                    affirmative-count: (if in-favor (+ (get affirmative-count motion) member-stake) (get affirmative-count motion)),
                    negative-count: (if in-favor (get negative-count motion) (+ (get negative-count motion) member-stake)),
                    total-ballots-cast: (+ (get total-ballots-cast motion) member-stake)
                }))
            
            (ok true)
        )
    )
)

;; Withdraw motion
(define-public (withdraw-motion (motion-id uint))
    (let (
        (motion (unwrap! (map-get? motions motion-id) ERR-MOTION-NOT-FOUND))
    )
        (asserts! (or (is-admin) (is-eq tx-sender (get initiator motion))) ERR-UNAUTHORIZED)
        (asserts! (not (get implemented motion)) ERR-ALREADY-IMPLEMENTED)
        (asserts! (<= block-height (get end-block motion)) ERR-MOTION-EXPIRED)
        
        (map-set motions motion-id (merge motion {withdrawn: true}))
        (ok true)
    )
)

;; Enhanced motion implementation with participation check
(define-public (implement-motion (motion-id uint))
    (let (
        (motion (unwrap! (map-get? motions motion-id) ERR-MOTION-NOT-FOUND))
    )
        (asserts! (not (var-get system-halted)) ERR-UNAUTHORIZED)
        (asserts! (> block-height (+ (get end-block motion) (get grace-period motion))) ERR-MOTION-NOT-FOUND)
        (asserts! (not (get implemented motion)) ERR-ALREADY-IMPLEMENTED)
        (asserts! (not (get withdrawn motion)) ERR-MOTION-EXPIRED)
        (asserts! (>= (get total-ballots-cast motion) PARTICIPATION-THRESHOLD) ERR-LOW-PARTICIPATION)
        (asserts! (> (get affirmative-count motion) (get negative-count motion)) ERR-MOTION-DEFEATED)
        
        (begin
            (map-set motions motion-id (merge motion {implemented: true}))
            ;; Add custom implementation logic here
            (ok true)
        )
    )
)

;; Read-only functions
(define-read-only (get-motion (motion-id uint))
    (map-get? motions motion-id)
)

(define-read-only (get-ballot (motion-id uint) (member principal))
    (map-get? ballots {motion-id: motion-id, member: member})
)

(define-read-only (get-stake (account principal))
    (default-to u0 (map-get? stakes account))
)