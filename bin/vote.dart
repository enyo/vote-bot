library vote_bot;

import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

import 'package:logging/logging.dart';
import 'package:vote_bot/settings.dart';
import 'dart:convert';

var log = new Logger('VoteBot');
math.Random _rng = new math.Random();

main() async {
  Logger.root.onRecord.listen(print);
  Logger.root.level = Level.ALL;

  await vote();
}

int totalVotes = 0, errorCount = 0;

Future vote() async {
  log.info('Voting now...');
  var nextVoteDuration =
      new Duration(milliseconds: voteInterval.inMilliseconds - _rng.nextInt(voteIntervalTolerance.inMilliseconds));
  try {
    final voteInformation = await getVoteInformation();
    log.info('Got request token ${voteInformation.token}');
    await postVote(voteInformation);
    errorCount = 0;
    totalVotes++;
    log.info('Finished voting. Total votes: $totalVotes. Next vote in $nextVoteDuration');
  } catch (e) {
    log.warning('There was an error: $e');
    errorCount++;
  }
  if (errorCount >= maxErrorCount) {
    log.severe('Too many failed attempts. Quitting now with total votes: $totalVotes.');
  } else {
    new Timer(nextVoteDuration, vote);
  }
}

class VoteInformation {
  final String token;
  final List<Cookie> cookies;
  final String userAgent;
  VoteInformation(this.token, this.cookies, this.userAgent);
}

final tokenRegex = new RegExp(r'name\=\"REQUEST_TOKEN\"\s+value\=\"([a-zA-Z0-9]+)\"');
Future<VoteInformation> getVoteInformation() async {
  HttpClient client = new HttpClient();
  var userAgent = getRandomUserAgent();
  var request = await client.getUrl(Uri.parse(url));
  request.headers..add('User-Agent', userAgent);
  var response = await request.close();
  var responseText = UTF8.decode(await response.fold([], (List prev, bytes) => new List.from(prev)..addAll(bytes)));

  final match = tokenRegex.firstMatch(responseText);
  if (match == null) throw 'No token found';

  return new VoteInformation(match.group(1), response.cookies, userAgent);
}

Future postVote(VoteInformation voteInformation) async {
  final body = 'FORM_SUBMIT=poll_29&REQUEST_TOKEN=${voteInformation.token}&options=&options=126';

  HttpClient client = new HttpClient();
  var uri = Uri.parse(url);
  var clientRequest = await client.postUrl(uri);
  clientRequest.headers
    ..add('Content-Type', 'application/x-www-form-urlencoded')
    ..add('Host', 'www.vcoe.at')
    ..add('Origin', 'https://www.vcoe.at')
    ..add('User-Agent', voteInformation.userAgent);
  voteInformation.cookies.forEach((cookie) => clientRequest.cookies.add(cookie));
  clientRequest.write(body);
  var response = await clientRequest.close();

  var responseText = UTF8.decode(await response.fold([], (List prev, bytes) => new List.from(prev)..addAll(bytes)));

  if (response.statusCode < 200 || response.statusCode >= 400) {
    throw 'Voting response was not positive:\n${responseText}';
  }
}

String getRandomUserAgent() => userAgents[_rng.nextInt(userAgents.length)];
