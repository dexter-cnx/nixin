use dextryx_core::CatalogMutationError;

/// Deterministic checkpoints around catalog snapshot persistence.
///
/// These points are qualification seams only. Reaching a checkpoint does not
/// imply that the corresponding filesystem operation is atomic or durable.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub enum PersistenceFaultPoint {
    BeforeTempCreate,
    AfterTempCreate,
    AfterSnapshotWrite,
    BeforeFileSync,
    AfterFileSync,
    BeforeDestinationReplace,
    AfterDestinationRemoved,
    AfterDestinationRename,
}

/// Qualification hook for deterministic persistence-failure tests.
///
/// Production persistence code should default to a no-op injector. Tests may
/// inject one typed persistence failure at a specific checkpoint and then
/// verify the on-disk snapshot and in-memory publication semantics after the
/// failed operation.
pub trait PersistenceFaultInjector {
    fn check(&mut self, point: PersistenceFaultPoint) -> Result<(), CatalogMutationError>;
}

#[derive(Clone, Copy, Debug, Default)]
pub struct NoPersistenceFaults;

impl PersistenceFaultInjector for NoPersistenceFaults {
    fn check(&mut self, _point: PersistenceFaultPoint) -> Result<(), CatalogMutationError> {
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    struct FailOnceAt {
        point: PersistenceFaultPoint,
        fired: bool,
    }

    impl PersistenceFaultInjector for FailOnceAt {
        fn check(&mut self, point: PersistenceFaultPoint) -> Result<(), CatalogMutationError> {
            if point == self.point && !self.fired {
                self.fired = true;
                return Err(CatalogMutationError::Persistence(format!(
                    "injected fault at {point:?}"
                )));
            }
            Ok(())
        }
    }

    #[test]
    fn no_faults_allows_every_checkpoint() {
        let mut injector = NoPersistenceFaults;
        for point in [
            PersistenceFaultPoint::BeforeTempCreate,
            PersistenceFaultPoint::AfterTempCreate,
            PersistenceFaultPoint::AfterSnapshotWrite,
            PersistenceFaultPoint::BeforeFileSync,
            PersistenceFaultPoint::AfterFileSync,
            PersistenceFaultPoint::BeforeDestinationReplace,
            PersistenceFaultPoint::AfterDestinationRemoved,
            PersistenceFaultPoint::AfterDestinationRename,
        ] {
            assert_eq!(injector.check(point), Ok(()));
        }
    }

    #[test]
    fn injected_fault_is_deterministic_and_one_shot() {
        let mut injector = FailOnceAt {
            point: PersistenceFaultPoint::BeforeFileSync,
            fired: false,
        };

        assert_eq!(
            injector.check(PersistenceFaultPoint::AfterSnapshotWrite),
            Ok(())
        );
        assert_eq!(
            injector.check(PersistenceFaultPoint::BeforeFileSync),
            Err(CatalogMutationError::Persistence(
                "injected fault at BeforeFileSync".to_string()
            ))
        );
        assert_eq!(
            injector.check(PersistenceFaultPoint::BeforeFileSync),
            Ok(())
        );
    }
}
