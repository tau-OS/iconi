public class IconMakerApplication : He.Application {
    private IconMakerWindow? window = null;

    public IconMakerApplication () {
        Object (application_id : "com.fyralabs.Iconi");
    }

    protected override void activate () {
        if (window == null) {
            window = new IconMakerWindow (this);
            setup_actions ();
        }
        window.present ();
    }

    private void setup_actions () {
        var export_action = new GLib.SimpleAction ("export", null);
        export_action.activate.connect (() => {
            if (window != null) {
                window.open_export_dialog ();
            }
        });
        add_action (export_action);

        var about_action = new GLib.SimpleAction ("about", null);
        about_action.activate.connect (() => {
            show_about_dialog ();
        });
        add_action (about_action);
    }

    private void show_about_dialog () {
        var about = new He.AboutWindow (
                                        window,
                                        "Iconi",
                                        "com.fyralabs.Iconi",
                                        "1.0.0",
                                        "com.fyralabs.Iconi",
                                        "https://github.com/tau-OS/iconi/issues/new",
                                        "https://github.com/tau-OS/iconi/issues",
                                        "https://github.com/tau-OS/iconi",
                                        { "Fyra Labs" },
                                        { "Fyra Labs" },
                                        2024,
                                        He.AboutWindow.Licenses.GPLV3,
                                        He.Colors.DARK
        );
        about.present ();
    }

    public static int main (string[] args) {
        var app = new IconMakerApplication ();
        return app.run (args);
    }
}