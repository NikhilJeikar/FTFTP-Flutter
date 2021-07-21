import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:ftp/Constants.dart';
import 'package:path_provider/path_provider.dart';
import 'Network.dart';

dynamic _username = "";
dynamic _password = "";
dynamic _storage = "";

dynamic _realName = "";

bool _isConnected = false;
bool _isUsername = true;
bool _isPassword = true;
bool _isIP = true;
bool _isPort = true;

bool _sendingFile = false;
dynamic _file;

dynamic _sock;

List _location = [];
List _prev = [];

Map _dirs = {};

dynamic _current = _dirs;
dynamic _context;

dynamic _screenWindow;

double _used = 0;

//Network

void send() async {
  await _sock.write(_file.bytes);
}

void refreshList() {
  _sock.write(FETCH + SEPARATOR + METADATA);
}

void handler(List lis) {
  if (lis[0] == LOGIN) {
    if (lis[1] == FALSE)
      _isUsername = false;
    else if (lis.length > 1 && lis[2] == FALSE)
      _isPassword = false;
    else if (lis[1] == TRUE && lis[2] == TRUE) {
      _sock.write(FETCH + SEPARATOR + METADATA);
      Navigator.pop(_context);
      Navigator.push(_context, MaterialPageRoute(builder: (builder) {
        return FilesDisplay();
      }));
    } // NextPage
  } else if (lis[0] == METADATA) {
    _storage = double.parse(lis[1].toString());
    _used = double.parse(lis[2].toString()) / _storage;
    _screenWindow.setState(() {});
    try {
      Map tem = json.decode(lis[3]);
      _dirs = tem[_username.toString()];
      _current = _dirs;
      if (_prev.isNotEmpty) {
        for (int i = 0; i < _prev.length; i) {
          if (_current.containsKey(_location[i])) {
            _current = _current[_location[i]];
          } else {
            break;
          }
        }
      }
      print("MetaData");
    } on FormatException {
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
  } else if (lis[0] == DELETE) {
    if (lis[1] == FOLDER) {
      ScaffoldMessenger.of(_context).showSnackBar(
        SnackBar(
          content: Text('Folder deleted'),
        ),
      );
    } else if (lis[1] == FILE) {
      ScaffoldMessenger.of(_context).showSnackBar(
        SnackBar(
          content: Text('File deleted'),
        ),
      );
    }
    _screenWindow.setState(() {});
  } else if (lis[0] == ERROR) {
    String temp = lis[1];
    ScaffoldMessenger.of(_context).showSnackBar(
      SnackBar(
        content: Text(temp),
      ),
    );
  } else if (lis[0] == UPLOAD) {
    if (lis[1] == ACKNOWLEDGE) {
      send();
      _sendingFile = false;
    }
  } else if (lis[0] == DOWNLOAD) {
  } else {}
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

  _location = [];
  _prev = [];

  _dirs = {};
}

void fileName(context) {
  TextEditingController name = new TextEditingController();
  showDialog(
      context: context,
      builder: (context) {
        return new AlertDialog(
          title: Center(
              child: Text(
            "Create new file",
            style: TextStyle(color: TEXT),
          )),
          actionsPadding: EdgeInsets.all(0),
          contentPadding: EdgeInsets.all(0),
          backgroundColor: BACKGROUND,
          content: Container(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: TextField(
                controller: name,
                style: TextStyle(color: TEXT),
                decoration: InputDecoration(
                  errorText: !_isIP ? "Invalid IP" : null,
                  border: OutlineInputBorder(
                      borderSide: BorderSide(
                    color: BORDER,
                  )),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                    color: BORDER,
                  )),
                  enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                    color: BORDER,
                  )),
                  labelText: "File name",
                  focusColor: BORDER,
                  labelStyle: TextStyle(color: TEXT),
                ),
              ),
            ),
          ),
          actions: [
            ElevatedButton(
                onPressed: () {
                  _sock.write(CREATE +
                      SEPARATOR +
                      FOLDER +
                      SEPARATOR +
                      _location.join("/") +
                      "/" +
                      name.text);
                  Navigator.of(context).pop();
                  refreshList();
                },
                child: Text("Create"))
          ],
        );
      });
}

Future<bool> delete(context, name, type) async {
  return await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Center(
              child: Text(
            "Confirmation",
            style: TextStyle(color: TEXT),
          )),
          actionsPadding: EdgeInsets.all(0),
          contentPadding: EdgeInsets.all(0),
          backgroundColor: BACKGROUND,
          content: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Text(
              'Do you want to delete "$name" ($type) ?',
              style: TextStyle(color: TEXT),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: ElevatedButton(
                onPressed: () {
                  _sock.write(DELETE +
                      SEPARATOR +
                      type +
                      SEPARATOR +
                      _location.join("/") +
                      "/" +
                      name);
                  Navigator.of(context).pop(true);
                  refreshList();
                },
                child: Text(
                  "Delete",
                  style: TextStyle(color: BUTTON_TEXT),
                ),
                style: loginButton,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: Text(
                  "Cancel",
                  style: TextStyle(color: BUTTON_TEXT),
                ),
                style: loginButton,
              ),
            )
          ],
        );
      });
}

void connect(ip, port) async {
  if (!_isConnected) {
    _sock = await Socket.connect(ip, port);
  }
  print('Connected to: ${_sock.remoteAddress.address}:${_sock.remotePort}');
  final login = LOGIN +
      SEPARATOR +
      _username.toString() +
      SEPARATOR +
      _password.toString();
  _sock.write(login);
  if (!_isConnected) {
    var serverResponse = "";
    _isConnected = true;
    _sock.listen(
      (data) {
        serverResponse = String.fromCharCodes(data);
        print(serverResponse.length);
        handler(serverResponse.split(SEPARATOR));
      },
      onDone: () {
        print('Server left.');
        _sock.destroy();
      },
      // handle errors
      onError: (error) {
        print("Error raised");
        print(error);
        _sock.destroy();
        reset();
        while (Navigator.canPop(_context)) {
          Navigator.pop(_context);
        }
        Navigator.push(_context, MaterialPageRoute(builder: (builder) {
          return Login();
        }));
      },
    );
  }
}

Future<String> getFilePath() async {
  Directory appDocumentsDirectory =
      await getApplicationDocumentsDirectory(); // 1
  String appDocumentsPath = appDocumentsDirectory.path; // 2
  String filePath = '$appDocumentsPath/demoTextFile.txt'; // 3
  return filePath;
}

void saveFile() async {
  var va = getFilePath();
  File file = File(await va); // 1
  file.writeAsString(
      "This is my demo text that will be saved to : demoTextFile.txt"); // 2
}

//Core
void main() {
  runApp(MaterialApp(home: Login()));
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
    _screenWindow = this;
    _context = context;
    return Scaffold(
      appBar: appBar(),
      body: Container(
        color: BACKGROUND,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      elevation: 5,
      color: WIDGETS,
      child: Container(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 40, 30, 10),
              child: TextField(
                onTap: () {
                  _isIP = true;
                  setState(() {});
                },
                controller: _ipController,
                style: TextStyle(color: INPUT_TEXT),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  errorText: !_isIP ? "Invalid IP" : null,
                  border: outlineInputBorder,
                  focusedBorder: outlineInputBorder,
                  enabledBorder: outlineInputBorder,
                  labelText: "IP Address",
                  focusColor: BORDER,
                  labelStyle: TextStyle(color: TEXT),
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 30.0, vertical: 10),
              child: TextField(
                onTap: () {
                  _isPort = true;
                  setState(() {});
                },
                controller: _portController,
                style: TextStyle(color: INPUT_TEXT),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  errorText: !_isPort ? "Invalid port" : null,
                  border: outlineInputBorder,
                  focusedBorder: outlineInputBorder,
                  enabledBorder: outlineInputBorder,
                  labelText: "Port",
                  focusColor: BORDER,
                  labelStyle: TextStyle(color: TEXT),
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 30.0, vertical: 10),
              child: TextField(
                controller: _usernameController,
                onTap: () {
                  _isUsername = true;
                  setState(() {});
                },
                style: TextStyle(color: INPUT_TEXT),
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  errorText: !_isUsername ? "Invalid username" : null,
                  border: outlineInputBorder,
                  focusedBorder: outlineInputBorder,
                  enabledBorder: outlineInputBorder,
                  labelText: "User Name",
                  focusColor: BORDER,
                  labelStyle: TextStyle(
                    color: TEXT,
                  ),
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 30.0, vertical: 10),
              child: TextField(
                onTap: () {
                  _isPassword = true;
                  setState(() {});
                },
                controller: _passwordController,
                style: TextStyle(color: INPUT_TEXT),
                obscureText: _passVisibility,
                decoration: InputDecoration(
                  errorText: !_isPassword ? "Invalid password" : null,
                  suffixIcon: IconButton(
                    icon: Icon(
                      (_passVisibility)
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: ICONS,
                    ),
                    onPressed: () {
                      setState(() {
                        _passVisibility = !_passVisibility;
                      });
                    },
                  ),
                  border: outlineInputBorder,
                  focusedBorder: outlineInputBorder,
                  enabledBorder: outlineInputBorder,
                  labelText: "Password",
                  focusColor: BORDER,
                  labelStyle: TextStyle(color: TEXT),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: ElevatedButton(
                  onPressed: () {
                    _realName = _usernameController.text;
                    if (!_ipRegex.hasMatch(_ipController.text)) {
                      _isIP = false;
                      setState(() {});
                    } else {
                      _isIP = true;
                      setState(() {});
                    }
                    if (_portController.text.toString() == "" ||
                        int.parse(_portController.text.toString()) < 0 ||
                        int.parse(_portController.text.toString()) > 65353) {
                      _isPort = false;
                      setState(() {});
                    } else {
                      _isPort = true;
                      setState(() {});
                    }
                    _username =
                        sha512.convert(utf8.encode(_usernameController.text));
                    _password =
                        sha512.convert(utf8.encode(_passwordController.text));
                    if (_isPassword && _isPort && _isUsername && _isIP) {
                      connect(_ipController.text.toString(),
                          int.parse(_portController.text.toString()));
                      setState(() {});
                    }
                  },
                  style: loginButton,
                  child: Text("Login", style: TextStyle(color: BUTTON_TEXT))),
            )
          ],
        ),
      ),
    );
  }

  AppBar appBar() {
    return AppBar(
      title: Text("Local FTP"),
      backgroundColor: APPBAR,
      elevation: 0,
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
    _screenWindow = this;
    _context = context;
    lis = _current.keys.toList();
    lis.remove("*");
    return Scaffold(
        appBar: appBar(context),
        body: Container(
          color: BACKGROUND,
          child: ListView.builder(
            itemCount: lis.length,
            padding: EdgeInsets.fromLTRB(0, 2, 0, 0),
            itemBuilder: (BuildContext context, int index) {
              return Dismissible(
                dismissThresholds: {
                  DismissDirection.startToEnd: 0.4,
                },
                background: Container(
                  color: Color.fromARGB(255, 255, 0, 38),
                  child: Icon(
                    Icons.delete,
                    color: ICONS,
                  ),
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.all(10),
                ),
                secondaryBackground: Container(
                  color: Color.fromARGB(255, 72, 255, 0),
                  child: Icon(
                    Icons.download_rounded,
                    color: ICONS,
                  ),
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.all(10),
                ),
                confirmDismiss: (dir)async {
                  if(dir == DismissDirection.startToEnd)
                    {
                      return delete(
                          context,
                          lis[index],
                          (_current[lis[index]].values.length != 0)
                              ? FOLDER
                              : FILE);
                    }
                  else {
                    return false;
                  }

                },
                key: Key(lis[index]),
                child: GestureDetector(
                    child: Card(
                      elevation: 5,
                      shadowColor: Color.fromARGB(255, 2, 250, 196),
                      color: WIDGETS,
                      child: ListTile(
                        title: Text(
                          lis[index],
                          maxLines: 1,
                          style: TextStyle(
                            color: TEXT,
                          ),
                        ),
                        leading: (_current[lis[index]].values.length == 0)
                            ? Icon(
                                Icons.insert_drive_file_outlined,
                                color: ICONS,
                              )
                            : Icon(
                                Icons.folder_open_rounded,
                                color: ICONS,
                              ),
                      ),
                    ),
                    onTap: () {
                      if (_current[lis[index]].values.length != 0) {
                        _prev.add(_current);
                        _location.add(lis[index]);
                        _current = _current[lis[index]];
                        setState(() {});
                      }
                    }),
              );
            },
          ),
        ));
  }

  AppBar appBar(BuildContext context) {
    return AppBar(
      title: Text(
        "Local FTP",
        style: TextStyle(color: TEXT),
      ),
      backgroundColor: APPBAR,
      elevation: 0,
      titleSpacing: 0,
      actions: [
        IconButton(
            onPressed: () {
              fileName(context);
              refreshList();
            },
            icon: Icon(
              Icons.add,
              color: ICONS,
            )),
        popupMenuButton()
      ],
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_rounded,
          color: ICONS,
        ),
        onPressed: () {
          if (_prev.isNotEmpty) {
            _current = _prev.removeLast();
            _location.removeLast();
            setState(() {});
          }
        },
      ),
    );
  }

  PopupMenuButton<dynamic> popupMenuButton() {
    return PopupMenuButton(
      color: BACKGROUND,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      itemBuilder: (context) {
        return [
          PopupMenuItem(
              child: Column(
            children: [
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person,
                      color: ICONS,
                    ),
                    Text(_realName),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: LinearProgressIndicator(
                    backgroundColor: PROGRESS_BACKGROUND,
                    value: _used,
                    color: (_used > 0.9) ? PROGRESS_A_LIMIT : PROGRESS_B_LIMIT),
              ),
              Text(
                  "${(_used / (1024 * 1024 * 1024) * _storage).toStringAsFixed(2)}GB used out of ${_storage / (1024 * 1024 * 1024)} GB"),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 5),
                child: GestureDetector(
                  child: Row(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Icon(
                        Icons.upload,
                        color: ICONS,
                      ),
                    ),
                    Text(
                      "Upload file",
                    ),
                  ]),
                  onTap: () async {
                    FilePickerResult? result =
                        await FilePicker.platform.pickFiles(withData: true);
                    if (result != null) {
                      PlatformFile file = result.files.first;
                      if (_sendingFile == false) {
                        _sock.write(UPLOAD +
                            SEPARATOR +
                            file.bytes.toString().length.toString() +
                            SEPARATOR +
                            _location.join("/") +
                            "/" +
                            file.name);
                        _file = file;
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Already an upload is in progress'),
                          ),
                        );
                      }
                    } else {
                      // User canceled the picker
                    }
                    Navigator.pop(context);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 5, 0, 5),
                child: GestureDetector(
                  child: Row(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Icon(
                        Icons.sync,
                        color: ICONS,
                      ),
                    ),
                    Text(
                      "Sync",
                    ),
                  ]),
                  onTap: () {
                    refreshList();
                    lis = _current.keys.toList();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Page Refreshed'),
                      ),
                    );
                    setState(() {});
                    Navigator.pop(context);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 5, 0, 10),
                child: GestureDetector(
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Icon(
                          Icons.logout,
                          color: ICONS,
                        ),
                      ),
                      Text(
                        "Logout",
                      ),
                    ],
                  ),
                  onTap: () {
                    _sock.close();
                    _isConnected = false;
                    reset();
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) {
                      return Login();
                    }));
                  },
                ),
              ),
            ],
          )),
        ];
      },
      icon: Icon(
        Icons.menu,
        color: ICONS,
      ),
      padding: EdgeInsets.all(0),
    );
  }
}

//192.168.1.22
//24680
//Nikhil
//qwerty
