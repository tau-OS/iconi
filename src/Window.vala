[GtkTemplate (ui = "/com/fyralabs/Iconi/mainwindow.ui")]
public class Iconi.MainWindow : He.ApplicationWindow {
    [GtkChild]
    private unowned He.Button export_button;
    [GtkChild]
    private unowned Gtk.Picture icon_preview;
    [GtkChild]
    private unowned Gtk.Label file_label;
    [GtkChild]
    private unowned He.Switch frame_switch;
    [GtkChild]
    private unowned He.Switch dev_switch;
    [GtkChild]
    private unowned He.Button generate_template_button;

    private string? selected_file_path = null;
    private string? temp_preview_path = null;
    private string template_path;
    private FileMonitor? file_monitor;
    private uint update_timeout_id = 0;

    private const GLib.ActionEntry WINDOW_ENTRIES[] = {
        { "about", action_about },
    };

    public MainWindow (He.Application application) {
        Object (
                application : application,
                icon_name: Config.APP_ID,
                title: _("Iconi")
        );
    }

    construct {
        add_action_entries (WINDOW_ENTRIES, this);

        export_button.clicked.connect (on_export_clicked);

        // Connect switches to update_preview
        frame_switch.iswitch.notify["active"].connect (() => {
            print ("Frame switch toggled: %s\n", frame_switch.iswitch.active.to_string ());
            if (selected_file_path != null) {
                update_preview (false);
            }
        });
        dev_switch.iswitch.notify["active"].connect (() => {
            print ("Dev switch toggled: %s\n", dev_switch.iswitch.active.to_string ());
            if (selected_file_path != null) {
                update_preview (false);
            }
        });

        setup_file_monitoring ();

        // Connect generate_template_button
        generate_template_button.clicked.connect (on_generate_template_clicked);

        // Set the template path
        template_path = Path.build_filename (Environment.get_home_dir (), "iconi_template.svg");

        // Initially disable all widgets except generate_template_button
        set_widgets_sensitive (false);
        generate_template_button.sensitive = true;

        Timeout.add (1000, () => {
            update_preview (true);
            return true;
        });
    }

    private void setup_file_monitoring () {
        if (selected_file_path != null) {
            try {
                var file = File.new_for_path (selected_file_path);
                file_monitor = file.monitor (FileMonitorFlags.NONE, null);
                file_monitor.changed.connect ((src, dest, event) => {
                    if (event == FileMonitorEvent.CHANGED || event == FileMonitorEvent.CREATED) {
                        // Use a short timeout to avoid multiple rapid updates
                        if (update_timeout_id != 0) {
                            Source.remove (update_timeout_id);
                        }
                        update_timeout_id = Timeout.add (100, () => {
                            update_preview (true);
                            update_timeout_id = 0;
                            return false;
                        });
                    }
                });
            } catch (Error e) {
                warning ("Error setting up file monitor: %s", e.message);
            }
        }
    }

    private void on_generate_template_clicked () {
        if (Utils.generate_template_svg (template_path)) {
            selected_file_path = template_path;
            setup_file_monitoring ();
            update_preview (true);
            set_widgets_sensitive (true);
            file_label.set_label (_("Template"));

            var info_dialog = new He.Dialog (
                                             true,
                                             this,
                                             _("Template Generated"),
                                             "",
                                             _("Template generated successfully at %s").printf (template_path),
                                             "dialog-information",
                                             null,
                                             null
            );
            info_dialog.present ();
        } else {
            var error_dialog = new He.Dialog (
                                              true,
                                              this,
                                              _("Error"),
                                              "",
                                              _("Failed to generate template"),
                                              "dialog-error",
                                              null,
                                              null
            );
            error_dialog.present ();
        }
    }

    private void set_widgets_sensitive (bool sensitive) {
        export_button.sensitive = sensitive;
        frame_switch.sensitive = sensitive;
        dev_switch.sensitive = sensitive;
    }

    private void update_preview (bool reload_file) {
        if (selected_file_path == null) {
            icon_preview.set_paintable (null);
            return;
        }

        if (temp_preview_path != null) {
            FileUtils.unlink (temp_preview_path);
        }

        temp_preview_path = Path.build_filename (Environment.get_tmp_dir (), "iconi_preview_XXXXXX.svg");
        Utils.create_svg_with_icon (
                                    selected_file_path,
                                    frame_switch.iswitch.active,
                                    dev_switch.iswitch.active,
                                    temp_preview_path
        );

        try {
            var file = File.new_for_path (temp_preview_path);
            var stream = file.read ();
            var pixbuf = new Gdk.Pixbuf.from_stream_at_scale (stream, 128, 128, true);
            var texture = Gdk.Texture.for_pixbuf (pixbuf);
            icon_preview.set_paintable (texture);
        } catch (Error e) {
            warning ("Error loading preview: %s", e.message);
            icon_preview.set_paintable (null);
        }
    }

    private void on_export_clicked () {
        if (selected_file_path == null) {
            var error_dialog = new He.Dialog (
                                              true,
                                              this,
                                              _("Error"),
                                              "",
                                              _("Please generate a template first."),
                                              "dialog-error",
                                              null,
                                              null
            );
            error_dialog.present ();
            return;
        }

        var save_dialog = new Gtk.FileChooserNative (_("Save SVG"), this,
                                                     Gtk.FileChooserAction.SAVE,
                                                     _("Save"), _("Cancel"));

        var svg_filter = new Gtk.FileFilter ();
        svg_filter.add_mime_type ("image/svg+xml");
        svg_filter.set_filter_name (_("SVG Files"));
        save_dialog.add_filter (svg_filter);

        save_dialog.set_current_name ("app.svg");

        save_dialog.response.connect ((response) => {
            if (response == Gtk.ResponseType.ACCEPT) {
                var file = save_dialog.get_file ();
                string output_path = file.get_path ();
                Utils.create_svg_with_icon (
                                            selected_file_path,
                                            frame_switch.iswitch.active,
                                            dev_switch.iswitch.active,
                                            output_path
                );
                clean_up ();
            }
        });

        save_dialog.show ();
    }

    private void clean_up () {
        if (temp_preview_path != null) {
            FileUtils.unlink (temp_preview_path);
            temp_preview_path = null;
        }
        selected_file_path = null;
        file_label.set_label (_("Template"));
        icon_preview.set_paintable (null);
        set_widgets_sensitive (false);
        generate_template_button.sensitive = true;
    }

    public override void dispose () {
        clean_up ();
        base.dispose ();
    }

    private void action_about () {
        new He.AboutWindow (
                            this,
                            _("Iconi") + Config.NAME_SUFFIX,
                            Config.APP_ID,
                            Config.VERSION,
                            Config.APP_ID,
                            null,
                            "https://github.com/tau-OS/iconi/issues",
                            "https://github.com/tau-OS/iconi",
                            null,
                            { "Fyra Labs" },
                            2024,
                            He.AboutWindow.Licenses.GPLV3,
                            He.Colors.PINK
        ).present ();
    }
}
