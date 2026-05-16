require 'xcodeproj'

project_path = File.expand_path('../ios/Runner.xcodeproj', __dir__)
project = Xcodeproj::Project.open(project_path)

runner_target = project.targets.find { |target| target.name == 'Runner' }
abort('Runner target not found') unless runner_target

def ensure_group(parent, name, path = name)
  parent.children.find { |child| child.isa == 'PBXGroup' && child.path == path } ||
    parent.new_group(name, path)
end

def ensure_file(group, path)
  basename = File.basename(path)
  file = group.files.find { |entry| File.basename(entry.path.to_s) == basename } || group.new_file(basename)
  file.path = basename
  file
end

def ensure_framework(project, target, framework_name)
  frameworks_group = project.frameworks_group || project.main_group['Frameworks'] || project.main_group.new_group('Frameworks')
  file_ref = frameworks_group.files.find { |file| File.basename(file.path.to_s) == framework_name } ||
    frameworks_group.new_file("System/Library/Frameworks/#{framework_name}", :sdk_root)
  already_linked = target.frameworks_build_phase.files_references.any? { |file| File.basename(file.path.to_s) == framework_name }
  target.frameworks_build_phase.add_file_reference(file_ref, true) unless already_linked
end

runner_group = project.main_group['Runner']
shared_group = ensure_group(project.main_group, 'Shared')
widget_group = ensure_group(project.main_group, 'WorkoutLiveActivity')

shared_attributes = ensure_file(shared_group, 'WorkoutLiveActivityAttributes.swift')
plugin_file = ensure_file(runner_group, 'WorkoutLiveActivityPlugin.swift')
manager_file = ensure_file(runner_group, 'WorkoutLiveActivityManager.swift')
widget_bundle_file = ensure_file(widget_group, 'WorkoutLiveActivityBundle.swift')
widget_file = ensure_file(widget_group, 'WorkoutLiveActivityWidget.swift')
widget_info_plist = ensure_file(widget_group, 'Info.plist')

runner_target.add_file_references([plugin_file, manager_file, shared_attributes])
ensure_framework(project, runner_target, 'ActivityKit.framework')

extension_target = project.targets.find { |target| target.name == 'WorkoutLiveActivityExtension' }
unless extension_target
  extension_target = project.new_target(
    :app_extension,
    'WorkoutLiveActivityExtension',
    :ios,
    '16.1'
  )
end

extension_target.product_reference.name = 'WorkoutLiveActivityExtension.appex'
extension_target.product_reference.path = 'WorkoutLiveActivityExtension.appex'
extension_target.product_name = 'WorkoutLiveActivityExtension'

extension_target.add_file_references([shared_attributes, widget_bundle_file, widget_file])
ensure_framework(project, extension_target, 'ActivityKit.framework')
ensure_framework(project, extension_target, 'WidgetKit.framework')
ensure_framework(project, extension_target, 'SwiftUI.framework')

runner_bundle_id =
  runner_target.build_configurations
              .map { |config| config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] }
              .compact
              .find { |bundle_id| bundle_id && !bundle_id.empty? }
runner_marketing_version =
  runner_target.build_configurations
              .map { |config| config.build_settings['MARKETING_VERSION'] }
              .compact
              .find { |version| version && !version.empty? } || '1.0.0'
team_id =
  runner_target.build_configurations
              .map { |config| config.build_settings['DEVELOPMENT_TEAM'] }
              .compact
              .find { |team| team && !team.empty? }

extension_target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['DEVELOPMENT_TEAM'] = team_id if team_id
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['INFOPLIST_FILE'] = 'WorkoutLiveActivity/Info.plist'
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.1'
  config.build_settings['MARKETING_VERSION'] = runner_marketing_version
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = "#{runner_bundle_id}.WorkoutLiveActivity"
  config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
end

copy_phase = runner_target.copy_files_build_phases.find { |phase| phase.name == 'Embed App Extensions' }
unless copy_phase
  copy_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
  copy_phase.name = 'Embed App Extensions'
  copy_phase.dst_subfolder_spec = '13'
end

unless copy_phase.files_references.include?(extension_target.product_reference)
  build_file = copy_phase.add_file_reference(extension_target.product_reference, true)
  build_file.settings = { 'ATTRIBUTES' => %w[RemoveHeadersOnCopy CodeSignOnCopy] }
end

runner_target.build_phases.delete(copy_phase)
thin_binary_index = runner_target.build_phases.index { |phase| phase.display_name == 'Thin Binary' } || runner_target.build_phases.length
runner_target.build_phases.insert(thin_binary_index, copy_phase)

project.save
