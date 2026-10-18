use core::{
    mem::MaybeUninit,
    ops::{Deref, DerefMut},
};

#[repr(C)]
#[derive(Clone, Copy)]
pub struct FixedCapDynArray<const LEN: usize, T: Copy> {
    data: [MaybeUninit<T>; LEN],
    len: isize,
}

impl<const LEN: usize, T: Copy> FixedCapDynArray<LEN, T> {
    pub const fn new() -> Self {
        assert!(LEN <= isize::MAX as usize);
        Self {
            data: [MaybeUninit::uninit(); LEN],
            len: 0,
        }
    }

    pub fn len(&self) -> usize {
        assert!(self.len >= 0 && self.len as usize <= LEN);
        self.len as usize
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }

    pub fn push(&mut self, value: T) {
        let len = self.len();
        assert!(len < LEN, "fixed-capacity array is full");
        self.data[len].write(value);
        self.len += 1;
    }

    pub fn pop(&mut self) -> Option<T> {
        let len = self.len().checked_sub(1)?;
        self.len = len as isize;
        Some(unsafe { self.data[len].assume_init() })
    }

    pub fn clear(&mut self) {
        self.len = 0;
    }

    pub fn as_slice(&self) -> &[T] {
        unsafe { core::slice::from_raw_parts(self.data.as_ptr().cast(), self.len()) }
    }

    pub fn as_mut_slice(&mut self) -> &mut [T] {
        let len = self.len();
        unsafe { core::slice::from_raw_parts_mut(self.data.as_mut_ptr().cast(), len) }
    }
}

impl<const LEN: usize, T: Copy> Default for FixedCapDynArray<LEN, T> {
    fn default() -> Self {
        Self::new()
    }
}

impl<const LEN: usize, T: Copy, const N: usize> From<[T; N]> for FixedCapDynArray<LEN, T> {
    fn from(values: [T; N]) -> Self {
        assert!(N <= LEN, "too many elements for fixed-capacity array");
        let mut result = Self::new();
        for value in values {
            result.push(value);
        }
        result
    }
}

impl<const LEN: usize, T: Copy> Deref for FixedCapDynArray<LEN, T> {
    type Target = [T];

    fn deref(&self) -> &Self::Target {
        self.as_slice()
    }
}

impl<const LEN: usize, T: Copy> DerefMut for FixedCapDynArray<LEN, T> {
    fn deref_mut(&mut self) -> &mut Self::Target {
        self.as_mut_slice()
    }
}
