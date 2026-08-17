import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common/hbbs/hbbs.dart';
import 'package:flutter_hbb/common/widgets/login.dart';
import 'package:flutter_hbb/common/widgets/peers_view.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';

import '../../common.dart';

class MyGroup extends StatefulWidget {
  final EdgeInsets? menuPadding;
  const MyGroup({Key? key, this.menuPadding}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _MyGroupState();
  }
}

class _MyGroupState extends State<MyGroup> {
  RxBool get isSelectedDeviceGroup => gFFI.groupModel.isSelectedDeviceGroup;
  RxString get selectedAccessibleItemName =>
      gFFI.groupModel.selectedAccessibleItemName;
  RxString get searchAccessibleItemNameText =>
      gFFI.groupModel.searchAccessibleItemNameText;
  static TextEditingController searchUserController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!gFFI.userModel.isLogin) {
        return Center(
            child: ElevatedButton(
                onPressed: loginDialog, child: Text(translate("Login"))));
      } else if (gFFI.userModel.networkError.isNotEmpty) {
        return netWorkErrorWidget();
      } else if (gFFI.groupModel.groupLoading.value && gFFI.groupModel.emtpy) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }
      return Column(
        children: [
          buildErrorBanner(context,
              loading: gFFI.groupModel.groupLoading,
              err: gFFI.groupModel.groupLoadError,
              retry: null,
              close: () => gFFI.groupModel.groupLoadError.value = ''),
          Expanded(
              child: Obx(() => stateGlobal.isPortrait.isTrue
                  ? _buildPortrait()
                  : _buildLandscape())),
        ],
      );
    });
  }

  Widget _buildLandscape() {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Theme.of(context).colorScheme.background)),
          child: Container(
            width: 150,
            height: double.infinity,
            child: Column(
              children: [
                _buildLeftHeader(),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    child: _buildLeftList(),
                  ),
                )
              ],
            ),
          ),
        ).marginOnly(right: 12.0),
        Expanded(
          child: Align(
              alignment: Alignment.topLeft,
              child: MyGroupPeerView(
                menuPadding: widget.menuPadding,
              )),
        )
      ],
    );
  }

  Widget _buildPortrait() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: Theme.of(context).colorScheme.background)),
          child: Container(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLeftHeader(),
                Container(
                  width: double.infinity,
                  child: _buildLeftList(),
                )
              ],
            ),
          ),
        ).marginOnly(bottom: 12.0),
        Expanded(
          child: Align(
              alignment: Alignment.topLeft,
              child: MyGroupPeerView(
                menuPadding: widget.menuPadding,
              )),
        )
      ],
    );
  }

  Widget _buildLeftHeader() {
    final fontSize = 14.0;
    return Row(
      children: [
        Expanded(
            child: TextField(
          controller: searchUserController,
          onChanged: (value) {
            searchAccessibleItemNameText.value = value;
            selectedAccessibleItemName.value = '';
          },
          textAlignVertical: TextAlignVertical.center,
          style: TextStyle(fontSize: fontSize),
          decoration: InputDecoration(
            filled: false,
            prefixIcon: Icon(
              Icons.search_rounded,
              color: Theme.of(context).hintColor,
            ).paddingOnly(top: 2),
            hintText: translate("Search"),
            hintStyle: TextStyle(fontSize: fontSize),
            border: InputBorder.none,
            isDense: true,
          ),
        ).workaroundFreezeLinuxMint()),
      ],
    );
  }

  Widget _buildLeftList() {
    return Obx(() {
      final userItems = gFFI.groupModel.users.where((p0) {
        if (searchAccessibleItemNameText.isNotEmpty) {
          final search = searchAccessibleItemNameText.value.toLowerCase();
          return p0.name.toLowerCase().contains(search) ||
              p0.displayNameOrName.toLowerCase().contains(search);
        }
        return true;
      }).toList();
      // Count occurrences of each displayNameOrName to detect duplicates
      final displayNameCount = <String, int>{};
      for (final u in userItems) {
        final dn = u.displayNameOrName;
        displayNameCount[dn] = (displayNameCount[dn] ?? 0) + 1;
      }
      final deviceGroupItems = gFFI.groupModel.deviceGroups.where((p0) {
        if (searchAccessibleItemNameText.isNotEmpty) {
          return p0.name
              .toLowerCase()
              .contains(searchAccessibleItemNameText.value.toLowerCase());
        }
        return true;
      }).toList();
      listView(bool isPortrait) => ListView.builder(
          shrinkWrap: isPortrait,
          itemCount: deviceGroupItems.length + userItems.length,
          itemBuilder: (context, index) => index < deviceGroupItems.length
              ? _buildDeviceGroupItem(deviceGroupItems[index])
              : _buildUserItem(userItems[index - deviceGroupItems.length],
                  displayNameCount));
      var maxHeight = max(MediaQuery.of(context).size.height / 6, 100.0);
      return Obx(() => stateGlobal.isPortrait.isFalse
          ? listView(false)
          : LimitedBox(maxHeight: maxHeight, child: listView(true)));
    });
  }

  Widget _buildUserItem(UserPayload user, Map<String, int> displayNameCount) {
    final username = user.name;
    final dn = user.displayNameOrName;
    final isDuplicate = (displayNameCount[dn] ?? 0) > 1;
    final displayName =
        isDuplicate && user.displayName.trim().isNotEmpty
            ? '${user.displayName} (@$username)'
            : dn;
    return InkWell(onTap: () {
      if (stateGlobal.isPortrait.isTrue) {
        Get.to(() => UserDetailPage(user: user));
      } else {
        isSelectedDeviceGroup.value = false;
        if (selectedAccessibleItemName.value != username) {
          selectedAccessibleItemName.value = username;
        } else {
          selectedAccessibleItemName.value = '';
        }
      }
    }, child: Obx(
      () {
        bool selected = !isSelectedDeviceGroup.value &&
            selectedAccessibleItemName.value == username;
        final isMe = username == gFFI.userModel.userName.value;
        final colorMe = MyTheme.color(context).me!;
        return Container(
          decoration: BoxDecoration(
            color: selected ? MyTheme.color(context).highlight : null,
            border: Border(
                bottom: BorderSide(
                    width: 0.7,
                    color: Theme.of(context).dividerColor.withOpacity(0.1))),
          ),
          child: Container(
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: str2color(username, 0xAF),
                    shape: BoxShape.circle,
                  ),
                  child: Align(
                    alignment: Alignment.center,
                    child: Center(
                      child: Text(
                        displayName.characters.first.toUpperCase(),
                        style: TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ).marginOnly(right: 4),
                if (isMe) Flexible(child: Text(displayName)),
                if (isMe)
                  Flexible(
                    child: Container(
                      margin: EdgeInsets.only(left: 5),
                      padding: EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                          color: colorMe.withAlpha(20),
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                          border: Border.all(color: colorMe.withAlpha(100))),
                      child: Text(
                        translate('Me'),
                        style: TextStyle(
                            color: colorMe.withAlpha(200), fontSize: 12),
                      ),
                    ),
                  ),
                if (!isMe) Expanded(child: Text(displayName)),
                InkWell(
                  onTap: () => Get.to(() => UserDetailPage(user: user)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: Theme.of(context).hintColor.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ).paddingSymmetric(vertical: 4),
          ),
        );
      },
    )).marginSymmetric(horizontal: 12).marginOnly(bottom: 6);
  }

  Widget _buildDeviceGroupItem(DeviceGroupPayload deviceGroup) {
    final name = deviceGroup.name;
    return InkWell(onTap: () {
      if (stateGlobal.isPortrait.isTrue) {
        Get.to(() => DeviceGroupDetailPage(deviceGroup: deviceGroup));
      } else {
        isSelectedDeviceGroup.value = true;
        if (selectedAccessibleItemName.value != name) {
          selectedAccessibleItemName.value = name;
        } else {
          selectedAccessibleItemName.value = '';
        }
      }
    }, child: Obx(
      () {
        bool selected = isSelectedDeviceGroup.value &&
            selectedAccessibleItemName.value == name;
        return Container(
          decoration: BoxDecoration(
            color: selected ? MyTheme.color(context).highlight : null,
            border: Border(
                bottom: BorderSide(
                    width: 0.7,
                    color: Theme.of(context).dividerColor.withOpacity(0.1))),
          ),
          child: Container(
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  child: Icon(IconFont.deviceGroupOutline,
                      color: MyTheme.accent, size: 19),
                ).marginOnly(right: 4),
                Expanded(child: Text(name)),
                InkWell(
                  onTap: () => Get.to(() => DeviceGroupDetailPage(deviceGroup: deviceGroup)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: Theme.of(context).hintColor.withOpacity(0.6),
                    ),
                  ),
                ),
              ],
            ).paddingSymmetric(vertical: 4),
          ),
        );
      },
    )).marginSymmetric(horizontal: 12).marginOnly(bottom: 6);
  }
}

/// Dedicated Subpage for Viewing a specific User and their connected devices
class UserDetailPage extends StatelessWidget {
  final UserPayload user;
  const UserDetailPage({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final username = user.name;
    final displayName = user.displayNameOrName;
    final isMe = username == gFFI.userModel.userName.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Obx(() {
        // Collect all accessible peers from both groupModel and abModel
        final allPeers = <Peer>[...gFFI.groupModel.peers];
        for (final abPeer in gFFI.abModel.peers) {
          if (!allPeers.any((p) => p.id == abPeer.id)) {
            allPeers.add(abPeer);
          }
        }

        // Match by account loginName or local username
        final userPeers = allPeers.where((p) {
          final pLogin = p.loginName.trim();
          final pUser = p.username.trim();
          final uName = username.trim();
          final uDisp = user.displayName.trim();

          if (pLogin.isNotEmpty && (pLogin == uName || (uDisp.isNotEmpty && pLogin == uDisp))) {
            return true;
          }
          if (pUser.isNotEmpty && (pUser == uName || (uDisp.isNotEmpty && pUser == uDisp))) {
            return true;
          }
          return false;
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // User Profile Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: str2color(username, 0xAF),
                      child: Text(
                        displayName.isNotEmpty ? displayName.characters.first.toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'BEN',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@$username',
                            style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color),
                          ),
                          if (user.email.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              user.email,
                              style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.devices_rounded, size: 20, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text(
                  'Kayıtlı Cihazlar (${userPeers.length})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (userPeers.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.desktop_access_disabled_rounded, size: 48, color: Colors.grey.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      const Text(
                        'Bu kullanıcıya ait bağlı cihaz bulunamadı.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...userPeers.map((peer) {
                final isOnline = peer.online;
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.3)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isOnline ? Colors.green : Colors.grey).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.desktop_windows_rounded,
                        color: isOnline ? Colors.green : Colors.grey,
                        size: 22,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            peer.hostname.isNotEmpty ? peer.hostname : peer.id,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isOnline ? Colors.green : Colors.grey).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isOnline ? 'ÇEVRİMİÇİ' : 'ÇEVRİMDIŞI',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isOnline ? Colors.green.shade800 : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      'ID: ${peer.id} • Platform: ${peer.platform.isNotEmpty ? peer.platform : "Bilinmiyor"}${peer.device_group_name.isNotEmpty ? " • Grup: ${peer.device_group_name}" : ""}',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                    ),
                    trailing: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      icon: const Icon(Icons.flash_on_rounded, size: 14),
                      label: const Text('Bağlan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        connect(context, peer.id);
                      },
                    ),
                  ),
                );
              }),
          ],
        );
      }),
    );
  }
}

/// Dedicated Subpage for Viewing a specific Device Group and its connected devices
class DeviceGroupDetailPage extends StatelessWidget {
  final DeviceGroupPayload deviceGroup;
  const DeviceGroupDetailPage({Key? key, required this.deviceGroup}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final groupName = deviceGroup.name;

    return Scaffold(
      appBar: AppBar(
        title: Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Obx(() {
        final groupPeers = gFFI.groupModel.peers.where((p) => p.device_group_name == groupName).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Device Group Header Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: MyTheme.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(IconFont.deviceGroupOutline, color: MyTheme.accent, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            groupName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cihaz Grubu • Toplam ${groupPeers.length} cihaz',
                            style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.devices_rounded, size: 20, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text(
                  'Gruptaki Cihazlar (${groupPeers.length})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (groupPeers.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.desktop_access_disabled_rounded, size: 48, color: Colors.grey.withOpacity(0.5)),
                      const SizedBox(height: 12),
                      const Text(
                        'Bu grupta henüz kayıtlı cihaz bulunmuyor.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...groupPeers.map((peer) {
                final isOnline = peer.online;
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.3)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isOnline ? Colors.green : Colors.grey).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.desktop_windows_rounded,
                        color: isOnline ? Colors.green : Colors.grey,
                        size: 22,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            peer.hostname.isNotEmpty ? peer.hostname : peer.id,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isOnline ? Colors.green : Colors.grey).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isOnline ? 'ÇEVRİMİÇİ' : 'ÇEVRİMDIŞI',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isOnline ? Colors.green.shade800 : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      'ID: ${peer.id} • Sahibi: ${peer.loginName.isNotEmpty ? peer.loginName : "Atanmamış"} • Platform: ${peer.platform.isNotEmpty ? peer.platform : "Bilinmiyor"}',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
                    ),
                    trailing: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                      icon: const Icon(Icons.flash_on_rounded, size: 14),
                      label: const Text('Bağlan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        connect(context, peer.id);
                      },
                    ),
                  ),
                );
              }),
          ],
        );
      }),
    );
  }
}
