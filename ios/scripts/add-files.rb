#!/usr/bin/env ruby
# Adds Swift files to the Rosin Xcode project (target: Rosin).
# Usage: add-files.rb <relative-path-from-ios-dir> [<relative-path> ...]
# Each path is resolved relative to the `ios/` directory.
# The script finds (or creates) the matching PBXGroup based on folder
# structure, then adds a file reference, target membership, and
# sources-phase membership. Idempotent: running twice with the same
# path is a no-op.

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../Rosin.xcodeproj', __dir__)
IOS_ROOT = File.expand_path('..', __dir__)

def ensure_group(project, folder_path)
  # folder_path is relative to ios/ (e.g. "Rosin/Views/Novice")
  parts = folder_path.split('/')
  current = project.main_group
  parts.each do |part|
    existing = current.groups.find { |g| g.name == part || g.path == part }
    if existing
      current = existing
    else
      current = current.new_group(part, part)
    end
  end
  current
end

def add_file(project, target, rel_path)
  abs_path = File.join(IOS_ROOT, rel_path)
  unless File.exist?(abs_path)
    warn "skip: #{rel_path} (file does not exist)"
    return
  end

  # Already registered?
  already = project.files.find { |f|
    f.real_path.to_s == abs_path || f.path == rel_path || f.path == File.basename(rel_path)
  }
  if already
    in_build = target.source_build_phase.files_references.include?(already)
    unless in_build
      target.source_build_phase.add_file_reference(already)
      puts "added to sources: #{rel_path}"
    else
      puts "skip: #{rel_path} (already registered)"
    end
    return
  end

  folder = File.dirname(rel_path)
  group = ensure_group(project, folder)
  ref = group.new_reference(File.basename(rel_path))
  target.source_build_phase.add_file_reference(ref)
  puts "added: #{rel_path}"
end

project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.find { |t| t.name == 'Rosin' } or abort 'target Rosin not found'

ARGV.each { |rel| add_file(project, target, rel) }

project.save
puts 'project.pbxproj saved'
