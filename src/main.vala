// GTK4 Icon Maker
public enum ElementType {
	RECTANGLE,
	CIRCLE,
	LINE
}

public class IconElement : GLib.Object {
	public ElementType type;
	public float x;
	public float y;
	public float width;   // for LINE: delta X
	public float height;  // for LINE: delta Y
	public Gdk.RGBA fill;
	public Gdk.RGBA stroke;
	public float stroke_width;
	public string blend_mode; // "normal", "multiply", "screen", "overlay"

	public IconElement (ElementType t) {
		type = t;
		x = 10.0f;
		y = 10.0f;
		width = 40.0f;
		height = 40.0f;
		stroke_width = 1.0f;
		blend_mode = "normal";
		Gdk.RGBA tmp = { 0 };
		tmp.parse ("#ffffff"); fill = tmp;
		tmp.parse ("#000000"); stroke = tmp;
	}
}

public class IconModel : GLib.Object {
	public GLib.ListStore elements; // IconElement
	public int selected_index = -1;
	public bool background_selected = false;
	public bool reorder_mode = false;

	public string name = "icon-name";
	public Gdk.RGBA background = { 0 };
	public bool use_wallpaper = false;
	public float zoom = 1.0f;

	public IconModel () {
		elements = new GLib.ListStore (typeof (IconElement));
		Gdk.RGBA tmp = { 0 };
		tmp.parse ("#0080FF"); background = tmp;
	}
}

public class IconMakerApp : Gtk.Application {
	private IconModel model;

	// UI fields
	private Gtk.ListBox listbox;
	private Gtk.DrawingArea canvas;

	private Gtk.Box props_area;
	private Gtk.Box bg_props_area;

	private Gtk.SpinButton x_entry;
	private Gtk.SpinButton y_entry;
	private Gtk.SpinButton w_entry;
	private Gtk.SpinButton h_entry;

	private Gtk.ColorDialogButton fill_btn;
	private Gtk.ColorDialogButton stroke_btn;
	private Gtk.SpinButton fill_opacity_spin;
	private Gtk.SpinButton stroke_opacity_spin;
	private Gtk.SpinButton stroke_width_spin;

	private Gtk.DropDown blend_drop;
	private string[] blends = {"normal","multiply","screen","overlay"};

	private Gtk.ColorDialogButton bg_color_btn;
	private Gtk.ColorDialogButton bg_side_color_btn;
	private Gtk.Switch bg_wallpaper_switch;
	private Gtk.Switch bg_side_wall_switch;

	private Gtk.Scale zoom_scale;

	public IconMakerApp () {
		Object (application_id: "com.example.Gtk4IconMaker");
		model = new IconModel ();
	}

	protected override void activate () {
		var win = new Gtk.ApplicationWindow (this);
		win.set_title ("Icon Maker");
		win.set_default_size (1024, 800);

		var main_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
		win.set_child (main_box);

		// Global key controller on main_box
		var key_controller = new Gtk.EventControllerKey ();
		main_box.add_controller (key_controller);
		key_controller.key_pressed.connect ((controller, keyval, keycode, state) => {
			if (keyval == Gdk.Key.Delete || keyval == Gdk.Key.BackSpace) {
				if (!model.background_selected && model.selected_index >= 0) {
					remove_element_at (model.selected_index);
				}
				return true;
			}
			return false;
		});

		// LEFT SIDEBAR
		var left_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		left_box.set_size_request (260, -1);
		left_box.set_vexpand (true);
		left_box.set_hexpand_set (true);
		left_box.set_margin_top (8);
		left_box.set_margin_bottom (8);
		left_box.set_margin_start (18);
		left_box.set_margin_end (18);
		main_box.append (left_box);

		var header_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		var left_header = new Gtk.Label (null);
		left_header.add_css_class ("title-1");
		left_header.set_markup ("Elements");
		left_header.set_halign (Gtk.Align.START);
		left_header.set_hexpand (true);

		var reorder_toggle = new Gtk.ToggleButton ();
		reorder_toggle.icon_name = "document-edit-symbolic";

		var add_menu_btn = new Gtk.MenuButton ();
		add_menu_btn.set_tooltip_text ("Add element");
		var add_pop = new Gtk.Popover ();
		var add_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		var add_rect_btn = new Gtk.Button.with_label ("Rectangle");
		var add_circle_btn = new Gtk.Button.with_label ("Circle");
		var add_line_btn = new Gtk.Button.with_label ("Line");
		add_box.append (add_rect_btn);
		add_box.append (add_circle_btn);
		add_box.append (add_line_btn);
		add_pop.set_child (add_box);
		add_menu_btn.set_popover (add_pop);
		add_menu_btn.set_child (new Gtk.Image.from_icon_name ("list-add-symbolic"));

		header_row.append (left_header);
		header_row.append (reorder_toggle);
		header_row.append (add_menu_btn);
		left_box.append (header_row);

		listbox = new Gtk.ListBox ();
		listbox.set_vexpand (true);
		listbox.add_css_class ("content-list");
		left_box.append (listbox);

		// CENTER
		var center_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		center_box.set_margin_top (8);
		center_box.set_hexpand (true);
		center_box.set_vexpand (true);
		main_box.append (center_box);

		var top_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		center_box.append (top_row);

		// Name label <-> entry via stack
		var name_label = new Gtk.Label (model.name);
		name_label.add_css_class ("title-1");
		name_label.set_halign (Gtk.Align.START);
		name_label.set_valign (Gtk.Align.CENTER);

		var name_entry = new Gtk.Entry ();
		name_entry.set_text (model.name);
		name_entry.set_hexpand (true);

		var name_stack = new Gtk.Stack ();
		name_stack.add_named (name_label, "label");
		name_stack.add_named (name_entry, "entry");
		name_stack.set_visible_child_name ("label");

		var name_click = new Gtk.GestureClick ();
		name_label.add_controller (name_click);
		name_click.released.connect ((g, n_press, x, y) => {
			name_stack.set_visible_child_name ("entry");
			name_entry.grab_focus ();
			name_entry.select_region (0, -1);
		});
		var focus_ctl = new Gtk.EventControllerFocus ();
		name_entry.add_controller (focus_ctl);
		focus_ctl.leave.connect (() => { commit_name (name_entry, name_label, name_stack); });
		name_entry.activate.connect (() => { commit_name (name_entry, name_label, name_stack); });

		top_row.append (name_stack);

		// Background popover
		var bg_pop = new Gtk.Popover ();
		var bg_pop_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);

		var bg_dialog = new Gtk.ColorDialog ();
		bg_dialog.set_with_alpha (true);
		bg_color_btn = new Gtk.ColorDialogButton (bg_dialog);
		bg_color_btn.set_rgba (model.background);

		bg_wallpaper_switch = new Gtk.Switch ();
		bg_pop_box.append (new Gtk.Label ("Background color:"));
		bg_pop_box.append (bg_color_btn);
		var wallpaper_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		wallpaper_box.append (new Gtk.Label ("Use wallpaper"));
		wallpaper_box.append (bg_wallpaper_switch);
		bg_pop_box.append (wallpaper_box);
		bg_pop.set_child (bg_pop_box);

		var bg_button = new Gtk.MenuButton ();
		bg_button.set_tooltip_text ("Background options");
		bg_button.set_popover (bg_pop);
		bg_button.set_child (new Gtk.Image.from_icon_name ("document-properties-symbolic"));
		top_row.append (bg_button);

		// Zoom
		zoom_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0.25, 3.0, 0.25);
		zoom_scale.set_value (model.zoom);
		var zoom_btn = new Gtk.MenuButton ();
		var zoom_pop = new Gtk.Popover ();
		var pop_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		pop_box.set_size_request (250, -1);
		pop_box.append (zoom_scale);
		zoom_pop.set_child (pop_box);
		zoom_btn.set_popover (zoom_pop);
		zoom_btn.set_child (new Gtk.Image.from_icon_name ("zoom-in-symbolic"));
		top_row.append (zoom_btn);

		// Canvas
		canvas = new Gtk.DrawingArea ();
		canvas.set_content_width (128);
		canvas.set_content_height (128);
		canvas.set_hexpand (true);
		canvas.set_vexpand (true);
		canvas.set_halign (Gtk.Align.CENTER);
		canvas.set_valign (Gtk.Align.CENTER);
		canvas.set_size_request ((int)(128 * model.zoom), (int)(128 * model.zoom));
		canvas.set_margin_top (6);
		center_box.append (canvas);
		canvas.set_draw_func ((area, cr, width, height) => {
			cr.set_source_rgba (0, 0, 0, 0);
			cr.paint ();
			float z = clampf (model.zoom, 0.25f, 4.0f);
			cr.save ();
			cr.scale (z, z);
			render_icon (cr, 128);
			cr.restore ();
		});

		// RIGHT SIDEBAR
		var right_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		right_box.set_size_request (300, -1);
		right_box.set_vexpand (true);
		right_box.set_hexpand_set (true);
		right_box.set_margin_top (8);
		right_box.set_margin_bottom (8);
		right_box.set_margin_start (18);
		right_box.set_margin_end (18);
		main_box.append (right_box);

		var prop_header = new Gtk.Label (null);
		prop_header.add_css_class ("title-1");
		prop_header.set_markup ("Properties");
		prop_header.set_halign (Gtk.Align.START);
		right_box.append (prop_header);

		props_area = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		right_box.append (props_area);

		bg_props_area = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		right_box.append (bg_props_area);

		// Background properties (right)
		var bg_side_dialog = new Gtk.ColorDialog ();
		bg_side_dialog.set_with_alpha (true);
		bg_side_color_btn = new Gtk.ColorDialogButton (bg_side_dialog);
		bg_side_color_btn.set_rgba (model.background);
		bg_side_wall_switch = new Gtk.Switch ();
		bg_props_area.append (new Gtk.Label ("Background color:"));
		bg_props_area.append (bg_side_color_btn);

		// Element properties
		var pos_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		x_entry = new Gtk.SpinButton.with_range (0, 109, 1);
		y_entry = new Gtk.SpinButton.with_range (0, 109, 1);
		pos_box.append (new Gtk.Label ("X:"));
		pos_box.append (x_entry);
		pos_box.append (new Gtk.Label ("Y:"));
		pos_box.append (y_entry);
		props_area.append (pos_box);

		var size_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		w_entry = new Gtk.SpinButton.with_range (1, 109, 1);
		h_entry = new Gtk.SpinButton.with_range (1, 109, 1);
		size_box.append (new Gtk.Label ("W:"));
		size_box.append (w_entry);
		size_box.append (new Gtk.Label ("H:"));
		size_box.append (h_entry);
		props_area.append (size_box);

		// Fill (hidden for Line)
		var fill_label = new Gtk.Label ("Fill:");
		var fill_dialog = new Gtk.ColorDialog ();
		fill_dialog.set_with_alpha (false);
		fill_btn = new Gtk.ColorDialogButton (fill_dialog);
		props_area.append (fill_label);
		props_area.append (fill_btn);

		var fill_opacity_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		fill_opacity_spin = new Gtk.SpinButton.with_range (0, 100, 1);
		fill_opacity_box.append (new Gtk.Label ("Fill opacity (%)"));
		fill_opacity_box.append (fill_opacity_spin);
		props_area.append (fill_opacity_box);

		// Stroke
		var stroke_label = new Gtk.Label ("Stroke:");
		var stroke_dialog = new Gtk.ColorDialog ();
		stroke_dialog.set_with_alpha (false);
		stroke_btn = new Gtk.ColorDialogButton (stroke_dialog);
		props_area.append (stroke_label);
		props_area.append (stroke_btn);

		var stroke_opacity_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		stroke_opacity_spin = new Gtk.SpinButton.with_range (0, 100, 1);
		stroke_opacity_box.append (new Gtk.Label ("Stroke opacity (%)"));
		stroke_opacity_box.append (stroke_opacity_spin);
		props_area.append (stroke_opacity_box);

		stroke_width_spin = new Gtk.SpinButton.with_range (0, 20, 0.5);
		stroke_width_spin.set_digits (1);
		props_area.append (new Gtk.Label ("Stroke width:"));
		props_area.append (stroke_width_spin);

		blend_drop = new Gtk.DropDown.from_strings (blends);
		props_area.append (new Gtk.Label ("Blend mode:"));
		props_area.append (blend_drop);

		// Export
		var export_btn = new Gtk.Button.with_label ("Export SVG");
		right_box.append (export_btn);

		// Signals

		listbox.row_selected.connect ((lb, row) => {
			if (row == null) {
				model.background_selected = false;
				model.selected_index = -1;
			} else {
				int ridx = row.get_index ();
				if (ridx == 0) {
					model.background_selected = true;
					model.selected_index = -1;
				} else {
					model.background_selected = false;
					model.selected_index = ridx - 1;
				}
			}
			update_properties_visibility ();
			canvas.queue_draw ();
		});

		add_rect_btn.clicked.connect (() => {
			model.elements.append (new IconElement (ElementType.RECTANGLE));
			refresh_listbox ();
			canvas.queue_draw ();
		});
		add_circle_btn.clicked.connect (() => {
			model.elements.append (new IconElement (ElementType.CIRCLE));
			refresh_listbox ();
			canvas.queue_draw ();
		});
		add_line_btn.clicked.connect (() => {
			var e = new IconElement (ElementType.LINE);
			e.width = 40.0f;
			e.height = 40.0f;
			model.elements.append (e);
			refresh_listbox ();
			canvas.queue_draw ();
		});

		reorder_toggle.toggled.connect (() => {
			model.reorder_mode = reorder_toggle.get_active ();
			refresh_listbox ();
		});

		// Canvas selection hit test
		var clickc = new Gtk.GestureClick ();
		canvas.add_controller (clickc);
		clickc.released.connect ((g, n_press, px, py) => {
			float z = clampf (model.zoom, 0.25f, 4.0f);
			float x = (float) (px / z);
			float y = (float) (py / z);
			float preview = 109.0f;
			float ox = (128.0f - preview) / 2.0f;
			float oy = (128.0f - preview) / 2.0f;
			float relx = x - ox;
			float rely = y - oy;

			model.selected_index = -1;
			model.background_selected = false;
			int n = (int) model.elements.get_n_items ();
			for (int i = n - 1; i >= 0; i--) {
				var el = (IconElement) model.elements.get_item ((uint) i);
				if (relx >= el.x && relx <= el.x + el.width && rely >= el.y && rely <= el.y + el.height) {
					model.selected_index = i;
					break;
				}
			}
			if (model.selected_index >= 0) {
				var row2 = listbox.get_row_at_index (model.selected_index + 1);
				if (row2 != null) listbox.select_row (row2);
			} else {
				listbox.unselect_all ();
			}
			update_properties_visibility ();
			canvas.queue_draw ();
		});

		// Element property handlers
		x_entry.value_changed.connect (() => {
			if (model.selected_index < 0) return;
			var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
			el.x = (float) GLib.Math.fmin (GLib.Math.fmax ((float) x_entry.get_value (), 0.0f), 109.0f);
			canvas.queue_draw ();
		});
		y_entry.value_changed.connect (() => {
			if (model.selected_index < 0) return;
			var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
			el.y = (float) GLib.Math.fmin (GLib.Math.fmax ((float) y_entry.get_value (), 0.0f), 109.0f);
			canvas.queue_draw ();
		});
		w_entry.value_changed.connect (() => {
			if (model.selected_index < 0) return;
			var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
			el.width = (float) GLib.Math.fmin (GLib.Math.fmax ((float) w_entry.get_value (), 1.0f), 109.0f);
			canvas.queue_draw ();
		});
		h_entry.value_changed.connect (() => {
			if (model.selected_index < 0) return;
			var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
			el.height = (float) GLib.Math.fmin (GLib.Math.fmax ((float) h_entry.get_value (), 1.0f), 109.0f);
			canvas.queue_draw ();
		});
		stroke_width_spin.value_changed.connect (() => {
			if (model.selected_index < 0) return;
			var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
			el.stroke_width = (float) stroke_width_spin.get_value ();
			canvas.queue_draw ();
		});

		fill_btn.notify.connect ((pspec) => {
			if (pspec.name != "rgba") return;
			if (model.selected_index < 0) return;
			var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
			var rgba = fill_btn.get_rgba ();
			float a = (float) (fill_opacity_spin.get_value () / 100.0);
			a = clampf (a, 0.0f, 1.0f);
			rgba.alpha = a;
			el.fill = rgba;
			canvas.queue_draw ();
		});
		stroke_btn.notify.connect ((pspec) => {
			if (pspec.name != "rgba") return;
			if (model.selected_index < 0) return;
			var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
			var rgba = stroke_btn.get_rgba ();
			float a = (float) (stroke_opacity_spin.get_value () / 100.0);
			a = clampf (a, 0.0f, 1.0f);
			rgba.alpha = a;
			el.stroke = rgba;
			canvas.queue_draw ();
		});

		fill_opacity_spin.value_changed.connect (() => {
			if (model.selected_index < 0) return;
			var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
			float a = (float) (fill_opacity_spin.get_value () / 100.0);
			a = clampf (a, 0.0f, 1.0f);
			var rgba = el.fill;
			rgba.alpha = a;
			el.fill = rgba;
			canvas.queue_draw ();
		});
		stroke_opacity_spin.value_changed.connect (() => {
			if (model.selected_index < 0) return;
			var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
			float a = (float) (stroke_opacity_spin.get_value () / 100.0);
			a = clampf (a, 0.0f, 1.0f);
			var rgba = el.stroke;
			rgba.alpha = a;
			el.stroke = rgba;
			canvas.queue_draw ();
		});

		blend_drop.notify.connect ((pspec) => {
			if (pspec.name != "selected") return;
			if (model.selected_index < 0) return;
			uint idx = blend_drop.get_selected ();
			if (idx >= blends.length) return;
			var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
			el.blend_mode = blends[(int) idx];
			canvas.queue_draw ();
		});

		// Background property handlers
		bg_color_btn.notify.connect ((pspec) => {
			if (pspec.name != "rgba") return;
			update_bg_color (bg_color_btn.get_rgba ());
		});
		bg_side_color_btn.notify.connect ((pspec) => {
			if (pspec.name != "rgba") return;
			update_bg_color (bg_side_color_btn.get_rgba ());
		});
		bg_wallpaper_switch.state_set.connect ((w, state) => {
			model.use_wallpaper = state;
			bg_side_wall_switch.set_active (state);
			canvas.queue_draw ();
			return false;
		});
		bg_side_wall_switch.state_set.connect ((w, state) => {
			model.use_wallpaper = state;
			bg_wallpaper_switch.set_active (state);
			canvas.queue_draw ();
			return false;
		});

		zoom_scale.value_changed.connect ((s) => {
			model.zoom = (float) zoom_scale.get_value ();
			canvas.set_size_request ((int)(128 * model.zoom), (int)(128 * model.zoom));
			canvas.queue_draw ();
		});

		// Export (Gtk.FileDialog)
		export_btn.clicked.connect (() => {
			var file_dialog = new Gtk.FileDialog ();
			file_dialog.set_title ("Export SVG");
			var svg_filter = new Gtk.FileFilter ();
			svg_filter.set_filter_name ("SVG Files");
			svg_filter.add_suffix ("svg");
			var filters = new GLib.ListStore (typeof (Gtk.FileFilter));
			filters.append (svg_filter);
			file_dialog.set_filters (filters);
			file_dialog.set_default_filter (svg_filter);

			file_dialog.save.begin (win, null, (obj, res) => {
				try {
					var file = file_dialog.save.end (res);
					if (file == null) return;
					string? path = file.get_path ();
					if (path == null) return;
					string filename = path;
					if (!filename.has_suffix (".svg")) filename = filename + ".svg";
					export_to_svg (filename);
				} catch (GLib.Error e) {
					GLib.warning ("Export canceled or failed: %s", e.message);
				}
			});
		});

		props_area.set_visible (false);
		bg_props_area.set_visible (false);
		refresh_listbox ();
		win.present ();
	}

	// Helpers as private methods

	private void commit_name (Gtk.Entry entry, Gtk.Label label, Gtk.Stack stack) {
		model.name = entry.get_text ();
		label.set_text (model.name);
		stack.set_visible_child_name ("label");
	}

	private void refresh_listbox () {
		while (true) {
			var r = listbox.get_row_at_index (0);
			if (r == null) break;
			listbox.remove (r);
		}
		// Background row
		{
			var row = new Gtk.ListBoxRow ();
			row.set_size_request (-1, 42);
			var h = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
			var lbl = new Gtk.Label ("Background");
			lbl.set_xalign (0.0f);
			lbl.set_hexpand (true);
			h.append (lbl);
			row.set_child (h);
			listbox.append (row);
		}
		// Elements
		int n = (int) model.elements.get_n_items ();
		for (int i = 0; i < n; i++) {
			int idx = i;
			var el = (IconElement) model.elements.get_item ((uint) i);
			var row = new Gtk.ListBoxRow ();
			row.set_size_request (-1, 42);
			var h = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);

			var lbl = new Gtk.Label (element_label (el));
			lbl.set_xalign (0.0f);
			lbl.set_hexpand (true);
			h.append (lbl);

			if (model.reorder_mode) {
				var up = new Gtk.Button.from_icon_name ("go-up-symbolic");
				var down = new Gtk.Button.from_icon_name ("go-down-symbolic");
				up.set_tooltip_text ("Move up");
				down.set_tooltip_text ("Move down");
				up.set_sensitive (idx > 0);
				down.set_sensitive (idx < n - 1);
				up.clicked.connect (() => { move_item (idx, idx - 1); });
				down.clicked.connect (() => { move_item (idx, idx + 1); });
				h.append (up);
				h.append (down);
			}

			var rem = new Gtk.Button.from_icon_name ("edit-delete-symbolic");
			rem.set_tooltip_text ("Remove");
			rem.set_valign (Gtk.Align.CENTER);
			rem.clicked.connect (() => { remove_element_at (idx); });
			h.append (rem);

			row.set_child (h);
			listbox.append (row);
		}

		// Restore selection
		if (model.background_selected) {
			var r0 = listbox.get_row_at_index (0);
			if (r0 != null) listbox.select_row (r0);
		} else if (model.selected_index >= 0) {
			var r2 = listbox.get_row_at_index (model.selected_index + 1);
			if (r2 != null) listbox.select_row (r2);
		} else {
			listbox.unselect_all ();
		}
	}

	private string element_label (IconElement e) {
		switch (e.type) {
			case ElementType.RECTANGLE: return "Rectangle";
			case ElementType.CIRCLE: return "Circle";
			case ElementType.LINE: return "Line";
		}
		return "Element";
	}

	private void move_item (int from, int to) {
		if (from == to) return;
		int count = (int) model.elements.get_n_items ();
		if (from < 0 || from >= count || to < 0 || to >= count) return;
		var el = (IconElement) model.elements.get_item ((uint) from);
		model.elements.remove ((uint) from);
		if (to > from) to -= 1;
		model.elements.insert ((uint) to, el);
		if (model.selected_index == from) model.selected_index = to;
		refresh_listbox ();
		canvas.queue_draw ();
	}

	private void remove_element_at (int idx) {
		int count = (int) model.elements.get_n_items ();
		if (idx < 0 || idx >= count) return;
		model.elements.remove ((uint) idx);
		model.selected_index = -1;
		model.background_selected = false;
		refresh_listbox ();
		update_properties_visibility ();
		canvas.queue_draw ();
	}

	private float clampf (float v, float lo, float hi) {
		return (float) GLib.Math.fmax (lo, GLib.Math.fmin (v, hi));
	}

	private Cairo.Operator blend_to_operator (string s) {
		if (s == "multiply") return Cairo.Operator.MULTIPLY;
		if (s == "screen") return Cairo.Operator.SCREEN;
		if (s == "overlay") return Cairo.Operator.OVERLAY;
		return Cairo.Operator.OVER;
	}

	private void rounded_rect (Cairo.Context cr, float x, float y, float w, float h, float r) {
		float rad = (float) (GLib.Math.PI / 180.0);
		cr.new_sub_path ();
		cr.arc (x + w - r, y + r, r, -90.0f * rad, 0.0f * rad);
		cr.arc (x + w - r, y + h - r, r, 0.0f * rad, 90.0f * rad);
		cr.arc (x + r, y + h - r, r, 90.0f * rad, 180.0f * rad);
		cr.arc (x + r, y + r, r, 180.0f * rad, 270.0f * rad);
		cr.close_path ();
	}

	private void render_icon (Cairo.Context cr, int canvas_size) {
		cr.set_source_rgba (1.0, 1.0, 1.0, 0.0);
		cr.paint ();

		float preview = 109.0f;
		float radius = 24.0f;
		float cx = (canvas_size - preview) / 2.0f;
		float cy = (canvas_size - preview) / 2.0f;

		rounded_rect (cr, cx, cy, preview, preview, radius);
		cr.clip ();

		// Background
		if (model.use_wallpaper) {
			// Simple diagonal stripes wallpaper
			for (int i = 0; i < 20; i++) {
				float t = (float) i / 20.0f;
				cr.set_source_rgba (0.10 + 0.10 * t, 0.20 + 0.05 * t, 0.35 + 0.05 * t, 1.0);
				cr.rectangle (cx + t * preview, cy, preview / 10.0, preview);
				cr.fill ();
			}
		} else {
			float br = (float) model.background.red;
			float bg = (float) model.background.green;
			float bb = (float) model.background.blue;
			float ba = (float) model.background.alpha;
			cr.set_source_rgba (br, bg, bb, ba);
			cr.rectangle (cx, cy, preview, preview);
			cr.fill ();
		}

		// Elements
		int n = (int) model.elements.get_n_items ();
		for (int i = 0; i < n; i++) {
			var el = (IconElement) model.elements.get_item ((uint) i);

			float ex = cx + el.x;
			float ey = cy + el.y;
			float ew = el.width;
			float eh = el.height;

			ex = clampf (ex, cx, cx + preview);
			ey = clampf (ey, cy, cy + preview);
			ew = (float) GLib.Math.fmin (ew, (cx + preview) - ex);
			eh = (float) GLib.Math.fmin (eh, (cy + preview) - ey);

			cr.set_operator (blend_to_operator (el.blend_mode));

			if (el.type == ElementType.RECTANGLE || el.type == ElementType.CIRCLE) {
				float fr = (float) el.fill.red;
				float fg = (float) el.fill.green;
				float fb = (float) el.fill.blue;
				float fa = (float) el.fill.alpha;

				if (el.type == ElementType.RECTANGLE) {
					cr.set_source_rgba (fr, fg, fb, fa);
					cr.rectangle (ex, ey, ew, eh);
					cr.fill_preserve ();
				} else {
					cr.save ();
					cr.translate (ex + ew / 2.0f, ey + eh / 2.0f);
					cr.scale (ew / 2.0f, eh / 2.0f);
					cr.set_source_rgba (fr, fg, fb, fa);
					cr.arc (0.0, 0.0, 1.0, 0.0, 2.0 * (float) GLib.Math.PI);
					cr.restore ();
					cr.close_path ();
					cr.fill_preserve ();
				}
				float sr1 = (float) el.stroke.red;
				float sg1 = (float) el.stroke.green;
				float sb1 = (float) el.stroke.blue;
				float sa1 = (float) el.stroke.alpha;
				cr.set_source_rgba (sr1, sg1, sb1, sa1);
				cr.set_line_width (el.stroke_width);
				cr.stroke ();
			} else if (el.type == ElementType.LINE) {
				float sr = (float) el.stroke.red;
				float sg = (float) el.stroke.green;
				float sb = (float) el.stroke.blue;
				float sa = (float) el.stroke.alpha;
				cr.set_source_rgba (sr, sg, sb, sa);
				cr.set_line_width (el.stroke_width);
				cr.move_to (ex, ey);
				cr.line_to (ex + ew, ey + eh);
				cr.stroke ();
			}

			cr.set_operator (Cairo.Operator.OVER);
		}
	}

	private void update_properties_visibility () {
		bool show_bg = model.background_selected;
		bool show_el = (!model.background_selected && model.selected_index >= 0);

		bg_props_area.set_visible (show_bg);
		props_area.set_visible (show_el);

		if (show_bg) {
			bg_side_color_btn.set_rgba (model.background);
			bg_side_wall_switch.set_active (model.use_wallpaper);
		}
		if (show_el) {
			var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
			x_entry.set_value ((double) el.x);
			y_entry.set_value ((double) el.y);
			w_entry.set_value ((double) el.width);
			h_entry.set_value ((double) el.height);
			stroke_width_spin.set_value ((double) el.stroke_width);
			fill_btn.set_rgba (el.fill);
			stroke_btn.set_rgba (el.stroke);

			// Blend selection
			int bidx = 0;
			for (int i = 0; i < blends.length; i++) {
				if (blends[i] == el.blend_mode) { bidx = i; break; }
			}
			blend_drop.set_selected ((uint) bidx);

			// Fill controls visibility for LINE
			bool show_fill = (el.type != ElementType.LINE);
			fill_btn.set_visible (show_fill);
			// The label and opacity box are previous widget siblings; hide via parent traversal if needed
			// But here we ensure opacity spin always available:
			fill_opacity_spin.set_sensitive (show_fill);

			fill_opacity_spin.set_value ((double) ((float) el.fill.alpha * 100.0f));
			stroke_opacity_spin.set_value ((double) ((float) el.stroke.alpha * 100.0f));
		}
	}

	private void update_bg_color (Gdk.RGBA rgba) {
		model.use_wallpaper = false;
		model.background = rgba;
		bg_color_btn.set_rgba (rgba);
		bg_side_color_btn.set_rgba (rgba);
		canvas.queue_draw ();
	}

	private void export_to_svg (string filename) {
		double out_size = 128.0;
		var surface = new Cairo.SvgSurface (filename, out_size, out_size);
		var cr = new Cairo.Context (surface);
		render_icon (cr, 128);
		cr.show_page ();
		surface.finish ();
	}
}

int main (string[] args) {
	var app = new IconMakerApp ();
	return app.run (args);
}