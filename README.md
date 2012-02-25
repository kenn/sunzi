Sunzi
=====

```
"The supreme art of war is to subdue the enemy without fighting." - Sunzi
```

Sunzi is a server provisioning tool for minimalists. Simplicity is the one and only goal - if Chef or Puppet is driving you nuts, try Sunzi.

Sunzi assumes that Linux distributions have (mostly) sane defaults.

Its design goals are:

* **Single shell script.** A big-bang overwriting with loads of custom configurations makes it difficult to know **what you are actually doing** - instead, Sunzi let you keep track of as little diff from default as possible.
* **No mysterious Ruby DSL involved.** Sunzi recipes are written in a plain shell script. Why? Because, most of the information about server configuration you get on the web is written in a set of shell commands. Why should you translate it into a proprietary DSL, rather than just copy-paste?
* **Minimum dependencies.** No configuration server required. You don't even need a Ruby runtime on the remote server.
* **Always use the root user.** Think twice before blindly assuming you need a regular user - it doesn't add any security benefit for server provisioning, it just adds extra verbosity for nothing. However, it doesn't mean that you shouldn't create regular users with Sunzi - feel free to write your own recipes.

Quickstart
----------

Install:

    $ gem install sunzi

Go to your project directory, then:

    $ sunzi create

It generates a `sunzi` folder along with subdirectories and templates. Inside `sunzi`, there's `attributes.yml`, which defines dynamic attributes to be used from recipes. Also there's the `remote` folder, which will be transferred to the remote server, that contains recipes and dynamic variables compiled from `attributes.yml`.

Go into the `sunzi` directory, then run the `sunzi deploy`:

    $ cd sunzi
    $ sunzi deploy root@example.com

Now, what it actually does is:

1. SSH to `example.com` and login as `root`
1. Transfer the content of the `remote` directory to the remote server and extract in `$HOME/sunzi`
1. Run `install.sh` in the remote server

As you can see, what you need to do is edit `install.sh` and add some shell commands. That's it.

Directory structure
-------------------

Here's the directory structure that `sunzi create` automatically generates:

```
sunzi/
  attributes.yml    ---- add custom attributes here
  recipes.yml       ---- add remote recipes here
  remote/           ---- everything under this folder will be transferred to the remote server
    attributes/     ---- compiled attributes from attributes.yml at deploy (do not edit directly)
      env
      ssh_key
    recipes/        ---- put commonly used scripts here, referred from install.sh
      ssh_key.sh
    install.sh      ---- main scripts that gets run on the remote server
```

Remote Recipes
--------------

Recipes can be retrieved remotely via HTTP. Put the URL in `recipes.yml`, and Sunzi automatically loads the content and put it into the `remote/recipes` folder.

For instance, if you have the following line in `recipes.yml`,

```
rvm: https://raw.github.com/kenn/sunzi-recipes/master/ruby/rvm.sh
```

`rvm.sh` will be available and you can refer to that recipe by `source recipes/rvm.sh`.

Vagrant
-------

If you're using Sunzi with [Vagrant](http://vagrantup.com/), you need to specify the port number 2222.

    $ vagrant up
    $ sunzi deploy root@localhost 2222
