import 'package:flutter/material.dart';
import 'package:trelloappclone_flutter/utils/color.dart';
import 'package:trelloappclone_flutter/models/activity.dart';
import 'package:trelloappclone_flutter/models/card.dart';

import '../../../utils/service.dart';

class Activities extends StatefulWidget {
  final Cardlist crd;
  const Activities(this.crd, {super.key});

  @override
  State<Activities> createState() => _ActivitiesState();
}

class _ActivitiesState extends State<Activities> with Service {
  List<Activity> activities = [];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        initialData: activities,
        future: getActivities(widget.crd),
        builder:
            (BuildContext context, AsyncSnapshot<List<Activity>> snapshot) {
          if (snapshot.hasData) {
            List<Activity> children = snapshot.data as List<Activity>;

            if (children.isNotEmpty) {
              return ListView(
                  shrinkWrap: true, children: buildWidget(children));
            }
          }
          return const SizedBox.shrink();
        });
  }

  List<Widget> buildWidget(List<Activity> activities) {
    List<Widget> tiles = [];

    for (int i = 0; i < activities.length; i++) {
      tiles.add(ActivityTile(activity: activities[i].description));
    }
    return tiles;
  }
}

class ActivityTile extends StatefulWidget {
  final String activity;
  const ActivityTile({required this.activity, super.key});

  @override
  State<ActivityTile> createState() => _ActivityTileState();
}

class _ActivityTileState extends State<ActivityTile> {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: brandColor,
      ),
      title: Text(widget.activity),
      subtitle: const Text("01 Jan 2023 at 1:11 am"),
    );
  }
}
