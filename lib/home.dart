// import 'dart:convert';
//
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
//
// import 'Models/PostModel.dart';
//
// class Home extends StatelessWidget {
//    Home({super.key});
//
//  List<PostModel> postList  = [];
//   Future<List<PostModel>> getPostApi ()async{
//     final responce = await http.get(Uri.parse('https://jsonplaceholder.typicode.com/posts'));
//     var data = jsonDecode(responce.body.toString());
//     if (responce.statusCode == 200){
//     for(Map i in data ){
//       postList.add(PostModel.fromJson(i));
//     }
//     return postList;
//     } else{
//       return postList;
//
//     }
//
//
//   }
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Api Test ')),
//
//       body: Column(
//           children: [
//
//
//       FutureBuilder(
//           future: getPostApi(), builder: (context,snapshot){
//
//
//
//       })
//
//
//
//
//       ]),
//
//     );
//   }
// }
//
//
//
