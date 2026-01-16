import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:belajar_mabrur/data/repositories/auth_repository.dart';

import 'package:uuid/uuid.dart';



import 'audio_room/audio_room_screen.dart';



class JoinTab extends StatefulWidget {

const JoinTab({super.key});



@override

State<JoinTab> createState() => _JoinTabState();

}



class _JoinTabState extends State<JoinTab> {

final TextEditingController _roomIDController = TextEditingController();

String _userName = '';

String _userID = '';

String _userRole = '';

bool _isLoading = true;

bool _isHost = false;



@override

void initState() {

super.initState();

_initializeUser();

}



@override

void dispose() {

_roomIDController.dispose();

super.dispose();

}



Future<void> _initializeUser() async {

if (! mounted) return;

setState(() => _isLoading = true);


try {

final userProfile = await context.read<AuthRepository>().getProfile().timeout(

const Duration(seconds: 10),

onTimeout: () => throw Exception("Koneksi Timeout"),

);


if (mounted) {

setState(() {

_userName = userProfile['name'] ?? 'User';

_userID = userProfile['id']?.toString() ?? '';

_userRole = userProfile['role'] ?? 'user';

if (_userRole != 'host') _isHost = false;

_isLoading = false;

});

}

} catch (e) {

debugPrint("Error profile di JoinTab: $e");


final prefs = await SharedPreferences. getInstance();

if (mounted) {

setState(() {

_userID = prefs.getString('saved_user_id') ?? const Uuid().v4().replaceAll('-', '');

_userRole = prefs.getString('user_role') ?? 'user';

_isLoading = false;

});

}

}

}



@override

Widget build(BuildContext context) {

return Scaffold(

backgroundColor: Colors.white,

appBar: AppBar(

title: const Text("Audio Conference",

style: TextStyle(color: Color(0xFFA01C1C), fontWeight: FontWeight.bold)),

backgroundColor: Colors.white,

elevation: 0,

centerTitle: true,

),

body: _isLoading

? const Center(child: CircularProgressIndicator(color: Color(0xFFA01C1C)))

: SingleChildScrollView(

padding: const EdgeInsets.all(20.0),

child: Column(

children: [

const Icon(Icons.mic_external_on, size: 80, color: Color(0xFFA01C1C)),

const SizedBox(height: 30),

_buildUserCard(),

const SizedBox(height: 30),


_buildInfoCard(),

const SizedBox(height: 20),


TextField(

controller: _roomIDController,

decoration: InputDecoration(

labelText: "Masukkan Room ID",

hintText: "Contoh: 112",

border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),

prefixIcon: const Icon(Icons.meeting_room, color: Color(0xFFA01C1C)),

),

keyboardType: TextInputType.number,

),

const SizedBox(height: 10),

if (_userRole == 'host')

SwitchListTile(

title: const Text("Buka sebagai Host? ", style: TextStyle(fontWeight: FontWeight.bold)),

subtitle: Text(_isHost ? "Anda akan membuat room baru" : "Masuk sebagai peserta"),

value: _isHost,

activeThumbColor: const Color(0xFFA01C1C),

onChanged: (val) => setState(() => _isHost = val),

)

else

const Padding(

padding: EdgeInsets.symmetric(vertical: 10),

child: Text(

"Anda akan bergabung sebagai Peserta",

style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)

),

),

const SizedBox(height: 30),

_buildJoinButton(),

],

),

),

);

}



Widget _buildUserCard() {

return Container(

padding: const EdgeInsets.all(15),

decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),

child: Row(

mainAxisAlignment: MainAxisAlignment.center,

children: [

const Icon(Icons.account_circle, color: Colors.grey),

const SizedBox(width: 10),

Text(_userName. isNotEmpty ? _userName : "User", style: const TextStyle(fontWeight: FontWeight.bold)),

const SizedBox(width: 10),

Container(

padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),

decoration: BoxDecoration(

color: _userRole == 'host' ? const Color(0xFFA01C1C) : Colors.blueGrey,

borderRadius: BorderRadius.circular(20)

),

child: Text(_userRole. toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10)),

)

],

),

);

}



Widget _buildInfoCard() {

return Container(

padding: const EdgeInsets.all(12),

decoration: BoxDecoration(

color: const Color(0xFFA01C1C).withOpacity(0.1),

borderRadius: BorderRadius.circular(12),

border: Border.all(color: const Color(0xFFA01C1C).withOpacity(0.3)),

),

child: Row(

children: [

const Icon(Icons.info, color: Color(0xFFA01C1C)),

const SizedBox(width: 12),

Expanded(

child: Column(

crossAxisAlignment: CrossAxisAlignment.start,

children: [

const Text(

"🎙️ Audio Room Zego",

style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFA01C1C)),

),

const SizedBox(height: 4),

Text(

_isHost

? "Sebagai Host, Anda bisa membuat room baru"

: "Sebagai Peserta, Anda bisa langsung join room",

style: const TextStyle(fontSize: 12, color: Colors.grey),

),

],

),

),

],

),

);

}



Widget _buildJoinButton() {

return SizedBox(

width: double.infinity,

height: 50,

child: ElevatedButton(

style: ElevatedButton.styleFrom(

backgroundColor: const Color(0xFFA01C1C),

shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

),

onPressed: _joinRoom,

child: const Text("GABUNG AUDIO ROOM",

style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),

),

);

}



void _joinRoom() async {

if (_roomIDController.text.trim().isEmpty) {

ScaffoldMessenger.of(context).showSnackBar(

const SnackBar(content: Text("Silakan isi Room ID"))

);

return;

}



String roomID = _roomIDController. text.trim();

String standardizedHostID = "host_$roomID";


bool isHostUser = _isHost && _userRole == 'host';

String myUserID = isHostUser ? standardizedHostID : _userID;

String displayName = _userName.isNotEmpty ? _userName : "User_$roomID";



// HANYA SIMPAN FLAG JIKA ADALAH HOST (untuk tracking end room)

if (isHostUser) {

final prefs = await SharedPreferences. getInstance();

await prefs. setBool('room_${roomID}_created', true);

await prefs.setString('room_${roomID}_host', displayName);

debugPrint('Host created room $roomID');

}



// Navigate ke Audio Room Screen (tanpa validasi)

if (!mounted) return;

Navigator. push(

context,

MaterialPageRoute(

builder: (context) => AudioRoomScreen(

roomID: roomID,

isHost: isHostUser,

userID: myUserID,

displayName: displayName,

hostUserID: standardizedHostID,

),

),

);

}

}

