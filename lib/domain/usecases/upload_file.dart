import 'dart:io';

import 'package:apix/apix.dart' hide Failure;

import '../../core/error/failures.dart';
import '../../core/error/wrap_exceptions.dart';
import '../../data/datasources/remote_data_source.dart';

/// Use case for uploading a file using apix's [MultipartInterceptor].
///
/// The interceptor auto-detects the `File` value, switches the request to
/// `multipart/form-data` and converts the `File` to a `MultipartFile`.
/// Returns the echo response from the server (JSONPlaceholder echoes the
/// payload back as JSON, which is enough to verify the upload roundtrip).
class UploadFile {
  final RemoteDataSource _dataSource;

  UploadFile(this._dataSource);

  Future<Result<Map<String, dynamic>, Failure>> call(
    File file, {
    String label = 'demo',
  }) {
    return wrapExceptions(() => _dataSource.uploadFile(file, label: label));
  }
}
