import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:intl/intl.dart';

void main() {
  runApp(const GitHubIssuesApp());
}

class GitHubIssuesApp extends StatefulWidget {
  const GitHubIssuesApp({super.key});

  @override
  _GitHubIssuesAppState createState() => _GitHubIssuesAppState();
}

class _GitHubIssuesAppState extends State<GitHubIssuesApp> {
  bool isDarkMode = false;

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GitHub Issues Viewer',
      theme: isDarkMode ? ThemeData.dark() : ThemeData.light(),
      home: IssuesScreen(toggleTheme: toggleTheme, isDarkMode: isDarkMode),
    );
  }
}

class IssuesScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const IssuesScreen(
      {super.key, required this.toggleTheme, required this.isDarkMode});

  @override
  _IssuesScreenState createState() => _IssuesScreenState();
}

class _IssuesScreenState extends State<IssuesScreen> {
  final TextEditingController _controller = TextEditingController();
  List issues = [];
  bool isLoading = false;
  bool hasMore = false;
  String? errorMessage;
  int page = 1;
  final int perPage = 10;
  String filterState = 'all';

  Future<void> fetchIssues(String repoUrl) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      Uri? uri = Uri.tryParse(repoUrl);
      if (uri == null || !uri.host.contains('github.com')) {
        throw 'Invalid GitHub repository URL';
      }

      List<String> pathSegments = uri.pathSegments;
      if (pathSegments.length < 2) {
        throw 'Invalid repository format';
      }
      String owner = pathSegments[0];
      String repo = pathSegments[1];

      final response = await http.get(
        Uri.parse(
            'https://api.github.com/repos/$owner/$repo/issues?state=$filterState&page=$page&per_page=$perPage'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode == 200) {
        List newIssues = json.decode(response.body);
        setState(() {
          issues.addAll(newIssues);
          hasMore = newIssues.length == perPage;
        });
      } else {
        throw 'Failed to fetch issues: ${response.statusCode}';
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: false,
      extendBody: true,
      appBar: AppBar(
        forceMaterialTransparency: true,
        title: const Text(
          'GitHub Issues Viewer',
          style: TextStyle(
            fontFamily: "cmn",
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.dark_mode : Icons.light_mode),
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              style: const TextStyle(fontFamily: "cmn"),
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'GitHub Repository URL',
                labelStyle: TextStyle(fontFamily: "cmn"),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      issues.clear();
                      page = 1;
                      hasMore = true;
                    });
                    fetchIssues(_controller.text);
                  },
                  child: const Text(
                    'Fetch Issues',
                    style: TextStyle(fontFamily: "cmn"),
                  ),
                ),
                DropdownButton<String>(
                  value: filterState,
                  items: const [
                    DropdownMenuItem(
                        value: 'all',
                        child: Text(
                          'All',
                          style: TextStyle(fontFamily: "cmn"),
                        )),
                    DropdownMenuItem(
                        value: 'open',
                        child: Text(
                          'Open',
                          style: TextStyle(fontFamily: "cmn"),
                        )),
                    DropdownMenuItem(
                        value: 'closed',
                        child: Text(
                          'Closed',
                          style: TextStyle(
                            fontFamily: "cmn",
                          ),
                        )),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        filterState = value;
                        issues.clear();
                        page = 1;
                      });
                      fetchIssues(_controller.text);
                    }
                  },
                ),
              ],
            ),
            if (isLoading) const CircularProgressIndicator(),
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red, fontFamily: "cmn"),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: issues.length + 1,
                itemBuilder: (context, index) {
                  if (index == issues.length) {
                    return hasMore
                        ? ElevatedButton(
                            onPressed: () {
                              setState(() {
                                page++;
                              });
                              fetchIssues(_controller.text);
                            },
                            child: const Text(
                              'Load More',
                              style: TextStyle(
                                fontFamily: "cmn",
                              ),
                            ),
                          )
                        : const SizedBox.shrink();
                  }
                  final issue = issues[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 4.0),
                    child: ListTile(
                      title: Text(issue['title'],
                          style: const TextStyle(
                              fontFamily: "cmn", fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Issue Number: #${issue['number']}",
                              style: const TextStyle(
                                  fontFamily: "cmn",
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                          Text("Issue State: ${issue['state'].toUpperCase()}",
                              style: const TextStyle(
                                  fontFamily: "cmn", color: Colors.grey)),
                          Text(
                              "Created At: ${formatDateTime(issue['created_at'])}",
                              style: const TextStyle(color: Colors.blueGrey)),
                          Text("Created By: ${issue['user']['login']}",
                              style: const TextStyle(
                                  fontFamily: "cmn", color: Colors.blueGrey)),
                          const SizedBox(height: 10),
                          Text(
                            issue['body'] ?? 'No description',
                            style: const TextStyle(fontFamily: "cmn"),
                          ),
                          Wrap(
                            children: issue['labels']
                                .map<Widget>((label) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4.0),
                                      child: Chip(
                                        label: Text(
                                          label['name'],
                                          style: TextStyle(
                                              fontFamily: "cmn",
                                              color: widget.isDarkMode
                                                  ? Colors.white
                                                  : Colors.black),
                                        ),
                                        backgroundColor: widget.isDarkMode
                                            ? Colors.grey[700]
                                            : Colors.grey[200],
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(issue['title'],style: const TextStyle(fontFamily: "cmn"),),
                            content: SingleChildScrollView(
                              child: ListBody(
                                children: [
                                  Text("Issue #${issue['number']}",
                                      style: const TextStyle(
                                          fontFamily: "cmn",
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 5),
                                  Text(
                                      style: const TextStyle(fontFamily: "cmn"),
                                      "State: ${issue['state'].toUpperCase()}"),
                                  Text(
                                      "Created At: ${formatDateTime(issue['created_at'])}",
                                      style: const TextStyle(
                                          fontFamily: "cmn",
                                          color: Colors.blueGrey)),
                                  Text("Created By: ${issue['user']['login']}",
                                      style: const TextStyle(
                                          fontFamily: "cmn",
                                          color: Colors.blueGrey)),
                                  const SizedBox(height: 10),
                                  Text(
                                    issue['body'] ?? 'No description',
                                    style: const TextStyle(fontFamily: "cmn"),
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close',style: TextStyle(fontFamily: "cmn",),),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String formatDateTime(String dateTime) {
    DateTime parsedDate = DateTime.parse(dateTime);
    return DateFormat('d/M/yyyy h:mm a').format(parsedDate);
  }
}
