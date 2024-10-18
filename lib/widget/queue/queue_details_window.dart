import 'package:brisk/db/hive_util.dart';
import 'package:brisk/model/download_queue.dart';
import 'package:brisk/provider/theme_provider.dart';
import 'package:brisk/widget/base/closable_window.dart';
import 'package:brisk/widget/base/rounded_outlined_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

import '../../provider/queue_provider.dart';
import '../../util/file_util.dart';

class QueueDetailsWindow extends StatefulWidget {
  final DownloadQueue queue;

  QueueDetailsWindow({Key? key, required this.queue}) : super(key: key);

  @override
  State<QueueDetailsWindow> createState() => _QueueDetailsWindowState();
}

class _QueueDetailsWindowState extends State<QueueDetailsWindow> {
  late List<int>? downloadIds = [];

  @override
  void initState() {
    downloadIds = [...?widget.queue.downloadItemsIds];
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme =
        Provider.of<ThemeProvider>(context).activeTheme.alertDialogTheme;
    final size = MediaQuery.of(context).size;
    return ClosableWindow(
      width: 800,
      height: 500,
      backgroundColor: theme.backgroundColor,
      disableCloseButton: true,
      padding: EdgeInsets.only(top: 60),
      content: SizedBox(
        child: Column(
          children: [
            SizedBox(
              width: 600,
              height: resolveRowHeight(size),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  downloadIds == null || downloadIds!.isEmpty
                      ? Container(
                          width: 600,
                          height: resolveListHeight(size),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.fromBorderSide(
                              BorderSide(
                                  color: theme.innerContainerBorderColor),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                "assets/icons/blank.svg",
                                height: 90,
                                width: 90,
                                colorFilter: ColorFilter.mode(
                                  theme.placeHolderIconColor,
                                  BlendMode.srcIn,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                "Queue is empty",
                                style: TextStyle(
                                  color: theme.placeHolderIconColor,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          width: 600,
                          height: resolveListHeight(size),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.fromBorderSide(
                              BorderSide(color: Colors.white12),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: ReorderableListView.builder(
                              buildDefaultDragHandles: false,
                              itemBuilder: (context, index) {
                                final dl = HiveUtil.instance.downloadItemsBox
                                    .get(HiveUtil.instance.downloadQueueBox
                                        .get(widget.queue.key)!
                                        .downloadItemsIds![index])!;
                                return ListTile(
                                  key: ValueKey(dl.key),
                                  leading: SizedBox(
                                    width: 25,
                                    height: 25,
                                    child: SvgPicture.asset(
                                      FileUtil.resolveFileTypeIconPath(
                                          dl.fileType),
                                      colorFilter: ColorFilter.mode(
                                        FileUtil.resolveFileTypeIconColor(
                                            dl.fileType),
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                  title: Text(dl.fileName,
                                      style: TextStyle(color: Colors.white)),
                                  trailing: SizedBox(
                                    width: 100,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.delete,
                                              color: Colors.red),
                                          onPressed: () =>
                                              onRemovePressed(index),
                                        ),
                                        ReorderableDragStartListener(
                                          index: index,
                                          child: const Icon(Icons.drag_handle,
                                              color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              itemCount: itemCount,
                              onReorder: onReorder,
                            ),
                          ),
                        )
                ],
              ),
            ),
            SizedBox(height: resolveButtonMargin(size)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RoundedOutlinedButton(
                  onPressed: onCancelPressed,
                  borderColor: theme.cancelButtonColor.borderColor,
                  hoverTextColor: theme.cancelButtonColor.hoverTextColor,
                  hoverBackgroundColor:
                      theme.cancelButtonColor.hoverBackgroundColor,
                  textColor: theme.cancelButtonColor.textColor,
                  width: 95,
                  text: "Cancel",
                ),
                const SizedBox(width: 50),
                RoundedOutlinedButton(
                  onPressed: onSavePressed,
                  borderColor: theme.addButtonColor.borderColor,
                  hoverTextColor: theme.addButtonColor.hoverTextColor,
                  hoverBackgroundColor:
                      theme.addButtonColor.hoverBackgroundColor,
                  textColor: theme.addButtonColor.textColor,
                  width: 95,
                  text: "Save",
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  double resolveListHeight(Size size) {
    return size.height < 600 ? 200 : 900;
  }

  double resolveButtonMargin(Size size) {
    double margin = 50;
    if (size.height < 600) {
      margin = 20;
    }
    if (size.height < 500) {
      margin = 0;
    }
    return margin;
  }

  double resolveRowHeight(Size size) {
    return size.height < 600 ? 250 : 300;
  }

  void onSavePressed() async {
    await widget.queue.save();
    Provider.of<QueueProvider>(context, listen: false).notifyListeners();
    Navigator.of(context).pop();
  }

  void onCancelPressed() {
    widget.queue.downloadItemsIds = downloadIds;
    Navigator.of(context).pop();
  }

  int get itemCount => widget.queue.downloadItemsIds == null
      ? 0
      : widget.queue.downloadItemsIds!.length;

  void onReorder(int oldIndex, int newIndex) {
    final len = widget.queue.downloadItemsIds!.length;
    if (newIndex >= len) newIndex = len - 1;
    if (oldIndex >= len) oldIndex = len - 1;
    final id = widget.queue.downloadItemsIds!.removeAt(oldIndex);
    widget.queue.downloadItemsIds!.insert(newIndex, id);
  }

  void onRemovePressed(int index) =>
      setState(() => widget.queue.downloadItemsIds!.removeAt(index));
}
