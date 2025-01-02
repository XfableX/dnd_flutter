import 'package:flutter/material.dart';

class textFieldTemplate extends StatelessWidget {
  textFieldTemplate(
      {super.key,
      required this.fieldName,
      required this.fieldScale,
      required this.hint,
      required this.labelScale,
      required this.controller});

  String fieldName;
  String hint;
  double labelScale;
  double fieldScale;
  TextEditingController controller;

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
        width: fieldScale,
        child: TextField(
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: hint,
          ),
          controller: controller,
          // key: Key("nameBox"),
        ),
      )
    ]);
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


