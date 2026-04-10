import 'dart:io';
import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (input.config.buildCodeAssets) {
      final srcDir = Directory.fromUri(input.packageRoot.resolve('native/src/'));
      final sources = srcDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.c'))
          .map((f) => f.uri.toFilePath())
          .toList();

      final builder = CBuilder.library(
        name: 'xpad',
        assetName: 'xpad.g.dart',
        sources: sources,
      );
      await builder.run(input: input, output: output);
    }
  });
}