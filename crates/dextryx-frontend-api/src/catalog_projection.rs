use std::fs;
use std::path::{Path, PathBuf};

use dextryx_core::{
    AssetStorageMode, AuthoritativeCatalogProjection, CatalogAsset, ProjectionCatalogReadAdapter,
    WorkplaceSummary,
};

use crate::CatalogReadApplication;

pub const CATALOG_PROJECTION_SCHEMA_HEADER: &str = "DXTR_CATALOG_READ\t1";

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum CatalogProjectionReadError {
    Io(String),
    InvalidHeader,
    MalformedLine { line: usize },
    InvalidStorageMode { line: usize, value: String },
    InvalidMissingFlag { line: usize, value: String },
    InvalidImportSequence { line: usize, value: String },
    InvalidEscape { line: usize },
}

pub type ProjectionCatalogReadApplication = CatalogReadApplication<ProjectionCatalogReadAdapter>;

pub fn read_catalog_projection(
    path: &Path,
) -> Result<ProjectionCatalogReadApplication, CatalogProjectionReadError> {
    let content = fs::read_to_string(path)
        .map_err(|error| CatalogProjectionReadError::Io(error.to_string()))?;
    parse_catalog_projection(&content)
}

pub fn parse_catalog_projection(
    content: &str,
) -> Result<ProjectionCatalogReadApplication, CatalogProjectionReadError> {
    let mut lines = content.lines();
    if lines.next() != Some(CATALOG_PROJECTION_SCHEMA_HEADER) {
        return Err(CatalogProjectionReadError::InvalidHeader);
    }

    let mut projection = AuthoritativeCatalogProjection::default();

    for (index, raw_line) in lines.enumerate() {
        let line_number = index + 2;
        if raw_line.is_empty() {
            continue;
        }
        let fields: Vec<_> = raw_line.split('\t').collect();
        match fields.first().copied() {
            Some("ACTIVE") if fields.len() == 2 => {
                let active = unescape(fields[1], line_number)?;
                projection.active_workplace_id = (!active.is_empty()).then_some(active);
            }
            Some("WORKPLACE") if fields.len() == 3 => {
                projection.workplaces.push(WorkplaceSummary {
                    id: unescape(fields[1], line_number)?,
                    name: unescape(fields[2], line_number)?,
                });
            }
            Some("ASSET") if fields.len() == 8 => {
                let storage_mode = match fields[5] {
                    "linked" => AssetStorageMode::Linked,
                    "managed" => AssetStorageMode::Managed,
                    value => {
                        return Err(CatalogProjectionReadError::InvalidStorageMode {
                            line: line_number,
                            value: value.to_string(),
                        });
                    }
                };
                let missing = match fields[6] {
                    "0" => false,
                    "1" => true,
                    value => {
                        return Err(CatalogProjectionReadError::InvalidMissingFlag {
                            line: line_number,
                            value: value.to_string(),
                        });
                    }
                };
                let import_sequence = fields[7].parse::<u64>().map_err(|_| {
                    CatalogProjectionReadError::InvalidImportSequence {
                        line: line_number,
                        value: fields[7].to_string(),
                    }
                })?;
                let managed_path = unescape(fields[4], line_number)?;
                projection.assets.push(CatalogAsset {
                    id: unescape(fields[1], line_number)?,
                    workplace_id: unescape(fields[2], line_number)?,
                    source_path: PathBuf::from(unescape(fields[3], line_number)?),
                    managed_path: (!managed_path.is_empty()).then(|| PathBuf::from(managed_path)),
                    storage_mode,
                    missing,
                    import_sequence,
                });
            }
            _ => {
                return Err(CatalogProjectionReadError::MalformedLine { line: line_number });
            }
        }
    }

    Ok(CatalogReadApplication::new(
        ProjectionCatalogReadAdapter::new(projection),
    ))
}

fn unescape(value: &str, line: usize) -> Result<String, CatalogProjectionReadError> {
    let mut output = String::with_capacity(value.len());
    let mut chars = value.chars();
    while let Some(ch) = chars.next() {
        if ch != '\\' {
            output.push(ch);
            continue;
        }
        match chars.next() {
            Some('\\') => output.push('\\'),
            Some('t') => output.push('\t'),
            Some('n') => output.push('\n'),
            Some('r') => output.push('\r'),
            _ => return Err(CatalogProjectionReadError::InvalidEscape { line }),
        }
    }
    Ok(output)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{AssetQuery, AssetStorageDto};

    #[test]
    fn parses_flutter_projection_through_read_application() {
        let input = concat!(
            "DXTR_CATALOG_READ\t1\n",
            "ACTIVE\tworkplace-1\n",
            "WORKPLACE\tworkplace-1\tMy workplace\n",
            "ASSET\tasset-1\tworkplace-1\t/external/a.nef\t/managed/a.nef\tmanaged\t0\t42\n",
            "ASSET\tasset-2\tworkplace-1\t/external/missing.jpg\t\tlinked\t1\t43\n",
        );

        let app = parse_catalog_projection(input).expect("projection should parse");
        let workplaces = app.list_workplaces();
        assert_eq!(workplaces.len(), 1);
        assert!(workplaces[0].is_active);

        let assets = app
            .list_assets("workplace-1", AssetQuery::All)
            .expect("assets should be readable");
        assert_eq!(assets.len(), 2);
        assert_eq!(assets[0].id, "asset-1");
        assert_eq!(assets[0].storage, AssetStorageDto::Managed);
        assert_eq!(assets[0].effective_path, PathBuf::from("/managed/a.nef"));

        let missing = app
            .list_assets("workplace-1", AssetQuery::Missing)
            .expect("missing query should be readable");
        assert_eq!(missing.len(), 1);
        assert_eq!(missing[0].id, "asset-2");
    }

    #[test]
    fn rejects_unknown_snapshot_schema() {
        let error = parse_catalog_projection("DXTR_CATALOG_READ\t2\n")
            .expect_err("unknown schema must be rejected");
        assert_eq!(error, CatalogProjectionReadError::InvalidHeader);
    }

    #[test]
    fn unescapes_projection_fields() {
        let input = concat!(
            "DXTR_CATALOG_READ\t1\n",
            "ACTIVE\tworkplace-1\n",
            "WORKPLACE\tworkplace-1\tMy\\tworkplace\n",
        );

        let app = parse_catalog_projection(input).expect("projection should parse");
        assert_eq!(app.list_workplaces()[0].name, "My\tworkplace");
    }
}
