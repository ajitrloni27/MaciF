use std::ffi::{CStr, CString};
use std::os::raw::c_char;

#[no_mangle]
pub extern "C" fn cih_chunk_text(input: *const c_char, chunk_size: i32) -> *mut c_char {
    if input.is_null() || chunk_size <= 0 {
        return std::ptr::null_mut();
    }

    let c_str = unsafe { CStr::from_ptr(input) };
    let input_str = match c_str.to_str() {
        Ok(value) => value,
        Err(_) => return std::ptr::null_mut(),
    };

    if input_str.is_empty() {
        return std::ptr::null_mut();
    }

    let mut chunks = Vec::new();
    let size = chunk_size as usize;
    let bytes = input_str.as_bytes();
    let mut offset = 0usize;

    while offset < bytes.len() {
        let end = (offset + size).min(bytes.len());
        chunks.push(&input_str[offset..end]);
        offset = end;
    }

    let payload = serde_json::to_string(&chunks).unwrap_or_else(|_| "[]".to_string());
    CString::new(payload).unwrap_or_else(|_| CString::new("[]").unwrap()).into_raw()
}
