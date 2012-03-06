# This file is used to define functions under the sunzi:: namespace.

function sunzi::silencer() {
  echo "Running \"$@\""
  eval "$@ > /dev/null 2>&1"
}
