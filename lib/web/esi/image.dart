import 'package:eve_fit_assistant/storage/preference/preference.dart';
import 'package:flutter/material.dart';

Image getCharacterImage(EsiAuthServer server, int characterId, {int size = 128}) => Image.network(
      'https://image.${switch (server) {
        EsiAuthServer.tranquility => 'eveonline',
        EsiAuthServer.serenity => 'evepc.163',
      }}.com/Character/${characterId}_$size.jpg',
    );
