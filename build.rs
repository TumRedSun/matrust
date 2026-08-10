// build.rs
// Minimal build script. qmetaobject handles its own Qt discovery via pkg-config
// and QMAKE. We expose a few extra env knobs for the user.

fn main() {
    // Allow the user to point to a custom qmake via QMAKE env var.
    if std::env::var("QMAKE").is_err() {
        // Try common Linux qmake binaries.
        for candidate in ["qmake6", "qmake-qt6", "qmake"] {
            if which::which(candidate).is_ok() {
                println!("cargo:rustc-env=QMAKE={}", candidate);
                break;
            }
        }
    }

    println!("cargo:rerun-if-changed=qml");
    println!("cargo:rerun-if-changed=Cargo.toml");
}

// Minimal which() helper to avoid an extra dependency.
mod which {
    use std::path::PathBuf;
    pub fn which(cmd: &str) -> Result<PathBuf, ()> {
        if let Ok(path) = std::env::var("PATH") {
            for dir in path.split(':') {
                let p: PathBuf = std::path::Path::new(dir).join(cmd);
                if p.is_file() {
                    return Ok(p);
                }
            }
        }
        Err(())
    }
}
