import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:majora/emotes.dart';

class MessageList extends StatelessWidget {
  final ScrollController _controller = ScrollController();
  final List<Message> _messages;

  MessageList(this._messages);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      reverse: true,
      controller: _controller,
      itemCount: _messages.length,
      itemBuilder: (BuildContext ctx, int index) {
        var msg = _messages[index];

        var output = <InlineSpan>[];

        msg.data.forEach((val) {
          // if type text, render text text span
          // if type emote, render img span
          // output.add(x);
          var x = TextSpan(
              text: val.toString(), style: TextStyle(color: Colors.grey[400]));
          output.add(x);
        });
        var nick = TextSpan(
            text: "\n" + msg.readTimestamp() + " " + msg.nick,
            style: TextStyle(color: Colors.grey[600]));
        output.add(nick);
        // var lt = ListTile(
        //   subtitle: Text(msg.readTimestamp() + " " + msg.nick,
        //       style: TextStyle(
        //         color: Colors.grey[600],
        //       )),
        // );
        return Card(
          color: Colors.grey[900],
          child: Text.rich(TextSpan(
              children:
                  output)), //_MessageListItem(_messages[index]), // WidgetSpan()
        );
      },
    );
  }
}

// can be deleted, i like the styling of
// the listtile tho
class _MessageListItem extends ListTile {
  _MessageListItem(Message msg)
      : super(
            dense: true,
            title: Text(msg.data.toString(),
                style: TextStyle(
                  color: Colors.grey[400],
                )),
            subtitle: Text(msg.readTimestamp() + " " + msg.nick,
                style: TextStyle(
                  color: Colors.grey[600],
                )),
            onTap: () {});
}

class Message {
  String type;
  String nick;
  int timestamp;
  List<MessageSegment> data;

  Message({this.type, this.nick, this.timestamp, this.data});

  String readTimestamp() {
    if (this.timestamp != 0) {
      DateTime d =
          new DateTime.fromMillisecondsSinceEpoch(this.timestamp, isUtc: true);
      return d.hour.toString() + ":" + d.minute.toString();
    }
    return "";
  }

  factory Message.fromJson(String type, Map parsedJson) {
    // ignore escaped backticks
    int _findNextTick(String str) {
      int base = 0;
      while (str.length > 0) {
        var index = str.indexOf('`');
        if (index == -1) {
          return -1;
        } else if (index - 1 >= 0 && str[(index - 1)] == '\\') {
          base += index + 1;
          str = str.substring(index + 1);
        } else {
          return index + base;
        }
      }
      return -1;
    }

    List<MessageSegment> _tokenizeCode(String str) {
      print('parsing code');
      print(str);
      List<MessageSegment> returnList = new List<MessageSegment>();
      int indexOne = _findNextTick(str);
      if (indexOne != -1) {
        String beforeFirstTick = str.substring(0, indexOne);
        String afterFirstTick = str.substring(indexOne + 1);
        int indexTwo = _findNextTick(afterFirstTick);
        if (indexTwo != -1) {
          String betweenTicks = afterFirstTick.substring(0, indexTwo);
          String afterSecondTick = afterFirstTick.substring(indexTwo + 1);
          if (beforeFirstTick.length > 0) {
            new MessageSegment('text', beforeFirstTick);
          }
          new MessageSegment('text', betweenTicks, modifier: 'code');
          print(betweenTicks);
          if (afterSecondTick.length > 0) {
            returnList.addAll(_tokenizeCode(afterSecondTick));
          }
        }
      } else {
        returnList.add(new MessageSegment('text', str));
      }
      return returnList;
    }

    MessageSegment _tokenizeGreentext(String str) {
      RegExp greenReg = new RegExp(r'^\s*>.*$');
      if (greenReg.hasMatch(str)) {
        return new MessageSegment('text', str, modifier: 'green');
      }
      return new MessageSegment('text', str);
    }

    MessageSegment _tokenizeSelf(String str) {
      if (str.substring(0, 3) == '/me') {
        return new MessageSegment('self', str.substring(3));
      }
      return new MessageSegment('regular', str);
    }

    List<MessageSegment> _tokenizeSpoiler(String str) {
      List<MessageSegment> returnList = new List<MessageSegment>();
      var indexOne = str.indexOf('||');
      if (indexOne != -1) {
        var afterTag = str.substring(indexOne + 2);
        var indexTwo = afterTag.indexOf('||');
        if (indexTwo != -1) {
          var betweenTags = afterTag.substring(0, indexTwo);
          if (new RegExp(r'^\s*$').hasMatch(betweenTags)) {
            returnList.add(new MessageSegment(
                'text', str.substring(0, indexOne) + '||||'));
          } else {
            if (str.substring(0, indexOne).length > 0) {
              returnList
                  .add(new MessageSegment('text', str.substring(0, indexOne)));
            }
            returnList.add(new MessageSegment('spoiler', betweenTags));
            if (afterTag.substring(indexTwo + 2).length > 0) {
              returnList
                  .addAll(_tokenizeSpoiler(afterTag.substring(indexTwo + 2)));
            }
          }
        }
      } else {
        returnList.add(new MessageSegment('text', str));
      }
      return returnList;
    }

    List<MessageSegment> _tokenizeEmotes(String data) {
      List<MessageSegment> returnList = new List<MessageSegment>();
      String tmpBuffer = "";

      for (String segment in data.split(" ")) {
        List<String> colonSplit = segment.split(":");
        if (colonSplit.length == 1 && kEmotes.containsKey(segment)) {
          returnList.add(new MessageSegment("text", tmpBuffer + " "));
          tmpBuffer = "";
          returnList.add(new MessageSegment("emote", segment));
        } else if (colonSplit.length == 2 &&
            kEmotes.containsKey(colonSplit[0]) &&
            kEmoteModifiers.contains(colonSplit[1])) {
          returnList.add(new MessageSegment("text", tmpBuffer + " "));
          tmpBuffer = "";
          returnList.add(new MessageSegment("emote", colonSplit[0],
              modifier: colonSplit[1]));
        } else {
          tmpBuffer += " " + segment;
        }
      }

      if (tmpBuffer != "") {
        returnList.add(new MessageSegment("text", tmpBuffer + " "));
      }

      return returnList;
    }

    List<MessageSegment> _tokenizeLinks(String str) {
      List<MessageSegment> returnList = new List<MessageSegment>();
      RegExp reg = new RegExp(
          r'(http(s)?:\/\/.)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,20}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*)');
      Iterable<RegExpMatch> matches = reg.allMatches(str);
      List<String> withoutUrls = str.split(reg);
      for (var i = 0; i < withoutUrls.length; i++) {
        returnList.add(new MessageSegment('text', withoutUrls[i]));
        if (matches.length > i) {
          returnList
              .add(new MessageSegment('url', matches.elementAt(i).group(0)));
        }
      }
    }

    List<MessageSegment> _tokenizeMessage(String message) {
      // get /me
      MessageSegment base = _tokenizeSelf(message);
      // get spoiler blocks
      base.subSegemnts = _tokenizeSpoiler(base.data);
      base.data = '';
      List<MessageSegment> newSubSegs = new List<MessageSegment>();
      // get code blockss
      for (MessageSegment segment in base.subSegemnts) {
        if (segment.type == 'spoiler') {
          segment.subSegemnts = _tokenizeCode(segment.data);
          segment.data = '';
          newSubSegs.add(segment);
        } else {
          newSubSegs.addAll(_tokenizeCode(segment.data));
        }
      }
      base.subSegemnts = newSubSegs;
      // get URLs
      List<MessageSegment> returnList = new List<MessageSegment>();
      returnList.add(base);

      return returnList;
    }

    // recursively apply tokenizer
    MessageSegment _applyTokenizerToText(
        Function tokenizerFunction(String str), MessageSegment base) {
      List<MessageSegment> newList = new List<MessageSegment>();
      if (base.subSegemnts != null) {
        for (MessageSegment child in base.subSegemnts) {
          if (child.type == 'text') {
            newList.addAll(tokenizerFunction(child.data));
          } else {
            _applyTokenizerToText(tokenizerFunction, child);
            newList.add(child);
          }
        }
      }
      base.subSegemnts = newList;
    }

    print(parsedJson['data']);
    List<MessageSegment> message = _tokenizeMessage(parsedJson['data']);
    return Message(
        type: type,
        nick: parsedJson['nick'],
        timestamp: parsedJson['timestamp'],
        data: message);
  }
}

class MessageSegment {
  String type;
  String data;
  String modifier;
  List<MessageSegment> subSegemnts;

  @override
  String toString() {
    return toStringIndent(1);
  }

  String toStringIndent(int depth) {
    String segs = '';
    if (subSegemnts != null) {
      for (MessageSegment segment in subSegemnts) {
        segs += "\n" + '  ' * depth + segment.toStringIndent(depth + 1) + '\n';
      }
    }
    String mod = (modifier != null) ? ', mod: ' + modifier : '';
    return '{type: ' +
        type +
        mod +
        ', data: ' +
        data +
        ', children: [' +
        segs +
        ']}';
  }

  String getData() {
    return data;
  }

  MessageSegment(this.type, this.data, {this.modifier, this.subSegemnts});
}
