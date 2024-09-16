[GtkTemplate (ui = "/com/fyralabs/Iconi/mainwindow.ui")]
public class Iconi.MainWindow : He.ApplicationWindow {

    [GtkChild]
    private unowned He.Button file_button;
    [GtkChild]
    private unowned He.Button export_button;
    [GtkChild]
    private unowned Gtk.Picture icon_preview;
    [GtkChild]
    private unowned Gtk.Label file_label;
    [GtkChild]
    private ColorPickerButton color_button;
    [GtkChild]
    private unowned He.Switch frame_switch;
    [GtkChild]
    private unowned He.Switch dev_switch;

    private string? selected_file_path = null;
    private string? temp_preview_path = null;

    private const GLib.ActionEntry WINDOW_ENTRIES[] = {
        { "about", action_about },
    };

    public MainWindow (He.Application application) {
        Object (
                application: application,
                icon_name: Config.APP_ID,
                title: _("Iconi")
        );
    }

    construct {
        add_action_entries (WINDOW_ENTRIES, this);

        file_button.clicked.connect (on_file_button_clicked);

        // Initialize ColorPickerButton
        color_button.current_color = { 0, (float) 0.52, 1, 1 };
        color_button.has_label = true;
        color_button.color_changed.connect (update_preview);

        export_button.clicked.connect (on_export_clicked);

        // Connect switches to update_preview
        frame_switch.iswitch.notify["active"].connect (update_preview);
        dev_switch.iswitch.notify["active"].connect (update_preview);
    }

    private void on_file_button_clicked () {
        var file_chooser = new Gtk.FileChooserDialog ("Choose SVG Icon", this,
                                                      Gtk.FileChooserAction.OPEN,
                                                      "_Cancel", Gtk.ResponseType.CANCEL,
                                                      "_Open", Gtk.ResponseType.ACCEPT);
        var filter = new Gtk.FileFilter ();
        filter.add_mime_type ("image/svg+xml");
        filter.set_filter_name ("SVG Files");
        file_chooser.add_filter (filter);

        file_chooser.response.connect ((response) => {
            if (response == Gtk.ResponseType.ACCEPT) {
                selected_file_path = file_chooser.get_file ().get_path ();
                file_label.set_label ("app.svg");
                file_button.sensitive = false;
                update_preview ();
            }
            file_chooser.destroy ();
        });

        file_chooser.present ();
    }

    private void update_preview () {
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
                                    color_button.current_color,
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
            var error_dialog = new Gtk.MessageDialog (this, Gtk.DialogFlags.MODAL,
                                                      Gtk.MessageType.ERROR,
                                                      Gtk.ButtonsType.OK,
                                                      "Please select an input SVG file first.");
            error_dialog.response.connect ((response_id) => {
                error_dialog.destroy ();
            });
            error_dialog.show ();
            return;
        }

        var save_dialog = new Gtk.FileChooserDialog ("Save SVG", this,
                                                     Gtk.FileChooserAction.SAVE,
                                                     "_Cancel", Gtk.ResponseType.CANCEL,
                                                     "_Save", Gtk.ResponseType.ACCEPT);

        var svg_filter = new Gtk.FileFilter ();
        svg_filter.add_mime_type ("image/svg+xml");
        svg_filter.set_filter_name ("SVG Files");
        save_dialog.add_filter (svg_filter);

        save_dialog.set_current_name ("app.svg");

        save_dialog.response.connect ((response) => {
            if (response == Gtk.ResponseType.ACCEPT) {
                string output_path = save_dialog.get_file ().get_path ();
                Utils.create_svg_with_icon (
                                            selected_file_path,
                                            color_button.current_color,
                                            frame_switch.iswitch.active,
                                            dev_switch.iswitch.active,
                                            output_path
                );
                clean_up ();
            }
            save_dialog.destroy ();
        });

        save_dialog.present ();
    }

    private void clean_up () {
        if (temp_preview_path != null) {
            FileUtils.unlink (temp_preview_path);
            temp_preview_path = null;
        }
        selected_file_path = null;
        file_label.set_label (_("Preview"));
        file_button.sensitive = true;
        color_button.current_color = { 0, (float) 0.52, 1, 1 };
        icon_preview.set_paintable (null);
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
