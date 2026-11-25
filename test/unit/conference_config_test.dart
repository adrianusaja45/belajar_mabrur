import 'package:belajar_mabrur/meet/conference_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zego_uikit_prebuilt_live_audio_room/zego_uikit_prebuilt_live_audio_room.dart';

void main() {
  testWidgets('ConferenceConfig host defaults mic off and locks moderated mode',
      (WidgetTester tester) async {
    late ZegoUIKitPrebuiltLiveAudioRoomConfig config;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            config = ConferenceConfig.get(
              context: context,
              isHost: true,
              hostUserID: 'host_112',
              currentUserID: 'host_112',
              roomID: '112',
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(config.turnOnMicrophoneWhenJoining, isFalse);
    expect(config.seat.closeWhenJoining, isTrue);
    expect(
      config.bottomMenuBar.hostButtons,
      isNot(contains(ZegoLiveAudioRoomMenuBarButtonName.closeSeatButton)),
    );
    expect(
      config.bottomMenuBar.hostButtons,
      containsAll([
        ZegoLiveAudioRoomMenuBarButtonName.toggleMicrophoneButton,
        ZegoLiveAudioRoomMenuBarButtonName.showMemberListButton,
        ZegoLiveAudioRoomMenuBarButtonName.leaveButton,
      ]),
    );
    expect(
      config.popUpMenu.seatClicked.hiddenMenus,
      contains(ZegoLiveAudioRoomPopupItemValue.takeOnSeat),
    );
    expect(config.innerText.memberListAgreeButton, 'Izinkan');
    expect(config.innerText.memberListDisagreeButton, 'Tolak');
  });

  testWidgets('ConferenceConfig audience defaults mic off and requires request',
      (WidgetTester tester) async {
    late ZegoUIKitPrebuiltLiveAudioRoomConfig config;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            config = ConferenceConfig.get(
              context: context,
              isHost: false,
              hostUserID: 'host_112',
              currentUserID: 'user_9',
              roomID: '112',
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(config.turnOnMicrophoneWhenJoining, isFalse);
    expect(config.seat.closeWhenJoining, isTrue);
    expect(
      config.bottomMenuBar.audienceButtons,
      contains(ZegoLiveAudioRoomMenuBarButtonName.applyToTakeSeatButton),
    );
    expect(
      config.bottomMenuBar.audienceButtons,
      isNot(
          contains(ZegoLiveAudioRoomMenuBarButtonName.toggleMicrophoneButton)),
    );
    expect(
      config.popUpMenu.seatClicked.hiddenMenus,
      contains(ZegoLiveAudioRoomPopupItemValue.takeOnSeat),
    );
    expect(config.innerText.applyToTakeSeatButton, 'Minta Izin Bicara');
    expect(
      config.innerText.cancelTheTakeSeatApplicationButton,
      'Batal Minta Izin',
    );
  });
}
