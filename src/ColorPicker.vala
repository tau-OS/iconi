public class Iconi.ColorPickerButton : He.Bin {
    private Gtk.DrawingArea color_preview = new Gtk.DrawingArea();
    private Gtk.Label color_label = new Gtk.Label("");
    private Gtk.Button main_button = new Gtk.Button();
    private Gtk.Button copy_button = new Gtk.Button.from_icon_name("edit-copy-symbolic");

    private Gdk.RGBA _current_color;
    public Gdk.RGBA current_color {
        get { return _current_color; }
        set {
            _current_color = value;
            color_label.set_text(He.hexcode(current_color.red * 255, current_color.green * 255, current_color.blue * 255));
            color_preview.queue_draw();
        }
    }

    private bool _has_label;
    public bool has_label {
        get { return _has_label; }
        set {
            _has_label = value;
            update_label_visibility();
        }
    }

    private bool _can_copy;
    public bool can_copy {
        get { return _can_copy; }
        set {
            _can_copy = value;
            update_copy_visibility();
        }
    }

    construct {
        add_css_class("color-picker-button");

        color_label.add_css_class("numeric");
        color_label.set_max_width_chars(7);
        color_label.set_width_chars(7);
        color_label.set_visible(false);
        color_label.margin_start = 12;
        color_label.margin_end = 12;

        var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
        color_preview.set_size_request(32, 32);
        hbox.append(color_preview);
        hbox.append(color_label);

        main_button.set_child(hbox);
        main_button.add_css_class("main-button");

        copy_button.set_tooltip_text("Copy color to clipboard");
        copy_button.set_size_request(32, 32);
        copy_button.add_css_class("copy-button");
        copy_button.set_visible(false);

        update_label_visibility();
        update_copy_visibility();

        var main_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12) {
            vexpand = true,
            valign = Gtk.Align.CENTER
        };
        main_box.append(main_button);
        main_box.append(copy_button);

        this.child = (main_box);

        color_preview.set_draw_func(draw_color_preview);
        main_button.clicked.connect(() => show_color_dialog());
        copy_button.clicked.connect(() => copy_color_to_clipboard());
    }

    private void update_label_visibility() {
        if (_has_label) {
            color_label.set_visible(true);
            color_label.set_text(He.hexcode(current_color.red * 255, current_color.green * 255, current_color.blue * 255));
        } else {
            color_label.set_visible(false);
        }
    }

    private void update_copy_visibility() {
        if (_has_label) {
            copy_button.set_visible(true);
        } else {
            copy_button.set_visible(false);
        }
    }

    private void draw_color_preview(Gtk.DrawingArea da, Cairo.Context cr, int w, int h) {
        int diameter = w - 4;
        int radius = diameter / 2;
        int center_x = w / 2;
        int center_y = h / 2;

        cr.set_source_rgba(current_color.red, current_color.green, current_color.blue, current_color.alpha);
        cr.arc(center_x, center_y, radius, 0, 2 * Math.PI);
        cr.fill_preserve();

        cr.set_source_rgba(0, 0, 0, 0.32);
        cr.stroke();
    }

    private void show_color_dialog() {
        var popover = new ColorPickerPopover(this, current_color);

        popover.set_parent(color_preview);
        popover.show();

        var new_color = popover.current_color;
        if (new_color != current_color) {
            current_color = new_color;
            color_preview.queue_draw();
            if (_has_label) {
                color_label.set_text(He.hexcode(current_color.red * 255, current_color.green * 255, current_color.blue * 255));
            }
            popover.color_changed(current_color);
            color_changed(current_color);
        }
    }

    private void copy_color_to_clipboard() {
        var clipboard = this.get_display().get_clipboard();
        string color_hex = He.hexcode(current_color.red, current_color.green, current_color.blue);

        clipboard.set_text(color_hex);
    }

    public signal void color_changed(Gdk.RGBA new_color);

    public class ColorPickerPopover : Gtk.Popover {
        private Gtk.Scale r_slider;
        private Gtk.Scale g_slider;
        private Gtk.Scale b_slider;
        public Gdk.RGBA current_color;
        private ColorPickerButton p;

        public ColorPickerPopover(ColorPickerButton pa, Gdk.RGBA color) {
            this.p = pa;
            this.current_color = color;
            this.set_position(Gtk.PositionType.BOTTOM);
            this.set_size_request(300, -1);
            this.has_arrow = false;

            var sliders_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 24) {
                margin_top = 18,
                margin_bottom = 18,
                margin_end = 18,
                margin_start = 18
            };

            r_slider = create_rgb_slider("r-slider");
            g_slider = create_rgb_slider("g-slider");
            b_slider = create_rgb_slider("b-slider");

            var rlabel = new Gtk.Label(_("H"));
            var rbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12) {
                hexpand = true
            };
            rbox.append(rlabel);
            rbox.append(r_slider);

            var glabel = new Gtk.Label(_("C"));
            var gbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12) {
                hexpand = true
            };
            gbox.append(glabel);
            gbox.append(g_slider);

            var blabel = new Gtk.Label(_("T"));
            var bbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 12) {
                hexpand = true
            };
            bbox.append(blabel);
            bbox.append(b_slider);

            sliders_box.append(rbox);
            sliders_box.append(gbox);
            sliders_box.append(bbox);

            var hct = He.hct_from_int(He.rgb_to_argb_int(He.from_gdk_rgba({ color.red* 255, color.green* 255, color.blue* 255 })));
            r_slider.set_value(hct.h / 360);
            g_slider.set_value(hct.c / 100);
            b_slider.set_value(hct.t / 100);

            r_slider.value_changed.connect(() => update_color());
            g_slider.value_changed.connect(() => update_color());
            b_slider.value_changed.connect(() => update_color());

            this.set_child(sliders_box);
        }

        private Gtk.Scale create_rgb_slider(string type) {
            switch (type) {
            default:
            case "r-slider":
                var slider = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 0, 1, 0.01) {
                    hexpand = true,
                    draw_value = true,
                    value_pos = Gtk.PositionType.RIGHT
                };
                slider.set_format_value_func((s, v) => {
                    return ((int) (v * 360)).to_string();
                });
                slider.add_css_class(type);
                return slider;
            case "g-slider":
                var slider = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 0, 1, 0.01) {
                    hexpand = true,
                    draw_value = true,
                    value_pos = Gtk.PositionType.RIGHT
                };
                slider.set_format_value_func((s, v) => {
                    return ((int) (v * 100)).to_string();
                });
                slider.add_css_class(type);
                return slider;
            case "b-slider":
                var slider = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 0, 1, 0.01) {
                    hexpand = true,
                    draw_value = true,
                    value_pos = Gtk.PositionType.RIGHT
                };
                slider.set_format_value_func((s, v) => {
                    return ((int) (v * 100)).to_string();
                });
                slider.add_css_class(type);
                return slider;
            }
        }

        private void update_color() {
            Gdk.RGBA new_color = {};
            new_color.parse(He.hexcode_argb(He.hct_to_argb(r_slider.get_value() * 360, g_slider.get_value() * 150, b_slider.get_value() * 100)));

            if (new_color != current_color) {
                p.current_color = new_color;
                current_color = new_color;
                p.color_preview.queue_draw();
                if (p._has_label) {
                    p.color_label.set_text(He.hexcode(current_color.red * 255, current_color.green * 255, current_color.blue * 255));
                }
                p.color_changed(current_color);
                color_changed(current_color);
            }
        }

        public signal void color_changed(Gdk.RGBA new_color);
    }
}
