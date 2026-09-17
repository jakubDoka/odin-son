#include <errno.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "aot_export.h"
#include "wasm_export.h"

static pthread_mutex_t run_mutex = PTHREAD_MUTEX_INITIALIZER;

static void
log_failure(const char *stage, const char *detail)
{
        if (detail != NULL && detail[0] != '\0')
                fprintf(stderr, "wamr: %s: %s\n", stage, detail);
        else
                fprintf(stderr, "wamr: %s\n", stage);
}

int
bh_platform_init(void)
{
        return 0;
}

void
bh_platform_destroy(void)
{
}

static bool
is_compiler_banner(const char *format)
{
        return strcmp(format, "Create AoT compiler with:\n") == 0
               || strcmp(format, "  target:        %s\n") == 0
               || strcmp(format, "  target cpu:    %s\n") == 0
               || strcmp(format, "  target triple: %s\n") == 0
               || strcmp(format, "  cpu features:  %s\n") == 0
               || strcmp(format, "  opt level:     %d\n") == 0
               || strcmp(format, "  size level:    %d\n") == 0
               || strncmp(format, "  output format: ", 17) == 0;
}

int
os_printf(const char *format, ...)
{
        va_list args;
        int result;

        if (is_compiler_banner(format))
                return 0;
        va_start(args, format);
        result = vprintf(format, args);
        va_end(args);
        return result;
}

int
os_vprintf(const char *format, va_list args)
{
        return vprintf(format, args);
}

static int
compile_module(uint8_t *bytes, uint32_t size, uint8_t **aot_bytes,
               uint32_t *aot_size)
{
        char error[256] = { 0 };
        wasm_module_t module = NULL;
        aot_comp_data_t comp_data = NULL;
        aot_comp_context_t comp_ctx = NULL;
        AOTCompOption option = { 0 };
        int status = ENOEXEC;

        module = wasm_runtime_load(bytes, size, error, sizeof(error));
        if (module == NULL) {
                log_failure("failed to load WebAssembly module", error);
                goto done;
        }

        comp_data = aot_create_comp_data(module, NULL, true);
        if (comp_data == NULL) {
                log_failure("failed to create AOT compilation data",
                            aot_get_last_error());
                goto done;
        }

        option.opt_level = 0;
        option.size_level = 0;
        option.output_format = AOT_FORMAT_FILE;
        option.bounds_checks = 2;
        option.stack_bounds_checks = 2;
        option.enable_simd = true;
        option.enable_aux_stack_check = true;
        option.enable_bulk_memory = true;
        option.enable_bulk_memory_opt = true;
        option.enable_gc = true;
        option.disable_llvm_lto = true;
        aot_call_stack_features_init_default(&option.call_stack_features);

        comp_ctx = aot_create_comp_context(comp_data, &option);
        if (comp_ctx == NULL) {
                log_failure("failed to create AOT compilation context",
                            aot_get_last_error());
                goto done;
        }
        if (!aot_compile_wasm(comp_ctx)) {
                log_failure("failed to compile WebAssembly module",
                            aot_get_last_error());
                goto done;
        }

        *aot_bytes = aot_emit_aot_file_buf(comp_ctx, comp_data, aot_size);
        if (*aot_bytes == NULL) {
                log_failure("failed to emit AOT module", aot_get_last_error());
                goto done;
        }
        status = 0;

done:
        if (comp_ctx != NULL)
                aot_destroy_comp_context(comp_ctx);
        if (comp_data != NULL)
                aot_destroy_comp_data(comp_data);
        if (module != NULL)
                wasm_runtime_unload(module);
        return status;
}

static int
execute_module(uint8_t *aot_bytes, uint32_t aot_size, const char *entry,
               int64_t *result)
{
        char error[256] = { 0 };
        wasm_module_t module = NULL;
        wasm_module_inst_t instance = NULL;
        wasm_exec_env_t exec_env = NULL;
        wasm_function_inst_t function;
        wasm_val_t value = { 0 };
        wasm_valkind_t result_type;
        int status = ENOEXEC;

        module = wasm_runtime_load(aot_bytes, aot_size, error, sizeof(error));
        if (module == NULL) {
                log_failure("failed to load compiled AOT module", error);
                goto done;
        }
        instance = wasm_runtime_instantiate(module, 512 * 1024, 0, error,
                                            sizeof(error));
        if (instance == NULL) {
                log_failure("failed to instantiate AOT module", error);
                goto done;
        }
        exec_env = wasm_runtime_create_exec_env(instance, 512 * 1024);
        if (exec_env == NULL) {
                log_failure("failed to create execution environment", NULL);
                status = ENOMEM;
                goto done;
        }
        function = wasm_runtime_lookup_function(instance, entry);
        if (function == NULL) {
                fprintf(stderr, "wamr: exported function '%s' was not found\n",
                        entry);
                status = ENOENT;
                goto done;
        }
        if (wasm_func_get_param_count(function, instance) != 0
            || wasm_func_get_result_count(function, instance) != 1) {
                fprintf(stderr,
                        "wamr: exported function '%s' must take no parameters "
                        "and return one value\n",
                        entry);
                status = EINVAL;
                goto done;
        }
        wasm_func_get_result_types(function, instance, &result_type);
        if (result_type != WASM_I32 && result_type != WASM_I64) {
                fprintf(stderr,
                        "wamr: exported function '%s' must return i32 or i64\n",
                        entry);
                status = EINVAL;
                goto done;
        }
        if (!wasm_runtime_call_wasm_a(exec_env, function, 1, &value, 0, NULL)) {
                log_failure("WebAssembly execution failed",
                            wasm_runtime_get_exception(instance));
                goto done;
        }

        *result = result_type == WASM_I32 ? (int64_t)value.of.i32
                                          : value.of.i64;
        status = 0;

done:
        if (exec_env != NULL)
                wasm_runtime_destroy_exec_env(exec_env);
        if (instance != NULL)
                wasm_runtime_deinstantiate(instance);
        if (module != NULL)
                wasm_runtime_unload(module);
        return status;
}

int
wamr_run_module(const uint8_t *bytes, size_t size, const char *entry_data,
                size_t entry_size, int64_t *result)
{
        uint8_t *module_bytes = NULL;
        uint8_t *aot_bytes = NULL;
        uint32_t aot_size = 0;
        char *entry = NULL;
        int status;

        if (bytes == NULL || size == 0 || size > UINT32_MAX
            || entry_data == NULL || entry_size == 0 || entry_size == SIZE_MAX
            || result == NULL)
                return EINVAL;

        module_bytes = malloc(size);
        entry = malloc(entry_size + 1);
        if (module_bytes == NULL || entry == NULL) {
                status = ENOMEM;
                goto done;
        }
        memcpy(module_bytes, bytes, size);
        memcpy(entry, entry_data, entry_size);
        entry[entry_size] = '\0';

        pthread_mutex_lock(&run_mutex);
        if (!wasm_runtime_init()) {
                log_failure("failed to initialize runtime", NULL);
                status = ENOMEM;
                goto unlock;
        }
        status = compile_module(module_bytes, (uint32_t)size, &aot_bytes,
                                &aot_size);
        if (status == 0)
                status = execute_module(aot_bytes, aot_size, entry, result);
        if (aot_bytes != NULL)
                wasm_runtime_free(aot_bytes);
        wasm_runtime_destroy();

unlock:
        pthread_mutex_unlock(&run_mutex);
done:
        free(entry);
        free(module_bytes);
        return status;
}
