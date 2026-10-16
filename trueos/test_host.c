#define _POSIX_C_SOURCE 200809L
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
extern int32_t trueos_main(size_t, char **);
void *trueos_cabi_alloc(size_t n) { return malloc(n); }
void *trueos_cabi_calloc(size_t n, size_t s) { return calloc(n, s); }
void *trueos_cabi_realloc(void *p, size_t n) { return realloc(p, n); }
void trueos_cabi_free(void *p) { free(p); }
void *sys_alloc_aligned(size_t n, size_t a) { void *p = NULL; return posix_memalign(&p, a, n) ? NULL : p; }
void trueos_cabi_write(uint32_t s, const void *p, size_t n) { fwrite(p, 1, n, s == 2 ? stderr : stdout); }
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
int main(int argc, char **argv) {
    int status = trueos_main(argc, argv);
    assert(live == 0);
    if (next_id) assert(polls && discarded == next_id);
    return status;
}
