# notes

A tiny daily notes app. You run it, it opens your editor, you write,
you close. Done. Everything else is automatic.

No accounts, no cloud, no config. Your notes live in a folder on your
own machine, one file per day.

## Install

You need [Zig](https://ziglang.org/) 0.16.

```sh
zig build --prefix ~/.local
# binary lands in ~/.local/bin/notes
```

Or grab a prebuilt binary from the
[releases](https://github.com/ilyeshdz/notes/releases) page.

## Usage

```sh
notes            # open today's note in $EDITOR
notes add "text" # append a checkbox to today's inbox list
notes check      # verify every note matches the format
notes init       # turn ~/.notes into a git repo
notes help       # this
```

The first time you run it, `~/.notes` is created. Today's note lives at
`~/.notes/2026-08-05.md` and starts like this:

```md
# 2026-08-05

## inbox
```

`notes add "buy milk"` turns that into:

```md
# 2026-08-05

## inbox
- [ ] buy milk
```

Add your own `## whatever` sections freely — they're left alone.

## Git

If `~/.notes` is a git repository, every edit is committed for you, so
you get history and a backup without thinking about it. If it's not a
repo, nothing happens — `notes` just works.

```sh
notes init   # git init + sane local identity, once
```

## Release

```sh
git tag v1.0.0 && git push origin v1.0.0
```

The GitHub Actions pipeline builds binaries for Linux, macOS and
Windows (x86_64 and aarch64) and publishes them to a release.

## License

MIT
