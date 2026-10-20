use crate::sys;

impl<T> sys::Slice<T> {
    pub unsafe fn as_slice<'a>(&self) -> &'a [T] {
        let len = usize::try_from(self.len).expect("negative slice length");
        if len == 0 {
            &[]
        } else {
            unsafe { core::slice::from_raw_parts(self.data, len) }
        }
    }

    pub unsafe fn as_mut_slice<'a>(&mut self) -> &'a mut [T] {
        let len = usize::try_from(self.len).expect("negative slice length");
        if len == 0 {
            &mut []
        } else {
            unsafe { core::slice::from_raw_parts_mut(self.data, len) }
        }
    }

    pub fn cast<U>(self) -> sys::Slice<U> {
        sys::Slice {
            data: self.data.cast(),
            len: self.len,
        }
    }
}

impl<T> From<&[T]> for sys::Slice<T> {
    fn from(slice: &[T]) -> Self {
        Self {
            data: slice.as_ptr().cast_mut(),
            len: slice.len().try_into().expect("slice length overflow"),
        }
    }
}

impl<T> From<&mut [T]> for sys::Slice<T> {
    fn from(slice: &mut [T]) -> Self {
        Self {
            data: slice.as_mut_ptr(),
            len: slice.len().try_into().expect("slice length overflow"),
        }
    }
}

impl sys::String {
    pub unsafe fn as_bytes<'a>(&self) -> &'a [u8] {
        unsafe {
            sys::Slice {
                data: self.data,
                len: self.len,
            }
            .as_slice()
        }
    }

    pub unsafe fn as_str<'a>(&self) -> Result<&'a str, core::str::Utf8Error> {
        core::str::from_utf8(unsafe { self.as_bytes() })
    }
}

impl From<&str> for sys::String {
    fn from(text: &str) -> Self {
        Self {
            data: text.as_ptr().cast_mut(),
            len: text.len().try_into().expect("string length overflow"),
        }
    }
}

impl<T> sys::DynamicArray<T> {
    pub unsafe fn as_slice<'a>(&self) -> &'a [T] {
        unsafe {
            sys::Slice {
                data: self.data,
                len: self.len,
            }
            .as_slice()
        }
    }

    pub unsafe fn as_mut_slice<'a>(&mut self) -> &'a mut [T] {
        unsafe {
            sys::Slice {
                data: self.data,
                len: self.len,
            }
            .as_mut_slice()
        }
    }
}
