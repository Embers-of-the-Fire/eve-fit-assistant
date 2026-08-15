# rustls-platform-verifier calls its Kotlin component by name over JNI
# (org.rustls.platformverifier.CertificateVerifier). With no Java-side
# references, R8 strips it from release builds and TLS verification fails
# with ClassNotFoundException at runtime.
-keep class org.rustls.platformverifier.** { *; }
