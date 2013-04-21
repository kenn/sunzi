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

# Runs recipes while providing a simple solution to ensure idempotence.
# Simply pass the name of the recipe without the .sh extension as the arg.
function sunzi.run_recipe() {
  completed_recipes_dir=/etc/sunzi/completed_recipes
  if [[ ! -d $completed_recipes_dir ]]; then
    mkdir -p $completed_recipes_dir
  fi
  tracker=$completed_recipes_dir/$1
  if [[ -f $tracker ]]; then
    echo ""
    echo "---------------------------------------------------------------------------------"
    echo " Skipping $1"
    echo "---------------------------------------------------------------------------------"
    echo ""
  else
    echo ""
    echo "---------------------------------------------------------------------------------"
    echo " Running $1"
    echo "---------------------------------------------------------------------------------"
    echo ""
    source $HOME/sunzi/recipes/$1.sh
    touch $tracker
  fi
}

