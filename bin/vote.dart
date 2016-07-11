library vote_bot;

import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:vote_bot/settings.dart';
import 'dart:convert';

var log = new Logger('VoteBot');

main() async {
  Logger.root.onRecord.listen(print);
  Logger.root.level = Level.ALL;

  await vote();
}

int errorCount = 0;

Future vote() async {
  log.info('Voting now...');
  try {
    final voteInformation = await getVoteInformation();
    log.info('Got request token ${voteInformation.token}');
    await postVote(voteInformation);
    errorCount = 0;
  } catch (e) {
    log.warning('There was an error: $e');
    errorCount++;
  }
  if (errorCount >= maxErrorCount) {
    log.severe('Too many failed attempts. Quitting now.');
  }
}

class VoteInformation {
  final String token;
  final List<Cookie> cookies;
  VoteInformation(this.token, this.cookies);
}

final tokenRegex = new RegExp(r'name\=\"REQUEST_TOKEN\"\s+value\=\"([a-zA-Z0-9]+)\"');
Future<VoteInformation> getVoteInformation() async {
  HttpClient client = new HttpClient();
  var response = await (await client.getUrl(Uri.parse(url))).close();
  var responseText = UTF8.decode(await response.fold([], (List prev, bytes) => new List.from(prev)..addAll(bytes)));

  final match = tokenRegex.firstMatch(responseText);
  if (match == null) throw 'No token found';

  return new VoteInformation(match.group(1), response.cookies);
}

Future postVote(VoteInformation voteInformation) async {
  var body = 'FORM_SUBMIT=poll_29&REQUEST_TOKEN=${voteInformation.token}&options=&options=126';
  print(voteInformation.cookies.first.toString());
  throw 'a';
  var response = await http.post(url,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Host': 'www.vcoe.at',
        'Origin': 'https://www.vcoe.at',
        'User-Agent': getRandomUserAgent()
      },
      body: body);
  if (response.statusCode < 200 || response.statusCode >= 400) {
    throw 'Voting response was not positive:\n${response.body}';
  }
}


math.Random _rng = new math.Random();
String getRandomUserAgent() => userAgents[_rng.nextInt(userAgents.length)];
