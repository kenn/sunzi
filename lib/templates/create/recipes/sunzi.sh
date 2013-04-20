# This file is used to define functions under the sunzi.* namespace.

# Set $sunzi_pkg to "apt-get" or "yum", or abort.
#
if which apt-get >/dev/null 2>&1; then
  export sunzi_pkg=apt-get
elif which yum >/dev/null 2>&1; then
  export sunzi_pkg=yum
fi

if [ "$sunzi_pkg" = '' ]; then
  echo 'sunzi only supports apt-get or yum!' >&2
  exit 1
fi

# Mute STDOUT and STDERR
#
function sunzi.mute() {
  echo "Running \"$@\""
  `$@ >/dev/null 2>&1`
  return $?
}

# Installer
#
function sunzi.installed() {
  if [ "$sunzi_pkg" = 'apt-get' ]; then
    dpkg -s $@ >/dev/null 2>&1
  elif [ "$sunzi_pkg" = 'yum' ]; then
    rpm -qa | grep $@ >/dev/null
  fi
  return $?
}

# When there's "set -e" in install.sh, sunzi.install should be used with if statement,
# otherwise the script may exit unexpectedly when the package is already installed.
#
function sunzi.install() {
  for name in $@
  do
    if sunzi.installed "$name"; then
      echo "$name already installed"
      return 1
    else
      echo "No packages found matching $name. Installing..."
      sunzi.mute "$sunzi_pkg -y install $name"
      return 0
    fi
  done
}
