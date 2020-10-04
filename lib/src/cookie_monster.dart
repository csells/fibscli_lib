// From http://www.fibs.com/fcm/
// FIBS Client Protocol Detailed Specification: http://www.fibs.com/fibs_interface.html
/*
 *---  FIBSCookieMonster.c --------------------------------------------------
 *
 *  Created by Paul Ferguson on Tue Dec 24 2002.
 *  Copyright (c) 2003 Paul Ferguson. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * * Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 *
 * * Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the distribution.
 *
 * * The name of Paul D. Ferguson may not be used to endorse or promote
 *   products derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
 * IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
 * OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *---------------------------------------------------------------------------
 * Oct, 2016, csells ported this to C# as part of Fibs.Net, added some useful features
 * http://github.com/csells/fibs.net
 * Oct, 2020, csells ported this to Dart as part of a FIBS Backgammon client for Flutter
 * http://github.com/csells/fibscli
 */

import 'package:meta/meta.dart';
import 'package:quiver/strings.dart';

class CookieMessage {
  final FibsCookie cookie;
  final String raw;
  Map<String, String> crumbs;
  final CookieMonsterState eatState;

  CookieMessage(this.cookie, this.raw, this.crumbs, this.eatState)
      :
        // Cannot have zero-length crumb dictionary. Pass null instead.
        assert(crumbs == null || crumbs.isNotEmpty);
}

// A simple state model
enum CookieMonsterState { FIBS_LOGIN_STATE, FIBS_MOTD_STATE, FIBS_RUN_STATE, FIBS_LOGOUT_STATE }

// Principle data structure. Used internally--clients never see the dough,
// just the finished cookie. TODO: rename to be private
class CookieDough {
  final FibsCookie cookie;
  final RegExp regex; // TODO: rename
  final Map<String, String> extras;
  CookieDough({@required this.cookie, @required this.regex, this.extras});
}

class CookieMonster {
  CookieMonsterState messageState = CookieMonsterState.FIBS_LOGIN_STATE;
  CookieMonsterState oldMessageState;

  static CookieMessage MakeCookie(List<CookieDough> batch, String raw, CookieMonsterState eatState) {
    for (final dough in batch) {
      var match = dough.regex.firstMatch(raw);
      if (match != null) {
        var crumbs = <String, String>{};
        var namedGroups = match.groupNames.where((n) => !isDigit(n.codeUnitAt(0)));
        for (final name in namedGroups) {
          var value = match.namedGroup(name).trim();
          crumbs[name] = value;

          // only "message" values are allowed to be empty
          assert((name == 'message') || !(value == null || value.isEmpty), '${dough.cookie}: missing crumb "$name"');
        }

        // drop in hard-coded extra name-value pairs
        if (dough.extras != null) {
          for (final pair in dough.extras.entries) {
            crumbs[pair.key] = pair.value;

            // only "message" values are allowed to be empty
            assert((pair.key == 'message') || !(pair.value == null || pair.value.isEmpty),
                '${dough.cookie}: missing crumb "{pair.Key}"');
          }
        }

        return CookieMessage(dough.cookie, raw, crumbs.isEmpty ? null : crumbs, eatState);
      }
    }

    return null;
  }

  // // Returns a cookie message
  // // NOTE: The incoming FIBS message should NOT include line terminators.
  // public CookieMessage EatCookie(string raw) {
  //   var eatState = MessageState;
  //   CookieMessage cm = null;

  //   switch (MessageState) {
  //     case States.FIBS_RUN_STATE:
  //       if (string.IsNullOrEmpty(raw)) {
  //         cm = new CookieMessage(FibsCookie.FIBS_Empty, raw, null, eatState);
  //         break;
  //       }

  //       char ch = raw[0];
  //       // CLIP messages and miscellaneous numeric messages
  //       if (char.IsDigit(ch)) {
  //         cm = MakeCookie(NumericBatch, raw, eatState);
  //       }
  //       // '** ' messages
  //       else if (ch == '*') {
  //         cm = MakeCookie(StarsBatch, raw, eatState);
  //       }
  //       // all other messages
  //       else {
  //         cm = MakeCookie(AlphaBatch, raw, eatState);
  //       }

  //       if (cm != null && cm.Cookie == FibsCookie.FIBS_Goodbye) {
  //         MessageState = States.FIBS_LOGOUT_STATE;
  //       }
  //       break;

  //     case States.FIBS_LOGIN_STATE:
  //       cm = MakeCookie(LoginBatch, raw, eatState);
  //       Debug.Assert(cm != null); // there's a catch all
  //       if (cm.Cookie == FibsCookie.CLIP_MOTD_BEGIN) {
  //         MessageState = States.FIBS_MOTD_STATE;
  //       }
  //       break;

  //     case States.FIBS_MOTD_STATE:
  //       cm = MakeCookie(MOTDBatch, raw, eatState);
  //       Debug.Assert(cm != null); // there's a catch all
  //       if (cm.Cookie == FibsCookie.CLIP_MOTD_END) {
  //         MessageState = States.FIBS_RUN_STATE;
  //       }
  //       break;

  //     case States.FIBS_LOGOUT_STATE:
  //       cm = new CookieMessage(FibsCookie.FIBS_PostGoodbye, raw, new Dictionary<string, string> { { "message", raw } }, eatState);
  //       break;

  //     default:
  //       throw new System.Exception($"Unknown state: {MessageState}");
  //   }

  //   if (cm == null) { cm = new CookieMessage(FibsCookie.FIBS_Unknown, raw, new Dictionary<string, string> { { "raw", raw } }, eatState); }

  //   // output the initial state if no state has been shown at all
  //   if (OldMessageState == null) {
  //     Debug.WriteLine($"State= {eatState}");
  //     OldMessageState = eatState;
  //   }

  //   Debug.WriteLine($"{cm.Cookie}: '{cm.Raw}'");
  //   if (cm.Crumbs != null) {
  //     var crumbs = string.Join(", ", cm.Crumbs.Select(kvp => $"{kvp.Key}= {kvp.Value}"));
  //     Debug.WriteLine($"\t{crumbs}");
  //   }

  //   // output the new state as soon as we transition
  //   if (OldMessageState != MessageState) {
  //     Debug.WriteLine($"State= {MessageState}");
  //     OldMessageState = MessageState;
  //   }

  //   return cm;
  // }

  // "-" returned as null
  static String parseOptional(String s) => s.trim() == '-' ? null : s;
  static bool parseBool(String s) => s == '1' || s == 'YES';
  static String parseBoardTurn(String s) => parseTurnColor(int.parse(s));
  static String parseBoardColorInt(int i) => i == -1 ? 'X' : 'O';
  static String parseBoardColorString(String s) => parseBoardColorInt(int.parse(s));

  static DateTime parseTimestamp(String timestamp) =>
      DateTime(1970, 1, 1, 0, 0, 0).toUtc().add(Duration(seconds: int.parse(timestamp)));

  static String parseTurnColor(int i) {
    if (i == -1) {
      return 'X';
    } else if (i == 1) {
      return 'O';
    } else {
      return null;
    }
  }

  // Initialize stuff, ready to start pumping out cookies by the thousands.
  // Note that the order of items in this function is important, in some cases
  // messages are very similar and are differentiated by depending on the
  // order the batch is processed.

  static final catchAllIntoMessageRegex = RegExp('(?<message>.*)');

  // for RUN_STATE
  static final alphaBatch = [
    CookieDough(
        cookie: FibsCookie.FIBS_Board,
        regex: RegExp(
            r'^board:(?<player1>[^:]+):(?<player2>[^:]+):(?<matchLength>\d+):(?<player1Score>\d+):(?<player2Score>\d+):(?<board>([-0-9]+:){25}\d+):(?<turnColor>-1|0|1):(?<player1Dice>\d:\d):(?<player2Dice>\d:\d):(?<doublingCube>\d+):(?<player1MayDouble>[0-1]):(?<player2MayDouble>[0-1]):(?<wasDoubled>[0-1]):(?<player1Color>-?1):(?<direction>-?1):\d+:\d+:(?<player1Home>\d+):(?<player2Home>\d+):(?<player1Bar>\d+):(?<player2Bar>\d+):(?<canMove>[0-4]):\d+:\d+:(?<redoubles>\d+)$')),
    CookieDough(cookie: FibsCookie.FIBS_YouRoll, regex: RegExp(r'^You roll (?<die1>[1-6]) and (?<die2>[1-6])')),
    CookieDough(
        cookie: FibsCookie.FIBS_PlayerRolls,
        regex: RegExp(r'^(?<opponent>[a-zA-Z_<>]+) rolls (?<die1>[1-6]) and (?<die2>[1-6])')),
    CookieDough(cookie: FibsCookie.FIBS_RollOrDouble, regex: RegExp(r"^It's your turn to roll or double\\.")),
    CookieDough(cookie: FibsCookie.FIBS_RollOrDouble, regex: RegExp(r"^It's your turn\\. Please roll or double")),
    CookieDough(
        cookie: FibsCookie.FIBS_AcceptRejectDouble,
        regex: RegExp(r"^(?<opponent>[a-zA-Z_<>]+) doubles\\. Type 'accept' or 'reject'\\.")),
    CookieDough(cookie: FibsCookie.FIBS_Doubles, regex: RegExp(r'(?<opponent>^[a-zA-Z_<>]+) doubles\\.')),
    CookieDough(
        cookie: FibsCookie.FIBS_PlayerAcceptsDouble,
        regex: RegExp(r'(?<opponent>^[a-zA-Z_<>]+) accepts the double\\.')),
    CookieDough(cookie: FibsCookie.FIBS_PleaseMove, regex: RegExp(r'^Please move (?<pieces>[1-4]) pieces?\\.')),
    CookieDough(
        cookie: FibsCookie.FIBS_PlayerMoves, regex: RegExp(r'^(?<player>[a-zA-Z_<>]+) moves (?<moves>[0-9- ]+)')),
    CookieDough(cookie: FibsCookie.FIBS_PlayerCantMove, regex: RegExp("^(?<player>[a-zA-Z_<>]+) can't move")),
    CookieDough(cookie: FibsCookie.FIBS_BearingOff, regex: RegExp("^Bearing off: (?<bearing>.*)")),
    CookieDough(cookie: FibsCookie.FIBS_YouReject, regex: RegExp("^You reject\\. The game continues\\.")),
    CookieDough(
        cookie: FibsCookie.FIBS_YouStopWatching,
        regex: RegExp(
            "(?<name>[a-zA-Z_<>]+) logs out\\. You're not watching anymore\\.")), // overloaded	//PLAYER logs out. You're not watching anymore.
    CookieDough(
        cookie: FibsCookie.FIBS_OpponentLogsOut,
        regex: RegExp(
            "^(?<opponent>[a-zA-Z_<>]+) logs out\\. The game was saved")), // PLAYER logs out. The game was saved.
    CookieDough(
        cookie: FibsCookie.FIBS_OpponentLogsOut,
        regex: RegExp(
            "^(?<opponent>[a-zA-Z_<>]+) drops connection\\. The game was saved")), // PLAYER drops connection. The game was saved.
    CookieDough(cookie: FibsCookie.FIBS_OnlyPossibleMove, regex: RegExp("^The only possible move is (?<move>.*)")),
    CookieDough(
        cookie: FibsCookie.FIBS_FirstRoll,
        regex: RegExp("(?<opponent>[a-zA-Z_<>]+) rolled (?<opponentDie>[1-6]).+rolled (?<yourDie>[1-6])")),
    CookieDough(
        cookie: FibsCookie.FIBS_MakesFirstMove, regex: RegExp("(?<opponent>[a-zA-Z_<>]+) makes the first move\\.")),
    CookieDough(
        cookie: FibsCookie.FIBS_YouDouble,
        regex: RegExp(
            "^You double\\. Please wait for (?<opponent>[a-zA-Z_<>]+) to accept or reject")), // You double. Please wait for PLAYER to accept or reject.
    CookieDough(
        cookie: FibsCookie.FIBS_PlayerWantsToResign,
        regex: RegExp(
            "^(?<opponent>[a-zA-Z_<>]+) wants to resign\\. You will win (?<points>[0-9]+) points?\\. Type 'accept' or 'reject'\\.")),
    CookieDough(
        cookie: FibsCookie.FIBS_WatchResign,
        regex: RegExp(
            "^(?<player1>[a-zA-Z_<>]+) wants to resign\\. (?<player2>[a-zA-Z_<>]+) will win (?<points>[0-9]+) points")), // PLAYER wants to resign. PLAYER2 will win 2 points.  (ORDER MATTERS HERE)
    CookieDough(
        cookie: FibsCookie.FIBS_YouResign,
        regex: RegExp(
            "^You want to resign. (?<opponent>[a-zA-Z_<>]+) will win (?<points>[0-9]+)")), // You want to resign. PLAYER will win 1 .
    CookieDough(
        cookie: FibsCookie.FIBS_ResumeMatchAck5,
        regex: RegExp("^You are now playing with (?<opponent>[a-zA-Z_<>]+)\\. Your running match was loaded")),
    CookieDough(
        cookie: FibsCookie.FIBS_JoinNextGame,
        regex: RegExp("^Type 'join' if you want to play the next game, type 'leave' if you don't\\.")),
    CookieDough(
        cookie: FibsCookie.FIBS_NewMatchRequest,
        regex: RegExp("^(?<name>[a-zA-Z_<>]+) wants to play a (?<points>[0-9]+) point match with you\\.")),
    CookieDough(
        cookie: FibsCookie.FIBS_WARNINGSavedMatch, regex: RegExp("^WARNING: Don't accept if you want to continue")),
    CookieDough(
        cookie: FibsCookie.FIBS_ResignRefused,
        regex: RegExp("^(?<opponent>[a-zA-Z_<>]+) rejects\\. The game continues\\.")),
    CookieDough(cookie: FibsCookie.FIBS_MatchLength, regex: RegExp("^match length: (?<length>.*)")),
    CookieDough(cookie: FibsCookie.FIBS_TypeJoin, regex: RegExp("^Type 'join (?<opponent>[a-zA-Z_<>]+)' to accept\\.")),
    CookieDough(cookie: FibsCookie.FIBS_YouAreWatching, regex: RegExp("^You're now watching (?<name>[a-zA-Z_<>]+)")),
    CookieDough(
        cookie: FibsCookie.FIBS_YouStopWatching,
        regex: RegExp("^You stop watching (?<name>[a-zA-Z_<>]+)")), // overloaded
    CookieDough(
        cookie: FibsCookie.FIBS_NotDoingAnything,
        regex: RegExp("^(?<name>[a-zA-Z_<>]+) is not doing anything interesting\\.")),
    CookieDough(
        cookie: FibsCookie.FIBS_PlayerStartsWatching,
        regex: RegExp("(?<player1>[a-zA-Z_<>]+) starts watching (?<player2>[a-zA-Z_<>]+)")),
    CookieDough(cookie: FibsCookie.FIBS_PlayerStartsWatching, regex: RegExp("(?<name>[a-zA-Z_<>]+) is watching you")),
    CookieDough(
        cookie: FibsCookie.FIBS_PlayerStopsWatching,
        regex: RegExp("(?<name>[a-zA-Z_<>]+) stops watching (?<player>[a-zA-Z_<>]+)")),
    CookieDough(cookie: FibsCookie.FIBS_PlayerIsWatching, regex: RegExp("(?<name>[a-zA-Z_<>]+) is watching ")),
    CookieDough(
        cookie: FibsCookie.FIBS_PlayerLeftGame,
        regex: RegExp("(?<player1>[a-zA-Z_<>]+) has left the game with (?<player2>[a-zA-Z_<>]+)")),
    CookieDough(
        cookie: FibsCookie.FIBS_ResignWins,
        regex: RegExp(
            "^(?<player1>[a-zA-Z_<>]+) gives up\\. (?<player2>[a-zA-Z_<>]+) wins (?<points>[0-9]+) points?")), // PLAYER1 gives up. PLAYER2 wins 1 point.
    CookieDough(
        cookie: FibsCookie.FIBS_ResignYouWin,
        regex: RegExp("^(?<opponent>[a-zA-Z_<>]+) gives up\\. You win (?<points>[0-9]+) points")),
    CookieDough(cookie: FibsCookie.FIBS_YouAcceptAndWin, regex: RegExp("^You accept and win (?<something>.*)")),
    CookieDough(
        cookie: FibsCookie.FIBS_AcceptWins,
        regex: RegExp(
            "^(?<opponent>[a-zA-Z_<>]+) accepts and wins (?<points>[0-9]+) point")), // PLAYER accepts and wins N points.
    CookieDough(
        cookie: FibsCookie.FIBS_PlayersStartingMatch,
        regex: RegExp(
            "^(?<player1>[a-zA-Z_<>]+) and (?<player2>[a-zA-Z_<>]+) start a (?<points>[0-9]+) point match")), // PLAYER and PLAYER start a <n> point match.
    CookieDough(
        cookie: FibsCookie.FIBS_StartingNewGame, regex: RegExp("^Starting a  game with (?<opponent>[a-zA-Z_<>]+)")),
    CookieDough(cookie: FibsCookie.FIBS_YouGiveUp, regex: RegExp("^You give up")),
    CookieDough(
        cookie: FibsCookie.FIBS_YouWinMatch,
        regex: RegExp("^You win the (?<points>[0-9]+) point match (?<winnerScore>[0-9]+)-(?<loserScore>[0-9]+)")),
    CookieDough(
        cookie: FibsCookie.FIBS_PlayerWinsMatch,
        regex: RegExp(
            "^(?<opponent>[a-zA-Z_<>]+) wins the (?<points>[0-9]+) point match (?<winnerScore>[0-9]+)-(?<loserScore>[0-9]+)")), //PLAYER wins the 3 point match 3-0 .
    CookieDough(
        cookie: FibsCookie.FIBS_ResumingUnlimitedMatch,
        regex: RegExp("^(?<player1>[a-zA-Z_<>]+) and (?<player2>[a-zA-Z_<>]+) are resuming their unlimited match\\.")),
    CookieDough(
        cookie: FibsCookie.FIBS_ResumingLimitedMatch,
        regex: RegExp(
            "^(?<player1>[a-zA-Z_<>]+) and (?<player2>[a-zA-Z_<>]+) are resuming their (?<points>[0-9]+)-point match\\.")),
    CookieDough(
        cookie: FibsCookie.FIBS_MatchResult,
        regex: RegExp(
            "^(?<winner>[a-zA-Z_<>]+) wins a (?<points>[0-9]+) point match against (?<loser>[a-zA-Z_<>]+) +(?<winnerScore>[0-9]+)-(?<loserScore>[0-9]+)")), //PLAYER wins a 9 point match against PLAYER  11-6 .
    CookieDough(
        cookie: FibsCookie.FIBS_PlayerWantsToResign,
        regex: RegExp(
            "^(?<name>[a-zA-Z_<>]+) wants to resign\\.")), //  Same as a longline in an actual game  This is just for watching.
    CookieDough(
        cookie: FibsCookie.FIBS_BAD_AcceptDouble,
        regex: RegExp("^(?<name>[a-zA-Z_<>]+) accepts? the double\\. The cube shows (?<cube>[0-9]+)")),
    CookieDough(
        cookie: FibsCookie.FIBS_YouAcceptDouble,
        regex: RegExp("^You accept the double\\. The cube shows (?<cube>[0-9]+)")),
    CookieDough(
        cookie: FibsCookie.FIBS_PlayerAcceptsDouble,
        regex: RegExp("(?<name>^[a-zA-Z_<>]+) accepts the double\\. The cube shows (?<cube>[0-9]+)")),
    CookieDough(
        cookie: FibsCookie.FIBS_PlayerAcceptsDouble,
        regex: RegExp("^(?<name>[a-zA-Z_<>]+) accepts the double")), // while watching
    CookieDough(
        cookie: FibsCookie.FIBS_ResumeMatchRequest,
        regex: RegExp("^(?<name>[a-zA-Z_<>]+) wants to resume a saved match with you")),
    CookieDough(
        cookie: FibsCookie.FIBS_ResumeMatchAck0,
        regex: RegExp("^(?<opponent>[a-zA-Z_<>]+) has joined you\\. Your running match was loaded")),
    CookieDough(cookie: FibsCookie.FIBS_YouWinGame, regex: RegExp("^You win the game and get (?<points>[0-9]+)")),
    CookieDough(
        cookie: FibsCookie.FIBS_UnlimitedInvite,
        regex: RegExp("^(?<name>[a-zA-Z_<>]+) wants to play an unlimted match with you")),
    CookieDough(
        cookie: FibsCookie.FIBS_PlayerWinsGame,
        regex: RegExp("^(?<opponent>[a-zA-Z_<>]+) wins the game and gets (?<points>[0-9]+) points?. Sorry")),
    // CookieDough (cookie: FibsCookie.FIBS_PlayerWinsGame, regex: RegExp("^[a-zA-Z_<>]+ wins the game and gets [0-9] points?.")), // (when watching)
    CookieDough(
        cookie: FibsCookie.FIBS_WatchGameWins,
        regex: RegExp("^(?<name>[a-zA-Z_<>]+) wins the game and gets (?<points>[0-9]+) points")),
    CookieDough(
        cookie: FibsCookie.FIBS_PlayersStartingUnlimitedMatch,
        regex: RegExp(
            "^(?<player1>[a-zA-Z_<>]+) and (?<player2>[a-zA-Z_<>]+) start an unlimited match")), // PLAYER_A and PLAYER_B start an unlimited match.
    CookieDough(
        cookie: FibsCookie.FIBS_ReportLimitedMatch,
        regex: RegExp(
            "^(?<player1>[a-zA-Z_<>]+) +- +(?<player2>[a-zA-Z_<>]+) (?<points>[0-9]+) point match (?<score1>[0-9]+)-(?<score2>[0-9]+)")), // PLAYER_A        -       PLAYER_B (5 point match 2-2)
    CookieDough(
        cookie: FibsCookie.FIBS_ReportUnlimitedMatch,
        regex: RegExp("^(?<player1>[a-zA-Z_<>]+) +- +(?<player2>[a-zA-Z_<>]+) \\(unlimited (?<something>.*)")),
    CookieDough(
        cookie: FibsCookie.FIBS_ShowMovesStart,
        regex: RegExp("^(?<playerX>[a-zA-Z_<>]+) is X - (?<playerO>[a-zA-Z_<>]+) is O")),
    CookieDough(cookie: FibsCookie.FIBS_ShowMovesRoll, regex: RegExp("^[XO]: \\([1-6]")), // ORDER MATTERS HERE
    CookieDough(cookie: FibsCookie.FIBS_ShowMovesWins, regex: RegExp("^[XO]: wins")),
    CookieDough(cookie: FibsCookie.FIBS_ShowMovesDoubles, regex: RegExp("^[XO]: doubles")),
    CookieDough(cookie: FibsCookie.FIBS_ShowMovesAccepts, regex: RegExp("^[XO]: accepts")),
    CookieDough(cookie: FibsCookie.FIBS_ShowMovesRejects, regex: RegExp("^[XO]: rejects")),
    CookieDough(cookie: FibsCookie.FIBS_ShowMovesOther, regex: RegExp("^[XO]:")), // AND HERE
    CookieDough(cookie: FibsCookie.FIBS_ScoreUpdate, regex: RegExp("^score in (?<points>[0-9]+) point match:")),
    CookieDough(
        cookie: FibsCookie.FIBS_MatchStart,
        regex: RegExp("^Score is (?<score1>[0-9]+)-(?<score2>[0-9]+) in a (?<points>[0-9]+) point match\\.")),
    CookieDough(cookie: FibsCookie.FIBS_SettingsHeader, regex: RegExp("^Settings of variables:")),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsValue,
        regex: RegExp(
            "^(?<name>allowpip|autoboard|autodouble|automove|bell|crawford|double|moreboards|moves|greedy|notify|ratings|ready|report|silent|telnet|wrap) +(?<value>YES|NO)")),
    CookieDough(cookie: FibsCookie.FIBS_Turn, regex: RegExp("^turn:")),
    CookieDough(cookie: FibsCookie.FIBS_SettingsValue, regex: RegExp("^(?<name>boardstyle): +(?<value>[1-3])")),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp("^Value of '(?<name>boardstyle)' set to (?<value>[1-3])\\.")),
    CookieDough(cookie: FibsCookie.FIBS_SettingsValue, regex: RegExp("^(?<name>linelength): +(?<value>[0-9]+)")),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp("^Value of '(?<name>linelength)' set to (?<value>[0-9]+)\\.")),
    CookieDough(cookie: FibsCookie.FIBS_SettingsValue, regex: RegExp("^(?<name>pagelength): +(?<value>[0-9]+)")),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp("^Value of '(?<name>pagelength)' set to (?<value>[0-9]+)\\.")),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsValue, regex: RegExp("^(?<name>redoubles): +(?<value>none|unlimited|[0-9]+)")),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp("^Value of '(?<name>redoubles)' set to '?(?<value>none|unlimited|[0-9]+)'?\\.")),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsValue,
        regex: RegExp("^(?<name>sortwho): +(?<value>login|name|rating|rrating)")),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp("^Value of '(?<name>sortwho)' set to (?<value>login|name|rating|rrating)")),
    CookieDough(cookie: FibsCookie.FIBS_SettingsValue, regex: RegExp("^(?<name>timezone): +(?<value>.*)")),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange, regex: RegExp("^Value of '(?<name>timezone)' set to (?<value>.*)\\.")),
    CookieDough(
        cookie: FibsCookie.FIBS_CantMove,
        regex: RegExp("^(?<name>[a-zA-Z_<>]+) can't move")), // PLAYER can't move || You can't move
    CookieDough(cookie: FibsCookie.FIBS_ListOfGames, regex: RegExp("^List of games:")),
    CookieDough(cookie: FibsCookie.FIBS_PlayerInfoStart, regex: RegExp("^Information about")),
    CookieDough(cookie: FibsCookie.FIBS_EmailAddress, regex: RegExp("^  Email address:")),
    CookieDough(cookie: FibsCookie.FIBS_NoEmail, regex: RegExp("^  No email address")),
    CookieDough(cookie: FibsCookie.FIBS_WavesAgain, regex: RegExp("^(?<name>[a-zA-Z_<>]+) waves goodbye again")),
    CookieDough(cookie: FibsCookie.FIBS_Waves, regex: RegExp("^(?<name>[a-zA-Z_<>]+) waves goodbye")),
    CookieDough(cookie: FibsCookie.FIBS_Waves, regex: RegExp("^You wave goodbye")),
    CookieDough(cookie: FibsCookie.FIBS_WavesAgain, regex: RegExp("^You wave goodbye again and log out")),
    CookieDough(cookie: FibsCookie.FIBS_NoSavedGames, regex: RegExp("^no saved games")),
    CookieDough(
        cookie: FibsCookie.FIBS_SavedMatch,
        regex: RegExp("^  (?<player1>[a-zA-Z_<>]+) +(?<score1>[0-9]+) +(?<score2>[0-9]+) +- +(?<something>.*)")),
    CookieDough(cookie: FibsCookie.FIBS_SavedMatchPlaying, regex: RegExp("^ \\*[a-zA-Z_<>]+ +[0-9]+ +[0-9]+ +- +")),
    // NOTE: for FIBS_SavedMatchReady, see the Stars message, because it will appear to be one of those (has asterisk at index 0).
    CookieDough(
        cookie: FibsCookie.FIBS_PlayerIsWaitingForYou, regex: RegExp("^[a-zA-Z_<>]+ is waiting for you to log in\\.")),
    CookieDough(cookie: FibsCookie.FIBS_IsAway, regex: RegExp("^[a-zA-Z_<>]+ is away: ")),
    CookieDough(cookie: FibsCookie.FIBS_Junk, regex: RegExp("^Closed old connection with user")),
    CookieDough(cookie: FibsCookie.FIBS_Done, regex: RegExp("^Done\\.")),
    CookieDough(cookie: FibsCookie.FIBS_YourTurnToMove, regex: RegExp("^It's your turn to move\\.")),
    CookieDough(
        cookie: FibsCookie.FIBS_SavedMatchesHeader,
        regex: RegExp("^  opponent          matchlength   score \\(your points first\\)")),
    CookieDough(cookie: FibsCookie.FIBS_MessagesForYou, regex: RegExp("^There are messages for you:")),
    CookieDough(
        cookie: FibsCookie.FIBS_DoublingCubeNow, regex: RegExp("^The number on the doubling cube is now [0-9]+")),
    CookieDough(
        cookie: FibsCookie.FIBS_FailedLogin,
        regex: RegExp("^> [0-9]+")), // bogus CLIP messages sent after a failed login
    CookieDough(cookie: FibsCookie.FIBS_Average, regex: RegExp("^Time (UTC)  average min max")),
    CookieDough(cookie: FibsCookie.FIBS_DiceTest, regex: RegExp("^[nST]: ")),
    CookieDough(cookie: FibsCookie.FIBS_LastLogout, regex: RegExp("^  Last logout:")),
    CookieDough(cookie: FibsCookie.FIBS_RatingCalcStart, regex: RegExp("^rating calculation:")),
    CookieDough(cookie: FibsCookie.FIBS_RatingCalcInfo, regex: RegExp("^Probability that underdog wins:")),
    CookieDough(
        cookie: FibsCookie.FIBS_RatingCalcInfo,
        regex: RegExp("is 1-Pu if underdog wins")), // P=0.505861 is 1-Pu if underdog wins and Pu if favorite wins
    CookieDough(
        cookie: FibsCookie.FIBS_RatingCalcInfo, regex: RegExp("^Experience: ")), // Experience: fergy 500 - jfk 5832
    CookieDough(
        cookie: FibsCookie.FIBS_RatingCalcInfo,
        regex: RegExp("^K=max\\(1")), // K=max(1 ,		-Experience/100+5) for fergy: 1.000000
    CookieDough(cookie: FibsCookie.FIBS_RatingCalcInfo, regex: RegExp("^rating difference")),
    CookieDough(
        cookie: FibsCookie.FIBS_RatingCalcInfo,
        regex: RegExp("^change for")), // change for fergy: 4*K*sqrt(N)*P=2.023443
    CookieDough(cookie: FibsCookie.FIBS_RatingCalcInfo, regex: RegExp("^match length  ")),
    CookieDough(cookie: FibsCookie.FIBS_WatchingHeader, regex: RegExp("^Watching players:")),
    CookieDough(cookie: FibsCookie.FIBS_SettingsHeader, regex: RegExp("^The current settings are:")),
    CookieDough(cookie: FibsCookie.FIBS_AwayListHeader, regex: RegExp("^The following users are away:")),
    CookieDough(
        cookie: FibsCookie.FIBS_RatingExperience,
        regex: RegExp("^  Rating: +[0-9]+\\.")), // Rating: 1693.11 Experience: 5781
    CookieDough(cookie: FibsCookie.FIBS_NotLoggedIn, regex: RegExp("^  Not logged in right now\\.")),
    CookieDough(cookie: FibsCookie.FIBS_IsPlayingWith, regex: RegExp("is playing with")),
    CookieDough(
        cookie: FibsCookie.FIBS_SavedScoreHeader,
        regex: RegExp("^opponent +matchlength")), //	opponent          matchlength   score (your points first)
    CookieDough(
        cookie: FibsCookie.FIBS_StillLoggedIn,
        regex: RegExp("^  Still logged in\\.")), //  Still logged in. 2:12 minutes idle.
    CookieDough(cookie: FibsCookie.FIBS_NoOneIsAway, regex: RegExp("^None of the users is away\\.")),
    CookieDough(
        cookie: FibsCookie.FIBS_PlayerListHeader,
        regex: RegExp("^No  S  username        rating  exp login    idle  from")),
    CookieDough(cookie: FibsCookie.FIBS_RatingsHeader, regex: RegExp("^ rank name            rating    Experience")),
    CookieDough(cookie: FibsCookie.FIBS_ClearScreen, regex: RegExp("^.\\[, },H.\\[2J")), // ANSI clear screen sequence
    CookieDough(cookie: FibsCookie.FIBS_Timeout, regex: RegExp("^Connection timed out\\.")),
    CookieDough(cookie: FibsCookie.FIBS_Goodbye, regex: RegExp("(?<message>           Goodbye\\.)")),
    CookieDough(cookie: FibsCookie.FIBS_LastLogin, regex: RegExp("^  Last login:")),
    CookieDough(cookie: FibsCookie.FIBS_NoInfo, regex: RegExp("^No information found on user")),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp("^You're away\\. Please type 'back'"),
        extras: {"name": "away", "value": "YES"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp("^Welcome back\\."),
        extras: {"name": "away", "value": "NO"}),
  ];

  //--- Numeric messages ---------------------------------------------------
  static final numericBatch = [
    CookieDough(
        cookie: FibsCookie.CLIP_WHO_INFO,
        regex: RegExp(
            r"^5 (?<name>[^ ]+) (?<opponent>[^ ]+) (?<watching>[^ ]+) (?<ready>[01]) (?<away>[01]) (?<rating>[0-9]+\\.[0-9]+) (?<experience>[0-9]+) (?<idle>[0-9]+) (?<login>[0-9]+) (?<hostName>[^ ]+) (?<client>[^ ]+) (?<email>[^ ]+)")),
    CookieDough(
        cookie: FibsCookie.FIBS_Average, regex: RegExp(r"^[0-9][0-9]:[0-9][0-9]-")), // output of average command
    CookieDough(cookie: FibsCookie.FIBS_DiceTest, regex: RegExp(r"^[1-6]-1 [0-9]")), // output of dicetest command
    CookieDough(cookie: FibsCookie.FIBS_DiceTest, regex: RegExp(r"^[1-6]: [0-9]")),
    CookieDough(cookie: FibsCookie.FIBS_Stat, regex: RegExp(r"^[0-9]+ bytes")), // output from stat command
    CookieDough(cookie: FibsCookie.FIBS_Stat, regex: RegExp(r"^[0-9]+ accounts")),
    CookieDough(cookie: FibsCookie.FIBS_Stat, regex: RegExp(r"^[0-9]+ ratings saved. reset log")),
    CookieDough(cookie: FibsCookie.FIBS_Stat, regex: RegExp(r"^[0-9]+ registered users.")),
    CookieDough(cookie: FibsCookie.FIBS_Stat, regex: RegExp(r"^[0-9]+\\([0-9]+\\) saved games check by cron")),
    CookieDough(cookie: FibsCookie.CLIP_WHO_END, regex: RegExp(r"^6$")),
    CookieDough(cookie: FibsCookie.CLIP_SHOUTS, regex: RegExp(r"^13 (?<name>[a-zA-Z_<>]+) (?<message>.*)")),
    CookieDough(cookie: FibsCookie.CLIP_SAYS, regex: RegExp(r"^12 (?<name>[a-zA-Z_<>]+) (?<message>.*)")),
    CookieDough(cookie: FibsCookie.CLIP_WHISPERS, regex: RegExp(r"^14 (?<name>[a-zA-Z_<>]+) (?<message>.*)")),
    CookieDough(cookie: FibsCookie.CLIP_KIBITZES, regex: RegExp(r"^15 (?<name>[a-zA-Z_<>]+) (?<message>.*)")),
    CookieDough(cookie: FibsCookie.CLIP_YOU_SAY, regex: RegExp(r"^16 (?<name>[a-zA-Z_<>]+) (?<message>.*)")),
    CookieDough(cookie: FibsCookie.CLIP_YOU_SHOUT, regex: RegExp(r"^17 (?<message>.*)")),
    CookieDough(cookie: FibsCookie.CLIP_YOU_WHISPER, regex: RegExp(r"^18 (?<message>.*)")),
    CookieDough(cookie: FibsCookie.CLIP_YOU_KIBITZ, regex: RegExp(r"^19 (?<message>.*)")),
    CookieDough(cookie: FibsCookie.CLIP_LOGIN, regex: RegExp(r"^7 (?<name>[a-zA-Z_<>]+) (?<message>.*)")),
    CookieDough(cookie: FibsCookie.CLIP_LOGOUT, regex: RegExp(r"^8 (?<name>[a-zA-Z_<>]+) (?<message>.*)")),
    CookieDough(
        cookie: FibsCookie.CLIP_MESSAGE, regex: RegExp(r"^9 (?<from>[a-zA-Z_<>]+) (?<time>[0-9]+) (?<message>.*)")),
    CookieDough(cookie: FibsCookie.CLIP_MESSAGE_DELIVERED, regex: RegExp(r"^10 (?<name>[a-zA-Z_<>]+)$")),
    CookieDough(cookie: FibsCookie.CLIP_MESSAGE_SAVED, regex: RegExp(r"^11 (?<name>[a-zA-Z_<>]+)$")),
  ];

  //--- '**' messages ------------------------------------------------------
  static final starsBatch = [
    CookieDough(cookie: FibsCookie.FIBS_Username, regex: RegExp(r"^\\*\\* User")),
    CookieDough(cookie: FibsCookie.FIBS_Junk, regex: RegExp(r"^\\*\\* You tell ")), // "** You tell PLAYER: xxxxx"
    CookieDough(cookie: FibsCookie.FIBS_YouGag, regex: RegExp(r"^\\*\\* You gag")),
    CookieDough(cookie: FibsCookie.FIBS_YouUngag, regex: RegExp(r"^\\*\\* You ungag")),
    CookieDough(cookie: FibsCookie.FIBS_YouBlind, regex: RegExp(r"^\\*\\* You blind")),
    CookieDough(cookie: FibsCookie.FIBS_YouUnblind, regex: RegExp(r"^\\*\\* You unblind")),
    CookieDough(cookie: FibsCookie.FIBS_UseToggleReady, regex: RegExp(r"^\\*\\* Use 'toggle ready' first")),
    CookieDough(
        cookie: FibsCookie.FIBS_NewMatchAck9, regex: RegExp(r"^\\*\\* You are now playing an unlimited match with ")),
    CookieDough(
        cookie: FibsCookie.FIBS_NewMatchAck10,
        regex: RegExp(
            r"^\\*\\* You are now playing a [0-9]+ point match with ")), // ** You are now playing a 5 point match with PLAYER
    CookieDough(
        cookie: FibsCookie.FIBS_NewMatchAck2,
        regex: RegExp(
            r"^\\*\\* Player [a-zA-Z_<>]+ has joined you for a")), // ** Player PLAYER has joined you for a 2 point match.
    CookieDough(cookie: FibsCookie.FIBS_YouTerminated, regex: RegExp(r"^\\*\\* You terminated the game")),
    CookieDough(
        cookie: FibsCookie.FIBS_OpponentLeftGame,
        regex: RegExp(r"^\\*\\* Player [a-zA-Z_<>]+ has left the game. The game was saved\\.")),
    CookieDough(cookie: FibsCookie.FIBS_PlayerLeftGame, regex: RegExp(r"has left the game\\.")), // overloaded
    CookieDough(cookie: FibsCookie.FIBS_YouInvited, regex: RegExp(r"^\\*\\* You invited")),
    CookieDough(cookie: FibsCookie.FIBS_YourLastLogin, regex: RegExp(r"^\\*\\* Last login:")),
    CookieDough(cookie: FibsCookie.FIBS_NoOne, regex: RegExp(r"^\\*\\* There is no one called (?<name>[a-zA-Z_<>]+)")),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* You allow the use the server's 'pip' command\\."),
        extras: {"name": "allowpip", "value": "YES"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* You don't allow the use of the server's 'pip' command\\."),
        extras: {"name": "allowpip", "value": "NO"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* The board will be refreshed"),
        extras: {"name": "autoboard", "value": "YES"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* The board won't be refreshed"),
        extras: {"name": "autoboard", "value": "NO"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* You agree that doublets"),
        extras: {"name": "autodouble", "value": "YES"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* You don't agree that doublets"),
        extras: {"name": "autodouble", "value": "NO"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* Forced moves will"),
        extras: {"name": "automove", "value": "YES"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* Forced moves won't"),
        extras: {"name": "automove", "value": "NO"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* Your terminal will ring"),
        extras: {"name": "bell", "value": "YES"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* Your terminal won't ring"),
        extras: {"name": "bell", "value": "NO"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* You insist on playing with the Crawford rule\\."),
        extras: {"name": "crawford", "value": "YES"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* You would like to play without using the Crawford rule\\."),
        extras: {"name": "crawford", "value": "NO"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* You will be asked if you want to double\\."),
        extras: {"name": "double", "value": "YES"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* You won't be asked if you want to double\\."),
        extras: {"name": "double", "value": "NO"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* Will use automatic greedy bearoffs\\."),
        extras: {"name": "greedy", "value": "YES"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* Won't use automatic greedy bearoffs\\."),
        extras: {"name": "greedy", "value": "NO"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* Will send rawboards after rolling\\."),
        extras: {"name": "moreboards", "value": "YES"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* Won't send rawboards after rolling\\."),
        extras: {"name": "moreboards", "value": "NO"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* You want a list of moves after this game\\."),
        extras: {"name": "moves", "value": "YES"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* You won't see a list of moves after this game\\."),
        extras: {"name": "moves", "value": "NO"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* You'll be notified"),
        extras: {"name": "notify", "value": "YES"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* You won't be notified"),
        extras: {"name": "notify", "value": "NO"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* You'll see how the rating changes are calculated\\."),
        extras: {"name": "ratings", "value": "YES"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* You won't see how the rating changes are calculated\\."),
        extras: {"name": "ratings", "value": "NO"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* You're now ready to invite or join someone\\."),
        extras: {"name": "ready", "value": "YES"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* You're now refusing to play with someone\\."),
        extras: {"name": "ready", "value": "NO"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* You will be informed"),
        extras: {"name": "report", "value": "YES"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* You won't be informed"),
        extras: {"name": "report", "value": "NO"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* You will hear what other players shout\\."),
        extras: {"name": "silent", "value": "YES"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* You won't hear what other players shout\\."),
        extras: {"name": "silent", "value": "NO"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* You use telnet"),
        extras: {"name": "telnet", "value": "YES"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* You use a client program"),
        extras: {"name": "telnet", "value": "NO"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* The server will wrap"),
        extras: {"name": "wrap", "value": "YES"}),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        regex: RegExp(r"^\\*\\* Your terminal knows how to wrap"),
        extras: {"name": "wrap", "value": "NO"}),
    CookieDough(
        cookie: FibsCookie.FIBS_PlayerRefusingGames, regex: RegExp(r"^\\*\\* [a-zA-Z_<>]+ is refusing games\\.")),
    CookieDough(cookie: FibsCookie.FIBS_NotWatching, regex: RegExp(r"^\\*\\* You're not watching\\.")),
    CookieDough(
        cookie: FibsCookie.FIBS_NotWatchingPlaying, regex: RegExp(r"^\\*\\* You're not watching or playing\\.")),
    CookieDough(cookie: FibsCookie.FIBS_NotPlaying, regex: RegExp(r"^\\*\\* You're not playing\\.")),
    CookieDough(cookie: FibsCookie.FIBS_NoUser, regex: RegExp(r"^\\*\\* There is no one called ")),
    CookieDough(cookie: FibsCookie.FIBS_AlreadyPlaying, regex: RegExp(r"is already playing with")),
    CookieDough(cookie: FibsCookie.FIBS_DidntInvite, regex: RegExp(r"^\\*\\* [a-zA-Z_<>]+ didn't invite you.")),
    CookieDough(cookie: FibsCookie.FIBS_BadMove, regex: RegExp(r"^\\*\\* You can't remove this piece")),
    CookieDough(
        cookie: FibsCookie.FIBS_CantMoveFirstMove,
        regex: RegExp(r"^\\*\\* You can't move ")), // ** You can't move 3 points in your first move
    CookieDough(
        cookie: FibsCookie.FIBS_CantShout,
        regex: RegExp(r"^\\*\\* Please type 'toggle silent' again before you shout\\.")),
    CookieDough(cookie: FibsCookie.FIBS_MustMove, regex: RegExp(r"^\\*\\* You must give [1-4] moves")),
    CookieDough(
        cookie: FibsCookie.FIBS_MustComeIn,
        regex: RegExp(r"^\\*\\* You have to remove pieces from the bar in your first move\\.")),
    CookieDough(cookie: FibsCookie.FIBS_UsersHeardYou, regex: RegExp(r"^\\*\\* [0-9]+ users? heard you\\.")),
    CookieDough(cookie: FibsCookie.FIBS_Junk, regex: RegExp(r"^\\*\\* Please wait for [a-zA-Z_<>]+ to join too\\.")),
    CookieDough(
        cookie: FibsCookie.FIBS_SavedMatchReady,
        regex: RegExp(
            r"^\\*\\*[a-zA-Z_<>]+ +[0-9]+ +[0-9]+ +- +[0-9]+")), // double star before a name indicates you have a saved game with this player
    CookieDough(
        cookie: FibsCookie.FIBS_NotYourTurnToRoll, regex: RegExp(r"^\\*\\* It's not your turn to roll the dice\\.")),
    CookieDough(cookie: FibsCookie.FIBS_NotYourTurnToMove, regex: RegExp(r"^\\*\\* It's not your turn to move\\.")),
    CookieDough(cookie: FibsCookie.FIBS_YouStopWatching, regex: RegExp(r"^\\*\\* You stop watching")),
    CookieDough(cookie: FibsCookie.FIBS_UnknownCommand, regex: RegExp(r"^\\*\\* Unknown command: (?<command>.*)$")),
    CookieDough(
        cookie: FibsCookie.FIBS_CantWatch,
        regex: RegExp(r"^\\*\\* You can't watch another game while you're playing\\.")),
    CookieDough(cookie: FibsCookie.FIBS_CantInviteSelf, regex: RegExp(r"^\\*\\* You can't invite yourself\\.")),
    CookieDough(cookie: FibsCookie.FIBS_DontKnowUser, regex: RegExp(r"^\\*\\* Don't know user")),
    CookieDough(cookie: FibsCookie.FIBS_MessageUsage, regex: RegExp(r"^\\*\\* usage: message <user> <text>")),
    CookieDough(cookie: FibsCookie.FIBS_PlayerNotPlaying, regex: RegExp(r"^\\*\\* [a-zA-Z_<>]+ is not playing\\.")),
    CookieDough(cookie: FibsCookie.FIBS_CantTalk, regex: RegExp(r"^\\*\\* You can't talk if you won't listen\\.")),
    CookieDough(cookie: FibsCookie.FIBS_WontListen, regex: RegExp(r"^\\*\\* [a-zA-Z_<>]+ won't listen to you\\.")),
    CookieDough(
        cookie: FibsCookie.FIBS_Why,
        regex: RegExp(r"Why would you want to do that")), // (not sure about ** vs *** at front of line.)
    CookieDough(cookie: FibsCookie.FIBS_Ratings, regex: RegExp(r"^\\* *[0-9]+ +[a-zA-Z_<>]+ +[0-9]+\\.[0-9]+ +[0-9]+")),
    CookieDough(cookie: FibsCookie.FIBS_NoSavedMatch, regex: RegExp(r"^\\*\\* There's no saved match with ")),
    CookieDough(
        cookie: FibsCookie.FIBS_WARNINGSavedMatch,
        regex: RegExp(r"^\\*\\* WARNING: Don't accept if you want to continue")),
    CookieDough(cookie: FibsCookie.FIBS_CantGagYourself, regex: RegExp(r"^\\*\\* You talk too much, don't you\\?")),
    CookieDough(
        cookie: FibsCookie.FIBS_CantBlindYourself,
        regex: RegExp(r"^\\*\\* You can't read this message now, can you\\?")),
    CookieDough(
        cookie: FibsCookie.FIBS_SettingsValue,
        regex: RegExp(r"^\\*\\* You're not away\\."),
        extras: {"name": "away", "value": "NO"}),
  ];

  // for LOGIN_STATE
  static final loginBatch = [
    CookieDough(cookie: FibsCookie.FIBS_LoginPrompt, regex: RegExp('^login:')),
    CookieDough(
        cookie: FibsCookie.FIBS_WARNINGAlreadyLoggedIn,
        regex: RegExp(r'^\\*\\* Warning: You are already logged in\\.')),
    CookieDough(
        cookie: FibsCookie.CLIP_WELCOME,
        regex: RegExp(r'^1 (?<name>[a-zA-Z_<>]+) (?<lastLogin>[0-9]+) (?<lastHost>.*)')),
    CookieDough(
        cookie: FibsCookie.CLIP_OWN_INFO,
        regex: RegExp(
            r'^2 (?<name>[a-zA-Z_<>]+) (?<allowpip>[01]) (?<autoboard>[01]) (?<autodouble>[01]) (?<automove>[01]) (?<away>[01]) (?<bell>[01]) (?<crawford>[01]) (?<double>[01]) (?<experience>[0-9]+) (?<greedy>[01]) (?<moreboards>[01]) (?<moves>[01]) (?<notify>[01]) (?<rating>[0-9]+\\.[0-9]+) (?<ratings>[01]) (?<ready>[01]) (?<redoubles>[0-9a-zA-Z]+) (?<report>[01]) (?<silent>[01]) (?<timezone>.*)')),
    CookieDough(cookie: FibsCookie.CLIP_MOTD_BEGIN, regex: RegExp(r'^3$')),
    CookieDough(
        cookie: FibsCookie.FIBS_FailedLogin,
        regex: RegExp(r'^> [0-9]+')), // bogus CLIP messages sent after a failed login
    CookieDough(cookie: FibsCookie.FIBS_PreLogin, regex: catchAllIntoMessageRegex), // catch all
  ];

  // Only interested in one message here, but we still use a message list for simplicity and consistency.
  // for MOTD_STATE
  static final motdBatch = [
    CookieDough(cookie: FibsCookie.CLIP_MOTD_END, regex: RegExp(r'^4$')),
    CookieDough(cookie: FibsCookie.FIBS_MOTD, regex: catchAllIntoMessageRegex), // catch all
  ];
}

enum FibsCookie {
  CLIP_NONE, // = 0
  CLIP_WELCOME, // = 1,
  CLIP_OWN_INFO, // = 2,
  CLIP_MOTD_BEGIN, // = 3,
  CLIP_MOTD_END, // = 4,
  CLIP_WHO_INFO, // = 5,
  CLIP_WHO_END, // = 6,
  CLIP_LOGIN, // = 7,
  CLIP_LOGOUT, // = 8,
  CLIP_MESSAGE, // = 9,
  CLIP_MESSAGE_DELIVERED, // = 10,
  CLIP_MESSAGE_SAVED, // = 11,
  CLIP_SAYS, // = 12,
  CLIP_SHOUTS, // = 13,
  CLIP_WHISPERS, // = 14,
  CLIP_KIBITZES, // = 15,
  CLIP_YOU_SAY, // = 16,
  CLIP_YOU_SHOUT, // = 17,
  CLIP_YOU_WHISPER, // = 18,
  CLIP_YOU_KIBITZ, // = 19,
  FIBS_PreLogin, // the ASCII "FIBS" art, etc.
  FIBS_LoginPrompt,
  FIBS_WARNINGAlreadyLoggedIn, // csells: already logged in warning
  FIBS_FailedLogin, // use this to detect a failed login (e.g. wrong password)
  FIBS_MOTD,
  FIBS_Goodbye,
  FIBS_PostGoodbye, // "send cookies", etc.
  FIBS_Unknown, // don't know the type, probably can ignore
  FIBS_Empty, // empty string
  FIBS_Junk, // a message we don't care about, but is not unknown
  FIBS_ClearScreen,
  FIBS_BAD_AcceptDouble, // DANGER, WILL ROBINSON!!! See notes in .c file about these two cookies!
  FIBS_Average,
  FIBS_DiceTest,
  FIBS_Stat,
  FIBS_Why,
  FIBS_NoInfo,
  FIBS_LastLogout,
  FIBS_RatingCalcStart,
  FIBS_RatingCalcInfo,
  FIBS_SettingsHeader,
  FIBS_PlayerListHeader,
  FIBS_AwayListHeader,
  FIBS_RatingExperience,
  FIBS_NotLoggedIn,
  FIBS_StillLoggedIn,
  FIBS_NoOneIsAway,
  FIBS_RatingsHeader,
  FIBS_IsPlayingWith,
  FIBS_Timeout,
  FIBS_UnknownCommand,
  FIBS_Username,
  FIBS_LastLogin,
  FIBS_YourLastLogin,
  FIBS_Registered,
  FIBS_ONEUSERNAME,
  FIBS_EnterUsername,
  FIBS_EnterPassword,
  FIBS_TypeInNo,
  FIBS_SavedScoreHeader,
  FIBS_NoSavedGames,
  FIBS_UsersHeardYou,
  FIBS_MessagesForYou,
  FIBS_IsAway,
  FIBS_OpponentLogsOut,
  FIBS_Waves,
  FIBS_WavesAgain,
  FIBS_YouGag,
  FIBS_YouUngag,
  FIBS_YouBlind,
  FIBS_YouUnblind,
  FIBS_WatchResign,
  FIBS_UseToggleReady,
  FIBS_WARNINGSavedMatch,
  FIBS_NoSavedMatch,
  FIBS_AlreadyPlaying,
  FIBS_DidntInvite,
  FIBS_WatchingHeader,
  FIBS_NotWatching,
  FIBS_NotWatchingPlaying,
  FIBS_NotPlaying,
  FIBS_PlayerNotPlaying,
  FIBS_NoUser,
  FIBS_CantInviteSelf,
  FIBS_CantWatch,
  FIBS_CantTalk,
  FIBS_CantBlindYourself,
  FIBS_CantGagYourself,
  FIBS_WontListen,
  FIBS_NoOne,
  FIBS_BadMove,
  FIBS_MustMove,
  FIBS_MustComeIn,
  FIBS_CantShout,
  FIBS_DontKnowUser,
  FIBS_MessageUsage,
  FIBS_Done,
  FIBS_SavedMatchesHeader,
  FIBS_NotYourTurnToRoll,
  FIBS_NotYourTurnToMove,
  FIBS_YourTurnToMove,
  FIBS_Ratings,
  FIBS_PlayerInfoStart,
  FIBS_EmailAddress,
  FIBS_NoEmail,
  FIBS_ListOfGames,
  FIBS_SavedMatch,
  FIBS_SavedMatchPlaying,
  FIBS_SavedMatchReady,
  FIBS_YouAreWatching,
  FIBS_YouStopWatching,
  FIBS_PlayerStartsWatching,
  FIBS_PlayerStopsWatching,
  FIBS_PlayerIsWatching,
  FIBS_ReportUnlimitedMatch,
  FIBS_ReportLimitedMatch,
  FIBS_RollOrDouble,
  FIBS_YouWinMatch,
  FIBS_PlayerWinsMatch,
  FIBS_YouReject,
  FIBS_YouResign,
  FIBS_ResumeMatchRequest,
  FIBS_ResumeMatchAck0,
  FIBS_ResumeMatchAck5,
  FIBS_NewMatchRequest,
  FIBS_UnlimitedInvite,
  FIBS_YouInvited,
  FIBS_NewMatchAck9,
  FIBS_NewMatchAck10,
  FIBS_NewMatchAck2,
  FIBS_YouTerminated,
  FIBS_OpponentLeftGame,
  FIBS_PlayerLeftGame,
  FIBS_PlayerRefusingGames,
  FIBS_TypeJoin,
  FIBS_ShowMovesStart,
  FIBS_ShowMovesWins,
  FIBS_ShowMovesRoll,
  FIBS_ShowMovesDoubles,
  FIBS_ShowMovesAccepts,
  FIBS_ShowMovesRejects,
  FIBS_ShowMovesOther,
  FIBS_Board,
  FIBS_YouRoll,
  FIBS_PlayerRolls,
  FIBS_PlayerMoves,
  FIBS_PlayerCantMove,
  FIBS_Doubles,
  FIBS_AcceptRejectDouble,
  FIBS_StartingNewGame,
  FIBS_PlayerAcceptsDouble,
  FIBS_YouAcceptDouble,
  FIBS_Turn,
  FIBS_FirstRoll,
  FIBS_DoublingCubeNow,
  FIBS_CantMove,
  FIBS_CantMoveFirstMove,
  FIBS_ResignRefused,
  FIBS_YouWinGame,
  FIBS_OnlyPossibleMove,
  FIBS_AcceptWins,
  FIBS_ResignWins,
  FIBS_ResignYouWin,
  FIBS_WatchGameWins,
  FIBS_ScoreUpdate,
  FIBS_MatchStart,
  FIBS_YouAcceptAndWin,
  FIBS_OnlyMove,
  FIBS_BearingOff,
  FIBS_PleaseMove,
  FIBS_MakesFirstMove,
  FIBS_YouDouble,
  FIBS_MatchLength,
  FIBS_PlayerWantsToResign,
  FIBS_PlayerWinsGame,
  FIBS_JoinNextGame,
  FIBS_ResumingUnlimitedMatch,
  FIBS_ResumingLimitedMatch,
  FIBS_PlayersStartingMatch,
  FIBS_PlayersStartingUnlimitedMatch,
  FIBS_MatchResult,
  FIBS_YouGiveUp,
  FIBS_PlayerIsWaitingForYou,
  FIBS_SettingsValue, // csells
  FIBS_SettingsChange, // csells
  FIBS_NotDoingAnything, // csells
}
