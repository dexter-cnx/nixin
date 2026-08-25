#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct DurableAuthorityCapabilities {
    pub atomic_commit: bool,
    pub crash_recovery: bool,
    pub durable_flush: bool,
    pub single_writer_enforced: bool,
    pub rollback_supported: bool,
    pub snapshot_round_trip_verified: bool,
    pub mutation_parity_verified: bool,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CutoverRequirement {
    AtomicCommit,
    CrashRecovery,
    DurableFlush,
    SingleWriterEnforced,
    RollbackSupported,
    SnapshotRoundTripVerified,
    MutationParityVerified,
}

pub fn missing_cutover_requirements(
    capabilities: DurableAuthorityCapabilities,
) -> Vec<CutoverRequirement> {
    let mut missing = Vec::new();
    if !capabilities.atomic_commit {
        missing.push(CutoverRequirement::AtomicCommit);
    }
    if !capabilities.crash_recovery {
        missing.push(CutoverRequirement::CrashRecovery);
    }
    if !capabilities.durable_flush {
        missing.push(CutoverRequirement::DurableFlush);
    }
    if !capabilities.single_writer_enforced {
        missing.push(CutoverRequirement::SingleWriterEnforced);
    }
    if !capabilities.rollback_supported {
        missing.push(CutoverRequirement::RollbackSupported);
    }
    if !capabilities.snapshot_round_trip_verified {
        missing.push(CutoverRequirement::SnapshotRoundTripVerified);
    }
    if !capabilities.mutation_parity_verified {
        missing.push(CutoverRequirement::MutationParityVerified);
    }
    missing
}

pub fn is_cutover_ready(capabilities: DurableAuthorityCapabilities) -> bool {
    missing_cutover_requirements(capabilities).is_empty()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_candidate_is_not_cutover_ready() {
        let missing = missing_cutover_requirements(DurableAuthorityCapabilities::default());
        assert_eq!(missing.len(), 7);
        assert!(!is_cutover_ready(DurableAuthorityCapabilities::default()));
    }

    #[test]
    fn all_required_guarantees_are_needed_for_cutover() {
        let ready = DurableAuthorityCapabilities {
            atomic_commit: true,
            crash_recovery: true,
            durable_flush: true,
            single_writer_enforced: true,
            rollback_supported: true,
            snapshot_round_trip_verified: true,
            mutation_parity_verified: true,
        };
        assert!(is_cutover_ready(ready));
    }

    #[test]
    fn one_missing_guarantee_blocks_cutover() {
        let incomplete = DurableAuthorityCapabilities {
            atomic_commit: true,
            crash_recovery: true,
            durable_flush: true,
            single_writer_enforced: false,
            rollback_supported: true,
            snapshot_round_trip_verified: true,
            mutation_parity_verified: true,
        };
        assert_eq!(
            missing_cutover_requirements(incomplete),
            vec![CutoverRequirement::SingleWriterEnforced]
        );
    }
}
