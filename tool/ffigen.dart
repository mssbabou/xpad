import 'dart:io';

import 'package:ffigen/ffigen.dart';
   
void main() {
  final packageRoot = Platform.script.resolve('../');
  FfiGenerator(
    // Required. Output path for the generated bindings.
    output: Output(dartFile: packageRoot.resolve('lib/xpad.g.dart')),
    // Optional. Where to look for header files.
    headers: Headers(entryPoints: [packageRoot.resolve('native/header/xpad.h')]),
    // Optional. What functions to generate bindings for.
    functions: Functions.includeAll,
  ).generate();
}