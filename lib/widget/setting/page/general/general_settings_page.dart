import 'package:brisk/widget/setting/page/general/behaviour_settings_group.dart';
import 'package:brisk/widget/setting/page/general/notification_settings_group.dart';
import 'package:brisk/widget/setting/page/general/ui_setting_group.dart';
import 'package:flutter/material.dart';

class GeneralSettingsPage extends StatelessWidget {
  const GeneralSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
            NotificationSettingsGroup(),
            UISettingGroup(),
            BehaviourSettingsGroup(),
          ],
        ),
      ),
    );
  }
}
