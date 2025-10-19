public enum ElementType {
    RECTANGLE,
    CIRCLE,
    LINE,
    SVG
}

public enum GroupEffectScope {
    INDIVIDUAL,
    COMBINED
}

public enum GridOverlayVariant {
    DARK,
    LIGHT
}

public enum IconBackgroundVariant {
    SYSTEM_DARK,
    SYSTEM_LIGHT,
    NONE
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
    public float corner_radius_top_left;
    public float corner_radius_top_right;
    public float corner_radius_bottom_right;
    public float corner_radius_bottom_left;
    public bool corner_radius_locked;
    public bool use_gradient;
    public Gdk.RGBA gradient_secondary;
    public double gradient_angle;
    public double line_angle;
    public float line_length;
    public double element_angle;
    public string svg_data;

    public IconElement (ElementType t) {
        type = t;
        x = 12.0f;
        y = 12.0f;
        width = 40.0f;
        height = 40.0f;
        stroke_width = 0.5f;
        corner_radius_top_left = 0.0f;
        corner_radius_top_right = 0.0f;
        corner_radius_bottom_right = 0.0f;
        corner_radius_bottom_left = 0.0f;
        corner_radius_locked = true;
        use_gradient = false;
        gradient_angle = 45.0;
        line_angle = 45.0;
        line_length = 40.0f;
        element_angle = 0.0;
        svg_data = "";
        Gdk.RGBA tmp = { 0 };
        tmp.parse ("#FFFFFF"); fill = tmp;
        tmp.parse ("#FFFFFF"); stroke = tmp;
        if (t == ElementType.LINE) {
            tmp.parse ("#000000"); gradient_secondary = tmp;
        } else {
            tmp.parse ("#888888"); gradient_secondary = tmp;
        }
    }
}

public class ElementGroup : GLib.Object {
    public string name;
    public GLib.ListStore elements;
    public string blend_mode;
    public bool use_sheen_layer;
    public bool use_shadow;
    public bool shadow_chromatic;
    public GroupEffectScope effect_scope;

    public ElementGroup (string group_name) {
        name = group_name;
        elements = new GLib.ListStore (typeof (IconElement));
        blend_mode = "normal";
        use_sheen_layer = false;
        use_shadow = false;
        shadow_chromatic = false;
        effect_scope = GroupEffectScope.INDIVIDUAL;
    }
}

public class IconModel : GLib.Object {
    public GLib.ListStore groups;
    public int selected_group_index = -1;
    public int selected_element_index = -1;
    public bool background_selected = false;
    public bool group_selected = false;
    public bool reorder_mode = false;

    public string name = "Icon Name";
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
    public bool show_grid_overlay = false;
    public GridOverlayVariant grid_overlay_variant = GridOverlayVariant.DARK;
    private IconBackgroundVariant _icon_background_variant = IconBackgroundVariant.NONE;
    public IconBackgroundVariant icon_background_variant {
        get {
            return _icon_background_variant;
        }
        set {
            if (_icon_background_variant == value) {
                return;
            }
            _icon_background_variant = value;
            apply_background_variant_colors ();
        }
    }

    public IconModel () {
        groups = new GLib.ListStore (typeof (ElementGroup));
        Gdk.RGBA tmp = { 0 };

        tmp.parse ("#888888"); view_background = tmp;
        apply_background_variant_colors ();
    }

    private void apply_background_variant_colors () {
        Gdk.RGBA bg_color = { 0 };
        Gdk.RGBA grad_color = { 0 };

        if (_icon_background_variant == IconBackgroundVariant.SYSTEM_LIGHT) {
            bg_color.parse ("#FAFAFA");
            grad_color.parse ("#F0F0F0");
            use_gradient = true;
        } else if (_icon_background_variant == IconBackgroundVariant.SYSTEM_DARK) {
            bg_color.parse ("#2d2d2d");
            grad_color.parse ("#000000");
            use_gradient = true;
        } else {
            bg_color.parse ("#6AC9FF");
            grad_color.parse ("#0077DD");
            use_gradient = true;
        }

        background = bg_color;
        gradient_secondary = grad_color;
    }
}