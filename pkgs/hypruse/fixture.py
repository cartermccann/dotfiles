"""Disposable, offline GTK test window. Writes only the named test-state file."""
import json
import os
import sys
from pathlib import Path

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import Gio, GLib, Gtk

name, state_file = sys.argv[1:]
app_id = "local.hypruse.Poc" + name
GLib.set_prgname(app_id)
GLib.set_application_name("Hypruse Test " + name)
state = {"name": name, "pid": os.getpid(), "clicks": 0, "text": "", "page": 0}


def save():
    Path(state_file).write_text(json.dumps(state))


def activate(app):
    win = Gtk.ApplicationWindow(application=app, title="Hypruse Test " + name)
    win.set_default_size(600, 400)
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
    box.set_border_width(32)
    win.add(box)
    box.pack_start(Gtk.Label(label="Disposable offline test " + name), False, False, 0)
    entry = Gtk.Entry()
    entry.get_accessible().set_name("Test input " + name)

    def changed(widget):
        state["text"] = widget.get_text()
        save()

    entry.connect("changed", changed)
    box.pack_start(entry, False, False, 0)
    button = Gtk.Button(label="Count click " + name)

    def clicked(_):
        state["clicks"] += 1
        button.set_label("Count click " + name + " (" + str(state["clicks"]) + ")")
        save()

    button.connect("clicked", clicked)
    box.pack_start(button, False, False, 0)
    notebook = Gtk.Notebook()
    for i in range(2):
        notebook.append_page(Gtk.Label(label="Offline page " + str(i + 1)), Gtk.Label(label="Page " + str(i + 1)))

    def switched(_, __, index):
        state["page"] = index
        save()

    notebook.connect("switch-page", switched)
    box.pack_start(notebook, True, True, 0)
    save()
    win.show_all()


app = Gtk.Application(application_id=app_id, flags=Gio.ApplicationFlags.NON_UNIQUE)
app.connect("activate", activate)
app.run([sys.argv[0]])
