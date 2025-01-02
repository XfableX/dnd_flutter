import 'dart:convert';

import 'package:dnd_flutter/character.dart';
import 'package:dnd_flutter/main.dart';
import 'package:dnd_flutter/templates.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:stomp_dart_client/stomp_dart_client.dart';

class CharacterImport extends StatefulWidget {
  final Function() refreshPage;
  String sessionId;
  CharacterImport(
      {required this.characters,
      required this.refreshPage,
      required this.sessionId,
      required this.jwtToken});
  int selectedIndex = 0;
  String jwtToken;
  @override
  State<CharacterImport> createState() => _CharacterImportState();

  List<CharacterEntity> characters;
}

class _CharacterImportState extends State<CharacterImport> {
  late CharacterEditor characterEditor;

  late StompClient stompClient;
  void stompSetup(StompFrame connectFrame) {
    debugPrint("Connected!");
    stompClient.subscribe(
        destination: '/socket/update/' + widget.sessionId,
        headers: {},
        callback: (frame) {
          // Received a frame for this subscription
          debugPrint(frame.body);
          debugPrint("Editor Update");
          CharacterSync();
        });
  }

  Future<List<CharacterEntity>> fetchSession() async {
    List<CharacterEntity> toAdd = [];
    try {
      Map<String, String> headers = {
        "sessionId": widget.sessionId,
        "token": widget.jwtToken
      };
      final response = await http.get(Uri.parse(hostname + '/getAll'),
          headers: headers);
      if (response.statusCode == 200) {
        var decoded = jsonDecode(response.body);

        for (var i = 0; i < decoded["Characters"].length; i++) {
          toAdd.add(CharacterEntity.fromJson(
              decoded["Characters"][i] as Map<String, dynamic>));
        }
      }
    } catch (e) {}

    return toAdd;
  }

  void CharacterSync() async {
    List<CharacterEntity> toAdd = await fetchSession();
    setState(() {
      widget.characters = [];
      for (var i in toAdd) {
        widget.characters.add(i);
      }
      ListStateRefresh();
    });
  }

  //Init Method
  @override
  void initState() {
    super.initState();
    stompClient = StompClient(
      config: StompConfig(
          url: 'ws://127.0.0.1:8080',
          onConnect: stompSetup,
          //stompConnectHeaders: {'Authorization': '$token'},
          // webSocketConnectHeaders: {'Authorization': '$token'},
          onWebSocketError: (e) => print("Sadge " + e.toString()),
          onStompError: (d) => print('error stomp'),
          onDisconnect: (f) => print('disconnected'),
          onDebugMessage: (e) => print(e)),
    );

    stompClient.activate();
    //Sets characters to parent array
    characters = widget.characters;
    ListStateRefresh();
    //Creates character
  }

  characterSelect(int index) {
    setState(() {
      widget.selectedIndex = index;
      //characterEditor = CharacterEditor(character: characters[index], refreshPage: ListStateRefresh);
      characterEditor.character = characters[widget.selectedIndex];
      characterEditor.refreshTextField();
    });
  }

//Move functionality to Java
  _addCharacter() async {
    Map<String, String> headers = {
      "sessionId": widget.sessionId,
      "token": widget.jwtToken
    };
    final response = await http.post(
        Uri.parse(hostname + '/addEmptyCharacter'),
        headers: headers);
  }

  //Refreshes the Sidebar
  ListStateRefresh() {
    setState(() {
      print("Editor refresh");
      widget.refreshPage();
      characters = widget.characters;
      characters.sort((a, b) => a.characterName.compareTo(b.characterName));
      charNames = [];
      for (var i = 0; i < characters.length; i++) {
        charNames.add(SizedBox(
            width: 200,
            child: TextButton(
                onPressed: () => characterSelect(i),
                child: Text(characters[i].characterName))));
      }
      if (characters.length >= 1) {
        characterEditor = CharacterEditor(
            jwtToken: widget.jwtToken,
            sessionId: widget.sessionId,
            character: characters[widget.selectedIndex],
            refreshPage: ListStateRefresh);
        //for (var i = 0; i < characters.length; i++) {
        // charNames.add(TextButton(
        //   onPressed: () => characterSelect(i),
        //child: Text(characters[i].characterName)));
        characterEditor.refreshTextField();
      }
    });
  }

  late List<CharacterEntity> characters;
  List<Widget> charNames = [];

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text("Character editor"),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Row(
          children: [
            Container(
                color: Color.fromARGB(00, 255, 255, 255),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SizedBox(
                    height: double.maxFinite,
                    width: 200,
                    child: Column(
                      children:
                          (charNames.isNotEmpty) ? charNames : [Text(". . .")],
                    ),
                  ),
                )),
            Container(
              child: (charNames.isNotEmpty)
                  ? characterEditor
                  : SizedBox(
                      width: 1000,
                      height: double.maxFinite,
                      child: Container(
                          width: double.maxFinite,
                          height: double.maxFinite,
                          color: Colors.white,
                          padding: EdgeInsets.all(16),
                          child: DefaultTextStyle(
                              style: const TextStyle(
                                  fontSize: 32, fontWeight: FontWeight.bold),
                              child: Center(
                                  child: Padding(
                                child: Text(
                                    "No characters yet! Try clicking the plus button at the bottom right"),
                                padding: EdgeInsets.all(20),
                              ))))),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCharacter,
        tooltip: 'Add Character',
        child: const Icon(Icons.add),
      ),
      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}

class CharacterEditor extends StatefulWidget {
  String sessionId;
  String jwtToken;
  final Function() refreshPage;
  CharacterEditor(
      {super.key,
      required this.character,
      required this.refreshPage,
      required this.sessionId,
      required this.jwtToken});
  CharacterEntity character;
  final nameController = TextEditingController();
  final acController = TextEditingController();
  final curHealthController = TextEditingController();
  final maxHealthController = TextEditingController();
  final initController = TextEditingController();
  final ownerController = TextEditingController();
  final lvl1SpellSlots = TextEditingController();
  final lvl2SpellSlots = TextEditingController();
  final lvl3SpellSlots = TextEditingController();
  final lvl4SpellSlots = TextEditingController();
  final lvl5SpellSlots = TextEditingController();
  final lvl6SpellSlots = TextEditingController();
  final lvl7SpellSlots = TextEditingController();
  final lvl8SpellSlots = TextEditingController();
  final lvl9SpellSlots = TextEditingController();

  refreshTextField() {
    ownerController.text = character.owner;
    nameController.text = character.characterName;
    acController.text = character.armorClass.toString();
    curHealthController.text = character.currentHealth.toString();
    maxHealthController.text = character.maxHealth.toString();
    initController.text = character.initiative.toString();

    lvl1SpellSlots.text = character.spellSlots["1"].toString();
    lvl2SpellSlots.text = character.spellSlots["2"].toString();
    lvl3SpellSlots.text = character.spellSlots["3"].toString();
    lvl4SpellSlots.text = character.spellSlots["4"].toString();
    lvl5SpellSlots.text = character.spellSlots["5"].toString();
    lvl6SpellSlots.text = character.spellSlots["6"].toString();
    lvl7SpellSlots.text = character.spellSlots["7"].toString();
    lvl8SpellSlots.text = character.spellSlots["8"].toString();
    lvl9SpellSlots.text = character.spellSlots["9"].toString();
  }

  @override
  State<CharacterEditor> createState() => _CharacterEditorState();
}

class _CharacterEditorState extends State<CharacterEditor> {
  @override
  void initState() {
    super.initState();
    widget.refreshTextField();
  }

  double labelScale = 200;
  double fieldScale = 600;

  //Updates local instance and pushes those changes up to java
  void _updateCharacter() async {
    
    
    widget.character.owner = widget.ownerController.text;

    widget.character.characterName = widget.nameController.text;
    widget.character.armorClass = int.parse(widget.acController.text);
    widget.character.currentHealth = int.parse(widget.curHealthController.text);
    widget.character.maxHealth = int.parse(widget.maxHealthController.text);
    widget.character.initiative = int.parse(widget.initController.text);
    debugPrint(widget.character.toJson().toString());
    try {
      widget.character.spellSlots
          .update("1", (current) => int.parse(widget.lvl1SpellSlots.text));
      widget.character.spellSlots
          .update("2", (current) => int.parse(widget.lvl2SpellSlots.text));
      widget.character.spellSlots
          .update("3", (current) => int.parse(widget.lvl3SpellSlots.text));
      widget.character.spellSlots
          .update("4", (current) => int.parse(widget.lvl4SpellSlots.text));
      widget.character.spellSlots
          .update("5", (current) => int.parse(widget.lvl5SpellSlots.text));
      widget.character.spellSlots
          .update("6", (current) => int.parse(widget.lvl6SpellSlots.text));
      widget.character.spellSlots
          .update("7", (current) => int.parse(widget.lvl7SpellSlots.text));
      widget.character.spellSlots
          .update("8", (current) => int.parse(widget.lvl8SpellSlots.text));
      widget.character.spellSlots
          .update("9", (current) => int.parse(widget.lvl9SpellSlots.text));
      widget.character.usedSpellSlots
          .update("1", (current) => int.parse(widget.lvl1SpellSlots.text));
      widget.character.usedSpellSlots
          .update("2", (current) => int.parse(widget.lvl2SpellSlots.text));
      widget.character.usedSpellSlots
          .update("3", (current) => int.parse(widget.lvl3SpellSlots.text));
      widget.character.usedSpellSlots
          .update("4", (current) => int.parse(widget.lvl4SpellSlots.text));
      widget.character.usedSpellSlots
          .update("5", (current) => int.parse(widget.lvl5SpellSlots.text));
      widget.character.usedSpellSlots
          .update("6", (current) => int.parse(widget.lvl6SpellSlots.text));
      widget.character.usedSpellSlots
          .update("7", (current) => int.parse(widget.lvl7SpellSlots.text));
      widget.character.usedSpellSlots
          .update("8", (current) => int.parse(widget.lvl8SpellSlots.text));
      widget.character.usedSpellSlots
          .update("9", (current) => int.parse(widget.lvl9SpellSlots.text));
    } catch (e) {
      debugPrint("Fail :( ${e}");
    }
    debugPrint(widget.character.toJson().toString());
    try {
      debugPrint(widget.character.toJson().toString());
      Map<String, String> headers = {
        "sessionId": widget.sessionId,
        "token": widget.jwtToken
      };
      final response = await http.post(
          Uri.parse(hostname + '/updateCharacter'),
          headers: headers,
          body: widget.character.toJson().toString());
      debugPrint("No sex!!!");
      if (response.statusCode == 200) {
        debugPrint("Sex?");
      }
      debugPrint("Not 200");
    } catch (e) {
      debugPrint("Fail :( ${e}");
    }
    debugPrint("Sadgher");
    widget.refreshPage();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
        child: SizedBox(
            width: 1000,
            height: double.maxFinite,
            child: Container(
                width: double.maxFinite,
                height: double.maxFinite,
                color: Colors.white,
                padding: EdgeInsets.all(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Column(
                    children: [
                      textFieldTemplate(
                          fieldName: "Character Name: ",
                          fieldScale: fieldScale,
                          hint: "Chatacter name...",
                          labelScale: labelScale,
                          controller: widget.nameController),
                      textFieldTemplate(
                          fieldName: "Armor Class: ",
                          fieldScale: fieldScale,
                          hint: "Armor Class...",
                          labelScale: labelScale,
                          controller: widget.acController),
                      textFieldTemplate(
                          fieldName: "Current Health: ",
                          fieldScale: fieldScale,
                          hint: "Current Health...",
                          labelScale: labelScale,
                          controller: widget.curHealthController),
                      textFieldTemplate(
                          fieldName: "Max Health: ",
                          fieldScale: fieldScale,
                          hint: "Max Health...",
                          labelScale: labelScale,
                          controller: widget.maxHealthController),
                      textFieldTemplate(
                          fieldName: "Inititative: ",
                          fieldScale: fieldScale,
                          hint: "Inititative...",
                          labelScale: labelScale,
                          controller: widget.initController),
                      textFieldTemplate(
                          fieldName: "Owner: ",
                          fieldScale: fieldScale,
                          hint: "Owner...",
                          labelScale: labelScale,
                          controller: widget.ownerController),
                      textFieldTemplate(
                          fieldName: "Level 1 spell slots: ",
                          fieldScale: fieldScale,
                          hint: "Spell slots...",
                          labelScale: labelScale,
                          controller: widget.lvl1SpellSlots),
                      textFieldTemplate(
                          fieldName: "Level 2 spell slots: ",
                          fieldScale: fieldScale,
                          hint: "Spell slots...",
                          labelScale: labelScale,
                          controller: widget.lvl2SpellSlots),
                      textFieldTemplate(
                          fieldName: "Level 3 spell slots: ",
                          fieldScale: fieldScale,
                          hint: "Spell slots...",
                          labelScale: labelScale,
                          controller: widget.lvl3SpellSlots),
                      textFieldTemplate(
                          fieldName: "Level 4 spell slots: ",
                          fieldScale: fieldScale,
                          hint: "Spell slots...",
                          labelScale: labelScale,
                          controller: widget.lvl4SpellSlots),
                      textFieldTemplate(
                          fieldName: "Level 5 spell slots: ",
                          fieldScale: fieldScale,
                          hint: "Spell slots...",
                          labelScale: labelScale,
                          controller: widget.lvl5SpellSlots),
                      textFieldTemplate(
                          fieldName: "Level 6 spell slots: ",
                          fieldScale: fieldScale,
                          hint: "Spell slots...",
                          labelScale: labelScale,
                          controller: widget.lvl6SpellSlots),
                      textFieldTemplate(
                          fieldName: "Level 7 spell slots: ",
                          fieldScale: fieldScale,
                          hint: "Spell slots...",
                          labelScale: labelScale,
                          controller: widget.lvl7SpellSlots),
                      textFieldTemplate(
                          fieldName: "Level 8 spell slots: ",
                          fieldScale: fieldScale,
                          hint: "Spell slots...",
                          labelScale: labelScale,
                          controller: widget.lvl8SpellSlots),
                      textFieldTemplate(
                          fieldName: "Level 9 spell slots: ",
                          fieldScale: fieldScale,
                          hint: "Spell slots...",
                          labelScale: labelScale,
                          controller: widget.lvl9SpellSlots),
                      TextButton(
                          onPressed: _updateCharacter, child: Text("Update"))
                    ],
                  ),
                ))));
  }
}
