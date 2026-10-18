use std::{
    env,
    path::{Path, PathBuf},
    process::Command,
};

fn run(command: &mut Command) {
    let status = command
        .status()
        .unwrap_or_else(|error| panic!("{command:?}: {error}"));
    assert!(status.success(), "{command:?} failed: {status}");
}

fn watch(path: &Path) {
    if path.is_dir() {
        for entry in path.read_dir().unwrap() {
            let path = entry.unwrap().path();
            if path
                .file_name()
                .is_some_and(|name| name == "bindings" || name == "c")
            {
                continue;
            }
            watch(&path);
        }
    } else {
        println!("cargo:rerun-if-changed={}", path.display());
    }
}

fn main() {
    for key in ["BAC_LIB_PATH", "ODIN"] {
        println!("cargo:rerun-if-env-changed={key}");
    }
    let manifest = PathBuf::from(env::var_os("CARGO_MANIFEST_DIR").unwrap());
    let root = manifest.join("../../..").canonicalize().unwrap();
    let out = PathBuf::from(env::var_os("OUT_DIR").unwrap());
    let library = if env::var_os("CARGO_FEATURE_BUILD_FROM_SOURCE").is_some() {
        assert_eq!(
            env::var("HOST").unwrap(),
            env::var("TARGET").unwrap(),
            "build-from-source currently builds for the host; supply a target BAC_LIB_PATH for cross compilation"
        );
        watch(&root.join("bac"));
        watch(&root.join("utils"));
        let object = out.join("bac.o");
        run(
            Command::new(env::var_os("ODIN").unwrap_or_else(|| "odin".into()))
                .current_dir(&root)
                .args([
                    "build",
                    "bac/bindgen/lib",
                    "-build-mode:obj",
                    "-no-entry-point",
                    "-use-single-module",
                    "-o:size",
                    "-source-code-locations:none",
                    "-disable-assert",
                    "-no-bounds-check",
                    "-no-type-assert",
                    "-define:NO_FMT=true",
                    "-default-to-nil-allocator",
                    "-define:ARNA_DISABLE_VIRTUAL=true",
                    "-define:ARNA_DISABLE_THREAD_LOCAL=true",
                    "-disable-init-fini",
                    "-define:INIT_FINI=false",
                ])
                .arg(format!("-out:{}", object.display())),
        );
        object
    } else {
        env::var_os("BAC_LIB_PATH")
            .map(PathBuf::from)
            .unwrap_or_else(|| root.join("bac/bindgen/lib/lib.o"))
    };
    assert!(
        library.is_file(),
        "BAC library not found at {}. Set BAC_LIB_PATH to a BAC object/static archive, run build-bac, or enable --features build-from-source (requires Odin).",
        library.display()
    );
    if env::var_os("CARGO_FEATURE_BUILD_FROM_SOURCE").is_none() {
        println!("cargo:rerun-if-changed={}", library.display());
    }
    let library = library.canonicalize().unwrap();
    let modifiers = if library.extension().is_some_and(|ext| ext == "a") {
        "+verbatim"
    } else {
        "-bundle,+verbatim"
    };
    println!(
        "cargo:rustc-link-search=native={}",
        library.parent().unwrap().display()
    );
    println!(
        "cargo:rustc-link-lib=static:{modifiers}={}",
        library.file_name().unwrap().to_str().unwrap()
    );
}
