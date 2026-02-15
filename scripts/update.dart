import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final samples = File('./scripts/assets/samples.json');

  if (!samples.existsSync()) {
    stderr.writeln('Error: scripts/assets/samples.json not found.');
    stderr.writeln('Run: flutter create --list-samples=scripts/assets/samples.json');
    exit(1);
  }

  final str = await samples.readAsString();
  final items = (jsonDecode(str) as List).cast<Map<String, dynamic>>();

  final template = File('./idx-template.json');
  const encoder = JsonEncoder.withIndent(' ');
  final json = encoder.convert(createTemplate(items));
  await template.writeAsString('$json\n');

  stdout.writeln('✅ idx-template.json updated with ${items.length} samples.');
}

Map<String, Object?> createTemplate(List<Map<String, dynamic>> samples) {
  return {
    "name": "Flutter",
    "description": "Flutter create template",
    "categories": ["Mobile"],
    "icon":
        "https://www.gstatic.com/images/branding/productlogos/flutter/v6/192px.svg",
    "publisher": "Rody Davis",
    "host": {"virtualization": true},
    "params": [
      {
        "id": "template",
        "name": "Template",
        "type": "enum",
        "default": "app",
        "options": {
          "app": "App",
          "module": "Module",
          "package": "Package",
          "plugin": "Plugin",
          "plugin_ffi": "Plugin (FFI)",
          "skeleton": "Skeleton",
        },
      },
      {
        "id": "sample",
        "name": "Sample",
        "type": "enum",
        "default": "none",
        "options": {
          "none": "None",
          for (final item in samples) ...{
            if (item
                case {
                  "id": String id,
                  "element": String name,
                }) ...{
              id: name,
            },
          },
        },
      },
      {
        "id": "blank",
        "name": "Empty",
        "type": "boolean",
        "default": "false",
      },
      {
        "id": "platforms",
        "name": "Platforms",
        "type": "text",
        "default": "web",
      },
      {
        "id": "org",
        "name": "Organization",
        "type": "text",
        "default": "com.example",
      },
      {
        "id": "project-name",
        "name": "Project Name",
        "type": "text",
        "default": "my_app",
      },
    ],
  };
}
