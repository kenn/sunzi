Sunzi
=====

```
"The supreme art of war is to subdue the enemy without fighting." - Sunzi
```

Sunzi is the easiest server provisioning utility designed for mere mortals. If Chef or Puppet is driving you nuts, try Sunzi!

Sunzi assumes that modern Linux distributions have (mostly) sane defaults and great package managers.

Its design goals are:

* **It's just shell script.** No clunky Ruby DSL involved. Sunzi recipes are written in a plain shell script. Why? Because, most of the information about server configuration on the web is written in shell commands. Just copy-paste them, why should you translate it into a proprietary, inconvenient DSL? Also, shell script is the greatest common denominator on minimum Linux installs.
* **Focus on diff from default.** No big-bang overwriting. Append or replace the smallest possible piece of data in a config file. Loads of custom configurations make it difficult to understand what you are really doing.
* **Always use the root user.** Think twice before blindly assuming you need a regular user - it doesn't add any security benefit for server provisioning, it just adds extra verbosity for nothing. However, it doesn't mean that you shouldn't create regular users with Sunzi - feel free to write your own recipes.
* **Minimum dependencies.** No configuration server required. You don't even need a Ruby runtime on the remote server.

Quickstart
----------

Install:

    $ gem install sunzi

Go to your project directory, then:

    $ sunzi create

It generates a `sunzi` folder along with subdirectories and templates. Inside `sunzi`, there's `sunzi.yml`, which defines dynamic attributes to be used from recipes. Also there's the `remote` folder, which will be transferred to the remote server, that contains recipes and dynamic variables compiled from `sunzi.yml`.

Go into the `sunzi` directory, then run the `sunzi deploy`:

    $ cd sunzi
    $ sunzi deploy example.com

Now, what it actually does is:

1. SSH to `example.com` and login as `root`
1. Transfer the content of the `remote` directory to the remote server and extract in `$HOME/sunzi`
1. Run `install.sh` on the remote server

As you can see, what you need to do is edit `install.sh` and add some shell commands. That's it.

Directory structure
-------------------

Here's the directory structure that `sunzi create` automatically generates:

```
sunzi/
  sunzi.yml         ---- add custom attributes and remote recipes here
  remote/           ---- everything under this folder will be transferred to the remote server
    attributes/     ---- compiled attributes from sunzi.yml at deploy (do not edit directly)
      ssh_key
    recipes/        ---- put commonly used scripts here, referred from install.sh
      ssh_key.sh
    install.sh      ---- main scripts that gets run on the remote server
```

How do you pass dynamic values to a recipe?
-------------------------------------------

In the compile phase, attributes defined in `sunzi.yml` are split into multiple files, one per attribute. We use filesystem as a sort of key-value storage so that it's easy to use from shell scripts.

The convention for argument passing to a recipe is to use `$1`, `$2`, etc. and put a comment line for each argument.

For instance, given a recipe `greeting.sh`:

```bash
# Greeting
# $1: Name for goodbye
# $2: Name for hello

echo "Goodbye $1, Hello $2!"
```

With `attributes.yml`:

```yaml
goodbye: Chef
hello: Sunzi
```

Then, include the recipe in `install.sh`:

```bash
source recipes/greeting.sh $(cat attributes/goodbye) $(cat attributes/hello)
```

Now, you get the following result. Isn't it awesome?

```
Goodbye Chef, Hello Sunzi!
```

Remote Recipes
--------------

Recipes can be retrieved remotely via HTTP. Put a URL in the recipes section of `sunzi.yml`, and Sunzi will automatically load the content and put it into the `remote/recipes` folder in the compile phase.

For instance, if you have the following line in `sunzi.yml`,

```yaml
recipes:
  rvm: https://raw.github.com/kenn/sunzi-recipes/master/ruby/rvm.sh
```

`rvm.sh` will be available and you can refer to that recipe by `source recipes/rvm.sh`.

Cloud Support
-------------

You can setup a new VM / teardown an existing VM interactively. Use `sunzi setup` and `sunzi teardown` for that.

The following screenshot says it all.

![Sunzi for Linode](http://farm8.staticflickr.com/7210/6783789868_ab89010d5c.jpg)

Vagrant
-------

If you're using Sunzi with [Vagrant](http://vagrantup.com/), make sure that you have a root access via SSH.

An easy way is to edit `Vagrantfile`:

```ruby
Vagrant::Config.run do |config|
  config.vm.provision :shell do |shell|
    shell.path = "chpasswd.sh"
  end
end
```

with `chpasswd.sh`:

```bash
#!/bin/bash

sudo echo 'root:vagrant' | /usr/sbin/chpasswd
```

and now run `vagrant up`, it will change the root password to `vagrant`.

Also keep in mind that you need to specify the port number 2222.

    $ sunzi deploy localhost:2222
