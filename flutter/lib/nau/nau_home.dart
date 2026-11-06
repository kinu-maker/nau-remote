import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

import 'nau_login_page.dart';
import 'nau_settings_page.dart';
import 'nau_theme.dart';

enum _NauPage { computers, settings, advanced }

const _kQueryOnlinesEvent = 'callback_query_onlines';
const _kQueryOnlinesHandler = 'nau_home';

/// Main window content: login first, then the computer list.
class NauHomeShell extends StatefulWidget {
  /// Setup card of the stock client (install, macOS permissions, ...).
  final Widget Function()? setupCardBuilder;
  const NauHomeShell({Key? key, this.setupCardBuilder}) : super(key: key);

  @override
  State<NauHomeShell> createState() => _NauHomeShellState();
}

class _NauHomeShellState extends State<NauHomeShell> {
  var _page = _NauPage.computers;
  final _onlineIds = Rx<Set<String>>(<String>{});
  final _myId = ''.obs;
  Timer? _onlineTimer;

  @override
  void initState() {
    super.initState();
    platformFFI.registerEventHandler(
        _kQueryOnlinesEvent, _kQueryOnlinesHandler, _onQueryOnlines,
        replace: true);
    _onlineTimer =
        Timer.periodic(const Duration(seconds: 12), (_) => _queryOnlines());
    Future.delayed(const Duration(seconds: 1), _queryOnlines);
    bind.mainGetMyId().then((id) {
      if (mounted) _myId.value = id;
    });
  }

  @override
  void dispose() {
    _onlineTimer?.cancel();
    platformFFI.unregisterEventHandler(
        _kQueryOnlinesEvent, _kQueryOnlinesHandler);
    super.dispose();
  }

  List<Peer> _myPeers() {
    final me = gFFI.userModel.userName.value;
    return gFFI.groupModel.peers
        .where((p) => p.loginName == me && p.id.isNotEmpty)
        .toList();
  }

  List<Peer> _sharedPeers() {
    final mine = _myPeers().map((p) => p.id).toSet();
    final seen = <String>{};
    final result = <Peer>[];
    for (final ab in gFFI.abModel.addressbooks.values) {
      for (final p in ab.peers) {
        if (p.id.isEmpty || mine.contains(p.id) || !seen.add(p.id)) continue;
        result.add(p);
      }
    }
    for (final p in gFFI.groupModel.peers) {
      if (p.id.isEmpty || mine.contains(p.id) || !seen.add(p.id)) continue;
      result.add(p);
    }
    return result;
  }

  void _queryOnlines() {
    if (!mounted || !gFFI.userModel.isLogin) return;
    final ids = <String>{
      ..._myPeers().map((p) => p.id),
      ..._sharedPeers().map((p) => p.id),
    }.toList(growable: false);
    if (ids.isEmpty) return;
    bind.queryOnlines(ids: ids);
  }

  Future<void> _onQueryOnlines(Map<String, dynamic> evt) async {
    final onlines = (evt['onlines'] ?? '').toString().split(',');
    final offlines = (evt['offlines'] ?? '').toString().split(',');
    final next = Set<String>.from(_onlineIds.value);
    next.addAll(onlines.where((e) => e.isNotEmpty));
    next.removeAll(offlines);
    _onlineIds.value = next;
  }

  Future<void> _refresh() async {
    gFFI.userModel.refreshCurrentUser();
    Future.delayed(const Duration(seconds: 2), _queryOnlines);
  }

  Future<void> _connect(Peer peer) async {
    if (peer.alias.isNotEmpty &&
        (await bind.mainGetPeerOption(id: peer.id, key: 'alias')).isEmpty) {
      await bind.mainSetPeerAlias(id: peer.id, alias: peer.alias);
    }
    if (!mounted) return;
    final shared = peer.password.isNotEmpty;
    connect(context, peer.id,
        password: shared ? peer.password : '', isSharedPassword: shared);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NauColors.background,
      child: DefaultTextStyle(
        style: nauText(),
        child: Obx(() {
          if (gFFI.userModel.userName.value.isEmpty) {
            return const NauLoginPage();
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSidebar(),
              Expanded(child: _buildPage()),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildPage() {
    switch (_page) {
      case _NauPage.computers:
        return _buildComputers();
      case _NauPage.settings:
        return NauSettingsPage(
          onOpenAdvanced: () => setState(() => _page = _NauPage.advanced),
        );
      case _NauPage.advanced:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: NauButton(
                  label: '설정으로 돌아가기',
                  icon: Icons.arrow_back,
                  onPressed: () => setState(() => _page = _NauPage.settings),
                ),
              ),
            ),
            Expanded(
              child: DesktopSettingPage(
                key: const ValueKey('nau-advanced-settings'),
                initialTabkey: SettingsTabKey.general,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildSidebar() {
    Widget navItem(String label, IconData icon, bool selected, _NauPage page) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Material(
          color: selected ? NauColors.navSelected : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _page = page),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(icon,
                      size: 20,
                      color:
                          selected ? NauColors.text : NauColors.textSecondary),
                  const SizedBox(width: 12),
                  Text(label,
                      style: nauText(
                          weight: FontWeight.w500,
                          color: selected
                              ? NauColors.text
                              : NauColors.textSecondary)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 216,
      decoration: const BoxDecoration(
        color: NauColors.sidebar,
        border: Border(right: BorderSide(color: NauColors.sidebarBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 22, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                const NauLogo(size: 30),
                const SizedBox(width: 10),
                Text(kNauAppTitle,
                    style: nauText(size: 16, weight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          navItem('컴퓨터', Icons.desktop_windows_outlined,
              _page == _NauPage.computers, _NauPage.computers),
          navItem(
              '설정', Icons.tune, _page != _NauPage.computers, _NauPage.settings),
          const Spacer(),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: NauColors.sidebarBorder)),
            ),
            child: Obx(() {
              final name = gFFI.userModel.displayNameOrUserName;
              final account = gFFI.userModel.userName.value;
              return Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                        color: NauColors.avatar, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(
                        name.isEmpty
                            ? '?'
                            : name.characters.first.toUpperCase(),
                        style: nauText(size: 13, weight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            overflow: TextOverflow.ellipsis,
                            style: nauText(size: 13, weight: FontWeight.w500)),
                        if (account != name)
                          Text(account,
                              overflow: TextOverflow.ellipsis,
                              style: nauText(
                                  size: 12, color: NauColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildComputers() {
    return Obx(() {
      final mine = _myPeers();
      final shared = _sharedPeers();
      final loading = gFFI.groupModel.groupLoading.value ||
          gFFI.abModel.currentAbLoading.value;
      final networkError = gFFI.userModel.networkError.value;
      final loadError = gFFI.groupModel.groupLoadError.value;
      final error = networkError.isNotEmpty ? networkError : loadError;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  Text('컴퓨터',
                      style: nauText(size: 26, weight: FontWeight.w700)),
                  const SizedBox(width: 14),
                  if (loading)
                    const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  const Spacer(),
                  NauButton(
                    label: '새로 고침',
                    icon: Icons.refresh,
                    onPressed: loading ? null : _refresh,
                  ),
                ],
              ),
            ),
            if (error.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildError(error),
            ],
            if (widget.setupCardBuilder != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: SizedBox(width: 340, child: widget.setupCardBuilder!()),
              ),
            const SizedBox(height: 22),
            _buildSection(
              '내 컴퓨터',
              mine,
              empty:
                  '아직 등록된 컴퓨터가 없습니다. 접속하려는 컴퓨터에 $kNauAppTitle를 설치하고 같은 계정으로 로그인하면 여기에 나타납니다.',
            ),
            if (shared.isNotEmpty) ...[
              const SizedBox(height: 28),
              _buildSection('공용 PC', shared),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildError(String detail) {
    return NauPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 20, color: NauColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('컴퓨터 목록을 불러오지 못했습니다. 인터넷 연결을 확인한 뒤 새로 고침을 누르세요.',
                    style: nauText(height: 1.5)),
                const SizedBox(height: 4),
                SelectableText(detail,
                    style: nauText(size: 12, color: NauColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Peer> peers, {String? empty}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: nauText(size: 15, weight: FontWeight.w700)),
            const SizedBox(width: 8),
            Text('${peers.length}',
                style: nauText(size: 13, color: NauColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 12),
        if (peers.isEmpty && empty != null)
          NauPanel(
            child: Text(empty,
                style: nauText(color: NauColors.textSecondary, height: 1.6)),
          ),
        if (peers.isNotEmpty)
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: peers.map(_buildCard).toList(),
          ),
      ],
    );
  }

  String _peerName(Peer peer) {
    if (peer.alias.isNotEmpty) return peer.alias;
    if (peer.hostname.isNotEmpty) return peer.hostname;
    return formatID(peer.id);
  }

  IconData _platformIcon(String platform) {
    switch (platform) {
      case kPeerPlatformAndroid:
        return Icons.phone_android;
      case kPeerPlatformMacOS:
        return Icons.laptop_mac;
      case kPeerPlatformWindows:
        return Icons.desktop_windows_outlined;
      default:
        return Icons.computer;
    }
  }

  Widget _buildCard(Peer peer) {
    final isThisDevice = peer.id == _myId.value;
    final online = isThisDevice || _onlineIds.value.contains(peer.id);
    final detail = [
      if (peer.platform.isNotEmpty) peer.platform,
      formatID(peer.id),
    ].join(' · ');
    return SizedBox(
      width: 268,
      child: NauPanel(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: NauColors.field,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(_platformIcon(peer.platform),
                      size: 22, color: NauColors.textMuted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_peerName(peer),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: nauText(size: 15, weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: nauText(
                              size: 12, color: NauColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: online ? NauColors.online : NauColors.offline,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                    isThisDevice
                        ? '이 컴퓨터'
                        : online
                            ? '온라인'
                            : '오프라인',
                    style: nauText(size: 13, color: NauColors.textMuted)),
                const Spacer(),
                if (!isThisDevice)
                  NauButton(
                    label: '연결',
                    primary: online,
                    height: 36,
                    onPressed: () => _connect(peer),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
