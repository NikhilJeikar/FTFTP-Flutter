import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'Network.dart';

dynamic _username = "";
dynamic _password = "";
dynamic _storage = "";

bool _isConnected = false;
bool _isUsername = true;
bool _isPassword = true;
bool _isIP = true;
bool _isPort = true;

dynamic sock;

List location = [];
List prev = [];

Map _dirs = {};

dynamic current = _dirs;
dynamic _context;

//Network
void refreshList() {
  sock.write(FETCH + SEPARATOR + METADATA);
}

void handler(List lis) async {
  if (lis[0] == LOGIN) {
    if (lis[1] == FALSE) _isUsername = false;
    else if (lis.length > 1 && lis[2] == FALSE) _isPassword = false;
    else if (lis[1] == TRUE && lis[2] == TRUE) {
      sock.write(FETCH + SEPARATOR + METADATA);
      Navigator.pop(_context);
      Navigator.push(_context, MaterialPageRoute(builder: (builder) {
        return FilesDisplay();
      }));
    } // NextPage
  } else if (lis[0] == METADATA) {
    _storage = lis[1];
    try{
      Map tem = json.decode(lis[2]);
      _dirs = tem[_username.toString()];
      current = _dirs;
      if (prev.isNotEmpty) {
        for (int i = 0; i < prev.length; i) {
          if (current.containsKey(location[i])) {
            current = current[location[i]];
          } else {
            break;
          }
        }
      }
    }
    on FormatException {
      refreshList();
      print("Failed packet");
    }

  } else if (lis[0] == CREATE) {
    if (lis[1] == FOLDER) {
      ScaffoldMessenger.of(_context).showSnackBar(
        SnackBar(
          content: Text('Folder created'),
        ),
      );
    }
  } else if (lis[0] == ERROR) {
    String temp = lis[1];
    ScaffoldMessenger.of(_context).showSnackBar(
      SnackBar(
        content: Text(temp),
      ),
    );
  }
}

//Supporters
void reset() {
  _username = "";
  _password = "";
  _storage = "";

  _isConnected = false;
  _isUsername = true;
  _isPassword = true;
  _isIP = true;
  _isPort = true;

  location = [];
  prev = [];

  _dirs = {};
}

void fileName(context) {
  TextEditingController name = new TextEditingController();
  AlertDialog dialog = new AlertDialog(
    title: Center(
        child: Text(
          "Create new file",
          style: TextStyle(color: Colors.white),
        )),
    actionsPadding: EdgeInsets.all(0),
    contentPadding: EdgeInsets.all(0),
    backgroundColor: Color.fromARGB(255, 22, 22, 22),
    content: Container(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: TextField(
          controller: name,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            errorText: !_isIP ? "Invalid IP" : null,
            border: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.white,
                )),
            focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.white,
                )),
            enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.white,
                )),
            labelText: "File name",
            focusColor: Colors.white,
            labelStyle: TextStyle(color: Colors.white),
          ),
        ),
      ),
    ),
    actions: [
      ElevatedButton(
          onPressed: () {
            sock.write(CREATE +
                SEPARATOR +
                FOLDER +
                SEPARATOR +
                location.join("/") +
                "/" +
                name.text);
            Navigator.of(context).pop();
            refreshList();
          },
          child: Text("Create"))
    ],
  );
  showDialog(
      context: context,
      builder: (context) {
        return dialog;
      });
}

void connect(ip, port) async {
  if (!_isConnected) {
    sock = await Socket.connect(ip, port);
  }
  print('Connected to: ${sock.remoteAddress.address}:${sock.remotePort}');
  final login = LOGIN +
      SEPARATOR +
      _username.toString() +
      SEPARATOR +
      _password.toString();
  sock.write(login);
  if (!_isConnected) {
    var serverResponse = "";
    _isConnected = true;
    sock.listen(
      (data) {
        serverResponse = String.fromCharCodes(data);
        print(serverResponse.length);
        handler(serverResponse.split(SEPARATOR));
      },
      onDone: () {
        print('Server left.');
        sock.destroy();
      },
      // handle errors
      onError: (error) {
        print("Error raised");
        print(error);
        sock.destroy();
        reset();
        Navigator.pop(_context);
        Navigator.push(_context, MaterialPageRoute(builder: (builder) {
          return Login();
        }));
      },
    );
  }
}

//Core
void main() {
  runApp(MaterialApp(
    home: Login(),
  ));
}

//UI
class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  bool _passVisibility = true;
  RegExp _ipRegex =
      new RegExp(r"^(?!0)(?!.*\.$)((1?\d?\d|25[0-5]|2[0-4]\d)(\.|$)){4}$");

  TextEditingController _ipController = new TextEditingController();
  TextEditingController _portController = new TextEditingController();
  TextEditingController _usernameController = new TextEditingController();
  TextEditingController _passwordController = new TextEditingController();

  @override
  Widget build(BuildContext context) {
    _context = context;
    return Scaffold(
      appBar: appBar(),
      body: Container(
        color: Colors.black87,
        height: double.infinity,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: loginCard(),
          ),
        ),
      ),
    );
  }

  Card loginCard() {
    return Card(
            shadowColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25)),
            elevation: 5,
            color: Color.fromARGB(255, 22, 22, 22),
            child: Container(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(30, 20, 30, 10),
                    child: TextField(
                      onTap: () {
                        _isIP = true;
                        setState(() {});
                      },
                      controller: _ipController,
                      style: TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        errorText: !_isIP ? "Invalid IP" : null,
                        border: OutlineInputBorder(
                            borderSide: BorderSide(
                          color: Colors.white,
                        )),
                        focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                          color: Colors.white,
                        )),
                        enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                          color: Colors.white,
                        )),
                        labelText: "IP Address",
                        focusColor: Colors.white,
                        labelStyle: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30.0, vertical: 10),
                    child: TextField(
                      onTap: () {
                        _isPort = true;
                        setState(() {});
                      },
                      controller: _portController,
                      style: TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        errorText: !_isPort ? "Invalid port" : null,
                        border: OutlineInputBorder(
                            borderSide: BorderSide(
                          color: Colors.white,
                        )),
                        focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                          color: Colors.white,
                        )),
                        enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                          color: Colors.white,
                        )),
                        labelText: "Port",
                        focusColor: Colors.white,
                        labelStyle: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30.0, vertical: 10),
                    child: TextField(
                      controller: _usernameController,
                      onTap: () {
                        _isUsername = true;
                        setState(() {});
                      },
                      style: TextStyle(color: Colors.white),
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        errorText: !_isUsername ? "Invalid username" : null,
                        border: OutlineInputBorder(
                            borderSide: BorderSide(
                          color: Colors.white,
                        )),
                        focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                          color: Colors.white,
                        )),
                        enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                          color: Colors.white,
                        )),
                        labelText: "User Name",
                        focusColor: Colors.white,
                        labelStyle: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30.0, vertical: 10),
                    child: TextField(
                      onTap: () {
                        _isPassword = true;
                        setState(() {});
                      },
                      controller: _passwordController,
                      style: TextStyle(color: Colors.white),
                      obscureText: _passVisibility,
                      decoration: InputDecoration(
                        errorText: !_isPassword ? "Invalid password" : null,
                        suffixIcon: IconButton(
                          icon: Icon(
                            (_passVisibility)
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _passVisibility = !_passVisibility;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                            borderSide: BorderSide(
                          color: Colors.white,
                        )),
                        focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                          color: Colors.white,
                        )),
                        enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                          color: Colors.white,
                        )),
                        labelText: "Password",
                        focusColor: Colors.white,
                        labelStyle: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: ElevatedButton(
                        onPressed: () {
                          if (!_ipRegex.hasMatch(_ipController.text)) {
                            _isIP = false;
                            setState(() {});
                          } else {
                            _isIP = true;
                            setState(() {});
                          }
                          if (_portController.text.toString() == "" ||
                              int.parse(_portController.text.toString()) <
                                  0 ||
                              int.parse(_portController.text.toString()) >
                                  65353) {
                            _isPort = false;
                            setState(() {});
                          } else {
                            _isPort = true;
                            setState(() {});
                          }
                          _username = sha512
                              .convert(utf8.encode(_usernameController.text));
                          _password = sha512
                              .convert(utf8.encode(_passwordController.text));
                          if (_isPassword &&
                              _isPort &&
                              _isUsername &&
                              _isIP) {
                            connect(_ipController.text.toString(),
                                int.parse(_portController.text.toString()));
                            setState(() {});
                          }
                        },
                        child: Text("Take me in")),
                  )
                ],
              ),
            ),
          );
  }

  AppBar appBar() {
    return AppBar(
      title: Text("Local FTP"),
      backgroundColor: Color.fromARGB(255, 22, 22, 22),
      shadowColor: Colors.white,
      elevation: 5,
    );
  }
}

class FilesDisplay extends StatefulWidget {
  const FilesDisplay({Key? key}) : super(key: key);

  @override
  _FilesDisplayState createState() => _FilesDisplayState();
}

class _FilesDisplayState extends State<FilesDisplay> {
  List lis = _dirs.keys.toList();

  @override
  Widget build(BuildContext context) {
    _context = context;
    lis = current.keys.toList();
    lis.remove("*");
    return Scaffold(
        appBar: appBar(context),
        body: Container(
          color: Colors.black87,
          child: RefreshIndicator(
            onRefresh: () {
              refreshList();
              return Future.delayed(
                Duration(seconds: 1),
                () {
                  lis = current.keys.toList();
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Page Refreshed'),
                    ),
                  );
                  setState(() {

                  });
                },
              );
            },
            child: ListView.builder(
              itemCount: lis.length,
              itemBuilder: (BuildContext context, int index) {
                return listViewTile(index);
              },
            ),
          ),
        ));
  }

  GestureDetector listViewTile(int index) {
    return GestureDetector(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(5.0, 2, 5, 0),
                  child: Card(
                    color: Color.fromARGB(255, 22, 22, 22),
                    child: ListTile(
                      title: Text(
                        lis[index],
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      ),
                      contentPadding: EdgeInsets.all(5),
                      leading: (current[lis[index]].values.length == 0)
                          ? Icon(
                              Icons.insert_drive_file_outlined,
                              color: Colors.white,
                            )
                          : Icon(
                              Icons.folder_open_rounded,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
                onTap: () {
                  if (current[lis[index]].values.length != 0) {
                    prev.add(current);
                    location.add(lis[index]);
                    current = current[lis[index]];
                    setState(() {});
                  }
                },
              );
  }

  AppBar appBar(BuildContext context) {
    return AppBar(
        title: Text("Local FTP"),
        backgroundColor: Color.fromARGB(255, 22, 22, 22),
        shadowColor: Colors.white,
        actions: [
          IconButton(
              onPressed: () {
                fileName(context);
                refreshList();
              },
              icon: Icon(Icons.add)),
          IconButton(
              onPressed: () {
                sock.close();
                _isConnected = false;
                reset();
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) {
                  return Login();
                }));
              },
              icon: Icon(Icons.logout)),
        ],
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (prev.isNotEmpty) {
              current = prev.removeLast();
              location.removeLast();
              setState(() {});
            }
          },
        ),
        elevation: 5,
      );
  }
}


//192.168.1.22
//24680
//Nikhil
//qwerty
