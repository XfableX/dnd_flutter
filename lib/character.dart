import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';

@JsonSerializable()
class CharacterEntity {

  CharacterEntity({required this.uuid,required this.characterName, required this.initiative, required this.armorClass, required this.maxHealth, required this.currentHealth, required this.concentrating, required this.reactionUsed});
  CharacterEntity.JsonConstruct({required this.uuid, required this.owner,required this.characterName, required this.initiative, required this.armorClass, required this.maxHealth, required this.currentHealth, required this.concentrating, required this.reactionUsed, required this.condition, required this.savingThrowNeg, required this.savingThrowPos, required this.spellSlots, required this.status, required this.usedSpellSlots});

  factory CharacterEntity.fromJson(Map<String, dynamic> json){
    print(json);
    return switch (json) {
      {
        'UUID' : var uuid,
        'Owner' : var owner,
        'CurrentHealth': var currentHealth,
        'Condition': var condition,
        'Status':var status,
        'Concentrating':var concentrating,
        'ReactionUsed':var reactionUsed,
        'UsedSlots':var usedSpellSlots,
        'Inititative':var initiative,
        'ArmorClass':var armorClass,
        'SpellSlots':var spellSlots,
        'MaxHealth':var maxHealth,
        'Name':var characterName,
        'PosSavingThrow': var savingThrowPos,
        'NegSavingThrow':var savingThrowNeg
      } =>
        CharacterEntity.JsonConstruct(
          uuid: uuid,
          owner: owner,
          characterName: characterName,
          condition: Condition.values.byName(condition),
          status: _convertToStatus(status),
          concentrating: concentrating,
          reactionUsed: reactionUsed,
          usedSpellSlots:Map.from(usedSpellSlots),
          spellSlots:Map.from(spellSlots),
          initiative: initiative,
          armorClass: armorClass,
          maxHealth: maxHealth,
          currentHealth: currentHealth,
          savingThrowNeg: savingThrowNeg,
          savingThrowPos: savingThrowPos
        ),
      _ => throw const FormatException("Failed to load album."),
    };
  }
  
  Map<String, dynamic> toJson(){
    Map<String, dynamic> json = {};
    json['Name'] = characterName;
    json['UUID'] = uuid;
    if(owner != ""){
      json['Owner'] = owner;
    }
    json['Initiative'] = initiative;
    json['ArmorClass'] = armorClass;
    json['MaxHealth'] = maxHealth;
    json['CurrentHealth'] = currentHealth;
    json['Concentrating'] = concentrating;
    json['ReactionUsed'] = reactionUsed;
    json['Condition'] = condition.name;
    json['PosSavingThrow'] = savingThrowPos;
    json['NegSavingThrow'] = savingThrowNeg;
    json['SpellSlots'] = spellSlots;
    json['UsedSlots'] = usedSpellSlots;

    List<String> statusString = [];
    for(var i in status){
      statusString.add(i.name);
    }

    json['status'] = statusString;

    return json;
    
    
  }
  String uuid;
  String characterName;
  String owner = "";
  int initiative;
  int armorClass;
  int maxHealth;
  int currentHealth;
  bool concentrating;
  bool reactionUsed;
  Condition condition = Condition.healthy;
  List<Status> status = [];
  int savingThrowPos = 0;
  int savingThrowNeg = 0;

  Map<String, int> spellSlots = {
    '1':0,
    '2':0,
    '3':0,
    '4':0,
    '5':0,
    '6':0,
    '7':0,
    '8':0,
    '9':0,
  };
  Map<String, int> usedSpellSlots = {
    '1':0,
    '2':0,
    '3':0,
    '4':0,
    '5':0,
    '6':0,
    '7':0,
    '8':0,
    '9':0,
  };
}


enum Condition {
    bloodied,
    healthy,
    stable,
    unconscious,
    dead
}

enum Status {
  blinded,
  charmed,
  deafened,
  frightened,
  grappled,
  incapacitated,
  invisible,
  paralyzed,
  petrified,
  poisoned,
  prone,
  restrained,
  stunned,
  exhaustion
}

List<Status> _convertToStatus(List<dynamic> input){
    List<Status> output = [];
    for(var i in input){
      print("AAAA " + i);
      output.add(Status.values.byName(i));
    }
    return output;
  }