#+build linux, amd64
#+private
package gpu

import "base:intrinsics"
import "core:sys/linux"

DRM_Command :: enum u32 {
	VERSION              = 0x00,
	GEM_CLOSE            = 0x09,
	I915_GETPARAM        = 0x46,
	I915_GEM_CREATE      = 0x5b,
	I915_GEM_SET_DOMAIN  = 0x5f,
	I915_GEM_MMAP_OFFSET = 0x64,
	I915_GEM_EXECBUFFER2 = 0x69,
	I915_GEM_WAIT        = 0x6c,
	I915_CONTEXT_CREATE  = 0x6d,
	I915_CONTEXT_DESTROY = 0x6e,
}

IOC_WRITE :: u32(1)
IOC_READ :: u32(2)

DRM_Version :: struct {
	major, minor, patch: i32,
	name_len:            u64,
	name:                u64,
	date_len, date:      u64,
	desc_len, desc:      u64,
}

I915_Getparam :: struct {
	param: i32,
	value: ^i32,
}

GEM_Create :: struct {
	size:   u64,
	handle: u32,
	pad:    u32,
}

GEM_Close :: struct {
	handle, pad: u32,
}

GEM_Mmap_Offset :: struct {
	handle, pad:               u32,
	offset, flags, extensions: u64,
}

GEM_Domain :: struct {
	handle, read_domains, write_domain: u32,
}

GEM_Context :: struct {
	id, pad: u32,
}

GEM_Wait :: struct {
	handle, flags: u32,
	timeout_ns:    i64,
}

GEM_Exec_Object :: struct {
	handle, relocation_count: u32,
	relocs_ptr:               u64,
	alignment:                u64,
	offset:                   u64,
	flags:                    u64,
	rsvd1, rsvd2:             u64,
}

GEM_Execbuffer :: struct {
	buffers_ptr:                        u64,
	buffer_count, batch_start_offset:   u32,
	batch_len, dr1, dr4, num_cliprects: u32,
	cliprects_ptr:                      u64,
	flags, context_id, rsvd2:           u64,
}

#assert(size_of(DRM_Version) == 64)
#assert(size_of(I915_Getparam) == 16)
#assert(size_of(GEM_Create) == 16)
#assert(size_of(GEM_Close) == 8)
#assert(size_of(GEM_Mmap_Offset) == 32)
#assert(size_of(GEM_Domain) == 12)
#assert(size_of(GEM_Context) == 8)
#assert(size_of(GEM_Wait) == 16)
#assert(size_of(GEM_Exec_Object) == 56)
#assert(size_of(GEM_Execbuffer) == 64)

EXEC_OBJECT_WRITE :: u64(1 << 2)
EXEC_OBJECT_SUPPORTS_48B :: u64(1 << 3)
EXEC_OBJECT_PINNED :: u64(1 << 4)
I915_EXEC_RENDER :: u64(1)
I915_EXEC_NO_RELOC :: u64(1 << 11)

drm_ioctl :: proc(
	fd: linux.Fd,
	command: DRM_Command,
	arg: ^$T,
	direction := IOC_READ | IOC_WRITE,
) -> Error {
	request :=
		direction << 30 | u32(size_of(T)) << 16 | u32('d') << 8 | u32(command)
	result := int(linux.ioctl(fd, request, uintptr(arg)))
	if result < 0 {
		return System_Error{"ioctl", linux.Errno(-result), request}
	}
	return nil
}

getparam :: proc(fd: linux.Fd, param: i32) -> (value: i32, error: Error) {
	request := I915_Getparam{param, &value}
	drm_ioctl(fd, .I915_GETPARAM, &request) or_return
	return value, nil
}

gem_create :: proc(fd: linux.Fd, size: u64) -> (handle: u32, error: Error) {
	request := GEM_Create {
		size = size,
	}
	drm_ioctl(fd, .I915_GEM_CREATE, &request) or_return
	return request.handle, nil
}

gem_close :: proc(fd: linux.Fd, handle: u32) {
	request := GEM_Close {
		handle = handle,
	}
	drm_ioctl(fd, .GEM_CLOSE, &request, IOC_WRITE)
}

GEM_Buffer :: struct {
	handle: u32,
	words:  []u32,
}

gem_buffer_create :: proc(
	fd: linux.Fd,
	bytes: int,
) -> (
	buffer: GEM_Buffer,
	error: Error,
) {
	I915_MMAP_OFFSET_WC :: 1
	handle := gem_create(fd, u64(bytes)) or_return
	keep := false
	defer if !keep do gem_close(fd, handle)
	request := GEM_Mmap_Offset {
		handle = handle,
		flags  = I915_MMAP_OFFSET_WC,
	}
	drm_ioctl(fd, .I915_GEM_MMAP_OFFSET, &request) or_return
	address, err := linux.mmap(
		0,
		uint(bytes),
		{.READ, .WRITE},
		{.SHARED},
		fd,
		i64(request.offset),
	)
	if err != .NONE {
		return {}, System_Error{"mmap", err, 0}
	}
	defer if !keep do linux.munmap(address, uint(bytes))
	gem_set_domain(fd, handle, true) or_return
	keep = true
	return {handle, ([^]u32)(address)[:bytes / size_of(u32)]}, nil
}

gem_set_domain :: proc(fd: linux.Fd, handle: u32, write: bool) -> Error {
	I915_GEM_DOMAIN_WC :: 0x80
	domain := GEM_Domain {
		handle       = handle,
		read_domains = I915_GEM_DOMAIN_WC,
	}
	if write do domain.write_domain = I915_GEM_DOMAIN_WC
	return drm_ioctl(fd, .I915_GEM_SET_DOMAIN, &domain, IOC_WRITE)
}

gem_buffer_destroy :: proc(fd: linux.Fd, buffer: GEM_Buffer) {
	linux.munmap(raw_data(buffer.words), uint(len(buffer.words) * size_of(u32)))
	gem_close(fd, buffer.handle)
}

flush_cpu_writes :: proc() {
	// Release fences alone do not drain x86 write-combining buffers.
	intrinsics.atomic_thread_fence(.Seq_Cst)
}
