mod api;

use api::{DevelopSettings, ExportOptions};
use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int};
use std::ptr;
use std::sync::Mutex;

pub struct ImageBuffer {
    pub width: u32,
    pub height: u32,
    pub len: usize,
    pub data: Vec<u8>,
}

static LAST_ERROR: Mutex<String> = Mutex::new(String::new());

fn set_last_error(msg: impl Into<String>) {
    if let Ok(mut e) = LAST_ERROR.lock() { *e = msg.into(); }
}

fn cstr_to_string(ptr: *const c_char) -> Result<String, String> {
    if ptr.is_null() { return Err("Null C string pointer".into()); }
    let s = unsafe { CStr::from_ptr(ptr) };
    s.to_str().map(str::to_owned).map_err(|e| format!("Invalid UTF-8 path: {e}"))
}

fn string_to_c(s: String) -> *mut c_char {
    match CString::new(s) {
        Ok(v) => v.into_raw(),
        Err(_) => CString::new("String contained NUL").unwrap().into_raw(),
    }
}

fn into_buffer(img: api::DevelopedImage) -> *mut ImageBuffer {
    let len = img.data.len();
    Box::into_raw(Box::new(ImageBuffer { width: img.width, height: img.height, len, data: img.data }))
}

fn run_image<F>(f: F) -> *mut ImageBuffer where F: FnOnce() -> Result<api::DevelopedImage,String> {
    match std::panic::catch_unwind(std::panic::AssertUnwindSafe(f)) {
        Ok(Ok(img)) => into_buffer(img),
        Ok(Err(e)) => { set_last_error(e); ptr::null_mut() },
        Err(_) => { set_last_error("Rust panic caught at FFI boundary"); ptr::null_mut() },
    }
}

#[no_mangle]
pub extern "C" fn get_v7_version() -> *mut c_char { string_to_c("Nixin Studio raw-engine 8.0.0".into()) }

#[no_mangle]
pub extern "C" fn free_string_rust(s: *mut c_char) {
    if !s.is_null() { unsafe { drop(CString::from_raw(s)); } }
}

#[no_mangle]
pub extern "C" fn free_image_buffer(ptr: *mut ImageBuffer) {
    if !ptr.is_null() { unsafe { drop(Box::from_raw(ptr)); } }
}

#[no_mangle] pub extern "C" fn image_buffer_get_width(buf: *const ImageBuffer) -> u32 { if buf.is_null(){0}else{unsafe{(*buf).width}} }
#[no_mangle] pub extern "C" fn image_buffer_get_height(buf: *const ImageBuffer) -> u32 { if buf.is_null(){0}else{unsafe{(*buf).height}} }
#[no_mangle] pub extern "C" fn image_buffer_get_len(buf: *const ImageBuffer) -> usize { if buf.is_null(){0}else{unsafe{(*buf).len}} }
#[no_mangle] pub extern "C" fn image_buffer_get_data(buf: *const ImageBuffer) -> *const u8 { if buf.is_null(){ptr::null()}else{unsafe{(*buf).data.as_ptr()}} }

#[no_mangle]
pub extern "C" fn get_last_error() -> *mut c_char {
    let s = LAST_ERROR.lock().map(|e| e.clone()).unwrap_or_else(|_| "LAST_ERROR poisoned".into());
    string_to_c(s)
}

/// Checks only that the Rust library is loaded and its internal error mutex is usable.
/// It does not test RAW decoding, filesystem permissions, platform packaging, or GPU/AI features.
#[no_mangle]
pub extern "C" fn check_engine() -> c_int { if LAST_ERROR.lock().is_ok() { 1 } else { 0 } }

#[no_mangle]
pub extern "C" fn develop_raw(path: *const c_char) -> *mut ImageBuffer {
    let path = match cstr_to_string(path) { Ok(v)=>v,Err(e)=>{set_last_error(e);return ptr::null_mut();} };
    run_image(|| api::apply_develop_settings(path, DevelopSettings::default()))
}

#[no_mangle]
pub extern "C" fn detect_subject_mask(path:*const c_char,x:i32,y:i32,has_click:c_int)->*mut ImageBuffer {
    let path=match cstr_to_string(path){Ok(v)=>v,Err(e)=>{set_last_error(e);return ptr::null_mut();}};
    let click=if has_click!=0{Some((x,y))}else{None};
    run_image(|| api::detect_subject_mask_internal(path,click).map(|m|m.overlay))
}

#[no_mangle]
pub extern "C" fn detect_sky_mask_ffi(path:*const c_char)->*mut ImageBuffer {
    let path=match cstr_to_string(path){Ok(v)=>v,Err(e)=>{set_last_error(e);return ptr::null_mut();}};
    run_image(|| api::detect_sky_mask_internal(path).map(|m|m.overlay))
}

#[no_mangle]
pub extern "C" fn apply_lut_file(path:*const c_char,lut_path:*const c_char,strength:f32)->*mut ImageBuffer {
    let path=match cstr_to_string(path){Ok(v)=>v,Err(e)=>{set_last_error(e);return ptr::null_mut();}};
    let lut=match cstr_to_string(lut_path){Ok(v)=>v,Err(e)=>{set_last_error(e);return ptr::null_mut();}};
    run_image(|| api::apply_lut_internal(path,lut,strength))
}

#[no_mangle]
pub extern "C" fn export_jpeg_with_quality(path:*const c_char,dest:*const c_char,quality:u8)->*mut c_char {
    let path=match cstr_to_string(path){Ok(v)=>v,Err(e)=>{set_last_error(e);return ptr::null_mut();}};
    let dest=match cstr_to_string(dest){Ok(v)=>v,Err(e)=>{set_last_error(e);return ptr::null_mut();}};
    match api::export_developed_jpeg(path,dest,DevelopSettings::default(),ExportOptions{quality,..Default::default()}) {
        Ok(v)=>string_to_c(v), Err(e)=>{set_last_error(e);ptr::null_mut()}
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_ffi_buffer() {
        let img = api::DevelopedImage { width: 2, height: 1, data: vec![1,2,3,4,5,6,7,8] };
        let p = into_buffer(img);
        assert_eq!(image_buffer_get_width(p),2);
        assert_eq!(image_buffer_get_height(p),1);
        assert_eq!(image_buffer_get_len(p),8);
        assert!(!image_buffer_get_data(p).is_null());
        free_image_buffer(p);
    }
}
