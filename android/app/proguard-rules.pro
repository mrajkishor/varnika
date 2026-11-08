# WireGuard's Go backend is reached through JNI and reflection-free lookups
# that R8 can't see; keep the whole library intact.
-keep class com.wireguard.** { *; }
-dontwarn com.wireguard.**

# Our services/receivers are referenced from the manifest (kept automatically),
# but keep the bridge's method names readable in crash reports.
-keepnames class com.mrajkishor.varnika.** { *; }
