#include <errno.h>
#include <stdint.h>
#include <stdio.h>

#include <exception>
#include <new>
#include <string_view>

#include "wabt/binary-reader.h"
#include "wabt/interp/binary-reader-interp.h"
#include "wabt/interp/interp.h"

namespace {

using namespace wabt;
using namespace wabt::interp;

void log_failure(const char *stage, const char *detail = nullptr) {
  if (detail != nullptr && detail[0] != '\0')
    fprintf(stderr, "wabt: %s: %s\n", stage, detail);
  else
    fprintf(stderr, "wabt: %s\n", stage);
}

int run_module(const uint8_t *bytes, size_t size, std::string_view entry_name,
               int64_t *result) {
  Features features;
  features.EnableAll();

  ModuleDesc module_desc;
  Errors errors;
  ReadBinaryOptions options(features, nullptr, false, true, true);
  if (Failed(ReadBinaryInterp("<memory>", bytes, size, options, &errors,
                              &module_desc))) {
    log_failure("failed to read WebAssembly module",
                errors.empty() ? nullptr : errors.front().message.c_str());
    return ENOEXEC;
  }

  Store store(features);
  auto module = Module::New(store, module_desc);
  RefVec imports(module->desc().imports.size(), Ref::Null);
  Trap::Ptr trap;
  auto instance = Instance::Instantiate(store, module.ref(), imports, &trap);
  if (!instance) {
    log_failure("failed to instantiate WebAssembly module",
                trap ? trap->message().c_str() : nullptr);
    return ENOEXEC;
  }

  const ExportDesc *found = nullptr;
  for (const auto &export_desc : module->desc().exports) {
    if (export_desc.type.name == entry_name) {
      found = &export_desc;
      break;
    }
  }
  if (found == nullptr) {
    fprintf(stderr, "wabt: exported function '%.*s' was not found\n",
            static_cast<int>(entry_name.size()), entry_name.data());
    return ENOENT;
  }
  if (found->type.type->kind != ExternalKind::Func) {
    fprintf(stderr, "wabt: export '%.*s' is not a function\n",
            static_cast<int>(entry_name.size()), entry_name.data());
    return EINVAL;
  }

  const auto *type = static_cast<const FuncType *>(found->type.type.get());
  if (!type->params.empty() || type->results.size() != 1) {
    fprintf(stderr,
            "wabt: exported function '%.*s' must take no parameters and "
            "return one value\n",
            static_cast<int>(entry_name.size()), entry_name.data());
    return EINVAL;
  }
  if (type->results[0] != Type::I32 && type->results[0] != Type::I64) {
    fprintf(stderr, "wabt: exported function '%.*s' must return i32 or i64\n",
            static_cast<int>(entry_name.size()), entry_name.data());
    return EINVAL;
  }

  auto function = store.UnsafeGet<Func>(instance->funcs()[found->index]);
  Values params;
  Values results;
  if (Failed(function->Call(store, params, results, &trap))) {
    log_failure("WebAssembly execution failed",
                trap ? trap->message().c_str() : nullptr);
    return ENOEXEC;
  }

  *result = type->results[0] == Type::I32
                ? static_cast<int64_t>(results[0].Get<int32_t>())
                : results[0].Get<int64_t>();
  return 0;
}

} // namespace

extern "C" int wabt_run_module(const uint8_t *bytes, size_t size,
                               const char *entry_data, size_t entry_size,
                               int64_t *result) {
  if (bytes == nullptr || size == 0 || entry_data == nullptr ||
      entry_size == 0 || result == nullptr)
    return EINVAL;

  try {
    return run_module(bytes, size, std::string_view(entry_data, entry_size),
                      result);
  } catch (const std::bad_alloc &) {
    log_failure("out of memory");
    return ENOMEM;
  } catch (const std::exception &error) {
    log_failure("unexpected interpreter failure", error.what());
    return ENOEXEC;
  } catch (...) {
    log_failure("unexpected interpreter failure");
    return ENOEXEC;
  }
}
