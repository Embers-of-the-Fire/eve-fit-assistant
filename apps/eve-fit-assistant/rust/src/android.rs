#![cfg(target_os = "android")]

use std::ffi::c_void;

use anyhow::Context as _;
use jni::JavaVM;
use jni::jni_sig;
use jni::jni_str;
use jni::objects::JObject;
use jni::refs::Global;

fn current_application(env: &mut jni::Env<'_>) -> anyhow::Result<Global<JObject<'static>>> {
    let class = env.find_class(jni_str!("android/app/ActivityThread"))?;
    let context = env
        .call_static_method(
            class,
            jni_str!("currentApplication"),
            jni_sig!("()Landroid/app/Application;"),
            &[],
        )?
        .l()?;
    Ok(env.new_global_ref(context)?)
}

#[no_mangle]
pub extern "C" fn JNI_OnLoad(vm: *mut jni::sys::JavaVM, _res: *mut c_void) -> jni::sys::jint {
    let context = unsafe { JavaVM::from_raw(vm) }
        .attach_current_thread(|env| -> anyhow::Result<*mut c_void> {
            Ok(current_application(env)?.into_raw().cast())
        })
        .unwrap_or_else(|err| {
            log::error!("failed to obtain Android application context: {err}");
            std::ptr::null_mut()
        });
    unsafe {
        ndk_context::initialize_android_context(vm.cast(), context);
    }
    jni::sys::JNI_VERSION_1_6
}

pub fn init_platform_verifier() -> anyhow::Result<()> {
    let vm = unsafe { JavaVM::from_raw(ndk_context::android_context().vm().cast()) };
    vm.attach_current_thread(|env| -> anyhow::Result<()> {
        let stored = ndk_context::android_context().context();
        let context = if stored.is_null() {
            let global = current_application(env)?;
            unsafe { JObject::from_raw(env, global.as_obj().as_raw()) }
        } else {
            unsafe { JObject::from_raw(env, stored.cast()) }
        };
        rustls_platform_verifier::android::init_with_env(env, context)
            .context("failed to initialize rustls platform verifier")?;
        Ok(())
    })
}
