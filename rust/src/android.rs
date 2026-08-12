#![cfg(target_os = "android")]

use std::ffi::c_void;

use anyhow::Context as _;
use jni::JavaVM;
use jni::jni_sig;
use jni::jni_str;

#[no_mangle]
pub extern "C" fn JNI_OnLoad(vm: *mut jni::sys::JavaVM, res: *mut c_void) -> jni::sys::jint {
    unsafe {
        ndk_context::initialize_android_context(vm.cast(), res);
    }
    jni::sys::JNI_VERSION_1_6
}

pub fn init_platform_verifier() -> anyhow::Result<()> {
    let vm = unsafe { JavaVM::from_raw(ndk_context::android_context().vm().cast()) };
    vm.attach_current_thread(|env| -> anyhow::Result<()> {
        let class = env.find_class(jni_str!("android/app/ActivityThread"))?;
        let context = env
            .call_static_method(
                class,
                jni_str!("currentApplication"),
                jni_sig!("()Landroid/app/Application;"),
                &[],
            )?
            .l()?;
        rustls_platform_verifier::android::init_with_env(env, context)
            .context("failed to initialize rustls platform verifier")?;
        Ok(())
    })
}
