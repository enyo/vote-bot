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

  Duration nextVoteDuration;
  try {
    final voteInformation = await getVoteInformation();
    log.info('Got request token ${voteInformation.token}');
    await postVote(voteInformation);
    errorCount = 0;
    totalVotes++;
    log.info('Finished voting. Total votes: $totalVotes.');
    nextVoteDuration = _getNextVoteDuration();
  } catch (e) {
    log.warning('There was an error: $e');
    errorCount++;
  }
  if (errorCount >= maxErrorCount) {
    log.severe('Too many failed attempts. Quitting now with total votes: $totalVotes.');
  } else {
    if (nextVoteDuration == null) nextVoteDuration = _getNextVoteDuration();
    new Timer(nextVoteDuration, vote);
  }
}

Duration _getNextVoteDuration() {
  var now = new DateTime.now();
  Duration nextVoteDuration;
  if (now.hour < 6 || now.hour > 23) {
    nextVoteDuration = new Duration(minutes: 40 + _rng.nextInt(20));
    log.info('Next vote in $nextVoteDuration (because of night time)');
  } else {
    if (_rng.nextInt(voteCountBeforeLonger) == 0) {
      var nextVoteDurationMs = voteInterval.inMilliseconds + _rng.nextInt(voteIntervalTolerance.inMilliseconds);
      nextVoteDurationMs += (nextVoteDurationMs * 0.5).round();
      nextVoteDuration = new Duration(milliseconds: nextVoteDurationMs);
      log.info('Next vote in $nextVoteDuration (a bit longer so it is alternating a bit)');
    } else {
      nextVoteDuration =
          new Duration(milliseconds: voteInterval.inMilliseconds - _rng.nextInt(voteIntervalTolerance.inMilliseconds));
      log.info('Next vote in $nextVoteDuration');
    }
  }

  return nextVoteDuration;
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
  } else {
    printStats(responseText);
  }
}

printStats(String responseText) {
  var regex = new RegExp(r'\"result_option\"\>(.*?)\<\/div\>[\s\S]*?result_prct\"\>(\d+)');
  var matches = regex.allMatches(responseText);

  log.info(matches.map((match) {
    var name = match.group(1).split(' ').first, percentage = match.group(2);
    return ('$name:$percentage%');
  }).join('  –  '));
}

String getRandomUserAgent() => userAgents[_rng.nextInt(userAgents.length)];
