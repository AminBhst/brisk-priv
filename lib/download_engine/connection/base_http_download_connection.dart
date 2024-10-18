import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:brisk/download_engine/http_download_engine.dart';
import 'package:brisk/download_engine/log/logger.dart';
import 'package:brisk/download_engine/message/connection_segment_message.dart';
import 'package:brisk/download_engine/message/log_message.dart';
import 'package:brisk/download_engine/segment/segment.dart';
import 'package:brisk/download_engine/model/download_item_model.dart';
import 'package:brisk/download_engine/message/internal_messages.dart';
import 'package:brisk/download_engine/message/download_progress_message.dart';
import 'package:brisk/constants/types.dart';
import 'package:brisk/download_engine/util/temp_file_util.dart';
import 'package:brisk/util/file_util.dart';
import 'package:dartx/dartx.dart';
import 'package:path/path.dart';
import 'package:http/http.dart' as http;
import 'package:brisk/download_engine/download_status.dart';
import 'package:brisk/download_engine/download_settings.dart';

/// The base class of Http Download connection is a client-agnostic implementation
/// that makes use of the abstract method [buildClient] to initialize the client.
/// The current implementations include [MockHttpDownloadConnection] and
/// [HttpDownloadConnection]
/// TODO print errors that are thrown in this isolate
abstract class BaseHttpDownloadConnection {
  Logger? logger;

  /// Buffer containing the received bytes
  List<List<int>> buffer = [];

  /// Total temp files written by this connection (includes temp files after connection reuse)
  final List<File> connectionCachedTempFiles = [];

  /// The download progress percentage for this segment
  double downloadProgress = 0;

  // The download progress in relation to the total progress
  double totalDownloadProgress = 0;

  /// The total of received bytes for this request
  int totalConnectionReceivedBytes = 0;

  int previouslyWrittenBytesLength = 0;

  /// used to differentiate between the total bytes of a request (with a certain
  /// byte range) and the total received bytes of a connection which is the
  /// accumulation of all received byte ranges
  int totalRequestReceivedBytes = 0;

  /// The total byte length of un-flushed buffer.
  /// This value reset to 0 after each flush.
  int tempReceivedBytes = 0;

  bool supportsPause = false;

  String transferRate = "";

  String status = "Stopped";

  /// Time used to calculate the elapsed milliseconds between data chunk transfers
  int _tmpTime = DateTime.now().millisecondsSinceEpoch;

  /// Buffer used to calculate transfer rate
  List<List<int>> _transferRateChunkBuffer = [];

  double bytesTransferRate = 0;

  String estimatedRemaining = "";

  bool paused = false;

  String detailsStatus = "";

  int totalRequestWrittenBytes = 0;

  int totalConnectionWrittenBytes = 0;

  /// calculate and update transfer rate every 0.7 seconds
  static const int _transferRateCalculationWindowMillis = 700;

  /// The client used to make http requests
  late http.Client client;

  /// Threshold is currently only dynamically decided (2 times the byte transfer rate per second -
  /// and less than 8 MB)
  // static const _staticFlushThreshold = 524288;
  double _dynamicFlushThreshold = 52428800;

  double totalConnectionWriteProgress = 0;

  double totalRequestWriteProgress = 0;

  /// Determines if the user is permitted to hit the pause button or not.
  /// In order to prevent issues (mostly regarding [startButtonEnabled] property),
  /// the user is only permitted to hit the pause button only once before hitting
  /// the resume button.
  bool pauseButtonEnabled = true;

  DownloadItemModel downloadItem;

  /// Callback method used to update the engine on the current progress of the download
  DownloadProgressCallback? progressCallback;

  Segment segment;

  int connectionNumber;

  int previousBufferEndByte = 0;

  /// Connection retry
  int lastResponseTimeMillis = DateTime.now().millisecondsSinceEpoch;

  Timer? connectionResetTimer;

  int _retryCount = 0;

  bool _isWritingTempFile = false;

  ConnectionSettings settings;

  BaseHttpDownloadConnection({
    required this.downloadItem,
    required this.segment,
    required this.connectionNumber,
    required this.settings,
  });

  /// Starts the download request.
  /// [progressCallback] is used to let the provider know that the values are
  /// changed so that it calls notify listeners which can be used to display its live progress.
  /// TODO Correct the received bytes when correcting temp bytes (never allow it to go beyond the required bytes)
  void start(
    DownloadProgressCallback progressCallback, {
    bool connectionReset = false,
    bool reuseConnection = false,
  }) {
    try {
      doStart(
        progressCallback,
        connectionReset: connectionReset,
        reuseConnection: reuseConnection,
      );
    } catch (e) {
      logger?.error("Failed to start! ${e.toString()}");
    }
  }

  /// TODO do not reInit client when the connection was not terminated
  /// TODO Fix: The main status shows complete then connecting then complete and so on
  void doStart(
    DownloadProgressCallback progressCallback, {
    bool connectionReset = false,
    bool reuseConnection = false,
  }) {
    _initTempFilesCache();
    initLogger();
    logger?.info(
      "Starting download for segment $startByte - $endByte with "
      "reuseConnection: $reuseConnection "
      "connectionReset: $connectionReset",
    );
    final startNotAllowed = isStartNotAllowed(connectionReset, reuseConnection);
    if (reuseConnection) {
      _resetStatus();
    }

    if (startNotAllowed) {
      logger?.info(
        "Start is not allowed for connection $connectionNumber!"
        "status: $status detailsStatus: $detailsStatus paused: $paused",
      );
      return;
    }
    // _runConnectionResetTimer(); /// TODO uncomment
    if (_isDownloadCompleted()) {
      logger?.info("Download is already completed! skipping...");
      _setDownloadComplete();
      _notifyProgress();
      return;
    }
    logger?.info("Download is incomplete. starting a new download request...");
    _init(connectionReset, progressCallback, reuseConnection);
    _notifyProgress();

    final request = buildDownloadRequest(reuseConnection);
    sendDownloadRequest(request);
  }

  void _resetStatus() {
    downloadProgress = 0;
    totalRequestWriteProgress = 0;
    tempReceivedBytes = 0;
    totalRequestWrittenBytes = 0;
    totalRequestReceivedBytes = 0;
    detailsStatus = DownloadStatus.connecting;
    previousBufferEndByte = 0;
  }

  void _init(
    bool connectionReset,
    DownloadProgressCallback progressCallback,
    bool reuseConnection,
  ) {
    detailsStatus =
        connectionReset ? DownloadStatus.resetting : DownloadStatus.connecting;
    status = detailsStatus;
    this.progressCallback = progressCallback;
    // if (!reuseConnection) {
    _initClient();
    // }
    paused = false;
    totalRequestReceivedBytes = 0;
  }

  http.Request buildDownloadRequest(bool reuseConnection) {
    final request = http.Request('GET', Uri.parse(downloadItem.downloadUrl));
    logger?.info("Setting request headers...");
    _setRequestHeaders(request, reuseConnection);
    return request;
  }

  void sendDownloadRequest(http.Request request) {
    try {
      final response = client.send(request);
      response.asStream().cast<http.StreamedResponse>().listen((response) {
        response.stream.listen(
          _processChunk,
          onDone: _onDownloadComplete,
          onError: _onError,
        );
      }).onError(_onError);
    } catch (e) {
      _onError(e);
      _notifyProgress();
    }
  }

  void _setDownloadComplete() {
    pauseButtonEnabled = true;
    downloadProgress = 1;
    totalConnectionWriteProgress = 1;
    detailsStatus = DownloadStatus.connectionComplete;
    final totalExistingLength = getTotalWrittenBytesLength();
    totalDownloadProgress = totalExistingLength / downloadItem.contentLength;
  }

  void _updateDownloadProgress() {
    downloadProgress = totalRequestReceivedBytes / segment.length;
    totalDownloadProgress =
        totalConnectionReceivedBytes / downloadItem.contentLength;
    if (downloadProgress > 1) {
      final excessBytes = totalConnectionReceivedBytes - segment.length;
      totalDownloadProgress = (totalConnectionReceivedBytes - excessBytes) /
          downloadItem.contentLength;
    }
  }

  // TODO USE THIS
  void _runConnectionResetTimer() {
    if (connectionResetTimer != null) return;
    connectionResetTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (connectionRetryAllowed) {
        resetConnection();
        _retryCount++;
      }
    });
  }

  void resetConnection() {
    client.close();
    totalConnectionReceivedBytes =
        totalConnectionReceivedBytes - tempReceivedBytes;
    totalRequestReceivedBytes = totalConnectionReceivedBytes;
    _clearBuffer();
    _dynamicFlushThreshold = double.infinity;
    start(progressCallback!, connectionReset: true);
  }

  void cancel({bool failure = false}) {
    client.close();
    _cancelConnectionResetTimer();
    _clearBuffer();
    final status = failure ? DownloadStatus.failed : DownloadStatus.canceled;
    _updateStatus(status);
    detailsStatus = status;
    _notifyProgress();
  }

  void _cancelConnectionResetTimer() {
    connectionResetTimer?.cancel();
    connectionResetTimer = null;
  }

  /// TODO don't create a new obj every time
  void _notifyProgress({bool completionSignal = false}) {
    final data = DownloadProgressMessage.loadFromHttpDownloadRequest(this);
    data.completionSignal = completionSignal;
    progressCallback!(data);
  }

  /// Sets the request byte range header to achieve resume functionality if the
  /// parts of the file has already been written.
  /// The length of the existing file is set to the start value and the TODO FIX DOC (SEGMENTED)
  /// content-length retrieved from the HEAD Request is set to the end value.
  /// returns whether the segment download has already been finished or not.
  /// TODO move variable sets outside of this method
  void _setRequestHeaders(http.Request request, bool reuseConnection) {
    tempDirectory.createSync(recursive: true);
    final reqStartByte = reuseConnection ? this.startByte : _getNewStartByte();
    logger?.info("newStartByte: $reqStartByte oldStartByte: ${this.startByte}");
    request.headers.addAll({
      "Range": "bytes=$reqStartByte-${this.endByte}",
      // "Keep-Alive": "timeout=5, max=1",
      // TODO handle request time-out response (We should reinitialize client)
      "User-Agent":
          "Mozilla/5.0 (Windows NT 6.1; Trident/7.0; rv:11.0) like Gecko;",
    });
    logger?.info("Request headers: ${request.headers}");
    totalRequestWriteProgress = downloadProgress;
    logger?.info("=========== Total connection temp files ===========");
    getConnectionTempFilesSorted().forEach(
      (f) => logger?.info(basename(f.path)),
    );
    logger?.info("===================================================");
    final totalExistingLength = getTotalWrittenBytesLength();
    totalRequestReceivedBytes = getTotalWrittenBytesLength(
      thisByteRangeOnly: true,
    );
    downloadProgress = totalRequestReceivedBytes / segment.length;
    totalConnectionReceivedBytes = totalExistingLength;
    totalConnectionWriteProgress += previousBufferEndByte;
    totalRequestWrittenBytes = totalRequestReceivedBytes;
    totalConnectionWrittenBytes = totalExistingLength;
    totalDownloadProgress =
        totalConnectionReceivedBytes / downloadItem.contentLength;
    logger?.info(
      "totalRequestReceivedBytes: $totalRequestReceivedBytes  "
      "totalConnectionReceivedBytes: $totalConnectionReceivedBytes "
      "totalConnectionWriteProgress: $totalConnectionWriteProgress "
      "totalRequestWrittenBytes: $totalRequestWrittenBytes "
      "totalConnectionWrittenBytes: $totalConnectionWrittenBytes "
      "totalDownloadProgress: $totalDownloadProgress",
    );
    if (reqStartByte == this.startByte) {
      previousBufferEndByte = 0;
    } else {
      previousBufferEndByte = reqStartByte - this.startByte;
      if (previousBufferEndByte < 0) {
        logger?.error("Previous buffer endByte is a negative number!");
      }
    }
    _notifyProgress();
  }

  int _getNewStartByte() {
    final tempFiles = getConnectionTempFilesSorted(thisByteRangeOnly: true);
    if (tempFiles.isEmpty) {
      logger?.info(
        "startByte::$startByte endBytes::$endByte ==> temp files were empty",
      );
      return this.startByte;
    }
    final lastFileName = basename(tempFiles.last.path);
    final newStartByte = getEndByteFromTempFileName(lastFileName) + 1;
    logger?.info(
      "GetNewStartByte:: bytesRange: $startByte-$endByte is $newStartByte. TempFiles ==> ",
    );
    tempFiles.forEach((f) => logger?.info(basename(f.path)));
    return getEndByteFromTempFileName(lastFileName) + 1;
  }

  void _processChunk(List<int> chunk) {
    try {
      _doProcessChunk(chunk);
    } catch (e) {
      if (e is http.ClientException && paused) return;
      logger?.info("Error! $e");
      client.close();
      _clearBuffer();
    }
  }

  /// Processes each data [chunk] in [streamedResponse].
  /// Once the [tempReceivedBytes] hits the [_dynamicFlushThreshold], the buffer is
  /// flushed to the disk. This process continues until the download has been
  /// finished. The buffer will be emptied after each flush
  void _doProcessChunk(List<int> chunk) {
    if (chunk.isEmpty) return;
    _updateStatus(DownloadStatus.downloading);
    lastResponseTimeMillis = _nowMillis;
    pauseButtonEnabled = downloadItem.supportsPause;
    detailsStatus = transferRate;
    _calculateTransferRate(chunk);
    _calculateDynamicFlushThreshold();
    buffer.add(chunk);
    _updateReceivedBytes(chunk);
    _updateDownloadProgress();
    if (receivedBytesExceededEndByte) {
      _onByteExceeded();
      _notifyProgress();
      return;
    }
    if (receivedBytesMatchEndByte) {
      _onByteExactMatch();
      return;
    }
    if (tempReceivedBytes > _dynamicFlushThreshold) {
      _flushBuffer();
    }
    _notifyProgress();
  }

  void _onByteExactMatch() {
    logger?.info(
      "Received bytes match endByte! "
      "closing the connection and flushing the buffer...",
    );
    if (this.endByte == downloadItem.contentLength) {
      logger?.info("Connection corresponds to the last segment!");
      totalRequestReceivedBytes += 3;
      totalConnectionReceivedBytes += 3;
      totalDownloadProgress =
          totalConnectionReceivedBytes / downloadItem.contentLength;
    }
    client.close();
    _flushBuffer();
    _setDownloadComplete();
    _notifyProgress();
  }

  void _onByteExceeded() {
    logger?.info("Received bytes exceeded endByte");
    client.close();
    _flushBuffer();
    _fixTempFiles();
    _setDownloadComplete();
  }

  /// Flushes the buffer containing the received bytes to the disk.
  /// All flush operations write temp files with their corresponding connection number
  /// and byte ranges
  /// e.g. 0#100-2500 => connectionNumber#startByte-endByte
  void _flushBuffer() {
    if (buffer.isEmpty) return;
    _isWritingTempFile = true;
    final bytes = _writeToUin8List(buffer);
    final filePath = join(
      tempDirectory.path,
      "${connectionNumber}#${tempFileStartByte}-${tempFileEndByte}",
    );
    previousBufferEndByte += bytes.lengthInBytes;
    final file = File(filePath)
      ..writeAsBytesSync(mode: FileMode.writeOnly, bytes);

    if (tempFileStartByte > downloadItem.contentLength) {
      logger?.warn(
          "Attention:: Extremely Weird:: conn$connectionNumber::$segment "
          "byteExceed?$receivedBytesExceededEndByte "
          "TotalReqRec:$totalRequestReceivedBytes "
          "prevbufs:$previousBufferEndByte");
    }
    connectionCachedTempFiles.add(file);
    logger?.info(
      newLine: false,
      "FlushBuffer for segment $startByte-$endByte ::${basename(filePath)}",
    );
    _onTempFileWriteComplete(file);
    _clearBuffer();
    sendLogBuffer();
  }

  void _onTempFileWriteComplete(File file) {
    totalRequestWrittenBytes += file.lengthSync();
    totalConnectionWriteProgress =
        totalConnectionWrittenBytes / downloadItem.contentLength;
    totalRequestWriteProgress = totalRequestReceivedBytes / segment.length;
    if (totalRequestWriteProgress == 1) {
      detailsStatus = DownloadStatus.connectionComplete;
    }
    _isWritingTempFile = false;
  }

  // TODO add doc
  void _fixTempFiles() {
    logger?.info("Fixing temp files with segment $startByte-$endByte");
    final tempFiles = getConnectionTempFilesSorted(thisByteRangeOnly: true);
    logger?.info("================ Temp Files ===================");
    tempFiles.forEach((e) => logger?.info(basename(e.path)));
    logger?.info("===============================================");
    List<File> tempFilesToDelete = [];
    Uint8List? newBufferToWrite;
    int? newBufferStartByte;
    for (var file in tempFiles) {
      final fileName = basename(file.path);
      final tempStartByte = getStartByteFromTempFileName(fileName);
      final tempEndByte = getEndByteFromTempFileName(fileName);
      if (this.endByte < tempStartByte) {
        logger?.info("Temp file to delete: ${basename(file.path)}");
        tempFilesToDelete.add(file);
        continue;
      }
      if (this.endByte < tempEndByte) {
        logger?.info("File to cut: ${basename(file.path)}");
        newBufferStartByte = tempStartByte;
        final bufferCutLength = this.endByte - tempStartByte + 1;
        newBufferToWrite = file.safeReadSync(bufferCutLength);
        tempFilesToDelete.add(file);
      }
    }

    for (final file in tempFilesToDelete) {
      totalConnectionReceivedBytes -= file.lengthSync();
      file.deleteSync();
      connectionCachedTempFiles.removeWhere((f) => f.path == file.path);
      logger?.info("Deleted file ${basename(file.path)}");
    }

    if (newBufferToWrite != null) {
      final newBufferEndByte =
          newBufferStartByte! + newBufferToWrite.lengthInBytes - 1;
      final newTempFilePath = join(
        tempDirectory.path,
        "${connectionNumber}#${newBufferStartByte}-${newBufferEndByte}",
      );
      logger?.info("Writing file ${basename(newTempFilePath)}");
      final file = File(newTempFilePath)..writeAsBytesSync(newBufferToWrite);
      connectionCachedTempFiles.add(file);
      totalConnectionReceivedBytes += newBufferToWrite.lengthInBytes;
      totalRequestWrittenBytes = segment.length;
    }
    totalDownloadProgress =
        totalConnectionReceivedBytes / downloadItem.contentLength;
    logger?.info("TempFiles fix complete");
  }

  /// TODO improve: we could send the newEndByte in this method instead of doing another IO in [_getNewStartByte]
  bool _isDownloadCompleted() {
    final tempFiles = getConnectionTempFilesSorted(thisByteRangeOnly: true);
    if (tempFiles.isEmpty) {
      logger?.info(
          "IsDownloadComplete::$connectionNumber::S$startByte-E$endByte ==> EMPTY");
      return false;
    }

    final str = StringBuffer(
        "IsDownloadComplete::$connectionNumber::S$startByte-E$endByte ==> ");
    tempFiles.forEach((e) {
      str.writeln(basename(e.path));
    });
    logger?.info(str.toString());
    if (tempFiles.length == 1) {
      final file = basename(tempFiles[0].path);
      final fileEndByte = getEndByteFromTempFileName(file);
      if (this.endByte == downloadItem.contentLength &&
          fileEndByte == downloadItem.contentLength - 1) {
        return true;
      }
      if (this.endByte != fileEndByte) {
        return false;
      }
    }
    for (var i = 0; i < tempFiles.length; i++) {
      if (i == 0) continue;
      final file = tempFiles[i];
      final prevFile = tempFiles[i - 1];
      final fileStartByte = getStartByteFromTempFile(file);
      final fileEndByte = getEndByteFromTempFile(file);
      final prevFileEndByte = getEndByteFromTempFile(prevFile);
      final isLastFile = i == tempFiles.length - 1;
      if (isLastFile && fileEndByte == this.endByte - 1) {
        logger?.info("ATTENTION:: ConnNum$connectionNumber is weird");
      }
      if (fileStartByte != prevFileEndByte + 1) {
        logger?.info(
            "IsDownloadComplete::Found inconsistent ranges : ${basename(prevFile.path)} != ${basename(file.path)}");
      }
      if (isLastFile) {
        if (this.endByte == downloadItem.contentLength &&
            fileEndByte == downloadItem.contentLength - 1) {
          return true;
        }
        if (fileEndByte != this.endByte) {
          return false;
        }
      }
    }
    return true;
  }

  void _calculateTransferRate(List<int> chunk) {
    _transferRateChunkBuffer.add(chunk);
    final nowMillis = _nowMillis;
    if (_tmpTime + _transferRateCalculationWindowMillis > nowMillis) return;
    var timeBefore = _tmpTime;
    _tmpTime = nowMillis;
    int len = 0;
    for (var element in _transferRateChunkBuffer) {
      len += element.length;
    }
    transferRate = _getTransferRateStr(timeBefore, len);
    _transferRateChunkBuffer = [];
  }

  String _getTransferRateStr(int timeBefore, int len) {
    final elapsedSec = (_tmpTime - timeBefore) / 1000;
    if (elapsedSec <= 0) return "";
    final speedInMegaBytes = (len / 1048576) / elapsedSec;
    final speedInKiloBytes = (len / 1024) / elapsedSec;
    bytesTransferRate = len / elapsedSec;

    if (speedInMegaBytes > 1) {
      return '${speedInMegaBytes.toStringAsFixed(2)} MB/s';
    } else if (speedInKiloBytes > 1) {
      return '${speedInKiloBytes.toStringAsFixed(2)} KB/s';
    } else {
      return '${bytesTransferRate.toStringAsFixed(2)} B/s';
    }
  }

  void _calculateDynamicFlushThreshold() {
    const double eightMegaBytes = 8388608;
    _dynamicFlushThreshold = bytesTransferRate * 2 < eightMegaBytes
        ? bytesTransferRate * 2
        : eightMegaBytes;
  }

  void pause(DownloadProgressCallback? progressCallback) {
    if (_isWritingTempFile) {
      logger?.info("Tried to pause while writing temp files!");
    }
    paused = true;
    logger?.info("Paused connection $connectionNumber");
    _cancelConnectionResetTimer();
    if (progressCallback != null) {
      this.progressCallback = progressCallback;
    }
    _flushBuffer();
    _updateStatus(DownloadStatus.paused);
    detailsStatus = DownloadStatus.paused;
    client.close();
    pauseButtonEnabled = false;
    _notifyProgress();
  }

  /// TODO handle cases where a segment is refreshed while the download has already finished!
  void refreshSegment(Segment segment, {bool reuseConnection = false}) {
    final prevEndByte = this.endByte;
    logger?.info(
        "Refresh requested for connection $connectionNumber with status ${this.status} ${this.detailsStatus}");
    logger?.info(
        "Inside refresh segment conn num $connectionNumber :: ${this.startByte} - ${this.endByte} ");
    logger?.info(
        "Inside refresh segment conn num $connectionNumber :: new ${segment.startByte} - ${segment.endByte} ");
    final message = ConnectionSegmentMessage(
      downloadItem: downloadItem,
      requestedSegment: segment,
      reuseConnection: reuseConnection,
    );
    if (this.status == DownloadStatus.connectionComplete) {
      message.internalMessage = message_refreshSegmentRefused(reuseConnection);
      progressCallback!.call(message);
      logger?.info(
          "Connection :: $connectionNumber ::::: Refresh segment :::: requested : ($segment) :::: validStart "
          ": ${message.validNewStartByte} , validEnd : ${message.validNewEndByte} :: message: ${message.internalMessage}");
      return;
    }
    if (this.startByte + totalRequestReceivedBytes >= segment.endByte) {
      message.internalMessage = InternalMessage.OVERLAPPING_REFRESH_SEGMENT;
      final newEndByte = _newValidRefreshSegmentEndByte;
      final validNewEndByte = prevEndByte;
      final validNewStartByte = this.startByte;
      if (newEndByte > 0 &&
          segment.startByte < newEndByte &&
          validNewStartByte +
                  HttpDownloadEngine.MINIMUM_DOWNLOAD_SEGMENT_LENGTH <
              validNewEndByte) {
        this.segment = Segment(segment.startByte, newEndByte);
        message
          ..validNewStartByte = this.endByte + 1
          ..validNewEndByte = prevEndByte
          ..refreshedStartByte = this.startByte
          ..refreshedEndByte = this.endByte;
      } else {
        message.internalMessage =
            message_refreshSegmentRefused(reuseConnection);
      }
      progressCallback!.call(message);
      logger?.info(
        "Refresh segment:: requested : ($segment) :: validStart "
        ": ${message.validNewStartByte} , validEnd : ${message.validNewEndByte} "
        ":: message: ${message.internalMessage}",
      );
      logger?.info("Refresh Segment :: ${this.startByte} ${this.endByte}");
      return;
    }
    if (segment.startByte >= segment.endByte ||
        segment.startByte + 1 >= segment.endByte) {
      message.internalMessage = InternalMessage.REFRESH_SEGMENT_REFUSED;
      progressCallback!.call(message);
      return;
    }
    this.segment = segment;
    message
      ..internalMessage = InternalMessage.REFRESH_SEGMENT_SUCCESS
      ..refreshedStartByte = this.startByte
      ..refreshedEndByte = this.endByte;
    // TODO properly handle the status conditions
    progressCallback!.call(message);
    logger?.info(
      "Refresh segment :: requested : ($segment) :: validStart "
      ": ${message.validNewStartByte} , validEnd : ${message.validNewEndByte} "
      ":: message: ${message.internalMessage}",
    );
    logger?.info("Refresh Segment :: ${this.startByte} - ${this.endByte}");
    _notifyProgress();
    return;
  }

  int get _newValidRefreshSegmentEndByte {
    final splitByte =
        ((this.endByte - (this.startByte + totalRequestReceivedBytes)) / 2)
            .floor();
    return splitByte <= 0
        ? -1
        : splitByte + this.startByte + totalRequestReceivedBytes;
  }

  void _clearBuffer() {
    buffer.clear();
    tempReceivedBytes = 0;
  }

  /// Flushes the remaining bytes in the buffer and completes the download.
  void _onDownloadComplete() {
    if (paused) return;
    bytesTransferRate = 0;
    downloadProgress = totalRequestReceivedBytes / segment.length;
    totalDownloadProgress =
        totalConnectionReceivedBytes / downloadItem.contentLength;
    _flushBuffer();
    detailsStatus = DownloadStatus.connectionComplete;
    logger?.info("Download complete with completion signal");
    logger?.info("connection progress : $downloadProgress");
    _setDownloadComplete();
    _notifyProgress(completionSignal: true);
  }

  void _onError(dynamic error, [dynamic s]) {
    try {
      client.close();
    } catch (e) {}
    _clearBuffer();
    _notifyProgress();
    if (!(error is http.ClientException && paused)) {
      logger?.error("connection $connectionNumber error : $error \n $s");
      throw error;
    }
  }

  Uint8List _writeToUin8List(List<List<int>> chunks) {
    int start = 0;
    var len = 0;
    chunks.forEach((c) => len += c.length);
    final bytes = Uint8List(len);
    for (var chunk in chunks) {
      bytes.setRange(start, start + chunk.length, chunk);
      start += chunk.length;
    }
    return bytes;
  }

  void _updateReceivedBytes(List<int> chunk) {
    totalConnectionReceivedBytes += chunk.length;
    totalRequestReceivedBytes += chunk.length;
    tempReceivedBytes += chunk.length;
  }

  void _updateStatus(String status) {
    this.status = status;
    downloadItem.status = this.status;
  }

  bool isStartNotAllowed(bool connectionReset, bool connectionReuse) {
    if (startByte >= endByte ||
        startByte > downloadItem.contentLength ||
        endByte > downloadItem.contentLength) {
      logger?.warn("Invalid requested byte ranges $segment. Skipping...");
      return true;
    }
    if (connectionReuse) {
      return false;
    }
    final isAllowed = (paused && _isWritingTempFile) ||
        (!paused && downloadProgress > 0) ||
        downloadItem.status == DownloadStatus.connectionComplete ||
        status == DownloadStatus.connectionComplete ||
        detailsStatus == DownloadStatus.connectionComplete;

    return isAllowed && !connectionReset;
  }

  int getTotalWrittenBytesLength({bool thisByteRangeOnly = false}) {
    if (connectionCachedTempFiles.isEmpty) {
      return 0;
    }

    final connectionFiles = getConnectionTempFilesSorted();
    if (connectionFiles.isEmpty) {
      return 0;
    }

    var fileNames = connectionFiles.map((f) => basename(f.path));
    if (thisByteRangeOnly) {
      fileNames = fileNames
          .where(
            (fileName) =>
                fileNameToSegment(fileName).isInRangeOfOther(this.segment),
          )
          .toList();
    }

    if (fileNames.isEmpty) {
      return 0;
    }

    if (fileNames.length == 1) {
      return getTempFileLength(fileNames.first);
    }

    return fileNames
        .reduce((f1, f2) => addTempFilesLength_reduce(f1, f2).toString())
        .toInt();
  }

  List<File> getConnectionTempFilesSorted({bool thisByteRangeOnly = false}) {
    if (connectionCachedTempFiles.isEmpty) {
      return [];
    }
    if (!thisByteRangeOnly) {
      return connectionCachedTempFiles;
    }
    return connectionCachedTempFiles
        .where(
          (file) => isTempFileInByteRange(
            file,
            this.startByte,
            this.endByte,
          ),
        )
        .toList()
      ..sort(sortByByteRanges);
  }

  void _initTempFilesCache() {
    if (connectionCachedTempFiles.isNotEmpty || !tempDirectory.existsSync()) {
      return;
    }
    connectionCachedTempFiles.addAll(
      tempDirectory
          .listSync()
          .map((f) => f as File)
          .where((file) => tempFileBelongsToConnection(file, connectionNumber))
          .toList(),
    );
  }

  /// The abstract buildClient method used for implementations of download connections.
  /// namely, [HttpDownloadConnection] and [MockHttpDownloadConnection]
  http.Client buildClient();

  void _initClient() {
    this.client = buildClient();
  }

  int get _nowMillis => DateTime.now().millisecondsSinceEpoch;

  /// e.g. 0#0-50, 0#51-150, 1#151-400 and so on...
  String get tempFileName =>
      "${connectionNumber}#${tempFileStartByte}-${tempFileEndByte}";

  /// The end byte of the buffer with respect to the target file (The file which will be built after download completes).
  int get tempFileEndByte =>
      startByte + previousBufferEndByte + tempReceivedBytes - 1;

  /// The start byte of the buffer with respect to the target file
  int get tempFileStartByte => startByte + previousBufferEndByte;

  Directory get tempDirectory => Directory(join(
        settings.baseTempDir.path,
        downloadItem.uid.toString(),
      ));

  /// Sends the log buffer to the engine to be flushed to disk
  void sendLogBuffer() {
    if (logger == null) return;
    final logMessage = LogMessage(logger!.logBuffer.toString(), downloadItem);
    progressCallback!(logMessage);
    logger!.logBuffer.clear();
  }

  void initLogger() {
    if (logger != null) return;
    logger = Logger(
      downloadUid: downloadItem.uid,
      logBaseDir: settings.baseTempDir,
      connectionNumber: this.connectionNumber,
    );
  }

  /// Determines if the user is permitted to hit the start (Resume) button or not
  bool get isStartButtonEnabled => paused;

  bool get receivedBytesMatchEndByte =>
      this.startByte + totalRequestReceivedBytes == this.endByte;

  bool get receivedBytesExceededEndByte =>
      this.startByte + totalRequestReceivedBytes >
      this.endByte; // TODO what if equals

  int get startByte => segment.startByte;

  int get endByte => segment.endByte;

  bool get connectionRetryAllowed =>
      lastResponseTimeMillis + settings.connectionRetryTimeout < _nowMillis &&
      !_isWritingTempFile &&
      status != DownloadStatus.paused &&
      status != DownloadStatus.connectionComplete &&
      detailsStatus != DownloadStatus.canceled &&
      detailsStatus != DownloadStatus.connectionComplete &&
      (_retryCount < settings.maxConnectionRetryCount ||
          settings.maxConnectionRetryCount == -1);
}
