import 'package:flutter/material.dart';
import 'package:belajar_mabrur/screens/audio_room/audio_room_controller.dart';

class PIPAudioOverlay {
  static OverlayEntry? _entry;

  static void show(BuildContext context) {
    // jika sudah tampil, jangan duplikat
    if (_entry != null) return;

    final overlay = Overlay.of(context, rootOverlay: true);

    final size = MediaQuery.of(context).size;
    // default position bottom-right
    double left = size.width - 110;
    double top = size. height - 140;

    _entry = OverlayEntry(
      builder:  (ctx) {
        return _DraggablePip(
          left: left,
          top: top,
          onRestore: () {
            hide();
            AudioRoomController.instance.restore();

            // Untuk menghindari circular import, kita pakai named route
            // Pastikan Anda mendaftarkan route '/audioRoom' pada MaterialApp
            final sess = AudioRoomController.instance;
            
            // Check semua session data ada
            if (sess.roomID != null &&
                sess.userID != null &&
                sess.displayName != null &&
                sess.hostUserID != null) {
              Navigator.of(context).pushNamed(
                '/audioRoom',
                arguments: {
                  'roomID': sess.roomID! ,
                  'userID':  sess.userID!,
                  'displayName': sess.displayName! ,
                  'hostUserID': sess.hostUserID!,
                  'isHost': sess.isHost,
                },
              );
            } else {
              // Debug: session data tidak lengkap
              debugPrint('PIPAudioOverlay: Session data incomplete');
            }
          },
          onEnd: () {
            hide();
            // End room - clear session dan leave
            AudioRoomController.instance.leaveRoom();
            
            // Pop back ke previous screen
            Navigator.of(context).pop();
          },
        );
      },
    );

    overlay.insert(_entry!);
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
  }
}

class _DraggablePip extends StatefulWidget {
  final double left;
  final double top;
  final VoidCallback onRestore;
  final VoidCallback onEnd;

  const _DraggablePip({
    Key? key,
    required this. left,
    required this.top,
    required this.onRestore,
    required this.onEnd,
  }) : super(key: key);

  @override
  State<_DraggablePip> createState() => _DraggablePipState();
}

class _DraggablePipState extends State<_DraggablePip> {
  late double left;
  late double top;

  @override
  void initState() {
    super.initState();
    left = widget.left;
    top = widget.top;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Positioned(
      left: _constrainPosition(left, size.width - 100),
      top: _constrainPosition(top, size. height - 120),
      child:  GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            left += details.delta.dx;
            top += details.delta. dy;
            
            // Constrain position agar tidak keluar screen
            left = _constrainPosition(left, size.width - 100);
            top = _constrainPosition(top, size.height - 120);
          });
        },
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 100,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mic, size: 28, color: Colors.black87),
                const SizedBox(height:  8),
                Text(
                  AudioRoomController.instance.displayName ?? 'User',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight. w600,
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment. spaceAround,
                  children: [
                    GestureDetector(
                      onTap: widget.onRestore,
                      child: Column(
                        children: const [
                          Icon(Icons.open_in_full, color: Colors. blue, size: 20),
                          SizedBox(height: 4),
                          Text('Restore', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onEnd,
                      child: Column(
                        children: const [
                          Icon(Icons.stop_circle, color: Colors.red, size: 20),
                          SizedBox(height: 4),
                          Text('End', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Constrain position agar PIP tidak keluar dari screen
  double _constrainPosition(double value, double max) {
    return value.clamp(0.0, max);
  }
}