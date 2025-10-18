public class IconMakerWindow : He.ApplicationWindow {
    private IconModel model;
    private IconRenderer renderer;
    private const double SAFE_VIEW_SIZE = 109.0;
    private const int SVG_VIEWPORT_SIZE = 128;
    private const int SIDEBAR_WIDTH = 313;

    public int INSPECTOR_WIDTH = 360;

    private Gtk.DrawingArea canvas;
    private Gtk.Box center_box;
    private He.AppBar mappbar;
    private Sidebar sidebar;
    private Inspector inspector;
    private Gtk.Overlay overlay;

    private Gtk.CssProvider? view_bg_css;
    private static GLib.Settings? wallpaper_settings;
    private string wallpaper_uri_cache = "";

    static construct {
        wallpaper_settings = new GLib.Settings ("org.gnome.desktop.background");
    }

    public IconMakerWindow (IconMakerApplication app) {
        Object (application : app);
        set_title ("Icon Maker");
        set_default_size (1240, 800);
        set_size_request (360, 294);
        model = new IconModel ();
        renderer = new IconRenderer (model);
        setup_wallpaper_settings ();
        setup_ui ();
    }

    public IconElement ? get_selected_element () {
        if (model.selected_group_index < 0 || model.selected_element_index < 0)
            return null;
        var group = (ElementGroup) model.groups.get_item ((uint) model.selected_group_index);
        if (group == null)
            return null;
        return (IconElement?) group.elements.get_item ((uint) model.selected_element_index);
    }

    public ElementGroup ? get_selected_group () {
        if (model.selected_group_index < 0)
            return null;
        return (ElementGroup?) model.groups.get_item ((uint) model.selected_group_index);
    }

    public void add_element_in_new_group (IconElement el) {
        var new_group = new ElementGroup (model.name);
        new_group.elements.append (el);
        model.groups.append (new_group);
        sidebar.refresh ();
        canvas.queue_draw ();
    }

    public void load_svg_file (GLib.File file) {
        sidebar.load_svg_file (file);
    }

    public void remove_element_at (int group_index, int element_index) {
        if (group_index < 0 || group_index >= (int) model.groups.get_n_items ())
            return;
        var group = (ElementGroup) model.groups.get_item ((uint) group_index);
        if (group == null)
            return;
        if (element_index < 0 || element_index >= (int) group.elements.get_n_items ())
            return;

        group.elements.remove ((uint) element_index);

        if (group.elements.get_n_items () == 0) {
            model.groups.remove ((uint) group_index);
            if (model.groups.get_n_items () == 0) {
                model.background_selected = true;
                model.group_selected = false;
                model.selected_group_index = -1;
                model.selected_element_index = -1;
            } else {
                int new_group = (int) GLib.Math.fmin ((double) group_index, (double) (model.groups.get_n_items () - 1));
                model.selected_group_index = new_group;
                model.selected_element_index = -1;
                model.background_selected = false;
                model.group_selected = true;
            }
        } else {
            int new_elem = (int) GLib.Math.fmin ((double) element_index, (double) (group.elements.get_n_items () - 1));
            model.selected_group_index = group_index;
            model.selected_element_index = new_elem;
            model.background_selected = false;
            model.group_selected = false;
        }

        sidebar.refresh ();
        sidebar_selection_changed ();
    }

    public void move_element_between_groups (int src_group_idx, int src_elem_idx, int dest_group_idx, int dest_elem_idx) {
        if (src_group_idx < 0 || src_group_idx >= (int) model.groups.get_n_items ())
            return;
        if (dest_group_idx < 0 || dest_group_idx >= (int) model.groups.get_n_items ())
            return;

        var src_group = (ElementGroup) model.groups.get_item ((uint) src_group_idx);
        if (src_group == null)
            return;
        if (src_elem_idx < 0 || src_elem_idx >= (int) src_group.elements.get_n_items ())
            return;

        var element = (IconElement) src_group.elements.get_item ((uint) src_elem_idx);
        if (element == null)
            return;

        src_group.elements.remove ((uint) src_elem_idx);

        var dest_group = (ElementGroup) model.groups.get_item ((uint) dest_group_idx);
        if (dest_group == null) {
            src_group.elements.insert ((uint) src_elem_idx, element);
            return;
        }

        int insert_pos = dest_elem_idx;
        if (src_group_idx == dest_group_idx && src_elem_idx < dest_elem_idx) {
            insert_pos--;
        }
        insert_pos = (int) GLib.Math.fmax (0.0, GLib.Math.fmin ((double) insert_pos, (double) dest_group.elements.get_n_items ()));
        dest_group.elements.insert ((uint) insert_pos, element);

        if (src_group.elements.get_n_items () == 0) {
            model.groups.remove ((uint) src_group_idx);
            if (dest_group_idx > src_group_idx) {
                dest_group_idx--;
            }
        }

        model.selected_group_index = dest_group_idx;
        model.selected_element_index = insert_pos;
        model.background_selected = false;
        model.group_selected = false;

        sidebar.refresh ();
        sidebar_selection_changed ();
    }

    public void refresh_line_deltas (IconElement el) {
        inspector.refresh_line_deltas (el);
        canvas.queue_draw ();
    }

    public void sidebar_selection_changed () {
        inspector.update_for_selection ();
        canvas.queue_draw ();
    }

    public void apply_view_background_css () {
        if (center_box == null)return;
        if (view_bg_css == null) {
            view_bg_css = new Gtk.CssProvider ();
            var display = get_display ();
            if (display != null) {
                Gtk.StyleContext.add_provider_for_display (display, view_bg_css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            }
        }

        bool needs_light_fg = model.use_wallpaper || should_use_light_view_foreground ();
        if (needs_light_fg) {
            center_box.add_css_class ("light-fg");
        } else {
            center_box.remove_css_class ("light-fg");
        }

        var builder = new GLib.StringBuilder ("#center-bg { ");
        var vb = model.view_background;
        int r = (int) (vb.red * 255.0 + 0.5);
        int g = (int) (vb.green * 255.0 + 0.5);
        int b = (int) (vb.blue * 255.0 + 0.5);
        builder.append ("background: rgba(%d, %d, %d, %.3f);".printf (r, g, b, vb.alpha));

        if (model.use_wallpaper) {
            string? uri = get_preferred_wallpaper_uri ();
            if (uri != null) {
                if (wallpaper_uri_cache != uri) {
                    wallpaper_uri_cache = uri;
                }
                string escaped = IconiUtils.escape_css_url (uri);
                builder.append (" background-image: url(\"%s\"); background-size: cover; background-position: center; background-repeat: no-repeat;".printf (escaped));
            }
        }
        builder.append (" }");

        view_bg_css.load_from_data ((uint8[]) builder.str);
    }

    private bool should_use_light_view_foreground () {
        double bg_luminance = IconiUtils.compute_relative_luminance (model.view_background);
        double contrast_white = IconiUtils.contrast_ratio (bg_luminance, 1.0);
        double contrast_black = IconiUtils.contrast_ratio (bg_luminance, 0.0);
        return contrast_white >= contrast_black;
    }

    private void apply_wallpaper_state (bool state) {
        model.use_wallpaper = state;
        if (inspector != null) {
            inspector.sync_wallpaper_toggle (state);
        }
        apply_view_background_css ();
    }

    public void open_export_dialog () {
        var file_chooser = new Gtk.FileDialog ();
        file_chooser.set_initial_name (model.name + ".svg");
        var filter = new Gtk.FileFilter ();
        filter.set_filter_name ("SVG Files");
        filter.add_mime_type ("image/svg+xml");
        filter.add_pattern ("*.svg");
        var filters = new GLib.ListStore (typeof (Gtk.FileFilter));
        filters.append (filter);
        file_chooser.set_filters (filters);
        file_chooser.save.begin (this, null, (obj, res) => {
            try {
                var file = file_chooser.save.end (res);
                if (file != null) {
                    string path = file.get_path ();
                    if (path != null) {
                        IconiUtils.export_icon_to_svg (model, path);
                        var toast = new He.Toast ("");
                        toast.set_halign (Gtk.Align.CENTER);
                        toast.set_valign (Gtk.Align.END);
                        toast.set_margin_bottom (18);
                        toast.label = "Icon exported successfully";
                        overlay.add_overlay (toast);
                        toast.send_notification ();
                    } else {
                        var toast = new He.Toast ("");
                        toast.set_halign (Gtk.Align.CENTER);
                        toast.set_valign (Gtk.Align.END);
                        toast.set_margin_bottom (18);
                        toast.label = "Operation cancelled";
                        overlay.add_overlay (toast);
                        toast.send_notification ();
                    }
                }
            } catch (Error e) {
            }
        });
    }

    private void setup_wallpaper_settings () {
        if (wallpaper_settings == null)
            return;
        wallpaper_settings.changed.connect ((key) => {
            if (key == "picture-uri" || key == "picture-uri-dark") {
                wallpaper_uri_cache = "";
                if (model.use_wallpaper) {
                    apply_view_background_css ();
                }
            }
        });
    }

    private string ? get_preferred_wallpaper_uri () {
        if (wallpaper_settings == null)return null;
        string primary = wallpaper_settings.get_string ("picture-uri");
        string? candidate = IconiUtils.normalize_wallpaper_entry (primary);
        if (candidate != null)return candidate;
        string secondary = wallpaper_settings.get_string ("picture-uri-dark");
        return IconiUtils.normalize_wallpaper_entry (secondary);
    }

    private void setup_ui () {
        var main_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);

        var key_controller = new Gtk.EventControllerKey ();
        main_box.add_controller (key_controller);
        key_controller.key_pressed.connect ((controller, keyval, keycode, state) => {
            if (keyval == Gdk.Key.Delete || keyval == Gdk.Key.BackSpace) {
                if (!model.background_selected && model.selected_group_index >= 0 && model.selected_element_index >= 0) {
                    remove_element_at (model.selected_group_index, model.selected_element_index);
                }
                return true;
            }
            return false;
        });

        sidebar = new Sidebar (this, model);

        center_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        center_box.set_vexpand (true);
        center_box.set_hexpand (true);
        center_box.set_name ("center-bg");

        mappbar = new He.AppBar ();
        mappbar.show_left_title_buttons = false;
        mappbar.show_right_title_buttons = false;
        mappbar.set_margin_end (INSPECTOR_WIDTH + 12);
        mappbar.set_margin_start (SIDEBAR_WIDTH + 12);
        mappbar.add_css_class ("main-appbar");
        center_box.append (mappbar);

        var name_label = new Gtk.Label (model.name);
        name_label.add_css_class ("view-title");
        name_label.set_halign (Gtk.Align.START);
        name_label.set_valign (Gtk.Align.CENTER);

        var name_entry = new He.TextField ();
        name_entry.is_outline = true;
        name_entry.get_internal_entry ().set_text (model.name);
        name_entry.set_halign (Gtk.Align.START);
        name_entry.set_size_request (180, -1);

        var name_stack = new Gtk.Stack ();
        name_stack.set_halign (Gtk.Align.START);
        name_stack.add_named (name_label, "label");
        name_stack.add_named (name_entry, "entry");
        name_stack.set_visible_child_name ("label");

        var name_click = new Gtk.GestureClick ();
        name_label.add_controller (name_click);
        name_click.released.connect ((g, n_press, x, y) => {
            name_stack.set_visible_child_name ("entry");
            name_entry.grab_focus ();
            name_entry.get_internal_entry ().select_region (0, -1);
        });
        var focus_ctl = new Gtk.EventControllerFocus ();
        name_entry.get_internal_entry ().add_controller (focus_ctl);
        focus_ctl.leave.connect (() => {
            string new_name = name_entry.get_internal_entry ().get_text ().strip ();
            if (new_name.length > 0) {
                model.name = new_name;
                name_label.set_text (new_name);
            }
            name_stack.set_visible_child_name ("label");
        });
        name_entry.get_internal_entry ().activate.connect (() => {
            string new_name = name_entry.get_internal_entry ().get_text ().strip ();
            if (new_name.length > 0) {
                model.name = new_name;
                name_label.set_text (new_name);
            }
            name_stack.set_visible_child_name ("label");
        });

        mappbar.viewtitle_widget = name_stack;

        var view_bg_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        view_bg_box.set_valign (Gtk.Align.CENTER);
        view_bg_box.add_css_class ("linked");

        var wallpaper_btn = new Gtk.ToggleButton ();
        wallpaper_btn.add_css_class ("wallpaper-btn");
        wallpaper_btn.set_tooltip_text ("Show system wallpaper behind preview");
        var wallpaper_icon = new Gtk.DrawingArea ();
        wallpaper_icon.set_content_width (32);
        wallpaper_icon.set_content_height (30);
        wallpaper_icon.set_draw_func ((area, cr, width, height) => {
            double w = width - 2;
            double h = height;
            double cx = w / 2.0;
            double cy = h / 2.0;
            double r = GLib.Math.fmin (w, h) / 2.0;

            cr.save ();
            cr.arc (cx + 1, cy, r, 0.0, 2.0 * GLib.Math.PI);
            cr.clip ();

            string? wp_uri = get_preferred_wallpaper_uri ();
            if (wp_uri != null && wp_uri.has_prefix ("file://")) {
                string path = wp_uri.substring (7);
                try {
                    var pixbuf = new Gdk.Pixbuf.from_file (path);
                    int pw = pixbuf.get_width ();
                    int ph = pixbuf.get_height ();

                    double scale = GLib.Math.fmax (w / (double) pw, h / (double) ph);
                    double sw = pw * scale;
                    double sh = ph * scale;
                    double ox = (w - sw) / 2.0;
                    double oy = (h - sh) / 2.0;

                    cr.scale (scale, scale);
                    Gdk.cairo_set_source_pixbuf (cr, pixbuf, ox / scale, oy / scale);
                    cr.paint ();
                } catch (Error e) {
                    cr.set_source_rgba (0.5, 0.5, 0.5, 1.0);
                    cr.paint ();
                }
            } else {
                cr.set_source_rgba (0.5, 0.5, 0.5, 1.0);
                cr.paint ();
            }

            cr.restore ();
        });
        wallpaper_btn.set_child (wallpaper_icon);
        view_bg_box.append (wallpaper_btn);

        var gray_btn = new Gtk.ToggleButton ();
        gray_btn.add_css_class ("gray-btn");
        gray_btn.set_tooltip_text ("Show gray background behind preview");
        var gray_icon = new Gtk.DrawingArea ();
        gray_icon.set_content_width (32);
        gray_icon.set_content_height (30);
        gray_icon.set_draw_func ((area, cr, width, height) => {
            double w = width - 2;
            double h = height;
            double cx = w / 2.0;
            double cy = h / 2.0;
            double r = GLib.Math.fmin (w, h) / 2.0;

            cr.arc (cx + 1, cy, r, 0.0, 2.0 * GLib.Math.PI);
            cr.set_source_rgb (0.533, 0.533, 0.533);
            cr.fill_preserve ();
            cr.stroke ();
        });
        gray_btn.set_child (gray_icon);
        view_bg_box.append (gray_btn);

        mappbar.append (view_bg_box);

        wallpaper_btn.toggled.connect (() => {
            if (wallpaper_btn.get_active ()) {
                gray_btn.set_active (false);
                apply_wallpaper_state (true);
                wallpaper_icon.queue_draw ();
                gray_icon.queue_draw ();
            }
        });

        gray_btn.toggled.connect (() => {
            if (gray_btn.get_active ()) {
                wallpaper_btn.set_active (false);
                apply_wallpaper_state (false);
                wallpaper_icon.queue_draw ();
                gray_icon.queue_draw ();
            }
        });

        if (model.use_wallpaper) {
            wallpaper_btn.set_active (true);
        } else {
            gray_btn.set_active (true);
        }

        canvas = new Gtk.DrawingArea ();
        canvas.set_margin_end (INSPECTOR_WIDTH + 12);
        canvas.set_margin_start (SIDEBAR_WIDTH + 12);
        canvas.set_content_width (SVG_VIEWPORT_SIZE);
        canvas.set_content_height (SVG_VIEWPORT_SIZE);
        canvas.set_hexpand (true);
        canvas.set_vexpand (true);
        canvas.set_halign (Gtk.Align.CENTER);
        canvas.set_valign (Gtk.Align.CENTER);
        canvas.set_size_request ((int) (SVG_VIEWPORT_SIZE * model.zoom), (int) (SVG_VIEWPORT_SIZE * model.zoom));
        canvas.set_margin_top (6);
        canvas.add_css_class ("view-canvas");
        canvas.set_draw_func ((area, cr, width, height) => {
            cr.set_source_rgba (0, 0, 0, 0);
            cr.paint ();
            float z = IconiUtils.clampf (model.zoom, 0.25f, 3.0f);
            cr.save ();
            cr.scale (z, z);
            renderer.render_icon (cr, 109.0f);
            cr.restore ();
        });
        center_box.append (canvas);

        main_box.append (center_box);

        inspector = new Inspector (this, model, canvas, mappbar);

        overlay = new Gtk.Overlay ();
        overlay.set_hexpand (true);
        overlay.set_vexpand (true);
        overlay.set_halign (Gtk.Align.FILL);
        overlay.set_valign (Gtk.Align.FILL);
        overlay.set_child (main_box);
        overlay.add_overlay (sidebar.get_widget ());
        overlay.add_overlay (inspector.get_widget ());

        child = overlay;
        apply_view_background_css ();

        this.present ();
    }
}