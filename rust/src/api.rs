use image::codecs::jpeg::JpegEncoder;
use image::{
    DynamicImage, ExtendedColorType, GenericImageView, ImageDecoder, ImageEncoder, ImageReader,
    RgbaImage,
};
use serde::{Deserialize, Serialize};
use std::collections::VecDeque;
use std::fs::{self, File};
use std::io::Write;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct DevelopSettings {
    pub exposure: f32,
    pub temperature: f32,
    pub contrast: f32,
}

impl Default for DevelopSettings {
    fn default() -> Self {
        Self {
            exposure: 0.0,
            temperature: 0.0,
            contrast: 1.0,
        }
    }
}

#[derive(Debug, Clone)]
pub struct DevelopedImage {
    pub width: u32,
    pub height: u32,
    pub data: Vec<u8>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExportOptions {
    pub quality: u8,
    pub rating: Option<i32>,
    pub label: Option<String>,
}

impl Default for ExportOptions {
    fn default() -> Self {
        Self {
            quality: 90,
            rating: None,
            label: None,
        }
    }
}

#[derive(Debug, Clone)]
pub struct MaskResult {
    pub overlay: DevelopedImage,
    pub mask: Vec<u8>,
}

#[derive(Debug, Clone)]
pub struct Lut3D {
    pub title: Option<String>,
    pub size: usize,
    pub domain_min: [f32; 3],
    pub domain_max: [f32; 3],
    pub data: Vec<[f32; 3]>,
}

/// Loads a standard raster image and normalizes its EXIF orientation before it
/// enters the editing pipeline. RAW containers fall back to the embedded-JPEG
/// preview path; V8 still does not debayer sensor RAW data.
pub fn load_embedded_preview(path: &str) -> Result<DynamicImage, String> {
    let source = Path::new(path);
    if let Ok(reader) = ImageReader::open(source) {
        if let Ok(reader) = reader.with_guessed_format() {
            if let Ok(mut decoder) = reader.into_decoder() {
                let orientation = decoder
                    .orientation()
                    .unwrap_or(image::metadata::Orientation::NoTransforms);
                if let Ok(mut image) = DynamicImage::from_decoder(decoder) {
                    image.apply_orientation(orientation);
                    return Ok(image);
                }
            }
        }
    }

    let bytes = fs::read(source).map_err(|e| format!("Image file read failed: {e}"))?;
    extract_best_embedded_jpeg(&bytes)
        .map_err(|e| format!("Unsupported image or RAW preview: {e}"))
}

fn extract_best_embedded_jpeg(bytes: &[u8]) -> Result<DynamicImage, String> {
    let mut starts = Vec::new();
    let mut i = 0usize;
    while i + 1 < bytes.len() {
        if bytes[i] == 0xFF && bytes[i + 1] == 0xD8 {
            starts.push(i);
        }
        i += 1;
    }
    if starts.is_empty() {
        return Err("No embedded JPEG start marker found".into());
    }

    let mut best: Option<(u64, DynamicImage)> = None;
    for start in starts {
        let mut j = start + 2;
        while j + 1 < bytes.len() {
            if bytes[j] == 0xFF && bytes[j + 1] == 0xD9 {
                let candidate = &bytes[start..=j + 1];
                if let Ok(img) =
                    image::load_from_memory_with_format(candidate, image::ImageFormat::Jpeg)
                {
                    let (w, h) = img.dimensions();
                    let area = (w as u64) * (h as u64);
                    if best.as_ref().map(|(a, _)| area > *a).unwrap_or(true) {
                        best = Some((area, img));
                    }
                }
                break;
            }
            j += 1;
        }
    }
    best.map(|(_, img)| img)
        .ok_or_else(|| "Embedded JPEG markers found, but none decoded".into())
}

pub fn apply_develop_settings(
    path: String,
    settings: DevelopSettings,
) -> Result<DevelopedImage, String> {
    let mut rgba = load_embedded_preview(&path)?.to_rgba8();
    apply_settings_to_rgba(&mut rgba, settings)?;
    Ok(from_rgba(rgba))
}

fn apply_settings_to_rgba(img: &mut RgbaImage, settings: DevelopSettings) -> Result<(), String> {
    if !settings.exposure.is_finite()
        || !settings.temperature.is_finite()
        || !settings.contrast.is_finite()
    {
        return Err("Develop settings must be finite".into());
    }
    let exposure_gain = 2.0_f32.powf(settings.exposure.clamp(-8.0, 8.0));
    let t = settings.temperature.clamp(-1.0, 1.0);
    let r_scale = 1.0 + 0.20 * t;
    let b_scale = 1.0 - 0.20 * t;
    let contrast = settings.contrast.clamp(0.0, 4.0);

    for p in img.pixels_mut() {
        let mut rgb = [p[0] as f32, p[1] as f32, p[2] as f32];
        rgb[0] *= exposure_gain * r_scale;
        rgb[1] *= exposure_gain;
        rgb[2] *= exposure_gain * b_scale;
        for c in &mut rgb {
            *c = ((*c - 128.0) * contrast + 128.0).clamp(0.0, 255.0);
        }
        p[0] = rgb[0].round() as u8;
        p[1] = rgb[1].round() as u8;
        p[2] = rgb[2].round() as u8;
    }
    Ok(())
}

pub fn detect_subject_mask_internal(
    path: String,
    click: Option<(i32, i32)>,
) -> Result<MaskResult, String> {
    let rgba = load_embedded_preview(&path)?.to_rgba8();
    let (w, h) = rgba.dimensions();
    let mut mask = vec![0u8; (w as usize) * (h as usize)];

    if let Some((x, y)) = click {
        if x < 0 || y < 0 || x >= w as i32 || y >= h as i32 {
            return Err("Click outside".into());
        }
        let seed = rgba.get_pixel(x as u32, y as u32).0;
        let mut visited = vec![false; mask.len()];
        let mut stack = vec![(x as u32, y as u32)];
        while let Some((cx, cy)) = stack.pop() {
            let idx = (cy * w + cx) as usize;
            if visited[idx] {
                continue;
            }
            visited[idx] = true;
            let p = rgba.get_pixel(cx, cy).0;
            let d = (p[0] as i32 - seed[0] as i32).abs()
                + (p[1] as i32 - seed[1] as i32).abs()
                + (p[2] as i32 - seed[2] as i32).abs();
            if d >= 70 {
                continue;
            }
            mask[idx] = 255;
            if cx > 0 {
                stack.push((cx - 1, cy));
            }
            if cx + 1 < w {
                stack.push((cx + 1, cy));
            }
            if cy > 0 {
                stack.push((cx, cy - 1));
            }
            if cy + 1 < h {
                stack.push((cx, cy + 1));
            }
        }
    } else {
        let mut border_sum = 0u64;
        let mut border_count = 0u64;
        for x in 0..w {
            for &y in &[0, h.saturating_sub(1)] {
                let p = rgba.get_pixel(x, y).0;
                border_sum += brightness(p) as u64;
                border_count += 1;
            }
        }
        for y in 1..h.saturating_sub(1) {
            for &x in &[0, w.saturating_sub(1)] {
                let p = rgba.get_pixel(x, y).0;
                border_sum += brightness(p) as u64;
                border_count += 1;
            }
        }
        let border_avg = if border_count == 0 {
            0.0
        } else {
            border_sum as f32 / border_count as f32
        };
        for y in 0..h {
            for x in 0..w {
                let b = brightness(rgba.get_pixel(x, y).0) as f32;
                if (b - border_avg).abs() > 22.0 {
                    mask[(y * w + x) as usize] = 255;
                }
            }
        }
    }

    Ok(MaskResult {
        overlay: mask_overlay(&rgba, &mask, [255, 70, 90]),
        mask,
    })
}

pub fn detect_sky_mask_internal(path: String) -> Result<MaskResult, String> {
    let rgba = load_embedded_preview(&path)?.to_rgba8();
    let (w, h) = rgba.dimensions();
    let mut candidate = vec![false; (w as usize) * (h as usize)];
    for y in 0..h {
        let vertical_prior = if h <= 1 {
            1.0
        } else {
            1.0 - 0.8 * (y as f32 / (h - 1) as f32)
        };
        for x in 0..w {
            let p = rgba.get_pixel(x, y).0;
            let r = p[0] as f32;
            let g = p[1] as f32;
            let b = p[2] as f32;
            let avg = (r + g + b) / 3.0;
            let sat = r.max(g).max(b) - r.min(g).min(b);
            let blue = b > r * 1.05 && b > g * 0.95 && b > 80.0;
            let overcast = avg > 150.0 && sat < 20.0;
            candidate[(y * w + x) as usize] = (blue || overcast) && vertical_prior >= 0.35;
        }
    }

    let mut mask = vec![0u8; candidate.len()];
    let mut q: VecDeque<(u32, u32)> = VecDeque::new();
    if h > 0 {
        for x in 0..w {
            let idx = x as usize;
            if candidate[idx] {
                mask[idx] = 255;
                q.push_back((x, 0u32));
            }
        }
    }
    while let Some((x, y)) = q.pop_front() {
        if x > 0 {
            enqueue_sky_neighbor(x - 1, y, w, h, &candidate, &mut mask, &mut q);
        }
        if let Some(nx) = x.checked_add(1) {
            enqueue_sky_neighbor(nx, y, w, h, &candidate, &mut mask, &mut q);
        }
        if y > 0 {
            enqueue_sky_neighbor(x, y - 1, w, h, &candidate, &mut mask, &mut q);
        }
        if let Some(ny) = y.checked_add(1) {
            enqueue_sky_neighbor(x, ny, w, h, &candidate, &mut mask, &mut q);
        }
    }
    Ok(MaskResult {
        overlay: mask_overlay(&rgba, &mask, [60, 160, 255]),
        mask,
    })
}

fn enqueue_sky_neighbor(
    x: u32,
    y: u32,
    w: u32,
    h: u32,
    candidate: &[bool],
    mask: &mut [u8],
    q: &mut VecDeque<(u32, u32)>,
) {
    if x >= w || y >= h {
        return;
    }
    let idx = (y * w + x) as usize;
    if candidate.get(idx).copied().unwrap_or(false) && mask.get(idx).copied().unwrap_or(0) == 0 {
        mask[idx] = 255;
        q.push_back((x, y));
    }
}

pub fn apply_lut_internal(
    path: String,
    lut_path: String,
    strength: f32,
) -> Result<DevelopedImage, String> {
    if !strength.is_finite() {
        return Err("LUT strength must be finite".into());
    }
    let strength = strength.clamp(0.0, 1.0);
    let lut =
        parse_cube(&fs::read_to_string(&lut_path).map_err(|e| format!("LUT read failed: {e}"))?)?;
    let mut rgba = load_embedded_preview(&path)?.to_rgba8();
    for p in rgba.pixels_mut() {
        let src = [
            p[0] as f32 / 255.0,
            p[1] as f32 / 255.0,
            p[2] as f32 / 255.0,
        ];
        let mapped = sample_lut_trilinear(&lut, src)?;
        for c in 0..3 {
            let v = src[c] * (1.0 - strength) + mapped[c] * strength;
            p[c] = (v.clamp(0.0, 1.0) * 255.0).round() as u8;
        }
    }
    Ok(from_rgba(rgba))
}

pub fn parse_cube(text: &str) -> Result<Lut3D, String> {
    let mut title = None;
    let mut size = None;
    let mut domain_min = [0.0, 0.0, 0.0];
    let mut domain_max = [1.0, 1.0, 1.0];
    let mut data = Vec::new();

    for raw in text.lines() {
        let line = raw.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if let Some(rest) = line.strip_prefix("TITLE") {
            let value = rest.trim();
            title = Some(value.trim_matches('"').to_string());
            continue;
        }
        if let Some(rest) = line.strip_prefix("LUT_3D_SIZE") {
            size = Some(
                rest.trim()
                    .parse::<usize>()
                    .map_err(|_| "Invalid LUT_3D_SIZE")?,
            );
            continue;
        }
        if let Some(rest) = line.strip_prefix("DOMAIN_MIN") {
            domain_min = parse_triplet(rest)?;
            continue;
        }
        if let Some(rest) = line.strip_prefix("DOMAIN_MAX") {
            domain_max = parse_triplet(rest)?;
            continue;
        }
        let parts: Vec<_> = line.split_whitespace().collect();
        if parts.len() == 3 {
            let vals = [
                parts[0].parse::<f32>().map_err(|_| "Invalid LUT value")?,
                parts[1].parse::<f32>().map_err(|_| "Invalid LUT value")?,
                parts[2].parse::<f32>().map_err(|_| "Invalid LUT value")?,
            ];
            if vals.iter().any(|v| !v.is_finite()) {
                return Err("Non-finite LUT value".into());
            }
            data.push(vals);
        }
    }
    let size = size.ok_or("Missing LUT_3D_SIZE")?;
    if size < 2 {
        return Err("LUT_3D_SIZE must be >= 2".into());
    }
    let expected = size
        .checked_mul(size)
        .and_then(|v| v.checked_mul(size))
        .ok_or("LUT size overflow")?;
    if data.len() != expected {
        return Err(format!(
            "LUT data length {} != size^3 {}",
            data.len(),
            expected
        ));
    }
    Ok(Lut3D {
        title,
        size,
        domain_min,
        domain_max,
        data,
    })
}

fn parse_triplet(rest: &str) -> Result<[f32; 3], String> {
    let v: Vec<_> = rest.split_whitespace().collect();
    if v.len() != 3 {
        return Err("Expected 3 values".into());
    }
    Ok([
        v[0].parse().map_err(|_| "Invalid triplet")?,
        v[1].parse().map_err(|_| "Invalid triplet")?,
        v[2].parse().map_err(|_| "Invalid triplet")?,
    ])
}

pub fn sample_lut_trilinear(lut: &Lut3D, rgb: [f32; 3]) -> Result<[f32; 3], String> {
    if rgb.iter().any(|v| !v.is_finite()) {
        return Err("Non-finite LUT input".into());
    }
    let n = lut.size as f32 - 1.0;
    let x = rgb[0].clamp(0.0, 1.0) * n;
    let y = rgb[1].clamp(0.0, 1.0) * n;
    let z = rgb[2].clamp(0.0, 1.0) * n;
    let r0 = x.floor() as usize;
    let r1 = (r0 + 1).min(lut.size - 1);
    let rd = x - r0 as f32;
    let g0 = y.floor() as usize;
    let g1 = (g0 + 1).min(lut.size - 1);
    let gd = y - g0 as f32;
    let b0 = z.floor() as usize;
    let b1 = (b0 + 1).min(lut.size - 1);
    let bd = z - b0 as f32;
    let at = |r: usize, g: usize, b: usize| lut.data[r + g * lut.size + b * lut.size * lut.size];
    let c000 = at(r0, g0, b0);
    let c100 = at(r1, g0, b0);
    let c010 = at(r0, g1, b0);
    let c110 = at(r1, g1, b0);
    let c001 = at(r0, g0, b1);
    let c101 = at(r1, g0, b1);
    let c011 = at(r0, g1, b1);
    let c111 = at(r1, g1, b1);
    let c00 = lerp3(c000, c100, rd);
    let c10 = lerp3(c010, c110, rd);
    let c01 = lerp3(c001, c101, rd);
    let c11 = lerp3(c011, c111, rd);
    let c0 = lerp3(c00, c10, gd);
    let c1 = lerp3(c01, c11, gd);
    Ok(lerp3(c0, c1, bd))
}

fn lerp3(a: [f32; 3], b: [f32; 3], t: f32) -> [f32; 3] {
    [
        a[0] + (b[0] - a[0]) * t,
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
    ]
}

pub fn export_developed_jpeg(
    path: String,
    dest: String,
    settings: DevelopSettings,
    options: ExportOptions,
) -> Result<String, String> {
    let developed = apply_develop_settings(path, settings)?;
    let quality = options.quality.clamp(1, 100);
    let file = File::create(&dest).map_err(|e| format!("Create JPEG failed: {e}"))?;
    let encoder = JpegEncoder::new_with_quality(file, quality);
    let rgb = rgba_to_rgb(&developed.data);
    encoder
        .write_image(
            &rgb,
            developed.width,
            developed.height,
            ExtendedColorType::Rgb8,
        )
        .map_err(|e| format!("JPEG encode failed: {e}"))?;

    if options.rating.is_some() || options.label.is_some() {
        let xmp = build_xmp(options.rating, options.label.as_deref());
        let sidecar = format!("{dest}.xmp");
        let mut f = File::create(&sidecar).map_err(|e| format!("Create XMP failed: {e}"))?;
        f.write_all(xmp.as_bytes())
            .map_err(|e| format!("Write XMP failed: {e}"))?;
    }
    Ok(dest)
}

pub fn build_xmp(rating: Option<i32>, label: Option<&str>) -> String {
    let rating_attr = rating
        .map(|v| format!(" xmp:Rating=\"{}\"", v))
        .unwrap_or_default();
    let label_attr = label
        .map(|v| format!(" xmp:Label=\"{}\"", xml_escape(v)))
        .unwrap_or_default();
    format!("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<x:xmpmeta xmlns:x=\"adobe:ns:meta/\">\n <rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\">\n  <rdf:Description xmlns:xmp=\"http://ns.adobe.com/xap/1.0/\"{rating_attr}{label_attr}/>\n </rdf:RDF>\n</x:xmpmeta>\n")
}

pub fn xml_escape(s: &str) -> String {
    s.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&apos;")
}

pub struct TetheredWatcher {
    pub watch_folder: PathBuf,
}
impl TetheredWatcher {
    pub fn check_new_files(&self, known: &[String]) -> Vec<String> {
        let known: std::collections::HashSet<&str> = known.iter().map(String::as_str).collect();
        let mut out = Vec::new();
        if let Ok(read) = fs::read_dir(&self.watch_folder) {
            for e in read.flatten() {
                if let Some(s) = e.path().to_str() {
                    if !known.contains(s) {
                        out.push(s.to_string());
                    }
                }
            }
        }
        out.sort();
        out
    }
}

fn from_rgba(img: RgbaImage) -> DevelopedImage {
    let (width, height) = img.dimensions();
    DevelopedImage {
        width,
        height,
        data: img.into_raw(),
    }
}
fn brightness(p: [u8; 4]) -> u8 {
    ((p[0] as u16 + p[1] as u16 + p[2] as u16) / 3) as u8
}
fn mask_overlay(base: &RgbaImage, mask: &[u8], color: [u8; 3]) -> DevelopedImage {
    let (w, h) = base.dimensions();
    let mut out = base.clone();
    for (i, p) in out.pixels_mut().enumerate() {
        if mask.get(i).copied().unwrap_or(0) > 0 {
            p[0] = ((p[0] as u16 + color[0] as u16) / 2) as u8;
            p[1] = ((p[1] as u16 + color[1] as u16) / 2) as u8;
            p[2] = ((p[2] as u16 + color[2] as u16) / 2) as u8;
            p[3] = 255;
        }
    }
    DevelopedImage {
        width: w,
        height: h,
        data: out.into_raw(),
    }
}
fn rgba_to_rgb(rgba: &[u8]) -> Vec<u8> {
    rgba.chunks_exact(4)
        .flat_map(|p| [p[0], p[1], p[2]])
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use image::{metadata::Orientation, ImageBuffer as ImgBuf, Rgba};
    use std::time::{SystemTime, UNIX_EPOCH};

    fn tmp(name: &str, ext: &str) -> String {
        let n = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        std::env::temp_dir()
            .join(format!("nixin-{name}-{n}.{ext}"))
            .to_string_lossy()
            .to_string()
    }
    fn identity_cube(size: usize) -> String {
        let mut s = format!("TITLE \"Identity\"\nLUT_3D_SIZE {size}\n");
        for b in 0..size {
            for g in 0..size {
                for r in 0..size {
                    let d = (size - 1) as f32;
                    s.push_str(&format!(
                        "{} {} {}\n",
                        r as f32 / d,
                        g as f32 / d,
                        b as f32 / d
                    ));
                }
            }
        }
        s
    }
    fn exif_orientation_chunk(orientation: Orientation) -> Vec<u8> {
        let value = orientation.to_exif();
        vec![
            b'I', b'I', 42, 0, 8, 0, 0, 0, 1, 0, 0x12, 0x01, 3, 0, 1, 0, 0, 0, value, 0, 0, 0, 0,
            0, 0, 0,
        ]
    }

    #[test]
    fn test_lut_identity() {
        let lut = parse_cube(&identity_cube(2)).unwrap();
        let v = sample_lut_trilinear(&lut, [0.25, 0.5, 0.75]).unwrap();
        assert!(
            (v[0] - 0.25).abs() < 1e-5 && (v[1] - 0.5).abs() < 1e-5 && (v[2] - 0.75).abs() < 1e-5
        );
    }
    #[test]
    fn test_lut_trilinear() {
        let lut = parse_cube(&identity_cube(2)).unwrap();
        let v = sample_lut_trilinear(&lut, [0.5, 0.5, 0.5]).unwrap();
        assert_eq!([0.5, 0.5, 0.5], v);
    }
    #[test]
    fn test_xmp_escape() {
        assert_eq!(xml_escape("<&>\"'"), "&lt;&amp;&gt;&quot;&apos;");
        let x = build_xmp(Some(5), Some("A&B"));
        assert!(x.contains("xmp:Rating=\"5\"") && x.contains("A&amp;B"));
    }
    #[test]
    fn test_jpeg_quality() {
        let rgba = ImgBuf::from_pixel(8, 8, Rgba([120u8, 80, 30, 255]));
        let d = tmp("q", "jpg");
        let f = File::create(&d).unwrap();
        JpegEncoder::new_with_quality(f, 90)
            .write_image(
                &rgba_to_rgb(&rgba.into_raw()),
                8,
                8,
                ExtendedColorType::Rgb8,
            )
            .unwrap();
        assert!(fs::metadata(&d).unwrap().len() > 0);
        let _ = fs::remove_file(d);
    }
    #[test]
    fn test_standard_png_input() {
        let rgba = ImgBuf::from_pixel(4, 3, Rgba([10u8, 20, 30, 255]));
        let d = tmp("source", "png");
        rgba.save(&d).unwrap();
        let loaded = load_embedded_preview(&d).unwrap();
        assert_eq!(loaded.dimensions(), (4, 3));
        let _ = fs::remove_file(d);
    }
    #[test]
    fn test_standard_jpeg_applies_exif_orientation() {
        let rgba = ImgBuf::from_pixel(2, 3, Rgba([40u8, 80, 120, 255]));
        let d = tmp("oriented", "jpg");
        let f = File::create(&d).unwrap();
        let mut encoder = JpegEncoder::new_with_quality(f, 100);
        encoder
            .set_exif_metadata(exif_orientation_chunk(Orientation::Rotate90))
            .unwrap();
        encoder
            .write_image(
                &rgba_to_rgb(&rgba.into_raw()),
                2,
                3,
                ExtendedColorType::Rgb8,
            )
            .unwrap();
        let loaded = load_embedded_preview(&d).unwrap();
        assert_eq!(loaded.dimensions(), (3, 2));
        let _ = fs::remove_file(d);
    }
    #[test]
    fn test_subject_oob() {
        let w = 2u32;
        let h = 2u32;
        let x = -1;
        let y = 0;
        assert!(x < 0 || y < 0 || x >= w as i32 || y >= h as i32);
    }
}
