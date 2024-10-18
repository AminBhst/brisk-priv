import 'dart:io';

import 'package:brisk/constants/file_type.dart';
import 'package:brisk/download_engine/download_command.dart';
import 'package:brisk/db/hive_util.dart';
import 'package:brisk/download_engine/download_status.dart';
import 'package:brisk/download_engine/segment/segment.dart';
import 'package:brisk/download_engine/util/temp_file_util.dart';
import 'package:brisk/model/download_item.dart';
import 'package:brisk/model/file_metadata.dart';
import 'package:brisk/provider/pluto_grid_check_row_provider.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/util/download_addition_ui_util.dart';
import 'package:path/path.dart';
import 'package:brisk/download_engine/model/download_item_model.dart';
import 'package:brisk/provider/pluto_grid_util.dart';
import 'package:brisk/util/responsive_util.dart';
import 'package:brisk/widget/base/checkbox_confirmation_dialog.dart';
import 'package:brisk/widget/download/add_url_dialog.dart';
import 'package:brisk/widget/top_menu/top_menu_button.dart';
import 'package:flutter/material.dart';
import 'package:pluto_grid/src/model/pluto_row.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../download_engine/client/mock_http_client_proxy.dart';
import '../../provider/download_request_provider.dart';
import '../../util/file_util.dart';
import '../queue/add_to_queue_window.dart';

class TopMenu extends StatefulWidget {
  @override
  State<TopMenu> createState() => _TopMenuState();
}

class _TopMenuState extends State<TopMenu> {
  String url = '';

  late DownloadRequestProvider provider;

  TextEditingController txtController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    provider = Provider.of<DownloadRequestProvider>(context, listen: false);
    final topMenuTheme =
        Provider.of<ThemeProvider>(context).activeTheme.topMenuTheme;
    Provider.of<PlutoGridCheckRowProvider>(context);
    final size = MediaQuery.of(context).size;
    return Container(
      width: resolveWindowWidth(size),
      height: 70,
      color: topMenuTheme.backgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: TopMenuButton(
              onTap: () => showDialog(
                context: context,
                builder: (_) => AddUrlDialog(),
                barrierDismissible: false,
              ),
              title: 'Add URL',
              icon: Icon(
                Icons.add_rounded,
                color: topMenuTheme.addUrlColor.iconColor,
              ),
              onHoverColor: topMenuTheme.addUrlColor.hoverBackgroundColor,
              textColor: topMenuTheme.addUrlColor.textColor,
            ),
          ),
          // TopMenuButton(
          //   /// TODO comment in production
          //   onTap: () => onMockDownloadPressed(context),
          //   title: 'Mock',
          //   icon: const Icon(Icons.not_started_outlined, color: Colors.red),
          //   onHoverColor: Colors.red,
          // ),
          TopMenuButton(
            onTap: isDownloadButtonEnabled ? onDownloadPressed : null,
            title: 'Download',
            icon: Icon(
              Icons.download_rounded,
              color: isDownloadButtonEnabled
                  ? topMenuTheme.downloadColor.iconColor
                  : Color.fromRGBO(79, 79, 79, 0.5),
            ),
            onHoverColor: topMenuTheme.downloadColor.hoverBackgroundColor,
            textColor: isDownloadButtonEnabled
                ? topMenuTheme.downloadColor.textColor
                : Color.fromRGBO(79, 79, 79, 1),
          ),
          TopMenuButton(
            onTap: isPauseButtonEnabled ? onStopPressed : null,
            title: 'Stop',
            icon: Icon(
              Icons.stop_rounded,
              color: isPauseButtonEnabled
                  ? topMenuTheme.stopColor.iconColor
                  : Color.fromRGBO(79, 79, 79, 0.5),
            ),
            onHoverColor: topMenuTheme.stopColor.hoverBackgroundColor,
            textColor: isPauseButtonEnabled
                ? topMenuTheme.stopColor.textColor
                : Color.fromRGBO(79, 79, 79, 1),
          ),
          // TopMenuButton(
          //   onTap: onStopAllPressed,
          //   title: 'Stop All',
          //   icon: Icon(
          //     Icons.stop_circle_outlined,
          //     color: topMenuTheme.stopAllColor.iconColor,
          //   ),
          //   onHoverColor: topMenuTheme.stopAllColor.hoverBackgroundColor,
          //   textColor: topMenuTheme.stopAllColor.textColor,
          // ),
          TopMenuButton(
            onTap: PlutoGridUtil.selectedRowExists
                ? () => onRemovePressed(context)
                : null,
            title: 'Remove',
            icon: Icon(
              Icons.delete,
              color: PlutoGridUtil.selectedRowExists
                  ? topMenuTheme.removeColor.iconColor
                  : disabledButtonColor,
            ),
            onHoverColor: topMenuTheme.removeColor.hoverBackgroundColor,
            textColor: PlutoGridUtil.selectedRowExists
                ? topMenuTheme.removeColor.textColor
                : disabledButtonTextColor,
          ),
          TopMenuButton(
            onTap: PlutoGridUtil.selectedRowExists
                ? () => onAddToQueuePressed(context)
                : null,
            title: 'Add To Queue',
            icon: Icon(
              Icons.queue,
              color: PlutoGridUtil.selectedRowExists
                  ? topMenuTheme.addToQueueColor.iconColor
                  : disabledButtonColor,
            ),
            fontSize: 10.5,
            onHoverColor: topMenuTheme.addToQueueColor.hoverBackgroundColor,
            textColor: PlutoGridUtil.selectedRowExists
                ? topMenuTheme.addToQueueColor.textColor
                : disabledButtonTextColor,
          ),
          SizedBox(width: 5),
          // Container(color: Colors.white, width: 1, height: 40),
          TopMenuButton(
            title: 'Get Extension',
            fontSize: 11,
            icon: Icon(
              Icons.extension,
              color: topMenuTheme.extensionColor.iconColor,
            ),
            onTap: () => launchUrlString(
              'https://github.com/AminBhst/brisk-browser-extension',
            ),
            onHoverColor: topMenuTheme.extensionColor.hoverBackgroundColor,
            textColor: topMenuTheme.extensionColor.textColor,
          ),
          SizedBox(width: 5),
          // Container(color: Colors.white, width: 1, height: 40),
          // TopMenuButton(
          //   title: 'Build',
          //   icon: Icon(
          //     Icons.extension,
          //     color: Colors.red,
          //   ),
          //   onTap: () {
          //     final dlitem = HiveUtil.instance.downloadItemsBox.getAt(0);
          //     final itemModel = DownloadItemModel.fromDownloadItem(dlitem!);
          //     FileUtil.doooo(itemModel.uid);
          //     assembleFile(
          //         itemModel, SettingsCache.temporaryDir, SettingsCache.saveDir);
          //     print("DONE");
          //   },
          // ),
        ],
      ),
    );
  }

  Color get disabledButtonColor => Color.fromRGBO(79, 79, 79, 0.5);

  Color get disabledButtonTextColor => Color.fromRGBO(79, 79, 79, 1);

  void onMockDownloadPressed(BuildContext context) async {
    final item = DownloadItem.fromUrl(mockDownloadUrl);
    item.contentLength = 65945577;
    item.fileName = "Mozilla.Firefox.zip";
    item.fileType = DLFileType.compressed.name;
    item.supportsPause = true;
    final fileInfo = FileInfo(
      item.supportsPause,
      item.fileName,
      item.contentLength,
    );
    DownloadAdditionUiUtil.addDownload(item, fileInfo, context, false);
  }

  void onDownloadPressed() async {
    PlutoGridUtil.doOperationOnCheckedRows((id, _) {
      provider.executeDownloadCommand(id, DownloadCommand.start);
    });
  }

  void onStopPressed() {
    PlutoGridUtil.doOperationOnCheckedRows((id, _) {
      provider.executeDownloadCommand(id, DownloadCommand.pause);
    });
  }

  void onStopAllPressed() {
    provider.downloads.forEach((id, _) {
      provider.executeDownloadCommand(id, DownloadCommand.pause);
    });
  }

  void onAddToQueuePressed(BuildContext context) {
    if (PlutoGridUtil.plutoStateManager!.checkedRows.isEmpty) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddToQueueWindow(),
    );
  }

  void onRemovePressed(BuildContext context) {
    final stateManager = PlutoGridUtil.plutoStateManager;
    if (stateManager!.checkedRows.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => CheckboxConfirmationDialog(
        onConfirmPressed: (deleteFile) {
          PlutoGridUtil.doOperationOnCheckedRows((id, row) {
            deleteOnCheckedRows(row, id, deleteFile);
          });
          stateManager.notifyListeners();
        },
        title: "Are you sure you want to delete the selected downloads?",
        checkBoxTitle: 'Delete downloaded file',
      ),
    );
  }

  void deleteOnCheckedRows(PlutoRow row, int id, bool deleteFile) {
    PlutoGridUtil.plutoStateManager!.removeRows([row]);
    FileUtil.deleteDownloadTempDirectory(id);
    provider.executeDownloadCommand(id, DownloadCommand.clearConnections);
    if (deleteFile) {
      final downloadItem = HiveUtil.instance.downloadItemsBox.get(id);
      final file = File(downloadItem!.filePath);
      if (file.existsSync()) {
        file.delete();
      }
    }
    HiveUtil.instance.downloadItemsBox.delete(id);
    HiveUtil.instance.removeDownloadFromQueues(id);
    provider.downloads.removeWhere((key, _) => key == id);
  }

  bool get isDownloadButtonEnabled {
    final selectedRowIds = PlutoGridUtil.selectedRowIds;
    final completedDownloadSelected = selectedRowIds
        .map((id) => HiveUtil.instance.downloadItemsBox.get(id))
        .toList()
        .any((download) =>
            download != null &&
            download.status == DownloadStatus.assembleComplete);
    return (selectedRowIds.isEmpty || completedDownloadSelected)
        ? false
        : (provider.downloads.values
                .where((item) => selectedRowIds.contains(item.downloadItem.id))
                .every((item) => item.buttonAvailability.startButtonEnabled) ||
            provider.downloads.values.isEmpty);
  }

  bool get isPauseButtonEnabled {
    final selectedRowIds = PlutoGridUtil.selectedRowIds;
    return (selectedRowIds.isEmpty || provider.downloads.values.isEmpty)
        ? false
        : provider.downloads.values
            .where((item) => selectedRowIds.contains(item.downloadItem.id))
            .every((item) => item.buttonAvailability.pauseButtonEnabled);
  }
}
