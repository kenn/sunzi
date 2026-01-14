# Sunzi Modernization Plan

## Overview
Update Sunzi (server provisioning tool) from 2018-era dependencies to modern Ruby ecosystem.

## Changes

### 1. Confirm minimum Ruby versions
Verified minimum Ruby version for `net-ssh ~> 7` and `thor ~> 1.3` is 2.6.
Set `spec.required_ruby_version` accordingly.

### 2. Update gemspec dependencies
**File:** [sunzi.gemspec](sunzi.gemspec)

| Dependency | Current | New |
|------------|---------|-----|
| `thor` | unrestricted | `~> 1.3` |
| `net-ssh` | `< 5` | `~> 7.0` |
| `rainbow` | `~> 3.0` | (keep) |
| `hashugar` | unrestricted | (keep) |
| `minitest` | unrestricted | `~> 6.0` |

Also add:
- `spec.required_ruby_version = '>= 2.6'`

### 3. Keep YAML.load for compatibility (document trust boundary)
**File:** [README.md](README.md)

Leave `YAML.load(ERB.new(File.read('sunzi.yml')).result)` as-is for maximum compatibility.
Add a short README note that `sunzi.yml` must be fully trusted because ERB executes Ruby
and YAML.load can instantiate arbitrary objects.

### 4. Replace Travis CI with GitHub Actions
**Delete:** `.travis.yml`
**Create:** `.github/workflows/test.yml`

```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        ruby: ['3.1', '3.2', '3.3']
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: ${{ matrix.ruby }}
          bundler-cache: true
      - run: bundle exec rake test
```

### 5. Update README badge + requirements
**File:** [README.md](README.md)

- Replace Travis badge with GitHub Actions badge (ensure workflow name/branch match the badge URL).
- Add a short Requirements note for the minimum supported Ruby (from step 1).

### 6. Add .ruby-version
**Create:** `.ruby-version` with content `3.2`

### 7. Update template default Ruby version
**File:** [templates/create/sunzi.yml](templates/create/sunzi.yml)

Update `ruby_version: 2.5` to match the modern baseline (e.g., `3.2`).

### 8. Update CHANGELOG
**File:** [CHANGELOG.md](CHANGELOG.md)

Add a `3.0.0` entry with the breaking changes (Ruby requirement, dependency bumps, CI migration).

### 9. Bump version
**File:** [sunzi.gemspec:5](sunzi.gemspec#L5)

Update version from `2.1.0` to `3.0.0` (major bump due to Ruby version requirement change).
If a version constant exists (e.g., `lib/sunzi/version.rb`), update it too.

## File Summary
| Action | File |
|--------|------|
| Edit | `sunzi.gemspec` |
| Edit | `README.md` |
| Edit | `templates/create/sunzi.yml` |
| Edit | `CHANGELOG.md` |
| Delete | `.travis.yml` |
| Create | `.github/workflows/test.yml` |
| Create | `.ruby-version` |

## Verification
1. Run `bundle install` to update Gemfile.lock
2. Run `bundle exec rake test` to verify tests pass
3. Run `bundle exec sunzi version` and `bundle exec sunzi create test_project` to verify CLI works
