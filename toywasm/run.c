#include <errno.h>
#include <limits.h>
#include <stddef.h>
#include <stdint.h>

#include "exec_context.h"
#include "instance.h"
#include "load_context.h"
#include "mem.h"
#include "module.h"
#include "report.h"
#include "type.h"
#include "valtype.h"

int
toywasm_run_module(const uint8_t *bytes, size_t size, const char *entry_data,
                   size_t entry_size, int32_t *result)
{
        struct mem_context mctx;
        struct module *module = NULL;
        struct instance *instance = NULL;
        int ret = EINVAL;

        if (bytes == NULL || size == 0 || entry_data == NULL ||
            entry_size > UINT32_MAX || result == NULL) {
                return ret;
        }

        mem_context_init(&mctx);

        struct load_context lctx;
        load_context_init(&lctx, &mctx);
        ret = module_create(&module, bytes, bytes + size, &lctx);
        load_context_clear(&lctx);
        if (ret != 0) {
                goto done;
        }

        struct name entry = {
                .nbytes = (uint32_t)entry_size,
                .data = entry_data,
        };
        uint32_t funcidx;
        ret = module_find_export(module, &entry, EXTERNTYPE_FUNC, &funcidx);
        if (ret != 0) {
                goto done;
        }

        const struct functype *type = module_functype(module, funcidx);
        if (type->parameter.ntypes != 0 || type->result.ntypes != 1 ||
            type->result.types[0] != TYPE_i32) {
                ret = EINVAL;
                goto done;
        }

        struct report report;
        report_init(&report);
        ret = instance_create(&mctx, module, &instance, NULL, &report);
        report_clear(&report);
        if (ret != 0) {
                goto done;
        }

        struct exec_context ectx;
        exec_context_init(&ectx, instance, &mctx);
        ret = instance_execute_func(&ectx, funcidx, &type->parameter,
                                    &type->result);
        ret = instance_execute_handle_restart(&ectx, ret);
        if (ret == 0) {
                struct val value;
                exec_pop_vals(&ectx, &type->result, &value);
                *result = (int32_t)value.u.i32;
        }
        exec_context_clear(&ectx);

done:
        if (instance != NULL) {
                instance_destroy(instance);
        }
        if (module != NULL) {
                module_destroy(&mctx, module);
        }
        mem_context_clear(&mctx);
        return ret;
}
