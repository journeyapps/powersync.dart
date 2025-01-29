import 'package:flutter/material.dart';
import 'package:trelloappclone_flutter/models/board.dart';

class CustomSearchDelegate extends SearchDelegate {
  List<Board> searchTerms = [];
  CustomSearchDelegate(List<Board> s) {
    searchTerms = s;
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () {
          query = '';
        },
        icon: const Icon(Icons.clear),
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () {
        close(context, null);
      },
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    List<Board> matchQuery = [];
    for (var brd in searchTerms) {
      if (brd.name.toLowerCase().contains(query.toLowerCase())) {
        matchQuery.add(brd);
      }
    }
    return ListView.builder(
      itemCount: matchQuery.length,
      itemBuilder: (context, index) {
        var result = matchQuery[index];

        return ListTile(
          onTap: () async {
            if (context.mounted) {
              Navigator.pushNamed(context, "/board");
            }
          },
          title: Text(result.name),
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    List matchQuery = [];
    for (var brd in searchTerms) {
      if (brd.name.toLowerCase().contains(query.toLowerCase())) {
        matchQuery.add(brd);
      }
    }
    return ListView.builder(
      itemCount: matchQuery.length,
      itemBuilder: (context, index) {
        var result = matchQuery[index];

        return ListTile(
          onTap: () async {
            if (context.mounted) {
              Navigator.pushNamed(context, "/board");
            }
          },
          title: Text(result.name),
        );
      },
    );
  }
}
