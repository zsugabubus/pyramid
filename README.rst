*******
pyramid
*******

Pyramid is a ancient building (tool). It’s like make(1) but shell
scriptable–call it “shake” if you want.

Why not...
##########

Make?
=====

Because `make` soon becomes cumbersome if you want to express something more
dynamically changing or something flexible/hackable. I think about init
scripts, package managers, system daemons, system timers… yes, I would like a
Linux from scratch. At first I tried hacking Makefiles, but I soon realized
that it has some serious, blocking limitations [#]_. Just look at FreeBSD’s
fcked Makefiles: `XYZ_DEPENDS = ...`. Yes, this is exactly how you should do
it.

.. [#] For example a target recipe cannot be run from a different directory. So if you can use `.ONESHELL` you have to `cd ...` before every recipe; if not, you are super unlucky because then you will have to do it before every line.

`... &; wait`?
==============

You can only wait for processes started by the current shell.

Usage
#####

.. code-block:: sh
    # Import functions.
    . /usr/lib/pyramid

    pyramid_uid() {
    	stat -c%D:%i -- "$1"
    }

    pyramid_recipe() {
    	"$1" &
    }

    pyramid_init "$0"
    pyramid_spawn /path/to/script
    for i in $(seq 1 10); do
      pyramid_depends "/path/to/dep$i"
    done
