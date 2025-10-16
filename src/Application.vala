public class IconMakerApplication : He.Application {
    public IconMakerApplication () {
        Object (application_id: "com.fyralabs.Iconi");
    }

    protected override void activate () {
        var window = new IconMakerWindow (this);
        window.present ();
    }

    public static int main (string[] args) {
        var app = new IconMakerApplication ();
        return app.run (args);
    }
}