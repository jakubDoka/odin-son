use std::{env, path::PathBuf};

fn main() {
    let mut arch = std::env::var("CARGO_CFG_TARGET_ARCH").unwrap();
    let os = std::env::var("CARGO_CFG_TARGET_OS").unwrap();

    if arch == "x86_64" {
        arch = "amd64".into();
    }

    if arch == "aarch64" {
        arch = "arm64".into();
    }

    for key in ["BAC_LIB_PATH", "ODIN"] {
        println!("cargo:rerun-if-env-changed={key}");
    }
    let manifest = PathBuf::from(env::var_os("CARGO_MANIFEST_DIR").unwrap());
    let is_debug = env::var("PROFILE").as_deref() == Ok("debug");
    let lib_name = if is_debug { "libdebug" } else { "lib" };
    let lib_name = format!("{os}_{arch}_{lib_name}.o");
    let root = manifest.join("../../..").canonicalize().unwrap();
    let library = env::var_os("BAC_LIB_PATH")
        .map(PathBuf::from)
        .unwrap_or_else(|| root.join("bac/bindgen/lib/").join(lib_name));
    assert!(
        library.is_file(),
        "BAC library not found at {}. Set BAC_LIB_PATH to a BAC object, or run \
        `fish -c 'source misc/profiles.fish; build-bac [debug]'` (requires Odin).",
        library.display()
    );
    let library = library.canonicalize().unwrap();
    println!("cargo:rerun-if-changed={}", library.display());
    let modifiers = "-bundle,+verbatim";
    println!(
        "cargo:rustc-link-search=native={}",
        library.parent().unwrap().display()
    );
    println!(
        "cargo:rustc-link-lib=static:{modifiers}={}",
        library.file_name().unwrap().to_str().unwrap()
    );
}
