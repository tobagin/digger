/*
 * digger-vala - DNS lookup tool with GTK interface
 * Copyright (C) 2024 tobagin
 */

using Gtk;
using Cairo;
using Gee;

namespace Digger {
    public class PerformanceGraph : Gtk.DrawingArea {
        private ArrayList<double?> data_points;
        private int max_points = 50;
        private double max_value = 100.0; // ms
        private string graph_label;
        private Gdk.RGBA line_color;

        public PerformanceGraph (string label, string color_str = "#3584e4") {
            data_points = new ArrayList<double?> ();
            graph_label = label;
            
            var rgba = Gdk.RGBA ();
            rgba.parse (color_str);
            line_color = rgba;

            this.set_draw_func (draw_func);
            this.set_content_width (300);
            this.set_content_height (150);
        }

        public void add_value (double value) {
            if (data_points.size >= max_points) {
                data_points.remove_at (0);
            }
            data_points.add (value);
            
            // Auto-scale max value, but decay slowly
            if (value > max_value) {
                max_value = value * 1.2;
            } else if (max_value > 100.0) {
                 // Slowly decay max scale if values are low
                 max_value = max_value * 0.99;
            }
            if (max_value < 50.0) max_value = 50.0;

            this.queue_draw ();
        }

        private void draw_func (Gtk.DrawingArea area, Cairo.Context cr, int width, int height) {
            // Background
            cr.set_source_rgba (0.1, 0.1, 0.1, 0.05);
            cr.rectangle (0, 0, width, height);
            cr.fill ();

            if (data_points.size < 2) return;

            // Draw grid lines
            cr.set_source_rgba (0.5, 0.5, 0.5, 0.2);
            cr.set_line_width (1.0);
            double step_y = height / 4.0;
            for (int i = 1; i < 4; i++) {
                cr.move_to (0, i * step_y);
                cr.line_to (width, i * step_y);
            }
            cr.stroke ();

            // Plot data
            cr.set_source_rgba (line_color.red, line_color.green, line_color.blue, 1.0);
            cr.set_line_width (2.0);

            double step_x = (double)width / (max_points - 1);
            
            bool first = true;
            for (int i = 0; i < data_points.size; i++) {
                double? val = data_points[i];
                if (val == null) continue;

                double x = i * step_x;
                // Invert Y axis (0 at top)
                double y = height - ((val / max_value) * height);
                // Clamp
                if (y < 0) y = 0;
                if (y > height) y = height;

                if (first) {
                    cr.move_to (x, y);
                    first = false;
                } else {
                    cr.line_to (x, y);
                }
            }
            cr.stroke ();

            // Label
            cr.set_source_rgb (0.5, 0.5, 0.5);
            cr.select_font_face ("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
            cr.set_font_size (10.0);
            cr.move_to (5, 15);
            cr.show_text (graph_label);
            
            // Max Scale Label
            cr.move_to (width - 40, 15);
            cr.show_text (@"$(int.max ((int)max_value, 0)) ms");
        }
    }
}
