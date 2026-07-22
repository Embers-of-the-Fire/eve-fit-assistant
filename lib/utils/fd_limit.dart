import "dart:ffi";
import "dart:io" show Platform;

import "package:ffi/ffi.dart";

const _rlimitNofile = 7;

typedef _RlimitNative = Int32 Function(Int32 resource, Pointer<Uint64> rlim);
typedef _RlimitDart = int Function(int resource, Pointer<Uint64> rlim);

void raiseFdSoftLimitToHard() {
  if (!Platform.isLinux) return;
  try {
    final libc = DynamicLibrary.process();
    final getrlimit = libc.lookupFunction<_RlimitNative, _RlimitDart>("getrlimit");
    final setrlimit = libc.lookupFunction<_RlimitNative, _RlimitDart>("setrlimit");
    using((arena) {
      final rlim = arena<Uint64>(2);
      if (getrlimit(_rlimitNofile, rlim) != 0) return;
      final soft = rlim[0];
      final hard = rlim[1];
      if (soft >= hard) return;
      rlim[0] = hard;
      setrlimit(_rlimitNofile, rlim);
    });
  } on Object {
    // best-effort
  }
}
