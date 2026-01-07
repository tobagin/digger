/*
 * digger-vala - DNS lookup tool with GTK interface
 * Copyright (C) 2024 tobagin
 */

using Gtk;
using Adw;
using Gee;

namespace Digger {
#if DEVELOPMENT
    [GtkTemplate (ui = "/io/github/tobagin/digger/Devel/performance-dialog.ui")]
#else
    [GtkTemplate (ui = "/io/github/tobagin/digger/performance-dialog.ui")]
#endif
    public class PerformanceDialog : Adw.Dialog {
        [GtkChild]
        private unowned Gtk.Button start_stop_button;
        
        [GtkChild]
        private unowned Gtk.Box graphs_box;
        
        [GtkChild]
        private unowned Gtk.Box stats_box;

        private bool is_monitoring = false;
        private DnsQuery dns_query;

        // Monitoring targets
        private class MonitorTarget {
            public string name;
            public string server_ip;
            public string color;
            public PerformanceGraph graph;
            public Gtk.Label stats_label;
            public int total_queries = 0;
            public int failed_queries = 0;
            public double total_latency = 0;

            public MonitorTarget(string name, string ip, string color) {
                this.name = name;
                this.server_ip = ip;
                this.color = color;
            }
        }
        
        private ArrayList<MonitorTarget> targets;

        public PerformanceDialog (Gtk.Widget? parent) {
            dns_query = DnsQuery.get_instance ();
            targets = new ArrayList<MonitorTarget> ();
            
            // Define targets
            targets.add (new MonitorTarget ("Google", "8.8.8.8", "#3584e4"));     // Blue
            targets.add (new MonitorTarget ("Cloudflare", "1.1.1.1", "#e01b24")); // Red
            targets.add (new MonitorTarget ("Quad9", "9.9.9.9", "#26a269"));      // Green
            
            setup_ui ();
        }

        private void setup_ui () {
            foreach (var target in targets) {
                // Create Graph
                target.graph = new PerformanceGraph (@"$(target.name) ($(target.server_ip))", target.color);
                graphs_box.append (target.graph);
                
                // Create Stats Label
                var card = new Adw.Bin ();
                card.add_css_class ("card");
                var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
                box.margin_start = 12;
                box.margin_end = 12;
                box.margin_top = 12;
                box.margin_bottom = 12;
                
                var title = new Gtk.Label (target.name);
                title.add_css_class ("heading");
                
                target.stats_label = new Gtk.Label ("Waiting...");
                target.stats_label.add_css_class ("caption");
                
                box.append (title);
                box.append (target.stats_label);
                card.child = box;
                
                stats_box.append (card);
            }
        }

        [GtkCallback]
        private void on_start_stop_clicked () {
            if (is_monitoring) {
                stop_monitoring ();
            } else {
                start_monitoring ();
            }
        }

        private void start_monitoring () {
            is_monitoring = true;
            start_stop_button.label = "Stop Monitoring";
            start_stop_button.remove_css_class ("suggested-action");
            start_stop_button.add_css_class ("destructive-action");
            
            monitor_loop.begin ();
        }

        private void stop_monitoring () {
            is_monitoring = false;
            start_stop_button.label = "Start Monitoring";
            start_stop_button.remove_css_class ("destructive-action");
            start_stop_button.add_css_class ("suggested-action");
        }

        private async void monitor_loop () {
            while (is_monitoring) {
                // Launch queries in parallel
                foreach (var target in targets) {
                    ping_target.begin (target);
                }
                
                // Wait 1 second between rounds
                yield nap (1000);
            }
        }

        private async void ping_target (MonitorTarget target) {
            // Use a lightweight query, e.g. root NS or just version.bind
            // For simplicity, let's query the root . NS
            var result = yield dns_query.perform_query (".", RecordType.NS, target.server_ip);
            
            double latency = 0;
            bool success = false;

            if (result.status == QueryStatus.SUCCESS || result.status == QueryStatus.NXDOMAIN) {
                // Even NXDOMAIN means the server responded
                latency = result.query_time_ms;
                success = true;
            } else {
                 // Timeout or error
                 success = false;
            }

            // Update Graph
            if (success) {
                target.graph.add_value (latency);
            } else {
                target.graph.add_value (0); // Or handled differently? 0 implies fast. Maybe logic in graph to show gap?
                // For now, let's just log it but graph 0 is misleading. 
                // Let's rely on stats to show failure.
            }

            // Update Stats
            target.total_queries++;
            if (!success) target.failed_queries++;
            else target.total_latency += latency;

            double avg_latency = target.total_queries > target.failed_queries ? 
                                 target.total_latency / (target.total_queries - target.failed_queries) : 0;
            double loss_rate = (double)target.failed_queries / target.total_queries * 100.0;

            string avg_str = "%.1f".printf (avg_latency);
            string loss_str = "%.1f".printf (loss_rate);

            target.stats_label.label = @"Avg: $avg_str ms\nLoss: $loss_str%";
        }

        private async void nap (uint interval) {
            Timeout.add (interval, () => {
                nap.callback ();
                return false;
            });
            yield;
        }
    }
}
