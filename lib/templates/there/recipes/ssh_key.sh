# SSH key
# $1: SSH key filename

if [ -f ~/.ssh/authorized_keys ]; then
  echo 'authorized_keys already created'
else
  if [ -f "$1" ]; then
    mkdir -p ~/.ssh
    cat $1 > ~/.ssh/authorized_keys
    rm $1
    chmod 700 ~/.ssh
    chmod 600 ~/.ssh/authorized_keys
  else
    echo 'The public key file ($1) not found! Copy it from $HOME/.ssh to the "there" directory.'
    echo 'If the file name found in .ssh is different from $1, edit here/attributes.yml as appropriate.'
  fi
fi
