public class Sidebar : Object {
    private weak IconMakerWindow owner;
    private IconModel model;
    private Gtk.Box container;
    private Gtk.ListBox listbox;
    private Gtk.Popover add_pop;
    private Gtk.ToggleButton reorder_toggle;

    public Sidebar (IconMakerWindow owner, IconModel model) {
        this.owner = owner;
        this.model = model;
        build_ui ();
        refresh ();
    }

    public Gtk.Widget get_widget () {
        return container;
    }

    public void refresh () {
        if (listbox == null)return;
        while (true) {
            var existing = listbox.get_row_at_index (0);
            if (existing == null)break;
            listbox.remove (existing);
        }

        // Background row
        var bg_row = new Gtk.ListBoxRow ();
        bg_row.set_size_request (-1, 42);
        var bg_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        bg_box.add_css_class ("mini-content-block");
        var bg_label = new Gtk.Label (model.name);
        bg_label.add_css_class ("cb-title");
        bg_label.add_css_class ("caption");
        bg_label.set_xalign (0.0f);
        bg_label.set_hexpand (true);
        bg_box.append (bg_label);
        bg_row.set_child (bg_box);
        listbox.append (bg_row);

        int group_count = (int) model.groups.get_n_items ();
        for (int g = 0; g < group_count; g++) {
            int group_index = g;
            var group = (ElementGroup) model.groups.get_item ((uint) g);

            var header_row = new Gtk.ListBoxRow ();
            header_row.set_size_request (-1, 42);
            var header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            header_box.add_css_class ("mini-content-block");
            header_box.set_margin_start (8);
            var header_label = new Gtk.Label ("Group");
            header_label.add_css_class ("caption");
            header_label.set_xalign (0.0f);
            header_label.set_hexpand (true);
            header_box.append (header_label);
            header_row.set_child (header_box);

            if (model.reorder_mode) {
                var header_drop = new Gtk.DropTarget (typeof (string), Gdk.DragAction.MOVE);
                header_drop.drop.connect ((dt, val, x, y) => {
                    var drag_data = (string) val;
                    var parts = drag_data.split (":");
                    if (parts.length == 2) {
                        int src_group = int.parse (parts[0]);
                        int src_elem = int.parse (parts[1]);
                        int dest_pos = (int) group.elements.get_n_items ();
                        owner.move_element_between_groups (src_group, src_elem, group_index, dest_pos);
                    }
                    return true;
                });
                header_row.add_controller (header_drop);
            }

            listbox.append (header_row);

            int element_count = (int) group.elements.get_n_items ();
            for (int i = 0; i < element_count; i++) {
                int element_index = i;
                var element = (IconElement) group.elements.get_item ((uint) i);
                var row = new Gtk.ListBoxRow ();
                row.set_size_request (-1, 42);
                var row_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
                row_box.add_css_class ("mini-content-block");
                row_box.set_margin_start (16);

                var mini_canvas = new Gtk.DrawingArea ();
                mini_canvas.set_content_width (32);
                mini_canvas.set_content_height (32);
                mini_canvas.set_draw_func ((da, cr, w, h) => {
                    render_mini_element (cr, element, 32);
                });
                row_box.append (mini_canvas);

                var label = new Gtk.Label (element_label (element));
                label.set_xalign (0.0f);
                label.set_hexpand (true);
                row_box.append (label);

                if (model.reorder_mode) {
                    var drag_source = new Gtk.DragSource ();
                    drag_source.set_actions (Gdk.DragAction.MOVE);
                    drag_source.prepare.connect ((ds, x, y) => {
                        var drag_data = @"$group_index:$element_index";
                        var value = GLib.Value (typeof (string));
                        value.set_string (drag_data);
                        return new Gdk.ContentProvider.for_value (value);
                    });
                    row.add_controller (drag_source);

                    var drop_target = new Gtk.DropTarget (typeof (string), Gdk.DragAction.MOVE);
                    drop_target.drop.connect ((dt, val, x, y) => {
                        var drag_data = (string) val;
                        var parts = drag_data.split (":");
                        if (parts.length == 2) {
                            int src_group = int.parse (parts[0]);
                            int src_elem = int.parse (parts[1]);
                            owner.move_element_between_groups (src_group, src_elem, group_index, element_index);
                        }
                        return true;
                    });
                    row.add_controller (drop_target);
                }

                var remove_btn = new He.Button ("edit-delete-symbolic", "");
                remove_btn.is_iconic = true;
                remove_btn.set_tooltip_text ("Remove");
                remove_btn.set_valign (Gtk.Align.CENTER);
                remove_btn.clicked.connect (() => {
                    owner.remove_element_at (group_index, element_index);
                });
                row_box.append (remove_btn);

                row.set_child (row_box);
                listbox.append (row);
            }
        }

        sync_selection ();
    }

    public void sync_selection () {
        if (listbox == null)return;
        if (model.background_selected) {
            var first = listbox.get_row_at_index (0);
            if (first != null) {
                listbox.select_row (first);
            }
            return;
        }

        int group_index = model.selected_group_index;
        if (group_index < 0) {
            listbox.unselect_all ();
            return;
        }

        if (model.group_selected) {
            int flat_index = 1;
            for (int g = 0; g < group_index; g++) {
                var grp = (ElementGroup) model.groups.get_item ((uint) g);
                flat_index += 1 + (int) grp.elements.get_n_items ();
            }
            flat_index += 1;
            var row = listbox.get_row_at_index (flat_index);
            if (row != null) {
                listbox.select_row (row);
            }
            return;
        }

        int element_index = model.selected_element_index;
        if (element_index < 0) {
            listbox.unselect_all ();
            return;
        }

        int flat = 1;
        for (int g = 0; g < (int) model.groups.get_n_items (); g++) {
            var grp = (ElementGroup) model.groups.get_item ((uint) g);
            flat += 1;
            if (g == group_index) {
                flat += element_index;
                var row = listbox.get_row_at_index (flat);
                if (row != null)listbox.select_row (row);
                return;
            }
            flat += (int) grp.elements.get_n_items ();
        }

        listbox.unselect_all ();
    }

    private void build_ui () {
        container = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        container.set_size_request (260, -1);
        container.set_vexpand (true);
        container.set_hexpand_set (true);
        container.set_halign (Gtk.Align.START);
        container.add_css_class ("sidebar-view");

        var appbar = new He.AppBar ();
        appbar.show_left_title_buttons = true;
        appbar.show_right_title_buttons = false;
        container.append (appbar);

        var left_header = new Gtk.Label (null);
        left_header.add_css_class ("view-title");
        left_header.set_markup ("Elements");
        left_header.set_halign (Gtk.Align.START);
        left_header.set_hexpand (true);

        reorder_toggle = new Gtk.ToggleButton ();
        reorder_toggle.icon_name = "document-edit-symbolic";

        appbar.viewtitle_widget = left_header;
        appbar.append_toggle (reorder_toggle);

        add_pop = new Gtk.Popover ();
        add_pop.set_autohide (true);
        add_pop.has_arrow = false;
        add_pop.set_position (Gtk.PositionType.TOP);
        add_pop.add_css_class ("overlay-popover");

        var add_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        add_box.margin_bottom = 6;
        add_box.margin_top = 6;
        add_box.margin_start = 6;
        add_box.margin_end = 6;

        var add_rect_btn = new He.Button ("", "Rectangle");
        add_rect_btn.is_textual = true;
        add_box.append (add_rect_btn);

        var add_circle_btn = new He.Button ("", "Circle");
        add_circle_btn.is_textual = true;
        add_box.append (add_circle_btn);

        var add_line_btn = new He.Button ("", "Line");
        add_line_btn.is_textual = true;
        add_box.append (add_line_btn);

        var add_svg_btn = new He.Button ("", "Image (.svg)");
        add_svg_btn.is_textual = true;
        add_box.append (add_svg_btn);

        add_pop.set_child (add_box);

        listbox = new Gtk.ListBox ();
        listbox.margin_start = 18;
        listbox.margin_end = 18;
        listbox.set_vexpand (true);
        listbox.add_css_class ("content-list");

        var drop_target = new Gtk.DropTarget (typeof (Gdk.FileList), Gdk.DragAction.COPY);
        drop_target.drop.connect ((dt, val, x, y) => {
            var file_list = (Gdk.FileList) val;
            var files = file_list.get_files ();
            for (int i = 0; i < files.length (); i++) {
                var file = files.nth_data (i);
                var path = file.get_path ();
                if (path != null && path.down ().has_suffix (".svg")) {
                    owner.load_svg_file (file);
                }
            }
            return true;
        });
        listbox.add_controller (drop_target);

        var add_overlay_btn = new He.OverlayButton ("list-add-symbolic", null, null);
        add_overlay_btn.primary_tooltip = "Add element";
        add_overlay_btn.typeb = He.OverlayButton.TypeButton.PRIMARY;
        add_overlay_btn.child = listbox;
        add_pop.set_parent (add_overlay_btn.get_primary_button ());
        add_overlay_btn.clicked.connect (() => {
            if (add_pop.get_visible ()) {
                add_pop.popdown ();
            } else {
                add_pop.popup ();
            }
        });

        container.append (add_overlay_btn);

        reorder_toggle.toggled.connect (() => {
            model.reorder_mode = reorder_toggle.get_active ();
            refresh ();
        });

        listbox.row_selected.connect ((lb, row) => {
            handle_row_selected (row);
        });

        add_rect_btn.clicked.connect (() => {
            owner.add_element_in_new_group (new IconElement (ElementType.RECTANGLE));
            refresh ();
            owner.sidebar_selection_changed ();
            add_pop.popdown ();
        });

        add_circle_btn.clicked.connect (() => {
            owner.add_element_in_new_group (new IconElement (ElementType.CIRCLE));
            refresh ();
            owner.sidebar_selection_changed ();
            add_pop.popdown ();
        });

        add_line_btn.clicked.connect (() => {
            var element = new IconElement (ElementType.LINE);
            element.line_length = 56.0f;
            element.line_angle = 0.0;
            element.gradient_secondary = element.stroke;
            owner.refresh_line_deltas (element);
            owner.add_element_in_new_group (element);
            refresh ();
            owner.sidebar_selection_changed ();
            add_pop.popdown ();
        });

        add_svg_btn.clicked.connect (() => {
            var file_chooser = new Gtk.FileDialog ();
            var filter = new Gtk.FileFilter ();
            filter.set_filter_name ("SVG Files");
            filter.add_mime_type ("image/svg+xml");
            filter.add_pattern ("*.svg");
            var filters = new GLib.ListStore (typeof (Gtk.FileFilter));
            filters.append (filter);
            file_chooser.set_filters (filters);
            file_chooser.open.begin (owner, null, (obj, res) => {
                try {
                    var file = file_chooser.open.end (res);
                    if (file != null) {
                        owner.load_svg_file (file);
                    }
                } catch (Error e) {
                }
            });
            add_pop.popdown ();
        });
    }

    private void handle_row_selected (Gtk.ListBoxRow? row) {
        if (row == null) {
            model.background_selected = false;
            model.group_selected = false;
            model.selected_group_index = -1;
            model.selected_element_index = -1;
        } else {
            int row_index = row.get_index ();
            if (row_index == 0) {
                model.background_selected = true;
                model.group_selected = false;
                model.selected_group_index = -1;
                model.selected_element_index = -1;
            } else {
                model.background_selected = false;
                model.group_selected = false;
                int flat_idx = row_index - 1;
                int counter = 0;
                bool found = false;
                for (int g = 0; g < (int) model.groups.get_n_items (); g++) {
                    var group = (ElementGroup) model.groups.get_item ((uint) g);
                    int element_count = (int) group.elements.get_n_items ();
                    if (flat_idx == counter) {
                        model.group_selected = true;
                        model.selected_group_index = g;
                        model.selected_element_index = -1;
                        found = true;
                        break;
                    }
                    counter++;
                    if (flat_idx < counter + element_count) {
                        model.selected_group_index = g;
                        model.selected_element_index = flat_idx - counter;
                        found = true;
                        break;
                    }
                    counter += element_count;
                }
                if (!found) {
                    model.selected_group_index = -1;
                    model.selected_element_index = -1;
                }
            }
        }

        owner.sidebar_selection_changed ();
    }

    private string element_label (IconElement element) {
        switch (element.type) {
        case ElementType.RECTANGLE :
            return "Rectangle";
        case ElementType.CIRCLE:
            return "Circle";
        case ElementType.LINE:
            return "Line";
        case ElementType.SVG:
            return "SVG";
        default:
            return "Element";
        }
    }

    private void render_mini_element (Cairo.Context cr, IconElement element, int size) {
        cr.new_path ();
        IconiUtils.append_rounded_rect (cr, 0.0, 0.0, (double) size, (double) size, 2.0, 2.0, 2.0, 2.0);
        cr.clip ();

        int checker_size = 4;
        for (int y = 0; y < size; y += checker_size) {
            for (int x = 0; x < size; x += checker_size) {
                if ((x / checker_size + y / checker_size) % 2 == 0) {
                    cr.set_source_rgba (0.9, 0.9, 0.9, 1.0);
                } else {
                    cr.set_source_rgba (0.8, 0.8, 0.8, 1.0);
                }
                cr.rectangle ((double) x, (double) y, (double) checker_size, (double) checker_size);
                cr.fill ();
            }
        }
        cr.reset_clip ();

        double scale = (double) size / 109.0;
        double ex = element.x * scale;
        double ey = element.y * scale;
        double ew = element.width * scale;
        double eh = element.height * scale;

        cr.save ();
        if (element.element_angle != 0.0) {
            double center_x = ex + ew / 2.0;
            double center_y = ey + eh / 2.0;
            cr.translate (center_x, center_y);
            cr.rotate (element.element_angle * (GLib.Math.PI / 180.0));
            cr.translate (-center_x, -center_y);
        }

        if (element.type == ElementType.RECTANGLE) {
            cr.set_source_rgba (element.fill.red, element.fill.green, element.fill.blue, element.fill.alpha);
            double tl = element.corner_radius_top_left * scale;
            double tr = element.corner_radius_top_right * scale;
            double br = element.corner_radius_bottom_right * scale;
            double bl = element.corner_radius_bottom_left * scale;
            cr.new_path ();
            IconiUtils.append_rounded_rect (cr, ex, ey, ew, eh, tl, tr, br, bl);
            cr.fill_preserve ();
            cr.set_source_rgba (element.stroke.red, element.stroke.green, element.stroke.blue, element.stroke.alpha);
            cr.set_line_width (element.stroke_width * scale);
            cr.stroke ();
        } else if (element.type == ElementType.CIRCLE) {
            double scale_x = ew / 2.0;
            double scale_y = eh / 2.0;
            double line_scale = (GLib.Math.fabs (scale_x) + GLib.Math.fabs (scale_y)) / 2.0;
            if (line_scale <= 0.0)line_scale = 1.0;
            cr.save ();
            cr.translate (ex + ew / 2.0, ey + eh / 2.0);
            cr.scale (scale_x, scale_y);
            cr.arc (0.0, 0.0, 1.0, 0.0, 2.0 * GLib.Math.PI);
            cr.restore ();
            cr.set_source_rgba (element.fill.red, element.fill.green, element.fill.blue, element.fill.alpha);
            cr.fill_preserve ();
            cr.set_source_rgba (element.stroke.red, element.stroke.green, element.stroke.blue, element.stroke.alpha);
            cr.set_line_width (element.stroke_width * scale);
            cr.stroke ();
        } else if (element.type == ElementType.LINE) {
            cr.set_source_rgba (element.stroke.red, element.stroke.green, element.stroke.blue, element.stroke.alpha);
            cr.set_line_width (element.stroke_width * scale);
            cr.move_to (ex, ey);
            cr.line_to (ex + ew, ey + eh);
            cr.stroke ();
        } else if (element.type == ElementType.SVG) {
            try {
                var handle = new Rsvg.Handle.from_data (element.svg_data.data);
                var viewport = Rsvg.Rectangle ();
                viewport.x = ex;
                viewport.y = ey;
                viewport.width = ew;
                viewport.height = eh;
                handle.render_document (cr, viewport);
            } catch (Error e) {
                warning ("Failed to render SVG in mini canvas: %s", e.message);
            }
        }

        cr.restore ();
    }
}