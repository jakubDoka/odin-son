#define _GNU_SOURCE

#include <dlfcn.h>
#include <errno.h>
#include <link.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef void *wasm_module_t;
typedef void *wasm_module_inst_t;
typedef void *wasm_exec_env_t;
typedef void *wasm_function_inst_t;

typedef struct wasm_val_t {
        uint8_t kind;
        uint8_t padding[7];
        union {
                int32_t i32;
                int64_t i64;
                float f32;
                double f64;
                uintptr_t foreign;
                void *ref;
        } of;
} wasm_val_t;

enum {
        WASM_I32,
        WASM_I64,
};

struct wamr_api {
        const char *library;
        void *handle;
        bool ready;
        bool (*runtime_init)(void);
        void (*runtime_destroy)(void);
        bool (*runtime_init_thread_env)(void);
        void (*runtime_destroy_thread_env)(void);
        bool (*runtime_thread_env_inited)(void);
        wasm_module_t (*runtime_load)(uint8_t *, uint32_t, char *, uint32_t);
        void (*runtime_unload)(wasm_module_t);
        wasm_module_inst_t (*runtime_instantiate)(wasm_module_t, uint32_t,
                                                  uint32_t, char *, uint32_t);
        void (*runtime_deinstantiate)(wasm_module_inst_t);
        wasm_exec_env_t (*runtime_create_exec_env)(wasm_module_inst_t,
                                                    uint32_t);
        void (*runtime_destroy_exec_env)(wasm_exec_env_t);
        wasm_function_inst_t (*runtime_lookup_function)(wasm_module_inst_t,
                                                        const char *);
        uint32_t (*func_get_param_count)(wasm_function_inst_t,
                                         wasm_module_inst_t);
        uint32_t (*func_get_result_count)(wasm_function_inst_t,
                                          wasm_module_inst_t);
        void (*func_get_result_types)(wasm_function_inst_t, wasm_module_inst_t,
                                      uint8_t *);
        bool (*runtime_call_wasm_a)(wasm_exec_env_t, wasm_function_inst_t,
                                    uint32_t, wasm_val_t *, uint32_t,
                                    wasm_val_t *);
};

static struct wamr_api simd_api = { .library = "libiwasm-simd.so" };
static struct wamr_api memory64_api = { .library = "libiwasm-memory64.so" };
static pthread_once_t init_once = PTHREAD_ONCE_INIT;
static pthread_mutex_t run_mutex = PTHREAD_MUTEX_INITIALIZER;

static void *
load_library(const char *path)
{
        return dlmopen(LM_ID_NEWLM, path, RTLD_NOW | RTLD_LOCAL);
}

static void *
open_runtime(const char *library)
{
        const char *directory = getenv("WAMR_LIB_DIR");
        char path[4096];

        if (directory != NULL
            && snprintf(path, sizeof(path), "%s/%s", directory, library) > 0) {
                void *handle = load_library(path);
                if (handle != NULL) {
                        return handle;
                }
        }

        if (snprintf(path, sizeof(path), "wamr/%s", library) > 0) {
                void *handle = load_library(path);
                if (handle != NULL) {
                        return handle;
                }
        }
        return load_library(library);
}

#define LOAD_SYMBOL(api, field, name)                                        \
        do {                                                                 \
                *(void **)(&(api)->field) = dlsym((api)->handle, name);       \
                if ((api)->field == NULL)                                    \
                        return;                                              \
        } while (0)

static void
init_api(struct wamr_api *api)
{
        api->handle = open_runtime(api->library);
        if (api->handle == NULL)
                return;

        LOAD_SYMBOL(api, runtime_init, "wasm_runtime_init");
        LOAD_SYMBOL(api, runtime_destroy, "wasm_runtime_destroy");
        LOAD_SYMBOL(api, runtime_init_thread_env,
                    "wasm_runtime_init_thread_env");
        LOAD_SYMBOL(api, runtime_destroy_thread_env,
                    "wasm_runtime_destroy_thread_env");
        LOAD_SYMBOL(api, runtime_thread_env_inited,
                    "wasm_runtime_thread_env_inited");
        LOAD_SYMBOL(api, runtime_load, "wasm_runtime_load");
        LOAD_SYMBOL(api, runtime_unload, "wasm_runtime_unload");
        LOAD_SYMBOL(api, runtime_instantiate, "wasm_runtime_instantiate");
        LOAD_SYMBOL(api, runtime_deinstantiate,
                    "wasm_runtime_deinstantiate");
        LOAD_SYMBOL(api, runtime_create_exec_env,
                    "wasm_runtime_create_exec_env");
        LOAD_SYMBOL(api, runtime_destroy_exec_env,
                    "wasm_runtime_destroy_exec_env");
        LOAD_SYMBOL(api, runtime_lookup_function,
                    "wasm_runtime_lookup_function");
        LOAD_SYMBOL(api, func_get_param_count, "wasm_func_get_param_count");
        LOAD_SYMBOL(api, func_get_result_count, "wasm_func_get_result_count");
        LOAD_SYMBOL(api, func_get_result_types, "wasm_func_get_result_types");
        LOAD_SYMBOL(api, runtime_call_wasm_a, "wasm_runtime_call_wasm_a");
        api->ready = true;
}

static void
init_runtimes(void)
{
        init_api(&simd_api);
        init_api(&memory64_api);
}

enum run_status {
        RUN_OK,
        RUN_LOAD_FAILED = -1,
};

static int
run_with(struct wamr_api *api, const uint8_t *bytes, uint32_t size,
         const char *entry, int64_t *result)
{
        char error[256];
        wasm_module_t module = NULL;
        wasm_module_inst_t instance = NULL;
        wasm_exec_env_t exec_env = NULL;
        wasm_function_inst_t function;
        wasm_val_t value = { 0 };
        uint8_t result_type;
        uint8_t *module_bytes = NULL;
        bool destroy_thread_env = false;
        int status = ENOEXEC;

        if (!api->ready)
                return RUN_LOAD_FAILED;
        if (!api->runtime_thread_env_inited()) {
                if (!api->runtime_init_thread_env())
                        return ENOMEM;
                destroy_thread_env = true;
        }

        module_bytes = malloc(size);
        if (module_bytes == NULL) {
                status = ENOMEM;
                goto done;
        }
        memcpy(module_bytes, bytes, size);

        module = api->runtime_load(module_bytes, size, error, sizeof(error));
        if (module == NULL) {
                status = RUN_LOAD_FAILED;
                goto done;
        }
        instance = api->runtime_instantiate(module, 512 * 1024, 0, error,
                                            sizeof(error));
        if (instance == NULL)
                goto done;
        exec_env = api->runtime_create_exec_env(instance, 512 * 1024);
        if (exec_env == NULL) {
                status = ENOMEM;
                goto done;
        }
        function = api->runtime_lookup_function(instance, entry);
        if (function == NULL) {
                status = ENOENT;
                goto done;
        }
        if (api->func_get_param_count(function, instance) != 0
            || api->func_get_result_count(function, instance) != 1) {
                status = EINVAL;
                goto done;
        }
        api->func_get_result_types(function, instance, &result_type);
        if (result_type != WASM_I32 && result_type != WASM_I64) {
                status = EINVAL;
                goto done;
        }
        if (!api->runtime_call_wasm_a(exec_env, function, 1, &value, 0, NULL))
                goto done;

        *result = result_type == WASM_I32 ? (int64_t)value.of.i32
                                          : value.of.i64;
        status = RUN_OK;

done:
        if (exec_env != NULL)
                api->runtime_destroy_exec_env(exec_env);
        if (instance != NULL)
                api->runtime_deinstantiate(instance);
        if (module != NULL)
                api->runtime_unload(module);
        free(module_bytes);
        if (destroy_thread_env)
                api->runtime_destroy_thread_env();
        return status;
}

static int
run_initialized(struct wamr_api *api, const uint8_t *bytes, uint32_t size,
                const char *entry, int64_t *result)
{
        int status;

        if (!api->ready)
                return RUN_LOAD_FAILED;
        if (!api->runtime_init())
                return ENOMEM;
        status = run_with(api, bytes, size, entry, result);
        api->runtime_destroy();
        return status;
}

int
wamr_run_module(const uint8_t *bytes, size_t size, const char *entry_data,
                size_t entry_size, int64_t *result)
{
        char *entry;
        int status;

        if (bytes == NULL || size == 0 || size > UINT32_MAX
            || entry_data == NULL || entry_size == 0 || entry_size == SIZE_MAX
            || result == NULL)
                return EINVAL;

        entry = malloc(entry_size + 1);
        if (entry == NULL)
                return ENOMEM;
        memcpy(entry, entry_data, entry_size);
        entry[entry_size] = '\0';

        pthread_once(&init_once, init_runtimes);
        pthread_mutex_lock(&run_mutex);
        status = run_initialized(&simd_api, bytes, (uint32_t)size, entry,
                                 result);
        if (status == RUN_LOAD_FAILED)
                status = run_initialized(&memory64_api, bytes, (uint32_t)size,
                                         entry, result);
        pthread_mutex_unlock(&run_mutex);

        free(entry);
        return status == RUN_LOAD_FAILED ? ENOEXEC : status;
}
