# Yazi

Terminal file manager with custom sorting shortcuts, a sort indicator, and
Rose Pine Moon and Catppuccin Mocha themes. The preview starts hidden;
press `T` to show or hide it, and `F1` to open keyboard help.

Run `./install.sh` to install Yazi, then `./stow-dotfiles.sh` and opt in to
the `yazi` package. Plugins and flavors are included with their licenses,
so no separate plugin or theme download is needed.

The installer backs up existing config files and creates file symlinks under
`~/.config/yazi`. Its saved `yazi=y` decision also enables the post-merge
hook to stow new files after future merge pulls.

To unlink: `stow -D -d ~/dotfiles -t "$HOME" yazi`.
