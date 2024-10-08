# Values defined here are accessible from within Vala.
# This can be useful for setting build-time constants, such as the version or app id.
# See the Config.vapi file for more information.

config = configuration_data()
config.set_quoted('APP_ID', meson.project_name())
config.set_quoted('APP_PATH', path_identifier)
config.set_quoted(
  'NAME_SUFFIX',
  get_option('development') ? ' (Development)' : '',
)
config.set_quoted('VERSION', meson.project_version())
config.set_quoted('GETTEXT_PACKAGE', meson.project_name())
config.set_quoted(
  'LOCALEDIR',
  join_paths(get_option('prefix'), get_option('localedir')),
)
config.set10('DEVELOPMENT', get_option('development'))

configure_file(
  output: 'config.h',
  configuration: config,
)

add_project_arguments(
  '-include', 'config.h',
  '-w',
  '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()),
  language: 'c',
)

sources = [
  gresources,
  'Config.vapi',
  'App.vala',
  'Window.vala',
  'Utils.vala',
]

dependencies = [
  dependency('gio-2.0'),
  dependency('gtk4'),
  dependency('glib-2.0'),
  dependency('gobject-2.0'),
  dependency('gee-0.8'),
  dependency('libhelium-1'),
  dependency('gmodule-2.0'),
  dependency('librsvg-2.0', version: '>= 2.52.0'),
  dependency('libxml-2.0'),
  meson.get_compiler('c').find_library('m', required: true),
]

executable(
  meson.project_name(),
  [blueprints_workaround, sources],
  dependencies: dependencies,
  vala_args: ['--pkg', 'libxml-2.0'],
  install: true,
)
