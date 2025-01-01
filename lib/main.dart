//import 'dart:ffi';

import 'dart:convert';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

//import 'dart:ffi';
import 'package:multi_dropdown/multi_dropdown.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:dnd_flutter/character_import.dart';
import 'package:flutter/material.dart';
import 'character.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

///Root widget of the application
class MyApp extends StatelessWidget {
  MyApp({super.key});

  ///This is the root character list, loaded into from the java microservice
  var characters = <CharacterEntity>[];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '5e Battle manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: MyHomePage(title: '5e Battle Manager', characters: characters),
    );
  }
}

///The Homepage widget
class MyHomePage extends StatefulWidget {
  MyHomePage({super.key, required this.title, required this.characters});
  List<CharacterEntity> characters;

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

///The homepage state
class _MyHomePageState extends State<MyHomePage> {
  ///Selected Key specifies the Global Key of the card whose turn it is.
  GlobalKey selectedKey = new GlobalKey();

  ///Defines the total cards
  var cards = <CharacterWidget>[];

  ///Defines the precards, useful for sorting the cards into those before and after the current turn
  var precards = <CharacterWidget>[];

  ///Defines the postcards, useful for sorting the cards into those before and after the current turn
  var postcards = <CharacterWidget>[];

  ///Scrollable controller for the Character cards. This allows methods to interact with it and animate it to scroll to certain points
  var scrollableController = ScrollController();

  //The turn controller, late as it gets created during init state to provide it with the current characters
  late TurnController turnController;

  //The stomp client. This handles socket connections to the java microservice. Mainly used to do live updates from java side
  late StompClient stompClient;

  ///Fetch session will query the java rest api for the current session and character information
  Future<List<CharacterEntity>> fetchSession() async {
    List<CharacterEntity> toAdd = [];
    try {
      final response =
          await http.get(Uri.parse('http://localhost:8080/getAll'));
      if (response.statusCode == 200) {
        var decoded = jsonDecode(response.body);
        turnController.currentTurn = decoded["Turn"];
        turnController.round = decoded["Round"];

        for (var i = 0; i < decoded["Characters"].length; i++) {
          toAdd.add(CharacterEntity.fromJson(
              decoded["Characters"][i] as Map<String, dynamic>));
        }
      }
    } catch (e) {}

    return toAdd;
  }

  ///Fetches session and then refreshes the UI, kept as a seperate method so State can be independant of the session sync.
  void CharacterSync() async {
    List<CharacterEntity> toAdd = await fetchSession();
    setState(() {
      widget.characters = [];
      for (var i in toAdd) {
        widget.characters.add(i);
      }
      _stateRefresh();
    });
  }

  ///Once STOMP connection is estabilished, this runs to subscribe to all endpoints. TO DO: make endpoint specific to session when sessions are implemented.
  void stompSetup(StompFrame connectFrame) {
    debugPrint("Connected!");
    stompClient.subscribe(
        destination: '/socket/update',
        headers: {},
        callback: (frame) {
          // Received a frame for this subscription
          debugPrint(frame.body);
          debugPrint("BAH");
          CharacterSync();
        });
  }

  ///Init state, runs every state refresh
  @override
  void initState() {
    super.initState();
    //Stomp initial config
    stompClient = StompClient(
      config: StompConfig(
          url: 'ws://127.0.0.1:8080',
          onConnect: stompSetup,
          onWebSocketError: (e) => print("Sadge " + e.toString()),
          onStompError: (d) => print('error stomp'),
          onDisconnect: (f) => print('disconnected'),
          onDebugMessage: (e) => print(e)),
    );
    stompClient.activate();

    //Generate new selected key. Required to avoid strange behaviour with using same key
    selectedKey = GlobalKey();
    widget.characters.sort((a, b) => a.initiative.compareTo(b.initiative));

    //runs session refresh and creates turn controller.
    CharacterSync();
    turnController = TurnController(characters: widget.characters);
  }

  ///State refresh generates all dynamic UI elements
  _stateRefresh() {
    //this.selectedKey = new GlobalKey();
    setState(() {
      //Resort as there is edge case where it runs before the sort
      widget.characters.sort((a, b) => b.initiative.compareTo(a.initiative));

      //Refresh current characters
      turnController.characters = widget.characters;

      //Set all lists to empty
      cards = <CharacterWidget>[];
      precards = <CharacterWidget>[];
      postcards = <CharacterWidget>[];

      //Routine for sorting through Character cards, sorting into pre or post current turn and marking the current turn card
      bool pastCurTurn = false;
      for (var i = 0; i < widget.characters.length; i++) {
        var key = GlobalKey();
        Color backgroundColor = Colors.white;
        bool isSelected = false;
        if (turnController.currentTurn == i) {
          //backgroundColor = Colors.cyanAccent;
          pastCurTurn = true;
          key = selectedKey;
          isSelected = true;
        }
        CharacterWidget newCard = new CharacterWidget(
            characterEntity: widget.characters[i],
            backgroundColor: backgroundColor,
            isSelected: isSelected,
            key: Key(widget.characters[i].uuid));

        if (pastCurTurn) {
          postcards.add(newCard);
        } else {
          precards.add(newCard);
        }
      }

      //Add all to main group
      cards.addAll(precards);
      cards.addAll(postcards);

      //If the round is reset, scroll to the start.
      if (turnController.currentTurn == 0) {
        scrollableController.animateTo(0,
            duration: Duration(milliseconds: 500), curve: Curves.linear);
      }
    });
  }

  ///Next turn method, calls next turn on microservice
  void _nextTurn() async {
    final response =
        await http.post(Uri.parse('http://localhost:8080/nextTurn'));

    setState(() {
      _stateRefresh();
      //after state refresh, scroll to current turn
      Scrollable.ensureVisible(selectedKey.currentContext!,
          duration: Duration(milliseconds: 500));
    });
  }

  ///Presents the character editor
  void _characterEditNav() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => CharacterImport(
                  characters: widget.characters,
                  refreshPage: CharacterSync,
                )));
  }

  //All UI definition
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 255, 127, 118),
          title: Text(widget.title),
          flexibleSpace:
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: _characterEditNav,
                    child: Text("Edit Characters.."))
              ],
            ),
          ])),
      body: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          //primary: true,
          controller: scrollableController,
          key: Key("mainScrollView"),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: cards,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _nextTurn,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}

///Character Widget is a custom stateful widget that defines a character card and related information
class CharacterWidget extends StatefulWidget {
  final CharacterEntity characterEntity;
  final Color backgroundColor;
  bool isSelected;

  CharacterWidget(
      {super.key,
      required this.backgroundColor,
      required this.characterEntity,
      required this.isSelected});

  @override
  State<CharacterWidget> createState() => _CharacterWidgetState();
}

class _CharacterWidgetState extends State<CharacterWidget> {
  final myController = TextEditingController();
  //Color backgroundColor = Colors.white;

  MultiSelectController<Status> dropController = MultiSelectController();
  bool getSelected(DropdownItem<Status> item) {
    print("Blah ");
    print("Blah " + item.value.name);
    print("Blah " + widget.characterEntity.status.toString());
    bool result = widget.characterEntity.status.contains(item.value);
    print(result.toString());
    return (result);
  }

  var items = [
    DropdownItem(label: "blinded", value: Status.blinded),
    DropdownItem(label: "charmed", value: Status.charmed),
    DropdownItem(label: "deafened", value: Status.deafened),
    DropdownItem(label: "frightened", value: Status.frightened),
    DropdownItem(label: "grappled", value: Status.grappled),
    DropdownItem(label: "incapacitated", value: Status.incapacitated),
    DropdownItem(label: "invisible", value: Status.invisible),
    DropdownItem(label: "paralyzed", value: Status.paralyzed),
    DropdownItem(label: "petrified", value: Status.petrified),
    DropdownItem(label: "poisoned", value: Status.poisoned),
    DropdownItem(label: "prone", value: Status.prone),
    DropdownItem(label: "restrained", value: Status.restrained),
    DropdownItem(label: "stunned", value: Status.stunned),
    DropdownItem(label: "exhaustion", value: Status.exhaustion),
  ];


  List<Widget> spellColumn = [];
  List<Widget> throwColumn = [];

  void _updateCharacter() async {
    try {
      debugPrint(widget.characterEntity.toJson().toString());
      final response = await http.post(
          Uri.parse('http://localhost:8080/updateCharacter'),
          body: widget.characterEntity.toJson().toString());
      if (response.statusCode == 200) {}
      debugPrint("Not 200");
    } catch (e) {
      debugPrint("Fail :( ${e}");
    }
    setState(() {});
  }

  void healthIncrement() {
    setState(() {
      widget.characterEntity.currentHealth += int.parse(myController.text);
      if (widget.characterEntity.currentHealth >
          widget.characterEntity.maxHealth / 2) {
        widget.characterEntity.condition = Condition.healthy;
      }

      if (widget.characterEntity.currentHealth <=
          widget.characterEntity.maxHealth / 2) {
        widget.characterEntity.condition = Condition.bloodied;
      }

      if (widget.characterEntity.currentHealth <= 0) {
        widget.characterEntity.condition = Condition.unconscious;
        widget.characterEntity.savingThrowNeg = 0;
        widget.characterEntity.savingThrowPos = 0;
      }
    });
    _updateCharacter();
  }

  void _toggleConcentration(bool? newval) {
    setState(() {
      widget.characterEntity.concentrating = newval!;
    });
    _updateCharacter();
  }

  void _updateStatus(List<Status> values) {

      List<Status> toAdd = [];
      for (var i in values) {
        toAdd.add(i);
      }

      if(!listEquals(widget.characterEntity.status,toAdd)){
      widget.characterEntity.status = toAdd;
      print("Updating status");
      print(toAdd);

    _updateCharacter();
      }
  }

  void updateCondition(Condition? value) async {
    setState(() {
      widget.characterEntity.condition = value!;
    });
    _updateCharacter();
  }

  void _toggleReaction(bool? newval) {
    setState(() {
      widget.characterEntity.reactionUsed = newval!;
    });
    _updateCharacter();
  }

  void _toggleSpellSlot(bool? action, String level) {
    setState(() {
      if (action!) {
        widget.characterEntity.usedSpellSlots.update(level, (int a) => a + 1);
      } else {
        widget.characterEntity.usedSpellSlots.update(level, (int a) => a - 1);
      }
      _updateCharacter();
      initSpellSlots();
    });
  }

  void _toggleSavedThrow(bool? action) {
    setState(() {
      if (action!) {
        widget.characterEntity.savingThrowPos += 1;
      } else {
        widget.characterEntity.savingThrowPos -= 1;
      }
      _updateCharacter();
      initSpellSlots();
    });
  }

  void _toggleFailedThrow(bool? action) {
    setState(() {
      if (action!) {
        widget.characterEntity.savingThrowNeg += 1;
      } else {
        widget.characterEntity.savingThrowNeg -= 1;
      }
      _updateCharacter();
      initSpellSlots();
    });
  }

  void initSpellSlots() {
    
    spellColumn = [];
    for (var i in widget.characterEntity.spellSlots.entries) {
      if (i.value != 0) {
        spellColumn.add(DefaultTextStyle(
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
            child: Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: EdgeInsets.all(15),
                  child: Text("Level " + i.key + " Spell Slots"),
                ))));

        List<Widget> rowItems = [];
        for (var j = 1; j <= i.value; j++) {
          if (j <= widget.characterEntity.usedSpellSlots[i.key]!) {
            rowItems.add(Checkbox(
                value: true,
                onChanged: (bool? action) => _toggleSpellSlot(action, i.key)));
          } else {
            rowItems.add(Checkbox(
                value: false,
                onChanged: (bool? action) => _toggleSpellSlot(action, i.key)));
          }
        }
        Row spellRow = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: rowItems,
        );
        spellColumn.add(Center(child: spellRow));
      }
    }
    ;
  }

  void initThrows() {
    throwColumn = [];

    throwColumn.add(DefaultTextStyle(
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
        child: Align(
            alignment: Alignment.center,
            child: Padding(
              padding: EdgeInsets.all(15),
              child: Text("Saved Death Throws"),
            ))));

    List<Widget> savedRowItems = [];
    for (var j = 1; j <= 3; j++) {
      if (j <= widget.characterEntity.savingThrowPos) {
        savedRowItems.add(Checkbox(
            value: true,
            onChanged: (bool? action) => _toggleSavedThrow(action)));
      } else {
        savedRowItems.add(Checkbox(
            value: false,
            onChanged: (bool? action) => _toggleSavedThrow(action)));
      }
    }
    Row savedSpellRow = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: savedRowItems,
    );
    throwColumn.add(Center(child: savedSpellRow));

    throwColumn.add(DefaultTextStyle(
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
        child: Align(
            alignment: Alignment.center,
            child: Padding(
              padding: EdgeInsets.all(15),
              child: Text("Failed Death Throws"),
            ))));

    List<Widget> failedRowItems = [];
    for (var j = 1; j <= 3; j++) {
      if (j <= widget.characterEntity.savingThrowNeg) {
        failedRowItems.add(Checkbox(
            value: true,
            onChanged: (bool? action) => _toggleFailedThrow(action)));
      } else {
        failedRowItems.add(Checkbox(
            value: false,
            onChanged: (bool? action) => _toggleFailedThrow(action)));
      }
    }
    Row failedSpellRow = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: failedRowItems,
    );
    throwColumn.add(Center(child: failedSpellRow));
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    initSpellSlots();
    dropController.selectWhere(getSelected);
  }

  List<Widget> SpellColumnGenerator(String blah) {
    initSpellSlots();
    return spellColumn;
  }

  List<Widget> throwColumnGenerator(String blah) {
    initThrows();
    return throwColumn;
  }

  @override
  void initState() {
    super.initState();
    debugPrint("Init");
    initSpellSlots();
    for(var i in items){
        i.selected = getSelected(i);

    }
    dropController.selectWhere(getSelected);
    print("DEBUG SESLECT");
    print(dropController.selectedItems);
  }

  double labelScale = 200;
  double contentScale = 200;

  @override
  Widget build(BuildContext context) {
    return Center(
        child: SizedBox(
      width: 500,
      height: 1000,
      child: Card(
        color: widget.backgroundColor,
        shape: widget.isSelected
            ? new RoundedRectangleBorder(
                side: new BorderSide(
                    color: const Color.fromARGB(255, 255, 187, 0), width: 3.0),
                borderRadius: BorderRadius.circular(4.0))
            : new RoundedRectangleBorder(
                side: new BorderSide(color: Colors.white, width: 2.0),
                borderRadius: BorderRadius.circular(4.0)),
        child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Column(children: <Widget>[
              /*
                                Character Name


                      */
              DefaultTextStyle(
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold),
                  child: Center(
                      child: Padding(
                    child: Text(widget.characterEntity.characterName),
                    padding: EdgeInsets.all(20),
                  ))),

              labelTemplate(
                  contentScale: contentScale,
                  fieldContent: widget.characterEntity.initiative.toString(),
                  fieldName: "Initiative: ",
                  labelScale: labelScale),
              labelTemplate(
                  contentScale: contentScale,
                  fieldContent: widget.characterEntity.armorClass.toString(),
                  fieldName: "Armor Class: ",
                  labelScale: labelScale),
              labelTemplate(
                  contentScale: contentScale,
                  fieldContent:
                      widget.characterEntity.currentHealth.toString() +
                          "/" +
                          widget.characterEntity.maxHealth.toString(),
                  fieldName: "Health: ",
                  labelScale: labelScale),
              /*

                      Quick health adjust


                      */
              TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: "Increase/Decrease health by...",
                ),
                controller: myController,
                key: Key(widget.characterEntity.characterName +
                    "HealthBar" +
                    this.hashCode.toString()),
              ),
              TextButton(onPressed: healthIncrement, child: Text("Submit")),
              /*

STATUS DROP DOWN


              */
              MultiDropdown<Status>(
                items: items,
                onSelectionChange: _updateStatus,
                controller: dropController,
                dropdownItemDecoration: DropdownItemDecoration(
                  
                  selectedIcon:
                      const Icon(Icons.check_box, color: Colors.green),
                  disabledIcon: Icon(Icons.lock, color: Colors.grey.shade300),
                ),
              ),
              /*
                  Tick box row
                  */
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  /*
                        Concentrating tickbox


                      */
                  Column(
                    children: [
                      DefaultTextStyle(
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.normal),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Padding(
                              padding: EdgeInsets.all(15),
                              child: Text("Concentrating"),
                            ),
                          )),
                      Checkbox(
                          value: widget.characterEntity.concentrating,
                          onChanged: _toggleConcentration)
                    ],
                  ),
                  /*
                        Reaction tickbox


                      */
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      DefaultTextStyle(
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.normal),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Padding(
                              padding: EdgeInsets.all(15),
                              child: Text("Reaction Used"),
                            ),
                          )),
                      Checkbox(
                          value: widget.characterEntity.reactionUsed,
                          onChanged: _toggleReaction)
                    ],
                  ),
                ],
              ),
              //Spell slots
              SizedBox(
                  width: double.maxFinite,
                  child: Center(
                      child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: SpellColumnGenerator(widget.key.toString()),
                  ))),
              SizedBox(
                  width: double.maxFinite,
                  child: DropdownButton<Condition>(
                    isExpanded: true,
                    items: Condition.values.map((toElement) {
                      return DropdownMenuItem(
                          child: Center(child: Text(toElement.name)),
                          value: toElement);
                    }).toList(),
                    onChanged: updateCondition,
                    value: widget.characterEntity.condition,
                  )),
              SizedBox(
                  width: double.maxFinite,
                  child: (widget.characterEntity.condition ==
                          Condition.unconscious)
                      ? Center(
                          child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: throwColumnGenerator(widget.key.toString()),
                        ))
                      : Text("")),
            ])),
      ),
    ));
  }
}

class TurnController {
  List<CharacterEntity> characters;
  TurnController({required this.characters});
  int currentTurn = 0;
  int round = 1;
  nextTurn() {
    if (currentTurn < characters.length - 1) {
      currentTurn++;
    } else {
      currentTurn = 0;
      round++;
    }
  }
}

class labelTemplate extends StatelessWidget {
  labelTemplate(
      {super.key,
      required this.contentScale,
      required this.fieldContent,
      required this.fieldName,
      required this.labelScale});

  String fieldName;
  String fieldContent;
  double labelScale;
  double contentScale;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(
          width: labelScale,
          child: DefaultTextStyle(
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.all(15),
                  child: Text(fieldName),
                ),
              ))),
      SizedBox(
          width: contentScale,
          child: DefaultTextStyle(
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.all(15),
                  child: Text(fieldContent),
                ),
              ))),
    ]);
  }
}

