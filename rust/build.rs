fn main() {
    // Prepared for Cronet static linking (Phase 2).
    // Currently using reqwest for HTTP. When Cronet FFI is added,
    // uncomment the below to link libcronet.a on macOS arm64.

    /*
    if cfg!(target_os = "macos") && cfg!(target_arch = "aarch64") {
        let dir = std::env::var("CARGO_MANIFEST_DIR").unwrap();
        println!("cargo:rustc-link-search=native={}/lib/darwin_arm64", dir);
        println!("cargo:rustc-link-lib=static=cronet");

        // Compile the stub for the missing symbol
        cc::Build::new()
            .file("lib/darwin_arm64/stub.c")
            .compile("cronet_stub");

        for fw in &[
            "CoreFoundation", "CoreGraphics", "CoreText", "Foundation",
            "Security", "ApplicationServices", "AppKit", "IOKit",
            "OpenDirectory", "CFNetwork", "CoreServices", "Network",
            "SystemConfiguration", "UniformTypeIdentifiers",
            "CryptoTokenKit", "LocalAuthentication",
        ] {
            println!("cargo:rustc-link-lib=framework={}", fw);
        }
        println!("cargo:rustc-link-lib=bsm");
        println!("cargo:rustc-link-lib=pmenergy");
        println!("cargo:rustc-link-lib=pmsample");
        println!("cargo:rustc-link-lib=resolv");
    }
    */
}
