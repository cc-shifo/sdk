// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// See http://dartbug.com/33660 for details about what inspired this generator.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

Random random = new Random();
int totalNodes = 0;
Set<String> seen = new Set<String>();

main(List<String> args) async {
  int maxSize;
  if (args.length > 0) maxSize = int.tryParse(args[0]);
  maxSize ??= 5;

  for (int i = 0; i < 2500; i++) {
    stdout.write(".");
    if (i % 75 == 74) stdout.write("\n");
    totalNodes = 0;
    Tree tree = fuzz(1 + random.nextInt(5), 1 + random.nextInt(8), maxSize);
    String expected =
        new List<String>.generate(totalNodes, (i) => "${i + 1}").join(" ");
    String asyncProgram = printProgram(tree, true, false, true, '"$expected"');
    if (seen.add(asyncProgram)) {
      File asyncFile = new File('${maxSize}_${i}.dart')
        ..writeAsStringSync(asyncProgram);

      List<String> run = await executeAndGetStdOut(
          Platform.executable, <String>[asyncFile.path]);
      if (expected == run[0]) {
        asyncFile.deleteSync();
      } else {
        print("\n${asyncFile.path} was not as expected!");
        String name = "async_nested_${maxSize}_${i}_test.dart";
        asyncFile.renameSync(name);
        print(" -> Created $name");
        print("    (you might want to run dartfmt -w $name).");
      }
    }
  }
  print(" done ");
}

Tree fuzz(int asyncLikely, int childrenLikely, int maxSize) {
  // asyncLikely = 3;
  // childrenLikely = 5;
  totalNodes++;
  Tree result = new Tree();
  result.name = "$totalNodes";
  result.async = random.nextInt(10) < asyncLikely;

  while (random.nextInt(10) < childrenLikely) {
    if (totalNodes >= maxSize) return result;
    result.children
        .add(fuzz(1 + random.nextInt(5), 1 + random.nextInt(8), maxSize));
  }

  return result;
}

String printProgram(Tree tree, bool emitAsync, bool emitPrintOnCreate,
    bool printSimple, String expected) {
  StringBuffer lines = new StringBuffer();
  lines.write("""
// Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// This has been automatically generated by script
// "async_nested_test_generator.dart".

import 'dart:async';

void main() async {
""");

  printNode(Tree node) {
    if (node.async && emitAsync) {
      lines.write("await new Future.value(");
    }
    lines.writeln("new Node('${node.name}', [");
    for (Tree child in node.children) {
      printNode(child);
      lines.write(",");
    }
    lines.writeln("])");
    if (node.async && emitAsync) {
      lines.write(")");
    }
  }

  if (expected != null) {
    lines.writeln('String expected = $expected;');
  }
  lines.write("Node node = ");
  printNode(tree);
  lines.writeln(";");
  if (printSimple) {
    lines.writeln("String actual = node.toSimpleString();");
  } else {
    lines.writeln("String actual = node.toString();");
  }
  lines.writeln("print(actual);");

  if (expected != null) {
    lines.writeln(r"""if (actual != expected) {
      throw "Expected '$expected' but got '$actual'";
    }""");
  }

  lines.writeln(r"""
}

class Node {
  final List<Node>? nested;
  final String name;

  Node(this.name, [this.nested]) {
""");
  if (emitPrintOnCreate) {
    lines.writeln(r'print("Creating $name");');
  }

  lines.write(r"""
  }

  String toString() => '<$name:[${nested?.join(', ')}]>';

  toSimpleString() {
    var tmp = nested?.map((child) => child.toSimpleString());
    return '$name ${tmp?.join(' ')}'.trim();
  }
}
""");

  return lines.toString();
}

Future<List<String>> executeAndGetStdOut(
    String executable, List<String> arguments) async {
  var process = await Process.start(executable, arguments);
  Future<List<String>> result = combine(
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .toList(),
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .toList());
  int exitCode = await process.exitCode;
  (await result).add("Exit code: $exitCode");

  return result;
}

Future<List<String>> combine(
    Future<List<String>> a, Future<List<String>> b) async {
  List<String> aDone = await a;
  List<String> bDone = await b;
  List<String> result = new List.from(aDone);
  result.addAll(bDone);
  return result;
}

class Tree {
  String name;
  bool async = false;
  List<Tree> children = <Tree>[];
}
