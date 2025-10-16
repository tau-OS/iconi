public enum ElementType {
    RECTANGLE,
    CIRCLE,
    LINE
}

public class IconElement : GLib.Object {
    public ElementType type;
    public float x;
    public float y;
    public float width;
    public float height;
    public Gdk.RGBA fill;
    public Gdk.RGBA stroke;
    public float stroke_width;
    public string blend_mode;
    public bool use_gradient;
    public Gdk.RGBA gradient_secondary;
    public double gradient_angle;
    public double line_angle;
    public float line_length;

    public IconElement (ElementType t) {
        type = t;
        x = 12.0f;
        y = 12.0f;
        width = 40.0f;
        height = 40.0f;
        stroke_width = 0.0f;
        blend_mode = "normal";
        use_gradient = false;
        gradient_angle = 45.0;
        line_angle = 45.0;
        line_length = 40.0f;
        Gdk.RGBA tmp = { 0 };
        tmp.parse ("#ffffff"); fill = tmp;
        tmp.parse ("#000000"); stroke = tmp;
        if (t == ElementType.LINE) {
            tmp.parse ("#888888"); gradient_secondary = tmp;
        } else {
            tmp.parse ("#888888"); gradient_secondary = tmp;
        }
    }
}

public class IconModel : GLib.Object {
    public GLib.ListStore elements;
    public int selected_index = -1;
    public bool background_selected = false;
    public bool reorder_mode = false;

    public string name = "icon-name";
    public Gdk.RGBA background = { 0 };
    public bool use_wallpaper = false;
    public bool use_gradient = false;
    public Gdk.RGBA gradient_secondary = { 0 };
    public double gradient_angle = 45.0;
    public Gdk.RGBA view_background = { 0 };
    public bool use_raised_effect = true;
    public bool use_frame_overlay = false;
    public bool show_dev_badge = false;
    public float zoom = 1.0f;

    public IconModel () {
        elements = new GLib.ListStore (typeof (IconElement));
        Gdk.RGBA tmp = { 0 };
        tmp.parse ("#0080FF"); background = tmp;
        tmp.parse ("#00C0FF"); gradient_secondary = tmp;
        tmp.parse ("#888888"); view_background = tmp;
    }
}