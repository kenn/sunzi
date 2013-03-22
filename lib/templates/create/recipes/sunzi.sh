# This file is used to define functions under the sunzi.* namespace.

# Set $sunzi_pkg to "aptitude" or "yum", or abort.
#
if which aptitude >/dev/null 2>&1; then
  export sunzi_pkg=aptitude
elif which yum >/dev/null 2>&1; then
  export sunzi_pkg=yum
fi

if [ "$sunzi_pkg" = '' ]; then
  echo 'sunzi only supports aptitude and yum!' >&2
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
  if [ "$sunzi_pkg" = 'aptitude' ]; then
    dpkg -s $@ >/dev/null 2>&1
  elif [ "$sunzi_pkg" = 'yum' ]; then
    rpm -qa | grep $@ >/dev/null
  fi
  return $?
}

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
