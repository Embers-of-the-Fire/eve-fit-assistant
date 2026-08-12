use flutter_rust_bridge::frb;

#[frb(sync)]
pub fn init_platform() -> anyhow::Result<()> {
    #[cfg(target_os = "android")]
    crate::android::init_platform_verifier()?;
    Ok(())
}
