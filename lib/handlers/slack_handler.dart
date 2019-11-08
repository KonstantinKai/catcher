import 'package:catcher/handlers/report_handler.dart';
import 'package:catcher/model/report.dart';
import 'package:catcher/utils/catcher_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

class _SlackAttachmentField {
  final String title;
  final String value;
  final bool short;

  _SlackAttachmentField({
    @required this.title,
    this.value,
    this.short = false,
  });

  Map<String, dynamic> get asMap => {
        'title': title,
        if (value?.isNotEmpty ?? false) 'value': value,
        'short': short,
      };
}

class _SlackAttachment {
  final String fallback;
  final String pretext;
  final String color;
  final List<_SlackAttachmentField> fields;

  _SlackAttachment({
    @required this.fallback,
    this.pretext,
    this.color,
    this.fields = const [],
  });

  Map<String, dynamic> get asMap => {
        'fallback': fallback,
        if (pretext?.isNotEmpty ?? false) 'pretext': pretext,
        if (color?.isNotEmpty ?? false) 'color': color,
        if (fields.isNotEmpty)
          'fields': fields.map((field) => field.asMap).toList(),
      };
}

class SlackHandler extends ReportHandler {
  final Dio _dio = Dio();
  final Logger _logger = Logger("SlackHandler");

  final String webhookUrl;
  final String channel;
  final String username;
  final String iconEmoji;

  final bool printLogs;
  final bool enableDeviceParameters;
  final bool enableApplicationParameters;
  final bool enableStackTrace;
  final bool enableCustomParameters;
  final bool useAttachment;

  SlackHandler(
    this.webhookUrl,
    this.channel, {
    this.username = "Catcher",
    this.iconEmoji = ":bangbang:",
    this.printLogs = false,
    this.enableDeviceParameters = false,
    this.enableApplicationParameters = false,
    this.enableStackTrace = false,
    this.enableCustomParameters = false,
    this.useAttachment = false,
  }) {
    assert(webhookUrl != null, "Webhook can't be null");
    assert(channel != null, "Channel can't be null");
  }

  @override
  Future<bool> handle(Report report) async {
    if (!(await CatcherUtils.isInternetConnectionAvailable())) {
      _printLog("No internet connection available");
      return false;
    }

    final List<_SlackAttachmentField> attachmentFields = [];

    StringBuffer stringBuffer = new StringBuffer();
    stringBuffer.write("*Error:* ```${report.error}```\n");

    if (useAttachment)
      attachmentFields.add(_SlackAttachmentField(
        title: 'Error:',
        value: '```${report.error}```',
      ));

    if (enableStackTrace) {
      stringBuffer.write("*Stack trace:* ```${report.stackTrace}```\n");

      if (useAttachment)
        attachmentFields.add(_SlackAttachmentField(
          title: 'Stack trace:',
          value: '```${report.stackTrace}```',
        ));
    }
    if (enableDeviceParameters && report.deviceParameters.length > 0) {
      stringBuffer.write("*Device parameters:* ```");
      final paramsStringBuffer = StringBuffer();
      for (var entry in report.deviceParameters.entries) {
        stringBuffer.write("${entry.key}: ${entry.value}\n");
        paramsStringBuffer.write("${entry.key}: ${entry.value}\n");
      }
      stringBuffer.write("```\n");

      if (useAttachment)
        attachmentFields.add(_SlackAttachmentField(
          title: 'Device parameters:',
          value: '```$paramsStringBuffer```',
        ));
    }

    if (enableApplicationParameters &&
        report.applicationParameters.length > 0) {
      stringBuffer.write("*Application parameters:* ```");
      final paramsStringBuffer = StringBuffer();
      for (var entry in report.applicationParameters.entries) {
        stringBuffer.write("${entry.key}: ${entry.value}\n");
        paramsStringBuffer.write("${entry.key}: ${entry.value}\n");
      }
      stringBuffer.write("```\n");

      if (useAttachment)
        attachmentFields.add(_SlackAttachmentField(
          title: 'Application parameters:',
          value: '```$paramsStringBuffer```',
        ));
    }

    if (enableCustomParameters && report.customParameters.length > 0) {
      stringBuffer.write("*Custom parameters:* ```");
      final paramsStringBuffer = StringBuffer();
      for (var entry in report.customParameters.entries) {
        stringBuffer.write("${entry.key}: ${entry.value}\n");
        paramsStringBuffer.write("${entry.key}: ${entry.value}\n");
      }
      stringBuffer.write("```\n");

      if (useAttachment)
        attachmentFields.add(_SlackAttachmentField(
          title: 'Custom parameters:',
          value: '```$paramsStringBuffer```',
        ));
    }

    String message = stringBuffer.toString();

    var data = {
      if (!useAttachment)
        "text": message
      else
        "attachments": [
          _SlackAttachment(
            fallback: message,
            fields: attachmentFields,
            color: '#D00000',
          ).asMap
        ],
      "channel": channel,
      "username": username,
      "icon_emoji": iconEmoji
    };
    _printLog("Sending request to Slack server...");
    Response response = await _dio.post(webhookUrl, data: data);
    _printLog(
        "Server responded with code: ${response.statusCode} and message: ${response.statusMessage}");
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  _printLog(String log) {
    if (printLogs) {
      _logger.info(log);
    }
  }
}
