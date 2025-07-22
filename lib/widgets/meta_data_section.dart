// Copyright 2020 Sarbagya Dhaubanjar. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

///
class MetaDataSection extends StatelessWidget {
  const MetaDataSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      alignment: Alignment.center,
      child: YoutubeValueBuilder(
        buildWhen: (o, n) {
          return o.metaData != n.metaData ||
              o.playbackQuality != n.playbackQuality;
        },
        builder: (context, value) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Text('Title', value.metaData.title),
              const SizedBox(height: 10),
              _Text('Channel', value.metaData.author),
              const SizedBox(height: 10),
              _Text('Playback Quality', value.playbackQuality ?? ''),
              const SizedBox(height: 10),
              Row(children: [_Text('Video Id', value.metaData.videoId)]),
            ],
          );
        },
      ),
    );
  }
}

class _Text extends StatelessWidget {
  final String title;
  final String value;

  const _Text(this.title, this.value);

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: '$title : ',
        style: Theme.of(context).textTheme.labelLarge,
        children: [
          TextSpan(
            text: value,
            style: Theme.of(
              context,
            ).textTheme.labelMedium!.copyWith(fontWeight: FontWeight.w300),
          ),
        ],
      ),
    );
  }
}
