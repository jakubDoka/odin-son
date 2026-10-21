#define _POSIX_C_SOURCE 200809L
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
extern int32_t trueos_main(size_t, char **);
void trueos_cabi_poll_once(void);
static size_t guest_allocations;
void *trueos_cabi_alloc(size_t n) { void *p = malloc(n); if (p) ++guest_allocations; return p; }
void *trueos_cabi_calloc(size_t n, size_t s) { void *p = calloc(n, s); if (p) ++guest_allocations; return p; }
void *trueos_cabi_realloc(void *p, size_t n) { void *q = realloc(p, n); if (!p && q) ++guest_allocations; else if (p && !n) --guest_allocations; return q; }
void trueos_cabi_free(void *p) { if (p) { assert(guest_allocations); --guest_allocations; } free(p); }
void *sys_alloc_aligned(size_t n, size_t a) { void *p = NULL; if (posix_memalign(&p, a, n)) return NULL; ++guest_allocations; return p; }
void trueos_cabi_write(uint32_t s, const void *p, size_t n) {
    if (getenv("TRUEOS_TEST_LINE_WRITES") && n >= 9 &&
        (!memcmp(p, "odin-son:", 9) || !memcmp(p, "[odin-son", 9))) {
        assert(((const char *)p)[n-1] == '\n');
    }
    fwrite(p, 1, n, s == 2 ? stderr : stdout);
}
int32_t trueos_cabi_blueprint_stop_control_v1(uint32_t op) { return 0; }
int32_t trueos_cabi_blueprint_shutdown(const void *p, size_t n) { return 0; }

typedef struct {
    uint32_t id;
    int kind, committed, ready, error, ticks;
    char path[4096];
    unsigned char *bytes;
    size_t size, offset;
} Operation;
static Operation operations[32];
static uint32_t next_id;
static size_t live, polls, discarded;
static int terminal_released;
int32_t trueos_cabi_blueprint_terminal_lease_current_v1(uint64_t ready, uint64_t *epoch) {
    assert(getenv("TRUEOS_TEST_TUI_KEYS")); assert(!terminal_released); *epoch = 1; return 0;
}
int32_t trueos_cabi_blueprint_terminal_lease_release_v1(uint64_t epoch, uint64_t *ticket) {
    assert(epoch == 1 && !terminal_released); terminal_released = 1; *ticket = 1; return 0;
}
int32_t trueos_cabi_blueprint_terminal_surface_snapshot_v1(uint64_t *gen, uint32_t *cols, uint32_t *rows) {
    static size_t calls;
    ++calls;
    if (getenv("TRUEOS_TEST_REENTRY") && calls >= 2 && calls <= 4) return -3;
    *gen = calls < 5 ? 1 : 2; *cols = calls < 5 ? 100 : 95; *rows = 35; return 0;
}
size_t trueos_cabi_shell_attached_write(const void *p, size_t n) {
    if (n > 73) n = 73;
    return fwrite(p, 1, n, stdout);
}
int32_t trueos_cabi_shell_attached_read_byte(void) {
    static size_t offset;
    const char *keys = getenv("TRUEOS_TEST_TUI_KEYS");
    assert(keys && keys[offset]);
    static size_t idle;
    if (!offset && getenv("TRUEOS_TEST_AUTO_DISCOVER") && idle++ < 102) {
        if (idle == 1) {
            assert(!mkdir("auto", 0755));
            FILE *file = fopen("auto/main.odin", "wb"); assert(file);
            fputs("package main\nmain :: proc() -> i32 { return 0 }\n", file); fclose(file);
        }
        return -1;
    }
    static size_t initial_allocations;
    if (getenv("TRUEOS_TEST_STABLE_HEAP")) {
        if (!offset) initial_allocations = guest_allocations;
        else assert(guest_allocations == initial_allocations);
    }
    if (keys[offset] == 'f' && getenv("TRUEOS_TEST_ADD_DEMO")) {
        assert(!mkdir("extra", 0755));
        FILE *file = fopen("extra/main.odin", "wb"); assert(file);
        fputs("package main\nmain :: proc() -> i32 { return 0 }\n", file); fclose(file);
    }
    return (unsigned char)keys[offset++];
}
void trueos_cabi_sleep_ms(uint64_t ms) { trueos_cabi_poll_once(); }


static Operation *get(uint32_t id) {
    for (size_t i = 0; i < 32; ++i) if (operations[i].id == id) return &operations[i];
    assert(!"invalid async operation ID");
    return NULL;
}
static Operation *start(int kind, const void *path, size_t len) {
    assert(len < sizeof(operations[0].path));
    for (size_t i = 0; i < 32; ++i) if (!operations[i].id) {
        Operation *op = &operations[i];
        memset(op, 0, sizeof(*op));
        op->id = ++next_id;
        op->kind = kind;
        op->ticks = 2;
        memcpy(op->path, path, len);
        ++live;
        return op;
    }
    assert(!"async operation leak");
    return NULL;
}
static void complete(Operation *op) {
    if (op->kind == 1) {
        FILE *file = fopen(op->path, "rb");
        if (!file) { op->error = -8; return; }
        fseek(file, 0, SEEK_END);
        op->size = (size_t)ftell(file);
        rewind(file);
        op->bytes = malloc(op->size ? op->size : 1);
        assert(op->bytes);
        if (fread(op->bytes, 1, op->size, file) != op->size) op->error = -2;
        fclose(file);
    } else if (op->kind == 2) {
        struct stat st;
        if (stat(op->path, &st)) { op->error = -8; return; }
        op->size = 12;
        op->bytes = calloc(1, 12);
        op->bytes[0] = S_ISDIR(st.st_mode) ? 2 : 1;
        uint64_t size = st.st_size;
        for (size_t i = 0; i < 8; ++i) op->bytes[4 + i] = size >> (8 * i);
    } else if (op->kind == 3) {
        DIR *dir = opendir(op->path);
        if (!dir) { op->error = -8; return; }
        op->bytes = calloc(1, 65536);
        memcpy(op->bytes, "TDL2", 4);
        size_t pos = 12;
        uint32_t count = 0;
        struct dirent *entry;
        while ((entry = readdir(dir))) {
            if (!strcmp(entry->d_name, ".") || !strcmp(entry->d_name, "..")) continue;
            size_t len = strlen(entry->d_name);
            assert(pos + 8 + len <= 65536);
            op->bytes[pos] = entry->d_type == 4 ? 2 : 1;
            op->bytes[pos + 2] = len;
            op->bytes[pos + 3] = len >> 8;
            op->bytes[pos + 4] = op->bytes[pos] == 1 ? 1 : 0;
            memcpy(op->bytes + pos + 8, entry->d_name, len);
            pos += 8 + len;
            ++count;
        }
        closedir(dir);
        for (size_t i = 0; i < 4; ++i) op->bytes[8 + i] = count >> (8 * i);
        op->size = pos;
    } else if (op->kind == 5) {
        if (mkdir(op->path, 0755)) {
            struct stat st;
            if (stat(op->path, &st) || !S_ISDIR(st.st_mode)) op->error = -2;
        }
    } else {
        assert(op->kind == 4 && op->committed && op->offset == op->size);
        if (getenv("TRUEOS_TEST_COMMIT_FAIL")) { op->error = -2; return; }
        FILE *file = fopen(op->path, "wb");
        if (!file) { op->error = -2; return; }
        if (fwrite(op->bytes, 1, op->size, file) != op->size) op->error = -2;
        if (fclose(file)) op->error = -2;
    }
}
void trueos_cabi_poll_once(void) {
    ++polls;
    for (size_t i = 0; i < 32; ++i) {
        Operation *op = &operations[i];
        if (!op->id || op->ready || (op->kind == 4 && !op->committed)) continue;
        if (--op->ticks == 0) { complete(op); op->ready = 1; }
    }
}
int32_t trueos_cabi_async_fs_create_dir_all_start(const void *p, size_t n) { return start(5, p, n)->id; }
int32_t trueos_cabi_async_fs_read_start(const void *p, size_t n) { assert(!getenv("TRUEOS_TEST_NO_SOURCE_IO")); return start(1, p, n)->id; }
int32_t trueos_cabi_async_fs_stat_start(const void *p, size_t n) { assert(!getenv("TRUEOS_TEST_NO_SOURCE_IO")); return start(2, p, n)->id; }
int32_t trueos_cabi_async_fs_typed_list_dir_start(const void *p, size_t n) { assert(!getenv("TRUEOS_TEST_NO_SOURCE_IO")); return start(3, p, n)->id; }
int32_t trueos_cabi_async_fs_status(uint32_t id) {
    Operation *op = get(id);
    assert(op->kind != 4 || op->committed);
    return !op->ready ? 0 : (op->error ? op->error : 1);
}
intptr_t trueos_cabi_async_fs_result_len(uint32_t id) {
    Operation *op = get(id);
    assert(op->ready && !op->error);
    return op->size;
}
intptr_t trueos_cabi_async_fs_result_read(uint32_t id, size_t offset, void *out, size_t cap) {
    Operation *op = get(id);
    assert(op->ready && !op->error && offset <= op->size);
    size_t count = op->size - offset;
    if (count > cap) count = cap;
    /* VMX may return fewer bytes than requested; the adapter must advance. */
    if (count > 37) count = 37;
    if (getenv("TRUEOS_TEST_ZERO_READ")) return 0;
    memcpy(out, op->bytes + offset, count);
    return count;
}
int32_t trueos_cabi_async_fs_write_begin(const void *p, size_t n, size_t size) {
    Operation *op = start(4, p, n);
    op->bytes = malloc(size ? size : 1);
    assert(op->bytes);
    op->size = size;
    return op->id;
}
int32_t trueos_cabi_async_fs_write_chunk(uint32_t id, size_t offset, const void *p, size_t n) {
    Operation *op = get(id);
    assert(op->kind == 4 && !op->committed && op->offset == offset && n <= op->size - offset);
    if (getenv("TRUEOS_TEST_CHUNK_FAIL")) return -2;
    memcpy(op->bytes + offset, p, n);
    op->offset += n;
    return 0;
}
int32_t trueos_cabi_async_fs_write_commit(uint32_t id) {
    Operation *op = get(id);
    assert(op->kind == 4 && !op->committed && op->offset == op->size);
    op->committed = 1;
    return 0;
}
int32_t trueos_cabi_async_fs_discard(uint32_t id) {
    Operation *op = get(id);
    free(op->bytes);
    memset(op, 0, sizeof(*op));
    --live;
    ++discarded;
    return 0;
}
int32_t trueos_cabi_blueprint_launch_script_v1(const void *p, size_t n) {
    const char *payload = p;
    size_t path_len = strlen(payload);
    const char *script = payload + path_len + 1;
    size_t script_len = strlen(script);
    assert(path_len + script_len + 10 == n);
    assert(!memcmp(script + script_len, "\0headless", 9));
    FILE *file = fopen(payload, "rb");
    assert(file);
    char magic[4];
    assert(fread(magic, 1, 4, file) == 4 && !memcmp(magic, "TRBP", 4));
    fclose(file);
    return 0;
}
int main(int argc, char **argv) {
    int status = trueos_main(argc, argv);
    assert(live == 0);
    if (next_id) assert(polls && discarded == next_id);
    return status;
}
