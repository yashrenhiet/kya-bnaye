// Local replacement for `dart analyze --fatal-infos --fatal-warnings`.
//
// Why this exists: on the dev Mac, macOS security tooling removes the Dart
// SDK's `dartaotruntime` binary, which `dart analyze` needs to start the AOT
// analysis server. The SDK also ships a JIT analysis server snapshot that
// runs on the regular VM, so this script talks to that server directly over
// its stdio JSON protocol. CI (Linux) keeps using the real `dart analyze`.
//
// Usage (from the repo root, after `flutter pub get`):
//   dart --packages=.dart_tool/package_config.json tool/analyze.dart [dir...]
// With no args it analyzes `packages/kya_core` and `app`.
//
// Exit codes: 0 = no diagnostics, 1 = diagnostics found, 2 = tool failure.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _defaultRoots = ['packages/kya_core', 'app'];
const _timeout = Duration(minutes: 5);

Future<void> main(List<String> args) async {
  exitCode = await _run(args.isEmpty ? _defaultRoots : args);
}

Future<int> _run(List<String> rootArgs) async {
  final roots = <String>[];
  for (final r in rootArgs) {
    final dir = Directory(r).absolute;
    if (!dir.existsSync()) {
      stderr.writeln('analyze: directory not found: $r');
      return 2;
    }
    roots.add(dir.resolveSymbolicLinksSync());
  }

  final sdkDir = File(Platform.resolvedExecutable).parent.parent;
  final snapshot = File(
    '${sdkDir.path}/bin/snapshots/analysis_server.dart.snapshot',
  );
  if (!snapshot.existsSync()) {
    stderr.writeln('analyze: JIT analysis server not found at $snapshot');
    return 2;
  }

  final server = await Process.start(Platform.resolvedExecutable, [
    snapshot.path,
    '--sdk',
    sdkDir.path,
    '--client-id=kya-bnaye-tool-analyze',
  ]);
  final session = _Session(server);
  try {
    final errorsByFile = await session.analyze(roots).timeout(_timeout);
    return _report(errorsByFile);
  } on TimeoutException {
    stderr.writeln('analyze: analysis did not finish within $_timeout');
    return 2;
  } on _ServerFailure catch (e) {
    stderr.writeln('analyze: analysis server error: ${e.message}');
    return 2;
  } finally {
    await session.shutdown();
  }
}

int _report(Map<String, List<Map<String, dynamic>>> errorsByFile) {
  final cwd = '${Directory.current.resolveSymbolicLinksSync()}/';
  final issues = [
    for (final errors in errorsByFile.values)
      for (final e in errors) _Issue.fromJson(e, stripPrefix: cwd),
  ]..sort();
  issues.forEach(stdout.writeln);
  stdout.writeln(
    issues.isEmpty ? 'No issues found!' : '${issues.length} issue(s) found.',
  );
  return issues.isEmpty ? 0 : 1;
}

/// One diagnostic, ordered by file, then line, then column.
class _Issue implements Comparable<_Issue> {
  _Issue.fromJson(Map<String, dynamic> json, {required String stripPrefix})
    : file = (json['location'] as Map<String, dynamic>)['file']
          .toString()
          .replaceFirst(stripPrefix, ''),
      line = (json['location'] as Map<String, dynamic>)['startLine'] as int,
      column = (json['location'] as Map<String, dynamic>)['startColumn'] as int,
      severity = json['severity'].toString().toLowerCase(),
      message = json['message'].toString(),
      code = json['code'].toString();

  final String file;
  final int line;
  final int column;
  final String severity;
  final String message;
  final String code;

  @override
  int compareTo(_Issue other) {
    final byFile = file.compareTo(other.file);
    if (byFile != 0) return byFile;
    final byLine = line.compareTo(other.line);
    return byLine != 0 ? byLine : column.compareTo(other.column);
  }

  @override
  String toString() =>
      '${severity.padLeft(7)} - $file:$line:$column - $message - $code';
}

class _ServerFailure implements Exception {
  _ServerFailure(this.message);
  final String message;
}

/// Minimal client for the analysis server's legacy stdio protocol.
class _Session {
  _Session(this._process) {
    _process.stderr.transform(utf8.decoder).listen(stderr.write);
    _process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_onLine);
    unawaited(
      _process.exitCode.then((code) {
        _fail('server exited early with code $code');
      }),
    );
  }

  final Process _process;
  final _pending = <String, Completer<Map<String, dynamic>>>{};
  final _done = Completer<void>();
  // The server re-sends the full list per file, so the latest one wins.
  final _errorsByFile = <String, List<Map<String, dynamic>>>{};
  var _nextId = 0;
  var _rootsSet = false;
  var _sawAnalyzing = false;
  var _shuttingDown = false;

  Future<Map<String, List<Map<String, dynamic>>>> analyze(
    List<String> roots,
  ) async {
    await _request('server.setSubscriptions', {
      'subscriptions': ['STATUS'],
    });
    // Set before sending: the first `isAnalyzing: true` status can arrive
    // ahead of the response to this request.
    _rootsSet = true;
    await _request('analysis.setAnalysisRoots', {
      'included': roots,
      'excluded': <String>[],
    });
    await _done.future;
    return {
      for (final e in _errorsByFile.entries)
        if (e.value.isNotEmpty) e.key: e.value,
    };
  }

  Future<void> shutdown() async {
    _shuttingDown = true;
    try {
      await _request(
        'server.shutdown',
        const {},
      ).timeout(const Duration(seconds: 5));
    } on Object {
      // Shutdown is best-effort; the process is killed below regardless.
    }
    _process.kill();
  }

  Future<Map<String, dynamic>> _request(
    String method,
    Map<String, Object> params,
  ) {
    final id = '${_nextId++}';
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _process.stdin.writeln(
      jsonEncode({'id': id, 'method': method, 'params': params}),
    );
    return completer.future;
  }

  void _onLine(String line) {
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on FormatException {
      return; // Non-protocol output (e.g. VM banners) is ignored.
    }
    if (decoded is! Map<String, dynamic>) return;

    final id = decoded['id'];
    if (id is String) {
      final completer = _pending.remove(id);
      final error = decoded['error'];
      if (error != null) {
        _fail('request failed: $error');
      } else {
        completer?.complete(
          (decoded['result'] as Map<String, dynamic>?) ?? const {},
        );
      }
      return;
    }

    final params = decoded['params'] as Map<String, dynamic>? ?? const {};
    switch (decoded['event']) {
      case 'analysis.errors':
        _errorsByFile[params['file'] as String] = [
          for (final e in params['errors'] as List<dynamic>)
            if ((e as Map<String, dynamic>)['type'] != 'TODO') e,
        ];
      case 'server.status':
        final analysis = params['analysis'] as Map<String, dynamic>?;
        if (analysis == null || !_rootsSet) return;
        if (analysis['isAnalyzing'] == true) {
          _sawAnalyzing = true;
        } else if (_sawAnalyzing && !_done.isCompleted) {
          _done.complete();
        }
      case 'server.error':
        _fail('${params['message']}\n${params['stackTrace']}');
    }
  }

  void _fail(String message) {
    if (_shuttingDown) return;
    final failure = _ServerFailure(message);
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(failure);
    }
    _pending.clear();
    if (!_done.isCompleted) _done.completeError(failure);
  }
}
