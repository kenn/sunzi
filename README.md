Sunzi
=====

```
"The supreme art of war is to subdue the enemy without fighting." - Sunzi
```

Sunzi is a server provisioning tool for minimalists. Simplicity is the one and only goal - if Chef or Puppet is driving you nuts, try Sunzi.

Sunzi assumes that Linux distributions have (mostly) sane defaults.

Its design goals are:

* A big-bang overwriting with loads of custom configurations makes it difficult to know **what you are actually doing** - instead, Sunzi let you keep track of as little diff from default as possible.
* No mysterious Ruby DSL involved. Sunzi recipes are written in a plain shell script. Why? Because, most of the information about server configuration you get on the web is written in a set of shell commands. Why should you translate it into a proprietary DSL, rather than just copy-paste?
* No configuration server. No dependency. You don't even need a Ruby runtime on the remote server.

Quickstart
----------

Install:

    $ gem install sunzi

Go to your project directory, then:

    $ sunzi create

It generates a `sunzi` folder, subdirectories and some templates for you. Inside `sunzi`, there's `here` folder, which will be kept in your local machine, that contains some scripts and definition files. Also there's `there` folder, which will be transferred to the remote server, that contains recipes and dynamic variables compiled from the definition files in the `here` folder.

Go into the `here` directory, then run the `deploy.sh`:

    $ cd sunzi/here
    $ bash deploy.sh root@example.com

Now, what it actually does is:

1. SSH to `example.com` and login as `root`
1. Transfer the content of the `there` directory to the remote server and extract in `$HOME/sunzi`
1. Run `install.sh` in the remote server

As you can see, what you need to do is edit `install.sh` and add some shell commands. That's it.

Tutorial
--------

Here's the directory structure that `sunzi create` automatically generates:

```
sunzi/
  here/               ---- kept in your local machine
    attributes.yml    ---- add custom variables here
    compile.rb        ---- compile the content of attributes.yml to there/attributes/*
    deploy.sh         ---- invoke this script
  there/              ---- transferred to the remote server
    attributes/       ---- compiled from attributes.yml at deploy
      env
      ssh_key
    recipes/          ---- put commonly used scripts here, referred from install.sh
      ssh_key.sh
    install.sh        ---- main scripts that gets run on the remote server
```

Vagrant
-------

If you're using Sunzi with [Vagrant](http://vagrantup.com/), make sure you allowed SSH access for root, then:

    $ vagrant up
    $ bash deploy.sh root@localhost -p 2222
