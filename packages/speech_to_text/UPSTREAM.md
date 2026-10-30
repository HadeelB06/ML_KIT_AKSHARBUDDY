# Upstream package

- Package: `speech_to_text`
- Upstream version: `6.6.2`
- Source: https://pub.dev/packages/speech_to_text/versions/6.6.2
- Published archive: https://pub.dev/api/archives/speech_to_text-6.6.2.tar.gz
- License: BSD 3-Clause; the upstream `LICENSE` file is preserved unchanged.

## Local patch

The only local code patch removes the obsolete Android `Registrar` import and
`registerWith(registrar)` compatibility shim. The modern `FlutterPlugin` and
`ActivityAware` registration and lifecycle implementation is unchanged.
