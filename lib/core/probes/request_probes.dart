import 'dart:convert';
import 'dart:typed_data';

import 'package:apix/apix.dart';

import 'demo_probe.dart';
import 'scripted_adapter.dart';

/// Requests and responses — the shapes a call comes back in.
///
/// The live CRUD and envelope features of this theme are hand-written on the
/// screen; the probes here pin what those buttons cannot show.
List<DemoProbe> requestProbes() => [
  const DemoProbe(
    id: 'requests.binary_download',
    theme: ProbeTheme.requests,
    label: 'Download a file, with its headers',
    run: _binaryDownload,
  ),
];

/// Starts like a PDF and is neither valid UTF-8 nor JSON: a body any decoding
/// on the way would damage.
final Uint8List _pdf = Uint8List.fromList([
  ...ascii.encode('%PDF-1.7\n'),
  0xE2,
  0xE3,
  0xCF,
  0xD3,
  ...ascii.encode('\n%%EOF'),
]);

Future<ProbeOutcome> _binaryDownload() async {
  final client = ApiClientFactory.create(
    baseUrl: 'https://demo.apix',
    httpClientAdapter: ScriptedAdapter(
      (options) => ScriptedResponse(
        _pdf,
        headers: {
          'content-type': ['application/pdf'],
          'content-disposition': [
            "attachment; filename=\"report.pdf\"; "
                "filename*=UTF-8''r%C3%A9sum%C3%A9-2026-08.pdf",
          ],
          'x-page-count': ['12'],
        },
      ),
    ),
  );

  final file = await client.getAndReadBytes(
    '/reports/2026-08',
    expectedContentTypes: ['application/pdf'],
  );

  final intact =
      file.bytes.length == _pdf.length &&
      Iterable<int>.generate(
        _pdf.length,
      ).every((i) => file.bytes[i] == _pdf[i]);
  return ProbeOutcome(
    headline: intact
        ? '${file.fileName} · ${file.bytes.length} bytes intact · '
              'x-page-count=${file.header('X-Page-Count')}'
        : 'REGRESSION — the bytes were altered on the way',
    detail:
        'getAndReadBytes returns the body byte for byte, with the file name '
        'from filename* and a business header — none of it reachable from the '
        'other shapes, and no dio type in sight. A portal page served as 200 '
        'would have been refused, not saved as the PDF.',
  );
}
